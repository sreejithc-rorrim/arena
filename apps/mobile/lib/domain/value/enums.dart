/// Domain enumerations shared across pricing, rules and entities.
///
/// Kept as plain Dart enums (no codegen) so the pure pricing engine has zero
/// build dependencies. Each maps to the text values used in the Postgres schema.
library;

/// Pricing band of a rate and of a charge row. The pricer always looks rates
/// up at [standard]; time-of-day prices are pricing rules (`PricingRule`), not
/// bands. Rates or charges stored with any other (retired) band code are kept
/// as data but never priced.
enum Band {
  standard;

  String get code => name;
  static Band fromCode(String c) => Band.values.firstWhere((b) => b.code == c);

  /// The band for [c], or null for a retired band code.
  static Band? tryFromCode(String c) {
    for (final b in Band.values) {
      if (b.code == c) return b;
    }
    return null;
  }
}

/// How an activity's time becomes money.
enum DurationModel {
  /// Priced per hour (rate.unitMinutes == 60). PS5, Pool.
  hourly,

  /// Priced in fixed blocks (rate.unitMinutes e.g. 30). VR.
  unit,

  /// Flat hourly, a single bundled resource. Lounge.
  flatHourly;

  String get code => switch (this) {
        DurationModel.hourly => 'hourly',
        DurationModel.unit => 'unit',
        DurationModel.flatHourly => 'flat_hourly',
      };

  static DurationModel fromCode(String c) => switch (c) {
        'hourly' => DurationModel.hourly,
        'unit' => DurationModel.unit,
        'flat_hourly' => DurationModel.flatHourly,
        _ => throw ArgumentError('Unknown duration_model: $c'),
      };
}

/// Partial-time billing granularity (OWNER CONFIRMATION #1).
enum BillingUnit {
  perMinute,
  block15,
  block30,
  block60;

  /// Block size in minutes, or null for per-minute.
  int? get blockMinutes => switch (this) {
        BillingUnit.perMinute => null,
        BillingUnit.block15 => 15,
        BillingUnit.block30 => 30,
        BillingUnit.block60 => 60,
      };

  String get code => switch (this) {
        BillingUnit.perMinute => 'per_minute',
        BillingUnit.block15 => 'block_15',
        BillingUnit.block30 => 'block_30',
        BillingUnit.block60 => 'block_60',
      };

  static BillingUnit fromCode(String c) => switch (c) {
        'per_minute' => BillingUnit.perMinute,
        'block_15' => BillingUnit.block15,
        'block_30' => BillingUnit.block30,
        'block_60' => BillingUnit.block60,
        _ => throw ArgumentError('Unknown billing_unit: $c'),
      };
}

/// Rounding direction for block/unit counts (OWNER CONFIRMATION #2).
enum Rounding {
  up,
  nearest;

  String get code => name;
  static Rounding fromCode(String c) => Rounding.values.firstWhere((r) => r.code == c);
}

/// Where per-unit price math is rounded to whole paise (OWNER CONFIRMATION #7).
enum RoundingScope {
  session,
  segment;

  String get code => name;
  static RoundingScope fromCode(String c) =>
      RoundingScope.values.firstWhere((r) => r.code == c);
}

/// VR partial-unit billing (OWNER CONFIRMATION #12).
enum VrUnitRounding {
  up,
  nearest,
  prorate;

  String get code => name;
  static VrUnitRounding fromCode(String c) =>
      VrUnitRounding.values.firstWhere((r) => r.code == c);
}

/// Early-exit billing basis (OWNER CONFIRMATION #5).
enum EarlyExit {
  actual,
  planned;

  String get code => name;
  static EarlyExit fromCode(String c) =>
      EarlyExit.values.firstWhere((r) => r.code == c);
}

/// Late-arrival billing basis (OWNER CONFIRMATION #8).
enum LateArrival {
  actual,
  planned;

  String get code => name;
  static LateArrival fromCode(String c) =>
      LateArrival.values.firstWhere((r) => r.code == c);
}

/// Final cash rounding direction (OWNER CONFIRMATION #16).
enum MoneyRoundingDir {
  nearest,
  up;

  String get code => name;
  static MoneyRoundingDir fromCode(String c) =>
      MoneyRoundingDir.values.firstWhere((r) => r.code == c);
}

/// When payment may be recorded (OWNER CONFIRMATION #17).
enum PaymentTiming {
  either,
  atStart,
  atEnd;

  String get code => switch (this) {
        PaymentTiming.either => 'either',
        PaymentTiming.atStart => 'start',
        PaymentTiming.atEnd => 'end',
      };

  static PaymentTiming fromCode(String c) => switch (c) {
        'either' => PaymentTiming.either,
        'start' => PaymentTiming.atStart,
        'end' => PaymentTiming.atEnd,
        _ => throw ArgumentError('Unknown payment_timing: $c'),
      };
}

/// Session lifecycle (spec §9). Overtime is NOT a status.
enum SessionStatus {
  active,
  completed,
  voided;

  String get code => name;
  static SessionStatus fromCode(String c) =>
      SessionStatus.values.firstWhere((s) => s.code == c);
}

/// Payment rollup (spec §9).
enum PaymentStatus {
  unpaid,
  partial,
  paid,
  waived;

  String get code => name;
  static PaymentStatus fromCode(String c) =>
      PaymentStatus.values.firstWhere((s) => s.code == c);
}

/// Payment method (spec §19).
enum PaymentMethod {
  cash,
  upi,
  card,
  other;

