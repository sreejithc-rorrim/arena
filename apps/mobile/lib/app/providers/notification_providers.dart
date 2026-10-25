/// Riverpod wiring for booking reminders and session timer alerts (spec §23).
library;

import 'package:arena_ops/app/notifications/booking_reminders.dart';
import 'package:arena_ops/app/notifications/notification_settings_actions.dart';
import 'package:arena_ops/app/notifications/session_reminders.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/notifications/notification_service.dart';
import 'package:arena_ops/data/local/local_notification_settings_repository.dart';
import 'package:arena_ops/domain/notifications/notification_settings.dart';
import 'package:arena_ops/domain/repositories/notification_settings_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The device notification service. Real implementation by default; overridden
/// with [NoopNotificationService] in tests so no platform channel is touched.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => LocalNotificationService(),
);

/// Repository for persisting notification preferences (sound, vibration, intervals).
final notificationSettingsRepositoryProvider =
    Provider<NotificationSettingsRepository>(
      (ref) => LocalNotificationSettingsRepository(ref.watch(databaseProvider)),
    );

/// Live stream of notification settings (vibration enabled, alerts, etc.).
final notificationSettingsProvider = StreamProvider<NotificationSettings>(
  (ref) => ref.watch(notificationSettingsRepositoryProvider).watchSettings(),
);

/// What the phone lets this app do. Each field is null when the platform does
/// not say (exact alarms: always on iOS).
typedef NotificationAccess = ({bool? allowed, bool? exactAlarms});

/// [NotificationAccess] as the phone reports it now. Read again whenever the
/// app comes back to the foreground — the person may have just changed it in
/// the phone's settings — and invalidate it after asking for a permission.
final notificationAccessProvider =
    FutureProvider.autoDispose<NotificationAccess>((ref) async {
      final resumed = AppLifecycleListener(onResume: ref.invalidateSelf);
      ref.onDispose(resumed.dispose);
      final service = ref.watch(notificationServiceProvider);
      return (
        allowed: await service.notificationsAllowed(),
        exactAlarms: await service.exactAlarmsAllowed(),
      );
    });

/// Coordinates scheduling/cancelling booking reminders.
final bookingRemindersProvider = Provider<BookingReminders>(
  (ref) => BookingReminders(
    service: ref.watch(notificationServiceProvider),
    bookings: ref.watch(bookingRepositoryProvider),
    customers: ref.watch(customerRepositoryProvider),
    catalog: ref.watch(catalogRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Coordinates scheduling/cancelling session timer alerts (5m, 1m, and expired).
final sessionRemindersProvider = Provider<SessionReminders>(
  (ref) => SessionReminders(
    service: ref.watch(notificationServiceProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    customers: ref.watch(customerRepositoryProvider),
    catalog: ref.watch(catalogRepositoryProvider),
    settingsRepo: ref.watch(notificationSettingsRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Changes this phone's alert settings and asks for its permissions.
final notificationSettingsActionsProvider =
    Provider<NotificationSettingsActions>(
      (ref) => NotificationSettingsActions(
        service: ref.watch(notificationServiceProvider),
        settings: ref.watch(notificationSettingsRepositoryProvider),
        sessionReminders: ref.watch(sessionRemindersProvider),
        clock: ref.watch(clockProvider),
      ),
    );
