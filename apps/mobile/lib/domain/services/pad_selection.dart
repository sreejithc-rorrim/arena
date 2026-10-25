/// Physical-controller selection for staff (controller allocation brief §3–§6).
///
/// Three pure pieces, shared by the pickers and the application actions so the
/// screen and the start/switch checks can never disagree:
///
///  * [PadBoard] — the arena inventory as seen from one station: every pad AT
///    the station (with why it can or cannot be picked), every pad ELSEWHERE
///    that could be borrowed, and reconciled counts (total / usable / free
///    globally / free here / free elsewhere). Built from the database rows —
///    never from an assumed "2 per station".
///  * [ControllerChoice] — the ONE source of truth for "how many controllers
///    and which ones". In tracked mode the billed count IS the number of picked
///    pads; a requested count the station cannot meet is held as a visible
///    shortfall that blocks Start, never silently shrunk.
///  * [PadSelection.check] — the friendly pre-flight. The repositories still
///    re-validate inside their transaction (and the one-open-allocation unique
///    index is the last word), so a stale screen cannot allocate a busy pad.
library;

import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:meta/meta.dart';

/// One currently-held pad: which controller, and what is holding it.
@immutable
class OpenPadAllocation {
  const OpenPadAllocation({
    required this.controllerId,
    required this.resourceId,
    this.sessionId,
    this.segmentId,
  });

  final String controllerId;

  /// The station the pad is being used at.
  final String resourceId;
  final String? sessionId;
  final String? segmentId;
}

/// Something occupying a station right now: an open single-session segment.
/// Used to spot stations whose pads are in players' hands WITHOUT being
/// tracked (a count-only session).
@immutable
class StationOccupant {
  const StationOccupant({
    required this.id,
    required this.resourceId,
    required this.usesControllers,
  });

  /// Segment id.
  final String id;
  final String resourceId;
  final bool usesControllers;
}

/// Why a pad can or cannot be picked.
enum PadAvailability {
  /// Usable and not held by anyone.
  free,

  /// Held by the session being changed — may be kept.
  yours,

  /// Held by another open session.
  inUse,

  /// At a station whose count-only session may have it in a player's hands.
  stationBusy,

  /// Stored status is not usable (faulty / missing / retired / unavailable).
  notUsable;

  bool get selectable => this == free || this == yours;
}

/// Where a pad is relative to the station being configured.
enum PadPlace { here, elsewhere }

/// A pad as one station sees it.
@immutable
class PadOption {
  const PadOption({
    required this.controller,
    required this.availability,
    required this.place,
    required this.stationName,
    this.homeName,
    this.heldAt,
    this.note,
  });

  final Controller controller;
  final PadAvailability availability;
  final PadPlace place;

  /// Name of the station the pad is physically at now.
  final String stationName;

  /// Name of the pad's home station (where it belongs / returns to).
  final String? homeName;

  /// When held by an open allocation: the station it is being used at.
  final String? heldAt;

  /// Away from its home station (borrowed or re-homed).
  bool get awayFromHome =>
      controller.currentResourceId != controller.homeResourceId;

  /// Short staff-facing reason when not selectable: "faulty", "in use",
  /// "HEX in use".
  final String? note;

  String get id => controller.id;
  String get label => controller.label;
  bool get selectable => availability.selectable;
  bool get needsBorrow => place == PadPlace.elsewhere;
}

/// Reconciled inventory counts — each physical pad counted once.
@immutable
class PadInventory {
  const PadInventory({
    required this.total,
    required this.usable,
    required this.globallyFree,
    required this.freeHere,
    required this.freeElsewhere,
  });

  /// Every pad on the books except retired ones.
  final int total;

  /// Pads whose stored status is usable.
  final int usable;

  /// Usable pads nobody else holds (and not stuck at a busy count-only
  /// station) — what could be handed out anywhere right now.
  final int globallyFree;

  /// Pickable pads physically at this station.
  final int freeHere;

