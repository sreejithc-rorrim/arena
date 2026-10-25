/// Pricing rules (server `_pr_rule` / `_pr_rule_price`): which rule applies,
/// judged once at the session's start in IST, and how it changes
/// every unit price of the quote.
library;

import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/pricing/pricing_quote.dart';
import 'package:arena_ops/domain/pricing/pricing_rule.dart';
import 'package:arena_ops/domain/pricing/pricing_service.dart';
import 'package:arena_ops/domain/pricing/pricing_snapshot.dart';
import 'package:arena_ops/domain/pricing/rule_engine.dart';
import 'package:arena_ops/domain/services/segment_billing.dart';
import 'package:arena_ops/domain/services/session_planner.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pricing_fixtures.dart';

void main() {
  const pricing = PricingService();

  PricingQuote quote(
    PricingSnapshot snap,
    String activity,
    int? cc,
    DateTime s,
    DateTime e, {
    DateTime? ruleAt,
  }) {
    final r = pricing.quote(
      snapshot: snap,
      activityCode: activity,
      controllerCount: cc,
      start: s,
      end: e,
      ruleAt: ruleAt,
    );
    expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    return r.valueOrNull!;
  }

  /// One PS5 hour, 1 controller (₹150 standard), starting at [s].
  int ps5Hour(List<PricingRule> rules, DateTime s, {Set<IstDate> holidays = const {}}) =>
      quote(currentSnapshot(rules: rules, holidays: holidays), 'PS5', 1, s,
              s.add(const Duration(hours: 1)))
          .amount
          .value;

  group('window [start_min, end_min) judged at the start (Friday)', () {
    final rules = [afternoonRule()];
    test('13:59 → no rule', () => expect(ps5Hour(rules, ist(2026, 10, 2, 13, 59)), 15000));
    test('14:00 → rule', () => expect(ps5Hour(rules, ist(2026, 10, 2, 14, 0)), 12000));
    test('14:01 → rule', () => expect(ps5Hour(rules, ist(2026, 10, 2, 14, 1)), 12000));
    test('16:59 → rule for the WHOLE hour, past 17:00', () {
      final q = quote(currentSnapshot(rules: rules), 'PS5', 1, ist(2026, 10, 2, 16, 59),
          ist(2026, 10, 2, 17, 59));
      expect(q.amount.value, 12000);
      expect(q.segments, hasLength(1), reason: 'no split at the window end');
    });
    test('17:00 → no rule (end is exclusive)', () {
      expect(ps5Hour(rules, ist(2026, 10, 2, 17, 0)), 15000);
    });
    test('17:01 → no rule', () => expect(ps5Hour(rules, ist(2026, 10, 2, 17, 1)), 15000));
  });

  group('minute of day drops the seconds, as the server does', () {
    // `_pr_rule` floors (seconds since IST midnight / 60): 13:59:59 is
    // still minute 839, before a 14:00 start.
    final rules = [afternoonRule()];
    DateTime at(int h, int m, int s) => ist(2026, 10, 2, h, m).add(Duration(seconds: s));
    test('13:59:30 → 839, no rule', () => expect(ps5Hour(rules, at(13, 59, 30)), 15000));
    test('13:59:59 → 839, no rule', () => expect(ps5Hour(rules, at(13, 59, 59)), 15000));
    test('16:59:30 → 1019, rule', () => expect(ps5Hour(rules, at(16, 59, 30)), 12000));
    test('16:59:59 → 1019, rule', () => expect(ps5Hour(rules, at(16, 59, 59)), 12000));
    test('ruleMinuteOfDay', () {
      expect(ruleMinuteOfDay(at(0, 0, 0)), 0);
      expect(ruleMinuteOfDay(at(13, 59, 59).add(const Duration(microseconds: 999999))), 839);
      expect(ruleMinuteOfDay(at(14, 0, 0)), 840);
      expect(ruleMinuteOfDay(at(23, 59, 59)), 1439);
    });
  });

  group('days are judged on the IST date (IST midnight)', () {
    // Saturdays only, 00:00–01:00 IST.
    final rule = afternoonRule(days: const [6], startMin: 0, endMin: 60);
    test('Sat 00:00 IST (Fri 18:30 UTC) → rule', () {
      expect(ps5Hour([rule], DateTime.utc(2026, 10, 2, 18, 30)), 12000);
    });
    test('Fri 23:59 IST (Fri 18:29 UTC) → no rule (Friday)', () {
      expect(ps5Hour([rule], DateTime.utc(2026, 10, 2, 18, 29)), 15000);
    });
    test('weekday outside days → no rule (Saturday 14:00 for Tue–Fri)', () {
      expect(ps5Hour([afternoonRule()], ist(2026, 10, 3, 14, 0)), 15000);
    });
  });

  group('holiday mode', () {
    final friday = ist(2026, 10, 2, 14, 0);
    final hol = {fridayDate};
    test('skip: not on a holiday', () {
      expect(ps5Hour([afternoonRule()], friday, holidays: hol), 15000);
      expect(ps5Hour([afternoonRule()], friday), 12000);
    });
    test('only: only on a holiday', () {
      final r = afternoonRule(holidayMode: RuleHolidayMode.only);
      expect(ps5Hour([r], friday, holidays: hol), 12000);
      expect(ps5Hour([r], friday), 15000);
    });
    test('any: both', () {
      final r = afternoonRule(holidayMode: RuleHolidayMode.any);
      expect(ps5Hour([r], friday, holidays: hol), 12000);
      expect(ps5Hour([r], friday), 12000);
    });
  });

  group('valid dates are inclusive IST dates', () {
    final friday = ist(2026, 10, 2, 14, 0);
    test('valid_from = the day → rule; the day after → not yet', () {
      expect(ps5Hour([afternoonRule(validFrom: fridayDate)], friday), 12000);
      expect(ps5Hour([afternoonRule(validFrom: const IstDate(2026, 10, 3))], friday), 15000);
    });
    test('valid_until = the day → rule; the day before → expired', () {
      expect(ps5Hour([afternoonRule(validUntil: fridayDate)], friday), 12000);
      expect(ps5Hour([afternoonRule(validUntil: const IstDate(2026, 10, 1))], friday), 15000);
    });
  });

  group('activity filter', () {
    final s = ist(2026, 10, 2, 14, 0);
    final e = ist(2026, 10, 2, 14, 30);
    test('listed codes only', () {
      final snap = currentSnapshot(rules: [afternoonRule(activityCodes: const ['POOL'])]);
      expect(quote(snap, 'POOL', null, s, e).rule, isNotNull);
      expect(quote(snap, 'PS5', 1, s, e).rule, isNull);
    });
    test('an empty list means every activity', () {
      final snap = currentSnapshot(rules: [afternoonRule(activityCodes: const [])]);
      expect(quote(snap, 'VR', null, s, e).amount.value, 16000); // ₹200 −20%
      expect(quote(snap, 'LOUNGE', null, s, ist(2026, 10, 2, 15, 0)).amount.value, 160000);
    });
  });

  group('priority, then name, then id', () {
    final at = ist(2026, 10, 2, 14, 0);
    PricingRule r(String id, String name, int priority, int pct) =>
        afternoonRule(id: id, name: name, priority: priority, adjustValue: pct);
    test('lower priority number wins', () {
      final m = matchRule([r('a', 'A', 2, -10), r('b', 'B', 1, -30)],
          activityCode: 'PS5', at: at, holidays: const {});
      expect(m?.id, 'b');
    });
    test('tie on priority → name', () {
      final m = matchRule([r('a', 'Zed', 1, -10), r('b', 'Alpha', 1, -30)],
          activityCode: 'PS5', at: at, holidays: const {});
      expect(m?.name, 'Alpha');
    });
    test('tie on priority and name → id', () {
      final m = matchRule([r('b', 'Same', 1, -10), r('a', 'Same', 1, -30)],
          activityCode: 'PS5', at: at, holidays: const {});
      expect(m?.id, 'a');
    });
    test('a higher-priority rule that does not apply never blocks a lower one', () {
      final m = matchRule([
        afternoonRule(id: 'x', priority: 0, activityCodes: const ['VR']),
        r('y', 'Y', 5, -10),
      ], activityCode: 'PS5', at: at, holidays: const {});
      expect(m?.id, 'y');
    });
  });

  group('applyRulePrice', () {
    PricingRule pct(int v) => afternoonRule(adjustValue: v);
    PricingRule perHour(int v) =>
        afternoonRule(adjustKind: RuleAdjustKind.perHour, adjustValue: v);
    test('null rule leaves the price', () => expect(applyRulePrice(15000, 60, null), 15000));
    test('percent rounds half up', () {
      expect(applyRulePrice(15050, 60, pct(-15)), 12793); // 12792.5
      expect(applyRulePrice(15, 60, pct(50)), 23); // 22.5
      expect(applyRulePrice(333, 60, pct(10)), 366); // 366.3
      expect(applyRulePrice(27500, 60, pct(-20)), 22000);
    });
    test('percent −100 is free', () => expect(applyRulePrice(15000, 60, pct(-100)), 0));
    test('per hour is pro rata to the unit, half toward +∞', () {
      expect(applyRulePrice(20000, 30, perHour(25)), 20013); // +12.5 → +13
      expect(applyRulePrice(20000, 30, perHour(-25)), 19988); // −12.5 → −12
      expect(applyRulePrice(20000, 45, perHour(-10)), 19993); // −7.5 → −7
      expect(applyRulePrice(20000, 45, perHour(-11)), 19992); // −8.25 → −8
      expect(applyRulePrice(15000, 60, perHour(5000)), 20000);
    });
    test('never below 0', () {
      expect(applyRulePrice(15000, 60, perHour(-100000)), 0);
      expect(applyRulePrice(100, 15, perHour(-1000)), 0);
    });
  });

  test('the adjusted price drives per-minute proration and the charge line', () {
    // PS5 2 controllers ₹280 −20% = ₹224/h; 40 min = ₹149.33 → ₹149.
    final q = quote(currentSnapshot(rules: [afternoonRule()]), 'PS5', 2,
        ist(2026, 10, 2, 14, 0), ist(2026, 10, 2, 14, 40));
    expect(q.segments.single.unitPrice, const Paise(22400));
    expect(q.subtotal.value, 14933);
    expect(q.amount.value, 14900);
  });

  test('ruleAt overrides the quoted start', () {
    final snap = currentSnapshot(rules: [afternoonRule()]);
    final evening = ist(2026, 10, 2, 18, 0);
    final q = quote(snap, 'PS5', 1, evening, evening.add(const Duration(hours: 1)),
        ruleAt: ist(2026, 10, 2, 16, 0));
    expect(q.amount.value, 12000);
    expect(q.rule?.id, 'r1');
  });

  group('a session keeps the rule judged at its start', () {
    final snap = currentSnapshot(rules: [afternoonRule()]);
    SessionSegment seg(int i, DateTime s, DateTime? e, int cc) => SessionSegment(
          id: 'seg$i', sessionId: 's', index: i, resourceId: 'hex', activityCode: 'PS5',
          controllerCount: cc, startedAt: s, endedAt: e, createdAt: s);

    test('a switch after the window still gets the discount', () {
      final t0 = ist(2026, 10, 2, 16, 30);
      final t1 = ist(2026, 10, 2, 17, 30);
      final bill = const SegmentBilling().bill(
        snapshot: snap,
        segments: [seg(0, t0, t1, 1), seg(1, t1, null, 2)],
        openEndAt: ist(2026, 10, 2, 18, 30),
        sessionStart: t0,
      );
      expect(bill.charges.map((c) => c.unitPricePaise), [12000, 22400]);
      expect(bill.total.value, 12000 + 22400);
      expect(bill.rules.single.id, 'r1');
    });

    test('a session started after the window gets none, even for earlier-looking segments', () {
      final t0 = ist(2026, 10, 2, 17, 5);
      final bill = const SegmentBilling().bill(
        snapshot: snap,
        segments: [seg(0, t0, null, 1)],
        openEndAt: t0.add(const Duration(hours: 1)),
        sessionStart: t0,
      );
      expect(bill.total.value, 15000);
      expect(bill.rules, isEmpty);
    });

    test('an extension is priced with the session-start rule', () {
      final start = ist(2026, 10, 2, 16, 0);
      final plan = const SessionPlanner().planExtension(
        snapshot: snap,
        activityCode: 'PS5',
        controllerCount: 1,
        resourceId: 'hex',
        startedAt: start,
        currentEnd: start.add(const Duration(hours: 1)),
        addedMinutes: 60,
        occupancies: const [],
        closeAt: start.add(const Duration(hours: 6)),
      );
      expect(plan.valueOrNull!.addedCost.value, 12000); // 17:00–18:00 still −20%
    });
  });

  group('snapshot JSON (server `_pricing_snapshot` shape)', () {
    test('no rules → no `rules` key, no retired keys', () {
      final j = currentSnapshot().toJson();
      expect(j.containsKey('rules'), isFalse);
      expect((j['hours'] as Map).keys, ['open']);
      expect((j['activities'] as List).first,
          {'code': 'PS5', 'duration_model': 'hourly', 'overtime_grace_minutes': 0});
      expect({for (final r in j['rates'] as List) r['band']}, {'standard'});
    });

    test('rules serialise with the server keys and round-trip', () {
      final rule = afternoonRule(validFrom: const IstDate(2026, 10, 1));
      final snap = currentSnapshot(rules: [rule]);
      final j = snap.toJson();
      expect(j['rules'], [
        {
          'id': 'r1',
          'name': 'Afternoon deal',
          'priority': 1,
          'days': [2, 3, 4, 5],
          'start_min': 840,
          'end_min': 1020,
          'holiday_mode': 'skip',
          'valid_from': '2026-10-01',
          'valid_until': null,
          'activity_codes': ['PS5', 'POOL'],
          'adjust_kind': 'percent',
          'adjust_value': -20,
        },
      ]);
      final back = PricingSnapshot.fromJson(j);
      expect(back.rules.single, rule);
      expect(back.toJson(), j);
    });

    test('rules are kept in rule order', () {
      final snap = currentSnapshot(rules: [
        afternoonRule(id: 'b', name: 'B', priority: 2),
        afternoonRule(id: 'a', name: 'A', priority: 2),
        afternoonRule(id: 'c', name: 'C', priority: 1),
      ]);
      expect(snap.rules.map((r) => r.id), ['c', 'a', 'b']);
    });

    test('a snapshot frozen by an older build still parses and prices', () {
      final j = currentSnapshot().toJson();
      // Older builds froze an extra activity flag, a second hours map and
      // rates of a band that no longer exists.
      for (final a in j['activities'] as List) {
        (a as Map<String, dynamic>)['retired_flag'] = true;
      }
      (j['hours'] as Map<String, dynamic>)['retired_window'] = {'2': {'start': 840, 'end': 1020}};
      (j['rates'] as List).add({
        'activity_code': 'PS5', 'band': 'retired_band', 'controller_count': 1,
        'unit_minutes': 60, 'price_paise': 1,
      });
      final snap = PricingSnapshot.fromJson(j);
      expect(snap.rules, isEmpty);
      expect(snap.rates.every((r) => r.band == Band.standard), isTrue);
      expect(ps5HourOn(snap, ist(2026, 10, 2, 14, 0)), 15000);
    });

    test('a feed row reads as a rule (extra columns ignored)', () {
      final r = PricingRule.fromJson({
        'id': 'u1', 'arena_id': 'x', 'name': 'Weekend', 'priority': 3, 'active': true,
        'days': [6, 7], 'start_min': 1080, 'end_min': 1440, 'holiday_mode': 'any',
        'valid_from': null, 'valid_until': '2026-12-31', 'activity_codes': <String>[],
        'adjust_kind': 'per_hour', 'adjust_value': 5000, 'sync_xid': '123',
      });
      expect(r.adjustKind, RuleAdjustKind.perHour);
      expect(r.validUntil, const IstDate(2026, 12, 31));
      expect(r.summary, 'Weekend +₹50/h');
    });
  });
}

int ps5HourOn(PricingSnapshot snap, DateTime s) => const PricingService()
    .quote(
      snapshot: snap,
      activityCode: 'PS5',
      controllerCount: 1,
      start: s,
      end: s.add(const Duration(hours: 1)),
    )
    .valueOrNull!
    .amount
    .value;
