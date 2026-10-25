/// Configuration writes go through [CatalogActions], which applies the
/// server's rules underneath every screen: everything needs `settings`,
/// except walking a pad to another station for now (a loan) or back home,
/// which is floor work (`start` or `settings`). A permanent re-home is
/// `settings`.
library;

import 'package:arena_ops/app/controllers/catalog_actions.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/money/paise.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/core/time/business_calendar.dart';
import 'package:arena_ops/core/time/ist.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_catalog_repository.dart';
import 'package:arena_ops/data/local/local_controller_allocation_repository.dart';
import 'package:arena_ops/data/local/local_customer_repository.dart';
import 'package:arena_ops/data/local/local_session_repository.dart';
import 'package:arena_ops/data/local/local_user_repository.dart';
import 'package:arena_ops/data/local/seed_data.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/domain/auth/permission.dart';
import 'package:arena_ops/domain/auth/permission_guard.dart';
import 'package:arena_ops/domain/entities/controller.dart';
import 'package:arena_ops/domain/entities/game.dart';
import 'package:arena_ops/domain/entities/resource.dart';
import 'package:arena_ops/domain/pricing/rate.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:arena_ops/domain/value/enums.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pricing_fixtures.dart';

void main() {
  late AppDatabase db;
  late FakeClock clock;
  late LocalCatalogRepository catalog;
  late LocalSessionRepository sessions;

  /// Holds settings (and everything else).
  const owner = AppUser(
    id: 'o',
    name: 'Arjun',
    perms: {
      Permission.start,
      Permission.bill,
      Permission.discount,
      Permission.members,
      Permission.money,
      Permission.reports,
      Permission.settings,
    },
  );

  /// Runs the floor, but no Settings.
  const staff = AppUser(
    id: 's',
    name: 'Priya',
    perms: {
      Permission.start,
      Permission.bill,
      Permission.discount,
      Permission.members,
    },
  );

  /// Takes money only.
  const till = AppUser(id: 't', name: 'Sam', perms: {Permission.bill});

  CatalogActions actionsFor(AppUser? user) => CatalogActions(
    catalog: catalog,
    inventory: LocalControllerAllocationRepository(db, clock),
    sessions: sessions,
    clock: clock,
    guard: PermissionGuard(user),
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await LocalSeed.apply(db);
    clock = FakeClock(ist(2026, 10, 2, 15, 30));
    catalog = LocalCatalogRepository(db, clock);
    sessions = LocalSessionRepository(db, clock);
  });

  tearDown(() async => db.close());

  /// Every configuration table, as one comparable value: "was anything
  /// written?" is then a single equality.
  Future<String> configState() async => [
    await db.select(db.settings).get(),
    await db.select(db.billingPolicies).get(),
    await db.select(db.rates).get(),
    await db.select(db.holidays).get(),
    await db.select(db.resources).get(),
    await db.select(db.resourceActivities).get(),
    await db.select(db.games).get(),
    await db.select(db.gameResources).get(),
    await db.select(db.gameControls).get(),
    await db.select(db.controllers).get(),
    await db.select(db.controllerMoves).get(),
  ].toString();

  Future<Controller> pad(String id) async =>
      (await catalog.controllers()).firstWhere((c) => c.id == id);

  // Each settings-level write, with a change it really makes.
  final settingsWrites =
      <String, Future<Result<Object?>> Function(CatalogActions)>{
        'save opening hours': (a) async {
          final h = await catalog.businessHours();
          return a.saveBusinessHours(
            BusinessHours(
              openByWeekday: {
                ...h.openByWeekday,
                DateTime.monday: const DayWindow.hm(10, 0, 22, 0),
              },
            ),
          );
        },
        'save billing rules': (a) async =>
            a.savePolicy((await catalog.policy()).copyWith(graceMinutes: 7)),
        'save a rate': (a) => a.saveRate(
          Rate(
            activityCode: 'POOL',
            band: Band.standard,
            controllerCount: null,
            unitMinutes: 60,
            price: const Paise(12345),
          ),
        ),
        'delete a rate': (a) async {
          final r = (await catalog.rates()).first;
          return a.deleteRate(
            activityCode: r.activityCode,
            band: r.band,
            controllerCount: r.controllerCount,
          );
        },
        'add a holiday': (a) => a.saveHoliday((
          day: const IstDate(2026, 11, 1),
          name: 'Test day',
          closed: true,
        )),
        'add a station': (a) => a.saveStation(
          const Resource(
            id: 'r_new',
            name: 'NOVA',
            kind: ResourceKind.station,
            activityCodes: ['PS5'],
          ),
        ),
        'take a station out of service': (a) async => a.setStationStatus(
          (await catalog.resources()).firstWhere((r) => r.id == 'hex'),
          ResourceStatus.maintenance,
        ),
        'lock RIFT to a mode': (a) => a.setStationMode('rift', 'VR'),
        'save a game with its compatibility': (a) => a.saveGame(
          const Game(id: 'g_new', name: 'New Game', platforms: ['PS5']),
          compatibility: const {'hex': GameAvailability.playable},
        ),
        'retire a game': (a) => a.setGameActive('g_eafc', active: false),
        'set a game status on one station': (a) => a.setCompatibility(
          'g_eafc',
          'hex',
          GameAvailability.notPlayable,
          notes: 'disc scratched',
        ),
        'replace a controls guide': (a) =>
            a.replaceControls('g_eafc', const []),
        'add a controller': (a) =>
            a.addController(label: 'HEX-9', resourceId: 'hex'),
        'rename a controller': (a) async =>
            a.renameController(await pad('ctl_hex_1'), 'HEX-A'),
        'set a controller home': (a) async =>
            a.setControllerHome(await pad('ctl_hex_1'), 'void'),
        'mark a controller faulty': (a) =>
            a.setControllerStatus('ctl_hex_1', ControllerStatus.faulty),
        're-home a controller for good': (a) async => a.moveController(
          controller: await pad('ctl_hex_1'),
          toResourceId: 'void',
          kind: ControllerMoveKind.permanent,
        ),
      };

  group('settings writes', () {
    for (final e in settingsWrites.entries) {
      test('${e.key}: allowed with settings', () async {
        final before = await configState();
        final r = await e.value(actionsFor(owner));
        expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
        expect(await configState(), isNot(before), reason: 'it was written');
      });

      test('${e.key}: refused without settings, nothing written', () async {
        final before = await configState();
        final r = await e.value(actionsFor(staff));
        expect(r.failureOrNull?.code, 'not_permitted');
        expect(r.failureOrNull!.message, contains('Priya'));
        expect(await configState(), before);
      });
    }

    test('nobody signed in is refused', () async {
      final before = await configState();
      final r = await actionsFor(null)
          .setControllerStatus('ctl_hex_1', ControllerStatus.faulty);
      expect(r.failureOrNull?.code, 'not_signed_in');
      expect(await configState(), before);
    });

    test('deleting a holiday needs settings too', () async {
      const day = IstDate(2026, 11, 1);
      await catalog.upsertHoliday((day: day, name: 'Diwali', closed: false));
      expect(
        (await actionsFor(staff).deleteHoliday(day)).failureOrNull?.code,
        'not_permitted',
      );
      expect(await catalog.holidays(), hasLength(1));
      expect((await actionsFor(owner).deleteHoliday(day)).isOk, isTrue);
      expect(await catalog.holidays(), isEmpty);
    });

    test('the visibility flag follows the permission', () {
      expect(actionsFor(owner).canChangeSettings, isTrue);
      expect(actionsFor(staff).canChangeSettings, isFalse);
      expect(actionsFor(null).canChangeSettings, isFalse);
    });
  });

  group('walking pads around the floor (start or settings)', () {
    test('staff with start can loan a pad and send it back', () async {
      final a = actionsFor(staff);
      final loaned = await a.moveController(
        controller: await pad('ctl_hex_1'),
        toResourceId: 'void',
        kind: ControllerMoveKind.loan,
      );
      expect(loaned.isOk, isTrue, reason: loaned.failureOrNull?.display);
      var c = await pad('ctl_hex_1');
      expect(c.currentResourceId, 'void');
      expect(c.homeResourceId, 'hex');

      final back = await a.returnHome(c);
      expect(back.isOk, isTrue, reason: back.failureOrNull?.display);
      c = await pad('ctl_hex_1');
      expect(c.currentResourceId, 'hex');
    });

    test('a settings holder without start can too', () async {
      final r =
          await actionsFor(
            const AppUser(
              id: 'cfg',
              name: 'Config only',
              perms: {Permission.settings},
            ),
          ).moveController(
            controller: await pad('ctl_hex_1'),
            toResourceId: 'void',
            kind: ControllerMoveKind.loan,
          );
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    });

    test('someone with neither is refused, naming both', () async {
      final before = await configState();
      final r = await actionsFor(till).moveController(
        controller: await pad('ctl_hex_1'),
        toResourceId: 'void',
        kind: ControllerMoveKind.loan,
      );
      expect(r.failureOrNull?.code, 'not_permitted');
      expect(r.failureOrNull!.message, contains('sessions'));
      expect(r.failureOrNull!.message, contains('settings'));
      expect(await configState(), before);
    });

    test(
      'a pad returned from the bill sheet needs start or settings',
      () async {
        await actionsFor(owner).moveController(
          controller: await pad('ctl_hex_1'),
          toResourceId: 'void',
          kind: ControllerMoveKind.loan,
        );
        expect(await actionsFor(till).returnPadsHome(['ctl_hex_1']), 0);
        expect((await pad('ctl_hex_1')).currentResourceId, 'void');
        expect(await actionsFor(staff).returnPadsHome(['ctl_hex_1']), 1);
        expect((await pad('ctl_hex_1')).currentResourceId, 'hex');
      },
    );

    test(
      '"permanently" to its own home is just a return, so start is enough',
      () async {
        await actionsFor(owner).moveController(
          controller: await pad('ctl_hex_1'),
          toResourceId: 'void',
          kind: ControllerMoveKind.loan,
        );
        final r = await actionsFor(staff).moveController(
          controller: await pad('ctl_hex_1'),
          toResourceId: 'hex',
          kind: ControllerMoveKind.permanent,
        );
        expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
        expect((await pad('ctl_hex_1')).currentResourceId, 'hex');
      },
    );
  });

  group('rules the action owns', () {
    test(
      'a station someone is playing on cannot be taken out of service',
      () async {
        final who = await LocalCustomerRepository(
          db,
          clock,
        ).create(name: 'Ravi');
        final started = await sessions.start(
          StartSessionCommand(
            customerId: who.id,
            startedAt: clock.now(),
            scheduledEndAt: clock.now().add(const Duration(hours: 1)),
            snapshot: await catalog.currentSnapshot(),
            resourceId: 'hex',
            resourceName: 'HEX',
            activityCode: 'PS5',
            controllerCount: 1,
          ),
        );
        expect(started.isOk, isTrue, reason: started.failureOrNull?.display);
        final hex = (await catalog.resources()).firstWhere(
          (r) => r.id == 'hex',
        );

        final r = await actionsFor(owner)
            .setStationStatus(hex, ResourceStatus.maintenance);
        expect(r.failureOrNull?.code, 'resource_busy');
        expect(
          r.failureOrNull!.display,
          'HEX is in use. End or move that session first.',
        );
        expect(
          (await catalog.resources()).firstWhere((x) => x.id == 'hex').status,
          ResourceStatus.available,
        );
      },
    );

    test('two pads never share a label (case-insensitive)', () async {
      final before = await configState();
      final r = await actionsFor(owner)
          .addController(label: 'hex-2', resourceId: 'hex');
      expect(r.failureOrNull?.code, 'label_taken');
      expect(
        r.failureOrNull!.display,
        'A controller is already labelled hex-2.',
      );
      expect(await configState(), before);
    });
  });

  group('staff profiles (Settings → Staff & roles)', () {
    // The seeded owner u1 (Prashanth) and staff u2 (Alan Benny).
    CatalogActions staffActions(AppUser actor) => CatalogActions(
          catalog: catalog,
          inventory: LocalControllerAllocationRepository(db, clock),
          sessions: sessions,
          clock: clock,
          guard: PermissionGuard(actor),
          users: LocalUserRepository(db, clock),
        );
    final ownerU1 = AppUser(id: 'u1', name: 'Prashanth', perms: Permission.all);

    test('a settings holder edits someone else\'s permissions', () async {
      final alan = (await LocalUserRepository(db, clock).getById('u2'))!;
      final r = await staffActions(ownerU1).saveStaff(
          alan.copyWith(perms: {...alan.perms, Permission.settings}));
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
      expect((await LocalUserRepository(db, clock).getById('u2'))!.perms,
          contains(Permission.settings));
    });

    test('nobody changes their own access (the server refuses it too)', () async {
      final me = (await LocalUserRepository(db, clock).getById('u1'))!;
      final r = await staffActions(ownerU1).saveStaff(me.copyWith(
          perms: me.perms.where((p) => p != Permission.money).toSet()));
      expect(r.failureOrNull?.code, 'own_access');
      expect((await LocalUserRepository(db, clock).getById('u1'))!.perms,
          contains(Permission.money));
    });

    test('renaming yourself is fine', () async {
      final me = (await LocalUserRepository(db, clock).getById('u1'))!;
      final r = await staffActions(ownerU1).saveStaff(me.copyWith(name: 'Prashanth K'));
      expect(r.isOk, isTrue, reason: r.failureOrNull?.display);
    });

    test('without settings it is refused and nothing is written', () async {
      final alan = (await LocalUserRepository(db, clock).getById('u2'))!;
      final r = await staffActions(staff).saveStaff(alan.copyWith(active: false));
      expect(r.failureOrNull?.code, 'not_permitted');
      expect((await LocalUserRepository(db, clock).getById('u2'))!.active, isTrue);
    });
  });

  group('the app clock stamps the writes', () {
    test(
      'a new controller is stamped with the clock, not the device',
      () async {
        final r = await actionsFor(owner)
            .addController(label: 'HEX-9', resourceId: 'hex');
        expect(r.valueOrNull!.updatedAt, clock.now());
        expect(r.valueOrNull!.homeResourceId, 'hex');
        expect(r.valueOrNull!.currentResourceId, 'hex');
      },
    );

    test('a compatibility change is stamped with the injected clock', () async {
      clock.set(ist(2031, 3, 15, 12, 0)); // nowhere near the device's time
      final r = await actionsFor(owner)
          .setCompatibility('g_eafc', 'hex', GameAvailability.notPlayable);
      expect(r.isOk, isTrue);
      final row =
          await (db.select(db.gameResources)..where(
                (t) => t.gameId.equals('g_eafc') & t.resourceId.equals('hex'),
              ))
              .getSingle();
      expect(row.updatedAt, ist(2031, 3, 15, 12, 0));
    });
  });
}
