// Controller-count pricing, partial hours, a 10% happy hour and the final
// bill, on a linear rate card (₹150 per controller per hour). The engine reads
// the configured row for the controller count and never multiplies by the
// count itself; preview, live total, End & Bill and the charge rows all come
// from the same PricingService, so they agree.

import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/money/rounding.dart';
import 'package:arena_ops/core/time/business_calendar.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/pricing/billing_policy.dart';
import 'package:arena_ops/domain/pricing/pricing_quote.dart';
import 'package:arena_ops/domain/pricing/pricing_rule.dart';
import 'package:arena_ops/domain/pricing/pricing_service.dart';
import 'package:arena_ops/domain/pricing/pricing_snapshot.dart';
import 'package:arena_ops/domain/pricing/rate.dart';
import 'package:arena_ops/domain/services/segment_billing.dart';
import 'package:arena_ops/domain/services/session_planner.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pricing_fixtures.dart';

/// PS5 at ₹150 × controllers per hour: ₹150 / ₹300 / ₹450 / ₹600.
PricingSnapshot linearSnapshot({
  BillingPolicy? policy,
  List<PricingRule> rules = const [],
  List<int> counts = const [1, 2, 3, 4],
}) =>
    PricingSnapshot(
      rateCardName: 'Linear',
      rates: [
        for (final c in counts)
          Rate(
            activityCode: 'PS5',
            band: Band.standard,
            controllerCount: c,
            unitMinutes: 60,
            price: Paise(15000 * c),
          ),
      ],
      activities: const [
        ActivitySpec(code: 'PS5', durationModel: DurationModel.hourly),
      ],
      policy: policy ?? BillingPolicy.defaults,
      hours: BusinessHours.current(),
      rules: rules,
    );

/// Tue–Fri 14:00–17:00 IST, 10% off PS5.
PricingRule happyHour10() =>
    afternoonRule(name: 'Happy hours', activityCodes: const ['PS5'], adjustValue: -10);

