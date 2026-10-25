/// Application-layer orchestration for the session lifecycle (spec §6–§16).
/// Wires the pure domain services (planner, pricing, segment billing) to the
/// repositories and the clock. The UI calls these; it never prices, checks
/// availability, or computes timestamps itself.
library;

import 'dart:async';

import 'package:arena_ops/app/controllers/pad_board_loader.dart';
import 'package:arena_ops/app/notifications/session_reminders.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/app/providers/notification_providers.dart';
import 'package:arena_ops/app/auth/auth_controller.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/money/rounding.dart';
import 'package:arena_ops/core/monitoring/app_telemetry.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/auth/permission_guard.dart';
import 'package:arena_ops/core/time/business_calendar.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/core/time/utc_interval.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/pricing/pricing_service.dart';
import 'package:arena_ops/domain/repositories/booking_repository.dart';
import 'package:arena_ops/domain/repositories/catalog_repository.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/repositories/controller_allocation_reader.dart';
import 'package:arena_ops/domain/repositories/session_repository.dart';
import 'package:arena_ops/domain/services/availability_service.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';
import 'package:arena_ops/domain/services/payment_rules.dart';
import 'package:arena_ops/domain/services/segment_billing.dart';
import 'package:arena_ops/domain/services/session_planner.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// The in-progress choices for a new session.
///
/// Controllers live in ONE value, [controllers]: the count shown, the pads
/// reserved and the count billed all come from it, so they cannot drift.
/// `controllerCount` / `controllerIds` remain as read-only views (and as
/// constructor shorthands for count-only callers).
@immutable
class NewSessionDraft {
  NewSessionDraft({
    this.customerId,
    this.activityCode,
    this.resourceId,
    this.resourceName,
    this.gameId,
    ControllerChoice? controllers,
    int? controllerCount,
    List<String>? controllerIds,
    this.durationMinutes = 60,
    this.openEnded = false,
  }) : controllers =
           controllers ??
           (controllerIds != null && controllerIds.isNotEmpty
               ? ControllerChoice.tracked(
                   requested: controllerIds.length,
                   padIds: controllerIds,
                 )
               : ControllerChoice.count(controllerCount));

  final String? customerId;
  final String? activityCode;
  final String? resourceId;
  final String? resourceName;
  final String? gameId;

  /// How many controllers and which physical pads (single source of truth).
  final ControllerChoice controllers;
  final int? durationMinutes;
  final bool openEnded;

  /// The billed controller count — derived, never stored separately.
  int? get controllerCount => controllers.count;
  List<String> get controllerIds => controllers.padIds;

  NewSessionDraft copyWith({
    String? customerId,
    String? activityCode,
    String? resourceId,
    String? resourceName,
    String? gameId,
    ControllerChoice? controllers,
    int? durationMinutes,
    bool? openEnded,
    bool clearActivity = false,
    bool clearGame = false,
    bool clearControllers = false,
  }) => NewSessionDraft(
    customerId: customerId ?? this.customerId,
    activityCode: clearActivity ? null : (activityCode ?? this.activityCode),
    resourceId: resourceId ?? this.resourceId,
    resourceName: resourceName ?? this.resourceName,
    gameId: clearGame ? null : (gameId ?? this.gameId),
    controllers: clearControllers
        ? ControllerChoice.none
        : (controllers ?? this.controllers),
    durationMinutes: durationMinutes ?? this.durationMinutes,
    openEnded: openEnded ?? this.openEnded,
  );
}

/// Legacy (count, ids) arguments folded into one [ControllerChoice].
ControllerChoice resolveControllerChoice(
  ControllerChoice? choice,
  int? controllerCount,
  List<String>? controllerIds,
) =>
    choice ??
    (controllerIds != null && controllerIds.isNotEmpty
        ? ControllerChoice.tracked(
            requested: controllerIds.length,
            padIds: controllerIds,
          )
        : ControllerChoice.count(controllerCount));

class SessionActions {
  SessionActions({
    required this.sessions,
    required this.catalog,
    required this.bookings,
    required this.clock,
    this.guard = const PermissionGuard(null),
    this.planner = const SessionPlanner(),
    this.billing = const SegmentBilling(),
    this.availability = const AvailabilityService(),
    this.reminders,
    this.pads,
    this.padSelection = const PadSelection(),
  });

