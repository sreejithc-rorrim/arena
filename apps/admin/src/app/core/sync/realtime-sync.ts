import { Service, effect, inject } from '@angular/core';
import { Router } from '@angular/router';
import type { RealtimeChannel, SupabaseClient } from '@supabase/supabase-js';
import { ArenaContext } from '../arena/arena-context';
import { Session } from '../auth/session';
import { FloorRead, FloorStore } from '../floor/floor-store';
import { AccessoriesStore } from '../../features/accessories/data/accessories-store';
import { FloorOptionsStore } from '../../features/settings/data/floor-options';
import { OverviewStore } from '../../features/overview/data/overview-store';
import { PricingStore } from '../../features/pricing/data/pricing-store';
import { SalesStore } from '../../features/sales/data/sales-store';
import { TeamStore } from '../../features/team/data/team-store';
import { UsersStore } from '../../features/users/data/users-store';
import { Supabase } from '../supabase/supabase';
import { VenueStore } from '../venue/venue';
import { SYNC_EVENT, arenaTopic } from './push-ops';

export type RefreshTarget =
  | 'floor_plays'
  | 'floor_charges'
  | 'stations'
  | 'games'
  | 'game_resources'
  | 'customers'
  | 'sales'
  | 'overview'
  | 'pricing'
  | 'settings'
  | 'users'
  | 'accessories'
  | 'arena';

/** How long a burst of events is gathered before one refresh. */
export const DEBOUNCE_MS = 800;

const BILLS: readonly RefreshTarget[] = ['floor_plays', 'overview', 'sales'];
const PRICES: readonly RefreshTarget[] = ['pricing', 'settings'];
/**
 * A staff change may be the signed-in login's own (deactivated, permissions changed): the
 * memberships reload too (ArenaContext), so lost access applies without a page reload. The
 * login's own deactivation never arrives as a row change (RLS hides the row from it by then): it
 * comes as the writer's broadcast nudge, or shows as the channel being refused.
 */
const STAFF: readonly RefreshTarget[] = ['users', 'arena'];

/**
 * The published tables the dashboard shows, and what each one's changes refresh. Bookings are
 * published for the floor app but not shown here, so they are not subscribed. A pad moved or lent
 * on the floor (controller.move, a session's borrow) updates its controllers row.
 */
export const TABLE_TARGETS: Readonly<Record<string, readonly RefreshTarget[]>> = {
  sessions: BILLS,
  session_segments: ['floor_plays', 'overview'],
  session_charges: ['sales', 'overview', 'floor_charges'],
  session_extensions: ['sales', 'overview', 'floor_plays'],
  payments: ['sales', 'overview', 'floor_plays'],
  resources: ['stations'],
  resource_activities: ['stations', 'pricing'],
  activities: ['pricing', 'stations'],
  games: ['games'],
  game_controls: ['games'],
  game_categories: ['games'],
  game_resources: ['game_resources'],
  customers: ['customers'],
  staff_profiles: STAFF,
  // Opening hours live in settings rows: a settings change refreshes pricing too.
  settings: PRICES,
  rates: PRICES,
  rate_cards: PRICES,
  rate_bands: PRICES,
  holidays: PRICES,
  billing_policies: PRICES,
  pricing_rules: PRICES,
  discounts: PRICES,
  bill_discounts: ['sales', 'overview'],
  controllers: ['accessories', 'stations'],
  accessory_kinds: ['accessories'],
};

const ALL_TARGETS: readonly RefreshTarget[] = [
  'floor_plays',
  'floor_charges',
  'stations',
  'games',
  'game_resources',
  'customers',
  'sales',
  'overview',
  'pricing',
  'settings',
  'users',
  'accessories',
  'arena',
];

