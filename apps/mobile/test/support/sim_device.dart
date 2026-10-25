/// A simulated counter device for sync tests: its own in-memory Drift
/// database, its own signed-in account, the real repositories (recording ops)
/// and a [SyncEngine] — exactly the stack the app runs, minus the UI.
library;

import 'dart:io';

import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/result/result.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/local_booking_repository.dart';
import 'package:arena_ops/data/local/local_catalog_repository.dart';
import 'package:arena_ops/data/local/local_controller_allocation_repository.dart';
import 'package:arena_ops/data/local/local_customer_repository.dart';
import 'package:arena_ops/data/local/local_session_repository.dart';
import 'package:arena_ops/data/sync/sync_engine.dart';
import 'package:arena_ops/data/sync/sync_recorder.dart';
import 'package:arena_ops/data/sync/sync_transport.dart';
import 'package:arena_ops/domain/entities/session.dart';
import 'package:arena_ops/domain/repositories/commands.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

class SimDevice {
  SimDevice._(this.name, this.client, this.db, this.transport);

  final String name;
  final SupabaseClient client;
  final AppDatabase db;
  final SyncTransport transport;
  final Clock clock = const SystemClock();

  late final SyncRecorder recorder;
  late final LocalSessionRepository sessions;
  late final LocalCustomerRepository customers;
  late final LocalCatalogRepository catalog;
  late final LocalBookingRepository bookings;
  late final LocalControllerAllocationRepository pads;
  late SyncEngine engine;

  String get userId => client.auth.currentUser!.id;

  /// Signs in with a login the owner created (tool/sync_it.sh provisions them
  /// — public sign-up is off) and opens an empty device database. The catalog
  /// arrives with the first pull.
  static Future<SimDevice> signIn(
      String name, String url, String anonKey, String email) async {
    // Two devices in one test isolate is the point here; each has its own
    // in-memory executor, so drift's same-executor warning does not apply.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final client = SupabaseClient(url, anonKey,
        authOptions: const AuthClientOptions(
            autoRefreshToken: false, authFlowType: AuthFlowType.implicit));
    // tool/sync_it.sh generates one password per run (AO_IT_PASSWORD) for its
    // throw-away local test logins; it is never printed or stored.
    final password = Platform.environment['AO_IT_PASSWORD'] ?? 'it-pass-$email';
    await client.auth.signInWithPassword(email: email, password: password);
    return SimDevice._(name, client, AppDatabase(NativeDatabase.memory()),
        SupabaseSyncTransport(client));
  }

  /// Binds this device to [arenaId]: repositories record ops, the engine syncs.
  void bind(String arenaId,
      {SyncTransport? via, void Function(List<String> appliedKinds)? onPushed}) {
    recorder = SyncRecorder(db, actor: () => userId, clock: clock);
    sessions = LocalSessionRepository(db, clock, recorder);
    customers = LocalCustomerRepository(db, clock, recorder);
    catalog = LocalCatalogRepository(db, clock, recorder);
    bookings = LocalBookingRepository(db, clock, recorder);
    pads = LocalControllerAllocationRepository(db, clock, recorder);
    engine = SyncEngine(db: db, transport: via ?? transport, arenaId: arenaId,
        clock: clock, onPushed: onPushed);
  }

  Future<SyncReport> sync() => engine.syncNow();

  Future<void> close() async {
    await engine.dispose();
    await db.close();
    await client.dispose();
  }

  // ------------------------------------------------------------ lookups

  Future<String> station(String name) async =>
      (await (db.select(db.resources)..where((t) => t.name.equals(name))).getSingle()).id;
  Future<String> pad(String label) async =>
      (await (db.select(db.controllers)..where((t) => t.label.equals(label))).getSingle()).id;
  Future<String> game(String name) async =>
      (await (db.select(db.games)..where((t) => t.name.equals(name))).getSingle()).id;

  /// Starts a PS5 session the way the New Session flow does.
  Future<Result<Session>> start({
    required String customerId,
    required String stationName,
    required List<String> padLabels,
    List<String> borrowLabels = const [],
    String gameName = 'EA SPORTS FC 25',
    int? count,
    String? bookingId,
  }) async {
    final now = clock.now();
    return sessions.start(StartSessionCommand(
      customerId: customerId,
      startedAt: now,
      scheduledEndAt: now.add(const Duration(hours: 1)),
      snapshot: await catalog.currentSnapshot(),
      resourceId: await station(stationName),
      resourceName: stationName,
      activityCode: 'PS5',
      gameId: await game(gameName),
      controllerCount: count ?? padLabels.length,
      controllerIds: padLabels.isEmpty
          ? null
          : [for (final l in padLabels) await pad(l)],
      borrowControllerIds: borrowLabels.isEmpty
          ? null
          : [for (final l in borrowLabels) await pad(l)],
      bookingId: bookingId,
    ));
  }

  Future<List<SyncOutboxRow>> outbox(String status) =>
      (db.select(db.syncOutbox)..where((t) => t.status.equals(status))).get();

  Future<Set<String>> openPadLabels() async {
    final open = await (db.select(db.controllerAllocations)
          ..where((t) => t.endedAt.isNull()))
        .get();
    final labels = <String>{};
    for (final a in open) {
      labels.add((await (db.select(db.controllers)
                ..where((t) => t.id.equals(a.controllerId)))
              .getSingle())
          .label);
    }
    return labels;
  }
}
