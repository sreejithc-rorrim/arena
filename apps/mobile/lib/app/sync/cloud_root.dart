/// Cloud mode's root: sign in → pick the arena → open that arena's database on
/// this device (downloading it the first time) → the normal app, with every
/// repository recording sync ops and a sync engine running.
///
/// Each (arena, person) gets its own database file. A device used by two people
/// therefore never pushes one person's unsent work under the other's sign-in,
/// and the local-only database (`arena_ops.sqlite`) is never touched.
library;

import 'dart:async';
import 'dart:io';

import 'package:arena_ops/app/arena_ops_app.dart';
import 'package:arena_ops/app/auth/auth_controller.dart';
import 'package:arena_ops/app/notifications/reminder_startup.dart';
import 'package:arena_ops/app/providers/core_providers.dart';
import 'package:arena_ops/app/providers/data_providers.dart';
import 'package:arena_ops/app/providers/my_bills_providers.dart';
import 'package:arena_ops/app/providers/profile_providers.dart';
import 'package:arena_ops/app/sync/cloud_binding.dart';
import 'package:arena_ops/app/sync/staff_access.dart';
import 'package:arena_ops/app/sync/stored_session.dart';
import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/core/monitoring/app_telemetry.dart';
import 'package:arena_ops/core/monitoring/replay_privacy.dart';
import 'package:arena_ops/core/notifications/notification_service.dart';
import 'package:arena_ops/core/theme/app_theme.dart';
import 'package:arena_ops/data/local/database.dart';
import 'package:arena_ops/data/local/db_safety.dart';
import 'package:arena_ops/data/remote/supabase_my_bills_repository.dart';
import 'package:arena_ops/data/remote/supabase_profile_repository.dart';
import 'package:arena_ops/data/sync/realtime_sync.dart';
import 'package:arena_ops/data/sync/sync_engine.dart';
import 'package:arena_ops/data/sync/sync_recorder.dart';
import 'package:arena_ops/data/sync/sync_transport.dart';
import 'package:arena_ops/domain/auth/app_user.dart';
import 'package:arena_ops/features/more/presentation/database_locked_screen.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:arena_ops/app/sync/staff_access.dart' show Membership;

/// Staff-only app: there is no sign-up or arena creation here. Owners register
/// and invite staff on the admin dashboard (apps/admin); an invited person
/// accepts there, then signs in here with their own e-mail and password.
enum _Phase { checking, signIn, pickArena, opening, ready, failed }

class CloudRoot extends StatefulWidget {
  const CloudRoot({required this.documentsPath, super.key});

  /// Where the per-arena database files and their backups live.
  final String documentsPath;

  @override
  State<CloudRoot> createState() => _CloudRootState();
}

class _CloudRootState extends State<CloudRoot> with WidgetsBindingObserver {
  _Phase _phase = _Phase.checking;
  String? _message;
  List<Membership> _arenas = const [];
  ProviderContainer? _container;
  AppDatabase? _db;
  CloudBinding? _binding;
  DbProtectReport? _locked;
  StreamSubscription<SyncStatus>? _statusSub;
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<void>? _dataSub;
  Timer? _reminderDebounce;
  Future<void> _reminderWork = Future.value();

  /// The clock offset the device's alerts were last scheduled with.
  Duration _alertsOffset = Duration.zero;

  /// The phone's notification scheduler outside an open arena (one per run).
  NotificationService? _alerts;

  /// What "Try again" on the failure screen repeats.
  late Future<void> Function() _retry = _loadArenas;

