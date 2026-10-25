import 'package:arena_ops/app/controllers/booking_actions.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/widgets/app_toast.dart';
import 'package:arena_ops/domain/entities/booking.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';
import 'package:arena_ops/features/controllers/presentation/controller_choice_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Check a booked party in (spec §22–§23) with the same controller control as
/// New Session: the system is resolved now (the booked one, or the best free
/// compatible one, with the other free ones as chips staff can pick instead),
/// the booking's controller count is pre-picked from the pads
/// standing there, and anything short can be borrowed explicitly. Nothing is
/// started until "Check in" — which re-validates everything.
///
/// Returns true when the session started.
Future<bool?> showCheckInSheet(BuildContext context, Booking booking) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CheckInSheet(booking: booking),
  );
}

class _CheckInSheet extends ConsumerStatefulWidget {
  const _CheckInSheet({required this.booking});
  final Booking booking;

  @override
  ConsumerState<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<_CheckInSheet> {
  late final Future<Result<CheckInPlan>> _plan =
      ref.read(bookingActionsProvider).planCheckIn(widget.booking);
  ControllerChoice? _choice;

  /// The station staff picked from the plan's choices (any-system bookings);
  /// null = the planned one.
  Resource? _station;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arena = context.arena;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: FutureBuilder<Result<CheckInPlan>>(
        future: _plan,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Finding a system…'),
            );
          }
          final planned = snap.data!;
          if (planned.isErr) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Check in', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                Text(planned.failureOrNull!.display,
                    key: const ValueKey('check-in-problem'),
                    style: TextStyle(color: theme.colorScheme.error)),
              ],
            );
          }
          final plan = planned.valueOrNull!;
          final station = _station ?? plan.resource;
          final choice = _choice ??
              (plan.requestedControllers == null
                  ? ControllerChoice.none
                  : ControllerChoice.tracked(
                      requested: plan.requestedControllers));
          final max = plan.gameMaxLocalPlayers;
          // Ready when the controllers (if any) are fully chosen: a tracked
          // pick with no shortfall, or a count in an untracked arena.
          final ready = !plan.usesControllers ||
              (choice.count != null &&
                  (!choice.isTracked || choice.shortfall == 0));
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Check in · ${_partyName()}',
                  key: const ValueKey('check-in-title'),
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${station.name}'
                '${plan.alternatives ? ' · free compatible system' : ''}'
                '${plan.requestedControllers == null ? '' : ' · booked for '
                    '${plan.requestedControllers} controller'
                    '${plan.requestedControllers == 1 ? '' : 's'}'}',
                key: const ValueKey('check-in-station'),
                style: ArenaType.caption.copyWith(color: arena.textMuted),
              ),
              if (plan.choices.length > 1) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final r in plan.choices)
                      ChoiceChip(
                        key: ValueKey('check-in-station-${r.id}'),
                        label: Text(r.name),
                        selected: station.id == r.id,
                        // Same count at the new station; the field picks
                        // that many free pads there.
                        onSelected: (_) {
                          if (r.id == station.id) return; // keep the picks
                          setState(() {
                            _station = r;
                            _choice = ControllerChoice.tracked(
                                requested: choice.requested);
                          });
                        },
                      ),
                  ],
                ),
              ],
              if (plan.usesControllers) ...[
                const SizedBox(height: AppSpacing.md),
                ControllerChoiceField(
                  key: ValueKey('check-in-pads-${station.id}'),
                  alternatives: plan.choices,
                  resourceId: station.id,
                  resourceName: station.name,
                  choice: choice,
                  maxCount: max,
                  maxReason: max == null || max >= 4
                      ? null
                      : '${plan.gameName ?? 'This game'} supports up to $max '
                          'local player${max == 1 ? '' : 's'}.',
                  onChanged: (c) => setState(() => _choice = c),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const ValueKey('check-in-confirm'),
                onPressed: !ready || _busy
                    ? null
                    : () => _confirm(plan, station, choice),
                icon: const Icon(Icons.play_arrow),
                label: Text(_busy ? 'Starting…' : 'Check in & start'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The name the upcoming-bookings tile shows: the party name, else the
  /// customer's (a walk-in booking has no party name).
  String _partyName() {
    final party = widget.booking.partyName;
    if (party != null && party.trim().isNotEmpty) return party;
    final customerId = widget.booking.customerId;
    if (customerId == null) return 'Guest';
    return ref.watch(customerByIdProvider(customerId)).value?.displayName ??
        'Guest';
  }

  Future<void> _confirm(
    CheckInPlan plan,
    Resource station,
    ControllerChoice choice,
  ) async {
    setState(() => _busy = true);
    final r = await ref.read(bookingActionsProvider).checkIn(
          widget.booking,
          controllers: plan.usesControllers ? choice : null,
          resourceId: station.id,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    r.fold(
      (_) => Navigator.of(context).pop(true),
      (f) => showFailure(context, f),
    );
  }
}