  final SessionRepository sessions;
  final CatalogRepository catalog;

  /// Read to keep a walk-in off a station someone has reserved.
  final BookingRepository bookings;
  final Clock clock;

  /// Optional session timer reminders orchestrator (spec §23).
  final SessionReminders? reminders;

  /// Checks the signed-in user before anything that takes money or changes the
  /// floor. Defaults to "nobody", so a caller that forgets to pass it is
  /// refused rather than quietly allowed.
  final PermissionGuard guard;
  final SessionPlanner planner;
  final SegmentBilling billing;
  final AvailabilityService availability;

  /// Who holds which pad. Optional so count-only callers (and older tests) need
  /// not wire it; without it a game change cannot carry pads across.
  final ControllerAllocationReader? pads;
  final PadSelection padSelection;

  DateTime _closeAt(DateTime at, BusinessCalendar calendar) =>
      calendar.operatingWindow(IstDate.fromUtc(at))?.end ??
      at.add(const Duration(hours: 12));

  /// Everything that holds a station over [window]: the open segment of each
  /// active session, and **bookings that overlap the window**.
  ///
  /// Bookings belong here: a walk-in started over the top of a reservation is
  /// exactly the double-booking the reservation was made to prevent, and it is
  /// only discovered when the booked customer arrives. An unassigned
  /// (any-system) booking does not hold a specific station until check-in, so
  /// it does not block one — the same rule the booking screen applies.
  Future<List<Occupancy>> _occupancies(
    UtcInterval window, {
    String? excludeSessionId,
  }) async {
    final active = await sessions.active();
    final booked = await bookings.overlapping(window.start, window.end);
    return [
      for (final a in active)
        if (a.session.id != excludeSessionId)
          Occupancy(
            resourceId: a.current.resourceId,
            interval: UtcInterval(
              a.current.startedAt,
              a.session.scheduledEndAt,
            ),
            isBooking: false,
          ),
      // `overlapping` returns only still-open (`booked`) reservations, so a
      // cancelled, no-show or already-checked-in booking never blocks.
      for (final b in booked)
        if (b.resourceId != null)
          Occupancy(
            resourceId: b.resourceId!,
            interval: UtcInterval(b.scheduledStart, b.scheduledEnd),
            isBooking: true,
            label: b.partyName,
          ),
    ];
  }

  /// Pads the session's current segment holds, in a stable order.
  Future<List<String>> padsHeldBy(SessionSegment segment) async => [
    for (final a
        in await pads?.openPadAllocations() ?? const <OpenPadAllocation>[])
      if (a.segmentId == segment.id) a.controllerId,
  ]..sort();

  Future<String> _resourceName(String id) async {
    for (final r in await catalog.resources()) {
      if (r.id == id) return r.name;
    }
    return id;
  }

  /// RIFT-style mode lock (brief §1): a station locked to one activity takes
  /// only that activity. The repository enforces it too; this says it early.
  Future<Failure?> _modeLock(String resourceId, String activityCode) async {
    for (final r in await catalog.resources()) {
      if (r.id == resourceId &&
          r.currentMode != null &&
          r.currentMode != activityCode) {
        return Failure(
          message: '${r.name} is set to ${r.currentMode} mode.',
          fix:
              'Switch ${r.name} to $activityCode in Settings → Stations, '
              'or use another system.',
          code: 'mode_locked',
        );
      }
    }
    return null;
  }

  PadBoardLoader get boards => PadBoardLoader(
    catalog: catalog,
    sessions: sessions,
    pads: pads,
  );