  static const _expiredNotice =
      'Your sign-in has expired. Sign in again to continue.';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = _client.auth.onAuthStateChange.listen(
      _onAuthChange,
      onError: (Object _) {}, // retryable refresh failures; handled per call
    );
    if (_client.auth.currentSession == null) {
      _phase = _Phase.signIn;
    } else {
      unawaited(_restore());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSub?.cancel());
    unawaited(_teardown());
    super.dispose();
  }

  /// Start-up with a stored sign-in: check it before the first call, so a
  /// refresh the server refused lands on Sign in instead of calling as `anon`.
  Future<void> _restore() async {
    switch (await checkStoredSession(_client.auth)) {
      case StoredSession.signInNeeded:
        _go(_Phase.signIn, message: _expiredNotice);
        return;
      case StoredSession.offline:
        // Auth is out of reach, so my_arenas would be too: open the last arena
        // from disk now instead of waiting for that call to time out as well.
        final last = await _lastArenaOnDisk();
        if (last != null) {
          await _open(last, confirmedOnline: false);
          return;
        }
      case StoredSession.valid:
        break;
    }
    await _loadArenas(); // offline: its fallback opens the last arena from disk
  }

  void _onAuthChange(AuthState state) {
    // The server ended the sign-in mid-shift (its refresh was refused): stop
    // and ask for a sign-in, as when access is turned off.
    if (state.event == AuthChangeEvent.signedOut && _phase == _Phase.ready) {
      unawaited(_signOut(reason: _expiredNotice));
    }
    // A fresh token after sync stopped on a token problem: carry on syncing
    // (never after access was turned off, and not while in the background).
    if (state.event == AuthChangeEvent.tokenRefreshed &&
        _phase == _Phase.ready &&
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      final engine = _binding?.engine;
      final status = engine?.status;
      if (engine != null &&
          status != null &&
          status.state == SyncState.authProblem &&
          !status.accessRevoked) {
        engine.start();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = _binding?.engine;
    final realtime = _binding?.realtime;
    if (engine == null) return;
    if (state == AppLifecycleState.resumed) {
      engine.start(); // also syncs at once: catch up after the pause
      if (realtime != null) unawaited(realtime.start());
      // Alerts may have rung, sessions may have moved on other devices while
      // this one slept: rebuild them from the database.
      _refreshRemindersSoon();
    } else if (state == AppLifecycleState.paused) {
      // Sends what is waiting before it stops (a session started just before
      // the phone was locked); session timers keep counting from their stored
      // times and their alerts are with the OS, so nothing else must run.
      unawaited(engine.pause());
      realtime?.stop();
    }
  }

  /// Rebuilds the device's alerts from the database, coalescing bursts (a
  /// sync that pulls many rows) and never running two rebuilds at once.
  void _refreshRemindersSoon() {
    final container = _container;
    if (container == null) return;
    _reminderDebounce?.cancel();
    _reminderDebounce = Timer(const Duration(milliseconds: 800), () {
      if (_container != container) return; // signed out or switched meanwhile
      // In the background (the pass pause() sends can pull rows) the alerts
      // already with the OS stand; resuming rebuilds them anyway.
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        return;
      }
      _reminderWork = _reminderWork.then((_) => refreshReminders(container));
    });
  }

  void _go(_Phase phase, {String? message}) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _message = message;
    });
  }

  /// [reopenLast]: with several arenas, go straight back to the one this
  /// person last worked in here (false when they asked for the list).
  Future<void> _loadArenas({bool reopenLast = true}) async {
    _go(_Phase.checking);
    final List<Membership> fetched;
    try {
      fetched = await fetchMemberships(_client);
    } on Object catch (e) {
      switch (classifyStartupFailure(
        e,
        hasSession: _client.auth.currentSession != null,
      )) {
        case StartupFailure.signInNeeded:
          // The sign-in itself was rejected: sign in again, never retry as
          // anon. Clearing it locally needs no network.
          try {
            await _client.auth.signOut(scope: SignOutScope.local);
          } on Object catch (_) {}
          _arenas = const [];
          await _dropDeviceAlerts();
          _go(_Phase.signIn, message: _expiredNotice);
        case StartupFailure.serverRefused:
          // Reachable and signed in, but refused: keep the sign-in.
          debugPrint('my_arenas refused: ${e.runtimeType}');
          _retry = () => _loadArenas(reopenLast: reopenLast);
          _go(_Phase.failed, message: arenaListFailureMessage(e));
        case StartupFailure.offline:
          // Offline (even if the access token needed refreshing): keep the
          // sign-in and open the last arena from disk. (Also when the list
          // was asked for: it cannot be had offline, and the floor must go
          // on.) The list last fetched for this login is kept.
          final last = await _lastArenaOnDisk();
          if (last != null) {
            await _open(last, confirmedOnline: false);
          } else {
            _retry = () => _loadArenas(reopenLast: reopenLast);
            _go(_Phase.failed, message: offlineMessage);
          }
      }
      return;
    }
    _arenas = fetched;
    final lastId = reopenLast ? (await _lastArenaOnDisk())?.arenaId : null;
    final arena = arenaToOpen(_arenas, lastId);
    if (arena != null) {
      await _open(arena);
      return;
    }
    // None (not invited yet, or every access turned off) or several: the list
    // says which, and only an active one can be opened. With none, this phone
    // follows no floor: alerts left from an earlier run go.
    if (!_arenas.any((a) => a.active)) await _dropDeviceAlerts();
    _go(_Phase.pickArena);
  }

  /// The arena this person last opened on this device, for offline starts.
  Future<Membership?> _lastArenaOnDisk() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final marker = File(
      '${widget.documentsPath}/arena_ops_cloud_last_${user.id}',
    );
    if (!marker.existsSync()) return null;
    final parts = marker.readAsStringSync().split('\n');
    if (parts.length < 2) return null;
    return (arenaId: parts[0], arenaName: parts[1], name: '', active: true);
  }

  /// Opens [arena]'s database on this device. [confirmedOnline]: my_arenas
  /// just reported this membership active (false for an offline start from
  /// the last arena on disk).
  Future<void> _open(Membership arena, {bool confirmedOnline = true}) async {
    final cleanUp = <Future<void> Function()>[];
    try {
      await _openArena(arena, confirmedOnline, cleanUp);
    } on Object catch (e, st) {
      // Never a dead "Opening…" spinner: close what was opened, offer a retry.
      debugPrint('opening ${arena.arenaName} failed: ${e.runtimeType}');
      unawaited(
        AppTelemetry.captureException(
          e,
          stackTrace: st,
          operation: 'cloud_open_arena',
        ),
      );
      for (final close in cleanUp.reversed) {
        try {
          await close().timeout(const Duration(seconds: 2));
        } on Object catch (_) {}
      }
      _retry = _retryOpen(arena, confirmedOnline);
      _go(
        _Phase.failed,
        message: "${arena.arenaName} couldn't be opened on this device. Try "
            'again; if it keeps happening, tell the maintainer.',
      );
    }
  }

  /// "Try again" after [arena] failed to open: that arena again if the server
  /// just listed it; after an offline start, the whole start (which fetches
  /// the list once online and still falls back to the disk offline).
  Future<void> Function() _retryOpen(Membership arena, bool confirmedOnline) =>
      confirmedOnline ? () => _open(arena) : _loadArenas;

  /// [cleanUp] collects how to close what has been opened so far; emptied once
  /// the arena is handed to the app.
  Future<void> _openArena(
    Membership arena,
    bool confirmedOnline,
    List<Future<void> Function()> cleanUp,
  ) async {
    _go(_Phase.opening, message: 'Opening ${arena.arenaName}…');
    final user = _client.auth.currentUser;
    if (user == null) {
      // The sign-in ended while choosing (refresh refused): never open as anon.
      _go(_Phase.signIn, message: _expiredNotice);
      return;
    }
    final dbPath = cloudDbPath(widget.documentsPath, arena.arenaId, user.id);
    final safety = await DbSafety.protect(
      dbFile: File(dbPath),
      appSchemaVersion: AppDatabase.expectedSchemaVersion,
      backupDir: Directory('${widget.documentsPath}/arena_ops-backups'),
      label: 'arena_ops_cloud_${arena.arenaId}',
    );
    if (!safety.safeToOpen) {
      if (_arenas.any((a) => a.active && a.arenaId != arena.arenaId)) {
        // Its data is kept as it is (backup + locked file); another arena can
        // still be worked in. Opening this one again shows the same.
        _go(
          _Phase.pickArena,
          message: "${arena.arenaName}'s data on this device needs the app's "
              'maintainer before it can open (nothing was changed or lost). '
              'You can open another arena.',
        );
        return;
      }
      setState(() => _locked = safety);
      return;
    }
    final db = AppDatabase(
      driftDatabase(
        name: 'arena_ops_cloud',
        native: DriftNativeOptions(databasePath: () async => dbPath),
      ),
    );
    cleanUp.add(db.close);
    final clock = OffsetClock(const SystemClock(), Duration.zero);
    late final RealtimeSync realtime;
    final engine = SyncEngine(
      db: db,
      transport: SupabaseSyncTransport(_client),
      arenaId: arena.arenaId,
      // Nudge the other devices only once the server has committed the ops
      // (never at record time, never for refused or unsent ones).
      onPushed: (kinds) => unawaited(realtime.broadcastSync(kinds: kinds)),
    );
    realtime = RealtimeSync(
      client: _client,
      arenaId: arena.arenaId,
      clock: clock,
      onSyncNeeded: engine.syncIfRunning,
    );
    cleanUp
      ..add(engine.dispose)
      ..add(realtime.dispose);
    final recorder = SyncRecorder(
      db,
      actor: () => user.id,
      clock: clock,
      onRecorded: engine.nudge,
    );

    // First open on this device: the arena must come down before anything
    // can be shown (there is no local catalog to fall back on).
    final cursor = await (db.select(
      db.syncMeta,
    )..where((t) => t.key.equals(SyncEngine.cursorKey))).getSingleOrNull();
    if (cursor == null) {
      _go(_Phase.opening, message: 'Downloading ${arena.arenaName}…');
      final first = await engine.syncNow();
      if (first.endedIn != SyncState.synced) {
        await realtime.dispose();
        await engine.dispose();
        await db.close();
        debugPrint('first download ended in ${first.endedIn}');
        _retry = _retryOpen(arena, confirmedOnline);
        _go(
          _Phase.failed,
          message: firstDownloadFailureMessage(engine.status, arena.arenaName),
        );
        return;
      }
    }
    final access = await confirmAccess(
      db: db,
      userId: user.id,
      confirmedOnline: confirmedOnline,
      sync: () => engine.syncNow(),
    );
    final AppUser me;
    switch (access) {
      case AccessGranted(user: final granted):
        me = granted;
      case AccessTurnedOff():
        await realtime.dispose();
        await engine.dispose();
        await db.close();
        await _dropDeviceAlerts();
        _go(
          _Phase.pickArena,
          message: 'Your access to ${arena.arenaName} is turned off. Ask the '
              'owner.',
        );
        return;
      case AccessNotOnDevice():
        await realtime.dispose();
        await engine.dispose();
        await db.close();
        _retry = _retryOpen(arena, confirmedOnline);
        _go(
          _Phase.failed,
          message: "Your profile in ${arena.arenaName} hasn't reached this "
              'device yet. Check the connection, then try again.',
        );
        return;
    }
    File('${widget.documentsPath}/arena_ops_cloud_last_${user.id}')
        .writeAsStringSync('${arena.arenaId}\n${arena.arenaName}');

    final binding = CloudBinding(
      arenaId: arena.arenaId,
      arenaName: arena.arenaName,
      userId: user.id,
      email: user.email ?? '',
      engine: engine,
      recorder: recorder,
      clock: clock,
      signOut: () => _signOut(),
      changePassword: (password) =>
          _client.auth.updateUser(UserAttributes(password: password)),
      realtime: realtime,
      // After an offline start the list is unknown: offer it, as the only way
      // to another arena until the next online start.
      switchArena:
          !confirmedOnline || _arenas.where((a) => a.active).length > 1
          ? _switchArena
          : null,
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        cloudBindingProvider.overrideWithValue(binding),
        clockProvider.overrideWithValue(clock),
        // Own closed bills and editing them (bill_edit): online only.
        myBillsRepositoryProvider.overrideWithValue(
          SupabaseMyBillsRepository(
            client: _client,
            transport: SupabaseSyncTransport(_client),
            arenaId: arena.arenaId,
            deviceId: engine.deviceId,
            onChanged: () => unawaited(
                realtime.broadcastSync(kinds: const ['bill.adjust'])),
          ),
        ),
        // Own details and the staff terms: online only.
        profileRepositoryProvider.overrideWithValue(
          SupabaseProfileRepository(
            client: _client,
            transport: SupabaseSyncTransport(_client),
            arenaId: arena.arenaId,
            userId: user.id,
            deviceId: engine.deviceId,
          ),
        ),
        authControllerProvider.overrideWith(() => CloudAuthController(me)),
        clockOffsetProvider.overrideWith((ref) {
          final offset =
              ref.watch(_serverOffsetProvider).value ?? Duration.zero;
          return ClockOffset(offset);
        }),
      ],
    );
    // Follow the server clock once it is off by more than the warning
    // threshold — then every device stamps sessions on the same clock.
    _statusSub = engine.statusStream.listen((s) {
      unawaited(_applyClockOffset(db, clock));
      // Revoked on the server: stop at once rather than keep working on stale
      // permissions. Unsent work stays in this person's database file.
      if (s.accessRevoked) unawaited(_signOut(reason: s.message));
    });
    await _applyClockOffset(db, clock);
    engine.start();
    unawaited(realtime.start());
    _db = db;
    _binding = binding;
    _container = container;
    cleanUp.clear(); // from here, _teardown closes them
    // Alerts follow the floor: another device ending, extending or moving a
    // session reaches this one through sync, and its alerts move with it.
    _dataSub = engine.dataChanged.listen((_) => _refreshRemindersSoon());
    _alertsOffset = clock.offset;
    _reminderWork = _reminderWork.then((_) => startReminders(container));
    _go(_Phase.ready);
    // The sign-in may have ended while this opened (a refresh the server
    // refused after an offline start): its signedOut event came before ready
    // and was not acted on.
    if (_client.auth.currentSession?.user.id != user.id) {
      unawaited(_signOut(reason: _expiredNotice));
    }
  }

  Future<void> _applyClockOffset(AppDatabase db, OffsetClock clock) async {
    final row = await (db.select(
      db.syncMeta,
    )..where((t) => t.key.equals(SyncEngine.clockOffsetKey))).getSingleOrNull();
    final measured = Duration(
      milliseconds: int.tryParse(row?.value ?? '') ?? 0,
    );
    clock.offset = ClockOffset(measured).isSignificant
        ? measured
        : Duration.zero;
    // Alert times are converted to the device clock with the offset. Each
    // measurement carries network latency, so only a real move (the clock was
    // corrected, or drifted) reschedules them — not every sync pass.
    if ((clock.offset - _alertsOffset).abs() >= const Duration(seconds: 5)) {
      _alertsOffset = clock.offset;
      _refreshRemindersSoon();
    }
  }

  Future<void> _teardown() async {
    await _statusSub?.cancel();
    _statusSub = null;
    await _dataSub?.cancel();
    _dataSub = null;
    _reminderDebounce?.cancel();
    final realtime = _binding?.realtime;
    final engine = _binding?.engine;
    _binding = null;
    final container = _container;
    _container = null;
    final db = _db;
    _db = null;
    try {
      await realtime?.dispose().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('realtime dispose warning: $e');
    }
    try {
      // Last chance to send what is waiting before this database closes.
      await engine?.pause().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('engine flush warning: $e');
    }
    try {
      await engine?.dispose().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('engine dispose warning: $e');
    }
    try {
      // A rebuild still reading this container must finish before it goes.
      await _reminderWork.timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('reminder work warning: $e');
    }
    try {
      container?.dispose();
    } catch (e) {
      debugPrint('container dispose warning: $e');
    }
    try {
      await db?.close().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('db close warning: $e');
    }
  }

  Future<void> _signOut({String? reason}) async {
    if (_phase != _Phase.ready &&
        _phase != _Phase.pickArena &&
        _phase != _Phase.failed) {
      return;
    }
    // Sign in shows only once the old arena is closed and signed out: a
    // quick next sign-in must not be caught by this sign-out.
    _go(_Phase.checking, message: 'Signing out…');
    await _leaveArena();
    try {
      await _client.auth.signOut().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('SignOut auth warning: $e');
    }
    _arenas = const [];
    _go(_Phase.signIn, message: reason);
  }

  /// Back to the arena list, still signed in (only offered with 2+ arenas).
  Future<void> _switchArena() async {
    if (_phase != _Phase.ready) return;
    _go(_Phase.checking, message: 'Closing ${_binding?.arenaName ?? ''}…');
    await _leaveArena();
    await _loadArenas(reopenLast: false);
  }

  /// Closes the open arena. Its alerts are cancelled too: this device stops
  /// following that floor, so it could no longer move or stop them when a
  /// session is extended or ended elsewhere. Opening an arena (after signing
  /// in again) schedules them afresh from its database.
  Future<void> _leaveArena() async {
    try {
      await _teardown();
    } catch (e) {
      debugPrint('SignOut teardown warning: $e');
    }
    await _dropDeviceAlerts();
  }

  /// Cancels every scheduled alert on this phone (delivered ones stay in the
  /// tray): used when it no longer follows any floor — signed out, access
  /// turned off, no arena — so nothing stale rings later.
  Future<void> _dropDeviceAlerts() async {
    try {
      await (_alerts ??= LocalNotificationService()).cancelAll();
    } catch (e) {
      debugPrint('alert clean-up warning: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    if (locked != null) return DatabaseLockedApp(report: locked);
    final container = _container;
    if (_phase == _Phase.ready && container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: const ArenaOpsApp(),
      );
    }
    return MaterialApp(
      title: 'ARQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: switch (_phase) {
        _Phase.signIn => CloudSignInScreen(
          signIn: (email, password) =>
              _client.auth.signInWithPassword(email: email, password: password),
          onSignedIn: _loadArenas,
          notice: _message,
        ),
        _Phase.pickArena => CloudArenaPickScreen(
          arenas: _arenas,
          message: _message,
          email: _client.auth.currentUser?.email ?? '',
          onPick: _open,
          onRefresh: () => _loadArenas(reopenLast: false),
          onSignOut: () => _signOut(),
        ),
        _Phase.failed => _Message(
          text: _message ?? 'Something went wrong.',
          action: 'Try again',
          // The step that failed, again: the arena list, or the arena that
          // was being opened (not the last one used, if that is another).
          onAction: () => _retry(),
          secondaryAction: 'Sign in again',
          onSecondaryAction: () => _signOut(),
        ),
        _ => _Message(text: _message ?? 'Checking your account…'),
      },
    );
  }
}

