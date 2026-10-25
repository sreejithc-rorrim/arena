import 'package:arena_ops/app/controllers/catalog_actions.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/core/widgets/app_toast.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one controller control for a station: how many, and which physical
/// pads — a single [ControllerChoice], so the count shown is always the pads
/// picked (controller allocation brief §3–§6).
///
///  * Count chips: tapping N picks N free pads AT the station (keeping valid
///    picks; lowering drops the last-picked). Counts above the game's
///    local-player limit are disabled with the reason.
///  * Pad chips at the station: tap to pick/un-pick; the count follows.
///    Faulty / missing / retired / unavailable and in-use pads are greyed with
///    the reason.
///  * "Borrow from another station": free pads elsewhere, picked only by an
///    explicit tap. Picking does NOT move a pad — it is moved (and its
///    origin recorded) when the session starts / the change is applied.
///  * A requested count the arena cannot meet shows as a shortfall with the
///    most available — it is never silently shrunk.
///
/// Whenever the station, game or inventory changes, the choice is re-fitted
/// (`ControllerChoice.reconcile`) and reported via [onChanged], so invalid
/// picks drop out and the count tops up from the station again.
///
/// With no pads on the books at all the arena is untracked and this is just
/// the legacy count chips.
class ControllerChoiceField extends ConsumerStatefulWidget {
  const ControllerChoiceField({
    super.key,
    required this.resourceId,
    required this.resourceName,
    required this.choice,
    required this.onChanged,
    this.keepIds = const {},
    this.exceptOccupantId,
    this.maxCount,
    this.maxReason,
    this.alternatives = const [],
  });

  final String resourceId;
  final String resourceName;
  final ControllerChoice choice;
  final ValueChanged<ControllerChoice> onChanged;

  /// Pads the session being changed already holds.
  final Set<String> keepIds;

  /// The segment being changed (not "someone else" at a station).
  final String? exceptOccupantId;

  /// The game's local-player limit, when a game is chosen.
  final int? maxCount;

  /// Why counts above [maxCount] are disabled ("EA FC supports 4 players").
  final String? maxReason;

  /// Other stations that could host this session right now (free, right
  /// activity / mode / game). When the request is short here, those with
  /// enough free pads of their own are suggested as an alternative to
  /// borrowing — never instead of it.
  final List<Resource> alternatives;

  @override
  ConsumerState<ControllerChoiceField> createState() =>
      _ControllerChoiceFieldState();
}

class _ControllerChoiceFieldState extends ConsumerState<ControllerChoiceField> {
  bool? _showBorrow;

  // The live inputs of the last board, reused for alternative-station counts.
  Set<String> _busy = const {};
  List<OpenPadAllocation> _open = const [];
  List<Controller> _controllers = const [];

  PadBoard? _board() {
    final controllers = ref.watch(controllersProvider);
    final open = ref.watch(openPadAllocationsProvider);
    final segs = ref.watch(openSegmentsProvider);
    final activities = ref.watch(activitiesProvider);
    if (!controllers.hasValue ||
        !open.hasValue ||
        !segs.hasValue ||
        !activities.hasValue) {
      return null;
    }
    final names = <String, String>{
      for (final r in ref.watch(resourcesProvider).value ?? const [])
        r.id: r.name,
    };
    final usesCtrl = {
      for (final a in activities.value!)
        if (a.usesControllers) a.code,
    };
    final occupants = [
      for (final s in segs.value!)
        if (s.id != widget.exceptOccupantId)
          StationOccupant(
            id: s.id,
            resourceId: s.resourceId,
            usesControllers: usesCtrl.contains(s.activityCode),
          ),
    ];
    _busy = PadSelection.untrackedBusyStations(
      occupants: occupants,
      open: open.value!,
    );
    _open = open.value!;
    _controllers = controllers.value!;
    return const PadSelection().board(
      resourceId: widget.resourceId,
      resourceName: widget.resourceName,
      controllers: controllers.value!,
      open: open.value!,
      resourceNames: names,
      busyStations: PadSelection.untrackedBusyStations(
        occupants: occupants,
        open: open.value!,
      ),
      keepIds: widget.keepIds,
    );
  }

  /// The choice re-fitted to the current board (station / game / inventory).
  ControllerChoice _fit(PadBoard board) =>
      widget.choice.reconcile(board, max: widget.maxCount);

