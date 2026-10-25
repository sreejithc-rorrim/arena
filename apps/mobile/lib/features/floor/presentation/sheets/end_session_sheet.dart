import 'package:arena_ops/app/controllers/session_actions.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/money/rupee_input.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/time/duration_format.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/core/widgets/app_toast.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/services/segment_billing.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/value/floor_options.dart';
import 'package:arena_ops/features/controllers/presentation/controller_choice_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// End a session and record payment (spec §14, §19–§20). The bill is computed
/// from every segment's configuration.
Future<void> showEndSessionSheet(BuildContext context, ActiveSession active) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.95,
      child: _EndSheet(active: active),
    ),
  );
}

class _EndSheet extends ConsumerStatefulWidget {
  const _EndSheet({required this.active});
  final ActiveSession active;
  @override
  ConsumerState<_EndSheet> createState() => _EndSheetState();
}

class _EndSheetState extends ConsumerState<_EndSheet> {
  late DateTime _endAt;
  late SegmentBill _bill;

  /// Staff's choice when played past the booked end: bill the overtime too.
  bool _chargeOvertime = false;

  /// What the overtime would add (0 when not over the booked end).
  int _overtimePaise = 0;

  final _amountCtrl = TextEditingController();

  /// The bill amount, prefilled with the price; staff may lower it.
  final _billCtrl = TextEditingController();
  final _waiveReasonCtrl = TextEditingController();

  /// Staff set an earlier end with the picker; it needs a reason (audited).
  bool _endPicked = false;
  final _endReasonCtrl = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;

  /// The pick, or the first method the arena offers when the pick is not (floor options).
  PaymentMethod _offered(PaymentMethod picked) =>
      (ref.read(floorOptionsProvider).value ?? FloorOptions.defaults).methodOr(picked);
  bool _waived = false;
  bool _saving = false;

  Session get _session => widget.active.session;

  @override
  void initState() {
    super.initState();
    _endAt = ref.read(clockProvider).now();
    _price();
  }

  /// Prices the session up to [_endAt] and puts that price in the bill box.
  void _price() {
    final actions = ref.read(sessionActionsProvider);
    final booked =
        actions.endSummary(_session, widget.active.segments, at: _endAt);
    final whole = actions.endSummary(_session, widget.active.segments,
        at: _endAt, chargeOvertime: true);
    _overtimePaise = whole.total.value - booked.total.value;
    _bill = _chargeOvertime ? whole : booked;
    _billCtrl.text = paiseToRupeeInput(_bill.total.value);
  }

  /// The bill amount typed; null while it is not an amount.
  int? get _typedBill => parseRupeesToPaise(_billCtrl.text);

  bool get _billInvalid =>
      _typedBill == null || _typedBill! > _bill.total.value;

  /// The bill End records: the price, or the lowered amount as the server
  /// rounds it.
  int get _finalBill => ref
      .read(sessionActionsProvider)
      .loweredBill(_session, _bill, _billInvalid ? null : _typedBill)
      .billedPaise;

  /// The amount received follows the bill.
  void _followBill() {
    final due = _finalBill - _collected();
    _amountCtrl.text = due > 0 ? paiseToRupeeInput(due) : '';
  }

