/// Moves the outbox to the server and the server's changes onto the device.
///
/// One pass ([syncNow]):
///  1. PUSH every pending op, oldest first. The server applies each once
///     (a retried op replays its first answer), so a timeout or a crash between
///     sending and recording the answer can never apply an op twice.
///  2. ROLL BACK what the server refused: the device's copy of each affected
///     entity (session, pad, customer, booking — or the whole catalog)
///     is replaced with the server's. The refused op itself is kept, with the
///     server's reason, until someone acknowledges it.
///  3. PULL everything committed since the cursor and apply it.
///
/// Steps 2–3 only run when the outbox is empty, and their writes happen in a
/// Drift transaction that re-checks that — so server rows are never laid over a
/// local change the server has not seen yet. A change made mid-pass simply
/// triggers another pass.
///
/// What this does NOT promise: an offline device cannot know what another
/// device did meanwhile. Conflicting work done offline (the same station, the
/// same pad, the same booking, a bill priced from a stale session) is refused
/// by the server on reconnect and surfaced as "needs attention" — never merged
/// silently.
library;

import 'dart:async';
import 'dart:convert';

import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/monitoring/app_telemetry.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/sync/sync_applier.dart';
import 'package:arena_ops/data/sync/sync_recorder.dart';
import 'package:arena_ops/data/sync/sync_transport.dart';
import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

enum SyncState {
  /// Cloud sync is not set up on this device (local-only mode).
  localOnly,

  /// Everything this device did is on the server, and the last pull worked.
  synced,

  /// Changes are saved on this device and waiting to be sent.
  pending,

  /// A pass is running.
  syncing,

  /// The server could not be reached; changes stay on this device until it can.
  offline,

  /// The sign-in expired or access was turned off; nothing syncs until fixed.
  authProblem,

  /// The server answered with an unexpected error; retried with backoff.
  error,
}

@immutable
class SyncStatus {
  const SyncStatus({
    required this.state,
    this.pending = 0,
    this.needsAttention = 0,
    this.lastSyncedAt,
    this.message,
    this.accessRevoked = false,
  });

  static const localOnly = SyncStatus(state: SyncState.localOnly);

  final SyncState state;

  /// Ops saved on this device, not yet accepted or refused by the server.
  final int pending;

  /// Ops the server refused that nobody has acknowledged yet.
  final int needsAttention;
  final DateTime? lastSyncedAt;
  final String? message;
  final bool accessRevoked;

  SyncStatus copyWith({
    SyncState? state,
    int? pending,
    int? needsAttention,
    DateTime? lastSyncedAt,
    String? message,
    bool? accessRevoked,
  }) => SyncStatus(
    state: state ?? this.state,
    pending: pending ?? this.pending,
    needsAttention: needsAttention ?? this.needsAttention,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    message: message,
    accessRevoked: accessRevoked ?? this.accessRevoked,
  );

  @override
  String toString() =>
      'SyncStatus($state, pending: $pending, attention: $needsAttention, $message)';
}

/// What one pass did (for tests and logs).
class SyncReport {
  int applied = 0;
  int rejected = 0;
  int rolledBack = 0;
  int pulledChanges = 0;
  SyncState endedIn = SyncState.synced;

  @override
  String toString() =>
      'SyncReport(applied: $applied, rejected: $rejected, '
      'rolledBack: $rolledBack, pulled: $pulledChanges, $endedIn)';
}

class SyncEngine {
  SyncEngine({
    required this.db,
    required this.transport,
    required this.arenaId,
    this.clock = const SystemClock(),
    this.pollEvery = const Duration(seconds: 10),
    this.batchSize = 50,
    this.onPushed,
  }) : _applier = SyncApplier(db);

  final AppDatabase db;
  final SyncTransport transport;
  final String arenaId;
  final Clock clock;
  final Duration pollEvery;
  final int batchSize;
  final SyncApplier _applier;

  /// Called after a push batch the server answered, with the kinds of the ops
  /// it APPLIED (empty batches and refused ops are not reported). Cloud mode
  /// broadcasts the nudge from here, so other devices hear about a change only
  /// once it is committed on the server — never for a refused or unsent op.
  final void Function(List<String> appliedKinds)? onPushed;

  static const _uuid = Uuid();
  static const cursorKey = 'pull_cursor';