  /// Pickable pads at other stations (borrow required).
  final int freeElsewhere;
}

/// The inventory as seen from one station.
@immutable
class PadBoard {
  const PadBoard({
    required this.resourceId,
    required this.resourceName,
    required this.here,
    required this.elsewhere,
    required this.inventory,
  });

  final String resourceId;
  final String resourceName;

  /// Every pad physically at the station, sorted by label.
  final List<PadOption> here;

  /// Every non-retired pad at another station, sorted by station then label.
  final List<PadOption> elsewhere;
  final PadInventory inventory;

  /// Allocation is tracked once the arena has any pad on the books. With an
  /// empty inventory the app falls back to the legacy count-only flow.
  bool get tracked => inventory.total > 0;

  PadOption? option(String id) {
    for (final o in here) {
      if (o.id == id) return o;
    }
    for (final o in elsewhere) {
      if (o.id == id) return o;
    }
    return null;
  }

  List<PadOption> get freeHere => [
    for (final o in here)
      if (o.selectable) o,
  ];
  List<PadOption> get freeElsewhere => [
    for (final o in elsewhere)
      if (o.selectable) o,
  ];

  /// Most controllers that could be picked right now (here + borrowable),
  /// capped at the port ceiling.
  int get reachable {
    final n = inventory.freeHere + inventory.freeElsewhere;
    return n < PadSelection.portCapacity ? n : PadSelection.portCapacity;
  }
}

/// Whether a choice tracks physical pads or only a billing count.
enum ControllerMode {
  /// Legacy / untracked: only a count. Validated against free supply when the
  /// arena has an inventory, but no pad is reserved.
  countOnly,

  /// Specific pads. The billed count is the number of picked pads.
  tracked,
}

/// How many controllers, and which physical ones — one value, so the count on
/// screen, the pads reserved and the count billed can never drift apart.
@immutable
class ControllerChoice {
  /// A count with no physical pads (legacy, or an arena without inventory).
  const ControllerChoice.count(this.requested)
    : mode = ControllerMode.countOnly,
      padIds = const [],
      borrowIds = const {};

  /// Specific pads. [requested] is what staff asked for; when it exceeds the
  /// picked pads the difference is a visible shortfall that blocks Start.
  const ControllerChoice.tracked({
    this.requested,
    this.padIds = const [],
    this.borrowIds = const {},
  }) : mode = ControllerMode.tracked;

  /// Nothing chosen yet.
  static const none = ControllerChoice.count(null);

  final ControllerMode mode;
  final int? requested;

  /// Picked pads, in the order they were added (players get them in order).
  final List<String> padIds;

  /// Picked pads that are at another station and will be borrowed (moved
  /// here) only when the session starts / the change is applied. Subset of
  /// [padIds]. Picking alone never moves a pad.
  final Set<String> borrowIds;

  bool get isTracked => mode == ControllerMode.tracked;

  /// The count to bill. Tracked: the number of picked pads (null if none).
  int? get count =>
      isTracked ? (padIds.isEmpty ? null : padIds.length) : requested;

  /// Requested minus picked (tracked only).
  int get shortfall {
    if (!isTracked || requested == null) return 0;
    final s = requested! - padIds.length;
    return s > 0 ? s : 0;
  }

  /// Pads to send to the repository (null when count-only / none).
  List<String>? get padIdsOrNull =>
      isTracked && padIds.isNotEmpty ? padIds : null;
  List<String>? get borrowIdsOrNull =>
      isTracked && borrowIds.isNotEmpty ? borrowIds.toList() : null;

  /// Staff asked for [n] controllers: keep the picks that are still valid
  /// (deterministically dropping the LAST-picked when lowering), then top up
  /// with free pads AT the station in label order. Pads elsewhere are never
  /// added automatically — borrowing is always an explicit tap.
  ControllerChoice request(int n, PadBoard board) {
    final kept = <String>[
      for (final id in padIds)
        if (board.option(id)?.selectable ?? false) id,
    ];
    while (kept.length > n) {
      kept.removeLast();
    }
    for (final o in board.freeHere) {
      if (kept.length >= n) break;
      if (!kept.contains(o.id)) kept.add(o.id);
    }
    return ControllerChoice.tracked(
      requested: n,
      padIds: kept,
      borrowIds: _borrowsIn(kept, board),
    );
  }

