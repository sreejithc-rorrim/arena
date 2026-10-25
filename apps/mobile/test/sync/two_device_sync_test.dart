/// Two independent device databases, two accounts (owner + staff), one local
/// Supabase stack. Nothing is mocked: every op goes through sync_push and every
/// change comes back through sync_pull, applied by the real SyncApplier.
///
/// Needs the local dev stack and its URL + anon key in the environment:
///   bash tool/sync_it.sh
/// Skipped (not failed) when they are absent, so `flutter test` stays offline.
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:arena_ops/data/sync/sync_engine.dart';
import 'package:arena_ops/data/sync/sync_recorder.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/domain/pricing/pricing_service.dart';
import 'package:arena_ops/domain/reports/report_models.dart';
import 'package:arena_ops/domain/reports/reports_service.dart';
import 'package:arena_ops/domain/pricing/rate.dart';
import 'package:arena_ops/domain/services/segment_billing.dart';
import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/data/local/local_user_repository.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/entities/booking.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import 'package:uuid/uuid.dart';

import '../support/sim_device.dart';

void main() {
  final url = Platform.environment['AO_SUPABASE_URL'];
  final key = Platform.environment['AO_SUPABASE_ANON_KEY'];
  // Provisioned by tool/sync_it.sh: throw-away local logins (Auth admin API),
  // the owner attached by bootstrap_owner, the arena given the test catalog.
  final ownerEmail = Platform.environment['AO_IT_OWNER_EMAIL'];
  final staffEmail = Platform.environment['AO_IT_STAFF_EMAIL'];
  final provisionedArena = Platform.environment['AO_IT_ARENA'];
  final skip = (url == null || key == null || ownerEmail == null)
      ? 'local Supabase stack not configured (run tool/sync_it.sh)'
      : null;

  late SimDevice a; // owner's phone
  late SimDevice b; // staff tablet
  late String arenaId;

  setUpAll(() async {
    if (skip != null) return;
    a = await SimDevice.signIn('A', url!, key!, ownerEmail!);
    arenaId = provisionedArena!;
    // The staff login joins the only way there is: the owner invites it and
    // it accepts with the one-time token (the e-mail delivery itself is
    // covered by the dashboard suite; here the token comes back to the owner).
    final invite = await a.client.rpc('invite_member', params: {
      'p_arena': arenaId,
      'p_email': staffEmail,
      'p_name': 'Staff B',
      'p_role': 'staff',
      'p_perms': ['start', 'bill', 'discount', 'members'],
    }) as Map;
    b = await SimDevice.signIn('B', url, key, staffEmail!);
    await b.client.rpc('accept_invite', params: {
      'p_invite': invite['invite_id'],
      'p_token': invite['token'],
    });
    a.bind(arenaId);
    b.bind(arenaId);
  });

  tearDownAll(() async {
    if (skip != null) return;
    await a.close();
    await b.close();
  });

  Future<int> serverCount(String table, String column, String value,
      {bool openOnly = false}) async {
    var q = a.client.from(table).select('id').eq(column, value);
    if (openOnly) q = q.isFilter('ended_at', null);
    return (await q).length;
  }

  // The server re-prices every bill (0013), so money the tests send must be
  // what the app would compute: the same engine the End / Extend screens use.
  Future<EndSessionCommand> pricedEnd(SimDevice d, String id, DateTime at) async {
    final s = (await d.sessions.getById(id))!;
    final bill = const SegmentBilling().bill(
        snapshot: s.snapshot, segments: await d.sessions.segmentsFor(id), openEndAt: at,
        sessionStart: s.startedAt);
    return EndSessionCommand(sessionId: id, actualEndedAt: at,
        charges: bill.charges, billedAmountPaise: bill.total.value);
  }

  // SessionPlanner.planExtension: quote to the new end − quote to the old end.
  Future<int> extensionCost(SimDevice d, Session s, DateTime newEnd) async {
    final segs = await d.sessions.segmentsFor(s.id);
    final open = segs.firstWhere((x) => x.isOpen, orElse: () => segs.last);
    int quote(DateTime end) => const PricingService()
        .quote(snapshot: s.snapshot, activityCode: open.activityCode,
            controllerCount: open.controllerCount, start: s.startedAt, end: end)
        .valueOrNull!
        .amount
        .value;
    return quote(newEnd) - quote(s.scheduledEndAt);
  }

  test('sign-up: confirm the e-mail first, one arena per login, no other route',
      () async {
    final stranger = SupabaseClient(url!, key!,
        authOptions: const AuthClientOptions(
            autoRefreshToken: false, authFlowType: AuthFlowType.implicit));
    addTearDown(stranger.dispose);
    final email = 'stranger-${DateTime.now().microsecondsSinceEpoch}@arena.test';
    try {
      final res = await stranger.auth.signUp(email: email, password: 'stranger-pass-123');
      expect(res.session, isNull, reason: 'a new login must confirm its e-mail first');
      await expectLater(
          stranger.auth.signInWithPassword(email: email, password: 'stranger-pass-123'),
          throwsA(isA<AuthException>()
              .having((e) => e.code, 'code', 'email_not_confirmed')));
    } on AuthException catch (e) {
      // The local stack sends at most a few e-mails an hour.
      expect(e.code, 'over_email_send_rate_limit');
    }
    await expectLater(stranger.auth.signInAnonymously(),
        throwsA(isA<AuthException>()));
    // Signed out, nothing can create an arena.
    await expectLater(
        stranger.rpc('create_my_arena', params: {'p_arena_name': 'Mine', 'p_owner_name': 'X'}),
        throwsA(isA<PostgrestException>()));
    // An owner already has their arena: the app's one-per-login limit holds.
    await expectLater(
        a.client.rpc('create_my_arena', params: {'p_arena_name': 'Mine', 'p_owner_name': 'X'}),
        throwsA(isA<PostgrestException>()
            .having((e) => e.message, 'message', 'arena_limit')));
    // The legacy unconfirmed, unlimited route stays gone.
    await expectLater(
        a.client.rpc('create_arena', params: {'p_name': 'Mine', 'p_owner_name': 'X'}),
        throwsA(isA<PostgrestException>()
            .having((e) => e.code, 'code', anyOf('42501', 'PGRST202'))));
    final mine = await b.client.rpc('my_arenas') as List;
    expect([for (final m in mine) (m as Map)['arena_id']], [arenaId],
        reason: 'staff belongs to exactly the arena the owner added them to');
  }, skip: skip);

  test('staff replace the owner-issued password with their own', () async {
    final startingPassword =
        Platform.environment['AO_IT_PASSWORD'] ?? 'it-pass-$staffEmail';
    var restored = false;
    Future<void> restorePassword() async {
      if (restored) return;
      restored = true;
      await b.client.auth.updateUser(UserAttributes(password: startingPassword));
    }

    addTearDown(restorePassword);

    await b.client.auth.updateUser(UserAttributes(password: 'staff-own-pass-42'));
    final again = SupabaseClient(url!, key!,
        authOptions: const AuthClientOptions(
            autoRefreshToken: false, authFlowType: AuthFlowType.implicit));
    addTearDown(again.dispose);
    await expectLater(
        again.auth.signInWithPassword(email: staffEmail!, password: startingPassword),
        throwsA(isA<AuthException>()), reason: 'the starting password no longer works');
    final ok = await again.auth.signInWithPassword(email: staffEmail, password: 'staff-own-pass-42');
    expect(ok.session, isNotNull);

    await restorePassword();
  }, skip: skip);

  test('both devices start from the server catalog (shared identity)', () async {
    expect((await a.sync()).endedIn, SyncState.synced);
    expect((await b.sync()).endedIn, SyncState.synced);
    for (final d in [a, b]) {
      expect((await d.db.select(d.db.resources).get()).length, 6);
      expect((await d.db.select(d.db.controllers).get()).length, 8);
      expect((await d.db.select(d.db.rates).get()).length, 12);
      // Everyone the server lists as a member (the dashboard phase may have
      // added an invited person), owner and staff among them.
      final users = await d.db.select(d.db.users).get();
      final members = await a.client.from('staff_profiles').select('user_id').eq('arena_id', arenaId);
      expect(users.length, members.length);
      expect(users.map((u) => u.id), containsAll([a.userId, b.userId]));
    }
    expect(await a.station('HEX'), await b.station('HEX'),
        reason: 'one id per station on every device');
    final staff = await (b.db.select(b.db.users)
          ..where((t) => t.id.equals(b.userId)))
        .getSingle();
    expect(staff.perms.toSet(), {'start', 'bill', 'discount', 'members'});
  }, skip: skip);

  late String ravi;

  test('critical scenario: HEX holds VOID-1/2; VOID borrows from GHOST on '
      'another device', () async {
    ravi = (await a.customers.create(name: 'Ravi', phone: '98${DateTime.now().microsecond}1')).id;
    final hex = await a.start(
      customerId: ravi,
      stationName: 'HEX',
      padLabels: ['HEX-1', 'HEX-2', 'VOID-1', 'VOID-2'],
      borrowLabels: ['VOID-1', 'VOID-2'],
    );
    expect(hex.isOk, isTrue, reason: '${hex.failureOrNull?.message}');
    final pushed = await a.sync();
    expect(pushed.applied, 2, reason: 'customer.create + session.start');
    expect(pushed.rejected, 0);
    expect(await serverCount('controller_allocations', 'session_id',
        hex.valueOrNull!.id, openOnly: true), 4);

    // Device B learns about it through the pull alone.
    await b.sync();
    expect(await b.openPadLabels(), {'HEX-1', 'HEX-2', 'VOID-1', 'VOID-2'});
    final void1 = await (b.db.select(b.db.controllers)
          ..where((t) => t.label.equals('VOID-1')))
        .getSingle();
    expect(void1.currentResourceId, await b.station('HEX'),
        reason: 'the borrow (location) synced too');

    // A new customer wants VOID: VOID-1/2 cannot be taken again — refused
    // on the device before anything is written.
    final walkIn = (await b.customers.createGuest()).id;
    final reuse = await b.start(
        customerId: walkIn, stationName: 'VOID', padLabels: ['VOID-1', 'VOID-2']);
    expect(reuse.isErr, isTrue);
    expect(reuse.failureOrNull!.code, anyOf('controller_elsewhere', 'controller_taken'));
    // Count-only: VOID has no free pads.
    final countOnly = await b.start(
        customerId: walkIn, stationName: 'VOID', padLabels: const [], count: 2);
    expect(countOnly.failureOrNull?.code, 'controllers_unavailable');

    // Borrowing GHOST's pads works, on B, and the server agrees.
    final onVoid = await b.start(
      customerId: walkIn,
      stationName: 'VOID',
      padLabels: ['GHOST-1', 'GHOST-2'],
      borrowLabels: ['GHOST-1', 'GHOST-2'],
    );
    expect(onVoid.isOk, isTrue, reason: '${onVoid.failureOrNull?.message}');
    final bPush = await b.sync();
    expect(bPush.rejected, 0);
    expect(await serverCount('controller_moves', 'session_ref',
        's:${onVoid.valueOrNull!.id}'), 2);

    await a.sync();
    expect(await a.openPadLabels(),
        {'HEX-1', 'HEX-2', 'VOID-1', 'VOID-2', 'GHOST-1', 'GHOST-2'},
        reason: 'A sees B\'s session and pads');
  }, skip: skip);

  test('offline conflict: both devices take RIFT; the second is refused, '
      'rolled back, and kept for attention — money included', () async {
    final x = (await a.customers.createGuest()).id;
    final y = (await b.customers.createGuest()).id;
    // Neither device syncs: each believes RIFT and RIFT-1 are free.
    final onA = await a.start(customerId: x, stationName: 'RIFT', padLabels: ['RIFT-1']);
    final onB = await b.start(customerId: y, stationName: 'RIFT', padLabels: ['RIFT-1']);
    expect(onA.isOk && onB.isOk, isTrue);
    final bSession = onB.valueOrNull!.id;
    await b.sessions.recordPayment(RecordPaymentCommand(
        sessionId: bSession, amountPaise: 15000, method: PaymentMethod.cash));

    expect((await a.sync()).rejected, 0, reason: 'A reaches the server first');
    final report = await b.sync();
    expect(report.rejected, 2, reason: 'B\'s start and its payment are refused');
    expect(report.rolledBack, greaterThanOrEqualTo(2));

    // B converged on the server: its RIFT session is gone, A's is there.
    expect(await b.sessions.getById(bSession), isNull);
    expect((await b.sessions.getById(onA.valueOrNull!.id))?.isActive, isTrue);
    expect(await b.openPadLabels(), contains('RIFT-1'));
    expect(await b.sessions.paymentsFor(bSession), isEmpty);
    // …but nothing is lost: the refused ops (with the ₹150) await a person.
    final refused = await b.outbox(OutboxStatus.rejected);
    expect({for (final o in refused) o.kind}, {'session.start', 'payment.record'});
    expect(refused.firstWhere((o) => o.kind == 'session.start').errorCode,
        anyOf('resource_busy', 'controller_taken'));
    expect(refused.firstWhere((o) => o.kind == 'payment.record').payload,
        contains('15000'));
    expect(b.engine.status.needsAttention, 2);
    expect(await serverCount('sessions', 'id', bSession), 0);
  }, skip: skip);

  test('a payment retried after a lost response is recorded once', () async {
    final s = (await a.sessions.active()).first.session.id;
    final pay = await a.sessions.recordPayment(RecordPaymentCommand(
        sessionId: s, amountPaise: 5000, method: PaymentMethod.upi));
    final op = (await a.outbox(OutboxStatus.pending)).single;
    // The push reaches the server, but the device never hears back.
    final first = await a.transport.push(arenaId, [
      (
        opId: op.opId,
        kind: op.kind,
        payload: jsonDecode(op.payload) as Map<String, dynamic>,
      ),
    ], 'lost-response');
    expect(first.single.status, 'applied');
    expect((await a.outbox(OutboxStatus.pending)).single.opId, op.opId,
        reason: 'the device still thinks it is pending');
    // Its next pass sends it again: the server replays, never re-applies.
    final again = await a.sync();
    expect(again.applied, 1);
    expect(await a.outbox(OutboxStatus.pending), isEmpty);
    expect(await serverCount('payments', 'id', pay.valueOrNull!.id), 1);
    expect(await serverCount('payments', 'session_id', s), 1);
  }, skip: skip);

  test('a stale end (priced before another device extended) is refused and '
      'the device rolls forward to the server', () async {
    await a.sync();
    await b.sync();
    final target = (await b.sessions.active())
        .firstWhere((x) => x.segments.any((s) => s.isOpen && s.resourceId.isNotEmpty))
        .session;
    // A extends and syncs; B, not having pulled, ends from the old end.
    final newEnd = target.scheduledEndAt.add(const Duration(minutes: 30));
    final ext = await a.sessions.extend(ExtendSessionCommand(
      sessionId: target.id,
      addedMinutes: 30,
      newEndAt: newEnd,
      addedAmountPaise: await extensionCost(a, target, newEnd),
    ));
    expect(ext.isOk, isTrue);
    await a.sync();
    final ended = await b.sessions
        .end(await pricedEnd(b, target.id, DateTime.now().toUtc()));
    expect(ended.valueOrNull?.status, SessionStatus.completed);
    final r = await b.sync();
    expect(r.rejected, 1);
    final refused = (await b.outbox(OutboxStatus.rejected))
        .firstWhere((o) => o.kind == 'session.end');
    expect(refused.errorCode, 'stale');
    final now = await b.sessions.getById(target.id);
    expect(now!.isActive, isTrue, reason: 'rolled back to the server: still running');
    expect(now.scheduledEndAt, target.scheduledEndAt.add(const Duration(minutes: 30)));
    expect(await b.sessions.chargesFor(target.id), isEmpty,
        reason: 'the refused bill\'s charges are gone');
    expect((await b.sessions.segmentsFor(target.id)).where((s) => s.isOpen),
        hasLength(1), reason: 'its station is held again on this device');
    final reopened = await (b.db.select(b.db.controllerAllocations)
          ..where((t) => t.sessionId.equals(target.id) & t.endedAt.isNull()))
        .get();
    expect(reopened, isNotEmpty,
        reason: 'the pads the refused end released are held again');
  }, skip: skip);

  test('staff cannot change prices: refused by the server, device reverts',
      () async {
    await b.catalog.upsertRate(Rate(
      activityCode: 'PS5',
      band: Band.standard,
      controllerCount: 1,
      unitMinutes: 60,
      price: const Paise(100),
    ));
    final r = await b.sync();
    expect(r.rejected, 1);
    expect((await b.outbox(OutboxStatus.rejected)).last.errorCode, 'forbidden');
    final price = (await b.catalog.rates()).firstWhere((x) =>
        x.activityCode == 'PS5' && x.band == Band.standard && x.controllerCount == 1);
    expect(price.price.value, 15000, reason: 'reverted to the server price');
  }, skip: skip);

  test('the owner can, and the other device gets it', () async {
    await a.catalog.upsertRate(Rate(
      activityCode: 'PS5',
      band: Band.standard,
      controllerCount: 1,
      unitMinutes: 60,
      price: const Paise(16000),
    ));
    expect((await a.sync()).rejected, 0);
    await b.sync();
    final price = (await b.catalog.rates()).where((x) =>
        x.activityCode == 'PS5' && x.band == Band.standard && x.controllerCount == 1);
    expect(price.single.price.value, 16000, reason: 'one row, the new price');
  }, skip: skip);

  test('ops survive a restart: a new engine on the same database sends them',
      () async {
    final g = (await b.customers.createGuest()).id;
    expect((await b.outbox(OutboxStatus.pending)).length, 1);
    await b.engine.dispose(); // "app killed" before it could sync
    final engine2 = SyncEngine(db: b.db, transport: b.transport, arenaId: arenaId);
    final r = await engine2.syncNow();
    expect(r.applied, 1);
    expect(await serverCount('customers', 'id', g), 1);
    await engine2.dispose();
    b.engine = engine2; // so tearDown disposes something valid
  }, skip: skip);

  test('ending a session on one device frees its pads on the other', () async {
    await a.sync();
    final hex = await a.station('HEX');
    final hexSession = (await a.sessions.active())
        .firstWhere((x) => x.segments.any((s) => s.isOpen && s.resourceId == hex))
        .session;
    // Ended 47m13.517s in: a real, multi-paise bill the server must re-price.
    final res = await a.sessions.end(await pricedEnd(a, hexSession.id,
        hexSession.startedAt.add(const Duration(minutes: 47, seconds: 13, milliseconds: 517))));
    expect(res.isOk, isTrue);
    expect((await a.sync()).rejected, 0);
    expect(await serverCount('controller_allocations', 'session_id', hexSession.id,
        openOnly: true), 0);
    await b.sync();
    final stillOpen = await (b.db.select(b.db.controllerAllocations)
          ..where((t) => t.sessionId.equals(hexSession.id) & t.endedAt.isNull()))
        .get();
    expect(stillOpen, isEmpty);
    final history = await (b.db.select(b.db.controllerAllocations)
          ..where((t) => t.sessionId.equals(hexSession.id)))
        .get();
    expect(history, isNotEmpty, reason: 'allocation history is kept');
  }, skip: skip);

  test('two devices checking in the same booking offline: one session, one '
      'check-in', () async {
    final start = DateTime.now().toUtc().add(const Duration(minutes: 5));
    final booking = await a.bookings.create(Booking(
      id: '',
      customerId: ravi,
      activityCode: 'POOL',
      resourceId: await a.station('Pool Table 1'),
      scheduledStart: start,
      scheduledEnd: start.add(const Duration(hours: 1)),
      status: BookingStatus.booked,
      createdAt: start,
      updatedAt: start,
    ));
    await a.sync();
    await b.sync();
    Future<Result<Session>> checkIn(SimDevice d) async {
      final now = DateTime.now().toUtc();
      return d.sessions.start(StartSessionCommand(
        customerId: ravi,
        startedAt: now,
        scheduledEndAt: now.add(const Duration(hours: 1)),
        snapshot: await d.catalog.currentSnapshot(),
        resourceId: await d.station('Pool Table 1'),
        resourceName: 'Pool Table 1',
        activityCode: 'POOL',
        bookingId: booking.id,
      ));
    }

    final onA = await checkIn(a);
    final onB = await checkIn(b);
    expect(onA.isOk && onB.isOk, isTrue, reason: 'both believe it is open');
    expect((await a.sync()).rejected, 0);
    expect((await b.sync()).rejected, 1);
    final refused = (await b.outbox(OutboxStatus.rejected)).last;
    expect(refused.errorCode, anyOf('booking_not_open', 'resource_busy'));
    expect(await b.sessions.getById(onB.valueOrNull!.id), isNull);
    expect((await b.bookings.getById(booking.id))!.status, BookingStatus.checkedIn);
    expect(await serverCount('sessions', 'booking_id', booking.id), 1);
  }, skip: skip);

  test('two ONLINE devices grab the same pad at the same moment: the server '
      'serialises them, exactly one holds it, both converge', () async {
    await a.sync();
    await b.sync();
    // VOID-1 stands at HEX (borrowed earlier), free since HEX ended.
    final onA = await a.start(
        customerId: ravi,
        stationName: 'GHOST',
        gameName: 'Tekken 8',
        padLabels: ['VOID-1'],
        borrowLabels: ['VOID-1']);
    final onB = await b.start(
        customerId: ravi, stationName: 'HEX', padLabels: ['VOID-1']);
    expect(onA.isOk && onB.isOk, isTrue,
        reason: '${onA.failureOrNull?.message} ${onB.failureOrNull?.message}');
    final results = await Future.wait([a.sync(), b.sync()]);
    expect(results[0].rejected + results[1].rejected, 1,
        reason: 'exactly one of the two is refused');
    final void1 = await a.pad('VOID-1');
    expect(await serverCount('controller_allocations', 'controller_id', void1,
        openOnly: true), 1);
    await a.sync();
    await b.sync();
    expect(await a.openPadLabels(), await b.openPadLabels(),
        reason: 'both devices agree who holds which pad');
  }, skip: skip);

  // The shift as two people work it: the owner starts a session, staff extend
  // it, end it, bill it and take the money on their own device; the owner's
  // device ends up with the same session, bill, payment and day totals, and
  // the server holds exactly one of each.
  test('owner starts, staff extend + end + take payment, owner sees the same '
      'bill, payment and day totals', () async {
    await a.sync();
    await b.sync();
    final lounge = await a.station('Private Lounge');
    final guest = (await a.customers.createGuest()).id;
    final startedAt = DateTime.now().toUtc().subtract(const Duration(minutes: 20));
    final started = await a.sessions.start(StartSessionCommand(
      customerId: guest,
      startedAt: startedAt,
      scheduledEndAt: startedAt.add(const Duration(hours: 1)),
      snapshot: await a.catalog.currentSnapshot(),
      resourceId: lounge,
      resourceName: 'Private Lounge',
      activityCode: 'LOUNGE',
    ));
    expect(started.isOk, isTrue, reason: '${started.failureOrNull?.message}');
    final id = started.valueOrNull!.id;
    expect((await a.sync()).rejected, 0);

    // Staff see it by pull alone: same id, same station, same planned end.
    await b.sync();
    final seen = (await b.sessions.getById(id))!;
    expect(seen.isActive, isTrue);
    expect(seen.scheduledEndAt, started.valueOrNull!.scheduledEndAt);
    expect((await b.sessions.segmentsFor(id)).single.resourceId, lounge);

    // Staff extend it (start permission) …
    final newEnd = seen.scheduledEndAt.add(const Duration(minutes: 30));
    final ext = await b.sessions.extend(ExtendSessionCommand(
        sessionId: id,
        addedMinutes: 30,
        newEndAt: newEnd,
        addedAmountPaise: await extensionCost(b, seen, newEnd)));
    expect(ext.isOk, isTrue, reason: '${ext.failureOrNull?.message}');
    expect((await b.sync()).rejected, 0);
    // … and the owner's device follows.
    await a.sync();
    expect((await a.sessions.getById(id))!.scheduledEndAt, newEnd);
    expect(await a.sessions.extensionsFor(id), hasLength(1));

    // Staff end, bill (bill permission) and take the money in one go.
    final endAt = startedAt.add(const Duration(minutes: 41, seconds: 7, milliseconds: 250));
    final ended = await b.sessions.end(await pricedEnd(b, id, endAt));
    expect(ended.isOk, isTrue, reason: '${ended.failureOrNull?.message}');
    final bill = ended.valueOrNull!.billedAmountPaise!;
    expect(bill, greaterThan(0));
    final paid = await b.sessions.recordPayment(RecordPaymentCommand(
        sessionId: id, amountPaise: bill, method: PaymentMethod.upi, requestId: 'pay-$id'));
    expect(paid.isOk, isTrue, reason: '${paid.failureOrNull?.message}');
    final pushed = await b.sync();
    expect(pushed.rejected, 0, reason: 'the server re-priced the bill and agreed');
    expect(await b.outbox(OutboxStatus.pending), isEmpty);

    // Server: one session, billed exactly what the device billed; one payment.
    final row = await a.client.from('sessions')
        .select('status, billed_amount_paise, payment_status').eq('id', id).single();
    expect(row['status'], 'completed');
    expect(row['billed_amount_paise'], bill);
    expect(row['payment_status'], 'paid');
    expect(await serverCount('payments', 'session_id', id), 1);
    expect(await serverCount('session_extensions', 'session_id', id), 1);

    // Owner's device converges on the same facts.
    await a.sync();
    final onA = (await a.sessions.getById(id))!;
    expect(onA.status, SessionStatus.completed);
    expect(onA.billedAmountPaise, bill);
    expect(onA.paymentStatus, PaymentStatus.paid);
    expect((await a.sessions.paymentsFor(id)).map((p) => p.amountPaise), [bill]);
    expect((await a.sessions.chargesFor(id)).fold<int>(0, (s, c) => s + c.amountPaise),
        (await b.sessions.chargesFor(id)).fold<int>(0, (s, c) => s + c.amountPaise));
    expect((await a.sessions.segmentsFor(id)).where((s) => s.isOpen), isEmpty,
        reason: 'the lounge is free on the owner\'s floor too');

    // Today's report is computed from each device's own database: equal.
    Future<(int, int, int)> today(SimDevice d) async {
      final range = ReportRange.today(IstDate.fromUtc(DateTime.now().toUtc()));
      final from = range.startUtc, to = range.endUtc;
      final r = const ReportsService().build(ReportInput(
        range: range,
        sessions: await d.sessions.inRange(from, to),
        segments: await d.sessions.segmentsInRange(from, to),
        charges: await d.sessions.chargesInRange(from, to),
        payments: await d.sessions.paymentsInRange(from, to),
        customers: await d.customers.all(),
        resources: await d.catalog.resources(),
        gameNames: const {},
        activityNames: const {},
        calendar: (await d.catalog.currentSnapshot()).calendar,
      ));
      return (r.billedPaise, r.collectedPaise, r.sessionCount);
    }

    expect(await today(a), await today(b));

    // The bill is settled: a second collection is refused on the device …
    final again = await b.sessions.recordPayment(RecordPaymentCommand(
        sessionId: id, amountPaise: bill, method: PaymentMethod.upi));
    expect(again.failureOrNull?.code, 'overpayment');
    // … and by the server for a device that had not seen the first payment
    // (the owner's phone before its pull): the server is the referee.
    final stalePay = await a.transport.push(arenaId, [
      (
        opId: const Uuid().v4(),
        kind: 'payment.record',
        payload: {
          'scope': 'single',
          'parent_id': id,
          'payment_id': const Uuid().v4(),
          'amount_paise': bill,
          'method': 'cash',
          'is_refund': false,
        },
      ),
    ], 'stale-device');
    expect(stalePay.single.status, 'rejected');
    expect(stalePay.single.error, 'overpayment');
    expect(await serverCount('payments', 'session_id', id), 1);
  }, skip: skip);

  test('turning a member off stops their device syncing; their unsent work '
      'stays on the device', () async {
    await b.sync();
    final staff = await (a.db.select(a.db.users)..where((t) => t.id.equals(b.userId)))
        .getSingle();
    var restored = false;
    Future<void> restoreStaff() async {
      if (restored) return;
      restored = true;
      await LocalUserRepository(a.db, a.clock, a.recorder).upsert(AppUser(
        id: staff.id,
        name: staff.name,
        perms: Permission.parse(staff.perms),
        active: true,
      ));
      expect((await a.sync()).rejected, 0);
    }

    addTearDown(restoreStaff);

    await LocalUserRepository(a.db, a.clock, a.recorder).upsert(AppUser(
      id: staff.id,
      name: staff.name,
      perms: Permission.parse(staff.perms),
      active: false,
    ));
    expect((await a.sync()).rejected, 0);
    await b.customers.createGuest();
    final r = await b.sync();
    expect(r.endedIn, SyncState.authProblem);
    expect(b.engine.status.accessRevoked, isTrue);
    expect((await b.outbox(OutboxStatus.pending)).length, 1,
        reason: 'nothing is thrown away');

    await restoreStaff();
  }, skip: skip);
}
