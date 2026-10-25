/// My bills: the closed bills the signed-in staff member started, one day at a
/// time (today first; the date picker and arrows switch days). Tap a bill to
/// change its total with a comment. Online only; the server keeps the list to
/// your own bills and re-checks every edit.
library;

import 'package:arena_ops/app/auth/auth_controller.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/app/providers/my_bills_providers.dart';
import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/core/widgets/arena_badge.dart';
import 'package:arena_ops/core/widgets/arena_list.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/bills/my_bill.dart';
import 'package:arena_ops/features/bills/presentation/add_missed_bill_sheet.dart';
import 'package:arena_ops/features/bills/presentation/edit_bill_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class MyBillsScreen extends ConsumerStatefulWidget {
  const MyBillsScreen({super.key});

  /// A bottom tab for staff with bill_edit; owners open it from More.
  static const String path = '/my-bills';

  @override
  ConsumerState<MyBillsScreen> createState() => _MyBillsScreenState();
}

class _MyBillsScreenState extends ConsumerState<MyBillsScreen> {
  IstDate? _day;

  IstDate get _today => IstDate.fromUtc(ref.read(clockProvider).now());

  Future<void> _pick(IstDate current) async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(today.year - 2, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    setState(() => _day = IstDate(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    final today = IstDate.fromUtc(ref.watch(clockProvider).now());
    final day = _day ?? today;
    final bills = ref.watch(myBillsForDayProvider(day));

    Future<void> refresh() async {
      ref.invalidate(myBillsForDayProvider(day));
      await ref.read(myBillsForDayProvider(day).future);
    }

    final failure = bills.value?.failureOrNull;
    final list = bills.value?.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My bills'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous day',
                  onPressed: () => setState(() => _day = day.addDays(-1)),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(day),
                    icon: const Icon(Icons.event_rounded),
                    label: Text(
                      day == today
                          ? 'Today · ${_dayLabel(day)}'
                          : _dayLabel(day),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next day',
                  onPressed: day.compareTo(today) >= 0
                      ? null
                      : () => setState(() => _day = day.addDays(1)),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: arena.bg,
      // Adding a missed bill is its own permission (bill_record).
      floatingActionButton:
          failure?.code == 'bills_need_cloud' ||
              !(ref.watch(authControllerProvider)?.can(Permission.billRecord) ?? false)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddMissedBillSheet(context, day: day),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add missed bill'),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  96,
                ),
                children: [
                  if (failure != null) ...[
                    Text(
                      failure.message,
                      style: ArenaType.body.copyWith(color: arena.text),
                    ),
                    if (failure.fix != null)
                      Text(
                        failure.fix!,
                        style: ArenaType.caption.copyWith(
                          color: arena.textMuted,
                        ),
                      ),
                  ] else if (list == null)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (list.isEmpty)
                    Text(
                      'No bills you started closed on this day.',
                      style: ArenaType.body.copyWith(color: arena.textMuted),
                    )
                  else ...[
                    Text(
                      _summary(list),
                      style: ArenaType.caption.copyWith(color: arena.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ArenaRowGroup(
                      children: [
                        for (final b in list) _BillRow(bill: b, day: day),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _dayLabel(IstDate d) =>
    DateFormat('EEE d MMM yyyy').format(DateTime.utc(d.year, d.month, d.day));

String _summary(List<MyBill> bills) {
  final closed = bills.where((b) => !b.isVoided).toList();
  final total = closed.fold<int>(0, (s, b) => s + (b.billedPaise ?? 0));
  return '${bills.length} ${bills.length == 1 ? 'bill' : 'bills'}'
      '${closed.isEmpty ? '' : ' · billed ${Paise(total).display}'}';
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill, required this.day});

  final MyBill bill;
  final IstDate day;

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    final b = bill;
    final tag = switch (b) {
      _ when b.isVoided => (
        label: 'Voided',
        fg: arena.textMuted,
        bg: arena.surfaceSunken,
      ),
      _ when b.isWaived => (
        label: 'Waived',
        fg: arena.textMuted,
        bg: arena.surfaceSunken,
      ),
      _ when b.paymentStatus == 'unpaid' => (
        label: 'Unpaid',
        fg: arena.danger,
        bg: arena.dangerSoft,
      ),
      _ when b.paymentStatus == 'partial' => (
        label: 'Part paid',
        fg: arena.warning,
        bg: arena.warningSoft,
      ),
      _ when b.edits.isNotEmpty || b.addedLater => (
        label: b.edits.isNotEmpty ? 'Edited' : 'Added later',
        fg: arena.warning,
        bg: arena.warningSoft,
      ),
      _ => null,
    };
    return ArenaListRow(
      icon: Icons.receipt_long_outlined,
      title: [
        b.guest || b.customer == null ? 'Guest' : b.customer!,
        if (b.stations.isNotEmpty) b.stations.join(', '),
      ].join(' · '),
      subtitle: [
        '${IstTime.format12(b.startedAt)} → '
            '${IstTime.format12(b.endedAt ?? b.closedAt)}',
        if (b.games.isNotEmpty) b.games.join(', '),
      ].join(' · '),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            b.billedPaise == null ? '—' : Paise(b.billedPaise!).display,
            style: AppTextStyles.mono(ArenaType.label).copyWith(
              color: b.isVoided ? arena.textMuted : arena.text,
              decoration: b.isVoided ? TextDecoration.lineThrough : null,
            ),
          ),
          if (tag != null) ...[
            const SizedBox(height: AppSpacing.xs),
            ArenaTag(label: tag.label, foreground: tag.fg, background: tag.bg),
          ],
        ],
      ),
      onTap: () => showEditBillSheet(context, bill: b, day: day),
    );
  }
}
