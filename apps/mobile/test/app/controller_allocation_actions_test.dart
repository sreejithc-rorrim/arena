/// Phase B — staff specific-pad allocation, driven through the application
/// actions the way the UI drives them: normal allocation, duplicate selection,
/// insufficient / busy / unusable / elsewhere pads, game player limits, the
/// RIFT mode lock, switching stations, game changes carrying pads, and the
/// end / void cleanup. Timers, history and billing must be untouched.
library;

import 'package:arena_ops/app/controllers/session_actions.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_booking_repository.dart';
import 'package:arena_ops/data/local/local_catalog_repository.dart';
import 'package:arena_ops/data/local/local_controller_allocation_repository.dart';
import 'package:arena_ops/data/local/local_customer_repository.dart';
import 'package:arena_ops/data/local/local_session_repository.dart';
import 'package:arena_ops/data/local/seed_data.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/auth/permission_guard.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/entities/customer.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pricing_fixtures.dart';

void main() {
  late AppDatabase db;
  late LocalSessionRepository sessionsRepo;
  late LocalCatalogRepository catalog;
  late LocalControllerAllocationRepository alloc;
  late SessionActions single;
  late Customer who;

  final start = ist(2026, 10, 2, 18, 0); // Friday 18:00 IST.
  late FakeClock clock;

  const staff = PermissionGuard(
    AppUser(
      id: 'u2',
      name: 'Staff',
      perms: {Permission.start, Permission.bill, Permission.discount},
    ),
  );

  setUp(() async {
    clock = FakeClock(start);
    db = AppDatabase(NativeDatabase.memory());
    await LocalSeed.apply(db);
    sessionsRepo = LocalSessionRepository(db, clock);
    catalog = LocalCatalogRepository(db);
    alloc = LocalControllerAllocationRepository(db, clock);
    final bookings = LocalBookingRepository(db, clock);
    single = SessionActions(
      sessions: sessionsRepo,
      catalog: catalog,
      bookings: bookings,
      clock: clock,
      guard: staff,
      pads: alloc,
    );
    who = await LocalCustomerRepository(
      db,
      clock,
    ).create(name: 'Arjun', phone: '9000000009');
  });

  tearDown(() async => db.close());

  NewSessionDraft draft({
    String resourceId = 'hex',
    String resourceName = 'HEX',
    String activity = 'PS5',
    String? gameId,
    int? count,
    List<String> pads = const [],
  }) => NewSessionDraft(
    customerId: who.id,
    activityCode: activity,
    resourceId: resourceId,
    resourceName: resourceName,
    gameId: gameId,
    controllerCount: count ?? (pads.isEmpty ? 1 : pads.length),
    controllerIds: pads,
  );

  Future<Set<String>> held() async => {
    for (final a in await alloc.openPadAllocations()) a.controllerId,
  };

  Future<ActiveSession> activeOn(String resourceId) async =>
      (await sessionsRepo.active()).firstWhere(
        (a) => a.current.resourceId == resourceId,
      );

  group('single session', () {
    test('normal allocation: picked pads are held by the session', () async {
      final r = await single.start(draft(pads: ['ctl_hex_1', 'ctl_hex_2']));
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
      expect(await held(), {'ctl_hex_1', 'ctl_hex_2'});
      final a = await activeOn('hex');
      expect(a.current.controllerCount, 2, reason: 'billing count = pads');
    });

    test('count-only start still works and allocates nothing', () async {
      final r = await single.start(draft(count: 2));
      expect(r.isOk, isTrue);
      expect(await held(), isEmpty);
    });

    test('duplicate selection is refused before anything is written', () async {
      final r = await single.start(draft(pads: ['ctl_hex_1', 'ctl_hex_1']));
      expect(r.failureOrNull?.code, 'controller_duplicate');
      expect(r.failureOrNull?.message, 'HEX-1 is picked twice.');
      expect(await sessionsRepo.active(), isEmpty);
      expect(await held(), isEmpty);
    });

    test('insufficient pads for the count reads as a clear mismatch', () async {
      final r = await single.start(NewSessionDraft(
        customerId: who.id,
        activityCode: 'PS5',
        resourceId: 'hex',
        resourceName: 'HEX',
        controllers: const ControllerChoice.tracked(
            requested: 2, padIds: ['ctl_hex_1']),
      ));
      expect(r.failureOrNull?.code, 'controller_count_mismatch');
      expect(r.failureOrNull?.display, contains('Pick 1 more at HEX'));
      expect(await sessionsRepo.active(), isEmpty);
    });

    test('a faulty or unavailable pad is never allocated', () async {
      await catalog.setControllerStatus('ctl_hex_2', ControllerStatus.faulty);
      var r = await single.start(draft(pads: ['ctl_hex_2']));
      expect(r.failureOrNull?.code, 'controller_unusable');
      expect(r.failureOrNull?.message, 'HEX-2 is faulty.');

      await catalog.setControllerStatus(
        'ctl_hex_2',
        ControllerStatus.unavailable,
      );
      r = await single.start(draft(pads: ['ctl_hex_2']));
      expect(r.failureOrNull?.message, 'HEX-2 is unavailable.');
      expect(await held(), isEmpty);
    });

    test('a pad at another station is refused, naming where it is', () async {
      final r = await single.start(draft(pads: ['ctl_void_1']));
      expect(r.failureOrNull?.code, 'controller_elsewhere');
      expect(r.failureOrNull?.message, 'VOID-1 is at VOID, not HEX.');
    });

    test('a pad another session holds is refused as in use', () async {
      // VOID-1 is borrowed into HEX and used there…
      await alloc.moveController(
        controllerId: 'ctl_void_1',
        toResourceId: 'hex',
        kind: ControllerMoveKind.loan,
      );
      expect((await single.start(draft(pads: ['ctl_void_1']))).isOk, isTrue);
      // …so it cannot be walked back to VOID mid-session…
      final move = await alloc.moveController(
        controllerId: 'ctl_void_1',
        toResourceId: 'void',
        kind: ControllerMoveKind.returnHome,
      );
      expect(move.failureOrNull?.code, 'controller_in_use');
      // …and another session cannot take it, even as a borrow.
      final r = await single.start(NewSessionDraft(
        customerId: who.id,
        activityCode: 'PS5',
        resourceId: 'void',
        resourceName: 'VOID',
        controllers: const ControllerChoice.tracked(
            requested: 1, padIds: ['ctl_void_1'], borrowIds: {'ctl_void_1'}),
      ));
      expect(r.failureOrNull?.code, 'controller_taken');
      expect(r.failureOrNull?.message, 'VOID-1 is already in use.');
    });

    test('more pads than the game supports is refused', () async {
      await alloc.moveController(
        controllerId: 'ctl_void_1',
        toResourceId: 'hex',
        kind: ControllerMoveKind.loan,
      );
      final r = await single.start(
        draft(
          gameId: 'g_tekken8', // 2 local players
          pads: ['ctl_hex_1', 'ctl_hex_2', 'ctl_void_1'],
        ),
      );
      expect(r.failureOrNull?.code, 'players_exceeded');
      expect(r.failureOrNull?.message, contains('Tekken 8 supports 2'));
    });

    test('RIFT locked to VR refuses a PS5 start with a clear reason', () async {
      await alloc.setResourceMode('rift', 'VR');
      final r = await single.start(
        draft(resourceId: 'rift', resourceName: 'RIFT', pads: ['ctl_rift_1']),
      );
      expect(r.failureOrNull?.code, 'mode_locked');
      expect(r.failureOrNull?.message, 'RIFT is set to VR mode.');
    });

    test(
      'switching stations moves the allocation; timer and history kept',
      () async {
        await single.start(draft(pads: ['ctl_hex_1', 'ctl_hex_2']));
        final before = await activeOn('hex');
        clock.advance(const Duration(minutes: 20));

        final r = await single.switchSystem(
          session: before.session,
          current: before.current,
          resourceId: 'void',
          resourceName: 'VOID',
          activityCode: 'PS5',
          controllerCount: 2,
          controllerIds: ['ctl_void_1', 'ctl_void_2'],
        );
        expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
        expect(await held(), {
          'ctl_void_1',
          'ctl_void_2',
        }, reason: 'HEX pads released at the switch instant');

        final after = await activeOn('void');
        expect(after.session.startedAt, before.session.startedAt);
        expect(after.session.scheduledEndAt, before.session.scheduledEndAt);
        expect(after.segments, hasLength(2));

        // Per-pad timeline: HEX-1 closed exactly at the switch.
        final hex1 = await alloc.allocationsForController('ctl_hex_1');
        expect(hex1.single.endedAt, start.add(const Duration(minutes: 20)));
      },
    );

    test(
      'switching with a busy pad at the target fails and changes nothing',
      () async {
        await single.start(
          draft(resourceId: 'void', resourceName: 'VOID', pads: ['ctl_void_1']),
        );
        // A second walk-in on HEX, then try to grab VOID-2 — VOID is busy as a
        // station, so use GHOST with a VOID pad to hit the pad rule instead.
        await single.start(draft(pads: ['ctl_hex_1']));
        final a = await activeOn('hex');
        final r = await single.switchSystem(
          session: a.session,
          current: a.current,
          resourceId: 'ghost',
          resourceName: 'GHOST',
          activityCode: 'PS5',
          controllerCount: 1,
          controllerIds: ['ctl_void_1'],
        );
        // VOID-1 is held by the VOID session — "in use" beats "elsewhere".
        expect(r.failureOrNull?.code, 'controller_taken');
        expect((await activeOn('hex')).segments, hasLength(1));
        expect(await held(), {'ctl_void_1', 'ctl_hex_1'});
      },
    );

    test('a game change keeps the same pads in the players’ hands', () async {
      await single.start(
        draft(gameId: 'g_eafc', pads: ['ctl_hex_1', 'ctl_hex_2']),
      );
      final a = await activeOn('hex');
      final r = await single.changeGame(
        session: a.session,
        current: a.current,
        gameId: 'g_wwe',
      );
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
      final now = await activeOn('hex');
      expect(now.segments, hasLength(2));
      expect(await single.padsHeldBy(now.current), ['ctl_hex_1', 'ctl_hex_2']);
    });

    test('a game change to one the pads exceed is refused', () async {
      await single.start(
        draft(gameId: 'g_eafc', pads: ['ctl_hex_1', 'ctl_hex_2']),
      );
      final a = await activeOn('hex');
      final r = await single.changeGame(
        session: a.session,
        current: a.current,
        gameId: 'g_gow',
      ); // 1 player
      expect(r.failureOrNull?.code, 'players_exceeded');
      expect(await held(), {'ctl_hex_1', 'ctl_hex_2'});
    });

    test('swapping a pad mid-session keeps the count and the timer', () async {
      await single.start(draft(pads: ['ctl_hex_1']));
      final a = await activeOn('hex');
      final r = await single.changeControllers(
        session: a.session,
        current: a.current,
        controllerCount: 1,
        controllerIds: ['ctl_hex_2'],
      );
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
      expect(await held(), {'ctl_hex_2'});
      expect(
        (await activeOn('hex')).session.scheduledEndAt,
        a.session.scheduledEndAt,
      );
    });

    test('ending the session releases every pad; billing unchanged', () async {
      await single.start(draft(pads: ['ctl_hex_1', 'ctl_hex_2']));
      final a = await activeOn('hex');
      clock.advance(const Duration(minutes: 60));
      final bill = single.endSummary(a.session, a.segments);
      final r = await single.end(a.session, a.segments);
      expect(r.isOk, isTrue);
      expect(r.valueOrNull!.billedAmountPaise, bill.total.value);
      expect(bill.total.value, 28000, reason: '2 controllers, 1h standard');
      expect(await held(), isEmpty);
    });

    test('voiding the session releases every pad', () async {
      await single.start(draft(pads: ['ctl_hex_1']));
      final a = await activeOn('hex');
      final r = await sessionsRepo.voidSession(a.session.id, 'wrong customer');
      expect(r.isOk, isTrue);
      expect(await held(), isEmpty);
    });
  });
}
