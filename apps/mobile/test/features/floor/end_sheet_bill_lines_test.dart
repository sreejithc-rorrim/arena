/// Widget-level: the End sheet's bill lines add up to its total (#22). Lines
/// show their exact amounts; cash rounding, applied once to the total, gets a
/// line of its own, as in the dashboard's Sales.
library;

import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_catalog_repository.dart';
import 'package:arena_ops/data/local/local_customer_repository.dart';
import 'package:arena_ops/data/local/local_session_repository.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/features/floor/presentation/sheets/end_session_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pricing_fixtures.dart';
import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  // Friday evening: standard band, no time rule; ₹150/h for one controller,
  // billed per minute, cash rounded to the nearest ₹1 (seed defaults).
  final now = ist(2026, 10, 2, 19, 2);

  setUp(() async => db = await seededMemoryDb());
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// Opens the End sheet for a one-controller PS5 session on HEX that started
  /// [played] ago; the game changes [changeAt] after the start, when given.
  Future<void> openEndSheet(
    WidgetTester tester, {
    required Duration played,
    Duration? changeAt,
  }) async {
    tester.view.physicalSize = const Size(1179, 5200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final who = await LocalCustomerRepository(db).create(name: 'Meera');
    final sessions = LocalSessionRepository(db);
    final startedAt = now.subtract(played);
    final started = await sessions.start(StartSessionCommand(
      customerId: who.id,
      startedAt: startedAt,
      scheduledEndAt: now,
      snapshot: await LocalCatalogRepository(db).currentSnapshot(),
      resourceId: 'hex',
      resourceName: 'HEX',
      activityCode: 'PS5',
      controllerCount: 1,
    ));
    expect(started.isOk, isTrue, reason: '${started.failureOrNull?.message}');
    if (changeAt != null) {
      final changed = await sessions.reconfigure(ReconfigureCommand(
        sessionId: started.valueOrNull!.id,
        at: startedAt.add(changeAt),
        resourceId: 'hex',
        resourceName: 'HEX',
        activityCode: 'PS5',
        gameId: 'g_eafc',
        controllerCount: 1,
      ));
      expect(changed.isOk, isTrue, reason: '${changed.failureOrNull?.message}');
    }
    final active = (await sessions.active()).single;

    await tester.pumpWidget(ProviderScope(
      overrides: testOverrides(db, clock: FakeClock(now)),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEndSessionSheet(context, active),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('lines show exact amounts and a Rounding line makes up the total',
      (tester) async {
    // 11 min = ₹27.50, then 42 min = ₹105: ₹132.50, cash rounded to ₹133.
    await openEndSheet(tester,
        played: const Duration(minutes: 53),
        changeAt: const Duration(minutes: 11));

    expect(find.text('₹27.50'), findsOneWidget);
    expect(find.text('₹105'), findsOneWidget);
    expect(find.text('₹28'), findsNothing,
        reason: 'a line is no longer rounded on its own');
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('bill-rounding')),
            matching: find.text('₹0.50')),
        findsOneWidget);
    // ₹27.50 + ₹105 + ₹0.50 = ₹133.
    expect(find.text('₹133'), findsWidgets);

    await close(tester);
  });

  testWidgets('no Rounding line when the lines already make the total',
      (tester) async {
    await openEndSheet(tester, played: const Duration(hours: 1));

    expect(find.byKey(const ValueKey('bill-rounding')), findsNothing);
    expect(find.text('₹150'), findsWidgets);

    await close(tester);
  });
}