final _serverOffsetProvider = StreamProvider<Duration>((ref) async* {
  final binding = ref.watch(cloudBindingProvider);
  if (binding == null) return;
  final db = ref.watch(databaseProvider);
  yield* (db.select(db.syncMeta)
        ..where((t) => t.key.equals(SyncEngine.clockOffsetKey)))
      .watchSingleOrNull()
      .map((r) => Duration(milliseconds: int.tryParse(r?.value ?? '') ?? 0));
});

// ------------------------------------------------------------------ screens

/// The cloud-mode entry screen: sign in, nothing else. Staff use the e-mail
/// they were invited with and the password they chose when accepting the
/// invitation (admin dashboard → Users → Invite user).
class CloudSignInScreen extends StatefulWidget {
  const CloudSignInScreen({
    required this.signIn,
    required this.onSignedIn,
    this.notice,
    super.key,
  });

  /// Signs in with e-mail + password (Supabase in the app; a fake in tests).
  final Future<void> Function(String email, String password) signIn;
  final Future<void> Function() onSignedIn;

  /// Why the device came back here (e.g. access turned off), if it was not
  /// the person's own choice.
  final String? notice;

  @override
  State<CloudSignInScreen> createState() => _CloudSignInScreenState();
}

class _CloudSignInScreenState extends State<CloudSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your e-mail and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.signIn(email, _password.text);
    } on Object catch (e) {
      // A refused sign-in is never retried on its own; the typed e-mail stays.
      if (mounted) setState(() => _error = signInFailureMessage(e));
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      await widget.onSignedIn();
    } on Object catch (_) {
      if (mounted) setState(() => _error = "Couldn't load your arenas. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Credentials are entered here: Session Replay pauses while it is open.
  @override
  Widget build(BuildContext context) => ReplayPause(child: _screen(context));

  Widget _screen(BuildContext context) {
    final arena = context.arena;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(
                  'Sign in',
                  style: ArenaType.h1.copyWith(color: arena.text),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Use the e-mail you were invited with and the password you '
                  'chose when you accepted the invitation. Not invited yet? '
                  'Ask the owner.',
                  style: ArenaType.body.copyWith(color: arena.textMuted),
                ),
                if (widget.notice != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    widget.notice!,
                    style: ArenaType.label.copyWith(color: arena.warning),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  key: const Key('cloud-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('cloud-password'),
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password'),
                  onSubmitted: (_) => _busy ? null : _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: ArenaType.label.copyWith(color: arena.danger),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The arenas this login belongs to. Arenas are not created here: owners
/// register and create their arena on the admin dashboard.
class CloudArenaPickScreen extends StatelessWidget {
  const CloudArenaPickScreen({
    required this.arenas,
    required this.email,
    required this.onPick,
    required this.onRefresh,
    required this.onSignOut,
    this.message,
    super.key,
  });

  final List<Membership> arenas;
  final String email;
  final String? message;
  final Future<void> Function(Membership) onPick;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              'Your arenas',
              style: ArenaType.h1.copyWith(color: arena.text),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Signed in as $email',
              style: ArenaType.caption.copyWith(color: arena.textMuted),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                message!,
                style: ArenaType.label.copyWith(color: arena.warning),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            for (final a in arenas)
              ListTile(
                title: Text(a.arenaName),
                subtitle: Text(a.active ? a.name : 'Access turned off'),
                enabled: a.active,
                trailing: const Icon(Icons.chevron_right),
                onTap: a.active ? () => onPick(a) : null,
              ),
            if (arenas.isEmpty)
              Text(
                'This login has no arena yet. Ask the owner to invite $email '
                'from the owner dashboard (Users → Invite user), open the '
                'invitation e-mail and accept it, then tap Refresh.',
                style: ArenaType.body.copyWith(color: arena.textMuted),
              )
            else if (!arenas.any((a) => a.active))
              Text(
                'Your access is turned off everywhere. Ask the owner to turn '
                'it back on, then tap Refresh.',
                style: ArenaType.body.copyWith(color: arena.textMuted),
              ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRefresh, child: const Text('Refresh')),
            const SizedBox(height: AppSpacing.xxl),
            TextButton(onPressed: onSignOut, child: const Text('Sign out')),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.action,
    this.onAction,
    this.secondaryAction,
    this.onSecondaryAction,
  });
  final String text;
  final String? action;
  final Future<void> Function()? onAction;
  final String? secondaryAction;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final arena = context.arena;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action == null) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: ArenaType.body.copyWith(color: arena.text),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(onPressed: onAction, child: Text(action!)),
                ],
                if (secondaryAction != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: onSecondaryAction,
                    child: Text(secondaryAction!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