  /// The friendly pre-flight for a [ControllerChoice] at a station: count
  /// required, port ceiling, the game's local-player limit, and — once the
  /// arena tracks pads — every picked pad (free / usable / not elsewhere
  /// unless borrowed) and any shortfall. The repository re-checks.
  ///
  /// [legacyUnchanged]: an existing count-only session keeping its station and
  /// not growing is not re-checked against supply, so sessions started before
  /// tracking keep working.
  Future<Failure?> checkControllers({
    required ControllerChoice choice,
    required String resourceId,
    required String resourceName,
    required String activityCode,
    String? gameId,
    Set<String> keepIds = const {},
    String? exceptOccupantId,
    bool legacyUnchanged = false,
  }) async {
    final activity = (await catalog.activities())
        .where((a) => a.code == activityCode)
        .firstOrNull;
    if (!(activity?.usesControllers ?? false)) return null;
    final game = gameId == null ? null : await catalog.gameById(gameId);
    final board = await boards.load(
      resourceId: resourceId,
      resourceName: resourceName,
      keepIds: keepIds,
      exceptOccupantId: exceptOccupantId,
    );
    return padSelection.check(
      choice,
      board,
      maxLocalPlayers: game?.maxLocalPlayers,
      gameName: game?.name,
      requireSupply: !(legacyUnchanged && !choice.isTracked),
    );
  }

  /// What the next hour would cost on [current]'s station at [count]
  /// controllers, from now, with the session's own frozen price list — the
  /// "estimate changed" line on the change-controllers sheet.
  Paise? nextHourCost(Session session, SessionSegment current, int? count) {
    final now = clock.now();
    return const PricingService()
        .quote(
          snapshot: session.snapshot,
          activityCode: current.activityCode,
          controllerCount: count,
          start: now,
          end: now.add(const Duration(hours: 1)),
          // The rule is the session's, judged at its start.
          ruleAt: session.startedAt,
        )
        .valueOrNull
        ?.amount;
  }

  /// Price preview + availability for a new session (spec §6, §17).
  Future<Result<StartPlan>> previewStart(NewSessionDraft d) async {
    if (d.customerId == null || d.resourceId == null) {
      return const Err(
        Failure(
          message: 'Pick a customer and a station.',
          code: 'incomplete',
        ),
      );
    }
    // The type comes with the station; only a multi-type one asks for it.
    if (d.activityCode == null) {
      return const Err(
        Failure(
          message: 'Choose what this station plays as.',
          code: 'incomplete',
        ),
      );
    }
    final snapshot = await catalog.currentSnapshot();
    // A controller-based activity has a rate *per controller count*, so
    // without one there is nothing to price. Say that, rather than letting
    // the pricer report a missing rate the owner has not actually missed.
    final locked = await _modeLock(d.resourceId!, d.activityCode!);
    if (locked != null) return Err(locked);
    final padProblem = await checkControllers(
      choice: d.controllers,
      resourceId: d.resourceId!,
      resourceName: d.resourceName ?? d.resourceId!,
      activityCode: d.activityCode!,
      gameId: d.gameId,
    );
    if (padProblem != null) return Err(padProblem);
    final now = clock.now();
    final closeAt = _closeAt(now, snapshot.calendar);
    return planner.planStart(
      snapshot: snapshot,
      activityCode: d.activityCode!,
      controllerCount: d.controllerCount,
      resourceId: d.resourceId!,
      resourceName: d.resourceName ?? d.resourceId!,
      startedAt: now,
      durationMinutes: d.openEnded ? null : d.durationMinutes,
      // Rest of today, which covers any session that has to end by closing —
      // a superset is safe because the planner still checks real overlap.
      occupancies: await _occupancies(UtcInterval(now, closeAt)),
      closeAt: closeAt,
    );
  }

  /// Starts the parent session and its first segment.
  Future<Result<Session>> start(NewSessionDraft d) async {
    final denied = guard.check(Permission.start);
    if (denied != null) return Err(denied);
    final preview = await previewStart(d);
    if (preview.isErr) return Err(preview.failureOrNull!);
    final plan = preview.valueOrNull!;
    final snapshot = await catalog.currentSnapshot();
    final res = await sessions.start(
      StartSessionCommand(
        customerId: d.customerId!,
        startedAt: plan.startedAt,
        scheduledEndAt: plan.scheduledEndAt,
        snapshot: snapshot,
        resourceId: d.resourceId!,
        resourceName: d.resourceName ?? d.resourceId!,
        activityCode: d.activityCode!,
        gameId: d.gameId,
        controllerCount: d.controllers.count,
        controllerIds: d.controllers.padIdsOrNull,
        borrowControllerIds: d.controllers.borrowIdsOrNull,
      ),
    );
    if (res.isOk) {
      unawaited(reminders?.scheduleFor(res.valueOrNull!));
      AppTelemetry.timerStarted(
        sessionId: res.valueOrNull!.id,
        resourceId: d.resourceId!,
        activityCode: d.activityCode!,
        durationMinutes: d.openEnded ? null : d.durationMinutes,
        controllerCount: d.controllers.count,
      );
    }
    return res;
  }

