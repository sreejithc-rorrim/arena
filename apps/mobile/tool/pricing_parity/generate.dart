// Pricing parity — case generator (the Dart side).
//
// Prices a deterministic set of cases with the app's own pricing code and
// writes them, with the expected money, as NDJSON for harness.sql to re-price
// on the server. The server's plpgsql pricing (`_pr_*`, incl. the pricing
// rules `_pr_rule` / `_pr_rule_price`) is a hand port of these Dart classes; this pair of files is what proves the two
// still agree, to the paisa.
//
//   dart run tool/pricing_parity/generate.dart [--random N] [--seed S]
//       [--skew-paise K]  > cases.ndjson
//
// Case kinds (field `k`):
//   q   PricingService.quote               one priced interval
//   x   SessionPlanner.planExtension       single-session extension cost
//   s   SegmentBilling.bill                multi-segment single session (end)
// Every s case also carries the wire-format charges the app sends with
// session.end, and a `waived` flag, so the harness can push the
// real ops through sync_push.
//
// `--skew-paise K` adds K paise to the expected money of the first priced
// case: the harness MUST then report a mismatch (proves it can fail).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/time/business_calendar.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/pricing/billing_policy.dart';
import 'package:arena_ops/domain/pricing/pricing_rule.dart';
import 'package:arena_ops/domain/pricing/pricing_service.dart';
import 'package:arena_ops/domain/pricing/pricing_snapshot.dart';
import 'package:arena_ops/domain/pricing/rate.dart';
import 'package:arena_ops/domain/services/segment_billing.dart';
import 'package:arena_ops/domain/services/session_planner.dart';
import 'package:arena_ops/domain/value/enums.dart';

/// Fixed station ids — harness.sql creates its throwaway arena with these, so
/// charge keys (which include the station) compare directly.
const stations = {
  'HEX': 'f0000000-0000-4000-8000-000000000001',
  'VOID': 'f0000000-0000-4000-8000-000000000002',
  'GHOST': 'f0000000-0000-4000-8000-000000000003',
  'RIFT': 'f0000000-0000-4000-8000-000000000004',
};

late Random rnd;
T pick<T>(List<T> l) => l[rnd.nextInt(l.length)];

const _open = DayWindow.hm(14, 0, 23, 0);

/// A pricing rule with server-shaped fields (ids are any text to the pricer).
PricingRule rule(String id, {String? name, int priority = 1, List<int> days = const [1, 2, 3, 4, 5, 6, 7],
        int start = 14 * 60, int end = 17 * 60, RuleHolidayMode holiday = RuleHolidayMode.any,
        IstDate? from, IstDate? until, List<String> acts = const [],
        RuleAdjustKind kind = RuleAdjustKind.percent, int value = -20}) =>
    PricingRule(id: id, name: name ?? 'Rule $id', priority: priority, days: days, startMin: start,
        endMin: end, holidayMode: holiday, validFrom: from, validUntil: until, activityCodes: acts,
        adjustKind: kind, adjustValue: value);

/// The seed catalog's prices (OWNER_CONFIRMATION) under [policy], with [rules].
PricingSnapshot seedSnapshot(BillingPolicy policy, {List<PricingRule> rules = const []}) =>
    PricingSnapshot(
      rateCardName: 'Current',
      rates: [
        for (final (cc, std) in [(1, 15000), (2, 28000), (3, 39000), (4, 48000)])
          Rate(activityCode: 'PS5', band: Band.standard, controllerCount: cc, unitMinutes: 60, price: Paise(std)),
        const Rate(activityCode: 'VR', band: Band.standard, controllerCount: null, unitMinutes: 30, price: Paise(20000)),
        const Rate(activityCode: 'POOL', band: Band.standard, controllerCount: null, unitMinutes: 60, price: Paise(27500)),
        const Rate(activityCode: 'LOUNGE', band: Band.standard, controllerCount: null, unitMinutes: 60, price: Paise(200000)),
      ],
      activities: const [
        ActivitySpec(code: 'PS5', durationModel: DurationModel.hourly),
        ActivitySpec(code: 'VR', durationModel: DurationModel.unit),
        ActivitySpec(code: 'POOL', durationModel: DurationModel.hourly),
        ActivitySpec(code: 'LOUNGE', durationModel: DurationModel.flatHourly),
      ],
      policy: policy,
      hours: BusinessHours(openByWeekday: {for (var d = 1; d <= 7; d++) d: _open}),
      holidays: {const IstDate(2026, 10, 2)},
      closedDays: const {},
      rules: rules,
    );

