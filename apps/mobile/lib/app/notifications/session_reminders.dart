import 'package:arena_ops/app/notifications/device_time.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/notifications/notification_service.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/notifications/notification_settings.dart';
import 'package:arena_ops/domain/notifications/reminder_plan.dart';
import 'package:arena_ops/domain/repositories/catalog_repository.dart';
import 'package:arena_ops/domain/repositories/customer_repository.dart';
import 'package:arena_ops/domain/repositories/notification_settings_repository.dart';
import 'package:arena_ops/domain/repositories/session_repository.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

/// Orchestrates session timer alerts (spec §23, timer alerts):
/// Schedules 5-minute lead, 1-minute lead ("1 min mune alert") and time expired ("സമയം കഴിഞ്ഞു").
/// Alerts work fully offline on the device without internet.
class SessionReminders {
  SessionReminders({
    required this.service,
    required this.sessions,
    required this.customers,
    required this.catalog,
    required this.settingsRepo,
    required this.clock,
  });

  final NotificationService service;
  final SessionRepository sessions;
  final CustomerRepository customers;
  final CatalogRepository catalog;
  final NotificationSettingsRepository settingsRepo;
  final Clock clock;

  /// Session ids this run has alerts scheduled for, so [reconcile]
  /// can cancel those whose session ended, was voided or rolled back elsewhere.
  final Set<String> _scheduled = {};

  /// When (app clock) each alert this run set is due, by notification id.
  final Map<int, DateTime> _ringsAt = {};

  /// Notification ids of everything this run has scheduled (start-up sweep).
  Set<int> get scheduledIds => {
    for (final id in _scheduled)
      for (var slot = 0; slot < 3; slot++) sessionAlertId(id, slot),
  };

  /// Every change to the OS alerts runs one at a time, in call order, and
  /// reads the session from the database when it runs (never a copy taken
  /// earlier). So an action's reschedule — an extension on this device — can
  /// never be overwritten by a refresh that read the session before it changed:
  /// the action's turn comes after the refresh and sees the new end.
  Future<void> _last = Future.value();

  /// Runs [work] in turn; true when it finished without an error.
  Future<bool> _serial(String what, Future<void> Function() work) {
    final done = _last
        .then((_) => work())
        .then(
          (_) => true,
          onError: (Object e) {
            debugPrint('SessionReminders.$what failed: $e');
            return false;
          },
        );
    _last = done;
    return done;
  }

  /// Runs [work] with no alert change in between (the start-up sweep).
  Future<bool> exclusive(Future<void> Function() work) =>
      _serial('exclusive', work);

  /// Schedule (or reschedule) timer alerts for one single session, as it is
  /// in the database now; a session no longer running has its alerts removed.
  Future<void> scheduleFor(Session session) =>
      _serial('scheduleFor(${session.id})', () async {
        await _scheduleSession(session.id, await sessions.active());
      });

  /// Cancel all 3 alert slots for a session (on session end or void).
  Future<void> cancelFor(String sessionId) =>
      _serial('cancelFor($sessionId)', () => _cancel(sessionId));

  /// Bring every alert in line with the sessions this device knows now: those
  /// that stopped running (ended, voided, or a start the server refused) are
  /// cancelled; every running one is (re)scheduled — the same ids replace the
  /// old alerts, so an extension or a station switch made on ANY device moves
  /// them. Run after sync brings changes, on resume, on startup and when this
  /// phone's alert settings change (an alert turned off stops ringing, sound
  /// or vibration changes on alerts already set).
  Future<bool> reconcile() => _serial('reconcile', () async {
    final active = await sessions.active();
    final running = {
      for (final a in active)
        if (a.session.isActive) a.session.id,
    };
    for (final id in _scheduled.difference(running).toList()) {
      await _cancel(id);
    }
    await _scheduleAll(active);
  });