  /// Staff tapped a pad: pick or un-pick it.
  ///
  /// Un-picking lowers the count at once. Picking raises it only when the pick
  /// goes beyond what was asked for — while filling a shortfall (asked 4, 2
  /// free here, borrowing the rest) each borrow moves TOWARD the request and
  /// never quietly shrinks it, so Start stays blocked until all 4 are picked.
  ControllerChoice toggle(String id, PadBoard board) {
    final next = [...padIds];
    int? want;
    if (next.contains(id)) {
      next.remove(id);
      want = next.isEmpty ? null : next.length;
    } else {
      final o = board.option(id);
      if (o == null || !o.selectable) return this;
      next.add(id);
      final asked = requested ?? 0;
      want = asked > next.length ? asked : next.length;
    }
    return ControllerChoice.tracked(
      requested: want,
      padIds: next,
      borrowIds: _borrowsIn(next, board),
    );
  }

  /// Re-fit to a new station / game / inventory: keep only picks that are
  /// still valid, cap the request at [max] (the game's local-player limit),
  /// and top up from the station again. A count-only choice becomes tracked
  /// once the arena has an inventory; without one it stays a plain count.
  ControllerChoice reconcile(PadBoard board, {int? max}) {
    var n = requested;
    if (n != null && max != null && n > max) n = max;
    if (!board.tracked) return ControllerChoice.count(n);
    if (n == null) {
      final kept = [
        for (final id in padIds)
          if (board.option(id)?.selectable ?? false) id,
      ];
      return ControllerChoice.tracked(
        padIds: kept,
        borrowIds: _borrowsIn(kept, board),
      );
    }
    return request(n, board);
  }

  static Set<String> _borrowsIn(List<String> ids, PadBoard board) => {
    for (final id in ids)
      if (board.option(id)?.needsBorrow ?? false) id,
  };

  @override
  bool operator ==(Object other) =>
      other is ControllerChoice &&
      other.mode == mode &&
      other.requested == requested &&
      _listEq(other.padIds, padIds) &&
      other.borrowIds.length == borrowIds.length &&
      other.borrowIds.containsAll(borrowIds);

  @override
  int get hashCode => Object.hash(
    mode,
    requested,
    Object.hashAll(padIds),
    Object.hashAllUnordered(borrowIds),
  );

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'ControllerChoice(${mode.name}, requested: $requested, pads: $padIds, '
      'borrow: $borrowIds)';
}

/// Builds boards and checks choices. Pure — no I/O.
class PadSelection {
  const PadSelection();

  /// Hardware ceiling: controller ports on one PS5.
  static const int portCapacity = 4;

  /// Stations whose pads may be in players' hands without being tracked: an
  /// open controller-using segment that holds no allocation.
  static Set<String> untrackedBusyStations({
    required List<StationOccupant> occupants,
    required List<OpenPadAllocation> open,
  }) {
    final holders = <String>{
      for (final a in open)
        if (a.segmentId != null) a.segmentId!,
    };
    return {
      for (final o in occupants)
        if (o.usesControllers && !holders.contains(o.id)) o.resourceId,
    };
  }

  /// Genuinely free pads physically at each station: usable, held by no open
  /// allocation, and not at a station whose count-only session may have them
  /// in hand. For suggesting where else a party could start.
  static Map<String, int> freeByStation({
    required List<Controller> controllers,
    required List<OpenPadAllocation> open,
    Set<String> busyStations = const {},
  }) {
    final held = {for (final a in open) a.controllerId};
    final out = <String, int>{};
    for (final c in controllers) {
      if (!c.status.isUsable || held.contains(c.id)) continue;
      if (busyStations.contains(c.currentResourceId)) continue;
      out[c.currentResourceId] = (out[c.currentResourceId] ?? 0) + 1;
    }
    return out;
  }

