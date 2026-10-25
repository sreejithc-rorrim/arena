import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Thrown inside a session transaction when a specific-controller
/// allocation cannot proceed. The owning repository catches it and returns
/// `Err(failure)`, so a blocked allocation rolls the whole operation back.
class ControllerAllocationException implements Exception {
  ControllerAllocationException(this.failure);
  final Failure failure;
}

/// Allocates SPECIFIC physical controllers to a session and keeps
/// the append-only per-pad timeline (brief §3–§5, §8).
///
/// Every method runs inside the CALLER's transaction, so start / switch / end
/// stay atomic. A pad may be in at most one active allocation: the pre-check
/// here gives a friendly message, and the partial unique index
/// `ux_one_open_allocation_per_controller` is the final guarantee against a
/// racing writer (brief §4, §9). Allocation is INDEPENDENT of the billing
/// `controllerCount` — pricing keeps reading the integer count, untouched.
class ControllerAllocator {
  ControllerAllocator(this._db, this._uuid);
  final AppDatabase _db;
  final Uuid _uuid;

  /// Open (active) allocation rows for one physical pad.
  Future<List<ControllerAllocationRow>> openForController(String controllerId) =>
      (_db.select(_db.controllerAllocations)
            ..where(
                (t) => t.controllerId.equals(controllerId) & t.endedAt.isNull()))
          .get();

