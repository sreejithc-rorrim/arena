/// The pricing engine (spec §15–§18). PURE Dart — no Flutter, no Supabase, no
/// UI. Deterministic given a [PricingSnapshot] and a time interval, so a session
/// priced today prices identically forever.
///
/// Flow (spec §15):
///   1. Validate the interval.
///   2. Find the pricing rule judged at the rule instant (the session's
///      start; see `rule_engine.dart`).
///   3. Apply grace (free if under grace) and minimum-charge (extend interval).
///   4. Resolve the standard rate and adjust its unit price by the rule.
///   5. Apply the billing policy to get billed time/units.
///   6. Compute amounts in integer paise (never floating point).
///   7. Round per rounding-scope, then apply final cash rounding.
///
/// Every quote is one charge line at [Band.standard]: time-of-day prices are
/// pricing rules, which change the unit price for the whole quote.
///
/// SERVER PARITY: the server re-prices every bill with a plpgsql port of this
/// code (`_pr_quote`, `_pr_rule`, `_pr_rule_price`) and refuses any
/// difference. Changing how money is computed here needs the matching change
/// to `supabase/schemas/` and a green parity check — see
/// docs/SYNC.md "Changing pricing".
///
/// Late arrival (§8) and early exit (§5) are decided by the *caller* choosing
/// which interval to price; the engine stays pure over `[start, end]`.
library;

import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/money/rounding.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/time/utc_interval.dart';
import 'package:arena_ops/domain/pricing/billing_policy.dart';
import 'package:arena_ops/domain/pricing/pricing_quote.dart';
import 'package:arena_ops/domain/pricing/pricing_snapshot.dart';
import 'package:arena_ops/domain/pricing/rule_engine.dart';
import 'package:arena_ops/domain/value/enums.dart';

class PricingService {
  const PricingService();

  /// Prices `[start, end]` of [activityCode] at [controllerCount].
  ///
  /// [ruleAt] is the instant the pricing rule is judged at: the session's
  /// start, so every segment and extension of one session gets the
  /// same rule. Defaults to [start] (`_pr_quote`'s `coalesce(p_rule_at,
  /// p_start)`).
  Result<PricingQuote> quote({
    required PricingSnapshot snapshot,
    required String activityCode,
    required int? controllerCount,
    required DateTime start,
    required DateTime end,
    DateTime? ruleAt,
  }) {
    final startUtc = start.toUtc();
    final endUtc = end.toUtc();

    if (endUtc.isBefore(startUtc)) {
      return const Err(Failure(
        message: 'Invalid session time.',
        fix: 'End time is before start time.',
        code: 'invalid_interval',
      ));
    }

    final activity = snapshot.activity(activityCode);
    if (activity == null) {
      return Err(Failure(
        message: 'No price is configured for this combination.',
        fix: 'Set up a rate for $activityCode.',
        code: 'no_rate',
      ));
    }

    final rule = snapshot.ruleFor(activityCode, (ruleAt ?? startUtc).toUtc());
    final policy = snapshot.policy;
    final totalSeconds = endUtc.difference(startUtc).inSeconds;

    // Grace: nothing to pay if under the grace period (default 0 → never free).
    if (totalSeconds <= policy.graceMinutes * 60) {
      return Ok(PricingQuote(
        segments: const [],
        playedSeconds: totalSeconds,
        billedMinutes: 0,
        subtotal: Paise.zero,
        amount: Paise.zero,
        rule: rule,
      ));
    }

    // Minimum charge: bill at least this much time by extending the interval.
    final minSeconds = policy.minimumChargeMinutes * 60;
    final billedEnd = totalSeconds < minSeconds
        ? startUtc.add(Duration(seconds: minSeconds))
        : endUtc;

    final rate = snapshot.rateFor(
      activityCode: activityCode,
      band: Band.standard,
      controllerCount: controllerCount,
    );
    if (rate == null) {
      return Err(Failure(
        message: controllerCount == null
            ? 'No price for $activityCode.'
            : 'No price for $activityCode with $controllerCount '
                'controller${controllerCount == 1 ? '' : 's'}.',
        fix: controllerCount == null
            ? 'Add a $activityCode price on the dashboard (Pricing).'
            : 'Pick another controller count, or add the price on the '
                'dashboard (Pricing).',
        code: 'no_rate',
      ));
    }
    final unitPrice = applyRulePrice(rate.price.value, rate.unitMinutes, rule);

    // One billed piece; it may run past [end] (minimum charge), but played
    // time counts only the real interval.
    final billed = UtcInterval(startUtc, billedEnd);
    final billedSeconds = billed.duration.inSeconds;
    final playedSeconds = UtcInterval(startUtc, endUtc)
            .intersection(billed)
            ?.duration
            .inSeconds ??
        0;

    final _SegMath m = activity.durationModel == DurationModel.unit
        ? _unitCharge(billedSeconds, unitPrice, rate.unitMinutes, policy)
        : _timeCharge(billedSeconds, unitPrice, rate.unitMinutes, policy);

    final segment = PricingSegment(
      interval: billed,
      band: Band.standard,
      playedSeconds: playedSeconds,
      billedMinutes: m.billedMinutes,
      units: m.units,
      unitMinutes: rate.unitMinutes,
      unitPrice: Paise(unitPrice),
      amount: Paise(roundDivHalfUp(m.num, m.den)),
      rawNumerator: m.num,
      rawDenominator: m.den,
    );

    // Rounding scope: round the piece (segment) or the exact sum once
    // (session). With a single piece both give the same paise; the branch is
    // kept so a future multi-piece quote cannot silently change the rule.
    final int subtotalPaise =
        policy.roundingScope == RoundingScope.segment
            ? segment.amount.value
            : roundDivHalfUp(m.num, m.den);

    final finalPaise = applyMoneyRounding(
      subtotalPaise,
      policy.moneyRoundingPaise,
      policy.moneyRoundingDir,
    );

    return Ok(PricingQuote(
      segments: [segment],
      playedSeconds: totalSeconds,
      billedMinutes: m.billedMinutes,
      subtotal: Paise(subtotalPaise),
      amount: Paise(finalPaise),
      rule: rule,
    ));
  }