  /// Live amount so far, billed across all segments (spec §14, §16). It
  /// stops at the booked end: overtime adds nothing until staff extend; the
  /// End screen shows what the overtime would cost ([endSummary]).
  SegmentBill liveBill(ActiveSession active, DateTime now) => billing.bill(
    snapshot: active.session.snapshot,
    segments: active.segments,
    openEndAt: now,
    sessionStart: active.session.startedAt,
    billUntil: now.isAfter(active.session.scheduledEndAt)
        ? active.session.scheduledEndAt
        : null,
  );

  // --- in-session changes (close current, open new at the exact instant) -----

  /// The session's frozen price list has no rate for the new segment: it
  /// would bill ₹0, and the server refuses it (`no_rate`).
  Failure? _unpriced(Session session, String activityCode, int? count) {
    if (session.snapshot.prices(activityCode, count)) return null;
    return Failure(
      message: 'This session\'s price list has no rate for that.',
      fix: count == null
          ? 'Pick a station type it prices, or end this session and start a new one.'
          : 'It has no $activityCode rate for $count '
              'controller${count == 1 ? '' : 's'}: pick another count, or end '
              'this session and start a new one with the current prices.',
      code: 'no_rate',
    );
  }

  Future<Result<SessionSegment>> switchSystem({
    required Session session,
    required SessionSegment current,
    required String resourceId,
    required String resourceName,
    required String activityCode,
    String? gameId,
    ControllerChoice? controllers,
    int? controllerCount,
    List<String>? controllerIds,
    DateTime? at,
  }) async {
    final denied = guard.check(Permission.start);
    if (denied != null) return Err(denied);
    final choice = resolveControllerChoice(
      controllers,
      controllerCount,
      controllerIds,
    );
    final locked = await _modeLock(resourceId, activityCode);
    if (locked != null) return Err(locked);
    final unpriced = _unpriced(session, activityCode, choice.count);
    if (unpriced != null) return Err(unpriced);
    final problem = await checkControllers(
      choice: choice,
      resourceId: resourceId,
      resourceName: resourceName,
      activityCode: activityCode,
      gameId: gameId,
      keepIds: (await padsHeldBy(current)).toSet(),
      exceptOccupantId: current.id,
    );
    if (problem != null) return Err(problem);
    final res = await sessions.reconfigure(
      ReconfigureCommand(
        sessionId: session.id,
        at: at ?? clock.now(),
        resourceId: resourceId,
        resourceName: resourceName,
        activityCode: activityCode,
        gameId: gameId,
        controllerCount: choice.count,
        controllerIds: choice.padIdsOrNull,
        borrowControllerIds: choice.borrowIdsOrNull,
      ),
    );
    if (res.isOk) {
      // The alerts name the station: reschedule them under the new one.
      unawaited(reminders?.scheduleFor(session));
      AppTelemetry.sessionSwitched(
        sessionId: session.id,
        operation: 'switch_station',
        fromResourceId: current.resourceId,
        toResourceId: resourceId,
        gameId: gameId,
        controllerCount: choice.count,
      );
    }
    return res;
  }

  Future<Result<SessionSegment>> changeGame({
    required Session session,
    required SessionSegment current,
    required String? gameId,
    DateTime? at,
  }) async {
    final denied = guard.check(Permission.start);
    if (denied != null) return Err(denied);
    // The same pads stay in the players' hands: carry them into the new
    // segment so a game change never silently frees them (brief §8).
    final held = await padsHeldBy(current);
    final choice = held.isEmpty
        ? ControllerChoice.count(current.controllerCount)
        : ControllerChoice.tracked(requested: held.length, padIds: held);
    final name = await _resourceName(current.resourceId);
    final problem = await checkControllers(
      choice: choice,
      resourceId: current.resourceId,
      resourceName: name,
      activityCode: current.activityCode,
      gameId: gameId,
      keepIds: held.toSet(),
      exceptOccupantId: current.id,
      legacyUnchanged: true,
    );
    if (problem != null) return Err(problem);
    final res = await sessions.reconfigure(
      ReconfigureCommand(
        sessionId: session.id,
        at: at ?? clock.now(),
        resourceId: current.resourceId,
        resourceName: name,
        activityCode: current.activityCode,
        gameId: gameId,
        controllerCount: current.controllerCount,
        controllerIds: choice.padIdsOrNull,
      ),
    );
    if (res.isOk) {
      AppTelemetry.sessionSwitched(
        sessionId: session.id,
        operation: 'change_game',
        fromResourceId: current.resourceId,
        toResourceId: current.resourceId,
        gameId: gameId,
        controllerCount: current.controllerCount,
      );
    }
    return res;
  }

