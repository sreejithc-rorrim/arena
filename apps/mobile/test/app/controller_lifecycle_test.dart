/// The controller lifecycle end to end through the application actions:
/// inventory-honest starts (4 asked at a 2-pad station), explicit borrowing
/// with origin/destination history and return, atomic rollback, billing over
/// the real controller intervals before/after a mid-session change, and
/// pre-tracking count-only sessions.
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
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';
import 'package:drift/drift.dart' show Value;
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
  late FakeClock clock;

  final start = ist(2026, 10, 2, 18, 0); // Friday 18:00 IST — standard band.

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

  Future<PadBoard> board(String station) =>
      single.boards.load(resourceId: station);

  NewSessionDraft at(String station, ControllerChoice c, {String? gameId}) =>
      NewSessionDraft(
        customerId: who.id,
        activityCode: 'PS5',
        resourceId: station,
        resourceName: station.toUpperCase(),
        gameId: gameId,
        controllers: c,
      );

  Future<Set<String>> held() async => {
    for (final a in await alloc.openPadAllocations()) a.controllerId,
  };

  Future<Controller> pad(String id) async =>
      (await catalog.controllers()).firstWhere((c) => c.id == id);

  Future<ActiveSession> activeOn(String station) async =>
      (await sessionsRepo.active()).firstWhere(
        (a) => a.current.resourceId == station,
      );

  group('inventory-honest starts', () {
    test('selecting 1–4 at HEX auto-picks only real free pads', () async {
      final b = await board('hex');
      expect(
        b.inventory.total,
        8,
        reason: 'from the seeded rows, not a constant',
      );
      expect(b.inventory.freeHere, 2);
      expect(b.inventory.freeElsewhere, 6);
      for (final n in [1, 2]) {
        final c = ControllerChoice.none.reconcile(b).request(n, b);
        expect(c.count, n);
        expect((await single.previewStart(at('hex', c))).isOk, isTrue);
      }
      for (final n in [3, 4]) {
        final c = ControllerChoice.none.reconcile(b).request(n, b);
        expect(c.padIds, hasLength(2), reason: 'never auto-borrows');
        final p = await single.previewStart(at('hex', c));
        expect(p.failureOrNull?.code, 'controllers_unavailable');
        expect(
          p.failureOrNull?.message,
          '$n requested, 2 selected — only 2 free at HEX.',
        );
      }
    });

    test('four at VOID count-only is refused, not faked', () async {
      final r = await single.start(at('void', const ControllerChoice.count(4)));
      expect(
        r.failureOrNull?.message,
        '4 controllers needed, only 2 free at VOID.',
      );
      // The repository refuses it too, for any caller that skips the actions.
      final direct = await sessionsRepo.start(
        StartSessionCommand(
          customerId: who.id,
          startedAt: start,
          scheduledEndAt: start.add(const Duration(hours: 1)),
          snapshot: await catalog.currentSnapshot(),
          resourceId: 'void',
          resourceName: 'VOID',
          activityCode: 'PS5',
          controllerCount: 4,
        ),
      );
      expect(direct.failureOrNull?.code, 'controllers_unavailable');
      expect(await sessionsRepo.active(), isEmpty);
    });
  });

  group('borrowing', () {
    test('four at VOID by explicitly borrowing two from HEX: moved at start, '
        'origin recorded, returned with history', () async {
      final b = await board('void');
      var c = ControllerChoice.none.reconcile(b).request(4, b);
      expect(c.shortfall, 2);
      c = c.toggle('ctl_hex_1', b).toggle('ctl_hex_2', b);
      expect(c.count, 4);
      expect(c.borrowIds, {'ctl_hex_1', 'ctl_hex_2'});
      // Picking alone moves nothing.
      expect((await pad('ctl_hex_1')).currentResourceId, 'hex');

      final started = await single.start(at('void', c));
      expect(started.isOk, isTrue, reason: started.failureOrNull?.display);
      final s = started.valueOrNull!;
      expect((await activeOn('void')).current.controllerCount, 4);
      expect(await held(), {
        'ctl_void_1',
        'ctl_void_2',
        'ctl_hex_1',
        'ctl_hex_2',
      });

      final hex1 = await pad('ctl_hex_1');
      expect(hex1.currentResourceId, 'void');
      expect(hex1.homeResourceId, 'hex');
      expect(hex1.loanReturnTo, 'hex');
      expect(hex1.loanSessionRef, Controller.sessionRef(s.id));
      var moves = await alloc.movesForController('ctl_hex_1');
      expect(moves, hasLength(1));
      expect(moves.single.fromResourceId, 'hex');
      expect(moves.single.toResourceId, 'void');
      expect(moves.single.kind, 'loan');
      expect(moves.single.sessionRef, Controller.sessionRef(s.id));

      // While VOID holds it, HEX cannot use it.
      final hexBoard = await board('hex');
      expect(hexBoard.option('ctl_hex_1')!.availability, PadAvailability.inUse);

      clock.advance(const Duration(hours: 1));
      final a = await activeOn('void');
      expect((await single.end(a.session, a.segments)).isOk, isTrue);
      expect(await held(), isEmpty, reason: 'no leaked allocations');
      // Ending does not teleport pads: they are still physically at VOID.
      expect((await pad('ctl_hex_1')).currentResourceId, 'void');

      await alloc.moveController(
        controllerId: 'ctl_hex_1',
        toResourceId: 'hex',
        kind: ControllerMoveKind.returnHome,
      );
      final back = await pad('ctl_hex_1');
      expect(back.currentResourceId, 'hex');
      expect(back.loanReturnTo, isNull);
      expect(back.loanSessionRef, isNull);
      moves = await alloc.movesForController('ctl_hex_1');
      expect(
        moves.map((m) => '${m.fromResourceId}->${m.toResourceId}:${m.kind}'),
        ['hex->void:loan', 'void->hex:returnHome'],
      );
    });

    test(
      'a failed start rolls the borrow back: nothing moved, no history',
      () async {
        // HEX-1 is in use at HEX (tracked), so it cannot be borrowed.
        final hb = await board('hex');
        await single.start(
          at('hex', ControllerChoice.none.reconcile(hb).request(1, hb)),
        );
        final r = await sessionsRepo.start(
          StartSessionCommand(
            customerId: who.id,
            startedAt: start,
            scheduledEndAt: start.add(const Duration(hours: 1)),
            snapshot: await catalog.currentSnapshot(),
            resourceId: 'void',
            resourceName: 'VOID',
            activityCode: 'PS5',
            controllerCount: 2,
            controllerIds: ['ctl_ghost_1', 'ctl_hex_1'],
            borrowControllerIds: ['ctl_ghost_1', 'ctl_hex_1'],
          ),
        );
        expect(r.failureOrNull?.code, 'controller_taken');
        expect(
          (await pad('ctl_ghost_1')).currentResourceId,
          'ghost',
          reason: 'the first borrow was rolled back with the rest',
        );
        expect(await alloc.movesForController('ctl_ghost_1'), isEmpty);
        expect((await sessionsRepo.active()).map((a) => a.current.resourceId), [
          'hex',
        ]);
      },
    );

    test(
      'pads at a station running a count-only session cannot be borrowed',
      () async {
        await single.start(at('hex', const ControllerChoice.count(2)));
        final b = await board('void');
        expect(
          b.option('ctl_hex_1')!.availability,
          PadAvailability.stationBusy,
        );
        const sneaky = ControllerChoice.tracked(
          requested: 1,
          padIds: ['ctl_hex_1'],
          borrowIds: {'ctl_hex_1'},
        );
        final r = await single.start(at('void', sneaky));
        expect(r.failureOrNull?.message, 'HEX-1 is at HEX, which is in use.');
        final direct = await sessionsRepo.start(
          StartSessionCommand(
            customerId: who.id,
            startedAt: start,
            scheduledEndAt: start.add(const Duration(hours: 1)),
            snapshot: await catalog.currentSnapshot(),
            resourceId: 'void',
            resourceName: 'VOID',
            activityCode: 'PS5',
            controllerCount: 1,
            controllerIds: ['ctl_hex_1'],
            borrowControllerIds: ['ctl_hex_1'],
          ),
        );
        expect(direct.failureOrNull?.code, 'controller_taken');
      },
    );

    test('RIFT pads can be borrowed while RIFT is locked to VR', () async {
      await alloc.setResourceMode('rift', 'VR');
      final b = await board('hex');
      expect(b.option('ctl_rift_1')!.selectable, isTrue);
      final c = ControllerChoice.none
          .reconcile(b)
          .request(2, b)
          .toggle('ctl_rift_1', b);
      expect((await single.start(at('hex', c))).isOk, isTrue);
      expect((await pad('ctl_rift_1')).currentResourceId, 'hex');
    });
  });

  group('billing follows the real controller intervals', () {
    test(
      'adding a controller halfway bills the first half at 1, the rest at 2',
      () async {
        final b = await board('hex');
        await single.start(
          at('hex', ControllerChoice.none.reconcile(b).request(1, b)),
        );
        final before = await activeOn('hex');
        expect(
          single
              .liveBill(before, start.add(const Duration(minutes: 30)))
              .total
              .value,
          7500,
          reason: '30 min at ₹150/h',
        );

        clock.advance(const Duration(minutes: 30));
        final r = await single.changeControllers(
          session: before.session,
          current: before.current,
          controllers: const ControllerChoice.tracked(
            requested: 2,
            padIds: ['ctl_hex_1', 'ctl_hex_2'],
          ),
        );
        expect(r.isOk, isTrue, reason: r.failureOrNull?.display);

        clock.advance(const Duration(minutes: 30));
        final a = await activeOn('hex');
        expect(
          a.session.startedAt,
          before.session.startedAt,
          reason: 'timer kept',
        );
        expect(a.session.scheduledEndAt, before.session.scheduledEndAt);
        final bill = single.endSummary(a.session, a.segments);
        expect(
          bill.total.value,
          7500 + 14000,
          reason: '30 min @ ₹150/h + 30 min @ ₹280/h — not a full hour at 2',
        );
        expect([for (final l in bill.lines) l.segment.controllerCount], [1, 2]);

        // Allocation history: HEX-1 continuous across the change, HEX-2 from 18:30.
        final hex1 = await alloc.allocationsForController('ctl_hex_1');
        final hex2 = await alloc.allocationsForController('ctl_hex_2');
        expect(hex1.map((x) => x.startedAt), [
          start,
          start.add(const Duration(minutes: 30)),
        ]);
        expect(hex1.first.endedAt, start.add(const Duration(minutes: 30)));
        expect(hex2.single.startedAt, start.add(const Duration(minutes: 30)));

        final ended = await single.end(a.session, a.segments);
        expect(ended.valueOrNull!.billedAmountPaise, 21500);
        expect(await held(), isEmpty);
      },
    );

    test('a removed controller stops accruing at the change', () async {
      final b = await board('hex');
      await single.start(
        at('hex', ControllerChoice.none.reconcile(b).request(2, b)),
      );
      clock.advance(const Duration(minutes: 30));
      final mid = await activeOn('hex');
      await single.changeControllers(
        session: mid.session,
        current: mid.current,
        controllers: const ControllerChoice.tracked(
          requested: 1,
          padIds: ['ctl_hex_1'],
        ),
      );
      expect(await held(), {'ctl_hex_1'}, reason: 'HEX-2 released at once');
      clock.advance(const Duration(minutes: 30));
      final a = await activeOn('hex');
      expect(
        single.endSummary(a.session, a.segments).total.value,
        14000 + 7500,
      );
    });

    test('replacing a faulty pad keeps count, price and timer', () async {
      final b = await board('hex');
      await single.start(
        at('hex', ControllerChoice.none.reconcile(b).request(1, b)),
      );
      await catalog.setControllerStatus('ctl_hex_1', ControllerStatus.faulty);
      clock.advance(const Duration(minutes: 20));
      final a = await activeOn('hex');
      final r = await single.changeControllers(
        session: a.session,
        current: a.current,
        controllers: const ControllerChoice.tracked(
          requested: 1,
          padIds: ['ctl_hex_2'],
        ),
      );
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
      expect(await held(), {'ctl_hex_2'});
      clock.advance(const Duration(minutes: 40));
      final now = await activeOn('hex');
      expect(single.endSummary(now.session, now.segments).total.value, 15000);
    });

    test(
      'the live estimate prices the picked pads (₹280 for two, 60 min)',
      () async {
        final b = await board('hex');
        final two = ControllerChoice.none.reconcile(b).request(2, b);
        final p = await single.previewStart(at('hex', two));
        expect(p.valueOrNull!.quote.amount.value, 28000);
        final one = two.toggle('ctl_hex_2', b);
        final p1 = await single.previewStart(at('hex', one));
        expect(p1.valueOrNull!.quote.amount.value, 15000);
      },
    );
  });

  group('old count-only sessions', () {
    /// A session started before pads were tracked (count 4 at a 2-pad station)
    /// — written straight to the tables, as an upgraded device would have it.
    Future<ActiveSession> legacyOnVoid() async {
      final snapshot = await catalog.currentSnapshot();
      await db
          .into(db.sessions)
          .insert(
            SessionRow(
              id: 'legacy',
              bookingId: null,
              customerId: who.id,
              status: 'active',
              paymentStatus: 'unpaid',
              startedAt: start,
              scheduledEndAt: start.add(const Duration(hours: 1)),
              actualEndedAt: null,
              pricingSnapshot: snapshot.toJson(),
              billedAmountPaise: null,
              voidReason: null,
              createdAt: start,
              updatedAt: start,
            ),
          );
      await db
          .into(db.sessionSegments)
          .insert(
            SessionSegmentsCompanion.insert(
              id: 'legacy-seg',
              sessionId: 'legacy',
              index: 0,
              resourceId: 'void',
              activityCode: 'PS5',
              controllerCount: const Value(4),
              startedAt: start,
              createdAt: start,
            ),
          );
      return activeOn('void');
    }

    test(
      'keep working: game change, shrink, bill — no pads involved',
      () async {
        var a = await legacyOnVoid();
        clock.advance(const Duration(minutes: 30));
        var r = await single.changeGame(
          session: a.session,
          current: a.current,
          gameId: 'g_wwe',
        );
        expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
        a = await activeOn('void');
        expect(a.current.controllerCount, 4);
        clock.advance(const Duration(minutes: 30));
        final bill = single.endSummary(a.session, a.segments);
        expect(bill.total.value, 48000, reason: '₹480/h for 4, unchanged');
        expect((await single.end(a.session, a.segments)).isOk, isTrue);
        expect(await held(), isEmpty);
      },
    );

    test('can be moved onto tracked pads mid-session', () async {
      final a = await legacyOnVoid();
      final r = await single.changeControllers(
        session: a.session,
        current: a.current,
        controllers: const ControllerChoice.tracked(
          requested: 2,
          padIds: ['ctl_void_1', 'ctl_void_2'],
        ),
      );
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
      expect(await held(), {'ctl_void_1', 'ctl_void_2'});
    });
  });
}
