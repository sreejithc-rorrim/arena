/// One counter, one shift, on a real file — the acceptance test.
///
/// Everything here runs against a file-backed database through the same
/// providers the app uses, with no network of any kind, and the app is *closed
/// and reopened* in the middle to stand in for a power cut on the counter. What
/// is being checked is not that the screens render, but that the shift's money
/// and timings are still right afterwards.
library;

import 'dart:io';

import 'package:arena_ops/app/auth/auth_controller.dart';
import 'package:arena_ops/app/controllers/session_actions.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/db_safety.dart';
import 'package:arena_ops/data/local/seed_data.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/repositories/user_repository.dart';
import 'package:arena_ops/domain/services/session_timer.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/domain/reports/report_models.dart';
import 'package:arena_ops/features/reports/application/reports_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pricing_fixtures.dart';
import '../support/test_db.dart';

void main() {
  late Directory dir;
  late File dbFile;
  late Directory backupDir;

  // Friday 6:00 PM — open, standard rate band.
  final shiftStart = ist(2026, 10, 2, 18, 0);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('arena_ops_shift');
    dbFile = File('${dir.path}/arena_ops.sqlite');
    backupDir = Directory('${dir.path}/arena_ops-backups');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// Opens the app the way `main()` does: protect the file first, then open.
  Future<({AppDatabase db, DbProtectReport safety})> openApp() async {
    final safety = await DbSafety.protect(
      dbFile: dbFile,
      appSchemaVersion: AppDatabase.expectedSchemaVersion,
      backupDir: backupDir,
    );
    expect(safety.safeToOpen, isTrue, reason: safety.toString());
    final db = AppDatabase(NativeDatabase(dbFile));
    await LocalSeed.applyIfEmpty(db);
    return (db: db, safety: safety);
  }

  test('a full counter shift survives a restart with its money intact',
      () async {
    // ---- the counter boots for the first time ------------------------------
    var opened = await openApp();
    var db = opened.db;
    expect(opened.safety.outcome, DbProtectOutcome.freshInstall,
        reason: 'nothing to protect before the first run');

    final clock = FakeClock(shiftStart);
    var container = ProviderContainer(
      // The real PIN controller: this shift starts locked, like the device does.
      overrides: testOverrides(db, clock: clock, auth: AuthController.new),
    );

    // ---- staff signs in ----------------------------------------------------
    expect(container.read(authControllerProvider), isNull,
        reason: 'the app opens locked, with no one signed in');

    final wrong = await container
        .read(authControllerProvider.notifier)
        .signIn('u2', '9999');
    expect(wrong, isA<PinRejected>());
    expect(container.read(authControllerProvider), isNull);

    final signedIn = await container
        .read(authControllerProvider.notifier)
        .signIn('u2', '2222'); // seeded staff PIN
    expect(signedIn, isA<PinAccepted>());
    final staff = container.read(authControllerProvider)!;
    expect(staff.id, 'u2');
    expect(staff.name, isNotEmpty);
    expect(staff.isOwner, isFalse, reason: 'staff, not owner');

    // ---- a walk-in with no record: quick guest session ---------------------
    final guest = await container.read(customerRepositoryProvider).createGuest();
    expect(guest.isGuest, isTrue);
    expect(guest.displayName, 'Walk-in');

    var actions = container.read(sessionActionsProvider);

    // Game compatibility is enforced in the write path, not just the picker:
    // Tekken 8 is seeded `not_playable` on RIFT.
    final incompatible = await actions.start(NewSessionDraft(
      customerId: guest.id,
      activityCode: 'PS5',
      resourceId: 'rift',
      resourceName: 'RIFT',
      gameId: 'g_tekken8',
      controllerCount: 2,
      durationMinutes: 60,
    ));
    expect(incompatible.isErr, isTrue,
        reason: 'the staff app must not start an unplayable combination');
    expect(incompatible.failureOrNull!.code, 'not_playable');

    // Start properly: PS5, 2 controllers, 1 hour on HEX.
    final started = await actions.start(NewSessionDraft(
      customerId: guest.id,
      activityCode: 'PS5',
      resourceId: 'hex',
      resourceName: 'HEX',
      gameId: 'g_wwe',
      controllerCount: 2,
      durationMinutes: 60,
    ));
    expect(started.isOk, isTrue, reason: started.failureOrNull?.display);
    final sessionId = started.valueOrNull!.id;

    // Controller supply: HEX has pads, and the floor still owns all eight.
    final controllers = await container.read(catalogRepositoryProvider).controllers();
    expect(controllers.where((c) => c.status.isUsable).length, 8);

    // The station now reads as occupied.
    expect((await container.read(sessionRepositoryProvider).openSegments())
        .single
        .resourceId, 'hex');

    // ---- 20 minutes in, they move to VOID ---------------------------------
    clock.advance(const Duration(minutes: 20));
    final moved = await actions.switchSystem(
      session: started.valueOrNull!,
      current: (await container
              .read(sessionRepositoryProvider)
              .segmentsFor(sessionId))
          .single,
      resourceId: 'void',
      resourceName: 'VOID',
      activityCode: 'PS5',
      gameId: 'g_wwe',
      controllerCount: 2,
    );
    expect(moved.isOk, isTrue, reason: moved.failureOrNull?.display);

    var segments =
        await container.read(sessionRepositoryProvider).segmentsFor(sessionId);
    expect(segments, hasLength(2));
    expect(segments[0].endedAt, segments[1].startedAt,
        reason: 'no gap and no overlap across a station change');
    expect(segments.where((s) => s.isOpen), hasLength(1));

    // ---- a part payment at the counter ------------------------------------
    final part = await actions.recordPayment(RecordPaymentCommand(
      sessionId: sessionId,
      amountPaise: 10000,
      method: PaymentMethod.cash,
    ));
    expect(part.isOk, isTrue, reason: part.failureOrNull?.display);

    // ---- the counter loses power ------------------------------------------
    await db.close();
    container.dispose();

    // ---- it comes back up --------------------------------------------------
    opened = await openApp();
    db = opened.db;
    expect(opened.safety.outcome, DbProtectOutcome.backedUp,
            reason: 'the restart takes a verified backup of the shift so far')
        ;
    expect(opened.safety.rowCounts['sessions'], 1);
    expect(opened.safety.rowCounts['payments'], 1);
    expect(db.rebuiltFromVersion, 0, reason: 'a restart must not rebuild');

    container = ProviderContainer(
      overrides: testOverrides(db, clock: clock, auth: AuthController.new),
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    // Locked again: the PIN is required after every restart.
    expect(container.read(authControllerProvider), isNull);
    expect(
      await container.read(authControllerProvider.notifier).signIn('u2', '2222'),
      isA<PinAccepted>(),
      reason: 'the hashed PIN still verifies after a restart',
    );

    final repo = container.read(sessionRepositoryProvider);
    actions = container.read(sessionActionsProvider);

    // The session is still running, on the station it was moved to.
    final recovered = await repo.getById(sessionId);
    expect(recovered, isNotNull);
    expect(recovered!.status, SessionStatus.active);
    expect(recovered.startedAt, shiftStart,
        reason: 'timings come back from the stored timestamps, unchanged');
    expect(recovered.scheduledEndAt, shiftStart.add(const Duration(hours: 1)));
    expect((await repo.openSegments()).single.resourceId, 'void');
    expect((await repo.paymentsFor(sessionId)).single.amountPaise, 10000);

    // The timer is derived, not counted: it reflects the real elapsed time
    // across the outage rather than restarting from zero.
    final timer = SessionTimer(
      startedAt: recovered.startedAt,
      scheduledEndAt: recovered.scheduledEndAt,
      actualEndedAt: recovered.actualEndedAt,
    );
    final now = clock.now();
    expect(timer.elapsed(now), const Duration(minutes: 20));
    expect(timer.remaining(now), const Duration(minutes: 40));
    expect(timer.isOvertime(now), isFalse);

    // ---- they ask for another half hour -----------------------------------
    segments = await repo.segmentsFor(sessionId);
    final extended = await actions.extend(recovered, segments, 30);
    expect(extended.isOk, isTrue, reason: extended.failureOrNull?.display);
    expect(extended.valueOrNull!.scheduledEndAt,
        shiftStart.add(const Duration(minutes: 90)));

    // ---- checkout ----------------------------------------------------------
    clock.advance(const Duration(minutes: 70)); // 90 minutes played in total
    final atEnd = (await repo.getById(sessionId))!;
    segments = await repo.segmentsFor(sessionId);
    final bill = actions.endSummary(atEnd, segments);
    expect(bill.unpriced, isEmpty,
        reason: 'every segment must be priced, or the bill is short');
    expect(bill.total.value, greaterThan(0));

    final ended = await actions.end(atEnd, segments);
    expect(ended.isOk, isTrue, reason: ended.failureOrNull?.display);
    expect((await repo.getById(sessionId))!.status, SessionStatus.completed);
    expect((await repo.getById(sessionId))!.paymentStatus,
        PaymentStatus.partial,
        reason: 'only 100.00 of the bill has been taken so far');

    // Settle the rest across a second method.
    final remainder = bill.total.value - 10000;
    final settled = await actions.recordPayment(RecordPaymentCommand(
      sessionId: sessionId,
      amountPaise: remainder,
      method: PaymentMethod.upi,
    ));
    expect(settled.isOk, isTrue, reason: settled.failureOrNull?.display);
    expect((await repo.getById(sessionId))!.paymentStatus, PaymentStatus.paid);

    // The station is free again for the next customer.
    expect(await repo.openSegments(), isEmpty);

    // ---- the day's report --------------------------------------------------
    final summary = await container.read(reportForRangeProvider(
        ReportRange.today(IstDate.fromUtc(container.read(clockProvider).now()))).future);
    expect(summary.collectedPaise, bill.total.value,
        reason: 'takings are the payment rows, not a running tally');
    expect(summary.billedPaise, bill.total.value);
    expect(summary.sessionCount, 1);
    expect(summary.gamingMinutes, 90);

    // ---- and it is all still there on the next restart ---------------------
    await db.close();
    final reopened = await openApp();
    addTearDown(reopened.db.close);
    final finalRepo = ProviderContainer(
      overrides: testOverrides(reopened.db, clock: clock),
    );
    addTearDown(finalRepo.dispose);
    final persisted =
        await finalRepo.read(sessionRepositoryProvider).getById(sessionId);
    expect(persisted!.status, SessionStatus.completed);
    expect(persisted.billedAmountPaise, bill.total.value);
    expect(
      (await finalRepo.read(sessionRepositoryProvider).paymentsFor(sessionId))
          .fold<int>(0, (a, p) => a + p.amountPaise),
      bill.total.value,
      reason: 'the shift balances after two restarts',
    );
  });
}
