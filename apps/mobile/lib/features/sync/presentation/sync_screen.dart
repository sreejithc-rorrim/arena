import 'dart:convert';

import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/app/sync/cloud_binding.dart';
import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/core/widgets/confirm_dialog.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/sync/sync_engine.dart';
import 'package:arena_ops/data/sync/sync_recorder.dart';
import 'package:drift/drift.dart' show OrderingMode, OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What this device has not yet got onto the server, and what the server
/// refused. Nothing here is ever dropped silently: a refused change (a session
/// another device beat us to, a payment for it) stays listed with the server's
/// reason — and the amount — until someone marks it seen.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arena = context.arena;
    final binding = ref.watch(cloudBindingProvider);
    final status = ref.watch(syncStatusProvider).value ?? SyncStatus.localOnly;
    final db = ref.watch(databaseProvider);
    final ops = ref.watch(_outboxProvider).value ?? const <SyncOutboxRow>[];
    final refused = [
      for (final o in ops)
        if (o.status == OutboxStatus.rejected && o.resolvedAt == null) o,
    ];
    final waiting = [
      for (final o in ops)
        if (o.status == OutboxStatus.pending) o,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Sync')),
      body: binding == null
          ? const Center(child: Text('This device is in local-only mode.'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(binding.arenaName, style: ArenaType.h2.copyWith(color: arena.text)),
                Text('Signed in as ${binding.email}',
                    style: ArenaType.caption.copyWith(color: arena.textMuted)),
                const SizedBox(height: AppSpacing.md),
                Text(_describe(status),
                    style: ArenaType.body.copyWith(color: arena.text)),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  // start(), not one pass: if syncing had stopped (a token
                  // problem), it resumes the background passes as well.
                  onPressed: status.state == SyncState.syncing
                      ? null
                      : binding.engine.start,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sync now'),
                ),
                if (status.state == SyncState.authProblem &&
                    !status.accessRevoked) ...[
                  const SizedBox(height: AppSpacing.sm),
                  // Unsent changes stay in this person's database file and go
                  // as soon as they sign in again on this device.
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      binding.signOut();
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in again'),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text('Needs attention (${refused.length})',
                    style: ArenaType.h3.copyWith(color: arena.text)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'The server refused these. This device has been put back in '
                  'step with the server, so the change is NOT on the floor — '
                  'redo it if it is still right. Money listed here was taken '
                  'on this device but is not recorded on the server.',
                  style: ArenaType.caption.copyWith(color: arena.textMuted),
                ),
                for (final o in refused)
                  _OpTile(
                    op: o,
                    db: db,
                    trailing: TextButton(
                      onPressed: () async {
                        final ok = await confirmAction(
                          context,
                          title: 'Dismiss this refused change?',
                          message: 'It leaves this list for good. Redo it on '
                              'the floor first if it is still right; money '
                              'listed here must be recorded again.',
                          confirm: 'Dismiss',
                          destructive: true,
                        );
                        if (ok) binding.engine.acknowledge(o.opId);
                      },
                      child: const Text('Seen'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                Text('Waiting to send (${waiting.length})',
                    style: ArenaType.h3.copyWith(color: arena.text)),
                const SizedBox(height: AppSpacing.xs),
                Text('Saved on this device. They go to the server, in order, '
                    'as soon as it can be reached.',
                    style: ArenaType.caption.copyWith(color: arena.textMuted)),
                for (final o in waiting) _OpTile(op: o, db: db),
              ],
            ),
    );
  }

  static String _describe(SyncStatus s) => switch (s.state) {
        SyncState.localOnly => 'Local-only mode: nothing is shared.',
        SyncState.synced => s.lastSyncedAt == null
            ? 'Up to date.'
            : 'Up to date (last synced ${IstTime.format12(s.lastSyncedAt!)}).',
        SyncState.pending => '${s.pending} change(s) waiting to send.',
        SyncState.syncing => 'Syncing…',
        SyncState.offline => 'Offline. ${s.pending} change(s) are saved on this '
            'device and will send when the server can be reached.',
        SyncState.authProblem => s.message ?? 'Sign in again to keep syncing.',
        SyncState.error => s.message ?? 'Sync failed; retrying.',
      };
}

final _outboxProvider = StreamProvider.autoDispose<List<SyncOutboxRow>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.syncOutbox)
        ..where((t) => t.status.isIn([OutboxStatus.pending, OutboxStatus.rejected]))
        ..orderBy([(t) => OrderingTerm(expression: t.seq, mode: OrderingMode.desc)]))
      .watch();
});

class _OpTile extends StatelessWidget {
  const _OpTile({required this.op, required this.db, this.trailing});
  final SyncOutboxRow op;
  final AppDatabase db;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;
    final reason = op.errorCode == null ? null : reasonFor(op.errorCode!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(labelFor(op.kind, payload)),
      subtitle: Text([
        IstTime.format12(op.createdAt),
        ?reason,
      ].join(' · '),
          style: ArenaType.caption.copyWith(
              color: reason == null ? arena.textMuted : arena.danger)),
      trailing: trailing,
    );
  }
}