  /// Changes how many controllers — and which pads — the session uses, from
  /// [at] on. A new segment opens at that instant, so the new count is billed
  /// only from then; the parent timer is untouched. Removed pads are released
  /// and added ones reserved (and borrowed, if from elsewhere) atomically.
  Future<Result<SessionSegment>> changeControllers({
    required Session session,
    required SessionSegment current,
    ControllerChoice? controllers,
    int? controllerCount,
    List<String>? controllerIds,
    DateTime? at,
  }) async {
    final denied = guard.check(Permission.start);
    if (denied != null) return Err(denied);
    final choice = resolveControllerChoice(
      controllers,
      controllerCount,
      controllerIds,
    );
    final unpriced = _unpriced(session, current.activityCode, choice.count);
    if (unpriced != null) return Err(unpriced);
    final name = await _resourceName(current.resourceId);
    final problem = await checkControllers(
      choice: choice,
      resourceId: current.resourceId,
      resourceName: name,
      activityCode: current.activityCode,
      gameId: current.gameId,
      keepIds: (await padsHeldBy(current)).toSet(),
      exceptOccupantId: current.id,
      legacyUnchanged: (choice.count ?? 0) <= (current.controllerCount ?? 0),
    );
    if (problem != null) return Err(problem);
    final res = await sessions.reconfigure(
      ReconfigureCommand(
        sessionId: session.id,
        at: at ?? clock.now(),
        resourceId: current.resourceId,
        resourceName: name,
        activityCode: current.activityCode,
        gameId: current.gameId,
        controllerCount: choice.count,
        controllerIds: choice.padIdsOrNull,
        borrowControllerIds: choice.borrowIdsOrNull,
      ),
    );
    if (res.isOk) {
      AppTelemetry.sessionSwitched(
        sessionId: session.id,
        operation: 'change_controllers',
        fromResourceId: current.resourceId,
        toResourceId: current.resourceId,
        gameId: current.gameId,
        controllerCount: choice.count,
      );
    }
    return res;
  }

  // --- extend / end ----------------------------------------------------------

  Future<Result<ExtensionPlan>> previewExtension(
    Session session,
    List<SessionSegment> segments,
    int addedMinutes,
  ) async {
    final current = segments.firstWhere(
      (s) => s.isOpen,
      orElse: () => segments.last,
    );
    final snapshot = session.snapshot;
    final closeAt = _closeAt(session.startedAt, snapshot.calendar);
    return planner.planExtension(
      snapshot: snapshot,
      activityCode: current.activityCode,
      controllerCount: current.controllerCount,
      resourceId: current.resourceId,
      startedAt: session.startedAt,
      currentEnd: session.scheduledEndAt,
      addedMinutes: addedMinutes,
      occupancies: await _occupancies(
        UtcInterval(session.scheduledEndAt, closeAt),
        excludeSessionId: session.id,
      ),
      closeAt: closeAt,
    );
  }

  Future<Result<Session>> extend(
    Session session,
    List<SessionSegment> segments,
    int addedMinutes,
  ) async {
    final denied = guard.check(Permission.start);
    if (denied != null) return Err(denied);
    final plan = await previewExtension(session, segments, addedMinutes);
    if (plan.isErr) return Err(plan.failureOrNull!);
    final p = plan.valueOrNull!;
    final res = await sessions.extend(
      ExtendSessionCommand(
        sessionId: session.id,
        addedMinutes: addedMinutes,
        newEndAt: p.newEnd,
        addedAmountPaise: p.addedCost.value,
      ),
    );
    if (res.isOk) {
      unawaited(reminders?.scheduleFor(res.valueOrNull!));
      AppTelemetry.addBreadcrumb(
        category: 'session',
        message: 'session_extended',
        data: {
          'sessionId': session.id,
          'addedMinutes': addedMinutes,
          'newEndAt': p.newEnd.toIso8601String(),
        },
      );
    }
    return res;
  }