  /// Staff set the real end (e.g. the timer ran on): between the current
  /// segment's start and now (SessionActions.pickedEnd).
  Future<void> _pickEnd() async {
    final toast = AppToast.of(context);
    final shown = IstTime.fromUtc(_endAt);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: shown.hour, minute: shown.minute),
    );
    if (t == null || !mounted) return;
    final picked = ref
        .read(sessionActionsProvider)
        .pickedEnd(_session, widget.active.segments, t.hour, t.minute);
    if (picked.isErr) {
      toast.failure(picked.failureOrNull!);
      return;
    }
    setState(() {
      _endAt = picked.valueOrNull!;
      _endPicked = true;
      _price();
      _followBill();
    });
  }

  /// Money already taken against this session while it ran (Take payment).
  int _collected() =>
      (ref.read(paymentsForSessionProvider(_session.id)).value ?? const [])
          .fold<int>(0, (sum, p) => sum + p.amountPaise);

  bool _prefilled = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _billCtrl.dispose();
    _waiveReasonCtrl.dispose();
    _endReasonCtrl.dispose();
    super.dispose();
  }

  /// A waive writes money off: it is never recorded without a reason.
  bool get _waiveReasonMissing =>
      _waived && _waiveReasonCtrl.text.trim().isEmpty;

  /// An earlier end lowers the bill: it is never recorded without a reason.
  bool get _endReasonMissing =>
      _endPicked && _endReasonCtrl.text.trim().isEmpty;

  /// Exact paise for what is typed (never via a double); 0 when empty.
  int get _paidPaise => parseRupeesToPaise(_amountCtrl.text) ?? 0;

  /// Text that is not a rupee amount: End is held back rather than ending the
  /// session as if nothing had been paid.
  bool get _amountInvalid =>
      !_waived &&
      _amountCtrl.text.trim().isNotEmpty &&
      parseRupeesToPaise(_amountCtrl.text) == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Settle what is still due: an advance taken while the session ran is
    // already in the till and must not be collected (or counted) again.
    final payments =
        ref.watch(paymentsForSessionProvider(_session.id)).value;
    final collected =
        (payments ?? const []).fold<int>(0, (sum, p) => sum + p.amountPaise);
    final billed = _finalBill - collected;
    if (!_prefilled && payments != null) {
      _prefilled = true;
      _amountCtrl.text = billed > 0 ? paiseToRupeeInput(billed) : '';
    }
    final paid = _paidPaise;
    final change = paid - billed;
    final customer = ref.watch(customerByIdProvider(_session.customerId)).value;
    final resources = <String, String>{
      for (final r in ref.watch(resourcesProvider).value ?? const []) r.id: r.name,
    };
    final games = <String, String>{
      for (final g in ref.watch(allGamesProvider).value ?? const []) g.id: g.name,
    };

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: ListView(
        children: [
          Text('End session', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(customer?.displayName ?? '', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            key: const ValueKey('end-time'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Ended at'),
            subtitle: const Text('Tap to change if the timer ran on'),
            trailing: Text(IstTime.format12(_endAt),
                style: theme.textTheme.titleMedium),
            onTap: _saving ? null : _pickEnd,
          ),
          if (_endPicked)
            TextField(
              key: const ValueKey('end-reason'),
              controller: _endReasonCtrl,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Why did it end earlier?',
                helperText: 'The owner sees it with the bill before and after',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          _BillCard(bill: _bill, resources: resources, games: games),
          if (_endAt.isAfter(_session.scheduledEndAt)) ...[
            const SizedBox(height: AppSpacing.sm),
            OvertimeChoice(
              scheduledEnd: _session.scheduledEndAt,
              over: _endAt.difference(_session.scheduledEndAt),
              extraPaise: _overtimePaise,
              charge: _chargeOvertime,
              onChanged: (v) => setState(() {
                _chargeOvertime = v;
                _price();
                _followBill();
              }),
            ),
          ],
          if (_bill.isIncomplete) ...[
            const SizedBox(height: AppSpacing.sm),
            _UnpricedWarning(bill: _bill, resources: resources),
          ],
          const SizedBox(height: AppSpacing.sm),
          BorrowedPadsNotice(
            sessionRef: Controller.sessionRef(_session.id),
            returning: _returning,
            onToggle: (id, on) => setState(
                () => on ? _returning.add(id) : _returning.remove(id)),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('bill-amount'),
            controller: _billCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              labelText: 'Bill amount (₹)',
              helperText: !_billInvalid && _finalBill != _bill.total.value
                  ? 'Charged ${Paise(_finalBill).display} instead of ${_bill.total.display}'
                  : 'Lower it if the price is off',
              border: const OutlineInputBorder(),
              prefixText: '₹ ',
              errorText: _billCtrl.text.trim().isNotEmpty && _typedBill == null
                  ? rupeeInputError
                  : _typedBill != null && _typedBill! > _bill.total.value
                      ? 'Cannot be more than ${_bill.total.display}'
                      : null,
            ),
            onChanged: (_) => setState(_followBill),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Payment', style: theme.textTheme.labelLarge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Waive (complimentary)'),
            value: _waived,
            onChanged: (v) => setState(() => _waived = v),
          ),
          if (_waived)
            TextField(
              key: const ValueKey('waive-reason'),
              controller: _waiveReasonCtrl,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Reason for waiving',
                helperText: 'The owner sees it with the amount written off',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          if (!_waived) ...[
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final m in ref.watch(offeredPaymentMethodsProvider))
                  ChoiceChip(
                    label: Text(_methodLabel(m)),
                    selected: _offered(_method) == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                labelText: 'Amount received (₹)',
                border: const OutlineInputBorder(),
                prefixText: '₹ ',
                errorText: _amountInvalid ? rupeeInputError : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (collected != 0)
              Text('Already collected ${Paise(collected).display} · '
                  'due now ${Paise(billed < 0 ? 0 : billed).display}',
                  style: theme.textTheme.bodySmall),
            _StatusLine(billed: billed, paid: paid, change: change),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed:
                _saving || _amountInvalid || _waiveReasonMissing ||
                        _endReasonMissing ||
                        (!_waived && _billInvalid)
                    ? null
                    : _confirm,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_saving ? 'Saving…' : 'End & record'),
          ),
        ],
      ),
    );
  }

  /// Borrowed pads ticked as walked back; recorded once the session ends.
  final Set<String> _returning = {};

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    final toast = AppToast.of(context);
    final actions = ref.read(sessionActionsProvider);
    final end = await actions.end(_session, widget.active.segments,
        markWaived: _waived,
        waiveReason: _waived ? _waiveReasonCtrl.text : null,
        billPaise: _waived ? null : _typedBill,
        chargeOvertime: _chargeOvertime,
        at: _endAt,
        endPicked: _endPicked,
        endReason: _endPicked ? _endReasonCtrl.text : null);
    if (end.isErr) {
      if (mounted) setState(() => _saving = false);
      toast.failure(end.failureOrNull!);
      return;
    }
    // The session no longer holds its pads: record the ticked returns.
    final notReturned = _returning.isEmpty
        ? 0
        : _returning.length - await returnPadsHome(ref, _returning);

    final billed = _finalBill - _collected();
    String message = 'Session ended';
    if (!_waived && _paidPaise > 0 && billed > 0) {
      final record = _paidPaise >= billed ? billed : _paidPaise;
      final paid = await actions.recordPayment(RecordPaymentCommand(
        sessionId: _session.id,
        amountPaise: record,
        method: _offered(_method),
      ));
      final change = _paidPaise - billed;
      if (paid.isErr) {
        // The session IS ended; only the money did not go in. Say so plainly
        // so nobody believes it was collected.
        message = 'Ended, but the payment was not recorded: '
            '${paid.failureOrNull!.display}';
      } else if (change > 0) {
        message = 'Paid. Return ${Paise(change).display} change.';
      } else if (_paidPaise < billed) {
        message = 'Partial. ${Paise(billed - _paidPaise).display} pending.';
      } else {
        message = 'Paid in full.';
      }
    } else if (_waived) {
      message = 'Session waived (complimentary).';
    } else if (billed <= 0) {
      message = billed < 0
          ? 'Paid in advance. ${Paise(-billed).display} more than the bill '
              'was collected; refund it if it is owed back.'
          : 'Paid in full.';
    } else {
      message = 'Ended. ${Paise(billed).display} pending.';
    }

    if (notReturned > 0) {
      message = '$message $notReturned pad${notReturned == 1 ? ' was' : 's were'} '
          'not marked returned; mark ${notReturned == 1 ? 'it' : 'them'} on the controller board.';
    }
    if (mounted) Navigator.of(context).pop();
    toast.show(message,
        kind: message.startsWith('Ended, but') ? ToastKind.error : ToastKind.success);
  }

  String _methodLabel(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.upi => 'UPI',
        PaymentMethod.card => 'Card',
        PaymentMethod.other => 'Other',
      };
}

