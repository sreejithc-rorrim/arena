import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/data/local/controller_allocator.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/mappers.dart';
import 'package:arena_ops/data/sync/sync_recorder.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/repositories/controller_allocation_reader.dart';
import 'package:arena_ops/domain/repositories/controller_inventory_writer.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// The state the owner dashboard shows for a physical pad (brief §7). The
/// stored statuses are usable/faulty/missing/retired/unavailable; `available`
/// and `inUse` are DERIVED from whether the pad has an open allocation.
enum PadState { available, inUse, faulty, missing, retired, unavailable }

/// One physical pad as the owner sees it: its stored record, its derived state,
/// and (when in use) the open allocation that says who/what it is on.
class PadView {
  const PadView({required this.controller, required this.state, this.allocation});
  final Controller controller;
  final PadState state;
  final ControllerAllocationRow? allocation;

  bool get inUse => state == PadState.inUse;

  /// Away from its home station — borrowed/relocated (brief §5, §7).
  bool get borrowed => controller.currentResourceId != controller.homeResourceId;

  /// Where the pad physically is now (its current station).
  String get locationResourceId => controller.currentResourceId;
}

/// One station as the owner sees it.
class StationView {
  const StationView({
    required this.id,
    required this.name,
    required this.status,
    required this.currentMode,
    required this.inUseControllers,
    required this.usableControllers,
  });
  final String id;
  final String name;
  final String status;
  final String? currentMode;
  final int inUseControllers;
  final int usableControllers;
}

/// The owner's at-a-glance resource + controller board (brief §7). Totals
/// count each physical pad ONCE: `inUse` is pads with an open allocation,
/// `available` is usable pads with none, and `total` excludes retired pads.
class ControllerDashboard {
  const ControllerDashboard({
    required this.pads,
    required this.stations,
    required this.total,
    required this.inUse,
    required this.available,
  });
  final List<PadView> pads;
  final List<StationView> stations;
  final int total;
  final int inUse;
  final int available;
}