/// A person-readable name for an op.
String labelFor(String kind, Map<String, dynamic> p) => switch (kind) {
      'session.start' => p['booking_id'] != null ? 'Check-in' : 'Start session',
      'session.reconfigure' => 'Change system / game / controllers',
      'session.extend' => 'Extend +${p['added_minutes']} min',
      'session.end' => 'End session (bill '
          '${Paise((p['billed_amount_paise'] as num?)?.toInt() ?? 0).display})',
      'session.void' => 'Void session',
      'payment.record' => '${p['is_refund'] == true ? 'Refund' : 'Payment'} '
          '${Paise(((p['amount_paise'] as num?)?.toInt() ?? 0).abs()).display} '
          '(${p['method']})',
      'controller.move' => 'Move controller',
      'customer.create' => 'New customer ${p['name'] ?? ''}',
      'customer.update' => 'Edit customer',
      'booking.create' => 'New booking',
      'booking.update' => 'Edit booking',
      'booking.set_status' => 'Booking ${p['status']}',
      'staff.update' => 'Staff change',
      _ => 'Settings change ($kind)',
    };

/// Why the server refused, in words staff can act on.
String reasonFor(String code) => switch (code) {
      'resource_busy' => 'that station was already in use (another device '
          'started it first)',
      'controller_taken' => 'a controller was already in use',
      'controller_elsewhere' => 'a controller had been moved to another station',
      'controllers_unavailable' => 'not enough free controllers at that station',
      'stale' => 'it was changed on another device first — check and redo',
      'not_active' => 'it had already been ended on another device',
      'booking_not_open' => 'the booking was already checked in or cancelled',
      'booking_conflict' => 'that time on that station was already booked',
      'forbidden' => 'your account is not allowed to do this',
      'voided' => 'it had been voided',
      'not_found' => 'it does not exist on the server (an earlier step was refused)',
      'duplicate' => 'already recorded',
      'players_exceeded' => 'too many players for that game',
      'not_playable' => 'that game cannot run on that station',
      'mode_locked' => 'that station is locked to another mode',
      'last_settings_holder' => 'someone must keep access to Settings',
      // Money and prices.
      'price_mismatch' => 'the server priced the bill differently, so it stays '
          'open — check its times and end it again',
      'pricing_snapshot_mismatch' => 'the price list changed while this device '
          'was offline — start it again with the current prices',
      'no_rate' => 'there is no price for that station type and controller count',
      'overpayment' => 'it would collect more than the bill — the money was taken '
          'but not recorded: hand it back or record it on the right bill',
      'refund_exceeds_paid' => 'the refund is more than was collected',
      'refund_reason_required' => 'a refund needs a reason',
      'amount_zero' || 'amount_negative' => 'the amount must be more than zero',
      'invalid_method' => 'that payment method is not accepted here',
      // Sessions.
      'invalid_time' => 'its times were out of order',
      'time_in_future' => 'its time is ahead of the server — check the '
          'tablet\'s date and time',
      'time_too_old' => 'it waited offline too long to be accepted — tell the '
          'owner, who can record it from the dashboard',
      'activity_not_offered' => 'that station does not offer that type',
      'waive_reason_required' => 'a waive needs a reason',
      'end_reason_required' => 'an earlier end needs a reason',
      'waive_over_limit' => 'only an owner can waive that much',
      'no_open_segment' => 'the session had already moved or ended on another device',
      'resource_unavailable' => 'that station is out of service',
      'resource_missing' || 'missing_reference' =>
        'a station, game or customer it names no longer exists',
      'activity_missing' => 'that station type no longer exists',
      'mode_switch_busy' => 'the station is in use, so its mode cannot change',
      // Controllers.
      'controllers_exceeded' => 'more controllers than that station takes',
      'controller_count_mismatch' =>
        'the controller count did not match the controllers picked',
      'controller_unusable' => 'a controller is marked faulty or unavailable',
      'controller_missing' => 'a controller no longer exists',
      'controller_duplicate' => 'the same controller was picked twice',
      'controller_in_use' => 'a controller was already in use',
      'move_kind_invalid' => 'that controller move is not allowed',
      // Customers and bookings.
      'phone_taken' => 'another customer already has that phone number',
      'invalid_birth_year' => 'the birth year is not valid',
      'booking_missing' => 'the booking no longer exists',
      'invalid_status' => 'that status change is not allowed',
      // Settings and anything else.
      'invalid_name' => 'the name is blank or too long',
      'invalid' || 'invalid_payload' => 'a value was not accepted by the server',
      'invalid_permission' => 'an unknown permission was sent',
      'setting_not_shared' => 'that setting is not shared between devices',
      'unknown_op' => 'this app version sent something the server does not '
          'know — update the app',
      'server_error' => 'the server hit an error — try again later',
      _ => 'refused ($code)',
    };
