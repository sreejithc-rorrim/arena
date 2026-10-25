import 'dart:async';

import 'package:arena_ops/core/clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Realtime nudges for the floor app.
///
/// Joins the arena's PRIVATE channel `arena:<arena_id>` (Supabase Realtime
/// Authorization: the realtime.messages policies admit only active members of
/// that arena, supabase/schemas/realtime/policies.sql). On it:
///  * Postgres Changes for the arena's published tables, INSERT and UPDATE only
///    and filtered by `arena_id` — Supabase neither RLS-checks nor filters
///    DELETE events, so those would carry other arenas' row ids; deletions
///    arrive as the broadcast nudge instead;
///  * the `sync` broadcast that other devices (and the dashboard) send after
///    the server has committed their ops.
/// Every event only asks the [SyncEngine] for a pass ([onSyncNeeded]); no
/// payload is ever applied — data still comes only from the authorized
/// `sync_pull`. Bursts are coalesced with a debounce, and a reconnect triggers a
/// catch-up pass (the pull cursor recovers anything missed while away).
class RealtimeSync {
  RealtimeSync({
    required this.client,
    required this.arenaId,
    required this.onSyncNeeded,
    this.clock = const SystemClock(),
    this.debounceDuration = const Duration(milliseconds: 150),
    this.onSubscribed,
    this.authorize,
  });

  final SupabaseClient client;
  final String arenaId;
  final Future<void> Function() onSyncNeeded;
  final Clock clock;
  final Duration debounceDuration;

  /// Called each time the channel is joined (first join and every rejoin).
  final void Function()? onSubscribed;

  /// Hands the signed-in user's JWT to the Realtime socket before joining (a
  /// private channel needs it). Defaults to the client's current session.
  final Future<void> Function()? authorize;

  RealtimeChannel? _channel;
  Timer? _debounce;
  bool _started = false;
  bool _subscribedOnce = false;

  /// The published tables (supabase/schemas/_cluster/publications.sql) whose
  /// changes this device pulls promptly instead of waiting for the next poll.
  static const List<String> listenedTables = [
    'activities',
    'billing_policies',
    'bookings',
    'controller_allocations',
    'controller_moves',
    'controllers',
    'customers',
    'game_categories',
    'game_controls',
    'game_resources',
    'games',
    'holidays',
    'payments',
    'rate_bands',
    'rate_cards',
    'rates',
    'resource_activities',
    'resources',
    'session_charges',
    'session_extensions',
    'session_segments',
    'sessions',
    'settings',
    'staff_profiles',
  ];

  /// Never DELETE (see the class comment).
  static const List<PostgresChangeEvent> listenedEvents = [
    PostgresChangeEvent.insert,
    PostgresChangeEvent.update,
  ];

  bool get isStarted => _started;

  /// Joins the arena channel. Calling it again while started does nothing; a
  /// start after [stop] replaces the old channel instead of stacking another.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _removeChannel();

    final channel = client.channel(
      'arena:$arenaId',
      opts: const RealtimeChannelConfig(private: true),
    );
    _channel = channel;

    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'arena_id',
      value: arenaId,
    );
    for (final table in listenedTables) {
      for (final event in listenedEvents) {
        channel.onPostgresChanges(
          event: event,
          schema: 'public',
          table: table,
          filter: filter,
          callback: (_) => _scheduleSync(),
        );
      }
    }

    channel.onBroadcast(
      event: 'sync',
      callback: (message) {
        // Only this arena's nudges (the channel is private, but be strict).
        if (nudgeOf(message)?['arena_id'] == arenaId) _scheduleSync();
      },
    );

    await _authorizeSocket();
    if (!_started || !identical(_channel, channel)) return; // stopped meanwhile
    channel.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Reconnected after a drop: catch up on anything missed.
        if (_subscribedOnce) _scheduleSync();
        _subscribedOnce = true;
        onSubscribed?.call();
      } else if (status == RealtimeSubscribeStatus.channelError) {
        // E.g. not (or no longer) a member: the 10 s poll still syncs.
        debugPrint('Realtime channel refused: $error');
      }
    });
  }

  Future<void> _authorizeSocket() async {
    try {
      final auth = authorize;
      if (auth != null) {
        await auth();
      } else {
        await client.realtime.setAuth(client.auth.currentSession?.accessToken);
      }
    } on Object catch (e) {
      // An expired token is replaced on the next refresh (supabase_flutter
      // calls setAuth on tokenRefreshed); joining just waits for it.
      debugPrint('Realtime auth not set yet: $e');
    }
  }

  /// Tells the arena's other devices and the dashboard that ops of [kinds]
  /// were just COMMITTED on the server (the engine calls this after a push the
  /// server applied). A nudge, not data: receivers pull or refetch.
  Future<void> broadcastSync({
    String? kind,
    List<String> kinds = const [],
  }) async {
    final channel = _channel;
    if (!_started || channel == null) return;
    try {
      // The Dart client sends the map it is given AS the message (adding
      // type/event to it); the JS client — the dashboard — sends and reads
      // {type, event, payload: {...}}. Wrap the nudge so both read it the same.
      await channel.sendBroadcastMessage(
        event: 'sync',
        payload: {
          'payload': {
            'arena_id': arenaId,
            'kind': kind ?? 'push',
            'kinds': kinds,
            'source': 'mobile',
            'at': clock.now().toUtc().toIso8601String(),
          },
        },
      );
    } on Object catch (e) {
      // Non-fatal: Postgres Changes and the poll still deliver the change.
      debugPrint('Realtime broadcast failed: $e');
    }
  }

  /// The nudge inside a received broadcast: `{type, event, payload: {...}}`
  /// as the dashboard (JS client) and this class send it, or the bare map an
  /// older floor app sent. Null when it carries no nudge.
  @visibleForTesting
  static Map<String, dynamic>? nudgeOf(Map<String, dynamic> message) {
    final inner = message['payload'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return message.containsKey('arena_id') ? message : null;
  }

  void _scheduleSync() {
    if (!_started) return;
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, () {
      if (!_started) return;
      unawaited(onSyncNeeded());
    });
  }

  /// Leaves the channel (app paused, signed out). [start] joins again.
  void stop() {
    _started = false;
    _debounce?.cancel();
    _debounce = null;
    final channel = _channel;
    if (channel != null) unawaited(channel.unsubscribe());
  }

  Future<void> _removeChannel() async {
    final channel = _channel;
    _channel = null;
    if (channel == null) return;
    try {
      await client.removeChannel(channel);
    } on Object catch (_) {
      // Already removed, or the client is disposed.
    }
  }

  /// Leaves and removes the channel for good.
  Future<void> dispose() async {
    stop();
    await _removeChannel();
  }
}
