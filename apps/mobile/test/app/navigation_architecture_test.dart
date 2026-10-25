import 'package:arena_ops/app/auth/auth_controller.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_catalog_repository.dart';
import 'package:arena_ops/data/local/local_customer_repository.dart';
import 'package:arena_ops/data/local/local_session_repository.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/features/controllers/presentation/controller_board_screen.dart';
import 'package:arena_ops/features/floor/presentation/floor_screen.dart';
import 'package:arena_ops/features/floor/presentation/station_detail_screen.dart';
import 'package:arena_ops/features/floor/presentation/widgets/station_card.dart';
import 'package:arena_ops/features/new_session/presentation/new_session_screen.dart';
import 'package:arena_ops/features/reports/presentation/session_log_screen.dart';
import 'package:arena_ops/app/router/app_shell.dart';
import 'package:arena_ops/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await seededMemoryDb();
  });

  tearDown(() async => db.close());

  Widget app({AuthController Function()? auth}) => ProviderScope(
        overrides: [
          ...testOverrides(db, auth: auth),
        ],
        child: const ArenaOpsApp(),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  void expectFullScreen(WidgetTester tester, Type screenType) {
    final screenFinder = find.byType(screenType);
    expect(screenFinder, findsOneWidget);
    final screenElement = tester.element(screenFinder);
    final screenRoute = ModalRoute.of(screenElement);
    expect(screenRoute?.isCurrent, isTrue,
        reason: '$screenType must be the current active top route');

    // The screen must NOT be inside AppShell (which would keep bottom nav visible).
    expect(
      find.descendant(of: find.byType(AppShell), matching: screenFinder),
      findsNothing,
      reason: '$screenType must be rendered outside AppShell on root navigator',
    );

    // AppShell must not be the active top route (either occluded or offstage).
    final appShellFinder = find.byType(AppShell);
    if (appShellFinder.evaluate().isNotEmpty) {
      final appShellElement = tester.element(appShellFinder);
      final appShellRoute = ModalRoute.of(appShellElement);
      expect(appShellRoute?.isCurrent, isFalse,
          reason: 'AppShell must be occluded by the full-screen route');
    }
  }

  group('Navigation Architecture Regression Suite', () {

    testWidgets('Primary tabs show bottom navigation bar', (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(FloorScreen), findsOneWidget);

      await tester.tap(find.text('Floor'));
      await settle(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(FloorScreen), findsOneWidget);

      await tester.tap(find.text('Bookings'));
      await settle(tester);
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.tap(find.text('More'));
      await settle(tester);
      expect(find.byType(NavigationBar), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets(
        'New Session opens full-screen without primary bottom navigation',
        (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);

      await tester.tap(find.text('Floor'));
      await settle(tester);

      // Tap FAB "New Session"
      await tester.tap(find.byType(FloatingActionButton));
      await settle(tester);

      // NewSessionScreen is full-screen outside AppShell.
      expectFullScreen(tester, NewSessionScreen);

      // Back returns to Floor with NavigationBar restored.
      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(find.byType(NewSessionScreen), findsNothing);
      expect(find.byType(FloorScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets(
        'StationDetailScreen hides bottom navigation and shows only its action bar',
        (tester) async {
      // Seed a live active session on station HEX.
      final catalog = LocalCatalogRepository(db);
      final customers = LocalCustomerRepository(db);
      final sessions = LocalSessionRepository(db);
      final customer = await customers.create(name: 'Test Gamer');
      final now = DateTime.now().toUtc();
      await sessions.start(StartSessionCommand(
        customerId: customer.id,
        resourceId: 'hex',
        resourceName: 'HEX',
        activityCode: 'PS5',
        gameId: 'g_eafc',
        controllerCount: 1,
        startedAt: now.subtract(const Duration(minutes: 15)),
        scheduledEndAt: now.add(const Duration(minutes: 45)),
        snapshot: await catalog.currentSnapshot(),
      ));

      await tester.pumpWidget(app());
      await settle(tester);

      await tester.tap(find.text('Floor'));
      await settle(tester);

      // Tap the active station card.
      final stationCards = find.byType(StationCard);
      expect(stationCards, findsWidgets);
      await tester.tap(stationCards.first);
      await settle(tester);

      // StationDetailScreen is full-screen outside AppShell.
      expectFullScreen(tester, StationDetailScreen);

      // StationDetail's own action buttons (Extend and Bill) are present.
      expect(
        find.descendant(
          of: find.byType(StationDetailScreen),
          matching: find.text('Extend'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StationDetailScreen),
          matching: find.text('Bill'),
        ),
        findsOneWidget,
      );

      // Back returns to Floor.
      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(find.byType(StationDetailScreen), findsNothing);
      expect(find.byType(FloorScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets(
        'Controller Board from More tab hides bottom navigation and returns to More',
        (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);

      await tester.tap(find.text('More'));
      await settle(tester);

      // Far enough that the row clears the bottom navigation bar.
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await settle(tester);
      await tester.tap(find.text('Controller board'));
      await settle(tester);

      expectFullScreen(tester, ControllerBoardScreen);

      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(find.byType(ControllerBoardScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets(
        'Session Log from More tab hides bottom navigation and returns to More',
        (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);

      await tester.tap(find.text('More'));
      await settle(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await settle(tester);
      await tester.tap(find.text('Session log'));
      await settle(tester);

      expectFullScreen(tester, SessionLogScreen);

      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(find.byType(SessionLogScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets(
        'Re-tapping the currently selected tab preserves state without discarding',
        (tester) async {
      await tester.pumpWidget(app());
      await settle(tester);

      final floorNav = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Floor'),
      );

      await tester.tap(floorNav);
      await settle(tester);

      expect(find.byType(FloorScreen), findsOneWidget);

      // Tap Floor tab again while already on Floor.
      await tester.tap(floorNav);
      await settle(tester);

      // Floor is still active and stable.
      expect(find.byType(FloorScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      await disposeApp(tester);
    });
  });
}
