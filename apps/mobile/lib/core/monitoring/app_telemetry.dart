import 'package:flutter/foundation.dart';

/// Centralized, privacy-safe instrumentation and telemetry for ARQ.
///
/// Crash reporting (Sentry) is removed for now: breadcrumbs are dropped and
/// timer anomalies and unexpected exceptions only go to the debug log. The
/// call sites stay so a reporter can be plugged back in here. Never logs
/// customer names, phone numbers, staff PINs, auth tokens, or payment
/// credentials.
class AppTelemetry {
  const AppTelemetry._();

  /// Adds a sanitized breadcrumb (no-op while no reporter is wired in).
  static void addBreadcrumb({
    required String category,
    required String message,
    Map<String, dynamic>? data,
  }) {}

  /// Records the start of a session timer.
  static void timerStarted({
    required String sessionId,
    required String resourceId,
    required String activityCode,
    int? durationMinutes,
    int? controllerCount,
  }) {
    addBreadcrumb(
      category: 'timer',
      message: 'timer_started',
      data: {
        'sessionId': sessionId,
        'resourceId': resourceId,
        'activityCode': activityCode,
        'durationMinutes': ?durationMinutes,
        'controllerCount': ?controllerCount,
      },
    );
  }

  /// Records the completion of a session timer and actual billing.
  static void timerStopped({
    required String sessionId,
    required String resourceId,
    required int billedAmountPaise,
    required Duration playedDuration,
  }) {
    addBreadcrumb(
      category: 'timer',
      message: 'timer_stopped',
      data: {
        'sessionId': sessionId,
        'resourceId': resourceId,
        'billedAmountPaise': billedAmountPaise,
        'playedSeconds': playedDuration.inSeconds,
        'playedMinutes': playedDuration.inMinutes,
      },
    );
  }

  /// Records an in-session configuration switch (station, game, or controllers).
  static void sessionSwitched({
    required String sessionId,
    required String operation,
    required String fromResourceId,
    required String toResourceId,
    String? gameId,
    int? controllerCount,
  }) {
    addBreadcrumb(
      category: 'session',
      message: 'session_switched',
      data: {
        'sessionId': sessionId,
        'operation': operation,
        'fromResourceId': fromResourceId,
        'toResourceId': toResourceId,
        'gameId': ?gameId,
        'controllerCount': ?controllerCount,
      },
    );
  }

  /// Records a computed bill across one or more segments.
  static void billingCalculated({
    required String sessionId,
    required int totalPaise,
    required int segmentCount,
    required int totalSeconds,
    bool isLive = false,
  }) {
    addBreadcrumb(
      category: 'billing',
      message: isLive ? 'live_bill_calculated' : 'billing_calculated',
      data: {
        'sessionId': sessionId,
        'totalPaise': totalPaise,
        'segmentCount': segmentCount,
        'totalSeconds': totalSeconds,
      },
    );
  }

  /// Records staff authentication events (sanitized, no PINs or credentials).
  static void staffAuth({
    required String operation,
    required String userId,
    bool success = true,
  }) {
    addBreadcrumb(
      category: 'auth',
      message: 'staff_$operation',
      data: {'userId': userId, 'success': success},
    );
  }

  /// Records booking lifecycle events without customer personal information.
  static void bookingOperation({
    required String bookingId,
    required String operation,
    String? resourceId,
    String? activityCode,
  }) {
    addBreadcrumb(
      category: 'booking',
      message: 'booking_$operation',
      data: {
        'bookingId': bookingId,
        'resourceId': ?resourceId,
        'activityCode': ?activityCode,
      },
    );
  }

  /// Reports impossible timer state transitions or corrupted timestamps.
  static void reportTimerAnomaly({
    required String sessionId,
    required String anomaly,
    required String resourceId,
    required DateTime startedAt,
    DateTime? scheduledEndAt,
    DateTime? actualEndedAt,
  }) {
    debugPrint(
      'Session timer anomaly: $anomaly '
      '(session $sessionId, resource $resourceId, '
      'started ${startedAt.toIso8601String()}, '
      'scheduled end ${scheduledEndAt?.toIso8601String()}, '
      'ended ${actualEndedAt?.toIso8601String()})',
    );
  }

  /// Logs an unexpected application exception with sanitized context.
  static Future<void> captureException(
    dynamic throwable, {
    dynamic stackTrace,
    String? operation,
    Map<String, dynamic>? extra,
  }) async {
    debugPrint(
      'Unexpected error${operation == null ? '' : ' in $operation'}: '
      '$throwable${extra == null || extra.isEmpty ? '' : ' $extra'}\n'
      '${stackTrace ?? ''}',
    );
  }
}