  /// The inventory as seen from [resourceId].
  ///
  /// [keepIds] are pads the session being changed already holds (they count
  /// as its own). [busyStations] comes from [untrackedBusyStations].
  PadBoard board({
    required String resourceId,
    required String resourceName,
    required List<Controller> controllers,
    required List<OpenPadAllocation> open,
    Map<String, String> resourceNames = const {},
    Set<String> busyStations = const {},
    Set<String> keepIds = const {},
  }) {
    final held = {for (final a in open) a.controllerId: a};
    String name(String id) =>
        id == resourceId ? resourceName : resourceNames[id] ?? id;
    final here = <PadOption>[];
    final elsewhere = <PadOption>[];
    var total = 0, usable = 0, globallyFree = 0;

    for (final c in controllers) {
      final atHere = c.currentResourceId == resourceId;
      if (c.status != ControllerStatus.retired) total++;
      if (c.status.isUsable) usable++;
      // A written-off pad elsewhere is noise; one standing here is shown
      // (greyed) so staff are not confused by a pad they can see.
      if (!atHere && c.status == ControllerStatus.retired) continue;

      final station = atHere
          ? resourceName
          : resourceNames[c.currentResourceId] ?? c.currentResourceId;
      final holder = held[c.id];
      final heldAt = holder == null ? null : name(holder.resourceId);
      // Availability of the PAD — independent of whether its station is free:
      // a pad can be held by a session at another station (borrowed), and a
      // free station can have none of its own pads on it.
      final (PadAvailability a, String? note) = !c.status.isUsable
          ? (PadAvailability.notUsable, c.status.label.toLowerCase())
          : keepIds.contains(c.id)
          ? (PadAvailability.yours, null)
          : holder != null
          ? (PadAvailability.inUse, 'in use at $heldAt')
          // A count-only session (no pads recorded) may have any pad at its
          // station in a player's hands — never offer those, here or away.
          : busyStations.contains(c.currentResourceId)
          ? (PadAvailability.stationBusy, '$station in use, not tracked')
          : (PadAvailability.free, null);
      if (a.selectable) globallyFree++;
      (atHere ? here : elsewhere).add(
        PadOption(
          controller: c,
          availability: a,
          place: atHere ? PadPlace.here : PadPlace.elsewhere,
          stationName: station,
          homeName: name(c.homeResourceId),
          heldAt: heldAt,
          note: note,
        ),
      );
    }
    here.sort((a, b) => a.label.compareTo(b.label));
    elsewhere.sort((a, b) {
      final s = a.stationName.compareTo(b.stationName);
      return s != 0 ? s : a.label.compareTo(b.label);
    });
    return PadBoard(
      resourceId: resourceId,
      resourceName: resourceName,
      here: here,
      elsewhere: elsewhere,
      inventory: PadInventory(
        total: total,
        usable: usable,
        globallyFree: globallyFree,
        freeHere: here.where((o) => o.selectable).length,
        freeElsewhere: elsewhere.where((o) => o.selectable).length,
      ),
    );
  }