/// 0–3 random rules: both kinds and signs, windows biased to 14:00 / 17:00,
/// random days, holiday modes, validity dates, activity filters and
/// priority ties (broken by name, then id).
List<PricingRule> randomRules() {
  final n = pick([0, 0, 1, 1, 2, 3]);
  return [
    for (var i = 0; i < n; i++)
      () {
        final start = pick<int>([840, 840, 0, 13 * 60 + 30, rnd.nextInt(1380)]);
        final end = pick<int>([1020, 1020, 1440, start + 1 + rnd.nextInt(1440 - start)]);
        final kind = pick(RuleAdjustKind.values);
        return rule(
          'r${String.fromCharCode(97 + rnd.nextInt(3))}$i',
          name: pick(['Afternoons', 'Evenings', 'Afternoons']),
          priority: rnd.nextInt(3),
          days: [for (var d = 1; d <= 7; d++) if (rnd.nextInt(3) > 0) d],
          start: start,
          end: end > start ? end : 1440,
          holiday: pick(RuleHolidayMode.values),
          from: rnd.nextInt(4) == 0 ? IstDate(2026, 10, 5 + rnd.nextInt(5)) : null,
          until: rnd.nextInt(4) == 0 ? IstDate(2026, 10, 9 + rnd.nextInt(5)) : null,
          acts: pick([const <String>[], const ['PS5'], const ['PS5', 'POOL'], const ['VR', 'LOUNGE']]),
          kind: kind,
          value: kind == RuleAdjustKind.percent
              ? pick([-100, -50, -33, -20, -15, -1, 1, 7, 25, 333, 500])
              : pick([-10000000, -5000, -2500, -1234, -1, 1, 777, 2500, 5000]),
        );
      }(),
  ].where((r) => r.days.isNotEmpty).toList();
}

PricingSnapshot randomSnapshot() {
  final policy = BillingPolicy(
    billingUnit: pick(BillingUnit.values),
    blockRounding: pick(Rounding.values),
    graceMinutes: pick([0, 0, 0, 5, 10]),
    minimumChargeMinutes: pick([0, 0, 0, 30, 60]),
    roundingScope: pick(RoundingScope.values),
    vrUnitRounding: pick(VrUnitRounding.values),
    moneyRoundingPaise: pick([1, 100, 100, 500, 1000]),
    moneyRoundingDir: pick(MoneyRoundingDir.values),
  );
  final rates = <Rate>[];
  void add(String a, int? cc, int um, int price) {
    if (rnd.nextInt(10) == 0) return; // sometimes missing: unpriced paths
    rates.add(Rate(activityCode: a, band: Band.standard, controllerCount: cc, unitMinutes: um, price: Paise(price)));
  }
  for (var cc = 1; cc <= 4; cc++) {
    add('PS5', cc, 60, 10000 + cc * 4000 + rnd.nextInt(3) * 333);
  }
  add('VR', null, pick([30, 15, 20]), 25000 + rnd.nextInt(999));
  add('POOL', null, 60, 20000 + rnd.nextInt(77));
  add('LOUNGE', null, pick([60, 45]), 99900 + rnd.nextInt(13));
  final hours = BusinessHours(
    openByWeekday: {for (var d = 1; d <= 7; d++) d: d == 1 ? null : _open},
  );
  return PricingSnapshot(
    rateCardName: 'Current',
    rates: rates,
    activities: const [
      ActivitySpec(code: 'PS5', durationModel: DurationModel.hourly),
      ActivitySpec(code: 'VR', durationModel: DurationModel.unit),
      ActivitySpec(code: 'POOL', durationModel: DurationModel.hourly),
      ActivitySpec(code: 'LOUNGE', durationModel: DurationModel.flatHourly),
    ],
    policy: policy,
    hours: hours,
    holidays: {if (rnd.nextBool()) const IstDate(2026, 10, 7), const IstDate(2026, 10, 9)},
    closedDays: {if (rnd.nextBool()) const IstDate(2026, 10, 9)},
    rules: randomRules(),
  );
}

