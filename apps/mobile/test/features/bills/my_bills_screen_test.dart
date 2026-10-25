/// Widget-level: Bills (My bills) asks for the IST business day the web's
/// Sales uses, and after a missed bill is added for another day it shows that
/// day, with the amount paid and — in the bill — today's price and the
/// difference, as the web does.
library;

import 'package:arena_ops/app/providers/my_bills_providers.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/domain/bills/my_bill.dart';
import 'package:arena_ops/domain/repositories/my_bills_repository.dart';
import 'package:arena_ops/features/bills/presentation/my_bills_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pricing_fixtures.dart';
import '../../support/test_db.dart';

/// Answers as the server does: today's price is ₹150; the bills added are
/// listed on the IST day they closed on, in my_bills' shape.
class _Bills implements MyBillsRepository {
  final days = <IstDate>[];
  final recorded = <MissedBillCommand>[];

  @override
  Future<Result<List<MyBill>>> forDay(IstDate day) async {
    days.add(day);
    return Ok([
      for (final c in recorded)
        if (IstDate.fromUtc(c.endedAt) == day)
          MyBill.fromJson({
            'kind': 'single',
            'id': c.id,
            'at': c.endedAt.toIso8601String(),
            'started_at': c.startedAt.toIso8601String(),
            'ended_at': c.endedAt.toIso8601String(),
            'status': 'completed',
            'payment_status': 'paid',
            'customer': 'Walk-in',
            'guest': true,
            'stations': ['HEX'],
            'games': <String>[],
            'billed_paise': c.paidPaise,
            'paid_paise': c.paidPaise,
            'methods': {c.method.code: c.paidPaise},
            'payments': [
              if (c.paidPaise > 0)
                {
                  'id': c.paymentId,
                  'at': c.endedAt.toIso8601String(),
                  'amount_paise': c.paidPaise,
                  'method': c.method.code,
                  'note': 'Added later',
                  'reason': c.reason.trim(),
                  'by': 'Owner',
                },
            ],
            'quoted_paise': c.billedPaise,
          }),
    ]);
  }

  @override
  Future<Result<String>> adjust(BillAdjustCommand cmd) async => const Ok('paid');

  @override
  Future<Result<int>> quote({
    required String resourceId,
    required String activityCode,
    int? controllerCount,
    required DateTime from,
    required DateTime to,
  }) async => const Ok(15000);

  @override
  Future<Result<int>> record(MissedBillCommand cmd) async {
    recorded.add(cmd);
    return Ok(cmd.paidPaise);
  }
}

void main() {
  late AppDatabase db;
  late _Bills bills;

  setUp(() async {
    db = await seededMemoryDb();
    bills = _Bills();
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> disposeApp(WidgetTester tester) async {
    // Let any toast (3 s, or 6 s for an error) time out first.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openBills(WidgetTester tester, DateTime now) async {
    tester.view.physicalSize = const Size(1179, 5200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db, clock: FakeClock(now)),
          myBillsRepositoryProvider.overrideWithValue(bills),
        ],
        child: const MaterialApp(home: MyBillsScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('just after IST midnight it asks for the new IST day, not the '
      'UTC date', (tester) async {
    // 01:00 IST Mon 26 Oct is still Sun 25 Oct in UTC.
    final now = ist(2026, 10, 26, 1, 0);
    expect(now.toUtc().day, 25);
    await openBills(tester, now);
    expect(bills.days, [const IstDate(2026, 10, 26)]);
    expect(find.text('Today · Mon 26 Oct 2026'), findsOneWidget);
    await disposeApp(tester);
  });

  testWidgets('a missed bill added for another day: the list moves to that '
      'day and shows it at the amount paid, with the price in the bill',
      (tester) async {
    await openBills(tester, ist(2026, 10, 25, 20, 0));
    expect(find.text('Today · Sun 25 Oct 2026'), findsOneWidget);

    await tester.tap(find.text('Add missed bill'));
    await settle(tester);
    await tester.tap(find.text('Pick customer'));
    await settle(tester);
    await tester.tap(find.text('Walk-in — start without details'));
    await settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await settle(tester);
    await tester.tap(find.text('HEX').last);
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '1'));
    await settle(tester);
    // The bill's date: Fri 23 Oct, while the list shows today.
    await tester.tap(find.text('Sun 25 Oct 2026'));
    await settle(tester);
    await tester.tap(find.text('23'));
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('Fri 23 Oct 2026'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('missed-bill-amount')),
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason (required)'),
      'Power cut',
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('missed-bill-save')));
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Add bill'),
      ),
    );
    await settle(tester);

    expect(IstDate.fromUtc(bills.recorded.single.endedAt),
        const IstDate(2026, 10, 23));
    expect(find.text('Fri 23 Oct 2026'), findsOneWidget,
        reason: 'the list shows the day the bill closed on');
    expect(bills.days.last, const IstDate(2026, 10, 23));
    expect(find.text('₹100'), findsOneWidget, reason: 'the amount paid');
    expect(find.text('Added later'), findsOneWidget);

    await tester.tap(find.text('₹100'));
    await settle(tester);
    expect(find.text('Billed ₹100 · Collected ₹100'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('bill-added-later')))
          .data,
      'Added later. Played but never started on the floor. '
      'Priced ₹150 on today\'s list; ₹100 paid.',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('bill-paid-adjustment')))
          .data,
      'Adjusted to amount paid −₹50',
    );
    await disposeApp(tester);
  });
}