  /// The final bill from all segments, for the End screen (spec §19). It stops
  /// at the booked end (see [overtimeBillUntil]) unless [chargeOvertime]
  /// (staff's choice at End).
  SegmentBill endSummary(
    Session session,
    List<SessionSegment> segments, {
    DateTime? at,
    bool chargeOvertime = false,
  }) {
    final end = at ?? clock.now();
    var last = end;
    for (final s in segments) {
      final e = s.endedAt ?? end;
      if (e.isAfter(last)) last = e;
    }
    return billing.bill(
      snapshot: session.snapshot,
      segments: segments,
      openEndAt: end,
      sessionStart: session.startedAt,
      billUntil: chargeOvertime
          ? null
          : overtimeBillUntil(lastEnd: last, scheduledEnd: session.scheduledEndAt),
    );
  }

  /// The bill once staff lower it to [billPaise] (null, or not lower: as
  /// priced): a manual flat discount off the subtotal, cash-rounded as the
  /// server does (`_discount_apply`, then `_pr_money`).
  ({int discountPaise, int billedPaise}) loweredBill(
    Session session,
    SegmentBill bill,
    int? billPaise,
  ) {
    final total = bill.total.value;
    if (billPaise == null || billPaise >= total) {
      return (discountPaise: 0, billedPaise: total);
    }
    final sub = bill.subtotal.value;
    final target = billPaise < 0 ? 0 : billPaise;
    final discount = sub - target > sub ? sub : sub - target;
    if (discount <= 0) return (discountPaise: 0, billedPaise: total);
    final policy = session.snapshot.policy;
    return (
      discountPaise: discount,
      billedPaise: applyMoneyRounding(
          sub - discount, policy.moneyRoundingPaise, policy.moneyRoundingDir),
    );
  }

  /// The earliest end staff may set: after the current segment started.
  DateTime _earliestEnd(Session session, List<SessionSegment> segments) {
    var earliest = session.startedAt;
    for (final s in segments) {
      if (s.startedAt.isAfter(earliest)) earliest = s.startedAt;
    }
    return earliest;
  }

  /// The end staff pick on the End sheet ([hour]:[minute] IST): today, or
  /// yesterday when that is still ahead of now; after the current segment
  /// started.
  Result<DateTime> pickedEnd(
    Session session,
    List<SessionSegment> segments,
    int hour,
    int minute,
  ) {
    final now = clock.now();
    final today = IstTime.fromUtc(now);
    var picked =
        IstTime(today.year, today.month, today.day, hour, minute).toUtc();
    if (picked.isAfter(now)) picked = picked.subtract(const Duration(days: 1));
    final earliest = _earliestEnd(session, segments);
    if (!picked.isAfter(earliest)) {
      return Err(Failure(
        message: 'The end must be after ${IstTime.format12(earliest)}.',
        fix: 'Pick a later time, when the session actually ended.',
        code: 'invalid_time',
      ));
    }
    return Ok(picked);
  }

