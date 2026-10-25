/// The complete, immutable pricing environment captured when a session starts
/// (spec §31). Everything the pricer needs to be deterministic lives here, so a
/// historical session is re-priced identically forever, regardless of later
/// rate/policy/schedule changes.
library;

import 'package:arena_ops/core/time/business_calendar.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/domain/pricing/billing_policy.dart';
import 'package:arena_ops/domain/pricing/pricing_rule.dart';
import 'package:arena_ops/domain/pricing/rate.dart';
import 'package:arena_ops/domain/pricing/rule_engine.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:meta/meta.dart';

@immutable
class PricingSnapshot {
  PricingSnapshot({
    required this.rateCardName,
    required List<Rate> rates,
    required List<ActivitySpec> activities,
    required this.policy,
    required this.hours,
    Set<IstDate> holidays = const {},
    Set<IstDate> closedDays = const {},
    List<PricingRule> rules = const [],
  })  : rates = List.unmodifiable(rates),
        activities = {for (final a in activities) a.code: a},
        holidays = Set.unmodifiable(holidays),
        closedDays = Set.unmodifiable(closedDays),
        rules = List<PricingRule>.unmodifiable(
            <PricingRule>[...rules]..sort(compareRuleOrder));

  final String rateCardName;
  final List<Rate> rates;
  final Map<String, ActivitySpec> activities;
  final BillingPolicy policy;
  final BusinessHours hours;
  final Set<IstDate> holidays;

  /// Dates the centre was closed outright (distinct from a trading holiday).
  final Set<IstDate> closedDays;

  /// The arena's active pricing rules when the snapshot was frozen, in rule
  /// order (priority, name, id). Empty for an arena without rules.
  final List<PricingRule> rules;

  /// The rule that prices [activityCode] for a session started at
  /// [at], or null (`_pr_rule`).
  PricingRule? ruleFor(String activityCode, DateTime at) => matchRule(rules,
      activityCode: activityCode, at: at, holidays: holidays);

  BusinessCalendar get calendar => BusinessCalendar(
        hours: hours,
        holidays: holidays,
        closedDays: closedDays,
      );

  ActivitySpec? activity(String code) => activities[code];

  /// Whether any band prices (activity, controllerCount): a segment without
  /// one would bill ₹0, so the server refuses it (`no_rate`, _seg_priced).
  bool prices(String activityCode, int? controllerCount) => rates.any((r) =>
      r.activityCode == activityCode && r.controllerCount == controllerCount);

  /// Exact rate match for (activity, band, controllerCount); no fallback.
  Rate? rateFor({
    required String activityCode,
    required Band band,
    required int? controllerCount,
  }) {
    for (final r in rates) {
      if (r.activityCode == activityCode &&
          r.band == band &&
          r.controllerCount == controllerCount) {
        return r;
      }
    }
    return null;
  }

  /// The server's `_pricing_snapshot` shape (compared via `_pricing_canon` at
  /// session.start). `rules` is present only when there are
  /// any, exactly like the server, so a rule-free arena's snapshot is the one
  /// older builds produced.
  Map<String, dynamic> toJson() => {
        'rate_card_name': rateCardName,
        'rates': rates.map((r) => r.toJson()).toList(),
        'activities': activities.values.map((a) => a.toJson()).toList(),
        'policy': policy.toJson(),
        'hours': hours.toJson(),
        'holidays': holidays.map((d) => d.iso).toList(),
        'closed_days': closedDays.map((d) => d.iso).toList(),
        if (rules.isNotEmpty) 'rules': rules.map((r) => r.toJson()).toList(),
      };

  factory PricingSnapshot.fromJson(Map<String, dynamic> j) => PricingSnapshot(
        rateCardName: j['rate_card_name'] as String,
        // A snapshot frozen by an older build can hold rates of a retired
        // band; they were never chosen by the pricer now, so they are dropped.
        rates: [
          for (final e in j['rates'] as List)
            ?Rate.tryFromJson(e as Map<String, dynamic>),
        ],
        activities: (j['activities'] as List)
            .map((e) => ActivitySpec.fromJson(e as Map<String, dynamic>))
            .toList(),
        policy: BillingPolicy.fromJson(j['policy'] as Map<String, dynamic>),
        hours: BusinessHours.fromJson(j['hours'] as Map<String, dynamic>),
        holidays: (j['holidays'] as List)
            .map((e) => IstDate.parse(e as String))
            .toSet(),
        // Older snapshots predate explicit closures; absent means "none".
        closedDays: ((j['closed_days'] as List?) ?? const [])
            .map((e) => IstDate.parse(e as String))
            .toSet(),
        // Absent when the arena had no active rule.
        rules: [
          for (final e in (j['rules'] as List?) ?? const [])
            PricingRule.fromJson(e as Map<String, dynamic>),
        ],
      );
}
