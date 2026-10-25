/// Cross-station controller borrowing (the HEX/VOID scenario):
///
///  HEX runs a 4-controller session on HEX-1, HEX-2, VOID-1, VOID-2. A new
///  customer wants VOID. VOID — the STATION — is free; its own pads are not.
///  Staff borrow genuinely free pads from GHOST / RIFT and start at VOID.
///
/// Station availability and pad availability are separate questions; these
/// tests pin both, plus count-only sessions, a venue with no free pads, and
/// ending / returning borrowed pads.
library;

import 'package:arena_ops/app/controllers/booking_actions.dart';
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
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pricing_fixtures.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late LocalSessionRepository sessionsRepo;
  late LocalCatalogRepository catalog;
  late LocalControllerAllocationRepository alloc;
  late SessionActions single;
  late BookingActions bookings;
  late String who;

  final start = ist(2026, 10, 2, 18, 0); // Friday 18:00 — standard band

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
    final bookingsRepo = LocalBookingRepository(db, clock);
    single = SessionActions(
      sessions: sessionsRepo,
      catalog: catalog,
      bookings: bookingsRepo,
      clock: clock,
      guard: staff,
      pads: alloc,
    );
    bookings = BookingActions(
      bookings: bookingsRepo,
      sessions: sessionsRepo,
      catalog: catalog,
      clock: clock,
      guard: staff,
      boards: single.boards,
    );
    who = (await LocalCustomerRepository(db, clock).create(name: 'Arjun')).id;
  });

  tearDown(() async => db.close());

  Future<PadBoard> board(String station) =>
      single.boards.load(resourceId: station);

  NewSessionDraft at(String station, ControllerChoice c) => NewSessionDraft(
    customerId: who,
    activityCode: 'PS5',
    resourceId: station,
    resourceName: station.toUpperCase(),
    controllers: c,
  );

  Future<Controller> pad(String id) async =>
      (await catalog.controllers()).firstWhere((c) => c.id == id);

  Future<Set<String>> held() async => {
    for (final a in await alloc.openPadAllocations()) a.controllerId,
  };

  Future<ActiveSession> activeOn(String station) async =>
      (await sessionsRepo.active()).firstWhere(
        (a) => a.current.resourceId == station,
      );

  /// HEX: a 4-controller session on HEX-1, HEX-2 + VOID-1, VOID-2 (borrowed).
  Future<void> hexOnFour() async {
    final hb = await board('hex');
    final c = ControllerChoice.none
        .reconcile(hb)
        .request(4, hb)
        .toggle('ctl_void_1', hb)
        .toggle('ctl_void_2', hb);
    final r = await single.start(at('hex', c));
    expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
  }

  group('the HEX / VOID scenario', () {
    test(
      'VOID the station stays free; VOID-1/2 show as in use at HEX',
      () async {
        await hexOnFour();
        final vb = await board('void');
        expect(vb.here, isEmpty, reason: 'VOID has none of its pads on it');
        final v1 = vb.option('ctl_void_1')!;
        expect(v1.availability, PadAvailability.inUse);
        expect(v1.stationName, 'HEX', reason: 'where it physically is');
        expect(v1.homeName, 'VOID');
        expect(v1.heldAt, 'HEX');
        expect(v1.note, 'in use at HEX');
        expect(v1.selectable, isFalse);
        // VOID can still take a session: nothing is ON the station.
        expect((await sessionsRepo.openSegments()).map((s) => s.resourceId), [
          'hex',
        ]);
        // Only genuinely free pads are offered: GHOST's and RIFT's.
        expect(vb.freeElsewhere.map((o) => o.id), [
          'ctl_ghost_1',
          'ctl_ghost_2',
          'ctl_rift_1',
          'ctl_rift_2',
        ]);
      },
    );

    test(
      'borrow GHOST-1/2 and start at VOID; nothing is double-allocated',
      () async {
        await hexOnFour();
        final vb = await board('void');
        var c = ControllerChoice.none.reconcile(vb).request(2, vb);
        expect(c.shortfall, 2);
        expect(
          single.padSelection.check(c, vb)!.fix,
          'Borrow 2 from another station (4 free).',
        );
        // VOID's own pads cannot be picked even by force.
        expect(c.toggle('ctl_void_1', vb), c);
        c = c.toggle('ctl_ghost_1', vb).toggle('ctl_ghost_2', vb);

        final r = await single.start(at('void', c));
        expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
        expect(await held(), {
          'ctl_hex_1', 'ctl_hex_2', 'ctl_void_1', 'ctl_void_2', //
          'ctl_ghost_1', 'ctl_ghost_2',
        });
        final g1 = await pad('ctl_ghost_1');
        expect(g1.currentResourceId, 'void');
        expect(g1.homeResourceId, 'ghost');
        expect(g1.loanSessionRef, Controller.sessionRef(r.valueOrNull!.id));
        final moves = await alloc.movesForController('ctl_ghost_1');
        expect(moves.single.fromResourceId, 'ghost');
        expect(moves.single.toResourceId, 'void');
        // Billed on its own 2 controllers at VOID.
        expect((await activeOn('void')).current.controllerCount, 2);
      },
    );

    test('borrowing does not make the source station busy: GHOST can still '
        'start, borrowing from RIFT', () async {
      await hexOnFour();
      var vb = await board('void');
      await single.start(
        at(
          'void',
          ControllerChoice.none
              .reconcile(vb)
              .request(2, vb)
              .toggle('ctl_ghost_1', vb)
              .toggle('ctl_ghost_2', vb),
        ),
      );
      // GHOST has no pads on it now, but the STATION is free.
      final gb = await board('ghost');
      expect(gb.here, isEmpty);
      expect(
        (await sessionsRepo.openSegments()).map((s) => s.resourceId),
        isNot(contains('ghost')),
      );
      final r = await single.start(
        at(
          'ghost',
          ControllerChoice.none
              .reconcile(gb)
              .request(1, gb)
              .toggle('ctl_rift_1', gb),
        ),
      );
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    });

    test(
      'a two-player booking checked in at VOID borrows the same way',
      () async {
        await hexOnFour();
        clock.set(ist(2026, 10, 2, 14, 0));
        final b = (await bookings.createBooking(
          BookingDraft(
            customerId: who,
            activityCode: 'PS5',
            date: fridayDate,
            startMinuteOfDay: 19 * 60,
            durationMinutes: 60,
            resourceId: 'void',
            controllerRequirement: 2,
          ),
        )).valueOrNull!;
        clock.set(ist(2026, 10, 2, 19, 0));
        final plan = (await bookings.planCheckIn(b)).valueOrNull!;
        expect(
          plan.resource.id,
          'void',
          reason: 'not pushed to another station because VOID\'s pads are out',
        );
        final vb = await board('void');
        final c = ControllerChoice.tracked(requested: 2)
            .reconcile(vb)
            .toggle('ctl_rift_1', vb)
            .toggle('ctl_rift_2', vb);
        final s = await bookings.checkIn(b, controllers: c);
        expect(s.isOk, isTrue, reason: s.failureOrNull?.display);
        expect((await pad('ctl_rift_2')).currentResourceId, 'void');
      },
    );
  });

  group('when the venue is short', () {
    test('every controller occupied: Start is refused with a clear reason', () async {
      await hexOnFour();
      // GHOST and RIFT busy with tracked sessions on their own pads.
      for (final s in ['ghost', 'rift']) {
        final b = await board(s);
        expect(
          (await single.start(
            at(s, ControllerChoice.none.reconcile(b).request(2, b)),
          )).isOk,
          isTrue,
        );
      }
      final vb = await board('void');
      expect(vb.inventory.globallyFree, 0);
      final c = ControllerChoice.none.reconcile(vb).request(1, vb);
      final p = await single.previewStart(at('void', c));
      expect(p.failureOrNull?.code, 'controllers_unavailable');
      expect(
        p.failureOrNull?.message,
        '1 requested, 0 selected — only 0 free at VOID.',
      );
      expect(
        p.failureOrNull?.fix,
        'No controller is free anywhere right now — wait for one to come free.',
      );
    });

    test('three free in the venue for a request of four: says so', () async {
      await hexOnFour();
      await catalog.setControllerStatus('ctl_rift_2', ControllerStatus.faulty);
      final vb = await board('void');
      final c = ControllerChoice.none.reconcile(vb).request(4, vb);
      expect(
        single.padSelection.check(c, vb)!.fix,
        'Only 3 free in the whole arena right now — choose 3 or wait for '
        'one to come free.',
      );
    });

    test('stations with enough pads of their own can be suggested', () {
      final free = PadSelection.freeByStation(
        controllers: [
          for (final s in const ['hex', 'void', 'ghost'])
            for (final n in const [1, 2])
              Controller(
                id: '${s}_$n',
                label: '$s-$n',
                homeResourceId: s,
                currentResourceId: s,
                updatedAt: start,
              ),
        ],
        open: const [
          OpenPadAllocation(controllerId: 'hex_1', resourceId: 'hex'),
        ],
        busyStations: const {'void'},
      );
      expect(free, {'hex': 1, 'ghost': 2});
    });
  });

  group('older count-only sessions', () {
    test('pads at a count-only station are never offered, and the '
        'repository refuses them too', () async {
      // GHOST runs a session started before pads were tracked.
      final r = await sessionsRepo.start(
        StartSessionCommand(
          customerId: who,
          startedAt: start,
          scheduledEndAt: start.add(const Duration(hours: 1)),
          snapshot: await catalog.currentSnapshot(),
          resourceId: 'ghost',
          resourceName: 'GHOST',
          activityCode: 'PS5',
          controllerCount: 2,
        ),
      );
      expect(r.isOk, isTrue);
      await hexOnFour();
      final vb = await board('void');
      final g1 = vb.option('ctl_ghost_1')!;
      expect(g1.availability, PadAvailability.stationBusy);
      expect(g1.note, 'GHOST in use, not tracked');
      expect(vb.freeElsewhere.map((o) => o.id), ['ctl_rift_1', 'ctl_rift_2']);

      final direct = await sessionsRepo.start(
        StartSessionCommand(
          customerId: who,
          startedAt: start,
          scheduledEndAt: start.add(const Duration(hours: 1)),
          snapshot: await catalog.currentSnapshot(),
          resourceId: 'void',
          resourceName: 'VOID',
          activityCode: 'PS5',
          controllerCount: 1,
          controllerIds: const ['ctl_ghost_1'],
          borrowControllerIds: const ['ctl_ghost_1'],
        ),
      );
      expect(direct.failureOrNull?.code, 'controller_taken');
      expect((await pad('ctl_ghost_1')).currentResourceId, 'ghost');
    });
  });

  group('ending and returning', () {
    test('ending VOID frees the borrowed pads; the return is recorded; HEX '
        'is untouched', () async {
      await hexOnFour();
      final vb = await board('void');
      await single.start(
        at(
          'void',
          ControllerChoice.none
              .reconcile(vb)
              .request(2, vb)
              .toggle('ctl_ghost_1', vb)
              .toggle('ctl_ghost_2', vb),
        ),
      );
      clock.advance(const Duration(minutes: 45));
      final v = await activeOn('void');
      final bill = single.endSummary(v.session, v.segments);
      expect(bill.total.value, 21000, reason: '45 min at ₹280/h');
      expect((await single.end(v.session, v.segments)).isOk, isTrue);
      expect(await held(), {
        'ctl_hex_1',
        'ctl_hex_2',
        'ctl_void_1',
        'ctl_void_2',
      });

      // While HEX still holds VOID-1, it cannot be walked anywhere.
      final blocked = await alloc.moveController(
        controllerId: 'ctl_void_1',
        toResourceId: 'void',
        kind: ControllerMoveKind.returnHome,
      );
      expect(blocked.failureOrNull?.code, 'controller_in_use');

      for (final id in ['ctl_ghost_1', 'ctl_ghost_2']) {
        await alloc.moveController(
          controllerId: id,
          toResourceId: 'ghost',
          kind: ControllerMoveKind.returnHome,
        );
        final m = await alloc.movesForController(id);
        expect(
          m.map((x) => '${x.fromResourceId}->${x.toResourceId}:${x.kind}'),
          ['ghost->void:loan', 'void->ghost:returnHome'],
        );
      }
      final gb = await board('ghost');
      expect(gb.inventory.freeHere, 2);

      // HEX ends; then VOID's pads can go home too.
      final h = await activeOn('hex');
      await single.end(h.session, h.segments);
      expect(await held(), isEmpty);
      expect(
        (await alloc.moveController(
          controllerId: 'ctl_void_1',
          toResourceId: 'void',
          kind: ControllerMoveKind.returnHome,
        )).isOk,
        isTrue,
      );
      expect((await pad('ctl_void_1')).currentResourceId, 'void');
    });

    test('voiding a session that borrowed releases the pads', () async {
      await hexOnFour();
      final vb = await board('void');
      final s = await single.start(
        at(
          'void',
          ControllerChoice.none
              .reconcile(vb)
              .request(1, vb)
              .toggle('ctl_rift_1', vb),
        ),
      );
      expect(
        (await sessionsRepo.voidSession(s.valueOrNull!.id, 'test')).isOk,
        isTrue,
      );
      expect(await held(), isNot(contains('ctl_rift_1')));
      expect(
        (await board('hex')).option('ctl_rift_1')!.selectable,
        isTrue,
        reason: 'free again (still at VOID until returned)',
      );
    });
  });
}