  String get code => name;

  String get label => switch (this) {
        PaymentMethod.upi => 'UPI',
        PaymentMethod.cash => 'Cash',
        PaymentMethod.card => 'Card',
        PaymentMethod.other => 'Other',
      };
  static PaymentMethod fromCode(String c) =>
      PaymentMethod.values.firstWhere((m) => m.code == c);
}

/// Booking lifecycle (spec §18, §22–§23).
enum BookingStatus {
  booked,
  checkedIn,
  cancelled,
  noShow;

  String get code => switch (this) {
        BookingStatus.booked => 'booked',
        BookingStatus.checkedIn => 'checked_in',
        BookingStatus.cancelled => 'cancelled',
        BookingStatus.noShow => 'no_show',
      };

  static BookingStatus fromCode(String c) => switch (c) {
        'booked' => BookingStatus.booked,
        'checked_in' => BookingStatus.checkedIn,
        'cancelled' => BookingStatus.cancelled,
        'no_show' => BookingStatus.noShow,
        _ => throw ArgumentError('Unknown booking status: $c'),
      };
}

/// Whether a device reminder is currently in place for a booking (spec §23).
/// Reminders are scheduled on the device, so this records intent — the
/// notification itself lives in the OS scheduler.
enum ReminderStatus {
  /// A reminder is scheduled to fire before the booking starts.
  scheduled,

  /// Deliberately silenced for this booking.
  off,

  /// The lead time had already passed when the booking was made, so no
  /// reminder could be scheduled.
  missed,

  /// The booking is done with (checked in / cancelled) and nothing is pending.
  done;

  String get code => name;

  String get label => switch (this) {
        ReminderStatus.scheduled => 'Reminder on',
        ReminderStatus.off => 'No reminder',
        ReminderStatus.missed => 'Too late to remind',
        ReminderStatus.done => 'Reminder cleared',
      };

  static ReminderStatus fromCode(String c) =>
      ReminderStatus.values.firstWhere(
        (s) => s.code == c,
        orElse: () => ReminderStatus.scheduled,
      );
}

/// One way a game can be played (spec §3; server games.play_modes). A game has
/// one or more, kept in this order.
enum PlayerMode {
  story,
  single,
  local,
  online;

  String get code => name;

  String get label => switch (this) {
        PlayerMode.story => 'Story Mode',
        PlayerMode.single => 'Single Player',
        PlayerMode.local => 'Local Multiplayer',
        PlayerMode.online => 'Online Multiplayer',
      };

  /// Stored codes as modes, in enum order. Codes this build does not know are
  /// skipped; a game always has at least one mode (single when none is left).
  static List<PlayerMode> fromCodes(Iterable<String> codes) {
    final known = [
      for (final m in PlayerMode.values)
        if (codes.contains(m.code)) m,
    ];
    return known.isEmpty ? const [PlayerMode.single] : known;
  }

  /// "Story Mode · Local Multiplayer".
  static String labelOf(List<PlayerMode> modes) =>
      modes.map((m) => m.label).join(' · ');
}

/// Whether a specific game can run on a specific resource (spec §4). A game is
/// never globally available — absence of a row means [notInstalled].
enum GameAvailability {
  playable,
  notPlayable,
  notInstalled,
  maintenance,
  temporarilyUnavailable;

  /// True only when a session may actually use this game on this resource.
  bool get isPlayable => this == GameAvailability.playable;

  String get code => switch (this) {
        GameAvailability.playable => 'playable',
        GameAvailability.notPlayable => 'not_playable',
        GameAvailability.notInstalled => 'not_installed',
        GameAvailability.maintenance => 'maintenance',
        GameAvailability.temporarilyUnavailable => 'temporarily_unavailable',
      };

  String get label => switch (this) {
        GameAvailability.playable => 'Playable',
        GameAvailability.notPlayable => 'Not playable',
        GameAvailability.notInstalled => 'Not installed',
        GameAvailability.maintenance => 'Maintenance',
        GameAvailability.temporarilyUnavailable => 'Temporarily unavailable',
      };

  static GameAvailability fromCode(String c) => switch (c) {
        'playable' => GameAvailability.playable,
        'not_playable' => GameAvailability.notPlayable,
        'not_installed' => GameAvailability.notInstalled,
        'maintenance' => GameAvailability.maintenance,
        'temporarily_unavailable' => GameAvailability.temporarilyUnavailable,
        _ => throw ArgumentError('Unknown game availability: $c'),
      };
}

/// How a pricing rule treats the snapshot's public holidays (server
/// `pricing_rules.holiday_mode`).
enum RuleHolidayMode {
  /// Holidays do not matter.
  any,

  /// Applies only on a listed holiday.
  only,

  /// Never applies on a listed holiday.
  skip;

  String get code => name;
  static RuleHolidayMode fromCode(String c) =>
      RuleHolidayMode.values.firstWhere((m) => m.code == c);
}

/// How a pricing rule changes a unit price (server `pricing_rules.adjust_kind`).
enum RuleAdjustKind {
  /// unit price × (100 + value) / 100, rounded half up.
  percent,

  /// unit price + value paise per hour, pro rata to the rate's unit.
  perHour;

  String get code => switch (this) {
        RuleAdjustKind.percent => 'percent',
        RuleAdjustKind.perHour => 'per_hour',
      };

  static RuleAdjustKind fromCode(String c) =>
      RuleAdjustKind.values.firstWhere((k) => k.code == c);
}