  /// The pull scope last seen (the server's hidden feeds, comma-joined).
  static const scopeKey = 'pull_scope';
  static const deviceKey = 'device_id';
  static const lastSyncKey = 'last_synced_at';
  static const clockOffsetKey = 'clock_offset_ms';

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = const SyncStatus(state: SyncState.pending);
  Future<SyncReport>? _running;
  bool _again = false;
  Timer? _poll;
  Timer? _debounce;
  int _failures = 0;
  DateTime? _notBefore;

  /// Ops per push: halved after each push the server failed as a whole (a
  /// timeout under load, a poison op), back to [batchSize] after a clean pass.
  late int _batchLimit = batchSize;

  /// After this many failed sends of a one-op batch the op is reported as
  /// stuck (kept pending, in order: never skipped or rolled back).
  static const stuckAfterAttempts = 8;

  /// The op the last failed push could not get past, once it is stuck.
  SyncOutboxRow? _stuck;
  bool _stopped = false;

  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Fires after a pass that changed this device's data from the server
  /// (pulled rows or a rollback). Screens that read the catalog once (station
  /// list, games, prices) re-read on it, so another device's edit appears
  /// without a restart. Floor state is already live through Drift streams.
  Stream<void> get dataChanged => _dataChanged.stream;
  final _dataChanged = StreamController<void>.broadcast();
  SyncStatus get status => _status;

  void _emit(SyncStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  /// Starts background passes: now, after every local change ([nudge]), and
  /// every [pollEvery] (that is how other devices' changes arrive).
  void start() {
    _stopped = false;
    unawaited(syncNow());
    _poll?.cancel();
    _poll = Timer.periodic(pollEvery, (_) {
      final wait = _notBefore;
      if (wait != null && clock.now().isBefore(wait)) return;
      unawaited(syncNow());
    });
  }

  void stop() {
    _stopped = true;
    _poll?.cancel();
    _debounce?.cancel();
  }

  /// The app is going to the background: stop polling, but first send what is
  /// waiting — a session started just before the phone was locked must reach
  /// the other devices now, not when this one is opened again. One pass at
  /// most; if it cannot finish (offline, or the OS suspends the app) the
  /// changes stay in the outbox for [start] on resume.
  Future<void> pause() async {
    final nudged = _debounce?.isActive ?? false;
    stop();
    try {
      await _running;
      if (nudged || await _count(OutboxStatus.pending) > 0) await syncNow();
    } on Object catch (_) {
      // The database is closing (sign-out): nothing left to send from here.
    }
  }

  Future<void> dispose() async {
    stop();
    await _running;
    await _statusController.close();
    await _dataChanged.close();
  }

  /// A local change was recorded: sync soon (coalescing bursts of writes).
  ///
  /// Repositories call this from INSIDE their Drift transaction (the recorder
  /// fires after the outbox insert). Anything scheduled from there inherits
  /// the transaction's zone, and Drift runs its queries on that transaction —
  /// which has committed by the time the timer fires, so the pass used to die
  /// silently and changes only went out on the next poll. Scheduling from the
  /// root zone makes the pass an ordinary reader that waits for the commit.
  void nudge() => Zone.root.run(_nudge);

  void _nudge() {
    if (_stopped) {
      // Not syncing (sign-in expired, paused), but the change is waiting: the
      // strip and the sign-out warning must count it.
      Timer.run(() => unawaited(_refreshCounts()));
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      // A nudge is fresh work, so it does not wait out an offline backoff.
      _notBefore = null;
      unawaited(syncNow());
    });
  }

  /// A remote nudge (Realtime): sync now unless the engine is stopped — paused
  /// in the background, or halted because the sign-in ended or access was
  /// turned off. Remote events must not restart a stopped engine.
  Future<void> syncIfRunning() async {
    if (_stopped) return;
    await syncNow();
  }