/// Reads for the owner dashboard, plus the two pad-level write flows that the
/// count-based model never had: MOVING a pad between stations (brief §5) and
/// LOCKING a dual-capability station to one mode (RIFT PS5/VR, brief §1).
/// Allocation itself happens inside the session repository via
/// [ControllerAllocator]; this repository is the owner-facing view + inventory.
class LocalControllerAllocationRepository
    implements ControllerAllocationReader, ControllerInventoryWriter {
  LocalControllerAllocationRepository(this._db,
      [this._clock = const SystemClock(), this._sync]);
  final AppDatabase _db;
  final Clock _clock;

  /// Cloud mode only (see SyncRecorder). Null in local-only mode.
  final SyncRecorder? _sync;
  static const _uuid = Uuid();

  ControllerAllocator get allocator => ControllerAllocator(_db, _uuid);

  /// Every currently-active allocation (one row per pad in use).
  Future<List<ControllerAllocationRow>> openAllocations() =>
      (_db.select(_db.controllerAllocations)..where((t) => t.endedAt.isNull())).get();

  OpenPadAllocation _toOpen(ControllerAllocationRow a) => OpenPadAllocation(
        controllerId: a.controllerId,
        resourceId: a.resourceId,
        sessionId: a.sessionId,
        segmentId: a.segmentId,
      );

  @override
  Future<List<OpenPadAllocation>> openPadAllocations() async =>
      (await openAllocations()).map(_toOpen).toList();

  @override
  Stream<List<OpenPadAllocation>> watchOpenPadAllocations() =>
      (_db.select(_db.controllerAllocations)..where((t) => t.endedAt.isNull()))
          .watch()
          .map((rows) => rows.map(_toOpen).toList());

  Future<List<ControllerAllocationRow>> allocationsForController(String id) =>
      (_db.select(_db.controllerAllocations)
            ..where((t) => t.controllerId.equals(id))
            ..orderBy([(t) => OrderingTerm(expression: t.startedAt)]))
          .get();

  /// Move a pad to another station (brief §5). The pad's physical location
  /// ([ControllerRow.currentResourceId]) is tracked SEPARATELY from any active
  /// allocation, so this only changes where the pad is — it never ends a
  /// session. A loan records where to return it and (optionally) which session
  /// owes the return; a permanent move re-homes it; returnHome sends it back.
  @override
  Future<Result<void>> moveController({
    required String controllerId,
    required String toResourceId,
    required ControllerMoveKind kind,
    String? loanSessionRef,
  }) async {
    final pad = await (_db.select(_db.controllers)
          ..where((t) => t.id.equals(controllerId)))
        .getSingleOrNull();
    if (pad == null) {
      return const Err(Failure(message: 'Controller not found.', code: 'not_found'));
    }
    // A pad a running session holds is in a player's hands: walking it to
    // another station would split its location from its allocation. Change
    // that session's controllers (or end it) first; the session flows move
    // pads themselves, inside their own transaction.
    if ((await allocator.openForController(controllerId)).isNotEmpty) {
      return Err(Failure(
        message: '${pad.label} is in use by a running session.',
        fix: 'Change that session\'s controllers or end it, then move '
            '${pad.label}.',
        code: 'controller_in_use',
      ));
    }
    final now = _clock.now();
    final companion = switch (kind) {
      ControllerMoveKind.loan => ControllersCompanion(
          currentResourceId: Value(toResourceId),
          loanReturnTo: Value(pad.homeResourceId),
          loanSessionRef: Value(loanSessionRef),
          updatedAt: Value(now),
        ),
      ControllerMoveKind.permanent => ControllersCompanion(
          currentResourceId: Value(toResourceId),
          homeResourceId: Value(toResourceId),
          loanReturnTo: const Value(null),
          loanSessionRef: const Value(null),
          updatedAt: Value(now),
        ),
      ControllerMoveKind.returnHome => ControllersCompanion(
          currentResourceId: Value(pad.homeResourceId),
          loanReturnTo: const Value(null),
          loanSessionRef: const Value(null),
          updatedAt: Value(now),
        ),
    };
    final to = switch (kind) {
      ControllerMoveKind.returnHome => pad.homeResourceId,
      _ => toResourceId,
    };
    await _db.transaction(() async {
      await (_db.update(_db.controllers)
            ..where((t) => t.id.equals(controllerId)))
          .write(companion);
      // Location history: only a real move is recorded (same-place is a no-op
      // for the timeline, e.g. "return home" on a pad already home).
      ControllerMoveRow? move;
      if (to != pad.currentResourceId) {
        move = await allocator.recordMove(
          controllerId: controllerId,
          from: pad.currentResourceId,
          to: to,
          kind: kind,
          sessionRef: kind == ControllerMoveKind.loan ? loanSessionRef : null,
          at: now,
          now: now,
        );
      }
      await _sync?.record(
        kind: 'controller.move',
        entityType: 'controller',
        entityId: controllerId,
        payload: {
          'controller_id': controllerId,
          'kind': kind.code,
          'to_resource_id': to,
          'session_ref': kind == ControllerMoveKind.loan ? loanSessionRef : null,
          'at': Wire.at(now),
          'move_id': move?.id,
        },
      );
    });
    return const Ok(null);
  }

  /// A pad's location history, oldest first.
  Future<List<ControllerMoveRow>> movesForController(String id) =>
      (_db.select(_db.controllerMoves)
            ..where((t) => t.controllerId.equals(id))
            ..orderBy([(t) => OrderingTerm(expression: t.movedAt)]))
          .get();

  /// Lock a dual-capability station (RIFT) to one activity, or clear the lock
  /// with [mode] = null (brief §1). Refused while the station has an open
  /// occupant, so a mode flip can never strand a running session.
  @override
  Future<Result<void>> setResourceMode(String resourceId, String? mode) async {
    final openSeg = await (_db.select(_db.sessionSegments)
          ..where((t) => t.resourceId.equals(resourceId) & t.endedAt.isNull()))
        .getSingleOrNull();
    if (openSeg != null) {
      return const Err(Failure(
        message: 'That station is in use.',
        fix: 'End the current session before changing its mode.',
        code: 'mode_switch_busy',
      ));
    }
    await _db.transaction(() async {
      await (_db.update(_db.resources)..where((t) => t.id.equals(resourceId)))
          .write(ResourcesCompanion(currentMode: Value(mode)));
      await _sync?.record(
        kind: 'resource.set_mode',
        entityType: 'catalog',
        entityId: resourceId,
        payload: {'id': resourceId, 'mode': mode},
      );
    });
    return const Ok(null);
  }

  /// The owner dashboard (brief §7): every pad with its derived state and what
  /// it is on, every station with its live counts, and reconciled totals.
  Future<ControllerDashboard> dashboard() async {
    final pads = await (_db.select(_db.controllers)
          ..orderBy([(t) => OrderingTerm(expression: t.label)]))
        .get();
    final open = await openAllocations();
    final openByController = <String, ControllerAllocationRow>{
      for (final a in open) a.controllerId: a,
    };
    final resources = await (_db.select(_db.resources)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();

    final views = <PadView>[];
    for (final p in pads) {
      final status = ControllerStatus.fromCode(p.status);
      final alloc = openByController[p.id];
      // An open allocation takes precedence over the stored status, so a pad
      // flagged faulty mid-session still reads "in use" here AND in the station
      // count — the two never disagree, and in-use == count of open allocations.
      final state = alloc != null
          ? PadState.inUse
          : switch (status) {
              ControllerStatus.faulty => PadState.faulty,
              ControllerStatus.missing => PadState.missing,
              ControllerStatus.retired => PadState.retired,
              ControllerStatus.unavailable => PadState.unavailable,
              ControllerStatus.usable => PadState.available,
            };
      views.add(PadView(
          controller: controllerFromRow(p), state: state, allocation: alloc));
    }

    final stations = <StationView>[
      for (final r in resources)
        StationView(
          id: r.id,
          name: r.name,
          status: r.status,
          currentMode: r.currentMode,
          // Pads in use AT this station come from the open allocation's
          // resource_id (where used), not the pad's home — a borrowed pad
          // counts at the station it is being used at.
          inUseControllers: open.where((a) => a.resourceId == r.id).length,
          usableControllers: pads
              .where((p) =>
                  p.currentResourceId == r.id &&
                  ControllerStatus.fromCode(p.status).isUsable)
              .length,
        ),
    ];

    // Each pad counted once: total excludes retired; in-use = open allocations;
    // available = usable with no open allocation.
    final total =
        views.where((v) => v.controller.status != ControllerStatus.retired).length;
    final inUse = views.where((v) => v.state == PadState.inUse).length;
    final available = views.where((v) => v.state == PadState.available).length;

    return ControllerDashboard(
      pads: views,
      stations: stations,
      total: total,
      inUse: inUse,
      available: available,
    );
  }
}