  // --- segment math ----------------------------------------------------------

  _SegMath _timeCharge(
      int billedSeconds, int price, int unitMinutes, BillingPolicy policy) {

    if (policy.billingUnit == BillingUnit.perMinute) {
      // Per-second proration of the per-unit price — the truest "actual time".
      final den = unitMinutes * 60;
      final num = price * billedSeconds;
      return _SegMath(
        num: num,
        den: den,
        billedMinutes: roundDivHalfUp(billedSeconds, 60),
        units: 0,
      );
    }

    final block = policy.billingUnit.blockMinutes!;
    final playedMinutesCeil = (billedSeconds + 59) ~/ 60; // whole minutes first
    final billedMinutes = policy.blockRounding == Rounding.up
        ? ceilToStep(playedMinutesCeil, block)
        : roundToStep(playedMinutesCeil, block);
    return _SegMath(
      num: price * billedMinutes,
      den: unitMinutes,
      billedMinutes: billedMinutes,
      units: 0,
    );
  }

  _SegMath _unitCharge(
      int billedSeconds, int price, int unitMinutes, BillingPolicy policy) {
    final unitSeconds = unitMinutes * 60;

    switch (policy.vrUnitRounding) {
      case VrUnitRounding.prorate:
        return _SegMath(
          num: price * billedSeconds,
          den: unitSeconds,
          billedMinutes: roundDivHalfUp(billedSeconds, 60),
          units: 0,
        );
      case VrUnitRounding.up:
        final units = (billedSeconds + unitSeconds - 1) ~/ unitSeconds;
        return _SegMath(
          num: price * units,
          den: 1,
          billedMinutes: units * unitMinutes,
          units: units,
        );
      case VrUnitRounding.nearest:
        final units = roundDivHalfUp(billedSeconds, unitSeconds);
        return _SegMath(
          num: price * units,
          den: 1,
          billedMinutes: units * unitMinutes,
          units: units,
        );
    }
  }
}

class _SegMath {
  const _SegMath({
    required this.num,
    required this.den,
    required this.billedMinutes,
    required this.units,
  });
  final int num;
  final int den;
  final int billedMinutes;
  final int units;
}
