/// Application-layer booking orchestration (spec §18–§23). Game-first
/// availability resolution on create; converts a booking into a real session on
/// check-in, keeping the booking as the planned record.
library;

import 'dart:async';

import 'package:arena_ops/app/auth/auth_controller.dart';
import 'package:arena_ops/app/controllers/pad_board_loader.dart';
import 'package:arena_ops/app/notifications/booking_reminders.dart';
import 'package:arena_ops/app/notifications/session_reminders.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/app/providers/notification_providers.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/monitoring/app_telemetry.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/core/time/utc_interval.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/auth/permission_guard.dart';
import 'package:arena_ops/domain/entities/booking.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/pricing/pricing_service.dart';
import 'package:arena_ops/domain/repositories/booking_repository.dart';
import 'package:arena_ops/domain/repositories/catalog_repository.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/repositories/session_repository.dart';
import 'package:arena_ops/domain/services/availability_service.dart';
import 'package:arena_ops/domain/services/booking_availability_service.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

@immutable
class BookingDraft {
  const BookingDraft({
    required this.customerId,
    required this.activityCode,
    required this.date,
    required this.startMinuteOfDay,
    required this.durationMinutes,
    this.gameId,
    this.resourceId, // null = any compatible system
    this.playersRequired,
    this.controllerRequirement,
    this.notes,
    this.editingId,
  });

  final String customerId;
  final String activityCode;
  final IstDate date;
  final int startMinuteOfDay;
  final int durationMinutes;
  final String? gameId;
  final String? resourceId;
  final int? playersRequired;
  final int? controllerRequirement;

  /// Free-text staff note ("birthday party, needs 2 tables").
  final String? notes;

  /// Set when amending an existing booking — the conflict check then ignores
  /// the booking's own slot so it never clashes with itself.
  final String? editingId;
}

/// What a check-in would do right now (see [BookingActions.planCheckIn]).
@immutable
class CheckInPlan {
  const CheckInPlan({
    required this.resource,
    required this.scheduledEnd,
    required this.usesControllers,
    this.requestedControllers,
    this.gameName,
    this.gameMaxLocalPlayers,
    this.alternatives = false,
    this.choices = const [],
  });

  final Resource resource;
  final DateTime scheduledEnd;
  final bool usesControllers;

  /// Controllers the booking asked for (null when it did not say).
  final int? requestedControllers;
  final String? gameName;
  final int? gameMaxLocalPlayers;

  /// True for an any-system booking: the station was chosen now.
  final bool alternatives;

  /// Every station an any-system booking could start at right now, [resource]
  /// among them (staff may pick another); empty for a booking for a named
  /// station.
  final List<Resource> choices;
}

class BookingActions {
  BookingActions({
    required this.bookings,
    required this.sessions,
    required this.catalog,
    required this.clock,
    this.guard = const PermissionGuard(null),
    this.reminders,
    this.sessionReminders,
    this.availability = const BookingAvailabilityService(),
    this.boards,
    this.padSelection = const PadSelection(),
    this.pricing = const PricingService(),
  });

  final BookingRepository bookings;
  final SessionRepository sessions;
  final CatalogRepository catalog;
  final Clock clock;

  /// Who is signed in. Booking, amending, cancelling and checking in all need
  /// `start` — the same rule the server's booking ops and session start apply.
  /// Defaults to "nobody", so a caller that forgets it is refused.
  final PermissionGuard guard;

  /// Schedules/cancels offline booking reminders (spec §23). Optional so the
  /// controller can be built without notifications (e.g. in tests).
  final BookingReminders? reminders;

  /// Timer alerts for the session a check-in starts (5 min, 1 min, time up).
  final SessionReminders? sessionReminders;
  final BookingAvailabilityService availability;

  /// The controller inventory as one station sees it. With it, check-in
  /// validates (and can borrow) specific pads exactly like New Session;
  /// without it, check-in is count-only (the repository still refuses more
  /// controllers than are free at the station).
  final PadBoardLoader? boards;
  final PadSelection padSelection;

