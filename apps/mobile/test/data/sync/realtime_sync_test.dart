import 'package:arena_ops/core/clock/clock.dart';
import 'package:arena_ops/data/sync/realtime_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeRealtimeChannel extends Fake implements RealtimeChannel {
  final Map<String, void Function(Map<String, dynamic>)> broadcastCallbacks =
      {};
  final List<void Function(PostgresChangePayload)> postgresCallbacks = [];
  final List<({PostgresChangeEvent event, String? table, String? filterValue})>
  postgresSubs = [];
  final List<Map<String, dynamic>> sentBroadcasts = [];
  void Function(RealtimeSubscribeStatus, Object?)? subscribeCallback;
  bool isUnsubscribed = false;

  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    List<PostgresChangeFilter>? filters,
    List<String>? select,
    required void Function(PostgresChangePayload payload) callback,
  }) {
    postgresCallbacks.add(callback);
    postgresSubs.add((
      event: event,
      table: table,
      filterValue: filter?.value as String?,
    ));
    return this;
  }

  @override
  RealtimeChannel onBroadcast({
    required String event,
    required void Function(Map<String, dynamic>) callback,
  }) {
    broadcastCallbacks[event] = callback;
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus, Object?)? callback,
    Duration? timeout,
  ]) {
    subscribeCallback = callback;
    return this;
  }

  @override
  Future<String> unsubscribe([Duration? timeout]) async {
    isUnsubscribed = true;
    return 'ok';
  }

  @override
  Future<ChannelResponse> sendBroadcastMessage({
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    sentBroadcasts.add({'event': event, 'payload': payload});
    return ChannelResponse.ok;
  }

  void triggerPostgresChange() {
    final payload = PostgresChangePayload(
      eventType: PostgresChangeEvent.all,
      newRecord: {},
      oldRecord: {},
      schema: 'public',
      table: 'sessions',
      commitTimestamp: DateTime.now().toUtc(),
      errors: null,
    );
    for (final cb in postgresCallbacks) {
      cb(payload);
    }
  }

  void triggerBroadcast(String event, Map<String, dynamic> payload) {
    broadcastCallbacks[event]?.call(payload);
  }

  void triggerSubscribeStatus(RealtimeSubscribeStatus status) {
    subscribeCallback?.call(status, null);
  }
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final Map<String, FakeRealtimeChannel> channels = {};
  final Map<String, RealtimeChannelConfig> configs = {};
  final List<RealtimeChannel> removedChannels = [];

  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    final ch = FakeRealtimeChannel();
    channels[name] = ch;
    configs[name] = opts;
    return ch;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    removedChannels.add(channel);
    return 'ok';
  }
}