  void _emit(ControllerChoice next) {
    if (next != widget.choice) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    final board = _board();
    final caption = ArenaType.caption.copyWith(color: arena.textMuted);

    if (board == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _countChips(null, null),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Checking controllers…',
            key: const ValueKey('pad-loading'),
            style: caption,
          ),
        ],
      );
    }

    // Keep the single source of truth fitted to what is actually free now.
    final fitted = _fit(board);
    if (fitted != widget.choice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emit(_fit(_board() ?? board));
      });
    }
    final choice = fitted;

    if (!board.tracked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _countChips(choice, board),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Controllers aren't in the inventory yet — billed by count.",
            style: caption,
          ),
        ],
      );
    }

    final labels = {
      for (final o in [...board.here, ...board.elsewhere]) o.id: o.label,
    };
    final picked = [
      for (final id in choice.padIds)
        choice.borrowIds.contains(id)
            ? '${labels[id] ?? id} (borrow)'
            : labels[id] ?? id,
    ];
    final inv = board.inventory;
    final shortfall = choice.shortfall;
    final showBorrow =
        _showBorrow ?? (shortfall > 0 || choice.borrowIds.isNotEmpty);
    // This station's own pads that are somewhere else right now — so staff
    // can see why they are not here (in use at another station, lent, …).
    final ownAway = [
      for (final o in board.elsewhere)
        if (o.controller.homeResourceId == board.resourceId) o,
    ];
    // Alternatives: free stations whose own free pads cover the request.
    final need = choice.requested ?? 0;
    final freeAt = PadSelection.freeByStation(
      controllers: _controllers,
      open: _open,
      busyStations: _busy,
    );
    final suggest = [
      for (final r in widget.alternatives)
        if (r.id != board.resourceId && need > 0 && (freeAt[r.id] ?? 0) >= need)
          '${r.name} (${freeAt[r.id]} free there)',
    ];
    final atPorts = choice.padIds.length >= PadSelection.portCapacity;

    void tap(PadOption o) => _emit(choice.toggle(o.id, board));

    Widget padChip(PadOption o) {
      final isPicked = choice.padIds.contains(o.id);
      final canAdd = o.selectable && !atPorts;
      // Pads elsewhere are listed under their station's name; the chip says
      // why one cannot be taken, and whose it is when it is away from home.
      final text = !o.selectable && o.note != null
          ? '${o.label} · ${o.note}'
          : o.awayFromHome && o.needsBorrow
          ? '${o.label} · home ${o.homeName}'
          : o.label;
      return FilterChip(
        key: ValueKey('pad-${o.id}'),
        label: Text(text),
        selected: isPicked,
        onSelected: isPicked || canAdd ? (_) => tap(o) : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _countChips(choice, board),
        const SizedBox(height: AppSpacing.sm),
        Text(
          picked.isEmpty ? 'Selected: none' : 'Selected: ${picked.join(', ')}',
          key: const ValueKey('pad-selected'),
          style: ArenaType.label.copyWith(color: arena.text),
        ),
        Text(
          '${inv.freeHere} free here · ${inv.freeElsewhere} free elsewhere · '
          '${inv.usable} of ${inv.total} usable',
          key: const ValueKey('pad-summary'),
          style: caption,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (board.here.isEmpty)
          Text('No controllers at ${board.resourceName}.', style: caption)
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [for (final o in board.here) padChip(o)],
          ),
        if (ownAway.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '${board.resourceName}\'s own: '
              '${ownAway.map((o) => '${o.label} ${o.selectable ? 'free at ${o.stationName}' : o.note ?? 'at ${o.stationName}'}').join(' · ')}',
              key: const ValueKey('pad-own-away'),
              style: caption,
            ),
          ),
        if (shortfall > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            // The headline only; the full fix is in the bar under the form.
            const PadSelection().check(choice, board)?.message ??
                '$shortfall more needed.',
            key: const ValueKey('pad-shortfall'),
            style: ArenaType.caption.copyWith(color: arena.warning),
          ),
          if (suggest.isNotEmpty)
            Text(
              'Or start at ${suggest.join(' or ')}.',
              key: const ValueKey('pad-suggest'),
              style: caption,
            ),
        ],
        if (widget.maxCount != null && widget.maxReason != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(widget.maxReason!, style: caption),
          ),
        if (board.elsewhere.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            key: const ValueKey('borrow-toggle'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => setState(() => _showBorrow = !showBorrow),
            icon: Icon(
              showBorrow ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(
              'Borrow from another station · '
              '${inv.freeElsewhere} free',
            ),
          ),
          if (showBorrow) ...[
            for (final entry in _byStation(board.elsewhere).entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 64, child: Text(entry.key, style: caption)),
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [for (final o in entry.value) padChip(o)],
                      ),
                    ),
                  ],
                ),
              ),
            if (choice.borrowIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Borrowed controllers move to ${board.resourceName} when '
                  'this is confirmed — carry them over.',
                  style: caption,
                ),
              ),
          ],
        ],
      ],
    );
  }

  static Map<String, List<PadOption>> _byStation(List<PadOption> pads) {
    final out = <String, List<PadOption>>{};
    for (final o in pads) {
      (out[o.stationName] ??= []).add(o);
    }
    return out;
  }

  Widget _countChips(ControllerChoice? choice, PadBoard? board) {
    final max = widget.maxCount;
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final n in const [1, 2, 3, 4])
          ChoiceChip(
            key: ValueKey('ctl-count-$n'),
            label: Text('$n'),
            selected: choice?.requested == n,
            onSelected:
                choice == null || board == null || (max != null && n > max)
                ? null
                : (_) => _emit(
                    board.tracked
                        ? choice.request(n, board)
                        : ControllerChoice.count(n),
                  ),
          ),
      ],
    );
  }
}

