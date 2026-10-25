/// Add a missed bill: a single session that was played but never started in
/// the app. Pick the customer, station, type, game and controllers, the date and
/// times, how it was paid, and say why. The server prices it on the current
/// price list (shown before saving), adds it already ended and paid in full,
/// and audits the comment. Online only.
library;

import 'dart:async';

import 'package:arena_ops/app/controllers/bill_edit_actions.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/app/providers/my_bills_providers.dart';
import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/core/widgets/app_toast.dart';
import 'package:arena_ops/core/widgets/arena_segmented.dart';
import 'package:arena_ops/core/widgets/confirm_dialog.dart';
import 'package:arena_ops/domain/bills/my_bill.dart';
import 'package:arena_ops/domain/entities/activity.dart';
import 'package:arena_ops/domain/entities/customer.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:arena_ops/features/new_session/presentation/customer_picker_sheet.dart';
import 'package:arena_ops/features/new_session/presentation/game_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

Future<void> showAddMissedBillSheet(
  BuildContext context, {
  required IstDate day,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => AddMissedBillSheet(day: day),
);

class AddMissedBillSheet extends ConsumerStatefulWidget {
  const AddMissedBillSheet({super.key, required this.day});

  /// The day the Bills list shows: the bill's date to start with.
  final IstDate day;

  @override
  ConsumerState<AddMissedBillSheet> createState() => _AddMissedBillSheetState();
}

class _AddMissedBillSheetState extends ConsumerState<AddMissedBillSheet> {
  Customer? _customer;
  Resource? _station;
  String? _activity;
  String? _gameId;
  String? _gameName;
  int? _controllers;
  late IstDate _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  PaymentMethod? _method;
  final _comment = TextEditingController();

  Result<int>? _quote;
  bool _quoting = false;
  int _quoteToken = 0;
  bool _busy = false;
  Failure? _failure;

  /// Kept to resend with the same ids after a dropped connection.
  MissedBillCommand? _unsent;

  @override
  void initState() {
    super.initState();
    _date = widget.day;
    final now = IstTime.fromUtc(ref.read(clockProvider).now());
    final today = _date == now.date;
    // Today: the hour that just ended; another day: an evening hour.
    final endHour = today ? now.hour : 19;
    _end = TimeOfDay(hour: endHour, minute: 0);
    _start = TimeOfDay(hour: (endHour + 23) % 24, minute: 0);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  /// Start and end as instants; an end at or before the start is the next day.
  (DateTime, DateTime) get _window {
    final start = IstTime(
      _date.year,
      _date.month,
      _date.day,
      _start.hour,
      _start.minute,
    ).toUtc();
    var end = IstTime(
      _date.year,
      _date.month,
      _date.day,
      _end.hour,
      _end.minute,
    ).toUtc();
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return (start, end);
  }

  List<String> _typesFor(Resource r, List<Activity> activities) {
    final active = [
      for (final a in activities)
        if (a.active) a.code,
    ];
    if (r.activityCodes.isEmpty) return active;
    return [
      for (final c in r.activityCodes)
        if (active.contains(c)) c,
    ];
  }

  Activity? _activityOf(List<Activity> activities) {
    for (final a in activities) {
      if (a.code == _activity) return a;
    }
    return null;
  }

  bool _ready(Activity? a) =>
      _station != null &&
      a != null &&
      (!a.usesControllers || _controllers != null);

  void _changed() {
    _unsent = null;
    _failure = null;
    unawaited(_requote());
  }

  Future<void> _requote() async {
    final activities = ref.read(activitiesProvider).value ?? const [];
    final a = _activityOf(activities);
    final token = ++_quoteToken;
    if (!_ready(a)) {
      setState(() {
        _quote = null;
        _quoting = false;
      });
      return;
    }
    setState(() => _quoting = true);
    final (start, end) = _window;
    final res = await ref
        .read(myBillsRepositoryProvider)
        .quote(
          resourceId: _station!.id,
          activityCode: a!.code,
          controllerCount: a.usesControllers ? _controllers : null,
          from: start,
          to: end,
        );
    if (!mounted || token != _quoteToken) return;
    setState(() {
      _quote = res;
      _quoting = false;
    });
  }

  Future<void> _pickDate() async {
    final today = IstDate.fromUtc(ref.read(clockProvider).now());
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(today.year - 2, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = IstDate(picked.year, picked.month, picked.day));
    _changed();
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked == null || !mounted) return;
    setState(() => start ? _start = picked : _end = picked);
    _changed();
  }

  Future<void> _pickCustomer() async {
    final c = await showCustomerPicker(context);
    if (c == null || !mounted) return;
    setState(() {
      _customer = c;
      _unsent = null;
    });
  }

  Future<void> _pickGame() async {
    final g = await showGamePicker(
      context,
      resourceId: _station!.id,
      resourceName: _station!.name,
    );
    if (g == null || !mounted) return;
    setState(() {
      _gameId = g.id;
      _gameName = g.name;
      _unsent = null;
    });
  }

  void _setStation(Resource r, List<Activity> activities) {
    final types = _typesFor(r, activities);
    setState(() {
      _station = r;
      _activity = types.contains(_activity)
          ? _activity
          : (types.length == 1 ? types.first : null);
      _gameId = null;
      _gameName = null;
      _controllers = null;
    });
    _changed();
  }

  Failure? _missing(Activity? a) {
    if (_customer == null) {
      return const Failure(
        message: 'Pick the customer.',
        fix: 'Search, add, or choose walk-in.',
        code: 'invalid_payload',
      );
    }
    if (!_ready(a)) {
      return const Failure(
        message: 'Pick the station, type and controllers.',
        fix: 'The price needs all three.',
        code: 'invalid_payload',
      );
    }
    if (_quote?.valueOrNull == null) {
      return const Failure(
        message: 'Wait for the price.',
        fix: 'It shows once the details are picked.',
        code: 'invalid_payload',
      );
    }
    if (_comment.text.trim().isEmpty) {
      return const Failure(
        message: 'Say why the bill is added later.',
        fix: 'Add a short comment.',
        code: 'reason_required',
      );
    }
    return null;
  }

  Future<void> _save(List<PaymentMethod> methods) async {
    final activities = ref.read(activitiesProvider).value ?? const [];
    final a = _activityOf(activities);
    final missing = _missing(a);
    if (missing != null) {
      setState(() => _failure = missing);
      return;
    }
    final method = _method ?? methods.first;
    final (start, end) = _window;
    final total = _quote!.valueOrNull!;
    final actions = ref.read(billEditActionsProvider);
    final cmd =
        _unsent ??
        actions.prepareMissed(
          customerId: _customer!.id,
          resourceId: _station!.id,
          activityCode: a!.code,
          gameId: a.usesGames ? _gameId : null,
          controllerCount: a.usesControllers ? _controllers : null,
          startedAt: start,
          endedAt: end,
          method: method,
          billedPaise: total,
          reason: _comment.text,
        );
    final ok = await confirmAction(
      context,
      title: 'Add this bill for ${Paise(total).display}?',
      message:
          '${_customer!.displayName} on ${_station!.name}, '
          '${IstTime.format12(start)} → ${IstTime.format12(end)}, '
          'paid by ${method.label}. It is recorded as added later, with your comment, '
          'and the owner can see it.',
      confirm: 'Add bill',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final res = await actions.record(cmd);
    if (!mounted) return;
    switch (res) {
      case Ok(value: final billed):
        ref.invalidate(myBillsForDayProvider(IstDate.fromUtc(end)));
        Navigator.of(context).pop();
        showToast(context, 'Bill added: ${Paise(billed).display}.');
      case Err(failure: final f):
        setState(() {
          _busy = false;
          _failure = f;
          _unsent = f.code == 'offline' || f.code == 'retry' ? cmd : null;
        });
        if (f.code == 'price_mismatch') unawaited(_requote());
    }
  }

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    final activities =
        ref.watch(activitiesProvider).value ?? const <Activity>[];
    final stations = ref.watch(resourcesProvider).value ?? const <Resource>[];
    final offered = ref.watch(offeredPaymentMethodsProvider);
    final methods = offered.isEmpty ? PaymentMethod.values : offered;
    final a = _activityOf(activities);
    final types = _station == null
        ? const <String>[]
        : _typesFor(_station!, activities);
    final (start, end) = _window;
    final overnight = IstDate.fromUtc(end) != IstDate.fromUtc(start);

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
                'Add missed bill',
                style: ArenaType.h2.copyWith(color: arena.text),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'For play that was never started in the app. It is priced on today\'s '
                'price list and recorded as paid.',
                style: ArenaType.caption.copyWith(color: arena.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickCustomer,
                icon: const Icon(Icons.person_outline_rounded),
                label: Text(_customer?.displayName ?? 'Pick customer'),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _station?.id,
                decoration: const InputDecoration(labelText: 'Station'),
                items: [
                  for (final r in stations)
                    if (_typesFor(r, activities).isNotEmpty)
                      DropdownMenuItem(value: r.id, child: Text(r.name)),
                ],
                onChanged: _busy
                    ? null
                    : (id) {
                        final r = stations.firstWhere((s) => s.id == id);
                        _setStation(r, activities);
                      },
              ),
              if (types.length > 1) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final t in activities)
                      if (types.contains(t.code))
                        ChoiceChip(
                          label: Text(t.name),
                          selected: _activity == t.code,
                          onSelected: _busy
                              ? null
                              : (_) {
                                  setState(() {
                                    _activity = t.code;
                                    _gameId = null;
                                    _gameName = null;
                                    _controllers = null;
                                  });
                                  _changed();
                                },
                        ),
                  ],
                ),
              ],
              if (a != null && a.usesGames) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _busy || _station == null ? null : _pickGame,
                  icon: const Icon(Icons.videogame_asset_outlined),
                  label: Text(_gameName ?? 'Game (optional)'),
                ),
              ],
              if (a != null && a.usesControllers) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Controllers',
                  style: ArenaType.label.copyWith(color: arena.text),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (var n = 1; n <= 4; n++)
                      ChoiceChip(
                        label: Text('$n'),
                        selected: _controllers == n,
                        onSelected: _busy
                            ? null
                            : (_) {
                                setState(() => _controllers = n);
                                _changed();
                              },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickDate,
                icon: const Icon(Icons.event_rounded),
                label: Text(
                  DateFormat('EEE d MMM yyyy')
                      .format(DateTime.utc(_date.year, _date.month, _date.day)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _pickTime(start: true),
                      child: Text('From ${IstTime.format12(start)}'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _pickTime(start: false),
                      child: Text(
                        'To ${IstTime.format12(end)}${overnight ? ' (next day)' : ''}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _quoting
                    ? 'Working out the price…'
                    : switch (_quote) {
                        null =>
                          'Pick the station and details to see the price.',
                        Ok(value: final t) => 'Price ${Paise(t).display}',
                        Err(failure: final f) => f.message,
                      },
                style: (_quote?.isOk ?? false) && !_quoting
                    ? AppTextStyles.mono(ArenaType.h3)
                          .copyWith(color: arena.text)
                    : ArenaType.body.copyWith(
                        color: _quote is Err ? arena.danger : arena.textMuted,
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Paid by',
                style: ArenaType.label.copyWith(color: arena.text),
              ),
              const SizedBox(height: AppSpacing.xs),
              ArenaSegmented<PaymentMethod>(
                segments: [for (final m in methods) ArenaSegment(m, m.label)],
                value: _method ?? methods.first,
                onChanged: (m) => setState(() {
                  _method = m;
                  _unsent = null;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _comment,
                enabled: !_busy,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comment (required)',
                  hintText: 'Why it was not started in the app',
                ),
                onChanged: (_) => setState(() {
                  _unsent = null;
                  _failure = null;
                }),
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
                  onPressed: _busy ? null : () => _save(methods),
                  child: Text(
                    _busy
                        ? 'Adding…'
                        : _unsent != null
                        ? 'Try again'
                        : 'Add bill',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
