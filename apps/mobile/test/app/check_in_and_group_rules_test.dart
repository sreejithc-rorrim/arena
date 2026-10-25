/// Booking check-in with physical controllers, through the application
/// actions.
library;

import 'package:arena_ops/app/controllers/booking_actions.dart';
import 'package:arena_ops/app/controllers/pad_board_loader.dart';
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
import 'package:arena_ops/domain/entities/booking.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/services/pad_selection.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pricing_fixtures.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late LocalSessionRepository sessionsRepo;
  late LocalBookingRepository bookingsRepo;
  late LocalCatalogRepository catalog;
  late LocalControllerAllocationRepository alloc;
  late BookingActions bookings;
  late PadBoardLoader boards;
  late String customerId;

  const staff = PermissionGuard(AppUser(
    id: 'u2',
    name: 'Staff',
    perms: {Permission.start, Permission.bill, Permission.discount},
  ));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await LocalSeed.apply(db);
    clock = FakeClock(ist(2026, 10, 2, 14, 0));
    sessionsRepo = LocalSessionRepository(db, clock);
    bookingsRepo = LocalBookingRepository(db, clock);
    catalog = LocalCatalogRepository(db);
    alloc = LocalControllerAllocationRepository(db, clock);
    boards = PadBoardLoader(
        catalog: catalog, sessions: sessionsRepo, pads: alloc);
    bookings = BookingActions(
      bookings: bookingsRepo,
      sessions: sessionsRepo,
      catalog: catalog,
      clock: clock,
      guard: staff,
      boards: boards,
    );
    customerId =
        (await LocalCustomerRepository(db, clock).create(name: 'Rahul')).id;
  });

  tearDown(() async => db.close());

  Future<Set<String>> held() async =>
      {for (final a in await alloc.openPadAllocations()) a.controllerId};

  Future<Booking> book({
    String? resourceId,
    String activity = 'PS5',
    String? gameId = 'g_eafc',
    int? controllers = 2,
  }) async {
    final r = await bookings.createBooking(BookingDraft(
      customerId: customerId,
      activityCode: activity,
      date: fridayDate,
      startMinuteOfDay: 19 * 60,
      durationMinutes: 60,
      gameId: gameId,
      resourceId: resourceId,
      controllerRequirement: controllers,
    ));
    expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    clock.set(ist(2026, 10, 2, 19, 2)); // the party arrives
    return r.valueOrNull!;
  }

  group('booking check-in', () {
    test('plans the booked system and pre-picks the booked pads', () async {
      final b = await book(resourceId: 'void');
      final plan = (await bookings.planCheckIn(b)).valueOrNull!;
      expect(plan.resource.id, 'void');
      expect(plan.requestedControllers, 2);
      final board = await boards.load(resourceId: 'void');
      final choice = ControllerChoice.tracked(requested: 2).reconcile(board);
      expect(choice.padIds, ['ctl_void_1', 'ctl_void_2']);

      final s = await bookings.checkIn(b,
          controllers: choice, resourceId: plan.resource.id);
      expect(s.isOk, isTrue, reason: s.failureOrNull?.display);
      expect(await held(), {'ctl_void_1', 'ctl_void_2'});
      expect((await bookingsRepo.getById(b.id))!.status, BookingStatus.checkedIn);
    });

    test('four booked at a two-pad station: refused until two are borrowed',
        () async {
      final b = await book(resourceId: 'void', controllers: 4);
      var board = await boards.load(resourceId: 'void');
      var choice = ControllerChoice.tracked(requested: 4).reconcile(board);
      expect(choice.shortfall, 2);
      final refused = await bookings.checkIn(b, controllers: choice);
      expect(refused.failureOrNull?.code, 'controllers_unavailable');
      expect((await bookingsRepo.getById(b.id))!.status, BookingStatus.booked,
          reason: 'nothing written on a refused check-in');
      expect(await sessionsRepo.active(), isEmpty);

      choice = choice.toggle('ctl_hex_1', board).toggle('ctl_hex_2', board);
      final s = await bookings.checkIn(b, controllers: choice);
      expect(s.isOk, isTrue, reason: s.failureOrNull?.display);
      expect((await sessionsRepo.active()).single.current.controllerCount, 4);
      final hex1 = await alloc.movesForController('ctl_hex_1');
      expect(hex1.single.toResourceId, 'void');
      expect(hex1.single.sessionRef, Controller.sessionRef(s.valueOrNull!.id));
      board = await boards.load(resourceId: 'hex');
      expect(board.inventory.freeHere, 0, reason: 'both HEX pads now at VOID');
    });

    test('a bare count is still checked against the free pads', () async {
      final b = await book(resourceId: 'void', controllers: 4);
      final r = await bookings.checkIn(b); // no pads picked (legacy caller)
      expect(r.failureOrNull?.message,
          '4 controllers needed, only 2 free at VOID.');
    });

    test('the game local-player limit applies at check-in', () async {
      final b = await book(resourceId: 'hex', gameId: 'g_tekken8');
      final board = await boards.load(resourceId: 'hex');
      final three = ControllerChoice.tracked(requested: 2)
          .reconcile(board)
          .toggle('ctl_void_1', board);
      final r = await bookings.checkIn(b, controllers: three);
      expect(r.failureOrNull?.code, 'players_exceeded');
    });

    test('a controller count the price list cannot bill is refused (#30)',
        () async {
      // No PS5 rate for two controllers: the session would bill ₹0 and the
      // server would refuse it (no_rate), so check-in must not start it.
      await (db.delete(db.rates)..where((t) => t.id.equals('ps5_2_standard')))
          .go();
      final b = await book(resourceId: 'void');
      final board = await boards.load(resourceId: 'void');
      final choice = ControllerChoice.tracked(requested: 2).reconcile(board);
      final r = await bookings.checkIn(b, controllers: choice);
      expect(r.failureOrNull?.code, 'no_rate');
      expect(r.failureOrNull?.message, 'No price for PS5 with 2 controllers.');
      expect((await bookingsRepo.getById(b.id))!.status, BookingStatus.booked,
          reason: 'nothing written on a refused check-in');
      expect(await sessionsRepo.active(), isEmpty);
      expect(await held(), isEmpty);
    });

    test('an activity without controllers checks in without pads', () async {
      final b = await book(
          resourceId: 'rift', activity: 'VR', gameId: null, controllers: null);
      final s = await bookings.checkIn(b);
      expect(s.isOk, isTrue, reason: s.failureOrNull?.display);
      expect(await held(), isEmpty);
    });
  });
}