/// Records the walk home for each of [ids] (after their session has ended).
/// Returns how many were recorded. Goes through [CatalogActions], which
/// checks the signed-in user may move pads (`start` or `settings`).
Future<int> returnPadsHome(WidgetRef ref, Iterable<String> ids) =>
    ref.read(catalogActionsProvider).returnPadsHome(ids);

/// Labels for pads, for read-only lists ("HEX-1, HEX-2").
String padLabels(Iterable<String> ids, List<Controller> controllers) {
  final byId = {for (final c in controllers) c.id: c.label};
  final out = [for (final id in ids) byId[id] ?? id]..sort();
  return out.join(', ');
}

/// Borrowed pads still away from home, each with a "Returned" button that
/// records the walk back (location history). With [sessionRef] it lists the
/// pads that session borrowed (end/bill sheets); without it, every
/// loaned pad nobody is using right now (the controller board), so a return
/// can still be recorded after the bill sheet has closed.
class BorrowedPadsNotice extends ConsumerWidget {
  const BorrowedPadsNotice({
    super.key,
    this.sessionRef,
    this.returning,
    this.onToggle,
  });

  /// `s:<sessionId>` (see [Controller.sessionRef]); null for
  /// all idle loaned pads.
  final String? sessionRef;

  /// Deferred mode (end / bill sheets): the pads are still held by the
  /// session until it ends, so a return cannot be recorded yet. Each pad gets
  /// a tick instead, and the sheet records the ticked returns right after the
  /// session ends. Null = immediate "Returned" buttons (controller board).
  final Set<String>? returning;
  final void Function(String controllerId, bool returned)? onToggle;

  /// Pads whose "Returned" tap is still being recorded.
  static final Set<String> _inFlight = {};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arena = context.arena;
    final held = {
      for (final a in ref.watch(openPadAllocationsProvider).value ?? const [])
        a.controllerId,
    };
    final borrowed = [
      for (final c
          in ref.watch(controllersProvider).value ?? const <Controller>[])
        if (sessionRef != null
            ? c.loanSessionRef == sessionRef
            : c.loanReturnTo != null &&
                  c.currentResourceId != c.homeResourceId &&
                  !held.contains(c.id))
          c,
    ]..sort((a, b) => a.label.compareTo(b.label));
    if (borrowed.isEmpty) return const SizedBox.shrink();
    final names = <String, String>{
      for (final r in ref.watch(resourcesProvider).value ?? const [])
        r.id: r.name,
    };
    return Column(
      key: const ValueKey('borrowed-pads'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BORROWED CONTROLLERS',
          style: ArenaType.overline.copyWith(color: arena.textMuted),
        ),
        for (final c in borrowed)
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c.label} → ${returning != null ? 'returned to' : 'return to'} '
                  '${names[c.loanReturnTo ?? c.homeResourceId] ?? c.homeResourceId}',
                  style: ArenaType.caption.copyWith(color: arena.warning),
                ),
              ),
              if (returning != null)
                Checkbox(
                  key: ValueKey('return-${c.id}'),
                  value: returning!.contains(c.id),
                  onChanged: (v) => onToggle?.call(c.id, v ?? false),
                )
              else
                TextButton(
                  key: ValueKey('return-${c.id}'),
                  onPressed: () async {
                    // One return per pad at a time: a double tap records once.
                    if (!_inFlight.add(c.id)) return;
                    final m = AppToast.of(context);
                    try {
                      final r = await ref
                          .read(catalogActionsProvider)
                          .returnHome(c);
                      m.result(r, '${c.label} returned.');
                    } finally {
                      _inFlight.remove(c.id);
                    }
                  },
                  child: const Text('Returned'),
                ),
            ],
          ),
      ],
    );
  }
}