  /// The price check New Session runs (SessionPlanner.planStart): check-in
  /// refuses what the price list cannot bill, as the server would (`no_rate`).
  final PricingService pricing;

  /// Active-session + existing-booking occupancy over [window]. Unassigned
  /// (any-system) bookings do not block a specific resource until check-in.
  Future<List<Occupancy>> _occupancies(
    UtcInterval window, {
    String? excludeBookingId,
  }) async {
    final active = await sessions.active();
    final booked = await bookings.overlapping(window.start, window.end);
    return [
      for (final a in active)
        Occupancy(
          resourceId: a.current.resourceId,
          interval: UtcInterval(a.current.startedAt, a.session.scheduledEndAt),
          isBooking: false,
        ),
      for (final b in booked)
        if (b.resourceId != null && b.id != excludeBookingId)
          Occupancy(
            resourceId: b.resourceId!,
            interval: UtcInterval(b.scheduledStart, b.scheduledEnd),
            isBooking: true,
          ),
    ];
  }

  Future<Map<String, GameAvailability>?> _compat(String? gameId) async {
    if (gameId == null) return null;
    return {
      for (final rf in await catalog.resourcesForGame(gameId))
        rf.resource.id: rf.status,
    };
  }

  /// Candidate systems for a draft (for showing the list before confirming).
  Future<List<Resource>> candidateSystems(BookingDraft d) async {
    final window = bookingWindow(
      date: d.date,
      startMinuteOfDay: d.startMinuteOfDay,
      durationMinutes: d.durationMinutes,
    );
    final game = d.gameId == null ? null : await catalog.gameById(d.gameId!);
    return availability.availableSystems(
      window: window,
      resources: await catalog.resources(),
      occupancies: await _occupancies(window),
      requireActivityCode: d.activityCode,
      compatibility: await _compat(d.gameId),
      gameMaxLocalPlayers: game?.maxLocalPlayers,
      playersRequired: d.playersRequired,
    );
  }

  Future<Result<Booking>> createBooking(BookingDraft d) async {
    final denied = guard.check(Permission.start);
    if (denied != null) return Err(denied);
    final window = bookingWindow(
      date: d.date,
      startMinuteOfDay: d.startMinuteOfDay,
      durationMinutes: d.durationMinutes,
    );
    final resources = await catalog.resources();
    final game = d.gameId == null ? null : await catalog.gameById(d.gameId!);
    final compat = await _compat(d.gameId);
    final occ = await _occupancies(window, excludeBookingId: d.editingId);

    if (d.resourceId != null) {
      final matches = resources.where((r) => r.id == d.resourceId).toList();
      if (matches.isEmpty) {
        return const Err(
          Failure(message: 'Unknown system.', code: 'no_resource'),
        );
      }
      final check = availability.checkSpecific(
        resource: matches.first,
        window: window,
        occupancies: occ,
        requireActivityCode: d.activityCode,
        gameName: game?.name,
        compatibility: compat,
        gameMaxLocalPlayers: game?.maxLocalPlayers,
        playersRequired: d.playersRequired,
      );
      if (check.isErr) return Err(check.failureOrNull!);
    } else {
      final avail = availability.availableSystems(
        window: window,
        resources: resources,
        occupancies: occ,
        requireActivityCode: d.activityCode,
        compatibility: compat,
        gameMaxLocalPlayers: game?.maxLocalPlayers,
        playersRequired: d.playersRequired,
      );
      if (avail.isEmpty) {
        return const Err(
          Failure(
            message: 'No compatible system is available for that time.',
            fix: 'Try another time or game.',
            code: 'no_availability',
          ),
        );
      }
    }

    final existing = d.editingId == null
        ? null
        : await bookings.getById(d.editingId!);
    final draft = Booking(
      id: d.editingId ?? '',
      customerId: d.customerId,
      activityCode: d.activityCode,
      gameId: d.gameId,
      resourceId: d.resourceId,
      scheduledStart: window.start,
      scheduledEnd: window.end,
      playersRequired: d.playersRequired,
      controllerRequirement: d.controllerRequirement,
      status: existing?.status ?? BookingStatus.booked,
      // The form does not edit these: an edit keeps the stored party name and
      // phone instead of sending them as cleared (booking.update writes what
      // the payload says).
      partyName: existing?.partyName,
      phone: existing?.phone,
      notes: d.notes,
      reminderStatus: existing?.reminderStatus ?? ReminderStatus.scheduled,
      createdAt: existing?.createdAt ?? clock.now(),
      updatedAt: clock.now(),
    );

    final Booking saved;
    try {
      saved = existing == null
          ? await bookings.create(draft)
          : await bookings.update(draft);
    } on BookingConflict catch (e) {
      // Taken between the check above and the write: the repository re-checks
      // inside its transaction and wrote nothing.
      return Err(e.failure);
    }

    // Rescheduled from the saved row; an amended time never leaves the old
    // reminder behind (spec §23): a slot the new time leaves out is cancelled.
    await reminders?.scheduleFor(saved);
    AppTelemetry.bookingOperation(
      bookingId: saved.id,
      operation: existing != null ? 'updated' : 'created',
      resourceId: saved.resourceId,
      activityCode: saved.activityCode,
    );
    return Ok(saved);
  }