  /// Validates and reserves [controllerIds] at [resourceId], inserting one open
  /// allocation row per pad. Throws [ControllerAllocationException] on the first
  /// conflict (unknown / not-usable / not-at-this-station / already-in-use).
  /// [sessionId]+[segmentId] identify what the pad is being used for. Returns
  /// the rows it inserted (their ids travel to the server with the operation).
  Future<List<ControllerAllocationRow>> allocate({
    required String scope, // always 'single'
    String? sessionId,
    String? segmentId,
    required List<String> controllerIds,
    required String resourceId,
    required String resourceName,
    required String activityCode,
    String? gameId,
    required DateTime startedAt,
    required DateTime now,
    String? requestId,
  }) async {
    if (controllerIds.toSet().length != controllerIds.length) {
      throw ControllerAllocationException(const Failure(
        message: 'The same controller was picked twice.',
        fix: 'Choose a different controller for each player.',
        code: 'controller_duplicate',
      ));
    }

    for (final id in controllerIds) {
      final pad = await (_db.select(_db.controllers)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (pad == null) {
        throw ControllerAllocationException(Failure(
          message: 'That controller no longer exists.',
          fix: 'Pick another controller.',
          code: 'controller_missing',
        ));
      }
      final status = ControllerStatus.fromCode(pad.status);
      if (!status.isUsable) {
        throw ControllerAllocationException(Failure(
          message: '${pad.label} is ${status.label.toLowerCase()}.',
          fix: 'Pick a usable controller, or change its status in '
              'Settings → Stations.',
          code: 'controller_unusable',
        ));
      }
      // Location (where the pad physically is) is tracked separately from its
      // active assignment: to use a pad from another station, move it here
      // first (brief §5).
      if (pad.currentResourceId != resourceId) {
        throw ControllerAllocationException(Failure(
          message: '${pad.label} is not at $resourceName.',
          fix: 'Move ${pad.label} to $resourceName first, then allocate it.',
          code: 'controller_elsewhere',
        ));
      }
      if ((await openForController(id)).isNotEmpty) {
        throw ControllerAllocationException(Failure(
          message: '${pad.label} is already in use.',
          fix: 'Pick a free controller.',
          code: 'controller_taken',
        ));
      }
      // Another player on this station without tracked pads (an older
      // count-only session) may be holding this very pad.
      if (await _untrackedBusy(resourceId, except: {?segmentId})) {
        throw ControllerAllocationException(Failure(
          message: '${pad.label} may be in use at $resourceName by a '
              'player whose controllers are not tracked.',
          fix: 'Record that player\'s controllers first, or use count only.',
          code: 'controller_taken',
        ));
      }
    }

    final inserted = <ControllerAllocationRow>[];
    for (final id in controllerIds) {
      try {
        final row = ControllerAllocationRow(
              id: _uuid.v4(),
              controllerId: id,
              scope: scope,
              sessionId: sessionId,
              segmentId: segmentId,
              resourceId: resourceId,
              activityCode: activityCode,
              gameId: gameId,
              startedAt: startedAt,
              endedAt: null,
              requestId: requestId,
              createdAt: now,
            );
        await _db.into(_db.controllerAllocations).insert(row);
        inserted.add(row);
      } on Exception {
        // The unique index rejected it: a racing writer took the pad between
        // the read above and this insert. Surface the same friendly conflict.
        throw ControllerAllocationException(const Failure(
          message: 'That controller was just taken.',
          fix: 'Pick a free controller.',
          code: 'controller_taken',
        ));
      }
    }
    return inserted;
  }

  /// Physically brings [controllerIds] to [resourceId] for a session that is
  /// about to hold them (brief §5 borrowing), inside the caller's transaction,
  /// BEFORE [allocate]. Each borrow updates the pad's location, records that it
  /// owes a return home ([sessionRef]), and appends a `controller_moves` row
  /// with the pad's real origin. A pad already at the station is left alone.
  ///
  /// Refused (whole operation rolls back) when a pad is unknown, not usable,
  /// held by an open allocation, or sits at a station whose count-only session
  /// may have it in a player's hands. Returns the move rows it recorded.
  Future<List<ControllerMoveRow>> borrow({
    required List<String> controllerIds,
    required String resourceId,
    required String resourceName,
    required String? sessionRef,
    required DateTime at,
    required DateTime now,
  }) async {
    final moved = <ControllerMoveRow>[];
    for (final id in controllerIds) {
      final pad = await (_db.select(_db.controllers)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (pad == null) {
        throw ControllerAllocationException(const Failure(
          message: 'That controller no longer exists.',
          fix: 'Pick another controller.',
          code: 'controller_missing',
        ));
      }
      if (pad.currentResourceId == resourceId) continue;
      final status = ControllerStatus.fromCode(pad.status);
      if (!status.isUsable) {
        throw ControllerAllocationException(Failure(
          message: '${pad.label} is ${status.label.toLowerCase()}.',
          fix: 'Pick a usable controller.',
          code: 'controller_unusable',
        ));
      }
      if ((await openForController(id)).isNotEmpty) {
        throw ControllerAllocationException(Failure(
          message: '${pad.label} is already in use.',
          fix: 'Pick a free controller.',
          code: 'controller_taken',
        ));
      }
      if (await _untrackedBusy(pad.currentResourceId)) {
        throw ControllerAllocationException(Failure(
          message: '${pad.label} is at a station that is in use.',
          fix: "Its controllers may be in players' hands. Pick another.",
          code: 'controller_taken',
        ));
      }
      final home = pad.homeResourceId;
      final returning = home == resourceId;
      await (_db.update(_db.controllers)..where((t) => t.id.equals(id)))
          .write(ControllersCompanion(
        currentResourceId: Value(resourceId),
        loanReturnTo: Value(returning ? null : home),
        loanSessionRef: Value(returning ? null : sessionRef),
        updatedAt: Value(now),
      ));
      moved.add(await recordMove(
        controllerId: id,
        from: pad.currentResourceId,
        to: resourceId,
        kind: returning ? ControllerMoveKind.returnHome : ControllerMoveKind.loan,
        sessionRef: returning ? null : sessionRef,
        at: at,
        now: now,
      ));
    }
    return moved;
  }

  /// Appends one location-history row and returns it.
  Future<ControllerMoveRow> recordMove({
    required String controllerId,
    required String from,
    required String to,
    required ControllerMoveKind kind,
    String? sessionRef,
    required DateTime at,
    required DateTime now,
  }) async {
    final row = ControllerMoveRow(
      id: _uuid.v4(),
      controllerId: controllerId,
      fromResourceId: from,
      toResourceId: to,
      kind: kind.code,
      sessionRef: sessionRef,
      movedAt: at,
      createdAt: now,
    );
    await _db.into(_db.controllerMoves).insert(row);
    return row;
  }

  /// True when [resourceId] hosts an open controller-using segment that holds
  /// NO tracked pad — its pads may be in players' hands.
  Future<bool> _untrackedBusy(
    String resourceId, {
    Set<String> except = const {},
  }) async {
    Future<bool> usesControllers(String code) async =>
        (await (_db.select(_db.activities)..where((t) => t.code.equals(code)))
                .getSingleOrNull())
            ?.usesControllers ??
        false;
    final segs = await (_db.select(_db.sessionSegments)
          ..where((t) => t.resourceId.equals(resourceId) & t.endedAt.isNull()))
        .get();
    for (final s in segs) {
      if (except.contains(s.id)) continue;
      if (!await usesControllers(s.activityCode)) continue;
      final held = await (_db.select(_db.controllerAllocations)
            ..where((t) => t.segmentId.equals(s.id) & t.endedAt.isNull()))
          .get();
      if (held.isEmpty) return true;
    }
    return false;
  }

  /// Usable pads physically at [resourceId] that no open allocation holds.
  Future<int> freeAt(String resourceId) async {
    final rows = await (_db.select(_db.controllers)
          ..where((t) =>
              t.currentResourceId.equals(resourceId) &
              t.status.equals(ControllerStatus.usable.code)))
        .get();
    var free = 0;
    for (final r in rows) {
      if ((await openForController(r.id)).isEmpty) free++;
    }
    return free;
  }

  /// Whether the arena tracks physical pads at all (any non-retired pad).
  Future<bool> inventoryTracked() async {
    final rows = await (_db.select(_db.controllers)
          ..where((t) => t.status.equals(ControllerStatus.retired.code).not())
          ..limit(1))
        .get();
    return rows.isNotEmpty;
  }

  /// End-date every open allocation tied to a single-session segment, at [at].
  Future<void> closeForSegment(String segmentId, DateTime at) =>
      (_db.update(_db.controllerAllocations)
            ..where((t) => t.segmentId.equals(segmentId) & t.endedAt.isNull()))
          .write(ControllerAllocationsCompanion(endedAt: Value(at)));

  /// End-date every open allocation for a whole single session, at [at].
  Future<void> closeForSession(String sessionId, DateTime at) =>
      (_db.update(_db.controllerAllocations)
            ..where((t) => t.sessionId.equals(sessionId) & t.endedAt.isNull()))
          .write(ControllerAllocationsCompanion(endedAt: Value(at)));
}
