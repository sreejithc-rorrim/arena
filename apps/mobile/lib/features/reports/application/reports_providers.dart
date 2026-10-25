/// Assembles an [ArenaReport] for a chosen window from the persisted rows.
///
/// All arithmetic lives in the pure [ReportsService]; this layer only fetches.
/// Nothing here invents a figure — an empty arena produces an empty report,
/// not a plausible-looking dashboard.
library;

import 'package:arena_ops/app/sync/cloud_binding.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/domain/reports/report_models.dart';
import 'package:arena_ops/domain/reports/reports_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The report for any window — used by the session log.
final reportForRangeProvider =
    FutureProvider.autoDispose.family<ArenaReport, ReportRange>(
        (ref, range) async {
  // Recompute when the floor changes, so "today" stays live.
  ref.watch(activeSessionsProvider);
  ref.watch(awaitingPaymentProvider);
  // …and when another device's bills or payments arrive by sync.
  ref.watch(syncRevisionProvider);

  final sessionRepo = ref.watch(sessionRepositoryProvider);
  final catalog = ref.watch(catalogRepositoryProvider);
  final customerRepo = ref.watch(customerRepositoryProvider);

  final from = range.startUtc;
  final to = range.endUtc;

  // Independent reads, issued together.
  final sessions = sessionRepo.inRange(from, to);
  final segments = sessionRepo.segmentsInRange(from, to);
  final charges = sessionRepo.chargesInRange(from, to);
  final payments = sessionRepo.paymentsInRange(from, to);
  final customers = customerRepo.all();
  final resources = catalog.resources();
  final games = catalog.games();
  final activities = catalog.activities();
  final snapshot = catalog.currentSnapshot();

  return const ReportsService().build(ReportInput(
    range: range,
    sessions: await sessions,
    segments: await segments,
    charges: await charges,
    payments: await payments,
    customers: await customers,
    resources: await resources,
    gameNames: {for (final g in await games) g.id: g.name},
    activityNames: {for (final a in await activities) a.code: a.name},
    // Operating hours decide the utilisation denominator, so the report uses
    // the same calendar the pricing engine does.
    calendar: (await snapshot).calendar,
  ));
});
