/// Characterisation of how the owner-selectable billing rules (Settings →
/// Billing rules: block billing, grace, minimum charge) apply when a session's
/// configuration changes mid-way — a controller change, game change or system
/// switch all close one segment and open the next at the same instant.
///
/// Today every rule is applied PER SEGMENT (each segment is quoted on its own;
/// only the final cash rounding is per session). With the shipped default
/// (per-minute, no grace, no minimum) that is exact. With the other options a
/// change can add or remove billed time — see docs/billing-segment-policy.md.
/// These tests PIN the current behaviour so any change to it is deliberate;
/// they do not endorse it. Owner decision pending.
library;

import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/pricing/billing_policy.dart';
import 'package:arena_ops/domain/services/segment_billing.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pricing_fixtures.dart';

void main() {
  const billing = SegmentBilling();
  final t0 = ist(2026, 10, 2, 18, 0); // Friday 18:00 — standard band

  SessionSegment seg(int index, int fromMin, int toMin, int controllers) =>
      SessionSegment(
        id: 'seg$index',
        sessionId: 's',
        index: index,
        resourceId: 'hex',
        activityCode: 'PS5',
        controllerCount: controllers,
        startedAt: t0.add(Duration(minutes: fromMin)),
        endedAt: t0.add(Duration(minutes: toMin)),
        createdAt: t0,
      );

  int bill(BillingPolicy policy, List<SessionSegment> segments) => billing
      .bill(
        snapshot: currentSnapshot(policy: policy),
        segments: segments,
        openEndAt: t0.add(const Duration(hours: 1)),
        sessionStart: t0,
      )
      .total
      .value;

  // One hour played: 20 min on 1 controller, then 40 min on 2.
  final changed = [seg(0, 0, 20, 1), seg(1, 20, 60, 2)];

  test('default policy (per-minute, no grace, no minimum): exact proration',
      () {
    // ₹150/h × 20 min + ₹280/h × 40 min = ₹50 + ₹186.67 → ₹237 (nearest ₹1).
    expect(bill(BillingPolicy.defaults, changed), 23700);
    // Unchanged session for comparison: an hour on 2 controllers.
    expect(bill(BillingPolicy.defaults, [seg(0, 0, 60, 2)]), 28000);
  });

  test('block billing rounds EACH segment up — a change adds billed time',
      () {
    const p = BillingPolicy(billingUnit: BillingUnit.block30);
    // 20 min → 30 billed at ₹150/h (₹75); 40 min → 60 billed at ₹280/h (₹280).
    // 90 minutes billed for 60 played.
    expect(bill(p, changed), 7500 + 28000);
    expect(bill(p, [seg(0, 0, 60, 2)]), 28000);
  });

  test('minimum charge applies to EACH segment', () {
    const p = BillingPolicy(minimumChargeMinutes: 30);
    // The 20-minute segment is billed as 30 (₹75); the 40-minute one as is.
    expect(bill(p, changed), 26200); // ₹75 + ₹186.67 → ₹262
  });

  test('grace applies to EACH segment — a short tail after a change is free',
      () {
    const p = BillingPolicy(graceMinutes: 5);
    // A controller added at 58 min: the 2-minute tail is under grace → ₹0.
    final lateChange = [seg(0, 0, 58, 1), seg(1, 58, 60, 2)];
    expect(bill(p, lateChange), 14500); // only 58 min at ₹150/h
  });

}
