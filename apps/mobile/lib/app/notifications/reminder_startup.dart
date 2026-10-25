/// Device alerts at app start and whenever the data under them changes.
library;

import 'package:arena_ops/app/providers/notification_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App start: ask once for permission to notify (Android 13+ and iOS post
/// nothing without it), then [refreshReminders] with the start-up sweep.
Future<void> startReminders(ProviderContainer container) async {
  try {
    final service = container.read(notificationServiceProvider);
    await service.init();
    await service.requestPermission();
  } catch (e) {
    debugPrint('notification permission skipped: $e');
  }
  await refreshReminders(container, sweep: true);
}

/// Rebuilds every scheduled alert from this device's database: the reminders
/// of every upcoming booking and a timer alert set for every running session.
/// A session started, extended, moved or ended — here, on another
/// device or while the app was closed — rings at its current end time, and an
/// ended one no longer rings. Alerts are replaced in place (same ids), never
/// cancelled first, so one falling due during the rebuild still rings.
///
/// [sweep] (start-up): afterwards, cancel whatever an earlier run left
/// scheduled that is no longer wanted. Never throws: alerts must not break the
/// app.
Future<void> refreshReminders(
  ProviderContainer container, {
  bool sweep = false,
}) async {
  try {
    final bookings = container.read(bookingRemindersProvider);
    final sessions = container.read(sessionRemindersProvider);
    final bookingsDone = await bookings.reconcile();
    final sessionsDone = await sessions.reconcile();
    // A rebuild that failed part-way does not know what is wanted: sweeping
    // then would cancel good alerts of sessions still running.
    if (!sweep || !bookingsDone || !sessionsDone) return;
    final service = container.read(notificationServiceProvider);
    // With no reminder change in between (an edit cancels, then reschedules).
    await bookings.exclusive(
      () => sessions.exclusive(() async {
        final wanted = {...bookings.scheduledIds, ...sessions.scheduledIds};
        for (final id in await service.pendingIds()) {
          if (!wanted.contains(id)) await service.cancel(id);
        }
      }),
    );
  } catch (e) {
    debugPrint('reminder refresh skipped: $e');
  }
}