DateTime randomInstant() {
  // 2026-10-05 (Mon) .. 2026-10-12, biased near rule-window edges (14:00, 17:00).
  final base = DateTime.utc(2026, 10, 5, 8, 30); // 14:00 IST
  final day = rnd.nextInt(7);
  final minute = pick([0, -1, 1, 179, 180, 181, 600, rnd.nextInt(1440), rnd.nextInt(1440)]);
  return base.add(Duration(days: day, minutes: minute, seconds: rnd.nextInt(60),
      microseconds: rnd.nextInt(3) == 0 ? 0 : rnd.nextInt(1000000)));
}

Duration randomDuration() => pick([
      Duration.zero,
      Duration(seconds: rnd.nextInt(600)),
      Duration(minutes: rnd.nextInt(240), seconds: rnd.nextInt(60), microseconds: rnd.nextInt(1000000)),
      Duration(minutes: 30 * (1 + rnd.nextInt(8))),
      Duration(hours: 20 + rnd.nextInt(30), minutes: rnd.nextInt(60)),
    ]);

String iso(DateTime t) => t.toUtc().toIso8601String();

/// Same text as the server's _pr_charge_key.
String key(String act, String? res, int? cc, String band, DateTime s, DateTime e, int played,
        int billed, int um, int price, int amount) =>
    [act, res ?? '-', cc?.toString() ?? '-', band, s.microsecondsSinceEpoch, e.microsecondsSinceEpoch,
      played, billed, um, price, amount].join('|');

final out = <Map<String, dynamic>>[];
const pricing = PricingService();

void quoteCase(String label, PricingSnapshot snap, String act, int? cc, DateTime s, DateTime e,
    {DateTime? ruleAt}) {
  final v = pricing
      .quote(snapshot: snap, activityCode: act, controllerCount: cc, start: s, end: e, ruleAt: ruleAt)
      .valueOrNull;
  out.add({
    'k': 'q', 'label': label, 'snap': snap.toJson(), 'act': act, 'cc': cc, 's': iso(s), 'e': iso(e),
    // _pr_quote's p_rule_at (null = the quoted start).
    'rule_at': ruleAt == null ? null : iso(ruleAt),
    'exp': v == null
        ? null
        : {
            'subtotal': v.subtotal.value,
            'amount': v.amount.value,
            'keys': [
              for (final l in v.segments)
                key(act, null, cc, l.band.code, l.interval.start, l.interval.end, l.playedMinutes,
                    l.billedMinutes, l.unitMinutes, l.unitPrice.value, l.amount.value)
            ]..sort(),
          },
  });
}

void extensionCase(String label, PricingSnapshot snap, String act, int? cc, DateTime start,
    DateTime oldEnd, int addedMinutes) {
  // The real app path. No neighbours and a far close: only the price matters.
  final plan = const SessionPlanner().planExtension(
    snapshot: snap, activityCode: act, controllerCount: cc, resourceId: stations['HEX']!,
    startedAt: start, currentEnd: oldEnd, addedMinutes: addedMinutes, occupancies: const [],
    closeAt: oldEnd.add(const Duration(days: 3)));
  final p = plan.valueOrNull;
  if (p == null) return; // e.g. no rate: the app cannot extend, nothing to compare
  out.add({
    'k': 'x', 'label': label, 'snap': snap.toJson(), 'act': act, 'cc': cc, 'start': iso(start),
    'old_end': iso(p.oldEnd), 'new_end': iso(p.newEnd), 'added_minutes': addedMinutes,
    'added': p.addedCost.value,
  });
}