void main() {
  const pricing = PricingService();
  const billing = SegmentBilling();
  const planner = SessionPlanner();

  // Friday 2026-10-02: 18:00 is outside the happy hour, 14:00 inside it.
  final evening = ist(2026, 10, 2, 18, 0);
  final afternoon = ist(2026, 10, 2, 14, 0);

  PricingQuote quote(
    int controllers,
    DateTime start,
    Duration played, {
    PricingSnapshot? snapshot,
  }) {
    final r = pricing.quote(
      snapshot: snapshot ?? linearSnapshot(),
      activityCode: 'PS5',
      controllerCount: controllers,
      start: start,
      end: start.add(played),
    );
    expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    return r.valueOrNull!;
  }

  group('one hour by controller count', () {
    for (final (n, paise) in const [(1, 15000), (2, 30000), (3, 45000), (4, 60000)]) {
      test('$n controller${n == 1 ? '' : 's'} = ${Paise(paise).display}', () {
        final q = quote(n, evening, const Duration(hours: 1));
        expect(q.amount, Paise(paise));
        expect(q.billedMinutes, 60);
        // The configured row is the unit price: no extra × controllers.
        expect(q.segments.single.unitPrice, Paise(paise));
        expect(q.rule, isNull);
      });
    }

    test('the price comes from the row, never 1-controller × count', () {
      // An owner's tiered card is charged as configured.
      final tiered = currentSnapshot();
      expect(quote(2, evening, const Duration(hours: 1), snapshot: tiered).amount,
          const Paise(28000));
      // No row for that count: refused, not extrapolated from the base price.
      final r = pricing.quote(
        snapshot: linearSnapshot(counts: const [1]),
        activityCode: 'PS5',
        controllerCount: 2,
        start: evening,
        end: evening.add(const Duration(hours: 1)),
      );
      expect(r.failureOrNull?.code, 'no_rate');
    });
  });

  group('partial hours, per minute (default: prorated, cash-rounded to ₹1)', () {
    test('30 min: ₹75 / ₹150 / ₹225 / ₹300', () {
      for (final n in [1, 2, 3, 4]) {
        expect(quote(n, evening, const Duration(minutes: 30)).amount,
            Paise(7500 * n));
      }
    });
    test('1 h 10 min at 2 controllers = ₹350', () {
      expect(quote(2, evening, const Duration(minutes: 70)).amount,
          const Paise(35000));
    });
    test('1 min at 1 controller = ₹2.50 exact, ₹3 after half-up cash rounding', () {
      final q = quote(1, evening, const Duration(minutes: 1));
      expect(q.subtotal, const Paise(250));
      expect(q.amount, const Paise(300));
    });
    test('seconds count: 90 s at 4 controllers = ₹15', () {
      expect(quote(4, evening, const Duration(seconds: 90)).amount,
          const Paise(1500));
    });
  });

  group('partial hours, block billing', () {
    PricingSnapshot blocks(BillingUnit unit, [Rounding r = Rounding.up]) =>
        linearSnapshot(
            policy: BillingPolicy.defaults
                .copyWith(billingUnit: unit, blockRounding: r));

    test('15-min blocks, up: 20 min bills 30 min (₹75 at 1 controller)', () {
      final q = quote(1, evening, const Duration(minutes: 20),
          snapshot: blocks(BillingUnit.block15));
      expect(q.billedMinutes, 30);
      expect(q.amount, const Paise(7500));
    });
    test('30-min blocks, up: 31 min bills 60 min (₹300 at 2 controllers)', () {
      final q = quote(2, evening, const Duration(minutes: 31),
          snapshot: blocks(BillingUnit.block30));
      expect(q.billedMinutes, 60);
      expect(q.amount, const Paise(30000));
    });
    test('30-min blocks, nearest: 44 min → 30, 45 min → 60', () {
      final s = blocks(BillingUnit.block30, Rounding.nearest);
      expect(quote(3, evening, const Duration(minutes: 44), snapshot: s).amount,
          const Paise(22500));
      expect(quote(3, evening, const Duration(minutes: 45), snapshot: s).amount,
          const Paise(45000));
    });
    test('hour blocks, up: 61 min bills 2 h (₹1200 at 4 controllers)', () {
      final q = quote(4, evening, const Duration(minutes: 61),
          snapshot: blocks(BillingUnit.block60));
      expect(q.billedMinutes, 120);
      expect(q.amount, const Paise(120000));
    });
    test('a started second rounds to the next whole minute first', () {
      final q = quote(1, evening, const Duration(minutes: 15, seconds: 1),
          snapshot: blocks(BillingUnit.block15));
      expect(q.billedMinutes, 30);
    });
  });

  group('cash rounding to ₹5, up', () {
    test('1 min at 1 controller (₹2.50) → ₹5; a whole hour stays ₹150', () {
      final s = linearSnapshot(
          policy: BillingPolicy.defaults.copyWith(
              moneyRoundingPaise: 500, moneyRoundingDir: MoneyRoundingDir.up));
      expect(quote(1, evening, const Duration(minutes: 1), snapshot: s).amount,
          const Paise(500));
      expect(quote(1, evening, const Duration(hours: 1), snapshot: s).amount,
          const Paise(15000));
    });
  });

  group('10% happy hour', () {
    final withRule = linearSnapshot(rules: [happyHour10()]);

    test('one hour inside the window: ₹135 / ₹270 / ₹405 / ₹540', () {
      for (final (n, paise) in const [(1, 13500), (2, 27000), (3, 40500), (4, 54000)]) {
        final q = quote(n, afternoon, const Duration(hours: 1), snapshot: withRule);
        expect(q.amount, Paise(paise), reason: '$n controllers');
        expect(q.rule?.summary, 'Happy hours −10%');
      }
    });
    test('applied once: unit price ₹135, amount ₹135 (not ₹121.50)', () {
      final q = quote(1, afternoon, const Duration(hours: 1), snapshot: withRule);
      expect(q.segments.single.unitPrice, const Paise(13500));
      expect(q.subtotal, const Paise(13500));
    });
    test('outside the window: full price', () {
      final q = quote(1, evening, const Duration(hours: 1), snapshot: withRule);
      expect(q.amount, const Paise(15000));
      expect(q.rule, isNull);
    });
    test('30 min inside the window at 1 controller = ₹67.50 → ₹68', () {
      final q = quote(1, afternoon, const Duration(minutes: 30), snapshot: withRule);
      expect(q.subtotal, const Paise(6750));
      expect(q.amount, const Paise(6800));
    });
    test('started inside, played past 17:00: the start decides the whole hour', () {
      final q = quote(2, ist(2026, 10, 2, 16, 30), const Duration(hours: 1),
          snapshot: withRule);
      expect(q.amount, const Paise(27000));
    });
  });

  group('final bill: preview = live = End & Bill = charge rows', () {
    SessionSegment segment(int n, DateTime start, {DateTime? end}) =>
        SessionSegment(
          id: 'seg_$n',
          sessionId: 's1',
          index: 0,
          resourceId: 'hex',
          activityCode: 'PS5',
          controllerCount: n,
          startedAt: start,
          endedAt: end,
          createdAt: start,
        );

    void agree(PricingSnapshot snap, DateTime start, int n, int expected) {
      final end = start.add(const Duration(hours: 1));
      final plan = planner.planStart(
        snapshot: snap,
        activityCode: 'PS5',
        controllerCount: n,
        resourceId: 'hex',
        resourceName: 'HEX',
        startedAt: start,
        durationMinutes: 60,
        occupancies: const [],
        closeAt: ist(2026, 10, 2, 23, 0),
      );
      expect(plan.isOk, isTrue, reason: plan.failureOrNull?.display);
      final preview = plan.valueOrNull!.quote.amount;

      // Live amount at the booked end (SessionActions.liveBill).
      final live = billing.bill(
        snapshot: snap,
        segments: [segment(n, start)],
        openEndAt: end,
        sessionStart: start,
      );
      // End & Bill at the booked end (SessionActions.endSummary).
      final bill = billing.bill(
        snapshot: snap,
        segments: [segment(n, start)],
        openEndAt: end,
        sessionStart: start,
        billUntil: overtimeBillUntil(
            lastEnd: end, scheduledEnd: end),
      );
      final rows = bill.charges.fold<int>(0, (a, c) => a + c.amountPaise);

      expect(preview, Paise(expected), reason: 'preview, $n ctrl');
      expect(live.total, Paise(expected), reason: 'live, $n ctrl');
      expect(bill.total, Paise(expected), reason: 'End & Bill, $n ctrl');
      expect(
          applyMoneyRounding(rows, snap.policy.moneyRoundingPaise,
              snap.policy.moneyRoundingDir),
          expected,
          reason: 'charge rows, $n ctrl');
      expect(bill.charges.single.controllerCount, n);
      expect(bill.charges.single.unitPricePaise, bill.lines.single.quote.segments.single.unitPrice.value);
      expect(bill.isIncomplete, isFalse);
    }

    test('standard hour, 1–4 controllers', () {
      for (final (n, paise) in const [(1, 15000), (2, 30000), (3, 45000), (4, 60000)]) {
        agree(linearSnapshot(), evening, n, paise);
      }
    });

    test('happy hour, 1–4 controllers', () {
      final snap = linearSnapshot(rules: [happyHour10()]);
      for (final (n, paise) in const [(1, 13500), (2, 27000), (3, 40500), (4, 54000)]) {
        agree(snap, afternoon, n, paise);
      }
    });

    test('a controller change mid-hour bills each half at its own row, rule once', () {
      final snap = linearSnapshot(rules: [happyHour10()]);
      final half = afternoon.add(const Duration(minutes: 30));
      final bill = billing.bill(
        snapshot: snap,
        segments: [
          segment(1, afternoon, end: half),
          SessionSegment(
            id: 'seg_b',
            sessionId: 's1',
            index: 1,
            resourceId: 'hex',
            activityCode: 'PS5',
            controllerCount: 3,
            startedAt: half,
            createdAt: half,
          ),
        ],
        openEndAt: afternoon.add(const Duration(hours: 1)),
        sessionStart: afternoon,
      );
      // 30 min × ₹135 + 30 min × ₹405 = ₹67.50 + ₹202.50 = ₹270.
      expect(bill.subtotal, const Paise(27000));
      expect(bill.total, const Paise(27000));
      expect(bill.charges.map((c) => c.unitPricePaise), [13500, 40500]);
    });

    test('ended within the overtime grace: only the booked hour is billed', () {
      final snap = linearSnapshot();
      final booked = evening.add(const Duration(hours: 1));
      final actual = booked.add(const Duration(minutes: 4));
      final bill = billing.bill(
        snapshot: snap,
        segments: [segment(2, evening)],
        openEndAt: actual,
        sessionStart: evening,
        billUntil: overtimeBillUntil(
            lastEnd: actual, scheduledEnd: booked),
      );
      expect(bill.total, const Paise(30000));
    });
  });
}