  /// Schedule alerts for all currently active sessions.
  /// [reconcile] does this too; on its own it never cancels anything.
  Future<void> syncActive() => _serial('syncActive', () async {
    await _scheduleAll(await sessions.active());
  });

  Future<void> _scheduleAll(List<ActiveSession> active) async {
    // Latest end first: iOS keeps only the 64 most recently set
    // notifications, so the alerts due soonest are set last.
    final ends = <(DateTime, Future<void> Function())>[
      for (final a in active)
        if (a.session.isActive)
          (
            a.session.scheduledEndAt,
            () => _scheduleSession(a.session.id, active),
          ),
    ]..sort((x, y) => y.$1.compareTo(x.$1));
    for (final (_, schedule) in ends) {
      await schedule();
    }
  }

  Future<void> _scheduleSession(String id, List<ActiveSession> active) async {
    final running = active.firstWhereOrNull((a) => a.session.id == id);
    final session = running?.session;
    if (running == null || session == null || !session.isActive) {
      await _cancel(id);
      return;
    }
    _scheduled.add(id); // before the reads, so the start-up sweep keeps it
    try {
      final settings = await settingsRepo.getSettings();
      final customer = await customers.getById(session.customerId);
      final customerName = customer?.name ?? 'Guest';
      final stationName =
          (await catalog.resources())
              .firstWhereOrNull((r) => r.id == running.current.resourceId)
              ?.name ??
          'Station';

      final plans = buildSessionAlerts(
        sessionId: session.id,
        titleName: '$stationName ($customerName)',
        scheduledEndAt: session.scheduledEndAt,
        now: clock.now(),
        settings: settings,
      );
      await _schedule(session.id, plans, session.scheduledEndAt, settings);
    } catch (e) {
      debugPrint('SessionReminders.scheduleFor($id) failed: $e');
    }
  }

  /// A slot the new plans leave out (its new time already past — e.g. an
  /// extension the server refused moved the end back — or turned off) is
  /// cancelled if this run set it to ring later than now. One turned off in
  /// the settings is cancelled too when an earlier run (before a restart) set
  /// it: if its time at the current end [endsAt] is still ahead and the phone
  /// still holds it unrung. One due or already rung is left alone, so it
  /// still rings and stays in the tray (cancelling removes it from there).
  Future<void> _schedule(
    String id,
    List<ReminderPlan> plans,
    DateTime endsAt,
    NotificationSettings settings,
  ) async {
    _scheduled.add(id);
    final kept = {for (final p in plans) p.id};
    final now = clock.now();
    Set<int>? pending; // asked of the phone only when needed
    for (var slot = 0; slot < 3; slot++) {
      final slotId = sessionAlertId(id, slot);
      if (kept.contains(slotId)) continue;
      final setFor = _ringsAt[slotId];
      var cancel = setFor != null && setFor.isAfter(now);
      if (!cancel &&
          !sessionAlertWanted(settings, slot) &&
          sessionAlertTime(endsAt, slot).isAfter(now)) {
        pending ??= (await service.pendingIds()).toSet();
        cancel = pending.contains(slotId);
      }
      if (cancel) {
        await service.cancel(slotId);
        _ringsAt.remove(slotId);
      }
    }
    for (final plan in plans) {
      await service.schedule(onDeviceClock(plan, clock));
      _ringsAt[plan.id] = plan.fireAtUtc;
    }
  }

  Future<void> _cancel(String sessionId) async {
    _scheduled.remove(sessionId);
    for (var slot = 0; slot < 3; slot++) {
      _ringsAt.remove(sessionAlertId(sessionId, slot));
    }
    try {
      await service.cancel(sessionAlertId(sessionId, 0));
      await service.cancel(sessionAlertId(sessionId, 1));
      await service.cancel(sessionAlertId(sessionId, 2));
    } catch (e) {
      debugPrint('SessionReminders.cancelFor($sessionId) failed: $e');
    }
  }
}