void sessionCase(String label, PricingSnapshot snap, DateTime start, DateTime end,
    List<SessionSegment> segs, {required bool waived}) {
  // The harness stores [start] as the session's started_at: the rule instant.
  final bill = const SegmentBilling().bill(snapshot: snap, segments: segs, openEndAt: end, sessionStart: start);
  out.add({
    'k': 's', 'label': label, 'snap': snap.toJson(), 'start': iso(start), 'end': iso(end),
    'waived': waived, 'unpriced': bill.unpriced.length,
    'segs': [
      for (final s in segs)
        {'idx': s.index, 'res': s.resourceId, 'act': s.activityCode, 'cc': s.controllerCount,
          's': iso(s.startedAt), 'e': s.endedAt == null ? null : iso(s.endedAt!)}
    ],
    'total': bill.total.value,
    'keys': [
      for (final c in bill.charges)
        key(c.activityCode, c.resourceId, c.controllerCount, c.bandCode, c.segmentStart,
            c.segmentEnd, c.playedMinutes, c.billedMinutes, c.unitMinutes, c.unitPricePaise,
            c.amountPaise)
    ]..sort(),
    // What session.end carries (LocalSessionRepository.chargeWire), minus ids
    // the harness assigns.
    'charges': [
      for (final c in bill.charges)
        {'seg_idx': int.parse(c.segmentId!.substring(3)), 'segment_index': c.segmentIndex,
          'band_code': c.bandCode, 'activity_code': c.activityCode, 'resource_id': c.resourceId,
          'controller_count': c.controllerCount, 'segment_start': iso(c.segmentStart),
          'segment_end': iso(c.segmentEnd), 'played_minutes': c.playedMinutes,
          'billed_minutes': c.billedMinutes, 'unit_minutes': c.unitMinutes,
          'unit_price_paise': c.unitPricePaise, 'amount_paise': c.amountPaise},
    ],
  });
}

// ------------------------------------------------------------ fixed corpus