/** What a committed op kind (`session.start`, `game.set_compat`…) refreshes, by its prefix. */
const KIND_TARGETS: readonly (readonly [string, readonly RefreshTarget[]])[] = [
  ['session.', BILLS],
  ['payment.', ['sales', 'overview', 'floor_plays']],
  ['game.set_compat', ['game_resources']],
  // A deleted game takes its station statuses with it.
  ['game.delete', ['games', 'game_resources']],
  ['game.', ['games']],
  ['resource.', ['stations', 'game_resources']],
  ['activity.', ['pricing', 'stations']],
  ['rate.', PRICES],
  ['policy.', PRICES],
  ['holiday.', PRICES],
  ['settings.', PRICES],
  ['hours.', PRICES],
  ['customer.', ['customers']],
  ['staff.', STAFF],
  ['arena.', ['arena', 'settings']],
  ['controller.', ['accessories', 'stations']],
  ['accessory_kind.', ['accessories']],
  ['rule.', PRICES],
  ['discount.', PRICES],
  // Floor-only records the dashboard does not show.
  ['booking.', []],
  // Personal details and terms: their tabs read them afresh each time they open.
  ['staff_details.', []],
  ['terms.', []],
];

export function targetsForKind(kind: string): readonly RefreshTarget[] {
  return KIND_TARGETS.find(([prefix]) => kind.startsWith(prefix))?.[1] ?? ALL_TARGETS;
}

/**
 * Live updates for the dashboard over the current arena's PRIVATE Realtime channel
 * (`arena:<id>`; Realtime Authorization admits only active members, so the user's JWT is set
 * before joining):
 * 1. Postgres Changes: INSERT and UPDATE of the published tables, filtered by arena_id (RLS also
 *    applies). DELETE is never subscribed — Supabase neither filters nor RLS-checks delete
 *    events, so they would leak other arenas' row ids; deletions arrive as a broadcast nudge.
 * 2. Broadcast `sync`: sent by a device after its push committed, listing the applied op kinds.
 *
 * Bursts are coalesced; each refresh re-reads through the stores' normal RLS-checked queries.
 * The channel follows the signed-in user and the selected arena, and is torn down on sign-out.
 */
@Service()
export class RealtimeSync {
  private readonly supabase = inject(Supabase);
  private readonly session = inject(Session);
  private readonly arena = inject(ArenaContext);
  private readonly floor = inject(FloorStore);
  private readonly sales = inject(SalesStore);
  private readonly overview = inject(OverviewStore);
  private readonly pricing = inject(PricingStore);
  private readonly floorOptions = inject(FloorOptionsStore);
  private readonly accessories = inject(AccessoriesStore);
  private readonly users = inject(UsersStore);
  private readonly team = inject(TeamStore);
  private readonly venue = inject(VenueStore);
  private readonly router = inject(Router);

  private activeChannel: RealtimeChannel | null = null;
  private subscribedArenaId: string | null = null;
  /** The login the channel was opened for (its JWT authorized the join). */
  private subscribedUserId: string | null = null;
  /** Bumped by every setup and teardown: callbacks of an older channel do nothing. */
  private generation = 0;
  private debounceTimer: ReturnType<typeof setTimeout> | null = null;
  private readonly pendingTargets = new Set<RefreshTarget>();
  private readonly onlineHandler = () => this.onOnline();

  constructor() {
    if (typeof window !== 'undefined') {
      window.addEventListener('online', this.onlineHandler);
    }

    // Follow the signed-in user and the selected arena; nobody signed in → no channel. Another
    // login (signed in from another tab) joins again with its own JWT, even for the same arena.
    effect(() => {
      const userId = this.session.user()?.id ?? null;
      const arenaId = this.arena.current().id;
      if (!userId) {
        if (this.subscribedArenaId !== null || this.activeChannel) void this.teardownCurrent();
        return;
      }
      if (arenaId !== this.subscribedArenaId || userId !== this.subscribedUserId) {
        void this.setupArena(arenaId);
      }
    });
  }