  /// The first problem with [choice] at [board], phrased for the counter, or
  /// null when it can be started / applied.
  Failure? check(
    ControllerChoice choice,
    PadBoard board, {
    int? maxLocalPlayers,
    String? gameName,
    bool requireSupply = true,
  }) {
    final n = choice.requested;
    final station = board.resourceName;
    if (n == null || n <= 0) {
      return const Failure(
        message: 'Choose how many controllers.',
        fix: 'The price depends on the number of controllers.',
        code: 'controllers_required',
      );
    }
    if (n > portCapacity) {
      return Failure(
        message: '$station can hold up to $portCapacity controllers.',
        fix: 'Choose $portCapacity or fewer, or use another system.',
        code: 'controllers_exceeded',
      );
    }
    if (maxLocalPlayers != null && n > maxLocalPlayers) {
      return Failure(
        message:
            '${gameName ?? 'This game'} supports $maxLocalPlayers local '
            'player${maxLocalPlayers == 1 ? '' : 's'}.',
        fix:
            'Choose $maxLocalPlayers controller'
            '${maxLocalPlayers == 1 ? '' : 's'}, or pick another game.',
        code: 'players_exceeded',
      );
    }
    if (!board.tracked) return null; // no inventory: legacy count-only

    if (!choice.isTracked) {
      // A bare count against a tracked inventory: allowed only if the station
      // really has that many free pads — nothing is borrowed without a pick.
      final free = board.inventory.freeHere;
      if (requireSupply && n > free) return _shortage(n, free, board);
      return null;
    }

    final seen = <String>{};
    for (final id in choice.padIds) {
      final o = board.option(id);
      if (o == null) {
        return const Failure(
          message: 'A picked controller is no longer available.',
          fix: 'Pick the controllers again.',
          code: 'controller_missing',
        );
      }
      final pad = o.label;
      if (!seen.add(id)) {
        return Failure(
          message: '$pad is picked twice.',
          fix: 'Give each player a different controller.',
          code: 'controller_duplicate',
        );
      }
      switch (o.availability) {
        case PadAvailability.notUsable:
          return Failure(
            message: '$pad is ${o.note}.',
            fix:
                'Pick a usable controller, or change its status in '
                'Settings → Stations.',
            code: 'controller_unusable',
          );
        case PadAvailability.inUse:
          return Failure(
            message: '$pad is already in use.',
            fix: 'Pick a free controller.',
            code: 'controller_taken',
          );
        case PadAvailability.stationBusy:
          return Failure(
            message: '$pad is at ${o.stationName}, which is in use.',
            fix: "Its controllers may be in players' hands. Pick another.",
            code: 'controller_taken',
          );
        case PadAvailability.free:
        case PadAvailability.yours:
          break;
      }
      if (o.needsBorrow && !choice.borrowIds.contains(id)) {
        return Failure(
          message: '$pad is at ${o.stationName}, not $station.',
          fix: 'Borrow $pad to $station, or pick a controller at $station.',
          code: 'controller_elsewhere',
        );
      }
    }
    if (choice.shortfall > 0) {
      final unpickedHere = [
        for (final o in board.freeHere)
          if (!choice.padIds.contains(o.id)) o,
      ].length;
      if (unpickedHere >= choice.shortfall) {
        // The station can cover it — staff just un-picked too many.
        return Failure(
          message: '$n requested, ${choice.padIds.length} selected.',
          fix: 'Pick ${choice.shortfall} more at $station.',
          code: 'controller_count_mismatch',
        );
      }
      return _shortage(
        n,
        board.inventory.freeHere,
        board,
        picked: choice.padIds.length,
      );
    }
    return null;
  }

  Failure _shortage(int n, int freeHere, PadBoard board, {int? picked}) {
    final station = board.resourceName;
    final have = picked ?? freeHere;
    final elsewhere = board.inventory.freeElsewhere;
    final head = picked == null
        ? '$n controllers needed, only $freeHere free at $station.'
        : '$n requested, $picked selected — only $freeHere free at $station.';
    final orFewer = have > 0 ? ', or choose $have' : '';
    final reachable = board.reachable;
    final fix = elsewhere > 0 && reachable >= n
        ? (picked != null
              ? 'Borrow ${n - have} from another station ($elsewhere free)'
                    '$orFewer.'
              : 'Pick the controllers to borrow them from another station '
                    '($elsewhere free)$orFewer.')
        : reachable > 0
        ? 'Only $reachable free in the whole arena right now — choose '
              '$reachable or wait for one to come free.'
        : 'No controller is free anywhere right now — wait for one to come '
              'free.';
    return Failure(message: head, fix: fix, code: 'controllers_unavailable');
  }
}
