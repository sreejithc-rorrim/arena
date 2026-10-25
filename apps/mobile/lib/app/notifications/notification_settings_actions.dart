/// This phone's alert settings, for whoever uses it (staff included: they
/// are device-local, never synced, and change no arena record — so no
/// permission is checked). Saving moves the alerts already set for running
/// sessions at once; turning alerts on asks the phone for permission.
library;

import 'package:arena_ops/app/notifications/device_time.dart';
import 'package:arena_ops/app/notifications/session_reminders.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/notifications/notification_service.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/domain/notifications/notification_settings.dart';
import 'package:arena_ops/domain/notifications/reminder_plan.dart';
import 'package:arena_ops/domain/repositories/notification_settings_repository.dart';
import 'package:flutter/foundation.dart';

class NotificationSettingsActions {
  NotificationSettingsActions({
    required this.service,
    required this.settings,
    required this.sessionReminders,
    required this.clock,
  });

  final NotificationService service;
  final NotificationSettingsRepository settings;
  final SessionReminders sessionReminders;
  final Clock clock;

  /// Store [next] for this phone, then rebuild the alerts of every running
  /// session with it: one turned off stops ringing, sound and
  /// vibration change on those already set. Switching timer alerts on asks
  /// for permission when the phone does not allow notifications yet.
  Future<Result<NotificationSettings>> save(NotificationSettings next) async {
    final NotificationSettings before;
    try {
      before = await settings.getSettings();
      await settings.saveSettings(next);
    } catch (e) {
      debugPrint('notification settings save failed: $e');
      return const Err(
        Failure(
          message: "The alert settings couldn't be saved on this phone.",
          fix: 'Try again.',
          code: 'notification_settings_not_saved',
        ),
      );
    }
    if (next.enabled &&
        !before.enabled &&
        await service.notificationsAllowed() != true) {
      await service.requestPermission();
    }
    await sessionReminders.reconcile();
    return Ok(next);
  }

  /// Ask the phone to allow notifications. True when it does.
  Future<bool> allowNotifications() => service.requestPermission();

  /// Android's "Alarms & reminders", so alerts ring on the minute.
  Future<bool> allowExactAlarms() => service.requestExactAlarms();

  /// The phone's own settings for this app, once it no longer asks.
  Future<bool> openPhoneSettings() => service.openSystemSettings();

  /// A test alert a few seconds from now that rings like "time up" with the
  /// current settings, so the person can lock the phone and hear it.
  Future<void> sendTestAlert() async {
    var current = const NotificationSettings();
    try {
      current = await settings.getSettings();
    } catch (e) {
      debugPrint('notification settings read failed: $e');
    }
    final plan = buildTestAlert(now: clock.now(), settings: current);
    await service.schedule(onDeviceClock(plan, clock));
  }
}