  /**
   * Tells the arena's other devices that `kind` was committed. Writes normally announce
   * themselves through pushOps after the server applied them; this is for anything else.
   */
  async broadcast(kind: string, meta: Record<string, unknown> = {}): Promise<void> {
    const channel = this.activeChannel;
    const arenaId = this.subscribedArenaId;
    if (!channel || !arenaId) return;

    try {
      await channel.send({
        type: 'broadcast',
        event: SYNC_EVENT,
        payload: {
          ...meta,
          arena_id: arenaId,
          kind,
          kinds: [kind],
          source: 'admin-web',
          at: new Date().toISOString(),
        },
      });
    } catch {
      // Not delivered: the other devices still see the rows through their own change feed.
    }
  }

  async setupArena(arenaId: string, force = false): Promise<void> {
    await this.teardownCurrent();

    const isVitest = Boolean(
      (
        (globalThis as Record<string, unknown>)['process'] as
          { env?: Record<string, string> } | undefined
      )?.env?.['VITEST'],
    );
    if (!arenaId || this.supabase.misconfigured || (isVitest && !force)) {
      return;
    }
    const run = ++this.generation;
    const live = () => run === this.generation;
    this.subscribedArenaId = arenaId;
    this.subscribedUserId = this.session.user()?.id ?? null;

    try {
      const client = await this.supabase.client();
      // The private channel is authorized with the user's JWT: no session, no channel.
      const { data } = await client.auth.getSession();
      const token = data.session?.access_token;
      if (!live()) return;
      if (!token) {
        this.subscribedArenaId = null;
        return;
      }
      await client.realtime.setAuth(token);
      if (!live()) return;

      const channel = client.channel(arenaTopic(arenaId), { config: { private: true } });
      const filter = `arena_id=eq.${arenaId}`;
      for (const [table, targets] of Object.entries(TABLE_TARGETS)) {
        for (const event of ['INSERT', 'UPDATE'] as const) {
          channel.on('postgres_changes', { event, schema: 'public', table, filter }, () => {
            if (live()) this.schedule(targets);
          });
        }
      }

      channel.on('broadcast', { event: SYNC_EVENT }, (message) => {
        // {type, event, payload: {...}} — what this client and the floor app send; a bare map
        // (an older floor app's broadcast) is read as the nudge itself.
        const m = message as { payload?: unknown };
        if (live()) this.onBroadcast(arenaId, m.payload ?? message);
      });

      let joined = false;
      channel.subscribe((status) => {
        if (status === 'SUBSCRIBED' && live()) {
          // Catch up on anything missed while connecting: the first join, the floor (screens
          // load the rest themselves); a rejoin after a dropped socket, everything, since any
          // change may have been missed meanwhile.
          this.schedule(
            joined ? ALL_TARGETS : ['floor_plays', 'stations', 'games', 'game_resources'],
          );
          joined = true;
        } else if (status === 'CHANNEL_ERROR' && live()) {
          // Refused (Realtime Authorization admits only active members) or dropped: check this
          // login's own access again.
          this.schedule(['arena']);
        }
      });

      this.activeChannel = channel;
    } catch {
      // Offline: the screens still load on their own; coming back online joins again.
      if (live()) this.subscribedArenaId = null;
    }
  }

  private onBroadcast(arenaId: string, raw: unknown): void {
    const payload = (raw ?? {}) as { arena_id?: unknown; kinds?: unknown; kind?: unknown };
    // Only nudges about this arena (a message without one is not trusted to be).
    if (payload.arena_id !== arenaId) return;
    const kinds = Array.isArray(payload.kinds)
      ? payload.kinds.filter((k): k is string => typeof k === 'string')
      : null;
    if (kinds) {
      this.schedule(kinds.length ? kinds.flatMap((k) => targetsForKind(k)) : ALL_TARGETS);
    } else if (typeof payload.kind === 'string' && payload.kind !== 'push') {
      this.schedule(targetsForKind(payload.kind));
    } else {
      this.schedule(ALL_TARGETS);
    }
  }