  /// Amend an existing booking. Runs the same conflict checks as creating one,
  /// minus the booking's own slot.
  Future<Result<Booking>> updateBooking(BookingDraft draft) {
    assert(draft.editingId != null, 'updateBooking needs the booking id');
    return createBooking(draft);
  }

  /// Where and how a booked customer would be seated right now: the station
  /// (the booked one, or the best free compatible one for an any-system
  /// booking, with the other free ones staff may pick instead), the session
  /// end, and the controllers the booking asked for.
  /// Nothing is written — the check-in sheet shows this, lets staff pick the
  /// physical pads, then calls [checkIn].
  Future<Result<CheckInPlan>> planCheckIn(
    Booking booking, {
    String? preferResourceId,
  }) async {
    if (booking.customerId == null) {
      return const Err(
        Failure(message: 'This booking has no customer.', code: 'no_customer'),
      );
    }
    final now = clock.now();
    final duration = booking.scheduledEnd.difference(booking.scheduledStart);
    final scheduledEnd = now.isBefore(booking.scheduledEnd)
        ? booking.scheduledEnd
        : now.add(duration);
    final window = UtcInterval(now, scheduledEnd);

    final resources = await catalog.resources();
    final game = booking.gameId == null
        ? null
        : await catalog.gameById(booking.gameId!);
    final compat = await _compat(booking.gameId);
    final occ = await _occupancies(window, excludeBookingId: booking.id);
    final activity = (await catalog.activities())
        .where((a) => a.code == booking.activityCode)
        .firstOrNull;
    final usesControllers = activity?.usesControllers ?? false;
    final wanted = booking.controllerRequirement ?? booking.playersRequired;

    Result<void> fits(Resource r) => availability.checkSpecific(
      resource: r,
      window: window,
      occupancies: occ,
      requireActivityCode: booking.activityCode,
      gameName: game?.name,
      compatibility: compat,
      gameMaxLocalPlayers: game?.maxLocalPlayers,
      playersRequired: booking.playersRequired,
    );

    // The session starts now, so a station whose session is still running is
    // busy even past that session's booked end (overtime), which the
    // occupancies above do not cover; one set to another mode would be
    // refused at start.
    final running = {
      for (final a in await sessions.active()) a.current.resourceId,
    };
    bool startableNow(Resource r) =>
        !running.contains(r.id) &&
        (r.currentMode == null || r.currentMode == booking.activityCode);

    final choices = booking.resourceId != null
        ? const <Resource>[]
        : [
            for (final r in availability.availableSystems(
              window: window,
              resources: resources,
              occupancies: occ,
              requireActivityCode: booking.activityCode,
              compatibility: compat,
              gameMaxLocalPlayers: game?.maxLocalPlayers,
              playersRequired: booking.playersRequired,
            ))
              if (startableNow(r)) r,
          ];

    Resource resolved;
    final fixedId = booking.resourceId ?? preferResourceId;
    if (fixedId != null) {
      final matches = resources.where((r) => r.id == fixedId).toList();
      if (matches.isEmpty) {
        return const Err(
          Failure(message: 'Unknown system.', code: 'no_resource'),
        );
      }
      final station = matches.first;
      if (running.contains(station.id)) {
        return Err(
          Failure(
            message: '${station.name} is still in use.',
            fix: booking.resourceId != null
                ? 'End the session there first, or edit the booking to '
                      'another station.'
                : 'Pick another station.',
            code: 'resource_busy',
          ),
        );
      }
      final check = fits(station);
      if (check.isErr) return Err(check.failureOrNull!);
      resolved = station;
    } else {
      if (choices.isEmpty) {
        return const Err(
          Failure(
            message: 'No compatible system is free right now.',
            fix: 'Free a system or pick another.',
            code: 'no_availability',
          ),
        );
      }
      resolved = choices.first;
      // Prefer a system that already has the booked controllers free, so the
      // party is not sent where pads would have to be borrowed.
      if (usesControllers && wanted != null && boards != null) {
        for (final r in choices) {
          final b = await boards!.load(resourceId: r.id, resourceName: r.name);
          if (!b.tracked || b.inventory.freeHere >= wanted) {
            resolved = r;
            break;
          }
        }
      }
    }
    return Ok(
      CheckInPlan(
        resource: resolved,
        scheduledEnd: scheduledEnd,
        usesControllers: usesControllers,
        requestedControllers: usesControllers ? wanted : null,
        gameName: game?.name,
        gameMaxLocalPlayers: game?.maxLocalPlayers,
        alternatives: booking.resourceId == null,
        choices: choices,
      ),
    );
  }

