/// The single source of "now" for the whole app.
///
/// Spec §7–8: timers are derived from timestamps, never from an incrementing
/// counter. The device clock may be wrong, so operational time flows through an
/// injectable [Clock] that can apply a server-time offset. Tests use [FakeClock].
///
/// Everything here returns **UTC** instants. IST is only applied for business
/// rules (see `core/time/`).
library;

import 'package:meta/meta.dart';

/// Returns the current instant in UTC.
abstract interface class Clock {
  DateTime now();
}

/// Real wall-clock time from the device, normalised to UTC.
class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now().toUtc();
}

/// A controllable clock for tests. Time only moves when you move it.
class FakeClock implements Clock {
  FakeClock(DateTime start) : _now = start.toUtc();
  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime t) => _now = t.toUtc();
  void advance(Duration d) => _now = _now.add(d);
}

/// Wraps a base clock and adds a measured offset so that operational time can
/// follow the server even when the device clock drifts.
///
/// [offset] = `serverNow - deviceNow`. When the device is ahead, offset is
/// negative; when behind, positive.
class OffsetClock implements Clock {
  OffsetClock(this._base, this.offset);
  final Clock _base;
  Duration offset;

  @override
  DateTime now() => _base.now().add(offset);
}

/// What the device's own clock says now — [clock] without any server
/// correction. Only for records that keep the phone's time as evidence next to
/// the server's (a terms acceptance's device_at); never for business rules.
DateTime deviceNow(Clock clock) => switch (clock) {
      OffsetClock(:final offset) => clock.now().subtract(offset),
      _ => clock.now(),
    };

/// The result of comparing device time to server time.
@immutable
class ClockOffset {
  const ClockOffset(this.value);
  const ClockOffset.none() : value = Duration.zero;

  /// `serverNow - deviceNow`.
  final Duration value;

  /// Spec §8: warn when the clock is off by more than two minutes.
  static const Duration threshold = Duration(minutes: 2);

  bool get isSignificant => value.abs() > threshold;

  /// The exact banner copy required by the spec.
  String get warning => 'Tablet clock is wrong. Timers use server time.';

  @override
  bool operator ==(Object other) => other is ClockOffset && other.value == value;
  @override
  int get hashCode => value.hashCode;
}
