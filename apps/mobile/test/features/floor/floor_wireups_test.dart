import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_db.dart';

/// Covers the Staff wire-ups added on top of the floor core:
///  - View Games per available station (spec §8, FR-FLOOR-05)
///  - honest Local-mode connection status (spec §4)
///  - custom session duration (spec §12)
void main() {
  late AppDatabase db;

  setUp(() async => db = await seededMemoryDb());
  tearDown(() async => db.close());

  Widget app() =>
      ProviderScope(overrides: testOverrides(db), child: const ArenaOpsApp());

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Floor shows Local mode status and Start on free stations',
      (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.text('Floor'));
    await settle(tester);

    // Honest connection status (local-first), not a misleading Online/Offline.
    expect(find.text('Local mode'), findsWidgets);
    // Free stations show a Start action (2-column card grid, like the design).
    expect(find.text('Start'), findsWidgets);

    await disposeApp(tester);
  });

  testWidgets('New Session duration offers a Custom option', (tester) async {
    await tester.pumpWidget(app());
    await settle(tester);

    await tester.tap(find.text('Floor'));
    await settle(tester);

    await tester.tap(find.text('New Session'));
    await settle(tester);

    // Presets plus Custom and Open (spec §12 custom duration).
    expect(find.text('60 min'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);

    await disposeApp(tester);
  });
}
