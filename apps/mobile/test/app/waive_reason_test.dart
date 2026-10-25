/// A waive writes money off, so it always says why: the action layer refuses
/// one without a reason (the session keeps running and nothing is sent), and
/// with one the end op sent to the server carries it, which audits it with the
/// amount written off (op_session_end, audit action `waive`).
library;

import 'dart:convert';

import 'package:arena_ops/app/controllers/session_actions.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_booking_repository.dart';
import 'package:arena_ops/data/local/local_catalog_repository.dart';
import 'package:arena_ops/data/local/local_customer_repository.dart';
import 'package:arena_ops/data/local/local_session_repository.dart';
import 'package:arena_ops/data/local/seed_data.dart';
import 'package:arena_ops/data/sync/sync_recorder.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/auth/permission_guard.dart';
import 'package:arena_ops/domain/entities/customer.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pricing_fixtures.dart';

void main() {
  late AppDatabase db;
  late LocalSessionRepository sessions;
  late SessionActions actions;
  late Customer walkIn;
  final clock = FakeClock(ist(2026, 10, 2, 18, 0));

  const owner = AppUser(
    id: 'owner',
    name: 'Arjun Mehra',
    // Owner level (money): below it a waive is capped at the manual-discount
    // limit (waive_over_limit), which is not what these tests are about.
    perms: {Permission.start, Permission.bill, Permission.discount, Permission.money},
  );

  setUp(() async {
    clock.set(ist(2026, 10, 2, 18, 0));
    db = AppDatabase(NativeDatabase.memory());
    await LocalSeed.apply(db);
    final recorder = SyncRecorder(db, actor: () => 'owner', clock: clock);
    sessions = LocalSessionRepository(db, clock, recorder);
    actions = SessionActions(
      sessions: sessions,
      catalog: LocalCatalogRepository(db),
      bookings: LocalBookingRepository(db, clock),
      clock: clock,
      guard: const PermissionGuard(owner),
    );
    walkIn = await LocalCustomerRepository(db, clock).create(name: 'Walk-in');
  });

  tearDown(() async => db.close());

  Future<Session> live() async {
    final started = await actions.start(NewSessionDraft(
      customerId: walkIn.id,
      resourceId: 'hex',
      resourceName: 'HEX',
      activityCode: 'PS5',
      gameId: 'g_wwe',
      controllerCount: 1,
      durationMinutes: 60,
    ));
    expect(started.isOk, isTrue, reason: started.failureOrNull?.display);
    clock.advance(const Duration(hours: 1));
    return started.valueOrNull!;
  }

  Future<List<Map<String, dynamic>>> endOps() async => [
        for (final o in await (db.select(db.syncOutbox)
              ..where((t) => t.kind.equals('session.end')))
            .get())
          jsonDecode(o.payload) as Map<String, dynamic>,
      ];

  test('a waive without a reason is refused; the session keeps running', () async {
    final session = await live();
    final r = await actions.end(
      session,
      await sessions.segmentsFor(session.id),
      markWaived: true,
    );
    expect(r.failureOrNull?.code, 'waive_reason_required');
    expect(r.failureOrNull?.fix, isNotNull, reason: 'the copy says what to do');
    expect((await sessions.getById(session.id))!.status, SessionStatus.active);
    expect(await endOps(), isEmpty, reason: 'nothing goes to the server');
  });

  test('a blank reason counts as none', () async {
    final session = await live();
    final r = await actions.end(
      session,
      await sessions.segmentsFor(session.id),
      markWaived: true,
      waiveReason: '   ',
    );
    expect(r.failureOrNull?.code, 'waive_reason_required');
  });

  test('with a reason the bill is waived and the end op carries the reason, trimmed', () async {
    final session = await live();
    final r = await actions.end(
      session,
      await sessions.segmentsFor(session.id),
      markWaived: true,
      waiveReason: '  Birthday treat ',
    );
    expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    final ended = (await sessions.getById(session.id))!;
    expect(ended.status, SessionStatus.completed);
    expect(ended.paymentStatus, PaymentStatus.waived);
    final op = (await endOps()).single;
    expect(op['mark_waived'], isTrue);
    expect(op['waive_reason'], 'Birthday treat');
  });

  test('an ordinary end sends no waive reason, even if one was typed', () async {
    final session = await live();
    final r = await actions.end(
      session,
      await sessions.segmentsFor(session.id),
      waiveReason: 'left over from the switch',
    );
    expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    final op = (await endOps()).single;
    expect(op['mark_waived'], isFalse);
    expect(op.containsKey('waive_reason'), isFalse);
  });
}
