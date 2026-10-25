/// One of my bills: what was billed and collected, earlier edits, and — when it
/// can still change — the new total, how any difference was paid or given back,
/// and a required comment. Sent as `bill.adjust`; the server records the
/// difference as one payment or refund and audits it with the comment.
library;

import 'package:arena_ops/app/auth/auth_controller.dart';
import 'package:arena_ops/app/controllers/bill_edit_actions.dart';
import 'package:arena_ops/app/providers/my_bills_providers.dart';
import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/money/rupee_input.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/core/widgets/app_toast.dart';
import 'package:arena_ops/core/widgets/arena_segmented.dart';
import 'package:arena_ops/core/widgets/confirm_dialog.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/bills/my_bill.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showEditBillSheet(
  BuildContext context, {
  required MyBill bill,
  required IstDate day,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => EditBillSheet(bill: bill, day: day),
);

class EditBillSheet extends ConsumerStatefulWidget {
  const EditBillSheet({super.key, required this.bill, required this.day});

  final MyBill bill;

  /// The day the list shows, refreshed after a change.
  final IstDate day;

  @override
  ConsumerState<EditBillSheet> createState() => _EditBillSheetState();
}

class _EditBillSheetState extends ConsumerState<EditBillSheet> {
  late final TextEditingController _amount;
  final _comment = TextEditingController();
  late PaymentMethod _method;
  bool _busy = false;
  Failure? _failure;

  /// Kept to resend with the same id after a dropped connection.
  BillAdjustCommand? _unsent;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    _amount = TextEditingController(
      text: b.billedPaise == null ? '' : paiseToRupeeInput(b.billedPaise!),
    );
    _method = b.methods.isEmpty
        ? PaymentMethod.cash
        : PaymentMethod.values.firstWhere(
            (m) => m.code == b.methods.first,
            orElse: () => PaymentMethod.cash,
          );
  }

  @override
  void dispose() {
    _amount.dispose();
    _comment.dispose();
    super.dispose();
  }

  int? get _newTotal => parseRupeesToPaise(_amount.text);

  void _changed() => setState(() {
    _unsent = null;
    _failure = null;
  });

  Future<void> _save() async {
    final b = widget.bill;
    final total = _newTotal;
    if (total == null) {
      setState(
        () => _failure = const Failure(
          message: 'That amount does not work.',
          fix: 'Enter the new total in rupees, 0 or more.',
          code: 'invalid_total',
        ),
      );
      return;
    }
    if (_comment.text.trim().isEmpty) {
      setState(
        () => _failure = const Failure(
          message: 'Say why the bill changes.',
          fix: 'Add a short comment.',
          code: 'reason_required',
        ),
      );
      return;
    }
    final actions = ref.read(billEditActionsProvider);
    final cmd =
        _unsent ??
        actions.prepare(
          bill: b,
          newTotalPaise: total,
          reason: _comment.text,
          method: _method,
        );
    final diff = cmd.differencePaise;
    final ok = await confirmAction(
      context,
      title: 'Change this bill to ${Paise(total).display}?',
      message: [
        'Billed ${Paise(b.billedPaise ?? 0).display} → ${Paise(total).display}.',
        if (diff > 0)
          'Collect ${Paise(diff).display} more by ${_method.label}.',
        if (diff < 0) 'Give back ${Paise(-diff).display} by ${_method.label}.',
        'The change and your comment are recorded and the owner can see them.',
      ].join(' '),
      confirm: 'Save change',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final res = await actions.adjust(cmd);
    if (!mounted) return;
    switch (res) {
      case Ok():
        ref.invalidate(myBillsForDayProvider(widget.day));
        Navigator.of(context).pop();
        showToast(context, 'Bill changed to ${Paise(total).display}.');
      // The bill changed since it was loaded: reopen it on the current amounts.
      case Err(failure: final f) when f.code == 'stale':
        ref.invalidate(myBillsForDayProvider(widget.day));
        final toast = AppToast.of(context);
        Navigator.of(context).pop();
        toast.failure(f);
      case Err(failure: final f):
        setState(() {
          _busy = false;
          _failure = f;
          _unsent = f.code == 'offline' || f.code == 'retry' ? cmd : null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    final b = widget.bill;
    final mayEdit =
        ref.watch(authControllerProvider)?.can(Permission.billEdit) ?? false;
    final editable = b.canEdit && mayEdit;
    final total = _newTotal;
    final diff = total == null ? 0 : total - b.paidPaise;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editable ? 'Edit bill' : 'Bill',
                style: ArenaType.h2.copyWith(color: arena.text),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  b.guest || b.customer == null ? 'Guest' : b.customer!,
                  if (b.stations.isNotEmpty) b.stations.join(', '),
                  '${IstTime.format12(b.startedAt)} → '
                      '${IstTime.format12(b.endedAt ?? b.closedAt)}',
                ].join(' · '),
                style: ArenaType.body.copyWith(color: arena.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Billed ${b.billedPaise == null ? '—' : Paise(b.billedPaise!).display}'
                ' · Collected ${Paise(b.paidPaise).display}',
                style: AppTextStyles.mono(ArenaType.label)
                    .copyWith(color: arena.text),
              ),
              for (final e in b.edits) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${IstTime.format12(e.at)} · '
                  '${e.amountPaise > 0 ? '+' : ''}${Paise(e.amountPaise).display}'
                  '${e.by == null ? '' : ' by ${e.by}'}'
                  '${e.reason == null ? '' : ': ${e.reason}'}',
                  style: ArenaType.caption.copyWith(color: arena.textMuted),
                ),
              ],
              if (!editable) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  !mayEdit
                      ? 'Changing a bill needs "Edit own bills" access. Ask the owner.'
                      : b.isVoided
                      ? 'This bill was voided, so it has no total to change.'
                      : b.isWaived
                      ? 'This bill was waived, so it owes nothing and cannot be changed.'
                      : 'This bill cannot be changed.',
                  style: ArenaType.body.copyWith(color: arena.text),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _amount,
                  enabled: !_busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'New total (₹)',
                    prefixText: '₹ ',
                  ),
                  onChanged: (_) => _changed(),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  total == null
                      ? 'Enter an amount in rupees.'
                      : diff > 0
                      ? 'Customer pays ${Paise(diff).display} more.'
                      : diff < 0
                      ? 'Give back ${Paise(-diff).display}.'
                      : 'Nothing to collect or give back.',
                  style: ArenaType.caption.copyWith(color: arena.textMuted),
                ),
                if (diff != 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    diff > 0 ? 'Paid by' : 'Given back by',
                    style: ArenaType.label.copyWith(color: arena.text),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ArenaSegmented<PaymentMethod>(
                    segments: [
                      for (final m in PaymentMethod.values)
                        ArenaSegment(m, m.label),
                    ],
                    value: _method,
                    onChanged: (m) {
                      _method = m;
                      _changed();
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _comment,
                  enabled: !_busy,
                  maxLength: 500,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Comment (required)',
                    hintText: 'Why the bill changes',
                  ),
                  onChanged: (_) => _changed(),
                ),
                if (_failure != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _failure!.message,
                    style: ArenaType.label.copyWith(color: arena.danger),
                  ),
                  if (_failure!.fix != null)
                    Text(
                      _failure!.fix!,
                      style: ArenaType.body.copyWith(color: arena.text),
                    ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: AppSpacing.minTarget,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(
                      _busy
                          ? 'Saving…'
                          : _unsent != null
                          ? 'Try again'
                          : 'Save change',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
