// Integration: a rate card saved in Settings → Pricing, then preview → live
// total → End & Bill → recorded bill → payment, through the real controllers,
// Drift repositories and pricing engine. Every figure must be ₹150 per
// controller per hour (10% less in the happy hour).

import 'package:arena_ops/app/controllers/catalog_actions.dart';
import 'package:arena_ops/app/controllers/session_actions.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/pricing/rate.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pricing_fixtures.dart';
import '../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late ProviderContainer container;

  /// A seeded arena at [at] whose owner saved ₹150 × controllers per hour
  /// for PS5; the seeded happy hour (Tue–Fri 14:00–17:00) is set to −10%.
  /// Unless [keepPads], pads are removed so 3–4 controllers can be asked for
  /// on one station (the seed has two per station).
  Future<void> arena(DateTime at, {bool keepPads = false}) async {
    db = await seededMemoryDb();
    clock = FakeClock(at);
    container = ProviderContainer(overrides: testOverrides(db, clock: clock));
    addTearDown(container.dispose);
    addTearDown(db.close);
    if (!keepPads) await db.delete(db.controllers).go();
    await (db.update(db.pricingRules)..where((t) => t.id.equals('rule_demo_1')))
        .write(const PricingRulesCompanion(adjustValue: Value(-10)));
    final catalog = container.read(catalogActionsProvider);
    for (final n in [1, 2, 3, 4]) {
      final saved = await catalog.saveRate(Rate(
        activityCode: 'PS5',
        band: Band.standard,
        controllerCount: n,
        unitMinutes: 60,
        price: Paise(15000 * n),
      ));
      expect(saved.isOk, isTrue, reason: saved.failureOrNull?.display);
    }
  }

  /// One hour on each PS5 at 1–4 controllers; every stage must equal
  /// [expected] for that count.
  Future<void> playOneHourEach(Map<int, int> expected) async {
    final actions = container.read(sessionActionsProvider);
    final repo = container.read(sessionRepositoryProvider);
    final customer =
        await container.read(customerRepositoryProvider).create(name: 'Asha');
    const stations = {1: 'hex', 2: 'void', 3: 'ghost', 4: 'rift'};

    final started = <int, Session>{};
    for (final n in expected.keys) {
      final draft = NewSessionDraft(
        customerId: customer.id,
        activityCode: 'PS5',
        resourceId: stations[n],
        resourceName: stations[n]!.toUpperCase(),
        controllerCount: n,
        durationMinutes: 60,
      );
      final preview = await actions.previewStart(draft);
      expect(preview.valueOrNull?.quote.amount, Paise(expected[n]!),
          reason: 'preview, $n ctrl: ${preview.failureOrNull?.display}');
      final s = await actions.start(draft);
      expect(s.isOk, isTrue, reason: s.failureOrNull?.display);
      started[n] = s.valueOrNull!;
    }

    clock.advance(const Duration(hours: 1));
    final now = clock.now();
    for (final MapEntry(key: n, value: session) in started.entries) {
      final want = Paise(expected[n]!);
      final segs = await repo.segmentsFor(session.id);
      expect(
          actions
              .liveBill(ActiveSession(session: session, segments: segs), now)
              .total,
          want,
          reason: 'live, $n ctrl');
      expect(actions.endSummary(session, segs, at: now).total, want,
          reason: 'End & Bill, $n ctrl');

      final ended = await actions.end(session, segs, at: now);
      expect(ended.isOk, isTrue, reason: ended.failureOrNull?.display);
      expect(ended.valueOrNull!.billedAmountPaise, want.value,
          reason: 'recorded bill, $n ctrl');

      final paid = await actions.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: want.value,
        method: PaymentMethod.cash,
      ));
      expect(paid.isOk, isTrue, reason: paid.failureOrNull?.display);
      final payments = await repo.paymentsFor(session.id);
      expect(payments.fold<int>(0, (a, p) => a + p.amountPaise), want.value,
          reason: 'recorded payment, $n ctrl');
      expect((await repo.getById(session.id))!.paymentStatus,
          PaymentStatus.paid);
    }
  }

  test('standard hour: ₹150 / ₹300 / ₹450 / ₹600 at every stage', () async {
    await arena(ist(2026, 10, 2, 18, 0)); // Friday 6 PM, no rule
    await playOneHourEach({1: 15000, 2: 30000, 3: 45000, 4: 60000});
  });

  test('10% happy hour: ₹135 / ₹270 / ₹405 / ₹540 at every stage', () async {
    await arena(ist(2026, 10, 2, 14, 0)); // Friday 2 PM, inside the rule
    await playOneHourEach({1: 13500, 2: 27000, 3: 40500, 4: 54000});
  });
}
