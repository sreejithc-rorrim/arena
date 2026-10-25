import 'package:arena_ops/app/controllers/session_actions.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/time/duration_format.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/core/widgets/app_toast.dart';
import 'package:arena_ops/core/widgets/custom_duration_sheet.dart';
import 'package:arena_ops/domain/entities/activity.dart';
import 'package:arena_ops/domain/entities/customer.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/pricing/pricing_quote.dart';
import 'package:arena_ops/domain/services/session_planner.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';
import 'package:arena_ops/features/controllers/presentation/controller_choice_field.dart';
import 'package:arena_ops/features/new_session/presentation/customer_picker_sheet.dart';
import 'package:arena_ops/features/new_session/presentation/game_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NewSessionScreen extends ConsumerStatefulWidget {
  const NewSessionScreen({super.key, this.initialResource});

  /// Optionally preselect a station the staff tapped on the floor.
  final Resource? initialResource;

  @override
  ConsumerState<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends ConsumerState<NewSessionScreen> {
  NewSessionDraft _draft = NewSessionDraft();
  Customer? _customer;
  String? _gameName;

  /// The chosen game's local-player limit (caps the controller count).
  int? _gameMax;

  /// The last estimate shown, so a change can be called out ("was ₹150").
  int? _shownAmount;
  int? _previousAmount;

  Result<StartPlan>? _preview;
  bool _loadingPreview = false;
  bool _starting = false;
  int _previewToken = 0;

  @override
  void initState() {
    super.initState();
    final r = widget.initialResource;
    if (r != null) {
      _draft = _draft.copyWith(resourceId: r.id, resourceName: r.name);
      // The station's type decides pricing; one it is locked to or its only one.
      final code = r.currentMode ??
          (r.activityCodes.length == 1 ? r.activityCodes.first : null);
      if (code != null) _applyActivityCode(code);
    }
  }

  /// The types a station can start right now: the one it is locked to, else
  /// every active type it offers (several only for a multi-type station such
  /// as RIFT, PS5 or VR).
  static List<String> _typesFor(Resource r, Set<String> activeCodes) {
    final mode = r.currentMode;
    if (mode != null) return activeCodes.contains(mode) ? [mode] : const [];
    return [
      for (final c in r.activityCodes)
        if (activeCodes.contains(c)) c,
    ];
  }

  void _update(NewSessionDraft next) {
    setState(() => _draft = next);
    _recomputePreview();
  }

  void _applyActivityCode(String code) {
    _draft = _draft.copyWith(
      activityCode: code,
      clearGame: true,
      clearControllers: true,
    );
  }

  Future<void> _recomputePreview() async {
    final token = ++_previewToken;
    setState(() => _loadingPreview = true);
    final preview = await ref.read(sessionActionsProvider).previewStart(_draft);
    if (!mounted || token != _previewToken) return;
    setState(() {
      final amount = preview.valueOrNull?.quote.amount.value;
      if (amount != null && amount != _shownAmount) {
        _previousAmount = _shownAmount;
        _shownAmount = amount;
      }
      _preview = preview;
      _loadingPreview = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activities = ref.watch(activitiesProvider).value ?? const [];
    final noun = ref.watch(resourceNounProvider);
    final activeCodes = {
      for (final a in activities)
        if (a.active) a.code,
    };
    final resources = ref.watch(resourcesProvider).value ?? const [];
    final openSegments = ref.watch(openSegmentsProvider).value ?? const [];
    // A STATION is free when no session is on it — whether
    // its own controllers are there is a separate question (they can be
    // borrowed in).
    final occupied = {
      for (final s in openSegments) s.resourceId,
    };

    Activity? activity;
    for (final a in activities) {
      if (a.code == _draft.activityCode) activity = a;
    }

    final playableHere = <String>{
      if (_draft.gameId != null)
        for (final rf
            in ref.watch(resourcesForGameProvider(_draft.gameId!)).value ??
                const [])
          if (rf.status.isPlayable) rf.resource.id,
    };
    // Every free station that can start something; its type comes with it.
    final availableResources = resources
        .where((r) =>
            r.status == ResourceStatus.available &&
            !occupied.contains(r.id) &&
            _typesFor(r, activeCodes).isNotEmpty)
        .toList();
    // Stations the chosen type can move to (controller borrowing alternatives).
    final sameType = [
      for (final r in availableResources)
        if (_typesFor(r, activeCodes).contains(_draft.activityCode)) r,
    ];
    Resource? station;
    for (final r in resources) {
      if (r.id == _draft.resourceId) station = r;
    }
    final stationTypes =
        station == null ? const <String>[] : _typesFor(station, activeCodes);

    // Steps are numbered as they are shown: Game and Controllers only appear
    // for a station whose type uses them, so a hidden step must not leave a
    // hole in the sequence.
    var step = 0;
    String n(String label) => '${++step} · $label';

    return Scaffold(
      appBar: AppBar(title: const Text('New Session')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Section(
            title: n('Customer'),
            child: OutlinedButton.icon(
              onPressed: () async {
                final c = await showCustomerPicker(context);
                if (c != null) {
                  _customer = c;
                  _update(_draft.copyWith(customerId: c.id));
                }
              },
              icon: const Icon(Icons.person_outline),
              label: Text(_customer?.name ?? 'Select customer'),
            ),
          ),
          _Section(
            title: n(noun.one),
            child: availableResources.isEmpty
                ? Text('No ${noun.many.toLowerCase()} free right now.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          for (final r in availableResources)
                            ChoiceChip(
                              label: Text(r.name),
                              selected: _draft.resourceId == r.id,
                              onSelected: (_) =>
                                  _changeStation(r, _typesFor(r, activeCodes)),
                            ),
                        ],
                      ),
                      // Only a station offering several types (and not locked
                      // to one) asks which: the price depends on it.
                      if (stationTypes.length > 1) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Play as',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            for (final a in activities)
                              if (stationTypes.contains(a.code))
                                ChoiceChip(
                                  label: Text(a.name),
                                  selected: _draft.activityCode == a.code,
                                  onSelected: (_) {
                                    _applyActivityCode(a.code);
                                    _update(_draft);
                                  },
                                ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
          if (activity != null && activity.usesGames)
            _Section(
              title: n('Game'),
              child: OutlinedButton.icon(
                // A game can only be chosen once a station is picked, so we show
                // only games playable on that station (spec §6).
                onPressed: _draft.resourceId == null
                    ? null
                    : () async {
                        final g = await showGamePicker(context,
                            resourceId: _draft.resourceId!,
                            resourceName: _draft.resourceName);
                        if (g != null) {
                          _gameName = g.name;
                          // The controller field re-fits the pads to the
                          // game's local-player limit on its next build.
                          _gameMax = g.maxLocalPlayers;
                          _update(_draft.copyWith(gameId: g.id));
                        }
                      },
                icon: const Icon(Icons.videogame_asset_outlined),
                label: Text(_gameName ??
                    (_draft.resourceId == null
                        ? 'Pick a station first'
                        : 'Select game (optional)')),
              ),
            ),
          if (activity != null && activity.usesControllers)
            _Section(
              title: n('Controllers'),
              child: _draft.resourceId == null
                  ? Text('Pick a station first.',
                      style: Theme.of(context).textTheme.bodySmall)
                  : ControllerChoiceField(
                      alternatives: [
                        for (final r in sameType)
                          if (_draft.gameId == null ||
                              playableHere.contains(r.id))
                            r,
                      ],
                      resourceId: _draft.resourceId!,
                      resourceName: _draft.resourceName ?? _draft.resourceId!,
                      choice: _draft.controllers,
                      maxCount: _gameMax,
                      maxReason: _gameMax == null || _gameMax! >= 4
                          ? null
                          : '${_gameName ?? 'This game'} supports up to '
                              '$_gameMax local player${_gameMax == 1 ? '' : 's'}.',
                      onChanged: (c) =>
                          _update(_draft.copyWith(controllers: c)),
                    ),
            ),
          _Section(
            title: n('Duration'),
            child: Builder(builder: (context) {
              final presets = ref.watch(startPresetsProvider);
              final isCustom = !_draft.openEnded &&
                  _draft.durationMinutes != null &&
                  !presets.contains(_draft.durationMinutes);
              return Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final d in presets)
                    ChoiceChip(
                      label: Text('$d min'),
                      selected: !_draft.openEnded && _draft.durationMinutes == d,
                      onSelected: (_) => _update(
                          _draft.copyWith(durationMinutes: d, openEnded: false)),
                    ),
                  ChoiceChip(
                    label: Text(isCustom
                        ? 'Custom · ${formatMinutesLabel(Duration(minutes: _draft.durationMinutes!))}'
                        : 'Custom'),
                    selected: isCustom,
                    onSelected: (_) async {
                      // Up to a day: rates can be per hour or per day.
                      final mins = await showCustomMinutesSheet(context,
                          initial: _draft.durationMinutes ?? 60, max: 24 * 60);
                      if (mins != null) {
                        _update(_draft.copyWith(
                            durationMinutes: mins, openEnded: false));
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Open'),
                    selected: _draft.openEnded,
                    onSelected: (_) => _update(_draft.copyWith(openEnded: true)),
                  ),
                ],
              );
            }),
          ),
          // Room for the estimate bar (with its breakdown) to sit over.
          const SizedBox(height: 260),
        ],
      ),
      bottomSheet: _PreviewBar(
        preview: _preview,
        loading: _loadingPreview,
        starting: _starting,
        onStart: _start,
        controllerCount:
            (activity?.usesControllers ?? false) ? _draft.controllerCount : null,
        previousAmount: _previousAmount,
        prompt: 'Pick a customer and a ${noun.word}.',
      ),
    );
  }

  /// A new station brings its type: the same type keeps the requested count
  /// and any explicitly borrowed pads (pads picked at the old station drop
  /// out and the field tops up from the new one); another type starts the
  /// game and controllers afresh. A multi-type station keeps the current type
  /// when it offers it, else waits for "Play as".
  void _changeStation(Resource r, List<String> types) {
    final keep = types.contains(_draft.activityCode);
    if (!keep) {
      _gameName = null;
      _gameMax = null;
      if (types.length == 1) {
        _applyActivityCode(types.first);
      } else {
        _draft = _draft.copyWith(
            clearActivity: true, clearGame: true, clearControllers: true);
      }
      _update(_draft.copyWith(resourceId: r.id, resourceName: r.name));
      return;
    }
    final c = _draft.controllers;
    final borrowed = [
      for (final id in c.padIds)
        if (c.borrowIds.contains(id)) id,
    ];
    _update(_draft.copyWith(
      resourceId: r.id,
      resourceName: r.name,
      controllers: c.isTracked
          ? ControllerChoice.tracked(
              requested: c.requested,
              padIds: borrowed,
              borrowIds: borrowed.toSet())
          : c,
    ));
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    final r = await ref.read(sessionActionsProvider).start(_draft);
    if (!mounted) return;
    setState(() => _starting = false);
    r.fold(
      (session) {
        Navigator.of(context).pop(true);
        showToast(context, 'Started ${_customer?.name ?? 'session'}');
      },
      (failure) => showFailure(context, failure),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({
    required this.preview,
    required this.loading,
    required this.starting,
    required this.onStart,
    required this.prompt,
    this.controllerCount,
    this.previousAmount,
  });

  final Result<StartPlan>? preview;
  final String prompt;
  final bool loading;
  final bool starting;
  final VoidCallback onStart;
  final int? controllerCount;
  final int? previousAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = preview?.valueOrNull;
    final failure = preview?.failureOrNull;
    final canStart = plan != null && !starting;

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loading)
                const Text('Calculating price…')
              else if (plan != null)
                _PlanLine(
                  plan: plan,
                  controllerCount: controllerCount,
                  previousAmount: previousAmount,
                )
              else if (failure != null)
                Text(failure.display, style: TextStyle(color: theme.colorScheme.error))
              else
                Text(prompt),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                onPressed: canStart ? onStart : null,
                icon: starting
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow),
                label: Text(starting ? 'Starting…' : 'Start session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanLine extends StatelessWidget {
  const _PlanLine({
    required this.plan,
    this.controllerCount,
    this.previousAmount,
  });
  final StartPlan plan;
  final int? controllerCount;
  final int? previousAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arena = context.arena;
    final q = plan.quote;
    final minutes = q.billedMinutes;
    String rateLine(PricingSegment s) {
      final per = formatPerUnit(s.unitMinutes);
      return '${s.unitPrice.display}/$per × '
          '${formatMinutesLabel(Duration(minutes: s.billedMinutes))} = '
          '${s.amount.display}';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${IstTime.format12(plan.startedAt)} → '
                '${plan.openEnded ? 'close' : IstTime.format12(plan.scheduledEndAt)}',
                style: AppTextStyles.mono(theme.textTheme.bodyMedium!),
              ),
              // Breakdown: duration, controllers, the rate actually applied.
              Text(
                [
                  formatMinutesLabel(Duration(minutes: minutes)),
                  if (controllerCount != null)
                    '$controllerCount controller${controllerCount == 1 ? '' : 's'}',
                ].join(' · '),
                key: const ValueKey('estimate-summary'),
                style: theme.textTheme.bodySmall,
              ),
              // The pricing rule the engine applied (judged at the start),
              // e.g. "Weekday afternoons −20%"; the rate line shows the adjusted price.
              if (q.rule != null)
                Text(q.rule!.summary,
                    key: const ValueKey('estimate-rule'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: arena.primary)),
              for (final s in q.segments)
                Text(rateLine(s),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: arena.textMuted)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(plan.openEnded ? 'Est. to close' : 'Estimated',
                style: theme.textTheme.labelSmall),
            Text(q.amount.display,
                key: const ValueKey('estimate-amount'),
                style: AppTextStyles.amount(context)),
            if (previousAmount != null && previousAmount != q.amount.value)
              Text('was ${Paise(previousAmount!).display}',
                  key: const ValueKey('estimate-was'),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: arena.warning)),
          ],
        ),
      ],
    );
  }
}
