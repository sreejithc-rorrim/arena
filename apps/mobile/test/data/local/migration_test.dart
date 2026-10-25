/// Schema migrations: every step must carry the centre's records forward.
///
/// Each case builds a database in the *old* shape, writes real business rows
/// into it, then opens it with the current [AppDatabase] and asserts that the
/// rows are still there and still correct.
library;

import 'dart:convert';
import 'dart:io';

import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_catalog_repository.dart';
import 'package:arena_ops/data/local/local_controller_allocation_repository.dart';
import 'package:arena_ops/data/local/local_customer_repository.dart';
import 'package:arena_ops/data/local/local_session_repository.dart';
import 'package:arena_ops/data/local/local_user_repository.dart';
import 'package:arena_ops/data/local/seed_data.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/repositories/user_repository.dart';
import 'package:arena_ops/domain/services/segment_billing.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory dir;
  late File file;
  final start = DateTime.utc(2026, 10, 10, 9);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('arena_ops_migration');
    file = File('${dir.path}/arena.sqlite');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// Reverses v17 -> v18 on a file the current AppDatabase built: the old
  /// one-value `player_mode` column instead of `play_modes`.
  void undoV18(Database raw) {
    raw.execute(
        "ALTER TABLE games ADD COLUMN player_mode TEXT NOT NULL DEFAULT 'single'");
    raw.execute('ALTER TABLE games DROP COLUMN play_modes');
  }

  /// Reverses v16 -> v17 and v17 -> v18: every fixture older than v17 is the
  /// current schema minus these (and its own later additions).
  void undoV17AndV18(Database raw) {
    undoV18(raw);
    raw.execute('ALTER TABLE activities DROP COLUMN overtime_grace_minutes');
  }

  /// One completed, billed and paid hour on HEX, for the v16 / v17 fixtures.
  Future<String> paidHour(AppDatabase db) async {
    final sessions = LocalSessionRepository(db);
    final who = await LocalCustomerRepository(db).create(name: 'Isha');
    final snapshot = await LocalCatalogRepository(db).currentSnapshot();
    final started = await sessions.start(StartSessionCommand(
      customerId: who.id,
      startedAt: start,
      scheduledEndAt: start.add(const Duration(hours: 1)),
      snapshot: snapshot,
      resourceId: 'hex',
      resourceName: 'HEX',
      activityCode: 'PS5',
      controllerCount: 1,
    ));
    final id = started.valueOrNull!.id;
    final bill = const SegmentBilling().bill(
      snapshot: snapshot,
      segments: await sessions.segmentsFor(id),
      openEndAt: start.add(const Duration(hours: 1)),
      sessionStart: start,
    );
    final ended = await sessions.end(EndSessionCommand(
      sessionId: id,
      actualEndedAt: start.add(const Duration(hours: 1)),
      billedAmountPaise: bill.total.value,
      charges: bill.charges,
    ));
    expect(ended.isOk, isTrue, reason: ended.failureOrNull?.display);
    await sessions.recordPayment(RecordPaymentCommand(
      sessionId: id,
      amountPaise: bill.total.value,
      method: PaymentMethod.cash,
    ));
    return id;
  }

  /// Builds a genuine **v10** database holding one session, one segment and one
  /// payment, plus two staff accounts with plaintext PINs.
  ///
  /// v11's only schema change is to `users`, so a faithful v10 file is the
  /// current schema with exactly that change reversed: the plaintext `pin`
  /// column back, the salt/hash/lockout columns gone, `user_version` at 10.
  Future<String> buildV10Database() async {
    final db = AppDatabase(NativeDatabase(file));
    await LocalSeed.apply(db);
    final catalog = LocalCatalogRepository(db);
    final customers = LocalCustomerRepository(db);
    final sessions = LocalSessionRepository(db);
    final snapshot = await catalog.currentSnapshot();
    final who = await customers.create(name: 'Ravi');
    final started = await sessions.start(StartSessionCommand(
      customerId: who.id,
      startedAt: start,
      scheduledEndAt: start.add(const Duration(hours: 1)),
      snapshot: snapshot,
      resourceId: 'hex',
      resourceName: 'HEX',
      activityCode: 'PS5',
      controllerCount: 2,
    ));
    final sessionId = started.valueOrNull!.id;
    await sessions.recordPayment(RecordPaymentCommand(
      sessionId: sessionId,
      amountPaise: 60700,
      method: PaymentMethod.cash,
    ));
    await db.close();

    // Reverse the v11 users change.
    final raw = sqlite3.open(file.path);
    raw.execute('ALTER TABLE users ADD COLUMN pin TEXT NOT NULL DEFAULT ""');
    raw.execute("UPDATE users SET pin = '1111' WHERE id = 'u1'");
    raw.execute("UPDATE users SET pin = '2222' WHERE id = 'u2'");
    for (final column in const [
      'pin_salt',
      'pin_hash',
      'pin_iterations',
      'failed_attempts',
      'locked_until_at',
    ]) {
      raw.execute('ALTER TABLE users DROP COLUMN $column');
    }
    // Reverse the v11 -> v12 additions too, so the fixture is a faithful v10
    // file (the current AppDatabase builds the v12 shape via createAll).
    raw.execute('DROP TABLE IF EXISTS controller_moves');
    raw.execute('DROP TABLE IF EXISTS controller_allocations');
    raw.execute('ALTER TABLE resources DROP COLUMN current_mode');
    raw.execute('DROP TABLE IF EXISTS sync_outbox');
    raw.execute('DROP TABLE IF EXISTS sync_meta');
    raw.execute('DROP TABLE IF EXISTS sync_versions');
    // customers.birth_year arrived in v15, pricing_rules in v16.
    raw.execute('ALTER TABLE customers DROP COLUMN birth_year');
    raw.execute('DROP TABLE IF EXISTS pricing_rules');
    undoV17AndV18(raw);
    raw.execute('PRAGMA user_version = 10');
    raw.close();
    return sessionId;
  }

  test('the v10 fixture really is at v10, with a plaintext PIN column', () async {
    await buildV10Database();
    final raw = sqlite3.open(file.path);
    expect(raw.userVersion, 10);
    final columns = raw
        .select("SELECT name FROM pragma_table_info('users')")
        .map((r) => '${r['name']}')
        .toSet();
    expect(columns, contains('pin'));
    expect(columns, isNot(contains('pin_hash')));
    expect(
      raw.select("SELECT pin FROM users WHERE id = 'u1'").first['pin'],
      '1111',
      reason: 'the fixture must reproduce the flaw the migration fixes',
    );
    raw.close();
  });

  group('v10 -> v11 (PINs stop being stored in the clear)', () {
    test('sessions, segments and payments survive the migration', () async {
      final sessionId = await buildV10Database();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final sessions = LocalSessionRepository(db);

      expect(db.rebuiltFromVersion, 0,
          reason: 'this must be a sequential step, not a rebuild');

      final reloaded = await sessions.getById(sessionId);
      expect(reloaded, isNotNull);
      expect(reloaded!.startedAt, start);
      expect(reloaded.scheduledEndAt, start.add(const Duration(hours: 1)));
      expect(reloaded.status, SessionStatus.active);
      expect((await sessions.paymentsFor(sessionId)).single.amountPaise, 60700);
      final segment = (await sessions.segmentsFor(sessionId)).single;
      expect(segment.resourceId, 'hex');
      expect(segment.controllerCount, 2);
      // The floor still shows the station as occupied after the upgrade.
      expect((await sessions.openSegments()).single.resourceId, 'hex');
    });

    test('the PINs staff already know keep working, now hashed', () async {
      await buildV10Database();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final users = LocalUserRepository(db);

      // Converted in place, not reset: staff are not locked out by an upgrade.
      expect(await users.verify('u1', '1111'), isA<PinAccepted>());
      expect(await users.verify('u2', '2222'), isA<PinAccepted>());
      expect(await users.verify('u1', '2222'), isA<PinRejected>());
    });

    test('no plaintext PIN is left anywhere in the file', () async {
      await buildV10Database();

      final db = AppDatabase(NativeDatabase(file));
      final users = LocalUserRepository(db);
      expect(await users.verify('u1', '1111'), isA<PinAccepted>());
      await db.close();

      final raw = sqlite3.open(file.path);
      final columns = raw
          .select("SELECT name FROM pragma_table_info('users')")
          .map((r) => '${r['name']}')
          .toSet();
      expect(columns, isNot(contains('pin')));
      expect(columns, containsAll(<String>[
        'pin_salt',
        'pin_hash',
        'pin_iterations',
        'failed_attempts',
        'locked_until_at',
      ]));
      expect(raw.userVersion, AppDatabase.expectedSchemaVersion);
      raw.close();

      // Dropping the column frees its pages but leaves the bytes behind, so the
      // migration also VACUUMs. Check the raw file, not just the schema.
      final vacuumed = sqlite3.open(file.path);
      expect(vacuumed.select('PRAGMA freelist_count').first.values.first, 0,
          reason: 'VACUUM ran: no free pages that could hold the old column');
      // Live values that vary run to run must not be mistaken for a leftover
      // PIN: wall-clock timestamps (microseconds like ".791111Z" made this test
      // fail ~1 run in 200), UUIDs, and the random base64 salts/hashes. Remove
      // them first; anything matching after that is a genuine leftover.
      final secrets = [
        for (final r in vacuumed.select('SELECT pin_salt, pin_hash FROM users'))
          for (final v in r.values)
            if (v is String && v.isNotEmpty) v,
      ];
      vacuumed.close();
      final bytes = await file.readAsBytes();
      var haystack = String.fromCharCodes(bytes)
          .replaceAll(
              RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z?'), '')
          .replaceAll(
              RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-'
                  r'[0-9a-f]{12}'),
              '');
      for (final s in secrets) {
        haystack = haystack.replaceAll(s, '');
      }
      for (final pin in const ['1111', '2222']) {
        expect(haystack.contains(pin), isFalse,
            reason: 'the old plaintext PIN $pin is still readable in the file');
      }
    });

    test('the catalog and customers are untouched', () async {
      await buildV10Database();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final snapshot = await LocalCatalogRepository(db).currentSnapshot();
      expect(snapshot.activities, isNotEmpty);
      expect(snapshot.rates, isNotEmpty);
      final customers = await LocalCustomerRepository(db).search('Ravi');
      expect(customers.map((c) => c.name), contains('Ravi'));
    });
  });

  test('migrating twice is a no-op (the app reopens cleanly)', () async {
    final sessionId = await buildV10Database();

    var db = AppDatabase(NativeDatabase(file));
    expect(await LocalSessionRepository(db).getById(sessionId), isNotNull);
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(db.rebuiltFromVersion, 0);
    expect(await LocalSessionRepository(db).getById(sessionId), isNotNull);
    expect(await LocalUserRepository(db).verify('u1', '1111'),
        isA<PinAccepted>());
  });

  /// Builds a genuine v11 database (the current shape minus the v12 additions)
  /// holding one session, segment and payment, stamped user_version 11.
  Future<String> buildV11Database() async {
    final db = AppDatabase(NativeDatabase(file));
    await LocalSeed.apply(db);
    final catalog = LocalCatalogRepository(db);
    final customers = LocalCustomerRepository(db);
    final sessions = LocalSessionRepository(db);
    final snapshot = await catalog.currentSnapshot();
    final who = await customers.create(name: 'Meera');
    final started = await sessions.start(StartSessionCommand(
      customerId: who.id,
      startedAt: start,
      scheduledEndAt: start.add(const Duration(hours: 1)),
      snapshot: snapshot,
      resourceId: 'hex',
      resourceName: 'HEX',
      activityCode: 'PS5',
      controllerCount: 2,
    ));
    final sessionId = started.valueOrNull!.id;
    await sessions.recordPayment(RecordPaymentCommand(
      sessionId: sessionId,
      amountPaise: 28000,
      method: PaymentMethod.cash,
    ));
    await db.close();

    // Reverse the v11 -> v12 additions, stamp v11.
    final raw = sqlite3.open(file.path);
    raw.execute('DROP TABLE IF EXISTS controller_moves');
    raw.execute('DROP TABLE IF EXISTS controller_allocations');
    raw.execute('ALTER TABLE resources DROP COLUMN current_mode');
    raw.execute('DROP TABLE IF EXISTS sync_outbox');
    raw.execute('DROP TABLE IF EXISTS sync_meta');
    raw.execute('DROP TABLE IF EXISTS sync_versions');
    // customers.birth_year arrived in v15, pricing_rules in v16.
    raw.execute('ALTER TABLE customers DROP COLUMN birth_year');
    raw.execute('DROP TABLE IF EXISTS pricing_rules');
    undoV17AndV18(raw);
    raw.execute('PRAGMA user_version = 11');
    raw.close();
    return sessionId;
  }

  group('v11 -> v12 (physical controller allocation)', () {
    test('the v11 fixture is at v11 without the controller_allocations table',
        () async {
      await buildV11Database();
      final raw = sqlite3.open(file.path);
      expect(raw.userVersion, 11);
      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r) => '${r['name']}')
          .toSet();
      expect(tables, isNot(contains('controller_allocations')));
      raw.close();
    });

    test('sessions, segments and payments survive, and the new table appears',
        () async {
      final sessionId = await buildV11Database();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final sessions = LocalSessionRepository(db);
      expect(db.rebuiltFromVersion, 0,
          reason: 'this must be a sequential step, not a rebuild');

      final reloaded = await sessions.getById(sessionId);
      expect(reloaded, isNotNull);
      expect(reloaded!.startedAt, start);
      expect((await sessions.paymentsFor(sessionId)).single.amountPaise, 28000);
      expect((await sessions.segmentsFor(sessionId)).single.resourceId, 'hex');

      final check = sqlite3.open(file.path);
      final tables = check
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r) => '${r['name']}')
          .toSet();
      expect(tables, contains('controller_allocations'));
      final resourceCols = check
          .select("SELECT name FROM pragma_table_info('resources')")
          .map((r) => '${r['name']}')
          .toSet();
      expect(resourceCols, contains('current_mode'));
      final idx = check
          .select("SELECT name FROM sqlite_master WHERE type='index' "
              "AND name='ux_one_open_allocation_per_controller'")
          .map((r) => '${r['name']}')
          .toSet();
      expect(idx, contains('ux_one_open_allocation_per_controller'),
          reason: 'the double-allocation guard survives the migration');
      check.close();
    });

    test('migrating twice is a no-op', () async {
      final sessionId = await buildV11Database();
      var db = AppDatabase(NativeDatabase(file));
      expect(await LocalSessionRepository(db).getById(sessionId), isNotNull);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0);
      expect(await LocalSessionRepository(db).getById(sessionId), isNotNull);
    });
  });

  /// A genuine v12 database: the current shape minus `controller_moves`, with
  /// a live session that holds two TRACKED pads (allocations) and a pad that
  /// an owner moved before the location history existed.
  Future<String> buildV12Database() async {
    final db = AppDatabase(NativeDatabase(file));
    await LocalSeed.apply(db);
    final catalog = LocalCatalogRepository(db);
    final sessions = LocalSessionRepository(db);
    final who = await LocalCustomerRepository(db).create(name: 'Anu');
    final started = await sessions.start(StartSessionCommand(
      customerId: who.id,
      startedAt: start,
      scheduledEndAt: start.add(const Duration(hours: 1)),
      snapshot: await catalog.currentSnapshot(),
      resourceId: 'hex',
      resourceName: 'HEX',
      activityCode: 'PS5',
      controllerCount: 2,
      controllerIds: ['ctl_hex_1', 'ctl_hex_2'],
    ));
    await sessions.recordPayment(RecordPaymentCommand(
      sessionId: started.valueOrNull!.id,
      amountPaise: 28000,
      method: PaymentMethod.upi,
    ));
    // A pad relocated under v12: only its location columns record it.
    await (db.update(db.controllers)..where((t) => t.id.equals('ctl_void_1')))
        .write(const ControllersCompanion(
      currentResourceId: Value('ghost'),
      loanReturnTo: Value('void'),
    ));
    await db.close();
    final raw = sqlite3.open(file.path);
    raw.execute('DROP TABLE IF EXISTS controller_moves');
    raw.execute('DROP TABLE IF EXISTS sync_outbox');
    raw.execute('DROP TABLE IF EXISTS sync_meta');
    raw.execute('DROP TABLE IF EXISTS sync_versions');
    // customers.birth_year arrived in v15, pricing_rules in v16.
    raw.execute('ALTER TABLE customers DROP COLUMN birth_year');
    raw.execute('DROP TABLE IF EXISTS pricing_rules');
    undoV17AndV18(raw);
    raw.execute('PRAGMA user_version = 12');
    raw.close();
    return started.valueOrNull!.id;
  }

  group('v12 -> v13 (controller location history)', () {
    test('live sessions, their tracked pads and pad locations survive; the '
        'history table appears empty and works', () async {
      final sessionId = await buildV12Database();
      final before = sqlite3.open(file.path);
      expect(before.userVersion, 12);
      expect(
          before
              .select(
                  "SELECT name FROM sqlite_master WHERE name='controller_moves'")
              .isEmpty,
          isTrue);
      before.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0, reason: 'sequential, not a rebuild');
      final s = await LocalSessionRepository(db).getById(sessionId);
      expect(s, isNotNull);
      expect(s!.isActive, isTrue);
      final sessions = LocalSessionRepository(db);
      expect((await sessions.segmentsFor(sessionId)).single.controllerCount, 2);
      expect((await sessions.paymentsFor(sessionId)).single.amountPaise, 28000);
      final alloc = LocalControllerAllocationRepository(db);
      expect({for (final a in await alloc.openPadAllocations()) a.controllerId},
          {'ctl_hex_1', 'ctl_hex_2'},
          reason: 'pads held by a running session stay held');
      final void1 = (await LocalCatalogRepository(db).controllers())
          .firstWhere((c) => c.id == 'ctl_void_1');
      expect(void1.currentResourceId, 'ghost');
      expect(void1.loanReturnTo, 'void');
      expect(await alloc.movesForController('ctl_void_1'), isEmpty);

      // The new history records from now on.
      await alloc.moveController(
          controllerId: 'ctl_void_1',
          toResourceId: 'void',
          kind: ControllerMoveKind.returnHome);
      final moves = await alloc.movesForController('ctl_void_1');
      expect(moves.single.fromResourceId, 'ghost');
      expect(moves.single.toResourceId, 'void');

      final check = sqlite3.open(file.path);
      expect(check.userVersion, AppDatabase.expectedSchemaVersion);
      expect(
          check
              .select("SELECT name FROM sqlite_master WHERE type='index' "
                  "AND name='ix_moves_controller'")
              .isNotEmpty,
          isTrue);
      check.close();
    });
  });

  /// A genuine v13 database: the current shape minus the sync tables, with a
  /// live session holding a tracked pad, a borrow in the location history, a
  /// payment, and a completed session.
  Future<String> buildV13Database() async {
    final db = AppDatabase(NativeDatabase(file));
    await LocalSeed.apply(db);
    final catalog = LocalCatalogRepository(db);
    final sessions = LocalSessionRepository(db);
    final who = await LocalCustomerRepository(db).create(name: 'Dev');
    final started = await sessions.start(StartSessionCommand(
      customerId: who.id,
      startedAt: start,
      scheduledEndAt: start.add(const Duration(hours: 1)),
      snapshot: await catalog.currentSnapshot(),
      resourceId: 'void',
      resourceName: 'VOID',
      activityCode: 'PS5',
      controllerCount: 3,
      controllerIds: ['ctl_void_1', 'ctl_void_2', 'ctl_ghost_1'],
      borrowControllerIds: ['ctl_ghost_1'],
    ));
    await sessions.recordPayment(RecordPaymentCommand(
      sessionId: started.valueOrNull!.id,
      amountPaise: 39000,
      method: PaymentMethod.cash,
    ));
    await db.close();
    final raw = sqlite3.open(file.path);
    raw.execute('DROP TABLE IF EXISTS sync_outbox');
    raw.execute('DROP TABLE IF EXISTS sync_meta');
    raw.execute('DROP TABLE IF EXISTS sync_versions');
    // customers.birth_year arrived in v15, pricing_rules in v16.
    raw.execute('ALTER TABLE customers DROP COLUMN birth_year');
    raw.execute('DROP TABLE IF EXISTS pricing_rules');
    undoV17AndV18(raw);
    raw.execute('PRAGMA user_version = 13');
    raw.close();
    return started.valueOrNull!.id;
  }

  group('v13 -> v14 (cloud sync bookkeeping)', () {
    test('sessions, pads, moves and payments survive; the sync tables appear '
        'empty; local-only mode records nothing', () async {
      final sessionId = await buildV13Database();
      final before = sqlite3.open(file.path);
      expect(before.userVersion, 13);
      expect(
          before
              .select("SELECT name FROM sqlite_master WHERE name='sync_outbox'")
              .isEmpty,
          isTrue);
      before.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0, reason: 'sequential, not a rebuild');
      final sessions = LocalSessionRepository(db);
      final s = await sessions.getById(sessionId);
      expect(s!.isActive, isTrue);
      expect((await sessions.paymentsFor(sessionId)).single.amountPaise, 39000);
      final alloc = LocalControllerAllocationRepository(db);
      expect({for (final a in await alloc.openPadAllocations()) a.controllerId},
          {'ctl_void_1', 'ctl_void_2', 'ctl_ghost_1'});
      expect((await alloc.movesForController('ctl_ghost_1')).single.toResourceId,
          'void');

      // Local-only repositories have no recorder: the outbox stays empty.
      await sessions.recordPayment(RecordPaymentCommand(
        sessionId: sessionId,
        amountPaise: 100,
        method: PaymentMethod.upi,
      ));
      expect(await db.select(db.syncOutbox).get(), isEmpty);
      expect(await db.select(db.syncMeta).get(), isEmpty);

      final check = sqlite3.open(file.path);
      expect(check.userVersion, AppDatabase.expectedSchemaVersion);
      expect(
          check
              .select("SELECT name FROM sqlite_master WHERE type='index' "
                  "AND name='ix_outbox_status'")
              .isNotEmpty,
          isTrue);
      check.close();
    });

    test('migrating twice is a no-op', () async {
      final sessionId = await buildV13Database();
      var db = AppDatabase(NativeDatabase(file));
      expect(await LocalSessionRepository(db).getById(sessionId), isNotNull);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0);
      expect(await LocalSessionRepository(db).getById(sessionId), isNotNull);
    });
  });

  /// A genuine v14 database: the current shape without customers.birth_year,
  /// holding a member and a live session with a payment.
  Future<({String sessionId, String customerId})> buildV14Database() async {
    final db = AppDatabase(NativeDatabase(file));
    await LocalSeed.apply(db);
    final catalog = LocalCatalogRepository(db);
    final sessions = LocalSessionRepository(db);
    final who = await LocalCustomerRepository(db)
        .create(name: 'Dev', phone: '9845012873');
    final started = await sessions.start(StartSessionCommand(
      customerId: who.id,
      startedAt: start,
      scheduledEndAt: start.add(const Duration(hours: 1)),
      snapshot: await catalog.currentSnapshot(),
      resourceId: 'void',
      resourceName: 'VOID',
      activityCode: 'PS5',
      controllerCount: 2,
      controllerIds: ['ctl_void_1', 'ctl_void_2'],
    ));
    await sessions.recordPayment(RecordPaymentCommand(
      sessionId: started.valueOrNull!.id,
      amountPaise: 26000,
      method: PaymentMethod.upi,
    ));
    await db.close();
    final raw = sqlite3.open(file.path);
    raw.execute('ALTER TABLE customers DROP COLUMN birth_year');
    raw.execute('DROP TABLE IF EXISTS pricing_rules');
    undoV17AndV18(raw);
    raw.execute('PRAGMA user_version = 14');
    raw.close();
    return (sessionId: started.valueOrNull!.id, customerId: who.id);
  }

  group('v14 -> v15 (member birth year)', () {
    test('customers, sessions and payments survive; birth year reads as not '
        'given', () async {
      final ids = await buildV14Database();
      final before = sqlite3.open(file.path);
      expect(before.userVersion, 14);
      expect(
          before
              .select("SELECT name FROM pragma_table_info('customers') "
                  "WHERE name='birth_year'")
              .isEmpty,
          isTrue);
      before.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0, reason: 'sequential, not a rebuild');
      final customers = LocalCustomerRepository(db);
      final dev = await customers.getById(ids.customerId);
      expect(dev!.name, 'Dev');
      expect(dev.phone, '9845012873');
      expect(dev.birthYear, isNull);
      final sessions = LocalSessionRepository(db);
      expect((await sessions.getById(ids.sessionId))!.isActive, isTrue);
      expect(
          (await sessions.paymentsFor(ids.sessionId)).single.amountPaise, 26000);

      // The new column is writable straight away.
      final saved = await customers.update(dev.copyWith(birthYear: 2001));
      expect(saved.birthYear, 2001);
      final made = await customers.create(name: 'Diya', birthYear: 2009);
      expect((await customers.getById(made.id))!.birthYear, 2009);

      final check = sqlite3.open(file.path);
      expect(check.userVersion, AppDatabase.expectedSchemaVersion);
      check.close();
    });

    test('migrating twice is a no-op', () async {
      final ids = await buildV14Database();
      var db = AppDatabase(NativeDatabase(file));
      expect(
          await LocalCustomerRepository(db).getById(ids.customerId), isNotNull);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0);
      expect(
          await LocalCustomerRepository(db).getById(ids.customerId), isNotNull);
    });
  });

  /// A genuine v15 database: the current shape without `pricing_rules`, with a
  /// cloud pull cursor, a rate row of a retired band, a live session whose
  /// frozen snapshot was written by an older build (extra keys, a retired-band
  /// rate), and a completed session with its charge row and payment.
  Future<({String live, String done})> buildV15Database() async {
    final db = AppDatabase(NativeDatabase(file));
    await LocalSeed.apply(db);
    final catalog = LocalCatalogRepository(db);
    final sessions = LocalSessionRepository(db);
    final who = await LocalCustomerRepository(db).create(name: 'Isha');
    final snapshot = await catalog.currentSnapshot();
    // A completed hour on HEX, billed and paid.
    final doneStart = await sessions.start(StartSessionCommand(
      customerId: who.id,
      startedAt: start,
      scheduledEndAt: start.add(const Duration(hours: 1)),
      snapshot: snapshot,
      resourceId: 'hex',
      resourceName: 'HEX',
      activityCode: 'PS5',
      controllerCount: 1,
    ));
    final doneId = doneStart.valueOrNull!.id;
    final doneBill = const SegmentBilling().bill(
      snapshot: snapshot,
      segments: await sessions.segmentsFor(doneId),
      openEndAt: start.add(const Duration(hours: 1)),
      sessionStart: start,
    );
    final ended = await sessions.end(EndSessionCommand(
      sessionId: doneId,
      actualEndedAt: start.add(const Duration(hours: 1)),
      billedAmountPaise: doneBill.total.value,
      charges: doneBill.charges,
    ));
    expect(ended.isOk, isTrue, reason: ended.failureOrNull?.display);
    await sessions.recordPayment(RecordPaymentCommand(
      sessionId: doneId,
      amountPaise: 15000,
      method: PaymentMethod.cash,
    ));
    // A live session on VOID.
    final live = await sessions.start(StartSessionCommand(
      customerId: who.id,
      startedAt: start.add(const Duration(hours: 2)),
      scheduledEndAt: start.add(const Duration(hours: 3)),
      snapshot: snapshot,
      resourceId: 'void',
      resourceName: 'VOID',
      activityCode: 'PS5',
      controllerCount: 2,
    ));
    final liveId = live.valueOrNull!.id;
    await sessions.recordPayment(RecordPaymentCommand(
      sessionId: liveId,
      amountPaise: 28000,
      method: PaymentMethod.upi,
    ));
    await db.close();

    // Builds before v16 froze no rules.
    final legacy = snapshot.toJson()..remove('rules');
    for (final a in legacy['activities'] as List) {
      (a as Map<String, dynamic>)['retired_flag'] = true;
    }
    (legacy['hours'] as Map<String, dynamic>)['retired_window'] = <String, dynamic>{};
    (legacy['rates'] as List).add({
      'activity_code': 'PS5', 'band': 'retired_band', 'controller_count': 2,
      'unit_minutes': 60, 'price_paise': 1,
    });
    final raw = sqlite3.open(file.path);
    raw.execute('UPDATE sessions SET pricing_snapshot = ? WHERE id = ?',
        [jsonEncode(legacy), liveId]);
    raw.execute("INSERT INTO rates (id, activity_code, band, controller_count, "
        "unit_minutes, price_paise) VALUES ('ps5_2_old', 'PS5', 'retired_band', 2, 60, 1)");
    raw.execute("INSERT INTO sync_meta (key, value) VALUES ('pull_cursor', '98765')");
    raw.execute('DROP TABLE IF EXISTS pricing_rules');
    undoV17AndV18(raw);
    raw.execute('PRAGMA user_version = 15');
    raw.close();
    return (live: liveId, done: doneId);
  }

  group('v15 -> v16 (pricing rules)', () {
    test('sessions, charges and payments survive; old snapshots still bill; the '
        'rules table appears and the pull cursor rewinds', () async {
      final ids = await buildV15Database();
      final before = sqlite3.open(file.path);
      expect(before.userVersion, 15);
      expect(
          before
              .select("SELECT name FROM sqlite_master WHERE name='pricing_rules'")
              .isEmpty,
          isTrue);
      before.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0, reason: 'sequential, not a rebuild');
      final sessions = LocalSessionRepository(db);

      final done = (await sessions.getById(ids.done))!;
      expect(done.billedAmountPaise, 15000);
      expect((await sessions.chargesFor(ids.done)).single.amountPaise, 15000);
      expect((await sessions.paymentsFor(ids.done)).single.amountPaise, 15000);

      final live = (await sessions.getById(ids.live))!;
      expect(live.isActive, isTrue);
      expect((await sessions.paymentsFor(ids.live)).single.amountPaise, 28000);
      final segs = await sessions.segmentsFor(ids.live);
      expect(segs.single.resourceId, 'void');
      // The older snapshot parses; its retired-band rate is never priced.
      expect(live.snapshot.rules, isEmpty);
      final bill = const SegmentBilling().bill(
        snapshot: live.snapshot,
        segments: segs,
        openEndAt: live.startedAt.add(const Duration(hours: 1)),
        sessionStart: live.startedAt,
      );
      expect(bill.total.value, 28000);

      // The retired rate row stays in the table but not in new snapshots.
      final snap = await LocalCatalogRepository(db).currentSnapshot();
      expect(snap.rates.every((r) => r.band == Band.standard), isTrue);
      expect(snap.rules, isEmpty);
      expect(snap.toJson().containsKey('rules'), isFalse);
      expect((await db.select(db.rates).get()).map((r) => r.id), contains('ps5_2_old'));

      // A synced rule lands in the new table and in the next snapshot.
      await db.into(db.pricingRules).insert(PricingRulesCompanion.insert(
            id: 'r1',
            name: 'Weekday afternoons',
            days: const [2, 3, 4, 5],
            startMin: 840,
            endMin: 1020,
            activityCodes: const ['PS5'],
            adjustKind: 'percent',
            adjustValue: -20,
          ));
      expect((await LocalCatalogRepository(db).currentSnapshot()).rules.single.id, 'r1');

      // Activities still insert into the old table shape (retired column).
      await db.into(db.activities).insert(ActivitiesCompanion.insert(
            id: 'darts',
            code: 'DARTS',
            name: 'Darts',
            usesControllers: false,
            usesGames: false,
            durationModel: 'hourly',
          ));

      final cursor = await (db.select(db.syncMeta)
            ..where((t) => t.key.equals('pull_cursor')))
          .getSingle();
      expect(cursor.value, '0', reason: 'the next pull re-reads the rules');
      final check = sqlite3.open(file.path);
      expect(check.userVersion, AppDatabase.expectedSchemaVersion);
      check.close();
    });

    test('migrating twice is a no-op', () async {
      final ids = await buildV15Database();
      var db = AppDatabase(NativeDatabase(file));
      expect(await LocalSessionRepository(db).getById(ids.live), isNotNull);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0);
      expect(await LocalSessionRepository(db).getById(ids.done), isNotNull);
    });
  });

  /// A genuine v16 database: no overtime grace, the old `player_mode`, a cloud
  /// pull cursor and one paid session.
  Future<String> buildV16Database() async {
    final db = AppDatabase(NativeDatabase(file));
    await LocalSeed.apply(db);
    final id = await paidHour(db);
    await db.close();
    final raw = sqlite3.open(file.path);
    raw.execute("INSERT INTO sync_meta (key, value) VALUES ('pull_cursor', '98765')");
    undoV17AndV18(raw);
    raw.execute('PRAGMA user_version = 16');
    raw.close();
    return id;
  }

  group('v16 -> v17 (overtime grace)', () {
    test('the session, charge and payment survive; every type gets 0 grace; '
        'the pull cursor rewinds', () async {
      final id = await buildV16Database();
      final before = sqlite3.open(file.path);
      expect(before.userVersion, 16);
      expect(
          before
              .select("SELECT 1 FROM pragma_table_info('activities') "
                  "WHERE name = 'overtime_grace_minutes'")
              .isEmpty,
          isTrue);
      before.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0, reason: 'sequential, not a rebuild');
      final sessions = LocalSessionRepository(db);
      final done = (await sessions.getById(id))!;
      expect((await sessions.chargesFor(id)).single.amountPaise, done.billedAmountPaise);
      expect((await sessions.paymentsFor(id)).single.amountPaise, done.billedAmountPaise);
      final types = await db.select(db.activities).get();
      expect(types, isNotEmpty);
      expect(types.every((a) => a.overtimeGraceMinutes == 0), isTrue);
      final cursor = await (db.select(db.syncMeta)
            ..where((t) => t.key.equals('pull_cursor')))
          .getSingle();
      expect(cursor.value, '0', reason: 'the next pull re-reads the grace');
      final check = sqlite3.open(file.path);
      expect(check.userVersion, AppDatabase.expectedSchemaVersion);
      check.close();
    });

    test('migrating twice is a no-op', () async {
      final id = await buildV16Database();
      var db = AppDatabase(NativeDatabase(file));
      expect(await LocalSessionRepository(db).getById(id), isNotNull);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0);
      expect(await LocalSessionRepository(db).getById(id), isNotNull);
    });
  });

  /// A genuine v17 database: one `player_mode` per game (one game of each
  /// value), a set overtime grace and one paid session.
  Future<String> buildV17Database() async {
    final db = AppDatabase(NativeDatabase(file));
    await LocalSeed.apply(db);
    final id = await paidHour(db);
    for (final g in ['m_single', 'm_local', 'm_online', 'm_both']) {
      await db.into(db.games).insert(GamesCompanion.insert(
            id: g,
            name: g,
            aliases: const [],
            platforms: const ['PS5'],
          ));
    }
    await db.close();
    final raw = sqlite3.open(file.path);
    undoV18(raw);
    for (final m in ['single', 'local', 'online', 'both']) {
      raw.execute('UPDATE games SET player_mode = ? WHERE id = ?', [m, 'm_$m']);
    }
    raw.execute("UPDATE activities SET overtime_grace_minutes = 5 WHERE code = 'PS5'");
    raw.execute("INSERT INTO sync_meta (key, value) VALUES ('pull_cursor', '98765')");
    raw.execute('PRAGMA user_version = 17');
    raw.close();
    return id;
  }

  group('v17 -> v18 (play modes)', () {
    test('each player mode becomes its play modes and the old column goes; '
        'sessions, payments, grace and the pull cursor are untouched', () async {
      final id = await buildV17Database();
      final before = sqlite3.open(file.path);
      expect(before.userVersion, 17);
      before.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0, reason: 'sequential, not a rebuild');
      Future<List<String>> modes(String g) async =>
          (await (db.select(db.games)..where((t) => t.id.equals(g))).getSingle())
              .playModes;
      expect(await modes('m_single'), ['single']);
      expect(await modes('m_local'), ['local']);
      expect(await modes('m_online'), ['online']);
      expect(await modes('m_both'), ['local', 'online']);

      final sessions = LocalSessionRepository(db);
      final done = (await sessions.getById(id))!;
      expect((await sessions.paymentsFor(id)).single.amountPaise, done.billedAmountPaise);
      final ps5 = await (db.select(db.activities)
            ..where((t) => t.code.equals('PS5')))
          .getSingle();
      expect(ps5.overtimeGraceMinutes, 5);
      final cursor = await (db.select(db.syncMeta)
            ..where((t) => t.key.equals('pull_cursor')))
          .getSingle();
      expect(cursor.value, '98765', reason: 'catalog-only step, no re-read');

      final check = sqlite3.open(file.path);
      expect(
          check
              .select("SELECT 1 FROM pragma_table_info('games') "
                  "WHERE name = 'player_mode'")
              .isEmpty,
          isTrue);
      expect(check.userVersion, AppDatabase.expectedSchemaVersion);
      check.close();
    });

    test('migrating twice is a no-op', () async {
      final id = await buildV17Database();
      var db = AppDatabase(NativeDatabase(file));
      expect(await LocalSessionRepository(db).getById(id), isNotNull);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0);
      expect(await LocalSessionRepository(db).getById(id), isNotNull);
    });
  });

  /// A genuine v18 database: the group tables and the group-only columns of
  /// controller_allocations (with their indexes) back, one closed single-session
  /// pad row, one open group pad row, and one paid session.
  Future<String> buildV18Database() async {
    final db = AppDatabase(NativeDatabase(file));
    await LocalSeed.apply(db);
    final id = await paidHour(db);
    await db.close();
    final raw = sqlite3.open(file.path);
    for (final c in const [
      'group_id TEXT',
      'assignment_id TEXT',
      'player_number INTEGER',
      'player_label TEXT',
    ]) {
      raw.execute('ALTER TABLE controller_allocations ADD COLUMN $c');
    }
    raw.execute(
        'CREATE INDEX ix_alloc_group ON controller_allocations (group_id)');
    raw.execute('CREATE INDEX ix_alloc_assignment '
        'ON controller_allocations (assignment_id)');
    for (final t in const [
      'group_sessions',
      'group_assignments',
      'group_extensions',
      'group_charges',
      'group_payments',
    ]) {
      raw.execute('CREATE TABLE $t (id TEXT NOT NULL PRIMARY KEY)');
    }
    raw.execute("INSERT INTO group_sessions (id) VALUES ('g1')");
    raw.execute("INSERT INTO group_payments (id) VALUES ('gp1')");
    const at = '2026-10-10T09:00:00.000Z';
    raw.execute(
        'INSERT INTO controller_allocations (id, controller_id, scope, '
        'session_id, segment_id, resource_id, activity_code, started_at, '
        'ended_at, created_at) VALUES '
        "('a_single', 'ctl_hex_1', 'single', ?, 'seg1', 'hex', 'PS5', ?, ?, ?)",
        [id, at, '2026-10-10T10:00:00.000Z', at]);
    raw.execute(
        'INSERT INTO controller_allocations (id, controller_id, scope, '
        'group_id, assignment_id, player_number, resource_id, activity_code, '
        'started_at, created_at) VALUES '
        "('a_group', 'ctl_void_1', 'group', 'g1', 'as1', 1, 'void', 'PS5', ?, ?)",
        [at, at]);
    raw.execute('PRAGMA user_version = 18');
    raw.close();
    return id;
  }

  group('v18 -> v19 (group sessions removed)', () {
    test('the group tables and columns go with the group pad rows; '
        'single-session pads, sessions and payments are untouched', () async {
      final id = await buildV18Database();
      final before = sqlite3.open(file.path);
      expect(before.userVersion, 18);
      before.close();

      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0, reason: 'sequential, not a rebuild');
      final pads = await db.select(db.controllerAllocations).get();
      expect(pads.map((a) => a.id), ['a_single']);
      expect(pads.single.sessionId, id);
      expect(pads.single.endedAt, DateTime.utc(2026, 10, 10, 10));

      final sessions = LocalSessionRepository(db);
      final done = (await sessions.getById(id))!;
      expect((await sessions.paymentsFor(id)).single.amountPaise,
          done.billedAmountPaise);

      final check = sqlite3.open(file.path);
      expect(
          check
              .select("SELECT name FROM sqlite_master WHERE type = 'table' "
                  "AND name LIKE 'group_%'")
              .isEmpty,
          isTrue);
      final columns = check
          .select("SELECT name FROM pragma_table_info('controller_allocations')")
          .map((r) => '${r['name']}')
          .toSet();
      expect(columns, isNot(contains('group_id')));
      expect(columns, isNot(contains('assignment_id')));
      expect(columns, isNot(contains('player_number')));
      expect(columns, isNot(contains('player_label')));
      final indexes = check
          .select("SELECT name FROM sqlite_master WHERE type = 'index' "
              "AND tbl_name = 'controller_allocations'")
          .map((r) => '${r['name']}')
          .toSet();
      expect(indexes, contains('ux_one_open_allocation_per_controller'));
      expect(indexes, isNot(contains('ix_alloc_group')));
      expect(check.userVersion, AppDatabase.expectedSchemaVersion);
      check.close();
    });

    test('migrating twice is a no-op', () async {
      final id = await buildV18Database();
      var db = AppDatabase(NativeDatabase(file));
      expect(await LocalSessionRepository(db).getById(id), isNotNull);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(db.rebuiltFromVersion, 0);
      expect(await LocalSessionRepository(db).getById(id), isNotNull);
    });
  });
}