  /// Ends the session at [at] (staff may set an earlier end: [endPicked], with
  /// [endReason], which the server audits). [billPaise] lowers the bill (see
  /// [loweredBill]); it needs the discount permission.
  Future<Result<Session>> end(
    Session session,
    List<SessionSegment> segments, {
    bool markWaived = false,
    String? waiveReason,
    DateTime? at,
    int? billPaise,
    bool chargeOvertime = false,
    bool endPicked = false,
    String? endReason,
  }) async {
    final actualEnd = at ?? clock.now();
    // A picked end is earlier than now, when staff end it: it needs a reason.
    final movedFrom = endPicked ? clock.now() : null;
    final endWhy = endReason?.trim() ?? '';
    if (movedFrom != null) {
      if (!actualEnd.isBefore(movedFrom) ||
          !actualEnd.isAfter(_earliestEnd(session, segments))) {
        return Err(Failure(
          message: 'The end must be after '
              '${IstTime.format12(_earliestEnd(session, segments))} and before now.',
          fix: 'Pick the time the session actually ended.',
          code: 'invalid_time',
        ));
      }
      if (endWhy.isEmpty) return const Err(endReasonRequired);
    }
    final bill = endSummary(session, segments,
        at: actualEnd, chargeOvertime: chargeOvertime);
    final lowered =
        markWaived ? (discountPaise: 0, billedPaise: bill.total.value)
            : loweredBill(session, bill, billPaise);
    final denied =
        guard.check(Permission.bill) ??
        (markWaived || lowered.discountPaise > 0
            ? guard.check(Permission.discount)
            : null);
    if (denied != null) return Err(denied);
    final reason = waiveReason?.trim() ?? '';
    if (markWaived && reason.isEmpty) return const Err(waiveReasonRequired);
    if (lowered.discountPaise > 0) {
      final over = discountOverLimit(
        canSettings: guard.check(Permission.settings) == null,
        discountPaise: lowered.discountPaise,
        subtotalPaise: bill.subtotal.value,
        maxPercent: await catalog.manualDiscountMaxPercent(),
      );
      if (over != null) return Err(over);
    }
    if (markWaived) {
      final over = waiveOverLimit(
        ownerLevel: guard.actor?.isOwner ?? false,
        billedPaise: bill.total.value,
        paidPaise: (await sessions.paymentsFor(session.id))
            .fold(0, (sum, p) => sum + p.amountPaise),
        maxPercent: await catalog.manualDiscountMaxPercent(),
      );
      if (over != null) return Err(over);
    }
    if (actualEnd.isBefore(session.startedAt)) {
      AppTelemetry.reportTimerAnomaly(
        sessionId: session.id,
        anomaly: 'actualEndedAt precedes startedAt',
        resourceId: segments.lastOrNull?.resourceId ?? 'unknown',
        startedAt: session.startedAt,
        actualEndedAt: actualEnd,
      );
    }
    final res = await sessions.end(
      EndSessionCommand(
        sessionId: session.id,
        actualEndedAt: actualEnd,
        charges: bill.charges,
        billedAmountPaise: lowered.billedPaise,
        markWaived: markWaived,
        waiveReason: markWaived ? reason : null,
        discountPaise: lowered.discountPaise,
        chargeOvertime: chargeOvertime,
        endMovedFrom: movedFrom,
        endReason: movedFrom == null ? null : endWhy,
      ),
    );
    if (res.isOk) {
      unawaited(reminders?.cancelFor(session.id));
      AppTelemetry.timerStopped(
        sessionId: session.id,
        resourceId: segments.lastOrNull?.resourceId ?? 'unknown',
        billedAmountPaise: bill.total.value,
        playedDuration: actualEnd.difference(session.startedAt),
      );
      AppTelemetry.billingCalculated(
        sessionId: session.id,
        totalPaise: bill.total.value,
        segmentCount: segments.length,
        totalSeconds: actualEnd.difference(session.startedAt).inSeconds,
      );
    }
    return res;
  }

  Future<Result> recordPayment(RecordPaymentCommand cmd) async {
    final denied =
        guard.check(Permission.bill) ??
        (cmd.isRefund ? guard.check(Permission.discount) : null);
    if (denied != null) return Err(denied);
    final res = await sessions.recordPayment(cmd);
    if (res.isOk) {
      AppTelemetry.addBreadcrumb(
        category: 'billing',
        message: 'payment_recorded',
        data: {
          'sessionId': cmd.sessionId,
          'amountPaise': cmd.amountPaise,
          'method': cmd.method.name,
          'isRefund': cmd.isRefund,
        },
      );
    }
    return res;
  }
}

final sessionActionsProvider = Provider<SessionActions>(
  (ref) => SessionActions(
    sessions: ref.watch(sessionRepositoryProvider),
    catalog: ref.watch(catalogRepositoryProvider),
    bookings: ref.watch(bookingRepositoryProvider),
    clock: ref.watch(clockProvider),
    guard: PermissionGuard(ref.watch(authControllerProvider)),
    reminders: ref.watch(sessionRemindersProvider),
    pads: ref.watch(controllerAllocationRepositoryProvider),
  ),
);
