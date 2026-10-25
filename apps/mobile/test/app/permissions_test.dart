/// Permission enforcement on protected actions.
///
/// These go through the action controllers rather than the widgets on purpose:
/// hiding a button is a courtesy, and the question here is whether the action
/// itself refuses someone who is not allowed to take it.
library;

import 'package:arena_ops/app/controllers/session_actions.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_booking_repository.dart';
import 'package:arena_ops/data/local/local_catalog_repository.dart';
import 'package:arena_ops/data/local/local_customer_repository.dart';
import 'package:arena_ops/data/local/local_session_repository.dart';
import 'package:arena_ops/data/local/seed_data.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/auth/permission_guard.dart';
import 'package:arena_ops/domain/entities/customer.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pricing_fixtures.dart';

void main() {
  late AppDatabase db;
  late LocalSessionRepository sessions;
  late LocalCatalogRepository catalog;
  late Customer walkIn;

  final start = ist(2026, 10, 2, 18, 0);
  final clock = FakeClock(start);

  const everything = AppUser(
    id: 'owner',
    name: 'Arjun Mehra',
    perms: {
      Permission.start,
      Permission.bill,
      Permission.discount,
      Permission.money,
      Permission.reports,
      Permission.settings,
    },
  );

  /// Can run the floor and take money, but cannot discount, waive or refund.
  const floorOnly = AppUser(
    id: 'floor',
    name: 'Priya Nair',
    perms: {Permission.start, Permission.bill},
  );

  /// Can take money but must not start or reconfigure sessions.
  const tillOnly = AppUser(
    id: 'till',
    name: 'Sam',
    perms: {Permission.bill},
  );

  SessionActions actionsFor(AppUser? user) => SessionActions(
        sessions: sessions,
        catalog: catalog,
        bookings: LocalBookingRepository(db, clock),
        clock: clock,
        guard: PermissionGuard(user),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await LocalSeed.apply(db);
    sessions = LocalSessionRepository(db, clock);
    catalog = LocalCatalogRepository(db);
    walkIn = await LocalCustomerRepository(db, clock).create(name: 'Walk-in');
  });

  tearDown(() async => db.close());

  NewSessionDraft draft() => NewSessionDraft(
        customerId: walkIn.id,
        resourceId: 'hex',
        resourceName: 'HEX',
        activityCode: 'PS5',
        gameId: 'g_wwe',
        controllerCount: 1,
        durationMinutes: 60,
      );

  /// A live session to act on, created by someone who is allowed to.
  Future<Session> liveSession() async {
    final started = await actionsFor(everything).start(draft());
    expect(started.isOk, isTrue, reason: started.failureOrNull?.display);
    return started.valueOrNull!;
  }

  group('a locked app refuses every protected action', () {
    test('nobody signed in cannot start a session', () async {
      final r = await actionsFor(null).start(draft());
      expect(r.isErr, isTrue);
      expect(r.failureOrNull!.code, 'not_signed_in');
      // Nothing was written.
      expect(await sessions.openSegments(), isEmpty);
    });

    test('nobody signed in cannot take a payment', () async {
      final session = await liveSession();
      final r = await actionsFor(null).recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: 10000,
        method: PaymentMethod.cash,
      ));
      expect(r.isErr, isTrue);
      expect(r.failureOrNull!.code, 'not_signed_in');
      expect(await sessions.paymentsFor(session.id), isEmpty,
          reason: 'a refused payment must not be recorded');
    });

    test('a deactivated account is refused even holding the permission',
        () async {
      final r = await actionsFor(
        const AppUser(
          id: 'x',
          name: 'Ex-staff',
          perms: {Permission.start},
          active: false,
        ),
      ).start(draft());
      expect(r.isErr, isTrue);
      expect(r.failureOrNull!.code, 'account_inactive');
    });
  });

  group('start permission', () {
    test('someone without it cannot start a session', () async {
      final r = await actionsFor(tillOnly).start(draft());
      expect(r.isErr, isTrue);
      expect(r.failureOrNull!.code, 'not_permitted');
      expect(await sessions.openSegments(), isEmpty);
    });

    test('someone without it cannot move a session between stations',
        () async {
      final session = await liveSession();
      final segment = (await sessions.segmentsFor(session.id)).single;
      final r = await actionsFor(tillOnly).switchSystem(
        session: session,
        current: segment,
        resourceId: 'void',
        resourceName: 'VOID',
        activityCode: 'PS5',
        gameId: 'g_wwe',
        controllerCount: 1,
      );
      expect(r.isErr, isTrue);
      expect(r.failureOrNull!.code, 'not_permitted');
      // The session is still on the original station.
      expect((await sessions.openSegments()).single.resourceId, 'hex');
    });

    test('someone without it cannot change controllers or extend', () async {
      final session = await liveSession();
      final segment = (await sessions.segmentsFor(session.id)).single;
      final blocked = actionsFor(tillOnly);

      final controllers = await blocked.changeControllers(
          session: session, current: segment, controllerCount: 3);
      expect(controllers.failureOrNull!.code, 'not_permitted');

      final extended = await blocked.extend(
          session, await sessions.segmentsFor(session.id), 30);
      expect(extended.failureOrNull!.code, 'not_permitted');
      // The scheduled end did not move.
      expect((await sessions.getById(session.id))!.scheduledEndAt,
          session.scheduledEndAt);
    });

    test('someone with it can', () async {
      final r = await actionsFor(floorOnly).start(draft());
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
      expect((await sessions.openSegments()).single.resourceId, 'hex');
    });
  });

  group('billing permission', () {
    test('someone without it cannot take a payment or close the bill',
        () async {
      final session = await liveSession();
      final blocked = actionsFor(
        const AppUser(id: 'g', name: 'Guest', perms: {Permission.start}),
      );

      final paid = await blocked.recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: 10000,
        method: PaymentMethod.cash,
      ));
      expect(paid.failureOrNull!.code, 'not_permitted');

      final ended = await blocked.end(
          session, await sessions.segmentsFor(session.id));
      expect(ended.failureOrNull!.code, 'not_permitted');
      expect((await sessions.getById(session.id))!.status,
          SessionStatus.active,
          reason: 'a refused checkout must leave the session running');
    });

    test('someone with it can take a part payment', () async {
      final session = await liveSession();
      final r = await actionsFor(floorOnly).recordPayment(RecordPaymentCommand(
        sessionId: session.id,
        amountPaise: 10000,
        method: PaymentMethod.cash,
      ));
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
      expect((await sessions.paymentsFor(session.id)).single.amountPaise, 10000);
    });
  });

  group('discount permission (waive and refund)', () {
    test('billing alone does not allow waiving a bill', () async {
      final session = await liveSession();
      clock.advance(const Duration(hours: 1));
      final r = await actionsFor(floorOnly).end(
        session,
        await sessions.segmentsFor(session.id),
        markWaived: true,
      );
      expect(r.isErr, isTrue);
      expect(r.failureOrNull!.code, 'not_permitted');
      expect((await sessions.getById(session.id))!.status, SessionStatus.active,
          reason: 'the write-off must not go through');
    });

    test('billing alone does not allow a refund', () async {
      final session = await liveSession();
      final taken = await actionsFor(floorOnly).recordPayment(
        RecordPaymentCommand(
          sessionId: session.id,
          amountPaise: 10000,
          method: PaymentMethod.cash,
        ),
      );
      expect(taken.isOk, isTrue);

      final refund = await actionsFor(floorOnly).recordPayment(
        RecordPaymentCommand(
          sessionId: session.id,
          amountPaise: 10000,
          method: PaymentMethod.cash,
          isRefund: true,
          reason: 'changed their mind',
        ),
      );
      expect(refund.isErr, isTrue);
      expect(refund.failureOrNull!.code, 'not_permitted');
      // Only the original payment is on the session.
      final payments = await sessions.paymentsFor(session.id);
      expect(payments, hasLength(1));
      expect(payments.single.isRefund, isFalse);
    });

    test('someone holding discount can waive and refund', () async {
      final session = await liveSession();
      // Nothing collected yet: there is nothing to give back.
      final early = await actionsFor(everything).recordPayment(
        RecordPaymentCommand(
          sessionId: session.id,
          amountPaise: 5000,
          method: PaymentMethod.cash,
          isRefund: true,
          reason: 'double charge',
        ),
      );
      expect(early.failureOrNull?.code, 'refund_exceeds_paid');
      final paid = await actionsFor(everything).recordPayment(
        RecordPaymentCommand(
            sessionId: session.id, amountPaise: 5000, method: PaymentMethod.cash),
      );
      expect(paid.isOk, isTrue, reason: paid.failureOrNull?.display);
      final refund = await actionsFor(everything).recordPayment(
        RecordPaymentCommand(
          sessionId: session.id,
          amountPaise: 5000,
          method: PaymentMethod.cash,
          isRefund: true,
          reason: 'double charge',
        ),
      );
      expect(refund.isOk, isTrue, reason: refund.failureOrNull?.display);

      clock.advance(const Duration(hours: 1));
      final waived = await actionsFor(everything).end(
        session,
        await sessions.segmentsFor(session.id),
        markWaived: true,
        waiveReason: 'Birthday treat',
      );
      expect(waived.isOk, isTrue, reason: waived.failureOrNull?.display);
    });
  });

  group('the guard fails closed', () {
    test('an action controller built without an actor allows nothing', () {
      const guard = PermissionGuard(null);
      for (final p in Permission.values) {
        expect(guard.allows(p), isFalse,
            reason: '$p must not be allowed with nobody signed in');
      }
    });

    test('the refusal names the person and what they cannot do', () {
      const guard = PermissionGuard(floorOnly);
      final failure = guard.check(Permission.discount)!;
      expect(failure.message, contains('Priya Nair'));
      expect(failure.display, contains('waive'));
      expect(failure.fix, isNotNull);
    });
  });
}