/// Some time played could not be priced, so the total below is short. Staff
/// are told rather than handing over an under-stated bill (brief §12).
class _UnpricedWarning extends StatelessWidget {
  const _UnpricedWarning({required this.bill, required this.resources});
  final SegmentBill bill;
  final Map<String, String> resources;

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: arena.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: arena.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: arena.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This total is incomplete',
                  style: ArenaType.label.copyWith(color: arena.warning),
                ),
                const SizedBox(height: 2),
                for (final u in bill.unpriced)
                  Text(
                    '${resources[u.segment.resourceId] ?? u.segment.resourceId}'
                    ' · ${u.segment.activityCode}'
                    '${u.segment.controllerCount == null ? '' : ' · ${u.segment.controllerCount} ctrl'}'
                    ' — ${u.reason}',
                    style: ArenaType.caption.copyWith(color: arena.text),
                  ),
                const SizedBox(height: 2),
                Text(
                  'The session\'s prices were fixed when it started, so a rate added '
                  'now does not apply to this bill.',
                  style: ArenaType.caption.copyWith(color: arena.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Played past the booked end: how long, what it would add, and the staff's
/// choice to bill it (off: the booked time only). Used by the End sheet. The
/// actual end is stored either way.
class OvertimeChoice extends StatelessWidget {
  const OvertimeChoice({
    super.key,
    required this.scheduledEnd,
    required this.over,
    required this.extraPaise,
    required this.charge,
    required this.onChanged,
  });

  final DateTime scheduledEnd;
  final Duration over;
  final int extraPaise;
  final bool charge;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arena = context.arena;
    return Container(
      key: const ValueKey('end-overtime'),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: arena.warning),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Played ${formatMinutesLabel(over)} past the booked end '
              '(${IstTime.format12(scheduledEnd)})',
              style: theme.textTheme.labelLarge),
          SwitchListTile(
            key: const ValueKey('charge-overtime'),
            contentPadding: EdgeInsets.zero,
            title: Text('Charge overtime (+${Paise(extraPaise).display})'),
            subtitle: Text(charge
                ? 'The whole time played is billed'
                : 'Only the booked time is billed'),
            value: charge,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.resources, required this.games});
  final SegmentBill bill;
  final Map<String, String> resources;
  final Map<String, String> games;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = AppTextStyles.mono(theme.textTheme.bodyMedium!);
    // Lines show their exact amounts and cash rounding is applied once to the
    // total, so it gets its own line (as in the dashboard's Sales) and the
    // lines always add up to the total.
    final rounding = bill.total.value - bill.subtotal.value;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in bill.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text([
                          resources[line.segment.resourceId] ?? line.segment.resourceId,
                          line.segment.activityCode,
                          if (line.segment.controllerCount != null)
                            '${line.segment.controllerCount}🎮',
                          if (line.segment.gameId != null)
                            (games[line.segment.gameId] ?? 'Game'),
                        ].join(' · '), style: theme.textTheme.bodyMedium),
                        Text(
                          '${IstTime.format12(line.quote.segments.isEmpty ? line.segment.startedAt : line.quote.segments.first.interval.start)} · '
                          '${formatMinutesLabel(Duration(seconds: line.quote.playedSeconds))}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(line.quote.subtotal.display, style: mono),
                ],
              ),
            ),
          if (rounding != 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                key: const ValueKey('bill-rounding'),
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rounding', style: theme.textTheme.bodyMedium),
                  Text(
                      rounding < 0
                          ? '−${Paise(-rounding).display}'
                          : Paise(rounding).display,
                      style: mono),
                ],
              ),
            ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: theme.textTheme.titleMedium),
              Text(bill.total.display, style: AppTextStyles.amount(context)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.billed, required this.paid, required this.change});
  final int billed;
  final int paid;
  final int change;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (paid <= 0) {
      text = 'Pending ${Paise(billed).display}';
    } else if (change > 0) {
      text = 'Change to return: ${Paise(change).display}';
    } else if (paid < billed) {
      text = 'Pending ${Paise(billed - paid).display}';
    } else {
      text = 'Paid in full';
    }
    return Text(text, style: Theme.of(context).textTheme.titleSmall);
  }
}
