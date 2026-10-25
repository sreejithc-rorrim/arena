import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/data/local/controller_allocator.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/mappers.dart';
import 'package:arena_ops/data/sync/sync_recorder.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/entities/payment.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/repositories/session_repository.dart';
import 'package:arena_ops/domain/services/payment_rules.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class LocalSessionRepository implements SessionRepository {
  LocalSessionRepository(this._db,
      [this._clock = const SystemClock(), this._sync]);

  final AppDatabase _db;
  final Clock _clock;

  /// Cloud mode only: records each change as a sync op in the same
  /// transaction. Null in local-only mode.
  final SyncRecorder? _sync;
  static const _uuid = Uuid();

  ControllerAllocator get _alloc => ControllerAllocator(_db, _uuid);

  /// Validates controller supply for a specific-pad allocation (brief §6): the
  /// station mode lock (RIFT PS5/VR), the pad count vs the billing count, the
  /// port ceiling, and the game's supported local players. Per-pad checks
  /// (usable / at this station / free) are done by [ControllerAllocator].
  Future<void> _ensureControllerSupply({
    required String resourceId,
    required String resourceName,
    required String activityCode,
    required String? gameId,
    required List<String>? controllerIds,
    required int? controllerCount,
    String? previousResourceId,
    int? previousCount,
  }) async {
    final res = await (_db.select(_db.resources)
          ..where((t) => t.id.equals(resourceId)))
        .getSingleOrNull();
    if (res != null && res.currentMode != null && res.currentMode != activityCode) {
      throw ControllerAllocationException(Failure(
        message: '$resourceName is set to ${res.currentMode} mode.',
        fix: 'Switch $resourceName to $activityCode in Settings → Stations, '
            'or use another system.',
        code: 'mode_locked',
      ));
    }
    if (controllerIds == null || controllerIds.isEmpty) {
      // Count-only (legacy) — still never more controllers than are physically
      // free at the station once the arena tracks pads. An existing count-only
      // session that keeps its station and does not grow is left alone, so
      // sessions started before tracking keep working.
      final n = controllerCount ?? 0;
      final unchanged = previousResourceId == resourceId && n <= (previousCount ?? 0);
      if (n > 0 &&
          !unchanged &&
          await _usesControllers(activityCode) &&
          await _alloc.inventoryTracked()) {
        final free = await _alloc.freeAt(resourceId);
        if (n > free) {
          throw ControllerAllocationException(Failure(
            message: '$resourceName has only $free free '
                'controller${free == 1 ? '' : 's'}.',
            fix: 'Pick the controllers (borrowing from another station if '
                'needed), or choose $free.',
            code: 'controllers_unavailable',
          ));
        }
      }
      return;
    }
    final count = controllerIds.length;
    if (controllerCount != null && controllerCount != count) {
      throw ControllerAllocationException(Failure(
        message: 'Picked $count controller${count == 1 ? '' : 's'} but the '
            'session is set to $controllerCount.',
        fix: 'Match the number of controllers to the players.',
        code: 'controller_count_mismatch',
      ));
    }
    const portCapacity = 4;
    if (count > portCapacity) {
      throw ControllerAllocationException(Failure(
        message: '$resourceName can hold up to $portCapacity controllers.',
        fix: 'Reduce controllers or use another system.',
        code: 'controllers_exceeded',
      ));
    }
    if (gameId != null) {
      final game = await (_db.select(_db.games)..where((t) => t.id.equals(gameId)))
          .getSingleOrNull();
      final maxPlayers = game?.maxLocalPlayers ?? 1;
      if (count > maxPlayers) {
        throw ControllerAllocationException(Failure(
          message: 'This game supports $maxPlayers local '
              'player${maxPlayers == 1 ? '' : 's'}.',
          fix: 'Reduce controllers to $maxPlayers, or pick a game that '
              'supports more players.',
          code: 'players_exceeded',
        ));
      }
    }
  }

  Future<bool> _usesControllers(String activityCode) async =>
      (await (_db.select(_db.activities)
                ..where((t) => t.code.equals(activityCode)))
              .getSingleOrNull())
          ?.usesControllers ??
      false;

  // --- reads -----------------------------------------------------------------

  SimpleSelectStatement<$SessionsTable, SessionRow> _activeQuery() =>
      _db.select(_db.sessions)
        ..where((t) => t.status.equals(SessionStatus.active.code))
        ..orderBy([(t) => OrderingTerm(expression: t.scheduledEndAt)]);

  Future<ActiveSession> _withSegments(SessionRow r) async => ActiveSession(
        session: sessionFromRow(r),
        segments: await segmentsFor(r.id),
      );

  @override
  Stream<List<ActiveSession>> watchActive() => _activeQuery().watch().asyncMap(
      (rows) async => [for (final r in rows) await _withSegments(r)]);

  @override
  Future<List<ActiveSession>> active() async =>
      [for (final r in await _activeQuery().get()) await _withSegments(r)];

  SimpleSelectStatement<$SessionSegmentsTable, SessionSegmentRow> _openQuery() =>
      _db.select(_db.sessionSegments)..where((t) => t.endedAt.isNull());

  @override
  Stream<List<SessionSegment>> watchOpenSegments() =>
      _openQuery().watch().map((r) => r.map(segmentFromRow).toList());

  @override
  Future<List<SessionSegment>> openSegments() async =>
      (await _openQuery().get()).map(segmentFromRow).toList();

  @override
  Future<Session?> getById(String id) async {
    final row = await (_db.select(_db.sessions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : sessionFromRow(row);
  }

  @override
  Stream<Session?> watchById(String id) =>
      (_db.select(_db.sessions)..where((t) => t.id.equals(id)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : sessionFromRow(r));

  @override
  Future<List<SessionSegment>> segmentsFor(String sessionId) async {
    final rows = await (_db.select(_db.sessionSegments)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm(expression: t.index)]))
        .get();
    return rows.map(segmentFromRow).toList();
  }

  @override
  Stream<List<SessionSegment>> watchSegmentsFor(String sessionId) =>
      (_db.select(_db.sessionSegments)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm(expression: t.index)]))
          .watch()
          .map((r) => r.map(segmentFromRow).toList());

  @override
  Stream<List<Session>> watchAwaitingPayment() =>
      (_db.select(_db.sessions)
            ..where((t) =>
                t.status.equals(SessionStatus.completed.code) &
                t.paymentStatus.isIn([
                  PaymentStatus.unpaid.code,
                  PaymentStatus.partial.code,
                ]))
            ..orderBy([
              (t) => OrderingTerm(
                  expression: t.actualEndedAt, mode: OrderingMode.desc),
            ]))
          .watch()
          .map((rows) => rows.map(sessionFromRow).toList());

  @override
  Future<List<Session>> recent({int limit = 30}) async {
    final rows = await (_db.select(_db.sessions)
          ..where((t) => t.status.equals(SessionStatus.active.code).not())
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
    return rows.map(sessionFromRow).toList();
  }

  @override
  Future<List<Session>> forCustomer(String customerId) async {
    final rows = await (_db.select(_db.sessions)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt, mode: OrderingMode.desc)]))
        .get();
    return rows.map(sessionFromRow).toList();
  }

  @override
  Future<List<Session>> inRange(DateTime fromUtc, DateTime toUtc) async {
    final rows = await (_db.select(_db.sessions)
          ..where((t) =>
              t.startedAt.isBiggerOrEqualValue(fromUtc) &
              t.startedAt.isSmallerThanValue(toUtc)))
        .get();
    return rows.map(sessionFromRow).toList();
  }

  @override
  Future<List<SessionSegment>> segmentsInRange(
      DateTime fromUtc, DateTime toUtc) async {
    // Half-open overlap: a segment counts if any of it falls in the window.
    // An open segment (endedAt null) counts when it started before the end.
    final rows = await (_db.select(_db.sessionSegments)
          ..where((t) =>
              t.startedAt.isSmallerThanValue(toUtc) &
              (t.endedAt.isNull() | t.endedAt.isBiggerThanValue(fromUtc))))
        .get();
    return rows.map(segmentFromRow).toList();
  }

  @override
  Future<List<SessionCharge>> chargesInRange(
      DateTime fromUtc, DateTime toUtc) async {
    final rows = await (_db.select(_db.sessionCharges)
          ..where((t) =>
              t.segmentStart.isSmallerThanValue(toUtc) &
              t.segmentEnd.isBiggerThanValue(fromUtc)))
        .get();
    return rows.map(chargeFromRow).toList();
  }

  // --- critical operations ---------------------------------------------------

  @override
  Future<Result<Session>> start(StartSessionCommand cmd) async {
    try {
      final row = await _db.transaction(() async {
        await _ensureResourceUsable(cmd.resourceId, cmd.resourceName);
        await _ensureGamePlayable(
            cmd.gameId, cmd.resourceId, cmd.resourceName);
        await _ensureControllerSupply(
          resourceId: cmd.resourceId,
          resourceName: cmd.resourceName,
          activityCode: cmd.activityCode,
          gameId: cmd.gameId,
          controllerIds: cmd.controllerIds,
          controllerCount: cmd.controllerCount,
        );
        await _ensureResourceFree(cmd.resourceId, cmd.resourceName);
        final now = _clock.now();
        final session = SessionRow(
          id: _uuid.v4(),
          bookingId: cmd.bookingId,
          customerId: cmd.customerId,
          status: SessionStatus.active.code,
          paymentStatus: PaymentStatus.unpaid.code,
          startedAt: cmd.startedAt.toUtc(),
          scheduledEndAt: cmd.scheduledEndAt.toUtc(),
          actualEndedAt: null,
          pricingSnapshot: cmd.snapshot.toJson(),
          billedAmountPaise: null,
          voidReason: null,
          createdAt: now,
          updatedAt: now,
        );
        await _db.into(_db.sessions).insert(session);
        final seg = await _insertSegment(
          sessionId: session.id,
          index: 0,
          resourceId: cmd.resourceId,
          activityCode: cmd.activityCode,
          gameId: cmd.gameId,
          controllerCount: cmd.controllerCount,
          startedAt: cmd.startedAt.toUtc(),
          now: now,
        );
        var moves = const <ControllerMoveRow>[];
        if (cmd.borrowControllerIds != null &&
            cmd.borrowControllerIds!.isNotEmpty) {
          moves = await _alloc.borrow(
            controllerIds: cmd.borrowControllerIds!,
            resourceId: cmd.resourceId,
            resourceName: cmd.resourceName,
            sessionRef: Controller.sessionRef(session.id),
            at: cmd.startedAt.toUtc(),
            now: now,
          );
        }
        var pads = const <ControllerAllocationRow>[];
        if (cmd.controllerIds != null && cmd.controllerIds!.isNotEmpty) {
          pads = await _alloc.allocate(
            scope: 'single',
            sessionId: session.id,
            segmentId: seg.id,
            controllerIds: cmd.controllerIds!,
            resourceId: cmd.resourceId,
            resourceName: cmd.resourceName,
            activityCode: cmd.activityCode,
            gameId: cmd.gameId,
            startedAt: cmd.startedAt.toUtc(),
            now: now,
            requestId: cmd.requestId,
          );
        }
        // A check-in: the booking is checked in by the same transaction that
        // starts its session, so neither can happen without the other (and
        // the server does the same, refusing a booking already checked in).
        if (cmd.bookingId != null) {
          await (_db.update(_db.bookings)
                ..where((t) => t.id.equals(cmd.bookingId!)))
              .write(BookingsCompanion(
            status: Value(BookingStatus.checkedIn.code),
            updatedAt: Value(now),
          ));
        }
        await (_db.update(_db.customers)..where((t) => t.id.equals(cmd.customerId)))
            .write(CustomersCompanion(lastVisitAt: Value(cmd.startedAt.toUtc())));
        await _touchGame(cmd.gameId, cmd.startedAt.toUtc());
        await _sync?.record(
          kind: 'session.start',
          entityType: 'session',
          entityId: session.id,
          payload: {
            'id': session.id,
            'segment_id': seg.id,
            'customer_id': cmd.customerId,
            'booking_id': cmd.bookingId,
            'started_at': Wire.at(session.startedAt),
            'scheduled_end_at': Wire.at(session.scheduledEndAt),
            'pricing_snapshot': session.pricingSnapshot,
            'resource_id': cmd.resourceId,
            'activity_code': cmd.activityCode,
            'game_id': cmd.gameId,
            'controller_count': cmd.controllerCount,
            'allocations': Wire.pads(pads),
            'moves': Wire.moves(moves),
          },
        );
        return session;
      });
      return Ok(sessionFromRow(row));
    } on ControllerAllocationException catch (e) {
      return Err(e.failure);
    } on _ResourceUnusable catch (e) {
      // Ahead of the catch-all below, which would otherwise report a station
      // under maintenance as merely "in use".
      return Err(e.failure);
    } on _ResourceBusy catch (e) {
      return Err(_busyFailure(e.resourceName));
    } catch (_) {
      return Err(_busyFailure(cmd.resourceName));
    }
  }

  @override
  Future<Result<SessionSegment>> reconfigure(ReconfigureCommand cmd) async {
    final session = await getById(cmd.sessionId);
    if (session == null) {
      return const Err(Failure(message: 'Session not found.', code: 'not_found'));
    }
    if (!session.isActive) {
      return const Err(Failure(
        message: 'This session is not active.',
        fix: 'Only active sessions can be changed.',
        code: 'not_active',
      ));
    }
    final segments = await segmentsFor(cmd.sessionId);
    final open = segments.where((s) => s.isOpen).toList();
    if (open.isEmpty) {
      return const Err(Failure(message: 'No open segment to change.', code: 'no_open_segment'));
    }
    final current = open.first;
    final at = cmd.at.toUtc();
    if (at.isBefore(current.startedAt)) {
      return const Err(Failure(
        message: 'Change time is before the segment started.',
        code: 'invalid_time',
      ));
    }

    try {
      final newSeg = await _db.transaction(() async {
        // Changing resource needs the target free (spec §24). Staying on the
        // same resource (game/controller change) skips the check.
        if (cmd.resourceId != current.resourceId) {
          await _ensureResourceUsable(cmd.resourceId, cmd.resourceName);
          await _ensureResourceFree(cmd.resourceId, cmd.resourceName);
        }
        // Checked on every change, not just a station change: changing the
        // game on the same station can pick one it cannot run.
        await _ensureGamePlayable(cmd.gameId, cmd.resourceId, cmd.resourceName);
        await _ensureControllerSupply(
          resourceId: cmd.resourceId,
          resourceName: cmd.resourceName,
          activityCode: cmd.activityCode,
          gameId: cmd.gameId,
          controllerIds: cmd.controllerIds,
          controllerCount: cmd.controllerCount,
          previousResourceId: current.resourceId,
          previousCount: current.controllerCount,
        );
        final now = _clock.now();
        // Close the current segment and its controller allocations at the exact
        // switch instant — the parent session timer is never touched (brief §8).
        await (_db.update(_db.sessionSegments)..where((t) => t.id.equals(current.id)))
            .write(SessionSegmentsCompanion(endedAt: Value(at)));
        await _alloc.closeForSegment(current.id, at);
        final seg = await _insertSegment(
          sessionId: cmd.sessionId,
          index: current.index + 1,
          resourceId: cmd.resourceId,
          activityCode: cmd.activityCode,
          gameId: cmd.gameId,
          controllerCount: cmd.controllerCount,
          startedAt: at,
          now: now,
        );
        // Pads from another station are carried over only now — after this
        // session's own pads were released — so nothing is double-held.
        var moves = const <ControllerMoveRow>[];
        var pads = const <ControllerAllocationRow>[];
        if (cmd.borrowControllerIds != null &&
            cmd.borrowControllerIds!.isNotEmpty) {
          moves = await _alloc.borrow(
            controllerIds: cmd.borrowControllerIds!,
            resourceId: cmd.resourceId,
            resourceName: cmd.resourceName,
            sessionRef: Controller.sessionRef(cmd.sessionId),
            at: at,
            now: now,
          );
        }
        if (cmd.controllerIds != null && cmd.controllerIds!.isNotEmpty) {
          pads = await _alloc.allocate(
            scope: 'single',
            sessionId: cmd.sessionId,
            segmentId: seg.id,
            controllerIds: cmd.controllerIds!,
            resourceId: cmd.resourceId,
            resourceName: cmd.resourceName,
            activityCode: cmd.activityCode,
            gameId: cmd.gameId,
            startedAt: at,
            now: now,
          );
        }
        await (_db.update(_db.sessions)..where((t) => t.id.equals(cmd.sessionId)))
            .write(SessionsCompanion(updatedAt: Value(now)));
        await _touchGame(cmd.gameId, at);
        await _sync?.record(
          kind: 'session.reconfigure',
          entityType: 'session',
          entityId: cmd.sessionId,
          payload: {
            'session_id': cmd.sessionId,
            'at': Wire.at(at),
            // The segment this device changed: refused as stale if another
            // device switched the session first.
            'expected_segment_id': current.id,
            'new_segment_id': seg.id,
            'resource_id': cmd.resourceId,
            'activity_code': cmd.activityCode,
            'game_id': cmd.gameId,
            'controller_count': cmd.controllerCount,
            'allocations': Wire.pads(pads),
            'moves': Wire.moves(moves),
          },
        );
        return seg;
      });
      return Ok(segmentFromRow(newSeg));
    } on ControllerAllocationException catch (e) {
      return Err(e.failure);
    } on _ResourceUnusable catch (e) {
      // Ahead of the catch-all below, which would otherwise report a station
      // under maintenance as merely "in use".
      return Err(e.failure);
    } on _ResourceBusy catch (e) {
      return Err(_busyFailure(e.resourceName));
    } catch (_) {
      return Err(_busyFailure(cmd.resourceName));
    }
  }

  @override
  Future<Result<Session>> extend(ExtendSessionCommand cmd) async {
    final existing = await getById(cmd.sessionId);
    if (existing == null) {
      return const Err(Failure(message: 'Session not found.', code: 'not_found'));
    }
    if (!existing.isActive) {
      return const Err(Failure(
        message: 'This session is not active.',
        fix: 'Only active sessions can be extended.',
        code: 'not_active',
      ));
    }
    await _db.transaction(() async {
      final now = _clock.now();
      final ext = SessionExtensionRow(
        id: _uuid.v4(),
        sessionId: cmd.sessionId,
        addedMinutes: cmd.addedMinutes,
        oldEndAt: existing.scheduledEndAt,
        newEndAt: cmd.newEndAt.toUtc(),
        addedAmountPaise: cmd.addedAmountPaise,
        reason: cmd.reason,
        createdAt: now,
      );
      await _db.into(_db.sessionExtensions).insert(ext);
      await (_db.update(_db.sessions)..where((t) => t.id.equals(cmd.sessionId)))
          .write(SessionsCompanion(
        scheduledEndAt: Value(cmd.newEndAt.toUtc()),
        updatedAt: Value(now),
      ));
      await _sync?.record(
        kind: 'session.extend',
        entityType: 'session',
        entityId: cmd.sessionId,
        payload: {
          'session_id': cmd.sessionId,
          'extension_id': ext.id,
          'added_minutes': ext.addedMinutes,
          // The end this extension builds on: two devices extending from the
          // same end must not both stack on it.
          'old_end_at': Wire.at(ext.oldEndAt),
          'new_end_at': Wire.at(ext.newEndAt),
          'added_amount_paise': ext.addedAmountPaise,
          'reason': ext.reason,
        },
      );
    });
    return Ok((await getById(cmd.sessionId))!);
  }

  @override
  Future<Result<Session>> end(EndSessionCommand cmd) async {
    final existing = await getById(cmd.sessionId);
    if (existing == null) {
      return const Err(Failure(message: 'Session not found.', code: 'not_found'));
    }
    if (existing.status == SessionStatus.completed) {
      return Ok(existing); // idempotent — no second write
    }
    if (existing.status == SessionStatus.voided) {
      return const Err(Failure(
        message: 'This session was voided.',
        fix: 'Voided sessions cannot be ended.',
        code: 'voided',
      ));
    }

    await _db.transaction(() async {
      final actualEnd = cmd.actualEndedAt.toUtc();
      // What this bill was priced from — the server refuses the end as stale
      // if another device switched or extended the session meanwhile.
      final pricedFrom = [
        for (final s in await segmentsFor(cmd.sessionId)) s.id,
      ];
      // Close the open segment at the actual end.
      await (_db.update(_db.sessionSegments)
            ..where((t) => t.sessionId.equals(cmd.sessionId) & t.endedAt.isNull()))
          .write(SessionSegmentsCompanion(endedAt: Value(actualEnd)));
      // Free every controller this session held.
      await _alloc.closeForSession(cmd.sessionId, actualEnd);

      final charges = [
        for (final c in cmd.charges)
          SessionChargeRow(
            id: _uuid.v4(),
            sessionId: cmd.sessionId,
            segmentId: c.segmentId,
            segmentIndex: c.segmentIndex,
            bandCode: c.bandCode,
            activityCode: c.activityCode,
            resourceId: c.resourceId,
            controllerCount: c.controllerCount,
            segmentStart: c.segmentStart,
            segmentEnd: c.segmentEnd,
            playedMinutes: c.playedMinutes,
            billedMinutes: c.billedMinutes,
            unitMinutes: c.unitMinutes,
            unitPricePaise: c.unitPricePaise,
            amountPaise: c.amountPaise,
          ),
      ];
      await _db.batch((b) => b.insertAll(_db.sessionCharges, charges));

      final paid = await _totalPaid(cmd.sessionId);
      final status = cmd.markWaived
          ? PaymentStatus.waived
          : _paymentStatus(billed: cmd.billedAmountPaise, paid: paid);
      await (_db.update(_db.sessions)..where((t) => t.id.equals(cmd.sessionId)))
          .write(SessionsCompanion(
        status: Value(SessionStatus.completed.code),
        actualEndedAt: Value(actualEnd),
        billedAmountPaise: Value(cmd.billedAmountPaise),
        paymentStatus: Value(status.code),
        updatedAt: Value(_clock.now()),
      ));
      await _sync?.record(
        kind: 'session.end',
        entityType: 'session',
        entityId: cmd.sessionId,
        payload: {
          'session_id': cmd.sessionId,
          'ended_at': Wire.at(actualEnd),
          'billed_amount_paise': cmd.billedAmountPaise,
          'mark_waived': cmd.markWaived,
          if (cmd.chargeOvertime) 'charge_overtime': true,
          if (cmd.markWaived && cmd.waiveReason != null)
            'waive_reason': cmd.waiveReason,
          // An earlier end: the server requires the reason and audits it.
          if (cmd.endMovedFrom != null)
            'end_moved': {
              'from': Wire.at(cmd.endMovedFrom),
              'reason': cmd.endReason,
            },
          // A lowered bill: the server re-checks it as a manual discount.
          if (cmd.discountPaise > 0)
            'discount': {
              'id': _uuid.v4(),
              'manual': {'value_kind': 'flat', 'value': cmd.discountPaise},
              'reason': 'Bill corrected',
              'amount_paise': cmd.discountPaise,
            },
          'expected_segment_ids': pricedFrom,
          'expected_scheduled_end_at': Wire.at(existing.scheduledEndAt),
          'charges': [for (final c in charges) chargeWire(c)],
        },
      );
    });
    return Ok((await getById(cmd.sessionId))!);
  }

  /// A charge row as the server's session.end expects it.
  static Map<String, Object?> chargeWire(SessionChargeRow c) => {
        'id': c.id,
        'segment_id': c.segmentId,
        'segment_index': c.segmentIndex,
        'band_code': c.bandCode,
        'activity_code': c.activityCode,
        'resource_id': c.resourceId,
        'controller_count': c.controllerCount,
        'segment_start': Wire.at(c.segmentStart),
        'segment_end': Wire.at(c.segmentEnd),
        'played_minutes': c.playedMinutes,
        'billed_minutes': c.billedMinutes,
        'unit_minutes': c.unitMinutes,
        'unit_price_paise': c.unitPricePaise,
        'amount_paise': c.amountPaise,
      };

  @override
  Future<Result<Session>> voidSession(String id, String reason) async {
    final existing = await getById(id);
    if (existing == null) {
      return const Err(Failure(message: 'Session not found.', code: 'not_found'));
    }
    await _db.transaction(() async {
      final now = _clock.now();
      // Free the resource by closing any open segment.
      await (_db.update(_db.sessionSegments)
            ..where((t) => t.sessionId.equals(id) & t.endedAt.isNull()))
          .write(SessionSegmentsCompanion(endedAt: Value(now)));
      await _alloc.closeForSession(id, now);
      await (_db.update(_db.sessions)..where((t) => t.id.equals(id))).write(
        SessionsCompanion(
          status: Value(SessionStatus.voided.code),
          voidReason: Value(reason),
          updatedAt: Value(now),
        ),
      );
      await _sync?.record(
        kind: 'session.void',
        entityType: 'session',
        entityId: id,
        payload: {'session_id': id, 'reason': reason, 'at': Wire.at(now)},
      );
    });
    return Ok((await getById(id))!);
  }

  // --- history + payments ----------------------------------------------------

  @override
  Future<List<SessionExtension>> extensionsFor(String sessionId) async {
    final rows = await (_db.select(_db.sessionExtensions)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    return rows.map(extensionFromRow).toList();
  }

  @override
  Future<List<SessionCharge>> chargesFor(String sessionId) async {
    final rows = await (_db.select(_db.sessionCharges)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm(expression: t.segmentIndex)]))
        .get();
    return rows.map(chargeFromRow).toList();
  }

  @override
  Future<List<Payment>> paymentsFor(String sessionId) async =>
      (await _paymentsQuery(sessionId).get()).map(paymentFromRow).toList();

  @override
  Stream<List<Payment>> watchPaymentsFor(String sessionId) =>
      _paymentsQuery(sessionId).watch().map((r) => r.map(paymentFromRow).toList());

  SimpleSelectStatement<$PaymentsTable, PaymentRow> _paymentsQuery(String sessionId) =>
      _db.select(_db.payments)
        ..where((t) => t.sessionId.equals(sessionId))
        ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);

  @override
  Future<Result<Payment>> recordPayment(RecordPaymentCommand cmd) async {
    if (cmd.isRefund && (cmd.reason == null || cmd.reason!.trim().isEmpty)) {
      return const Err(Failure(
        message: 'A refund needs a reason.',
        fix: 'Add why the money is being returned.',
        code: 'refund_reason_required',
      ));
    }
    final amount =
        signedPaymentAmount(cmd.amountPaise, isRefund: cmd.isRefund);
    if (amount.isErr) return Err(amount.failureOrNull!);
    final signed = amount.valueOrNull!;
    final session = await getById(cmd.sessionId);
    if (session == null) {
      return const Err(Failure(message: 'Session not found.', code: 'not_found'));
    }
    Failure? refused;
    final row = await _db.transaction(() async {
      // Read the balance inside the write transaction, so a double tap cannot
      // pass the check twice.
      refused = paymentBalanceProblem(
        signed: signed,
        alreadyPaid: await _totalPaid(cmd.sessionId),
        billed: session.billedAmountPaise,
        waived: session.paymentStatus == PaymentStatus.waived,
      );
      if (refused != null) return null;
      final now = _clock.now();
      final payment = PaymentRow(
        id: _uuid.v4(),
        sessionId: cmd.sessionId,
        amountPaise: signed,
        method: cmd.method.code,
        isRefund: cmd.isRefund,
        note: cmd.note,
        reason: cmd.reason,
        createdAt: now,
      );
      await _db.into(_db.payments).insert(payment);
      // The payment id is this device's: a retried push can never charge
      // twice (the server replays the op, and its primary key refuses a copy).
      await _sync?.record(
        kind: 'payment.record',
        entityType: 'session',
        entityId: cmd.sessionId,
        payload: {
          'scope': 'single',
          'parent_id': cmd.sessionId,
          'payment_id': payment.id,
          'amount_paise': payment.amountPaise,
          'method': payment.method,
          'is_refund': payment.isRefund,
          'note': payment.note,
          'reason': payment.reason,
        },
      );
      if (session.paymentStatus != PaymentStatus.waived) {
        final paid = await _totalPaid(cmd.sessionId);
        final status = _paymentStatus(billed: session.billedAmountPaise, paid: paid);
        await (_db.update(_db.sessions)..where((t) => t.id.equals(cmd.sessionId)))
            .write(SessionsCompanion(
          paymentStatus: Value(status.code),
          updatedAt: Value(now),
        ));
      }
      return payment;
    });
    if (row == null) return Err(refused!);
    return Ok(paymentFromRow(row));
  }

  @override
  Future<List<Payment>> paymentsInRange(DateTime fromUtc, DateTime toUtc) async {
    final rows = await (_db.select(_db.payments)
          ..where((t) =>
              t.createdAt.isBiggerOrEqualValue(fromUtc) &
              t.createdAt.isSmallerThanValue(toUtc)))
        .get();
    return rows.map(paymentFromRow).toList();
  }

  // --- helpers ---------------------------------------------------------------

  Future<void> _ensureResourceFree(String resourceId, String resourceName) async {
    final busy = await (_db.select(_db.sessionSegments)
          ..where((t) => t.resourceId.equals(resourceId) & t.endedAt.isNull()))
        .getSingleOrNull();
    if (busy != null) throw _ResourceBusy(resourceName);
  }

  /// Refuses to *put* a session on a station that is not available.
  ///
  /// Checked here rather than only in the picker: the pickers filter by status,
  /// but a sheet can be open when a station is sent for maintenance, and a
  /// booking check-in arrives with a resource chosen earlier. Deliberately only
  /// applies when entering a station — a session already running on one that
  /// has just been marked for maintenance can still be changed, billed and
  /// ended.
  Future<void> _ensureResourceUsable(
      String resourceId, String resourceName) async {
    final row = await (_db.select(_db.resources)
          ..where((t) => t.id.equals(resourceId)))
        .getSingleOrNull();
    if (row == null) {
      throw _ResourceUnusable(Failure(
        message: '$resourceName no longer exists.',
        fix: 'Pick another station.',
        code: 'resource_missing',
      ));
    }
    final status = ResourceStatus.fromCode(row.status);
    if (status != ResourceStatus.available) {
      throw _ResourceUnusable(Failure(
        message: '$resourceName is marked ${status.label.toLowerCase()}.',
        fix: 'Pick another station, or make it available in '
            'Settings → Stations.',
        code: 'resource_unavailable',
      ));
    }
  }

  /// Refuses a game that this station cannot actually run.
  ///
  /// Checked here, not only in the game picker: a stale sheet — or a station
  /// switch that carried the current game onto a system without it — could
  /// start a session on a disc that is scratched, uninstalled or region-locked. Absence of a
  /// compatibility row means the game is not installed there.
  Future<void> _ensureGamePlayable(
      String? gameId, String resourceId, String resourceName) async {
    if (gameId == null) return;
    final compat = await (_db.select(_db.gameResources)
          ..where((t) =>
              t.gameId.equals(gameId) & t.resourceId.equals(resourceId)))
        .getSingleOrNull();
    final status = compat == null
        ? GameAvailability.notInstalled
        : GameAvailability.fromCode(compat.status);
    if (status != GameAvailability.playable) {
      throw _ResourceUnusable(Failure(
        message: "$resourceName can't run this game (${status.label}).",
        fix: 'Pick a system where the game is playable, or change the game.',
        code: 'not_playable',
      ));
    }
  }

  Future<SessionSegmentRow> _insertSegment({
    required String sessionId,
    required int index,
    required String resourceId,
    required String activityCode,
    required String? gameId,
    required int? controllerCount,
    required DateTime startedAt,
    required DateTime now,
  }) async {
    final seg = SessionSegmentRow(
      id: _uuid.v4(),
      sessionId: sessionId,
      index: index,
      resourceId: resourceId,
      activityCode: activityCode,
      gameId: gameId,
      controllerCount: controllerCount,
      startedAt: startedAt,
      endedAt: null,
      createdAt: now,
    );
    await _db.into(_db.sessionSegments).insert(seg);
    return seg;
  }

  Future<void> _touchGame(String? gameId, DateTime at) async {
    if (gameId == null) return;
    await (_db.update(_db.games)..where((t) => t.id.equals(gameId)))
        .write(GamesCompanion(lastPlayedAt: Value(at)));
  }

  Future<int> _totalPaid(String sessionId) async {
    final rows = await (_db.select(_db.payments)
          ..where((t) => t.sessionId.equals(sessionId)))
        .get();
    return rows.fold<int>(0, (sum, p) => sum + p.amountPaise);
  }

  PaymentStatus _paymentStatus({required int? billed, required int paid}) {
    if (billed == null) return paid > 0 ? PaymentStatus.partial : PaymentStatus.unpaid;
    if (paid >= billed) return PaymentStatus.paid;
    if (paid > 0) return PaymentStatus.partial;
    return PaymentStatus.unpaid;
  }

  Failure _busyFailure(String resourceName) => Failure(
        message: '$resourceName is in use.',
        fix: 'Pick another station.',
        code: 'resource_busy',
      );
}

class _ResourceBusy implements Exception {
  _ResourceBusy(this.resourceName);
  final String resourceName;
}

/// A station that exists but must not take a session right now (maintenance,
/// temporarily unavailable, disabled), or has been deleted.
class _ResourceUnusable implements Exception {
  _ResourceUnusable(this.failure);
  final Failure failure;
}
