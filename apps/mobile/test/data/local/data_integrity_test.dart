/// Data-integrity rules that must hold however the UI is driven.
///
/// Each group here covers a rule that was only being applied in the pickers, or
/// not at all, and so could be bypassed by a stale sheet, a booking check-in or
/// a call site that got an argument wrong.
library;

import 'package:arena_ops/app/controllers/session_actions.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/time/utc_interval.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_booking_repository.dart';
import 'package:arena_ops/data/local/local_catalog_repository.dart';
import 'package:arena_ops/data/local/local_customer_repository.dart';
import 'package:arena_ops/data/local/local_session_repository.dart';
import 'package:arena_ops/data/local/seed_data.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/auth/permission_guard.dart';
import 'package:arena_ops/domain/entities/booking.dart';
import 'package:arena_ops/domain/entities/customer.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../../support/pricing_fixtures.dart';

void main() {
  late AppDatabase db;
  late LocalSessionRepository sessions;
  late LocalCatalogRepository catalog;
  late LocalBookingRepository bookings;
  late SessionActions actions;
  late Customer walkIn;

  // 6:00 PM on a trading day, well inside opening hours.
  final start = ist(2026, 10, 2, 18, 0);
  late FakeClock clock;

  const staff = AppUser(
    id: 'u2',
    name: 'Priya Nair',
    perms: {Permission.start, Permission.bill, Permission.discount},
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await LocalSeed.apply(db);
    clock = FakeClock(start);
    sessions = LocalSessionRepository(db, clock);
    catalog = LocalCatalogRepository(db);
    bookings = LocalBookingRepository(db, clock);
    walkIn = await LocalCustomerRepository(db, clock).create(name: 'Walk-in');
    actions = SessionActions(
      sessions: sessions,
      catalog: catalog,
      bookings: bookings,
      clock: clock,
      guard: const PermissionGuard(staff),
    );
  });

  tearDown(() async => db.close());

  NewSessionDraft draft({String resourceId = 'hex', int minutes = 60}) =>
      NewSessionDraft(
        customerId: walkIn.id,
        resourceId: resourceId,
        resourceName: resourceId.toUpperCase(),
        activityCode: 'PS5',
        gameId: 'g_wwe',
        controllerCount: 1,
        durationMinutes: minutes,
      );

  Future<Session> startSession({String resourceId = 'hex'}) async {
    final r = await actions.start(draft(resourceId: resourceId));
    expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    return r.valueOrNull!;
  }

  Future<Booking> bookStation({
    required String resourceId,
    required DateTime from,
    required Duration length,
    BookingStatus status = BookingStatus.booked,
    String party = 'Nikhil',
  }) async {
    final now = clock.now();
    return bookings.create(Booking(
      id: const Uuid().v4(),
      activityCode: 'PS5',
      resourceId: resourceId,
      scheduledStart: from,
      scheduledEnd: from.add(length),
      status: status,
      partyName: party,
      createdAt: now,
      updatedAt: now,
    ));
  }

  group('a station that is not available cannot take a session', () {
    for (final status in const [
      ResourceStatus.maintenance,
      ResourceStatus.temporarilyUnavailable,
      ResourceStatus.disabled,
    ]) {
      test('${status.code}: starting on it is refused', () async {
        await catalog.setResourceStatus('hex', status);

        final r = await actions.start(draft());
        expect(r.isErr, isTrue,
            reason: 'a ${status.code} station must not take a session');
        expect(r.failureOrNull!.code, 'resource_unavailable');
        expect(r.failureOrNull!.message, contains(status.label.toLowerCase()));
        expect(await sessions.openSegments(), isEmpty);
      });
    }

    test('moving a running session onto one is refused', () async {
      final session = await startSession();
      await catalog.setResourceStatus('void', ResourceStatus.maintenance);

      final segment = (await sessions.segmentsFor(session.id)).single;
      final r = await actions.switchSystem(
        session: session,
        current: segment,
        resourceId: 'void',
        resourceName: 'VOID',
        activityCode: 'PS5',
        gameId: 'g_wwe',
        controllerCount: 1,
      );
      expect(r.isErr, isTrue);
      expect(r.failureOrNull!.code, 'resource_unavailable');
      // Still on the original station, still one open segment.
      expect((await sessions.openSegments()).single.resourceId, 'hex');
      expect((await sessions.segmentsFor(session.id)), hasLength(1));
    });

    test(
        'a session already running is not stranded when its station goes into '
        'maintenance', () async {
      final session = await startSession();
      // The console breaks mid-session; the customer still has to be billed.
      await catalog.setResourceStatus('hex', ResourceStatus.maintenance);
      clock.advance(const Duration(hours: 1));

      final segments = await sessions.segmentsFor(session.id);
      final paid = await actions.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: 20000,
        method: PaymentMethod.cash,
      ));
      expect(paid.isOk, isTrue, reason: paid.failureOrNull?.display);

      final ended = await actions.end(session, segments);
      expect(ended.isOk, isTrue, reason: ended.failureOrNull?.display);
      expect((await sessions.getById(session.id))!.status,
          SessionStatus.completed);
    });

    test('an available station still works', () async {
      await catalog.setResourceStatus('hex', ResourceStatus.maintenance);
      await catalog.setResourceStatus('hex', ResourceStatus.available);
      final r = await actions.start(draft());
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    });
  });

  group('a station must be able to run the game', () {
    test('starting a session with an unplayable game is refused', () async {
      // Tekken 8 is seeded `not_playable` on RIFT.
      final r = await actions.start(NewSessionDraft(
        customerId: walkIn.id,
        resourceId: 'rift',
        resourceName: 'RIFT',
        activityCode: 'PS5',
        gameId: 'g_tekken8',
        controllerCount: 1,
        durationMinutes: 60,
      ));
      expect(r.isErr, isTrue,
          reason: 'the picker filters these out, but the write path is what '
              'a stale sheet or a booking check-in goes through');
      expect(r.failureOrNull!.code, 'not_playable');
      expect(await sessions.openSegments(), isEmpty);
    });

    test('a game not installed on the station at all is refused', () async {
      await catalog.setCompatibility(
          'g_wwe', 'hex', GameAvailability.notInstalled);
      final r = await actions.start(draft());
      expect(r.isErr, isTrue);
      expect(r.failureOrNull!.code, 'not_playable');
    });

    test('switching a running session to a game the station cannot run is '
        'refused', () async {
      final session = await startSession();
      final segment = (await sessions.segmentsFor(session.id)).single;
      // HEX can run WWE, but mark it unplayable mid-session (scratched disc).
      await catalog.setCompatibility(
          'g_wwe', 'hex', GameAvailability.maintenance);

      final r = await actions.changeGame(
        session: session,
        current: segment,
        gameId: 'g_wwe',
      );
      expect(r.isErr, isTrue);
      expect(r.failureOrNull!.code, 'not_playable');
      expect(await sessions.segmentsFor(session.id), hasLength(1),
          reason: 'a refused change must not split the session');
    });

    test('a session with no game chosen is fine', () async {
      final r = await actions.start(NewSessionDraft(
        customerId: walkIn.id,
        resourceId: 'hex',
        resourceName: 'HEX',
        activityCode: 'PS5',
        controllerCount: 1,
        durationMinutes: 60,
      ));
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    });
  });

  group('a reservation holds its station against walk-ins', () {
    test('a walk-in overlapping a booking on that station is refused',
        () async {
      // Booked 6:30–7:30 PM; the walk-in wants 6:00–7:00 PM on the same system.
      await bookStation(
        resourceId: 'hex',
        from: start.add(const Duration(minutes: 30)),
        length: const Duration(hours: 1),
      );

      final r = await actions.start(draft(minutes: 60));
      expect(r.isErr, isTrue,
          reason: 'starting over a reservation is the double-booking the '
              'reservation exists to prevent');
      expect(r.failureOrNull!.code, 'resource_busy');
      expect(await sessions.openSegments(), isEmpty);
    });

    test('a walk-in that finishes before the booking starts is allowed',
        () async {
      await bookStation(
        resourceId: 'hex',
        from: start.add(const Duration(hours: 2)),
        length: const Duration(hours: 1),
      );
      // 6:00–7:00 PM, booking is 8:00–9:00 PM.
      final r = await actions.start(draft(minutes: 60));
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    });

    test('a booking on another station does not block this one', () async {
      await bookStation(
        resourceId: 'void',
        from: start.add(const Duration(minutes: 30)),
        length: const Duration(hours: 1),
      );
      final r = await actions.start(draft(resourceId: 'hex'));
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    });

    test('an any-system booking does not hold a particular station', () async {
      await bookings.create(Booking(
        id: const Uuid().v4(),
        activityCode: 'PS5',
        resourceId: null, // any compatible system
        scheduledStart: start.add(const Duration(minutes: 30)),
        scheduledEnd: start.add(const Duration(minutes: 90)),
        status: BookingStatus.booked,
        partyName: 'Flexible',
        createdAt: clock.now(),
        updatedAt: clock.now(),
      ));
      final r = await actions.start(draft());
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    });

    test('a cancelled booking does not block', () async {
      final booking = await bookStation(
        resourceId: 'hex',
        from: start.add(const Duration(minutes: 30)),
        length: const Duration(hours: 1),
      );
      await bookings.setStatus(booking.id, BookingStatus.cancelled);
      final r = await actions.start(draft(minutes: 60));
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    });

    test('an extension cannot run into a reservation', () async {
      final session = await startSession();
      // Booked from 7:00 PM — exactly when this session is due to end.
      await bookStation(
        resourceId: 'hex',
        from: start.add(const Duration(hours: 1)),
        length: const Duration(hours: 1),
      );
      final segments = await sessions.segmentsFor(session.id);
      final r = await actions.extend(session, segments, 30);
      expect(r.isErr, isTrue,
          reason: 'extending into a reservation double-books the station');
      expect((await sessions.getById(session.id))!.scheduledEndAt,
          session.scheduledEndAt);
    });
  });

  group('money rows keep their sign', () {
    test('a refund is stored negative even when passed positive', () async {
      final session = await startSession();
      await actions.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: 60700,
        method: PaymentMethod.cash,
      ));
      // A positive "refund" would otherwise be added to the takings.
      final r = await actions.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: 20000,
        method: PaymentMethod.cash,
        isRefund: true,
        reason: 'left early',
      ));
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);

      final all = await sessions.paymentsFor(session.id);
      final refund = all.firstWhere((p) => p.isRefund);
      expect(refund.amountPaise, -20000);
      expect(all.fold<int>(0, (a, p) => a + p.amountPaise), 40700,
          reason: '607.00 taken less 200.00 returned');
    });

    test('a refund passed negative stays negative', () async {
      final session = await startSession();
      await actions.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: 60700,
        method: PaymentMethod.cash,
      ));
      await actions.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: -20000,
        method: PaymentMethod.cash,
        isRefund: true,
        reason: 'left early',
      ));
      final refund =
          (await sessions.paymentsFor(session.id)).firstWhere((p) => p.isRefund);
      expect(refund.amountPaise, -20000);
    });

    test('a negative payment is refused, not treated as a refund', () async {
      final session = await startSession();
      final r = await actions.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: -20000,
        method: PaymentMethod.cash,
      ));
      expect(r.isErr, isTrue,
          reason: 'a negative payment would return money with no reason '
              'recorded and no discount permission checked');
      expect(r.failureOrNull!.code, 'amount_negative');
      expect(await sessions.paymentsFor(session.id), isEmpty);
    });

    test('a zero payment is refused', () async {
      final session = await startSession();
      final r = await actions.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: 0,
        method: PaymentMethod.cash,
      ));
      expect(r.isErr, isTrue);
      expect(r.failureOrNull!.code, 'amount_zero');
      expect(await sessions.paymentsFor(session.id), isEmpty);
    });

    test('a refund still needs a reason', () async {
      final session = await startSession();
      final r = await actions.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: 20000,
        method: PaymentMethod.cash,
        isRefund: true,
      ));
      expect(r.isErr, isTrue);
      expect(r.failureOrNull!.code, 'refund_reason_required');
    });

    test('part payments add up and settle the bill', () async {
      final session = await startSession();
      clock.advance(const Duration(hours: 1));
      final segments = await sessions.segmentsFor(session.id);
      final bill = actions.endSummary(session, segments);

      await actions.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: 10000,
        method: PaymentMethod.cash,
      ));
      await actions.end(session, segments);
      expect((await sessions.getById(session.id))!.paymentStatus,
          PaymentStatus.partial);

      await actions.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: bill.total.value - 10000,
        method: PaymentMethod.upi,
      ));
      expect((await sessions.getById(session.id))!.paymentStatus,
          PaymentStatus.paid);
    });
  });

  group('repeated operations do not duplicate', () {
    test('a second start on the same station is refused', () async {
      await startSession();
      final again = await actions.start(draft());
      expect(again.isErr, isTrue);
      expect(await sessions.openSegments(), hasLength(1),
          reason: 'one open segment per station');
    });

    test('ending twice bills once', () async {
      final session = await startSession();
      clock.advance(const Duration(hours: 1));
      final segments = await sessions.segmentsFor(session.id);

      final first = await actions.end(session, segments);
      expect(first.isOk, isTrue);
      final billed = (await sessions.getById(session.id))!.billedAmountPaise;
      final chargeCount = (await sessions.chargesFor(session.id)).length;
      expect(chargeCount, greaterThan(0));

      final second = await actions.end(session, segments);
      expect(second.isOk, isTrue, reason: 'idempotent, not an error');
      expect((await sessions.getById(session.id))!.billedAmountPaise, billed,
          reason: 'the bill must not double');
      expect(await sessions.chargesFor(session.id), hasLength(chargeCount),
          reason: 'the charge rows the report reads must not be duplicated');
    });
  });

  group('the booking window query is honest about overlap', () {
    test('half-open: a booking starting exactly at the end does not overlap',
        () async {
      final from = start.add(const Duration(hours: 1));
      await bookStation(
          resourceId: 'hex', from: from, length: const Duration(hours: 1));
      final found = await bookings.overlapping(
        start,
        from, // window ends exactly when the booking starts
      );
      expect(found, isEmpty);

      final overlapping = await bookings.overlapping(
        start,
        from.add(const Duration(minutes: 1)),
      );
      expect(overlapping, hasLength(1));
    });

    test('UtcInterval agrees with it', () {
      final a = UtcInterval(start, start.add(const Duration(hours: 1)));
      final b = UtcInterval(start.add(const Duration(hours: 1)),
          start.add(const Duration(hours: 2)));
      expect(a.overlaps(b), isFalse);
    });
  });
}