void main() {
  late FakeSupabaseClient client;
  late List<int> syncCalls;
  late int authorizeCalls;
  late RealtimeSync sync;

  setUp(() {
    client = FakeSupabaseClient();
    syncCalls = [];
    authorizeCalls = 0;
    sync = RealtimeSync(
      client: client,
      arenaId: 'arena_123',
      clock: FakeClock(DateTime.utc(2026, 10, 13, 12)),
      onSyncNeeded: () async {
        syncCalls.add(DateTime.now().millisecondsSinceEpoch);
      },
      debounceDuration: const Duration(milliseconds: 50),
      authorize: () async => authorizeCalls++,
    );
  });

  tearDown(() {
    sync.dispose();
  });

  test(
    'joins the PRIVATE arena channel, authorized before subscribing',
    () async {
      await sync.start();
      expect(sync.isStarted, isTrue);
      expect(client.channels.containsKey('arena:arena_123'), isTrue);
      expect(
        client.configs['arena:arena_123']!.private,
        isTrue,
        reason: 'only active members of the arena may join (realtime.messages policies)',
      );
      expect(
        authorizeCalls,
        1,
        reason: 'the JWT is handed to the socket before joining',
      );

      final channel = client.channels['arena:arena_123']!;
      expect(channel.broadcastCallbacks.containsKey('sync'), isTrue);
      expect(channel.subscribeCallback, isNotNull);
    },
  );

  test(
    'listens to INSERT and UPDATE of every published table, never DELETE',
    () async {
      await sync.start();
      final subs = client.channels['arena:arena_123']!.postgresSubs;
      expect(subs.map((s) => s.event).toSet(), {
        PostgresChangeEvent.insert,
        PostgresChangeEvent.update,
      }, reason: 'DELETE events are not RLS-checked or filtered by Supabase');
      expect(subs.where((s) => s.event == PostgresChangeEvent.delete), isEmpty);
      expect(subs.where((s) => s.event == PostgresChangeEvent.all), isEmpty);
      expect(
        subs.map((s) => s.table).toSet(),
        RealtimeSync.listenedTables.toSet(),
      );
      expect(
        subs.every((s) => s.filterValue == 'arena_123'),
        isTrue,
        reason: 'every subscription is filtered to this arena',
      );
      // The tables the audit found missing are now included.
      expect(
        RealtimeSync.listenedTables,
        containsAll(<String>[
          'game_resources',
          'game_controls',
          'staff_profiles',
          'holidays',
          'billing_policies',
          'session_charges',
          'session_extensions',
        ]),
      );
    },
  );

  test(
    'debounces rapid bursts of postgres changes into a single sync call',
    () async {
      await sync.start();
      final channel = client.channels['arena:arena_123']!;

      // Fire 5 change events rapidly
      channel.triggerPostgresChange();
      channel.triggerPostgresChange();
      channel.triggerPostgresChange();
      channel.triggerPostgresChange();
      channel.triggerPostgresChange();

      expect(syncCalls.length, equals(0));

      // Wait past debounce duration
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(syncCalls.length, equals(1));
    },
  );

  test(
    'syncs on broadcast from same arena and ignores different arena',
    () async {
      await sync.start();
      final channel = client.channels['arena:arena_123']!;

      // Broadcast from a different arena -> ignored
      channel.triggerBroadcast('sync', {'arena_id': 'other_arena'});
      // …and one that does not say which arena -> ignored too
      channel.triggerBroadcast('sync', {'kind': 'push'});
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(syncCalls.length, equals(0));

      // Broadcast from same arena -> triggers sync
      channel.triggerBroadcast('sync', {'arena_id': 'arena_123'});
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(syncCalls.length, equals(1));
    },
  );

  test('triggers catch-up sync on reconnection after disconnect', () async {
    await sync.start();
    final channel = client.channels['arena:arena_123']!;

    // First connect: marks subscribedOnce = true
    channel.triggerSubscribeStatus(RealtimeSubscribeStatus.subscribed);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(syncCalls.length, equals(0));

    // Reconnection event
    channel.triggerSubscribeStatus(RealtimeSubscribeStatus.subscribed);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(syncCalls.length, equals(1));
  });

  test('broadcastSync sends a minimal post-commit nudge: arena, kinds, source, time', () async {
    await sync.start();
    final channel = client.channels['arena:arena_123']!;

    await sync.broadcastSync(kinds: ['session.start', 'payment.record']);
    expect(channel.sentBroadcasts.length, equals(1));
    expect(channel.sentBroadcasts.first['event'], equals('sync'));
    final message =
        channel.sentBroadcasts.first['payload'] as Map<String, dynamic>;
    expect(message.keys, ['payload'],
        reason: 'the JS envelope {type, event, payload} the dashboard reads');
    expect(
      message['payload'],
      {
        'arena_id': 'arena_123',
        'kind': 'push',
        'kinds': ['session.start', 'payment.record'],
        'source': 'mobile',
        'at': '2026-10-13T12:00:00.000Z',
      },
      reason: 'no business data travels in the nudge; time comes from the injected clock',
    );
  });

  test('reads the nudge in the JS envelope and the legacy bare map, for this arena only',
      () async {
    await sync.start();
    final channel = client.channels['arena:arena_123']!;
    channel.triggerBroadcast('sync', {
      'type': 'broadcast',
      'event': 'sync',
      'payload': {'arena_id': 'other_arena', 'kinds': ['game.upsert']},
    });
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(syncCalls, isEmpty, reason: 'another arena, enveloped');
    channel.triggerBroadcast('sync', {
      'type': 'broadcast',
      'event': 'sync',
      'payload': {'arena_id': 'arena_123', 'kinds': ['game.upsert'], 'source': 'admin-web'},
    });
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(syncCalls.length, 1, reason: "the dashboard's enveloped nudge");
    expect(
      RealtimeSync.nudgeOf({'arena_id': 'arena_123', 'type': 'broadcast'})?['arena_id'],
      'arena_123',
      reason: "an older floor app's bare map",
    );
    expect(RealtimeSync.nudgeOf({'type': 'broadcast', 'event': 'sync'}), isNull);
  });

  test('a restart replaces the channel instead of stacking another', () async {
    await sync.start();
    final first = client.channels['arena:arena_123']!;
    sync.stop();
    await sync.start();
    expect(client.removedChannels, contains(first));
    expect(identical(client.channels['arena:arena_123'], first), isFalse);
  });

  test('stop and dispose unsubscribes and cleans up channel', () async {
    await sync.start();
    final channel = client.channels['arena:arena_123']!;

    sync.stop();
    expect(sync.isStarted, isFalse);
    expect(channel.isUnsubscribed, isTrue);

    await sync.dispose();
    expect(client.removedChannels.contains(channel), isTrue);
  });
}