  /// One full pass. Concurrent calls share the running pass and schedule one
  /// more, so no change is missed and no two passes overlap.
  Future<SyncReport> syncNow() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final pass = _pass();
    _running = pass;
    return pass.whenComplete(() {
      _running = null;
      if (_again && !_stopped) {
        _again = false;
        unawaited(syncNow());
      }
    });
  }

  /// This device's id (sent with every push; created once).
  Future<String> deviceId() async {
    final row = await (db.select(
      db.syncMeta,
    )..where((t) => t.key.equals(deviceKey))).getSingleOrNull();
    if (row != null) return row.value;
    final id = _uuid.v4();
    await db
        .into(db.syncMeta)
        .insertOnConflictUpdate(SyncMetaRow(key: deviceKey, value: id));
    return id;
  }

  Future<int> _count(String status, {bool unresolvedOnly = false}) async {
    final q = db.selectOnly(db.syncOutbox)
      ..addColumns([db.syncOutbox.seq.count()])
      ..where(db.syncOutbox.status.equals(status));
    if (unresolvedOnly) q.where(db.syncOutbox.resolvedAt.isNull());
    return (await q.getSingle()).read(db.syncOutbox.seq.count()) ?? 0;
  }

  Future<SyncStatus> _counts(SyncStatus base) async => base.copyWith(
    state: base.state,
    message: base.message,
    pending: await _count(OutboxStatus.pending),
    needsAttention: await _count(OutboxStatus.rejected, unresolvedOnly: true),
  );

  Future<void> _refreshCounts() async {
    try {
      final s = await _counts(_status);
      if (!_statusController.isClosed) _emit(s);
    } on Object catch (_) {
      // The database is closing (sign-out): nothing left to show.
    }
  }

  Future<SyncReport> _pass() async {
    final report = SyncReport();
    _emit(await _counts(_status.copyWith(state: SyncState.syncing)));
    try {
      await _push(report);
      if (await _count(OutboxStatus.pending) == 0) {
        await _reconcile(report);
      }
      if ((report.pulledChanges > 0 || report.rolledBack > 0) &&
          !_dataChanged.isClosed) {
        _dataChanged.add(null);
      }
      _failures = 0;
      _notBefore = null;
      _batchLimit = batchSize;
      _stuck = null;
      final pending = await _count(OutboxStatus.pending);
      report.endedIn = pending == 0 ? SyncState.synced : SyncState.pending;
      final now = clock.now();
      if (pending == 0) await _setMeta(lastSyncKey, now.toIso8601String());
      _emit(
        await _counts(
          SyncStatus(
            state: report.endedIn,
            lastSyncedAt: pending == 0 ? now : _status.lastSyncedAt,
          ),
        ),
      );
    } on SyncOfflineException catch (e) {
      report.endedIn = SyncState.offline;
      _backoff();
      _emit(
        await _counts(
          _status.copyWith(
            state: SyncState.offline,
            message: 'Server unreachable ($e)',
          ),
        ),
      );
    } on SyncAuthException catch (e) {
      report.endedIn = SyncState.authProblem;
      stop();
      // Unsent work stays in this person's file and only they can send it:
      // say so before the device signs them out (FL-003).
      final unsent = e.revoked ? await _count(OutboxStatus.pending) : 0;
      _emit(
        await _counts(
          _status.copyWith(
            state: SyncState.authProblem,
            accessRevoked: e.revoked,
            message: !e.revoked
                ? 'Sign in again to keep syncing.'
                : unsent == 0
                ? 'Your access to this arena was turned off.'
                : 'Your access to this arena was turned off. $unsent '
                      'change${unsent == 1 ? '' : 's'} on this device (payments '
                      'included) did not reach the server: tell the owner, who '
                      'can turn your access back on so they send.',
          ),
        ),
      );
    } on Object catch (e, st) {
      report.endedIn = SyncState.error;
      _backoff();
      unawaited(
        AppTelemetry.captureException(
          e,
          stackTrace: st,
          operation: 'sync_engine_cycle',
        ),
      );
      final stuck = _stuck;
      _emit(
        await _counts(
          _status.copyWith(
            state: SyncState.error,
            message: stuck == null
                ? 'Sync failed: $e'
                : 'One change (${stuck.kind}) has failed to send '
                    '${stuck.attempts} times and is holding back the rest. '
                    'Keep the app open on Wi-Fi; if it stays stuck, contact '
                    'support before signing out: $e',
          ),
        ),
      );
    }
    return report;
  }

  void _backoff() {
    _failures++;
    final seconds = [2, 4, 8, 16, 32, 60][(_failures - 1).clamp(0, 5)];
    _notBefore = clock.now().add(Duration(seconds: seconds));
  }

  // ----------------------------------------------------------------- push

  Future<void> _push(SyncReport report) async {
    final device = await deviceId();
    while (true) {
      final batch =
          await (db.select(db.syncOutbox)
                ..where((t) => t.status.equals(OutboxStatus.pending))
                ..orderBy([(t) => OrderingTerm(expression: t.seq)])
                ..limit(_batchLimit))
              .get();
      if (batch.isEmpty) return;

      final attemptAt = clock.now();
      await db.transaction(() async {
        for (final o in batch) {
          await (db.update(
            db.syncOutbox,
          )..where((t) => t.seq.equals(o.seq))).write(
            SyncOutboxCompanion(
              attempts: Value(o.attempts + 1),
              lastAttemptAt: Value(attemptAt),
            ),
          );
        }
      });

      final List<OpResult> results;
      try {
        results = await transport.push(arenaId, [
          for (final o in batch)
            (
              opId: o.opId,
              kind: o.kind,
              payload: jsonDecode(o.payload) as Map<String, dynamic>,
            ),
        ], device);
      } on SyncOfflineException {
        rethrow;
      } on SyncAuthException {
        rethrow;
      } on Object {
        // The whole push failed: send fewer next time, down to the one op
        // that may be causing it, and report that op once it keeps failing.
        if (_batchLimit > 1) {
          _batchLimit = (_batchLimit / 2).ceil();
        } else if (batch.single.attempts + 1 >= stuckAfterAttempts) {
          _stuck = batch.single.copyWith(attempts: batch.single.attempts + 1);
        }
        rethrow;
      }
      final byId = {for (final r in results) r.opId: r};

      var stop = false;
      final appliedKinds = <String>[];
      await db.transaction(() async {
        final now = clock.now();
        for (final o in batch) {
          final r = byId[o.opId];
          if (r == null || r.status == 'retry') {
            // Not decided (a transient lock on the server). Keep order: stop.
            stop = true;
            break;
          }
          if (r.status == 'applied') {
            report.applied++;
            appliedKinds.add(o.kind);
            await (db.update(
              db.syncOutbox,
            )..where((t) => t.seq.equals(o.seq))).write(
              SyncOutboxCompanion(
                status: const Value(OutboxStatus.applied),
                result: Value(r.result == null ? null : jsonEncode(r.result)),
                needsRefetch: Value(r.adjusted),
                resolvedAt: Value(now),
              ),
            );
          } else {
            report.rejected++;
            await (db.update(
              db.syncOutbox,
            )..where((t) => t.seq.equals(o.seq))).write(
              SyncOutboxCompanion(
                status: const Value(OutboxStatus.rejected),
                errorCode: Value(r.error),
                errorDetail: Value(r.detail),
                needsRefetch: const Value(true),
              ),
            );
          }
        }
      });
      if (appliedKinds.isNotEmpty) {
        try {
          onPushed?.call(appliedKinds);
        } on Object catch (_) {
          // A failed nudge only delays other devices until their next poll;
          // it must never break this pass.
        }
      }
      if (stop) return;
    }
  }

  // ------------------------------------------------- roll back + pull

  /// The entities an op wrote on this device (its own + every pad it moved or
  /// allocated), in rollback order: parents first, pads last.
  static List<({String type, String id})> refsFor(SyncOutboxRow op) {
    final refs = <({String type, String id})>[
      (type: op.entityType, id: op.entityId),
    ];
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;
    // A check-in marks its booking checked_in in the same transaction; a
    // refused one must put the booking back as the server has it, or it drops
    // off the upcoming list on this device only.
    final booking = payload['booking_id'];
    if (op.entityType != 'booking' && booking is String) {
      refs.add((type: 'booking', id: booking));
    }
    final pads = <String>{};
    void collect(Object? list) {
      if (list is! List) return;
      for (final e in list) {
        final id = (e as Map)['controller_id'];
        if (id is String) pads.add(id);
      }
    }

    collect(payload['allocations']);
    collect(payload['moves']);
    if (op.kind == 'controller.move' || op.kind.startsWith('controller.')) {
      final id = payload['controller_id'] ?? payload['id'];
      if (id is String) pads.add(id);
    }
    for (final id in pads) {
      if (!(op.entityType == 'controller' && op.entityId == id)) {
        refs.add((type: 'controller', id: id));
      }
    }
    return refs;
  }

  Future<void> _reconcile(SyncReport report) async {
    final toRefetch =
        await (db.select(db.syncOutbox)
              ..where((t) => t.needsRefetch.equals(true))
              ..orderBy([(t) => OrderingTerm(expression: t.seq)]))
            .get();

    final entityRefs = <({String type, String id})>[];
    var catalog = false;
    for (final op in toRefetch) {
      if (op.entityType == 'catalog' || op.entityType == 'staff') {
        catalog = true;
        continue;
      }
      for (final r in refsFor(op)) {
        if (!entityRefs.contains(r)) entityRefs.add(r);
      }
    }
    // Parents before pads, so a pad's open allocation from a refused session is
    // already gone when the pad's own rows are applied.
    entityRefs.sort(
      (a, b) => (a.type == 'controller' ? 1 : 0).compareTo(
        b.type == 'controller' ? 1 : 0,
      ),
    );

    final fetched = entityRefs.isEmpty
        ? const <EntityRows>[]
        : await transport.fetchEntities(arenaId, entityRefs);
    List<ServerRow>? catalogRows;
    if (catalog) {
      catalogRows = [];
      var c = '0';
      while (true) {
        final page = await transport.pull(arenaId, c);
        for (final ch in page.changes) {
          final t = ch['t'] as String;
          if (catalogTables.contains(t)) {
            catalogRows.add((
              table: t,
              row: Map<String, dynamic>.from(ch['r'] as Map),
            ));
          }
        }
        c = page.cursor;
        if (!page.hasMore) break;
      }
    }

    var cursor = await _meta(cursorKey) ?? '0';
    var first = true;
    while (true) {
      final page = await transport.pull(arenaId, cursor);
      // What this member may read changed (a permission granted or taken):
      // re-read the feed from the start so newly visible rows arrive. The
      // cursor is rewound before the scope is stored, so a pass cut short
      // here rewinds again next time.
      final scope = page.scope?.join(',');
      if (scope != null) {
        final known = await _meta(scopeKey);
        if (known != scope) {
          if (known != null && cursor != '0') {
            await _setMeta(cursorKey, '0');
            await _setMeta(scopeKey, scope);
            cursor = '0';
            continue;
          }
          await _setMeta(scopeKey, scope);
        }
      }
      final applied = await db.transaction(() async {
        // A local write slipped in since the push: its op has not reached the
        // server, so the server's rows must not be laid over it yet.
        if (await _count(OutboxStatus.pending) > 0) return false;
        if (first) {
          for (final e in fetched) {
            await _applier.replaceEntity(e.type, e.id, [
              for (final r in e.rows)
                (
                  table: r['t'] as String,
                  row: Map<String, dynamic>.from(r['r'] as Map),
                ),
            ]);
          }
          if (catalogRows != null) await _applier.replaceCatalog(catalogRows);
          if (toRefetch.isNotEmpty) {
            await (db.update(
                  db.syncOutbox,
                )..where((t) => t.seq.isIn([for (final o in toRefetch) o.seq])))
                .write(const SyncOutboxCompanion(needsRefetch: Value(false)));
            report.rolledBack += toRefetch.length;
          }
        }
        await _applier.applyChanges(page.changes);
        await _setMeta(cursorKey, page.cursor);
        final serverTime = page.serverTime;
        if (serverTime != null) {
          await _setMeta(
            clockOffsetKey,
            '${serverTime.difference(clock.now()).inMilliseconds}',
          );
        }
        return true;
      });
      if (!applied) return;
      first = false;
      report.pulledChanges += page.changes.length;
      cursor = page.cursor;
      if (!page.hasMore) return;
    }
  }

  Future<String?> _meta(String key) async => (await (db.select(
    db.syncMeta,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _setMeta(String key, String value) => db
      .into(db.syncMeta)
      .insertOnConflictUpdate(SyncMetaRow(key: key, value: value));

  /// Marks a refused op as seen by a person (it stays in the outbox as history).
  Future<void> acknowledge(String opId) async {
    await (db.update(db.syncOutbox)..where((t) => t.opId.equals(opId))).write(
      SyncOutboxCompanion(resolvedAt: Value(clock.now())),
    );
    _emit(await _counts(_status));
  }
}