  private async teardownCurrent(): Promise<void> {
    this.generation++;
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = null;
    }
    this.pendingTargets.clear();

    const channel = this.activeChannel;
    this.activeChannel = null;
    this.subscribedArenaId = null;

    if (channel) {
      try {
        const client: SupabaseClient = await this.supabase.client();
        await client.removeChannel(channel);
      } catch {
        // Ignore channel unsubscribe errors during teardown
      }
    }
  }

  private onOnline(): void {
    const arenaId = this.arena.current().id;
    if (this.session.user() === null || !arenaId) return;
    if (!this.activeChannel) {
      // The channel never joined (offline at the time): join now; SUBSCRIBED catches up.
      void this.setupArena(arenaId);
      return;
    }
    this.schedule(ALL_TARGETS);
  }

  /** Coalesces a burst of events (a session end writes several tables) into one refresh. */
  private schedule(targets: readonly RefreshTarget[]): void {
    if (!targets.length) return;
    for (const t of targets) {
      this.pendingTargets.add(t);
    }

    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer);
    }

    this.debounceTimer = setTimeout(() => {
      this.debounceTimer = null;
      void this.flush();
    }, DEBOUNCE_MS);
  }

  /**
   * Reloads what the open screen shows; anything else is only marked out of date, so it is read
   * again when a screen next needs it instead of being downloaded in the background.
   */
  private async flush(): Promise<void> {
    const targets = new Set(this.pendingTargets);
    this.pendingTargets.clear();
    const path = this.router.url.split(/[?#]/)[0];
    // The games library lives under Settings but reads floor data like its own page.
    const page = path.startsWith('/settings/games') ? 'games' : (path.split('/')[1] ?? '');
    const on = (...pages: string[]) => pages.includes(page);
    const jobs: Promise<void>[] = [];

    const floor = (what: FloorRead[]) => {
      if (on('stations', 'games', 'members', 'overview')) jobs.push(this.floor.refresh(what));
      else this.floor.stale(what);
    };
    if (targets.has('floor_plays')) {
      floor(['live', 'stationFigures', 'gameFigures']);
    }
    if (targets.has('floor_charges')) floor(['stationFigures']);
    if (targets.has('stations')) floor(['stations', 'stationFigures']);
    if (targets.has('games')) floor(['games']);
    if (targets.has('game_resources')) floor(['gameResources']);
    // Members are read on demand; a member change only bumps what those reads depend on.
    if (targets.has('customers')) floor(['live']);
    if (targets.has('sales')) {
      if (on('sales')) jobs.push(this.sales.refresh());
      else this.sales.stale();
    }
    if (targets.has('overview')) {
      if (on('overview')) jobs.push(this.overview.refresh());
      else this.overview.stale();
    }
    if (targets.has('pricing')) {
      if (on('pricing', 'settings', 'stations', 'overview')) jobs.push(this.pricing.refresh());
      else this.pricing.stale();
    }
    if (targets.has('settings')) {
      if (on('settings')) jobs.push(this.floorOptions.refresh());
      else this.floorOptions.stale();
    }
    if (targets.has('users')) {
      if (on('settings', 'staff')) jobs.push(this.users.refresh());
      else this.users.stale();
      if (on('staff')) jobs.push(this.team.refresh());
    }
    if (targets.has('accessories')) {
      if (on('stations', 'settings')) jobs.push(this.accessories.refresh());
      else this.accessories.stale();
    }
    // Station types and the venue profile decide the nav on every screen: always read again.
    if (targets.has('pricing') || targets.has('settings')) jobs.push(this.venue.refresh());
    // Memberships decide what this login may still do: always read again.
    if (targets.has('arena')) jobs.push(this.arena.load(true));

    await Promise.allSettled(jobs);
  }

  destroy(): void {
    if (typeof window !== 'undefined') {
      window.removeEventListener('online', this.onlineHandler);
    }
    void this.teardownCurrent();
  }
}