/// Hand-picked boundaries that random sampling hits only by luck.
void boundaryCases() {
  // Mon 2026-10-05; 14:00 IST = 08:30 UTC, 17:00 IST = 11:30 UTC.
  final twoPm = DateTime.utc(2026, 10, 5, 8, 30);
  final fivePm = DateTime.utc(2026, 10, 5, 11, 30);
  const s1 = Duration(seconds: 1);

  // Every billing policy knob, at block / grace / minimum edges (no rules).
  for (final unit in BillingUnit.values) {
    for (final rounding in Rounding.values) {
      for (final (step, dir) in [(1, MoneyRoundingDir.nearest), (100, MoneyRoundingDir.nearest),
          (100, MoneyRoundingDir.up), (500, MoneyRoundingDir.nearest), (1000, MoneyRoundingDir.up)]) {
        final snap = seedSnapshot(BillingPolicy(
            billingUnit: unit, blockRounding: rounding, moneyRoundingPaise: step, moneyRoundingDir: dir));
        for (final d in [const Duration(minutes: 15), const Duration(minutes: 15) + s1,
            const Duration(minutes: 7, seconds: 30), const Duration(minutes: 22, seconds: 29),
            const Duration(minutes: 22, seconds: 30), const Duration(minutes: 59, seconds: 59),
            const Duration(hours: 1), const Duration(minutes: 61)]) {
          final at = fivePm.add(const Duration(hours: 1));
          quoteCase('policy ${unit.code}/${rounding.code}/$step-${dir.code} ${d.inSeconds}s',
              snap, 'PS5', 2, at, at.add(d));
        }
      }
    }
  }
  for (final grace in [0, 5]) {
    for (final minimum in [0, 30, 60]) {
      final snap = seedSnapshot(BillingPolicy(graceMinutes: grace, minimumChargeMinutes: minimum));
      for (final d in [const Duration(minutes: 4, seconds: 59), const Duration(minutes: 5),
          const Duration(minutes: 5) + s1, const Duration(minutes: 29, seconds: 59),
          const Duration(minutes: 30), const Duration(minutes: 60) + s1]) {
        final at = fivePm.add(const Duration(hours: 2));
        quoteCase('grace $grace min $minimum ${d.inSeconds}s', snap, 'POOL', null, at, at.add(d));
      }
    }
  }

  // ---- pricing rules (_pr_rule / _pr_rule_price) ----
  // Each adjustment kind and sign, on every activity, starting at the window
  // edges: ±1 min, and seconds just before them (the minute of day drops the
  // seconds, so 13:59:59 is still before 14:00).
  final adjustments = [
    (RuleAdjustKind.percent, -20), (RuleAdjustKind.percent, -15), (RuleAdjustKind.percent, 7),
    (RuleAdjustKind.percent, -100), (RuleAdjustKind.perHour, 2500), (RuleAdjustKind.perHour, -2500),
    (RuleAdjustKind.perHour, -1234), (RuleAdjustKind.perHour, 777), (RuleAdjustKind.perHour, -10000000),
  ];
  final edges = <(String, DateTime)>[
    ('13:59', twoPm.subtract(const Duration(minutes: 1))),
    ('13:59:30', twoPm.subtract(const Duration(seconds: 30))),
    ('13:59:59', twoPm.subtract(const Duration(seconds: 1))),
    ('14:00', twoPm),
    ('14:01', twoPm.add(const Duration(minutes: 1))),
    ('16:59', fivePm.subtract(const Duration(minutes: 1))),
    ('16:59:30', fivePm.subtract(const Duration(seconds: 30))),
    ('16:59:59', fivePm.subtract(const Duration(seconds: 1))),
    ('17:00', fivePm),
  ];
  for (final (kind, value) in adjustments) {
    final snap = seedSnapshot(BillingPolicy.defaults,
        rules: [rule('edge', kind: kind, value: value)]);
    for (final (name, at) in edges) {
      for (final (act, cc) in [('PS5', 2), ('POOL', null), ('VR', null), ('LOUNGE', null)]) {
        quoteCase('rule ${kind.code} $value start $name $act', snap, act, cc, at,
            at.add(const Duration(minutes: 47, seconds: 13)));
      }
    }
  }
  // Holiday modes on the holiday (Fri 2026-10-02) and a normal Friday.
  for (final mode in RuleHolidayMode.values) {
    final snap = seedSnapshot(BillingPolicy.defaults,
        rules: [rule('hol', holiday: mode, days: const [5])]);
    for (final day in [2, 9]) {
      final at = DateTime.utc(2026, 10, day, 9);
      quoteCase('rule holiday ${mode.code} Oct $day', snap, 'PS5', 1, at, at.add(const Duration(hours: 1)));
    }
  }
  // Valid dates: inclusive at both ends, judged on the IST date.
  for (final (from, until) in [
    (const IstDate(2026, 10, 5), null), (const IstDate(2026, 10, 6), null),
    (null, const IstDate(2026, 10, 5)), (null, const IstDate(2026, 10, 4)),
    (const IstDate(2026, 10, 5), const IstDate(2026, 10, 5)),
  ]) {
    final snap = seedSnapshot(BillingPolicy.defaults, rules: [rule('dates', from: from, until: until)]);
    quoteCase('rule valid ${from?.iso}..${until?.iso}', snap, 'POOL', null, twoPm, fivePm);
  }
  // IST midnight: a Tuesday-only rule from 00:00, around Mon 18:30 UTC.
  final midnight = seedSnapshot(BillingPolicy.defaults,
      rules: [rule('night', days: const [2], start: 0, end: 60, value: -50)]);
  for (final at in [DateTime.utc(2026, 10, 5, 18, 29, 29), DateTime.utc(2026, 10, 5, 18, 29, 30),
      DateTime.utc(2026, 10, 5, 18, 30), DateTime.utc(2026, 10, 5, 19, 29, 59)]) {
    quoteCase('rule IST midnight ${iso(at)}', midnight, 'PS5', 3, at, at.add(const Duration(minutes: 90)));
  }
  // Activity filter and priority: name, then id, break priority ties.
  final ordered = seedSnapshot(BillingPolicy.defaults, rules: [
    rule('b1', name: 'Beta', priority: 1, value: -10),
    rule('a1', name: 'Beta', priority: 1, value: -30),
    rule('c1', name: 'Alpha', priority: 2, value: 50),
    rule('d1', name: 'Alpha', priority: 0, value: 25, acts: const ['VR']),
  ]);
  for (final (act, cc) in [('PS5', 1), ('VR', null), ('POOL', null)]) {
    quoteCase('rule priority/name/id $act', ordered, act, cc, twoPm, twoPm.add(const Duration(hours: 1)));
  }
  // The rule instant is the session start, not the quoted start.
  final std = seedSnapshot(BillingPolicy.defaults, rules: [rule('late')]);
  quoteCase('rule judged at an earlier session start', std, 'PS5', 4, fivePm.add(const Duration(hours: 1)),
      fivePm.add(const Duration(hours: 2)), ruleAt: fivePm.subtract(const Duration(minutes: 1)));
  quoteCase('rule at 16:59:59 rounds to 17:00 (no rule)', std, 'PS5', 4, fivePm,
      fivePm.add(const Duration(hours: 1)), ruleAt: fivePm.subtract(s1));
  quoteCase('rule not judged at the quoted start', std, 'PS5', 4, twoPm,
      twoPm.add(const Duration(hours: 1)), ruleAt: fivePm);

  // VR unit rounding at unit boundaries, with and without a rule.
  for (final r in VrUnitRounding.values) {
    for (final rules in [const <PricingRule>[], [rule('vr', kind: RuleAdjustKind.perHour, value: -1234)]]) {
      final snap = seedSnapshot(BillingPolicy(vrUnitRounding: r), rules: rules);
      for (final m in [1, 14, 15, 16, 29, 30, 31, 45, 59, 60]) {
        final at = twoPm.add(const Duration(minutes: 30));
        quoteCase('VR ${r.code} $m min rules=${rules.length}', snap, 'VR', null, at, at.add(Duration(minutes: m)));
      }
    }
  }
  // Lounge flat-hourly.
  final plain = seedSnapshot(BillingPolicy.defaults);
  for (final m in [1, 59, 60, 61, 120]) {
    final at = fivePm.add(const Duration(hours: 1));
    quoteCase('LOUNGE $m min', plain, 'LOUNGE', null, at, at.add(Duration(minutes: m)));
  }
  // Extensions of a session started in the rule window, past its end, and
  // plain ones.
  for (final added in [15, 30, 60]) {
    extensionCase('extend PS5 +$added from inside the window', std, 'PS5', 2,
        fivePm.subtract(const Duration(hours: 1)), fivePm.subtract(const Duration(minutes: 10)), added);
    extensionCase('extend POOL +$added', plain, 'POOL', null, fivePm, fivePm.add(const Duration(hours: 1)), added);
  }
  // A 3-segment session started inside the window, switching station and
  // controllers after it ends, ended normally and waived, under segment- and
  // session-scoped rounding; with and without the rule.
  for (final scope in RoundingScope.values) {
    for (final rules in [const <PricingRule>[], [rule('seg', kind: RuleAdjustKind.perHour, value: -2500)]]) {
      final snap = seedSnapshot(BillingPolicy(roundingScope: scope, billingUnit: BillingUnit.block15), rules: rules);
      final t0 = fivePm.subtract(const Duration(minutes: 50));
      final t1 = t0.add(const Duration(minutes: 37, seconds: 13));
      final t2 = t1.add(const Duration(minutes: 22, seconds: 1));
      final end = t2.add(const Duration(minutes: 41));
      final segs = [
        SessionSegment(id: 'seg0', sessionId: 's', index: 0, resourceId: stations['HEX']!, activityCode: 'PS5',
            controllerCount: 2, startedAt: t0, endedAt: t1, createdAt: t0),
        SessionSegment(id: 'seg1', sessionId: 's', index: 1, resourceId: stations['VOID']!, activityCode: 'PS5',
            controllerCount: 3, startedAt: t1, endedAt: t2, createdAt: t0),
        SessionSegment(id: 'seg2', sessionId: 's', index: 2, resourceId: stations['VOID']!, activityCode: 'PS5',
            controllerCount: 1, startedAt: t2, createdAt: t0),
      ];
      for (final waived in [false, true]) {
        sessionCase('3 segments ${scope.code} rules=${rules.length} waived=$waived', snap, t0, end, segs,
            waived: waived);
      }
    }
  }
}

