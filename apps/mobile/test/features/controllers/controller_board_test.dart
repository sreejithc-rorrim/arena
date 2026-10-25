/// Owner controller board (brief §7): renders stations + pads, flags a borrowed
/// pad and an in-use pad, and shows reconciled totals.
///
/// The board's dashboard() query is covered by the data-layer suite
/// (controller_allocation_test.dart); here the live provider is overridden with
/// a fixed snapshot so the RENDERING is tested deterministically (the real
/// provider watches Drift streams, which never idle under a widget test).
library;

import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_controller_allocation_repository.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/features/controllers/presentation/controller_board_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await seededMemoryDb());
  tearDown(() async => db.close());

  final t = DateTime.utc(2026, 10, 1, 9);

  // HEX-1: at home, in use by a session on EA FC at HEX.
  final hex1 = PadView(
    controller: Controller(
        id: 'ctl_hex_1', label: 'HEX-1', homeResourceId: 'hex',
        currentResourceId: 'hex', updatedAt: t),
    state: PadState.inUse,
    allocation: ControllerAllocationRow(
      id: 'a1', controllerId: 'ctl_hex_1', scope: 'single',
      resourceId: 'hex', activityCode: 'PS5', gameId: 'g_eafc',
      startedAt: t, createdAt: t,
    ),
  );
  // GHOST-1: physically moved to VOID (borrowed), not allocated.
  final ghost1 = PadView(
    controller: Controller(
        id: 'ctl_ghost_1', label: 'GHOST-1', homeResourceId: 'ghost',
        currentResourceId: 'void', updatedAt: t),
    state: PadState.available,
  );

  final dashboard = ControllerDashboard(
    pads: [hex1, ghost1],
    stations: const [
      StationView(id: 'hex', name: 'HEX', status: 'available', currentMode: null,
          inUseControllers: 1, usableControllers: 2),
      StationView(id: 'void', name: 'VOID', status: 'available', currentMode: null,
          inUseControllers: 0, usableControllers: 3),
    ],
    total: 8,
    inUse: 1,
    available: 7,
  );

  Widget app() => ProviderScope(
        overrides: [
          ...testOverrides(db),
          controllerBoardProvider.overrideWith((ref) async => dashboard),
        ],
        child: const MaterialApp(home: ControllerBoardScreen()),
      );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('shows totals, an in-use pad, and a borrowed pad', (tester) async {
    tester.view.physicalSize = const Size(1179, 4000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.text('Controller board'), findsOneWidget);
    expect(find.text('HEX-1'), findsWidgets);
    expect(find.text('GHOST-1'), findsWidgets);
    expect(find.text('IN USE'), findsWidgets); // totals cell + pad badge
    expect(find.text('BORROWED'), findsWidgets); // the moved GHOST-1
    // Totals reconcile and render.
    expect(find.text('7'), findsWidgets); // available
    expect(find.text('8'), findsWidgets); // total

    // The board also watches live tables (borrowed pads to return); tear the
    // tree down so no stream timer outlives the test, like the other suites.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('opened from More, it has a back button that returns there', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...testOverrides(db),
          controllerBoardProvider.overrideWith((ref) async => dashboard),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                // As More does: a pushed page.
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ControllerBoardScreen(),
                  ),
                ),
                child: const Text('More'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('More'));
    await settle(tester);
    expect(find.text('Controller board'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    // The page's exit transition, then it is gone (the board watches live
    // tables, so the tree never idles: no pumpAndSettle).
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Controller board'), findsNothing);
    expect(find.text('More'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