  /// Check in a booked customer: re-check availability now and start a session
  /// linked to the booking (spec §22–§23). [controllers] are the physical pads
  /// staff picked on the check-in sheet (validated — and borrowed — exactly
  /// like New Session); without it the booking's controller count is used
  /// count-only, which the repository still checks against the free pads.
  Future<Result<Session>> checkIn(
    Booking booking, {
    ControllerChoice? controllers,
    String? resourceId,
  }) async {
    // Checking in starts a session, so it takes the session-start permission.
    final denied = guard.check(Permission.start);
    if (denied != null) return Err(denied);
    final planned = await planCheckIn(booking, preferResourceId: resourceId);
    if (planned.isErr) return Err(planned.failureOrNull!);
    final plan = planned.valueOrNull!;
    final resolved = plan.resource;
    final now = clock.now();

    var choice =
        controllers ?? ControllerChoice.count(plan.requestedControllers);
    if (!plan.usesControllers) choice = ControllerChoice.none;
    if (plan.usesControllers && boards != null) {
      final board = await boards!.load(
        resourceId: resolved.id,
        resourceName: resolved.name,
      );
      final problem = padSelection.check(
        choice,
        board,
        maxLocalPlayers: plan.gameMaxLocalPlayers,
        gameName: plan.gameName,
      );
      if (problem != null) return Err(problem);
    }

    final snapshot = await catalog.currentSnapshot();
    // Priced like a walk-in start, for the chosen controller count: without a
    // rate the session would bill ₹0 and the server refuses it.
    final priced = pricing.quote(
      snapshot: snapshot,
      activityCode: booking.activityCode,
      controllerCount: plan.usesControllers ? choice.count : null,
      start: now,
      end: plan.scheduledEnd,
    );
    if (priced.isErr) return Err(priced.failureOrNull!);
    final started = await sessions.start(
      StartSessionCommand(
        customerId: booking.customerId!,
        startedAt: now,
        scheduledEndAt: plan.scheduledEnd,
        snapshot: snapshot,
        resourceId: resolved.id,
        resourceName: resolved.name,
        activityCode: booking.activityCode,
        gameId: booking.gameId,
        controllerCount: plan.usesControllers ? choice.count : null,
        controllerIds: choice.padIdsOrNull,
        borrowControllerIds: choice.borrowIdsOrNull,
        bookingId: booking.id,
      ),
    );
    if (started.isOk) {
      // The session start already checked the booking in, in the same
      // transaction (and the server does the same), so there is no second
      // write here that could succeed or fail on its own.
      // They arrived — the reminder is no longer needed.
      await reminders?.cancelFor(booking.id);
      await bookings.setReminderStatus(booking.id, ReminderStatus.done);
      // The session's own timer alerts, as for a walk-in start.
      unawaited(sessionReminders?.scheduleFor(started.valueOrNull!));
      AppTelemetry.bookingOperation(
        bookingId: booking.id,
        operation: 'checked_in',
        resourceId: booking.resourceId,
        activityCode: booking.activityCode,
      );
    }
    return started;
  }

