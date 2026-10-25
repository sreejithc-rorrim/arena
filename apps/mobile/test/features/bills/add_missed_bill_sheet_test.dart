/// Widget-level: Bills › Add missed bill asks what the customer actually paid,
/// fills it in with today's price, shows the difference, and keeps Add bill off
/// until the amount and the reason are valid, saying what is missing.
library;

import 'package:arena_ops/app/providers/my_bills_providers.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/money/rupee_input.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/remote/bill_failures.dart';
import 'package:arena_ops/domain/bills/my_bill.dart';
import 'package:arena_ops/domain/repositories/my_bills_repository.dart';
import 'package:arena_ops/features/bills/presentation/add_missed_bill_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pricing_fixtures.dart';
import '../../support/test_db.dart';

/// Today's price is [price] (or [quoteFailure]); keeps the bills added.
class _Bills implements MyBillsRepository {
  int price = 15000;
  Failure? quoteFailure;
  final recorded = <MissedBillCommand>[];

  @override
  Future<Result<List<MyBill>>> forDay(IstDate day) async => const Ok([]);

  @override
  Future<Result<String>> adjust(BillAdjustCommand cmd) async => const Ok('paid');

  @override
  Future<Result<int>> quote({
    required String resourceId,
    required String activityCode,
    int? controllerCount,
    required DateTime from,
    required DateTime to,
  }) async => quoteFailure == null ? Ok(price) : Err(quoteFailure!);

  @override
  Future<Result<int>> record(MissedBillCommand cmd) async {
    recorded.add(cmd);
    return Ok(cmd.paidPaise);
  }
}

void main() {
  late AppDatabase db;
  late _Bills bills;

  /// What the sheet resolved to: the day the added bill closed on.
  IstDate? closedOn;

  setUp(() async {
    db = await seededMemoryDb();
    bills = _Bills();
    closedOn = null;
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

  Finder amountField() => find.byKey(const ValueKey('missed-bill-amount'));
  String amount(WidgetTester tester) =>
      tester.widget<TextField>(amountField()).controller!.text;
  InputDecoration amountDecoration(WidgetTester tester) =>
      tester.widget<TextField>(amountField()).decoration!;
  bool canSave(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('missed-bill-save')))
          .onPressed !=
      null;
  String? missing(WidgetTester tester) {
    final f = find.byKey(const ValueKey('missed-bill-missing'));
    return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
  }

  Finder reason() => find.widgetWithText(TextField, 'Reason (required)');

  /// Opens the sheet, picks a walk-in, HEX and one controller: priced at
  /// today's price, amount filled in.
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 5200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db, clock: FakeClock(ist(2026, 10, 2, 20, 0))),
          myBillsRepositoryProvider.overrideWithValue(bills),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => closedOn = await showAddMissedBillSheet(
                  context,
                  day: const IstDate(2026, 10, 2),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
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
  }

  testWidgets('the amount paid is filled in with the price and shows how it '
      'differs', (tester) async {
    await open(tester);
    expect(amount(tester), '150.00');
    expect(amountDecoration(tester).helperText, 'Same as today\'s price');

    await tester.enterText(amountField(), '100');
    await settle(tester);
    expect(amountDecoration(tester).helperText, '₹50 less than today\'s price');
    await tester.enterText(amountField(), '170');
    await settle(tester);
    expect(amountDecoration(tester).helperText, '₹20 more than today\'s price');
    await disposeApp(tester);
  });

  testWidgets('Add bill stays off until the amount paid and the reason are '
      'valid', (tester) async {
    await open(tester);
    expect(canSave(tester), isFalse);
    expect(missing(tester), 'Say why the bill is added later.');

    await tester.enterText(reason(), '   ');
    await settle(tester);
    expect(canSave(tester), isFalse, reason: 'a blank reason is no reason');
    await tester.enterText(reason(), 'Power cut');
    await settle(tester);
    expect(canSave(tester), isTrue);
    expect(missing(tester), isNull);

    await tester.enterText(amountField(), '');
    await settle(tester);
    expect(canSave(tester), isFalse);
    expect(missing(tester), 'Enter what the customer paid.');

    for (final bad in ['12.345', '1,5', '.']) {
      await tester.enterText(amountField(), bad);
      await settle(tester);
      expect(canSave(tester), isFalse, reason: bad);
      expect(amountDecoration(tester).errorText, rupeeInputError, reason: bad);
    }

    await tester.enterText(amountField(), '0');
    await settle(tester);
    expect(canSave(tester), isTrue, reason: 'nothing paid is an amount');
    await disposeApp(tester);
  });

  testWidgets('the bill is added at the amount paid, with the price shown',
      (tester) async {
    await open(tester);
    await tester.enterText(amountField(), '100');
    await tester.enterText(reason(), '  Old rate  ');
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('missed-bill-save')));
    await settle(tester);
    expect(find.text('Add this bill for ₹100?'), findsOneWidget);
    expect(find.textContaining('Today\'s price is ₹150.'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Add bill'),
      ),
    );
    await settle(tester);

    final cmd = bills.recorded.single;
    expect(cmd.billedPaise, 15000);
    expect(cmd.paidPaise, 10000);
    expect(cmd.toPayload()['paid_amount_paise'], 10000);
    expect(cmd.toPayload()['reason'], 'Old rate');
    expect(find.text('Bill added: ₹100.'), findsOneWidget);
    expect(closedOn, const IstDate(2026, 10, 2),
        reason: 'the list is told which day to show');
    await disposeApp(tester);
  });

  testWidgets('a price that cannot be worked out says what to do, not to wait',
      (tester) async {
    bills.quoteFailure = BillFailures.rejected('no_rate', null);
    await open(tester);
    await tester.enterText(amountField(), '100');
    await tester.enterText(reason(), 'Power cut');
    await settle(tester);
    expect(find.text(bills.quoteFailure!.message), findsOneWidget);
    expect(canSave(tester), isFalse);
    expect(missing(tester), bills.quoteFailure!.fix);
    expect(find.text('Wait for the price.'), findsNothing);

    bills.quoteFailure = null;
    await tester.tap(find.widgetWithText(ChoiceChip, '2'));
    await settle(tester);
    expect(canSave(tester), isTrue, reason: 'priced again');
    await disposeApp(tester);
  });

  testWidgets('a typed amount survives a new price; a cleared one follows the '
      'price again', (tester) async {
    await open(tester);
    await tester.enterText(amountField(), '100');
    await settle(tester);
    bills.price = 28000;
    await tester.tap(find.widgetWithText(ChoiceChip, '2'));
    await settle(tester);
    expect(amount(tester), '100');
    expect(amountDecoration(tester).helperText, '₹180 less than today\'s price');

    await tester.enterText(amountField(), '');
    await settle(tester);
    bills.price = 15000;
    await tester.tap(find.widgetWithText(ChoiceChip, '1'));
    await settle(tester);
    expect(amount(tester), '150.00');
    await disposeApp(tester);
  });
}
