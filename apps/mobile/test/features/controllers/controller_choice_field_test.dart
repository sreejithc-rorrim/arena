/// The staff controller UI as it is actually used: one control where the count
/// and the physical pads are the same thing, an estimate that follows them,
/// explicit borrowing, reasons for unavailable pads, the game limit, active
/// session changes and switching.
library;

import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_catalog_repository.dart';
import 'package:arena_ops/data/local/local_controller_allocation_repository.dart';
import 'package:arena_ops/data/local/local_customer_repository.dart';
import 'package:arena_ops/data/local/local_session_repository.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/features/controllers/presentation/controller_board_screen.dart';
import 'package:arena_ops/features/floor/presentation/sheets/change_controllers_sheet.dart';
import 'package:arena_ops/features/floor/presentation/sheets/switch_system_sheet.dart';
import 'package:arena_ops/features/new_session/presentation/new_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pricing_fixtures.dart';
import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  final start = ist(2026, 10, 2, 18, 0); // standard band

  setUp(() async => db = await seededMemoryDb());
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

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 5200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Widget host(Widget child) => ProviderScope(
    overrides: testOverrides(db, clock: FakeClock(start)),
    child: MaterialApp(home: child),
  );

  Future<Resource> station(String id) async => (await LocalCatalogRepository(
    db,
  ).resources()).firstWhere((r) => r.id == id);

  Future<Set<String>> held() async => {
    for (final a in await LocalControllerAllocationRepository(
      db,
    ).openPadAllocations())
      a.controllerId,
  };

  FilterChip pad(WidgetTester tester, String id) =>
      tester.widget<FilterChip>(find.byKey(ValueKey('pad-$id')));
  ChoiceChip count(WidgetTester tester, int n) =>
      tester.widget<ChoiceChip>(find.byKey(ValueKey('ctl-count-$n')));
  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;
  FilledButton startButton(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(FilledButton),
        ),
      );

  Future<void> openNewSession(WidgetTester tester, String stationId) async {
    await tester.pumpWidget(
      host(NewSessionScreen(initialResource: await station(stationId))),
    );
    await settle(tester);
    await tester.tap(find.text('Select customer'));
    await settle(tester);
    await tester.tap(find.text('Walk-in — start without details'));
    await settle(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey(key)));
    await settle(tester);
  }

  testWidgets('count 1–2 auto-picks pads; 3–4 at a 2-pad station shows the '
      'shortfall and blocks Start', (tester) async {
    phone(tester);
    await openNewSession(tester, 'hex');

    await tapKey(tester, 'ctl-count-1');
    expect(text(tester, 'pad-selected'), 'Selected: HEX-1');
    expect(text(tester, 'estimate-amount'), '₹150');

    await tapKey(tester, 'ctl-count-2');
    expect(text(tester, 'pad-selected'), 'Selected: HEX-1, HEX-2');
    expect(pad(tester, 'ctl_hex_2').selected, isTrue);
    expect(text(tester, 'estimate-amount'), '₹280');
    expect(
      text(tester, 'estimate-was'),
      'was ₹150',
      reason: 'the estimate change is called out',
    );
    expect(text(tester, 'estimate-summary'), '1h · 2 controllers');

    for (final n in [3, 4]) {
      await tapKey(tester, 'ctl-count-$n');
      expect(count(tester, n).selected, isTrue);
      expect(
        text(tester, 'pad-selected'),
        'Selected: HEX-1, HEX-2',
        reason: 'never silently borrows or claims pads it does not have',
      );
      expect(
        text(tester, 'pad-shortfall'),
        contains('$n requested, 2 selected — only 2 free at HEX.'),
      );
      expect(startButton(tester, 'Start session').onPressed, isNull);
    }
    expect(
      text(tester, 'pad-summary'),
      '2 free here · 6 free elsewhere · 8 of 8 usable',
    );
    await disposeApp(tester);
  });

  testWidgets('borrowing fills the gap; count, pads and price stay in step; '
      'the pad moves only at Start', (tester) async {
    phone(tester);
    await openNewSession(tester, 'hex');
    await tapKey(tester, 'ctl-count-4');
    // The borrow list opened itself because of the shortfall.
    await tapKey(tester, 'pad-ctl_void_1');
    // Regression (found on the simulator): one borrow toward 4 must not shrink
    // the request to 3 and quietly enable Start.
    expect(count(tester, 4).selected, isTrue);
    expect(startButton(tester, 'Start session').onPressed, isNull);
    await tapKey(tester, 'pad-ctl_void_2');
    expect(count(tester, 4).selected, isTrue);
    expect(
      text(tester, 'pad-selected'),
      'Selected: HEX-1, HEX-2, VOID-1 (borrow), VOID-2 (borrow)',
    );
    expect(text(tester, 'estimate-amount'), '₹480');
    expect(find.byKey(const ValueKey('pad-shortfall')), findsNothing);

    // Lower to 3: the last-picked pad drops out.
    await tapKey(tester, 'ctl-count-3');
    expect(
      text(tester, 'pad-selected'),
      'Selected: HEX-1, HEX-2, VOID-1 (borrow)',
    );
    expect(text(tester, 'estimate-amount'), '₹390');

    // Un-pick HEX-2 by hand: the count follows immediately.
    await tapKey(tester, 'pad-ctl_hex_2');
    expect(count(tester, 2).selected, isTrue);
    expect(text(tester, 'estimate-amount'), '₹280');

    // Not moved yet.
    final before = (await LocalCatalogRepository(
      db,
    ).controllers()).firstWhere((c) => c.id == 'ctl_void_1');
    expect(before.currentResourceId, 'void');

    await tester.tap(find.text('Start session'));
    await settle(tester);
    expect(await held(), {'ctl_hex_1', 'ctl_void_1'});
    final moved = (await LocalCatalogRepository(
      db,
    ).controllers()).firstWhere((c) => c.id == 'ctl_void_1');
    expect(moved.currentResourceId, 'hex');
    expect(moved.loanReturnTo, 'void');
    await disposeApp(tester);
  });

  testWidgets('unavailable pads show why; loading never says "none"', (
    tester,
  ) async {
    phone(tester);
    await LocalCatalogRepository(db)
        .setControllerStatus('ctl_hex_2', ControllerStatus.faulty);
    await tester.pumpWidget(
      host(NewSessionScreen(initialResource: await station('hex'))),
    );
    // First frame, before the live reads land.
    await tester.pump();
    expect(find.textContaining('No controllers'), findsNothing);
    await settle(tester);

    expect(find.text('HEX-2 · faulty'), findsOneWidget);
    expect(pad(tester, 'ctl_hex_2').onSelected, isNull);
    await tapKey(tester, 'ctl-count-2');
    expect(text(tester, 'pad-selected'), 'Selected: HEX-1');
    expect(
      text(tester, 'pad-summary'),
      '1 free here · 6 free elsewhere · 7 of 8 usable',
    );
    await disposeApp(tester);
  });

  testWidgets('a game limit disables higher counts and trims the pick', (
    tester,
  ) async {
    phone(tester);
    await openNewSession(tester, 'hex');
    await tapKey(tester, 'ctl-count-2');
    await tester.tap(find.text('Select game (optional)'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'God of War');
    await settle(tester);
    await tester.tap(find.text('God of War Ragnarok').last);
    await settle(tester);

    expect(text(tester, 'pad-selected'), 'Selected: HEX-1');
    expect(count(tester, 2).onSelected, isNull);
    expect(
      find.text('God of War Ragnarok supports up to 1 local player.'),
      findsOneWidget,
    );
    expect(text(tester, 'estimate-amount'), '₹150');
    await disposeApp(tester);
  });

  Future<void> seedHex(List<String> pads) async {
    final who = await LocalCustomerRepository(db)
        .create(name: 'Kabir', phone: '9000000001');
    final r = await LocalSessionRepository(db).start(
      StartSessionCommand(
        customerId: who.id,
        startedAt: start,
        scheduledEndAt: start.add(const Duration(hours: 1)),
        snapshot: await LocalCatalogRepository(db).currentSnapshot(),
        resourceId: 'hex',
        resourceName: 'HEX',
        activityCode: 'PS5',
        controllerCount: pads.length,
        controllerIds: pads,
      ),
    );
    expect(r.isOk, isTrue);
  }

  Widget opener(void Function(BuildContext) open) => host(
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => open(context),
          child: const Text('open'),
        ),
      ),
    ),
  );

  testWidgets('active session: current pads shown; add one; the rate change '
      'is shown; timer kept', (tester) async {
    phone(tester);
    await seedHex(['ctl_hex_1']);
    final active = (await LocalSessionRepository(db).active()).single;
    await tester.pumpWidget(
      opener((c) => showChangeControllersSheet(c, active)),
    );
    await tester.tap(find.text('open'));
    await settle(tester);

    expect(text(tester, 'current-pads'), 'Now 1 · HEX-1');
    expect(pad(tester, 'ctl_hex_1').selected, isTrue);
    expect(startButton(tester, 'Apply').onPressed, isNull);

    await tapKey(tester, 'ctl-count-2');
    expect(text(tester, 'pad-selected'), 'Selected: HEX-1, HEX-2');
    expect(text(tester, 'rate-change'), contains('Next hour: ₹150 → ₹280'));
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await settle(tester);

    expect(await held(), {'ctl_hex_1', 'ctl_hex_2'});
    final after = (await LocalSessionRepository(db).active()).single;
    expect(after.segments, hasLength(2));
    expect(after.session.startedAt, active.session.startedAt);
    expect(after.session.scheduledEndAt, active.session.scheduledEndAt);
    await disposeApp(tester);
  });

  testWidgets('switch system: the same count is auto-picked at the target', (
    tester,
  ) async {
    phone(tester);
    await seedHex(['ctl_hex_1', 'ctl_hex_2']);
    final active = (await LocalSessionRepository(db).active()).single;
    await tester.pumpWidget(opener((c) => showSwitchSystemSheet(c, active)));
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.text('VOID'));
    await settle(tester);

    expect(text(tester, 'pad-selected'), 'Selected: VOID-1, VOID-2');
    await tester.tap(find.text('Switch to VOID'));
    await settle(tester);
    expect(await held(), {'ctl_void_1', 'ctl_void_2'});
    expect(
      (await LocalSessionRepository(db).active()).single.current.resourceId,
      'void',
    );
    await disposeApp(tester);
  });

  testWidgets('after the bill, a borrowed pad can still be marked returned '
      'from the controller board (location history recorded)', (tester) async {
    phone(tester);
    final who = await LocalCustomerRepository(db)
        .create(name: 'Kabir', phone: '9000000001');
    final sessions = LocalSessionRepository(db);
    final started = await sessions.start(
      StartSessionCommand(
        customerId: who.id,
        startedAt: start,
        scheduledEndAt: start.add(const Duration(hours: 1)),
        snapshot: await LocalCatalogRepository(db).currentSnapshot(),
        resourceId: 'void',
        resourceName: 'VOID',
        activityCode: 'PS5',
        controllerCount: 1,
        controllerIds: ['ctl_hex_1'],
        borrowControllerIds: ['ctl_hex_1'],
      ),
    );
    expect(started.isOk, isTrue);
    await sessions.end(
      EndSessionCommand(
        sessionId: started.valueOrNull!.id,
        actualEndedAt: start.add(const Duration(hours: 1)),
        charges: const [],
        billedAmountPaise: 15000,
      ),
    );

    await tester.pumpWidget(host(const ControllerBoardScreen()));
    await settle(tester);
    expect(find.text('HEX-1 → return to HEX'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('return-ctl_hex_1')));
    await settle(tester);

    final pad = (await LocalCatalogRepository(
      db,
    ).controllers()).firstWhere((c) => c.id == 'ctl_hex_1');
    expect(pad.currentResourceId, 'hex');
    final moves = await LocalControllerAllocationRepository(db)
        .movesForController(pad.id);
    expect(moves.map((m) => '${m.fromResourceId}->${m.toResourceId}'), [
      'hex->void',
      'void->hex',
    ]);
    expect(find.text('HEX-1 → return to HEX'), findsNothing);
    await disposeApp(tester);
  });

  testWidgets('HEX holds VOID-1/2: New Session at VOID shows where they are, '
      'suggests GHOST, and starts by borrowing GHOST-1/2', (tester) async {
    phone(tester);
    final who = await LocalCustomerRepository(db).create(name: 'Kabir');
    final hexStart = await LocalSessionRepository(db).start(
      StartSessionCommand(
        customerId: who.id,
        startedAt: start,
        scheduledEndAt: start.add(const Duration(hours: 1)),
        snapshot: await LocalCatalogRepository(db).currentSnapshot(),
        resourceId: 'hex',
        resourceName: 'HEX',
        activityCode: 'PS5',
        controllerCount: 4,
        controllerIds: const [
          'ctl_hex_1',
          'ctl_hex_2',
          'ctl_void_1',
          'ctl_void_2',
        ],
        borrowControllerIds: const ['ctl_void_1', 'ctl_void_2'],
      ),
    );
    expect(hexStart.isOk, isTrue);

    await openNewSession(tester, 'void');
    await tapKey(tester, 'ctl-count-2');

    expect(
      text(tester, 'pad-own-away'),
      "VOID's own: VOID-1 in use at HEX · VOID-2 in use at HEX",
    );
    expect(
      text(tester, 'pad-shortfall'),
      contains('2 requested, 0 selected — only 0 free at VOID.'),
    );
    expect(
      text(tester, 'pad-suggest'),
      'Or start at GHOST (2 free there) or RIFT (2 free there).',
    );
    // In-use pads are listed with the reason and cannot be picked.
    expect(find.text('VOID-1 · in use at HEX'), findsOneWidget);
    expect(pad(tester, 'ctl_void_1').onSelected, isNull);
    expect(pad(tester, 'ctl_hex_1').onSelected, isNull);
    expect(startButton(tester, 'Start session').onPressed, isNull);

    await tapKey(tester, 'pad-ctl_ghost_1');
    await tapKey(tester, 'pad-ctl_ghost_2');
    expect(
      text(tester, 'pad-selected'),
      'Selected: GHOST-1 (borrow), GHOST-2 (borrow)',
    );
    expect(text(tester, 'estimate-amount'), '₹280');
    await tester.tap(find.text('Start session'));
    await settle(tester);

    final active = await LocalSessionRepository(db).active();
    expect(active.map((a) => a.current.resourceId).toSet(), {'hex', 'void'});
    expect(await held(), {
      'ctl_hex_1', 'ctl_hex_2', 'ctl_void_1', 'ctl_void_2', //
      'ctl_ghost_1', 'ctl_ghost_2',
    });
    await disposeApp(tester);
  });
}