  /// Cancel a reservation (booking.set_status). The slot is freed and the
  /// reminder cleared; the booking stays in history as cancelled.
  Future<Result<void>> cancel(String id) async {
    final denied = guard.check(Permission.start);
    if (denied != null) return Err(denied);
    await bookings.setStatus(id, BookingStatus.cancelled);
    await reminders?.cancelFor(id);
    await bookings.setReminderStatus(id, ReminderStatus.done);
    AppTelemetry.bookingOperation(bookingId: id, operation: 'cancelled');
    return const Ok(null);
  }

  /// The customer never came (booking.set_status no_show). Frees the slot and
  /// clears the reminder like a cancel, but keeps why in history. Only once
  /// the booked start has passed: before that it is a cancel.
  Future<Result<void>> markNoShow(Booking booking) async {
    final denied = guard.check(Permission.start);
    if (denied != null) return Err(denied);
    if (booking.scheduledStart.isAfter(clock.now())) {
      return const Err(Failure(
        message: 'The booking has not started yet.',
        fix: 'Cancel it instead if they are not coming.',
        code: 'booking_not_started',
      ));
    }
    await bookings.setStatus(booking.id, BookingStatus.noShow);
    await reminders?.cancelFor(booking.id);
    await bookings.setReminderStatus(booking.id, ReminderStatus.done);
    AppTelemetry.bookingOperation(bookingId: booking.id, operation: 'no_show');
    return const Ok(null);
  }

  /// Turn the device reminder for a booking on or off.
  Future<void> setReminder(Booking booking, {required bool on}) async {
    if (on) {
      // Status first: scheduleFor reads the row and skips a reminder that is
      // turned off.
      await bookings.setReminderStatus(booking.id, ReminderStatus.scheduled);
      await reminders?.scheduleFor(booking);
    } else {
      await reminders?.cancelFor(booking.id);
      await bookings.setReminderStatus(booking.id, ReminderStatus.off);
    }
  }
}

final bookingActionsProvider = Provider<BookingActions>(
  (ref) => BookingActions(
    bookings: ref.watch(bookingRepositoryProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    catalog: ref.watch(catalogRepositoryProvider),
    clock: ref.watch(clockProvider),
    guard: PermissionGuard(ref.watch(authControllerProvider)),
    reminders: ref.watch(bookingRemindersProvider),
    sessionReminders: ref.watch(sessionRemindersProvider),
    boards: PadBoardLoader(
      catalog: ref.watch(catalogRepositoryProvider),
      sessions: ref.watch(sessionRepositoryProvider),
      pads: ref.watch(controllerAllocationRepositoryProvider),
    ),
  ),
);