// ----------------------------------------------------------- random corpus

void randomCases(int n) {
  for (var i = 0; i < n; i++) {
    final snap = randomSnapshot();
    final act = pick(['PS5', 'PS5', 'VR', 'POOL', 'LOUNGE']);
    final cc = act == 'PS5' ? 1 + rnd.nextInt(4) : null;
    final s = randomInstant();
    switch (i % 4) {
      case 0 || 1:
        final e = rnd.nextInt(25) == 0 ? s.subtract(const Duration(minutes: 1)) : s.add(randomDuration());
        // Sometimes priced as a later segment of a session that began earlier.
        final ruleAt = rnd.nextInt(3) == 0 ? s.subtract(Duration(minutes: rnd.nextInt(300))) : null;
        quoteCase('random q$i', snap, act, cc, s, e, ruleAt: ruleAt);
      case 2:
        extensionCase('random x$i', snap, act, cc, s,
            s.add(Duration(minutes: 1 + rnd.nextInt(240), seconds: rnd.nextInt(60))),
            pick([15, 30, 45, 60, 90]));
      default:
        final end = s.add(Duration(minutes: 1 + rnd.nextInt(300), microseconds: rnd.nextInt(999999)));
        DateTime between() => s.add(Duration(
            microseconds: (end.difference(s).inMicroseconds * rnd.nextDouble()).floor()));
        final count = 1 + rnd.nextInt(4);
        final cuts = [for (var j = 0; j < count - 1; j++) between()]..sort();
        final bounds = [s, ...cuts, end];
        final segs = <SessionSegment>[];
        final names = stations.keys.toList();
        for (var j = 0; j < count; j++) {
          final a = pick(['PS5', 'PS5', 'VR', 'POOL']);
          segs.add(SessionSegment(
            id: 'seg$j', sessionId: 's', index: j, resourceId: stations[pick(names)]!,
            activityCode: a, controllerCount: a == 'PS5' ? 1 + rnd.nextInt(4) : null,
            startedAt: bounds[j], endedAt: j == count - 1 ? null : bounds[j + 1], createdAt: s));
        }
        sessionCase('random s$i', snap, s, end, segs, waived: rnd.nextInt(4) == 0);
    }
  }
}

void main(List<String> args) {
  int opt(String name, int fallback) {
    final i = args.indexOf(name);
    return i < 0 ? fallback : int.parse(args[i + 1]);
  }

  rnd = Random(opt('--seed', 20261011));
  boundaryCases();
  randomCases(opt('--random', 3000));

  final skew = opt('--skew-paise', 0);
  if (skew != 0) {
    // Corrupt one expectation by [skew] paise: the harness must catch it.
    final c = out.firstWhere((c) => c['k'] == 's' && (c['total'] as int) > 0);
    c['total'] = (c['total'] as int) + skew;
    c['label'] = '${c['label']} (SKEWED +$skew paise)';
  }
  final sink = stdout;
  for (final c in out) {
    sink.writeln(jsonEncode(c));
  }
}
