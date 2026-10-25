/// The game catalog's lifecycle as the device sees it: a game (or station
/// type) the owner deleted on the dashboard disappears from this device too;
/// an archived game leaves the pickers but stays for history; and the device's
/// own game edits carry what the server needs to refuse a stale one, without
/// wiping fields or station notes the form does not show.
library;

import 'dart:convert';

import 'package:arena_ops/app/controllers/catalog_actions.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_catalog_repository.dart';
import 'package:arena_ops/data/local/local_controller_allocation_repository.dart';
import 'package:arena_ops/data/local/local_session_repository.dart';
import 'package:arena_ops/data/local/seed_data.dart';
import 'package:arena_ops/data/sync/sync_applier.dart';
import 'package:arena_ops/data/sync/sync_recorder.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/auth/permission_guard.dart';
import 'package:arena_ops/domain/entities/game.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  late AppDatabase db;
  late SyncRecorder recorder;
  late LocalCatalogRepository catalog;
  final clock = FakeClock(DateTime.utc(2026, 10, 14, 8));

  const owner = AppUser(
    id: 'o',
    name: 'Arjun',
    perms: {Permission.start, Permission.settings},
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await LocalSeed.apply(db);
    recorder = SyncRecorder(db, actor: () => 'o', clock: clock);
    catalog = LocalCatalogRepository(db, clock, recorder);
  });
  tearDown(() async => db.close());

  Future<void> pull(List<Map<String, dynamic>> changes) =>
      db.transaction(() => SyncApplier(db).applyChanges(changes));

  Map<String, dynamic> tombstone(String table, Map<String, dynamic> row) => {
        't': '_tombstone',
        'r': {'table': table, 'row': row},
      };

  Future<List<SyncOutboxRow>> outbox() => (db.select(db.syncOutbox)
        ..orderBy([(t) => OrderingTerm(expression: t.seq)]))
      .get();

  Map<String, dynamic> payload(SyncOutboxRow o) =>
      jsonDecode(o.payload) as Map<String, dynamic>;

  CatalogActions actions() => CatalogActions(
        catalog: catalog,
        inventory: LocalControllerAllocationRepository(db, clock),
        sessions: LocalSessionRepository(db, clock),
        clock: clock,
        guard: const PermissionGuard(owner),
      );

  group('a delete made on the dashboard', () {
    test('removes the game from this device and from its pickers', () async {
      expect(await catalog.gameById('g_gt7'), isNotNull);
      // Only the game's own tombstone in this page: its station statuses go
      // with it even if their tombstones arrive later.
      await pull([
        tombstone('games', {'id': 'g_gt7', 'arena_id': 'a', 'name': 'Gran Turismo 7'}),
      ]);
      expect(await catalog.gameById('g_gt7'), isNull);
      expect((await catalog.games()).map((g) => g.id), isNot(contains('g_gt7')));
      expect(
        (await catalog.gamesForResource('hex')).map((g) => g.game.id),
        isNot(contains('g_gt7')),
      );
      expect(
        (await catalog.compatibility()).where((c) => c.gameId == 'g_gt7'),
        isEmpty,
      );
    });

    test('a live row in the same page outranks the tombstone', () async {
      await pull([
        {
          't': 'games',
          'r': {
            'id': 'g_gt7',
            'name': 'Gran Turismo 7',
            'aliases': <String>[],
            'category_id': null,
            'platforms': ['PS5'],
            'play_modes': ['single'],
            'max_local_players': 1,
            'active': true,
            'last_played_at': null,
          },
        },
        tombstone('games', {'id': 'g_gt7'}),
      ]);
      expect(await catalog.gameById('g_gt7'), isNotNull);
    });

    test('removes a station type nothing used (activity.remove)', () async {
      expect((await catalog.activities()).map((a) => a.code), contains('LOUNGE'));
      final lounge = (await catalog.activities()).firstWhere((a) => a.code == 'LOUNGE');
      await pull([tombstone('activities', {'id': lounge.id, 'code': 'LOUNGE'})]);
      expect((await catalog.activities()).map((a) => a.code), isNot(contains('LOUNGE')));
    });
  });

  group('an archive made on the dashboard', () {
    test('takes the game out of the pickers but keeps it for history', () async {
      final before = await catalog.gameById('g_tekken8');
      await pull([
        {
          't': 'games',
          'r': {
            'id': 'g_tekken8',
            'name': before!.name,
            'aliases': before.aliases,
            'category_id': before.categoryId,
            'platforms': before.platforms,
            'play_modes': [for (final m in before.playModes) m.code],
            'max_local_players': before.maxLocalPlayers,
            'active': false,
            'last_played_at': null,
          },
        },
      ]);
      expect((await catalog.gameById('g_tekken8'))!.active, isFalse);
      expect(
        (await catalog.gamesForResource('hex')).map((g) => g.game.id),
        isNot(contains('g_tekken8')),
      );
      expect((await catalog.games()).map((g) => g.id), contains('g_tekken8'));
    });
  });

  group('an edit made on this device', () {
    test('sends the active flag it held, so the server can refuse a stale one',
        () async {
      final game = (await catalog.gameById('g_tekken8'))!;
      await catalog.upsertGame(game.copyWith(name: 'Tekken 8 Ultimate'));
      final p = payload((await outbox()).last);
      expect(p['name'], 'Tekken 8 Ultimate');
      expect(p['active'], isTrue);
      expect(p['base_active'], isTrue);
    });

    test('a new game has nothing to be stale against', () async {
      await catalog.upsertGame(const Game(
        id: 'g_new',
        name: 'Hades II',
        platforms: ['PS5'],
        playModes: [PlayerMode.single],
        maxLocalPlayers: 1,
      ));
      expect(payload((await outbox()).last).containsKey('base_active'), isFalse);
    });

    test('saving the form writes only the stations it changed, keeping notes',
        () async {
      await catalog.setCompatibility('g_tekken8', 'hex', GameAvailability.maintenance,
          notes: 'disc scratched');
      await db.delete(db.syncOutbox).go();
      final game = (await catalog.gameById('g_tekken8'))!;
      final stored = {
        for (final c in await catalog.compatibility())
          if (c.gameId == 'g_tekken8') c.resourceId: c.status,
      };
      final r = await actions().saveGame(
        game.copyWith(name: 'Tekken 8'),
        // The form sends every station; only VOID differs from what is stored.
        compatibility: {
          ...stored,
          'hex': GameAvailability.maintenance,
          'void': GameAvailability.notPlayable,
        },
      );
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
      final ops = await outbox();
      expect(ops.map((o) => o.kind), ['game.upsert', 'game.set_compat']);
      expect(payload(ops.last)['resource_id'], 'void');
      final hex = (await catalog.compatibility())
          .firstWhere((c) => c.gameId == 'g_tekken8' && c.resourceId == 'hex');
      expect(hex.notes, 'disc scratched');
    });

  });
}
