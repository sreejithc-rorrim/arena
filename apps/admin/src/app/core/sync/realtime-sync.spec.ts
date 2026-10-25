import { signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import type { RealtimeChannel, SupabaseClient } from '@supabase/supabase-js';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ArenaContext } from '../arena/arena-context';
import { Account } from '../auth/auth-api';
import { Session } from '../auth/session';
import { Router } from '@angular/router';
import { FloorStore } from '../floor/floor-store';
import { AccessoriesStore } from '../../features/accessories/data/accessories-store';
import { FloorOptionsStore } from '../../features/settings/data/floor-options';
import { OverviewStore } from '../../features/overview/data/overview-store';
import { PricingStore } from '../../features/pricing/data/pricing-store';
import { SalesStore } from '../../features/sales/data/sales-store';
import { TeamStore } from '../../features/team/data/team-store';
import { UsersStore } from '../../features/users/data/users-store';
import { Supabase } from '../supabase/supabase';
import { DEBOUNCE_MS, RealtimeSync, TABLE_TARGETS } from './realtime-sync';

/** Past the debounce window. */
const AFTER = DEBOUNCE_MS + 10;
type Mock = ReturnType<typeof vi.fn>;

describe('RealtimeSync', () => {
  let sync: RealtimeSync;
  let mockFloor: { load: Mock; refresh: Mock; stale: Mock };
  let mockSales: { refresh: Mock; stale: Mock };
  let mockOverview: { refresh: Mock; stale: Mock };
  let mockPricing: { refresh: Mock; stale: Mock };
  let mockFloorOptions: { refresh: Mock; stale: Mock };
  let mockUsers: { refresh: Mock; stale: Mock };
  let mockAccessories: { refresh: Mock; stale: Mock };
  let mockTeam: { refresh: Mock; stale: Mock };
  /** The screen the dashboard shows (RealtimeSync reloads only what it needs). */
  const router = { url: '/sales' };
  let mockArenaContext: { current: ReturnType<typeof vi.fn>; load: ReturnType<typeof vi.fn> };
  let user: ReturnType<typeof signal<Account | null>>;
  let sessionToken: string | null;
  const order: string[] = [];

  /** Last handler per table (any event), and every subscription made. */
  const postgresHandlers = new Map<string, (payload: unknown) => void>();
  const subscriptions: { table: string; event: string; filter: string; schema: string }[] = [];
  const broadcastHandlers = new Map<string, (payload: unknown) => void>();
  let channelSubscribeCallback: ((status: string) => void) | null = null;
  const mockChannel = {
    on: vi.fn((type: string, filter: unknown, cb: (payload: unknown) => void) => {
      if (type === 'postgres_changes') {
        const f = filter as { table: string; event: string; filter: string; schema: string };
        postgresHandlers.set(f.table, cb);
        subscriptions.push({ table: f.table, event: f.event, filter: f.filter, schema: f.schema });
      } else if (type === 'broadcast') {
        const event = (filter as { event: string }).event;
        broadcastHandlers.set(event, cb);
      }
      return mockChannel;
    }),
    subscribe: vi.fn((cb?: (status: string) => void) => {
      order.push('subscribe');
      if (cb) channelSubscribeCallback = cb;
      return mockChannel;
    }),
    send: vi.fn().mockResolvedValue('ok'),
  } as unknown as RealtimeChannel;

  const mockClient = {
    channel: vi.fn().mockReturnValue(mockChannel),
    removeChannel: vi.fn().mockResolvedValue('ok'),
    auth: {
      getSession: vi.fn(async () => ({
        data: { session: sessionToken ? { access_token: sessionToken } : null },
      })),
    },
    realtime: {
      setAuth: vi.fn(async () => {
        order.push('setAuth');
      }),
    },
  } as unknown as SupabaseClient;

  beforeEach(() => {
    vi.useFakeTimers();
    postgresHandlers.clear();
    subscriptions.length = 0;
    broadcastHandlers.clear();
    order.length = 0;
    channelSubscribeCallback = null;
    sessionToken = 'jwt-of-arjun';
    vi.clearAllMocks();

    const store = () => ({ refresh: vi.fn().mockResolvedValue(undefined), stale: vi.fn() });
    mockFloor = { load: vi.fn().mockResolvedValue(undefined), ...store() };
    mockSales = store();
    mockOverview = store();
    mockPricing = store();
    mockFloorOptions = store();
    mockUsers = store();
    mockAccessories = store();
    mockTeam = store();
    router.url = '/sales';
    user = signal<Account | null>({ id: 'u0', email: 'arjun@404arena.in', name: 'Arjun Mehra' });

    mockArenaContext = {
      current: vi.fn().mockReturnValue({ id: 'arena-123', name: 'Test Arena' }),
      load: vi.fn().mockResolvedValue(undefined),
    };

    const mockSupabase = {
      misconfigured: false,
      client: vi.fn().mockResolvedValue(mockClient),
    };

    TestBed.configureTestingModule({
      providers: [
        RealtimeSync,
        { provide: ArenaContext, useValue: mockArenaContext },
        { provide: Session, useValue: { user } },
        { provide: Supabase, useValue: mockSupabase },
        { provide: FloorStore, useValue: mockFloor },
        { provide: SalesStore, useValue: mockSales },
        { provide: OverviewStore, useValue: mockOverview },
        { provide: PricingStore, useValue: mockPricing },
        { provide: FloorOptionsStore, useValue: mockFloorOptions },
        { provide: UsersStore, useValue: mockUsers },
        { provide: AccessoriesStore, useValue: mockAccessories },
        { provide: TeamStore, useValue: mockTeam },
        { provide: Router, useValue: router },
      ],
    });

    sync = TestBed.inject(RealtimeSync);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  const broadcast = (payload: unknown) => broadcastHandlers.get('sync')!({ payload });

  it('subscribes to channel arena:arena-123 with postgres changes and broadcast', async () => {
    await sync.setupArena('arena-123', true);

    expect(mockClient.channel).toHaveBeenCalledWith('arena:arena-123', {
      config: { private: true },
    });
    expect(mockChannel.subscribe).toHaveBeenCalled();
    expect(postgresHandlers.has('sessions')).toBe(true);
    expect(postgresHandlers.has('payments')).toBe(true);
    expect(postgresHandlers.has('games')).toBe(true);
    expect(postgresHandlers.has('resources')).toBe(true);
    expect(postgresHandlers.has('settings')).toBe(true);
    expect(broadcastHandlers.has('sync')).toBe(true);
  });

  it('joins the private channel only after handing Realtime the user JWT', async () => {
    await sync.setupArena('arena-123', true);
    expect(mockClient.realtime.setAuth).toHaveBeenCalledWith('jwt-of-arjun');
    expect(order).toEqual(['setAuth', 'subscribe']);
  });

  it('opens no channel without a session', async () => {
    sessionToken = null;
    await sync.setupArena('arena-123', true);
    expect(mockClient.channel).not.toHaveBeenCalled();
  });

  it('subscribes INSERT and UPDATE of every shown table, filtered by arena — never DELETE', async () => {
    await sync.setupArena('arena-123', true);

    const events = new Set(subscriptions.map((s) => s.event));
    expect(events).toEqual(new Set(['INSERT', 'UPDATE']));
    expect(subscriptions.every((s) => s.filter === 'arena_id=eq.arena-123')).toBe(true);
    expect(subscriptions.every((s) => s.schema === 'public')).toBe(true);
    const tables = [...new Set(subscriptions.map((s) => s.table))].sort();
    expect(tables).toEqual(
      [
        'accessory_kinds',
        'activities',
        'bill_discounts',
        'billing_policies',
        'controllers',
        'discounts',
        'pricing_rules',
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
      ].sort(),
    );
    expect(tables).toEqual(Object.keys(TABLE_TARGETS).sort());
    for (const table of tables) {
      expect(subscriptions.filter((s) => s.table === table).map((s) => s.event)).toEqual([
        'INSERT',
        'UPDATE',
      ]);
    }
  });

  it('coalesces a burst of session changes into one reload of the open screen', async () => {
    router.url = '/overview?period=7d';
    await sync.setupArena('arena-123', true);

    const onSessions = postgresHandlers.get('sessions')!;
    const onSegments = postgresHandlers.get('session_segments')!;

    onSessions({ eventType: 'INSERT' });
    onSegments({ eventType: 'INSERT' });
    onSessions({ eventType: 'UPDATE' });

    vi.advanceTimersByTime(DEBOUNCE_MS - 50);
    expect(mockFloor.refresh).not.toHaveBeenCalled();

    vi.advanceTimersByTime(60);
    expect(mockFloor.refresh).toHaveBeenCalledTimes(1);
    expect(mockFloor.refresh).toHaveBeenCalledWith(['live', 'stationFigures', 'gameFigures']);
    expect(mockOverview.refresh).toHaveBeenCalledTimes(1);
    // Sales is not on screen: marked out of date, not downloaded.
    expect(mockSales.refresh).not.toHaveBeenCalled();
    expect(mockSales.stale).toHaveBeenCalledTimes(1);
  });

  it('only marks stores out of date when no screen shows them', async () => {
    router.url = '/settings?id=billing';
    await sync.setupArena('arena-123', true);
    postgresHandlers.get('sessions')!({ eventType: 'INSERT' });
    postgresHandlers.get('controllers')!({ eventType: 'UPDATE' });
    vi.advanceTimersByTime(AFTER);

    expect(mockFloor.refresh).not.toHaveBeenCalled();
    expect(mockFloor.stale).toHaveBeenCalledWith(['live', 'stationFigures', 'gameFigures']);
    expect(mockSales.refresh).not.toHaveBeenCalled();
    expect(mockSales.stale).toHaveBeenCalled();
    expect(mockOverview.stale).toHaveBeenCalled();
    // Settings shows accessory types: those reload.
    expect(mockAccessories.refresh).toHaveBeenCalledTimes(1);
  });

  it('reloads games when game table changes occur', async () => {
    router.url = '/settings/games';
    await sync.setupArena('arena-123', true);

    const onGames = postgresHandlers.get('games')!;
    onGames({ eventType: 'UPDATE' });

    vi.advanceTimersByTime(AFTER);
    expect(mockFloor.refresh).toHaveBeenCalledWith(['games']);
    expect(mockSales.refresh).not.toHaveBeenCalled();
  });

  it('reloads stations when resources table changes occur', async () => {
    router.url = '/stations';
    await sync.setupArena('arena-123', true);

    const onResources = postgresHandlers.get('resources')!;
    onResources({ eventType: 'UPDATE' });

    vi.advanceTimersByTime(AFTER);
    expect(mockFloor.refresh).toHaveBeenCalledWith(['stations', 'stationFigures']);
  });

  it('reloads floor options when settings table changes occur', async () => {
    router.url = '/settings';
    await sync.setupArena('arena-123', true);

    const onSettings = postgresHandlers.get('settings')!;
    onSettings({ eventType: 'UPDATE' });

    vi.advanceTimersByTime(AFTER);
    expect(mockFloorOptions.refresh).toHaveBeenCalledTimes(1);
    // Opening hours are settings rows: pricing reloads too.
    expect(mockPricing.refresh).toHaveBeenCalledTimes(1);
  });

  it('routes the published tables to the stores that show them', async () => {
    await sync.setupArena('arena-123', true);
    const fire = (table: string, on: string) => {
      vi.clearAllMocks();
      router.url = on;
      postgresHandlers.get(table)!({ eventType: 'INSERT' });
      vi.advanceTimersByTime(AFTER);
    };

    fire('game_resources', '/settings/games');
    expect(mockFloor.refresh).toHaveBeenCalledWith(['gameResources']);
    expect(mockFloor.refresh).not.toHaveBeenCalledWith(['games']);

    fire('game_controls', '/settings/games');
    expect(mockFloor.refresh).toHaveBeenCalledWith(['games']);
    fire('game_categories', '/settings/games');
    expect(mockFloor.refresh).toHaveBeenCalledWith(['games']);

    fire('staff_profiles', '/staff/team');
    expect(mockUsers.refresh).toHaveBeenCalledTimes(1);
    // It may be the signed-in login's own row: its access is read again too.
    expect(mockArenaContext.load).toHaveBeenCalledWith(true);
    expect(mockSales.refresh).not.toHaveBeenCalled();

    for (const table of ['session_charges', 'bill_discounts']) {
      fire(table, '/sales');
      expect(mockSales.refresh).toHaveBeenCalledTimes(1);
      expect(mockOverview.stale).toHaveBeenCalledTimes(1);
    }
    fire('session_charges', '/stations');
    expect(mockFloor.refresh).toHaveBeenCalledWith(['stationFigures']);

    fire('session_extensions', '/sales');
    expect(mockSales.refresh).toHaveBeenCalledTimes(1);
    expect(mockOverview.stale).toHaveBeenCalledTimes(1);

    for (const table of [
      'holidays',
      'billing_policies',
      'rate_cards',
      'rate_bands',
      'rates',
      'pricing_rules',
      'discounts',
    ]) {
      fire(table, '/pricing');
      expect(mockPricing.refresh).toHaveBeenCalledTimes(1);
      expect(mockFloorOptions.stale).toHaveBeenCalledTimes(1);
      expect(mockSales.refresh).not.toHaveBeenCalled();
    }

    // An accessory moved, lent or edited on the floor: the Stations screen re-reads it.
    fire('controllers', '/stations');
    expect(mockAccessories.refresh).toHaveBeenCalledTimes(1);
    expect(mockFloor.refresh).toHaveBeenCalledWith(['stations', 'stationFigures']);
    expect(mockPricing.refresh).not.toHaveBeenCalled();

    fire('accessory_kinds', '/settings');
    expect(mockAccessories.refresh).toHaveBeenCalledTimes(1);
  });

  it('handles peer broadcast sync messages for matching arena', async () => {
    router.url = '/overview';
    await sync.setupArena('arena-123', true);

    const onBroadcast = broadcastHandlers.get('sync')!;
    onBroadcast({
      payload: { arena_id: 'arena-123', kind: 'session.start' },
    });

    vi.advanceTimersByTime(AFTER);
    expect(mockFloor.refresh).toHaveBeenCalledWith(['live', 'stationFigures', 'gameFigures']);
    expect(mockOverview.refresh).toHaveBeenCalledTimes(1);
  });

  it('routes a committed push by its applied kinds', async () => {
    router.url = '/settings/games';
    await sync.setupArena('arena-123', true);
    broadcast({
      arena_id: 'arena-123',
      kind: 'push',
      kinds: ['game.set_compat', 'staff.update', 'controller.move'],
      source: 'mobile',
      at: '2026-10-13T14:00:00Z',
    });
    vi.advanceTimersByTime(AFTER);

    expect(mockFloor.refresh).toHaveBeenCalledWith(['gameResources']);
    expect(mockUsers.stale).toHaveBeenCalledTimes(1);
    expect(mockAccessories.stale).toHaveBeenCalledTimes(1);
    expect(mockFloor.refresh).not.toHaveBeenCalledWith(['games']);
    expect(mockSales.refresh).not.toHaveBeenCalled();
    expect(mockPricing.refresh).not.toHaveBeenCalled();
    expect(mockPricing.stale).not.toHaveBeenCalled();
  });

  it('routes rule, discount and accessory-kind pushes to pricing and accessories', async () => {
    router.url = '/pricing';
    await sync.setupArena('arena-123', true);
    broadcast({
      arena_id: 'arena-123',
      kind: 'push',
      kinds: ['rule.upsert', 'discount.set_active', 'accessory_kind.upsert'],
      source: 'admin-web',
    });
    vi.advanceTimersByTime(AFTER);
    expect(mockPricing.refresh).toHaveBeenCalledTimes(1);
    expect(mockAccessories.stale).toHaveBeenCalledTimes(1);
    expect(mockSales.stale).not.toHaveBeenCalled();
  });

  it('a staff change pushed elsewhere re-reads the login’s own access (deactivation arrives only so)', async () => {
    router.url = '/staff/team';
    await sync.setupArena('arena-123', true);
    broadcast({
      arena_id: 'arena-123',
      kind: 'push',
      kinds: ['staff.update'],
      source: 'admin-web',
    });
    vi.advanceTimersByTime(AFTER);
    expect(mockArenaContext.load).toHaveBeenCalledWith(true);
    expect(mockUsers.refresh).toHaveBeenCalledTimes(1);
    expect(mockFloor.refresh).not.toHaveBeenCalled();
    expect(mockPricing.refresh).not.toHaveBeenCalled();
  });

  it('a refused or dropped channel re-reads the login’s own access, nothing else', async () => {
    await sync.setupArena('arena-123', true);
    channelSubscribeCallback!('CHANNEL_ERROR');
    vi.advanceTimersByTime(AFTER);
    expect(mockArenaContext.load).toHaveBeenCalledWith(true);
    expect(mockFloor.refresh).not.toHaveBeenCalled();
    expect(mockSales.refresh).not.toHaveBeenCalled();
    expect(mockUsers.refresh).not.toHaveBeenCalled();
  });

  it('a push of settings or payments refreshes pricing or the bills', async () => {
    router.url = '/settings';
    await sync.setupArena('arena-123', true);
    broadcast({ arena_id: 'arena-123', kind: 'push', kinds: ['settings.save'], source: 'mobile' });
    vi.advanceTimersByTime(AFTER);
    expect(mockPricing.refresh).toHaveBeenCalledTimes(1);
    expect(mockFloorOptions.refresh).toHaveBeenCalledTimes(1);

    vi.clearAllMocks();
    router.url = '/sales';
    broadcast({ arena_id: 'arena-123', kind: 'push', kinds: ['payment.record'], source: 'mobile' });
    vi.advanceTimersByTime(AFTER);
    expect(mockSales.refresh).toHaveBeenCalledTimes(1);
    expect(mockOverview.stale).toHaveBeenCalledTimes(1);
    expect(mockPricing.refresh).not.toHaveBeenCalled();
  });

  it('reads a bare-map nudge (an older floor app) as the nudge itself', async () => {
    await sync.setupArena('arena-123', true);
    broadcastHandlers.get('sync')!({
      type: 'broadcast',
      event: 'sync',
      arena_id: 'arena-123',
      kind: 'push',
      kinds: ['payment.record'],
      source: 'mobile',
    });
    vi.advanceTimersByTime(AFTER);
    expect(mockSales.refresh).toHaveBeenCalledTimes(1);

    vi.clearAllMocks();
    broadcastHandlers.get('sync')!({
      type: 'broadcast',
      event: 'sync',
      arena_id: 'other',
      kind: 'push',
    });
    vi.advanceTimersByTime(AFTER);
    expect(mockSales.refresh).not.toHaveBeenCalled();
  });

  it('falls back to everything when a push names no kinds: the open screen reloads', async () => {
    router.url = '/stations';
    await sync.setupArena('arena-123', true);
    broadcast({ arena_id: 'arena-123', kind: 'push', source: 'mobile' });
    vi.advanceTimersByTime(AFTER);

    expect(mockFloor.refresh).toHaveBeenCalledWith(['live', 'stationFigures', 'gameFigures']);
    expect(mockFloor.refresh).toHaveBeenCalledWith(['stations', 'stationFigures']);
    expect(mockFloor.refresh).toHaveBeenCalledWith(['games']);
    expect(mockPricing.refresh).toHaveBeenCalled();
    expect(mockAccessories.refresh).toHaveBeenCalled();
    expect(mockSales.stale).toHaveBeenCalled();
    expect(mockOverview.stale).toHaveBeenCalled();
    expect(mockUsers.stale).toHaveBeenCalled();
  });

  it('ignores peer broadcast messages from a different arena', async () => {
    await sync.setupArena('arena-123', true);

    const onBroadcast = broadcastHandlers.get('sync')!;
    onBroadcast({
      payload: { arena_id: 'other-arena-999', kind: 'session.start' },
    });
    // No arena named: not this arena's either.
    onBroadcast({ payload: { kind: 'push', kinds: ['session.start'] } });

    vi.advanceTimersByTime(AFTER);
    expect(mockFloor.refresh).not.toHaveBeenCalled();
    expect(mockSales.refresh).not.toHaveBeenCalled();
  });

  it('tears down previous channel when switching arenas', async () => {
    await sync.setupArena('arena-123', true);
    expect(mockClient.channel).toHaveBeenCalledWith('arena:arena-123', {
      config: { private: true },
    });

    await sync.setupArena('arena-456', true);
    expect(mockClient.removeChannel).toHaveBeenCalledWith(mockChannel);
    expect(mockClient.channel).toHaveBeenCalledWith('arena:arena-456', {
      config: { private: true },
    });
  });

  it('tears the channel down when the user signs out', async () => {
    TestBed.tick();
    await sync.setupArena('arena-123', true);
    expect(mockClient.removeChannel).not.toHaveBeenCalled();

    user.set(null);
    TestBed.tick();
    await vi.waitFor(() => expect(mockClient.removeChannel).toHaveBeenCalledWith(mockChannel));

    // Nothing left to refresh for a signed-out dashboard.
    postgresHandlers.get('sessions')!({ eventType: 'INSERT' });
    window.dispatchEvent(new Event('online'));
    vi.advanceTimersByTime(AFTER);
    expect(mockFloor.refresh).not.toHaveBeenCalled();
  });

  it('another login (signed in from another tab) does not keep the previous login’s channel', async () => {
    TestBed.tick();
    await sync.setupArena('arena-123', true);

    // Same arena, different login: the old JWT's channel goes.
    user.set({ id: 'u9', email: 'farah@404arena.in', name: 'Farah Khan' });
    TestBed.tick();
    await vi.waitFor(() => expect(mockClient.removeChannel).toHaveBeenCalledWith(mockChannel));
    postgresHandlers.get('sessions')!({ eventType: 'INSERT' });
    vi.advanceTimersByTime(AFTER);
    expect(mockFloor.refresh).not.toHaveBeenCalled();
  });

  it('catches up once subscribed', async () => {
    router.url = '/settings/games';
    await sync.setupArena('arena-123', true);
    channelSubscribeCallback!('SUBSCRIBED');
    vi.advanceTimersByTime(AFTER);
    expect(mockFloor.refresh).toHaveBeenCalledWith(['live', 'stationFigures', 'gameFigures']);
    expect(mockFloor.refresh).toHaveBeenCalledWith(['gameResources']);
  });

  it('a rejoin after a dropped socket reloads the open screen and marks the rest out of date', async () => {
    await sync.setupArena('arena-123', true);
    channelSubscribeCallback!('SUBSCRIBED');
    vi.advanceTimersByTime(AFTER);
    expect(mockSales.refresh).not.toHaveBeenCalled();

    vi.clearAllMocks();
    channelSubscribeCallback!('CHANNEL_ERROR');
    channelSubscribeCallback!('SUBSCRIBED');
    vi.advanceTimersByTime(AFTER);
    expect(mockFloor.stale).toHaveBeenCalledWith(['live', 'stationFigures', 'gameFigures']);
    expect(mockSales.refresh).toHaveBeenCalledTimes(1);
    expect(mockOverview.stale).toHaveBeenCalledTimes(1);
    expect(mockPricing.stale).toHaveBeenCalledTimes(1);
    expect(mockUsers.stale).toHaveBeenCalledTimes(1);
    // Access may have changed meanwhile too.
    expect(mockArenaContext.load).toHaveBeenCalledWith(true);
  });

  it('broadcasts outgoing sync messages on active channel', async () => {
    await sync.setupArena('arena-123', true);

    await sync.broadcast('resource.upsert', { id: 'station-1' });
    expect(mockChannel.send).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'broadcast',
        event: 'sync',
        payload: expect.objectContaining({
          arena_id: 'arena-123',
          kind: 'resource.upsert',
          kinds: ['resource.upsert'],
        }),
      }),
    );
  });
});
