// Integration test (spec §26): Start → Switch system → Extend → End → Pay →
// Daily report, with the real pricing engine, segment billing, Drift repos and
// the today-summary reporting end to end.

import 'package:arena_ops/app/controllers/session_actions.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/domain/entities/customer.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/domain/reports/report_models.dart';
import 'package:arena_ops/features/reports/application/reports_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pricing_fixtures.dart';
import '../support/test_db.dart';

void main() {
  test('start → switch → extend → end → pay → daily report', () async {
    final db = await seededMemoryDb();
    final clock = FakeClock(ist(2026, 10, 2, 18, 0)); // Friday 6:00 PM, standard
    final container = ProviderContainer(overrides: testOverrides(db, clock: clock));
    addTearDown(container.dispose);
    addTearDown(db.close);

    final actions = container.read(sessionActionsProvider);
    final repo = container.read(sessionRepositoryProvider);
    final Customer rahul =
        await container.read(customerRepositoryProvider).create(name: 'Rahul');

    // START — PS5, 2 controllers, 60 min on HEX.
    final started = await actions.start(NewSessionDraft(
      customerId: rahul.id,
      activityCode: 'PS5',
      resourceId: 'hex',
      resourceName: 'HEX',
      controllerCount: 2,
      durationMinutes: 60,
    ));
    expect(started.isOk, isTrue, reason: started.failureOrNull?.display);
    final session = started.valueOrNull!;

    // SWITCH — to VOID at 6:30 PM, same config.
    clock.set(ist(2026, 10, 2, 18, 30));
    final segs = await repo.segmentsFor(session.id);
    final current = segs.firstWhere((s) => s.isOpen);
    final switched = await actions.switchSystem(
      session: session,
      current: current,
      resourceId: 'void',
      resourceName: 'VOID',
      activityCode: 'PS5',
      controllerCount: 2,
    );
    expect(switched.isOk, isTrue, reason: switched.failureOrNull?.display);
    expect((await repo.segmentsFor(session.id)).length, 2);

    // EXTEND — +30 → scheduled end 7:30 PM.
    final extended =
        await actions.extend(session, await repo.segmentsFor(session.id), 30);
    expect(extended.isOk, isTrue, reason: extended.failureOrNull?.display);
    expect(extended.valueOrNull!.scheduledEndAt, ist(2026, 10, 2, 19, 30));

    // They play until 7:30 PM (HEX 30m + VOID 60m = 90m, all PS5 2c).
    clock.set(ist(2026, 10, 2, 19, 30));
    final ended = await actions.end(
        extended.valueOrNull!, await repo.segmentsFor(session.id));
    expect(ended.isOk, isTrue, reason: ended.failureOrNull?.display);
    expect(ended.valueOrNull!.billedAmountPaise, 42000); // 90 min PS5 2c = ₹420

    // PAY — ₹420 cash.
    await actions.recordPayment(RecordPaymentCommand(
      sessionId: session.id, amountPaise: 42000, method: PaymentMethod.cash));
    expect((await repo.getById(session.id))!.paymentStatus, PaymentStatus.paid);

    // DAILY REPORT.
    final summary = await container.read(reportForRangeProvider(
        ReportRange.today(IstDate.fromUtc(container.read(clockProvider).now()))).future);
    expect(summary.billedPaise, 42000);
    expect(summary.collectedPaise, 42000);
    expect(summary.pendingPaise, 0);
    expect(summary.sessionCount, 1);
    expect(summary.gamingMinutes, 90);
  });
}
