import { istDayStart } from '../../shared/time/ist';
import { AppError } from '../auth/auth-api';
import { FLOOR_MESSAGES, FloorApi, compatOps } from './floor-api';
import {
  Activity,
  Charge,
  CompatStatus,
  Customer,
  Game,
  GameCompat,
  GameFan,
  GameFigures,
  GameInput,
  GameUsage,
  MemberPage,
  Play,
  Station,
  StationFigures,
  StationInput,
  StationStatus,
  Visit,
} from './floor.models';

function station(id: string, name: string, codes: string[], o: Partial<Station> = {}): Station {
  return {
    id,
    name,
    kind: 'station',
    status: 'available',
    sortOrder: 0,
    activityCodes: codes,
    ...o,
  };
}

function game(
  id: string,
  name: string,
  platforms: string[],
  active = true,
  ageRating: Game['ageRating'] = null,
  media: Game['media'] = null,
): Game {
  return {
    id,
    name,
    aliases: [],
    categoryId: null,
    platforms,
    playModes: ['story', 'local'],
    maxLocalPlayers: 4,
    active,
    ageRating,
    media,
  };
}

/**
 * A deterministic floor for tests, lined up with SampleSalesApi (station and member names) and
 * SamplePricingApi (type codes): HEX and VOID are playing, NOVA is out of service, PS4 is removed.
 * Changes are applied in memory like the server would and recorded in `ops`.
 */
export class SampleFloorApi extends FloorApi {
  stationList: Station[];
  gameList: Game[];
  /** Where each game is playable; every sample game is playable on at least one station. */
  compatList: GameCompat[];
  customerList: Customer[];
  playList: Play[];
  visitList: Visit[];
  chargeList: Charge[];
  /** Every write, in order, as `kind` + payload. */
  readonly ops: { kind: string; payload: unknown }[] = [];
  /** Every read, in order, by method name (lazy-loading checks). */
  readonly reads: string[] = [];
  /** What the sample treats as now (open plays count up to it). */
  private readonly now: Date;
  /** Set to make the next call fail with this code. */
  failNext: string | null = null;
  /** Bookings that name a game (the sample floor has none unless a test adds them). */
  readonly bookingsByGame = new Map<string, number>();
  /** Ids game.delete removed; the server never lets game.upsert bring them back. */
  private readonly deletedGames = new Set<string>();

  constructor(now: Date) {
    super();
    this.now = now;
    /** An instant `daysAgo` IST days back at hh:mm IST. */
    const at = (daysAgo: number, hhmm: string) => {
      const [h, m] = hhmm.split(':').map(Number);
      return new Date(istDayStart(now, daysAgo).getTime() + (h * 60 + m) * 60_000).toISOString();
    };
    const inMin = (m: number) => new Date(now.getTime() + m * 60_000).toISOString();

    this.stationList = [
      station('s-hex', 'HEX', ['PS5'], { sortOrder: 0 }),
      station('s-void', 'VOID', ['PS5'], { sortOrder: 1 }),
      station('s-ghost', 'GHOST', ['PS5'], { sortOrder: 2 }),
      station('s-rift', 'RIFT', ['PS5', 'VR'], { sortOrder: 3 }),
      station('s-nova', 'NOVA', ['PS5'], { sortOrder: 4, status: 'maintenance' }),
      station('s-vr', 'VR Bay', ['VR'], { sortOrder: 5 }),
      station('s-ps4', 'PS4', ['PS5'], { sortOrder: 6, status: 'disabled' }),
    ];
    this.gameList = [
      game('g-fc', 'EA SPORTS FC 25', ['PS5'], true, 3, 'digital'),
      game('g-tekken', 'Tekken 8', ['PS5'], true, 16, 'disc'),
      game('g-gt', 'Gran Turismo 7', ['PS5']),
      game('g-mk', 'Mortal Kombat 1', ['PS5'], false, 18, 'disc'),
      game('g-beat', 'Beat Saber', ['PSVR2']),
    ];
    const playable = (gameId: string, ...stations: string[]): GameCompat[] =>
      stations.map((resourceId) => ({ gameId, resourceId, status: 'playable' }));
    this.compatList = [
      ...playable('g-fc', 's-hex', 's-void', 's-ghost', 's-rift'),
      ...playable('g-tekken', 's-hex', 's-void'),
      ...playable('g-gt', 's-rift'),
      { gameId: 'g-gt', resourceId: 's-hex', status: 'not_playable' },
      ...playable('g-mk', 's-hex'),
      ...playable('g-beat', 's-vr', 's-rift'),
    ];
    this.customerList = [
      { id: 'c-kiran', name: 'Kiran Rao', phone: '9845012873', lastVisitAt: at(0, '17:40') },
      { id: 'c-aditya', name: 'Aditya Shah', phone: '9845744810', lastVisitAt: at(0, '15:45') },
      { id: 'c-meera', name: 'Meera Pillai', phone: '9846476747', lastVisitAt: at(0, '12:10') },
      { id: 'c-rahul', name: 'Rahul Verma', phone: null, lastVisitAt: at(1, '19:00') },
      { id: 'c-sana', name: 'Sana Khan', phone: '9847940621', lastVisitAt: null },
    ].map((c) => ({
      ...c,
      createdAt: at(80, '12:00'),
      birthYear: c.id === 'c-kiran' ? 2001 : null,
    }));

    const play = (
      id: string,
      o: Partial<Play> & Pick<Play, 'billId' | 'customerId' | 'resourceId' | 'startedAt'>,
    ): Play => ({
      id,
      billStatus: 'completed',
      activityCode: 'PS5',
      gameId: null,
      controllers: 1,
      endedAt: null,
      scheduledEndAt: o.startedAt,
      ...o,
    });
    this.playList = [
      // Live: HEX ends in 25 minutes, VOID (two controllers) in 8.
      play('p-live-hex', {
        billId: 'b-live-hex',
        billStatus: 'active',
        customerId: 'c-kiran',
        resourceId: 's-hex',
        gameId: 'g-fc',
        controllers: 2,
        startedAt: inMin(-35),
        scheduledEndAt: inMin(25),
      }),
      play('p-live-void', {
        billId: 'b-live-void',
        billStatus: 'active',
        customerId: 'c-aditya',
        resourceId: 's-void',
        gameId: 'g-tekken',
        controllers: 2,
        startedAt: inMin(-52),
        scheduledEndAt: inMin(8),
      }),
      // History.
      play('p-1', {
        billId: 'b-1',
        customerId: 'c-kiran',
        resourceId: 's-hex',
        gameId: 'g-fc',
        startedAt: at(0, '16:40'),
        endedAt: at(0, '17:40'),
      }),
      play('p-2', {
        billId: 'b-2',
        customerId: 'c-meera',
        resourceId: 's-rift',
        gameId: 'g-gt',
        startedAt: at(0, '11:10'),
        endedAt: at(0, '12:10'),
      }),
      play('p-3', {
        billId: 'b-3',
        customerId: 'c-kiran',
        resourceId: 's-hex',
        gameId: 'g-mk',
        startedAt: at(1, '18:00'),
        endedAt: at(1, '19:30'),
      }),
      play('p-4', {
        billId: 'b-4',
        customerId: 'c-rahul',
        resourceId: 's-void',
        gameId: 'g-fc',
        startedAt: at(1, '18:00'),
        endedAt: at(1, '19:00'),
      }),
      play('p-5', {
        billId: 'b-5',
        billStatus: 'voided',
        customerId: 'c-kiran',
        resourceId: 's-ghost',
        gameId: 'g-fc',
        startedAt: at(2, '15:00'),
        endedAt: at(2, '16:00'),
      }),
    ];
    this.visitList = [
      { id: 'b-live-hex', customerId: 'c-kiran', status: 'active' },
      { id: 'b-live-void', customerId: 'c-aditya', status: 'active' },
      { id: 'b-1', customerId: 'c-kiran', status: 'completed', billed: 24000 },
      { id: 'b-2', customerId: 'c-meera', status: 'completed', billed: 15000 },
      { id: 'b-3', customerId: 'c-kiran', status: 'completed', billed: 18000 },
      { id: 'b-4', customerId: 'c-rahul', status: 'completed', billed: 12000 },
      { id: 'b-5', customerId: 'c-kiran', status: 'voided', billed: 12000 },
    ].map((v): Visit => {
      const plays = this.playList.filter((p) => p.billId === v.id);
      return {
        id: v.id,
        customerId: v.customerId,
        status: v.status as Visit['status'],
        startedAt: plays[0].startedAt,
        endedAt: plays[0].endedAt,
        billedPaise: v.billed ?? null,
      };
    });
    this.chargeList = [
      { billId: 'b-1', resourceId: 's-hex', at: at(0, '16:40'), minutes: 60, paise: 24000 },
      { billId: 'b-2', resourceId: 's-rift', at: at(0, '11:10'), minutes: 60, paise: 15000 },
      { billId: 'b-3', resourceId: 's-hex', at: at(1, '18:00'), minutes: 90, paise: 18000 },
      { billId: 'b-4', resourceId: 's-void', at: at(1, '18:00'), minutes: 60, paise: 12000 },
      { billId: 'b-6', resourceId: 's-vr', at: at(4, '17:00'), minutes: 30, paise: 30000 },
    ].map((c): Charge => ({
      billId: c.billId,
      resourceId: c.resourceId,
      activityCode: c.resourceId === 's-vr' ? 'VR' : 'PS5',
      segmentStart: c.at,
      playedMinutes: c.minutes,
      amountPaise: c.paise,
    }));
  }

  async stations(): Promise<Station[]> {
    this.fail();
    this.reads.push('stations');
    return [...this.stationList].sort((a, b) => a.sortOrder - b.sortOrder);
  }

  async games(): Promise<Game[]> {
    this.fail();
    this.reads.push('games');
    return [...this.gameList].sort((a, b) => a.name.localeCompare(b.name));
  }

  async gameResources(): Promise<GameCompat[]> {
    this.fail();
    this.reads.push('gameResources');
    return this.compatList.map((c) => ({ ...c }));
  }

  async plays(_arenaId: string, since: Date): Promise<Play[]> {
    this.fail();
    this.reads.push('plays');
    return this.playList.filter((p) => !p.endedAt || Date.parse(p.startedAt) >= since.getTime());
  }

  /** Plays of bills not voided, started since `since` or still open (the server's _plays). */
  private recent(since: Date): Play[] {
    return this.playList.filter(
      (p) =>
        p.billStatus !== 'voided' && (!p.endedAt || Date.parse(p.startedAt) >= since.getTime()),
    );
  }

  private minutes(p: Play): number {
    const end = p.endedAt ? Date.parse(p.endedAt) : this.now.getTime();
    return Math.max(0, (end - Date.parse(p.startedAt)) / 60_000);
  }

  async stationFigures(
    _arenaId: string,
    today: Date,
    since: Date,
    to: Date,
  ): Promise<ReadonlyMap<string, StationFigures>> {
    this.fail();
    this.reads.push('stationFigures');
    const plays = this.recent(since);
    const charges = this.chargeList.filter((c) => {
      const t = Date.parse(c.segmentStart);
      return t >= since.getTime() && t < to.getTime();
    });
    return new Map(
      this.stationList.map((s) => {
        const mine = plays.filter((p) => p.resourceId === s.id);
        const billed = charges.filter((c) => c.resourceId === s.id);
        return [
          s.id,
          {
            billedToday: billed
              .filter((c) => Date.parse(c.segmentStart) >= today.getTime())
              .reduce((n, c) => n + c.amountPaise, 0),
            sessionsToday: new Set(
              mine.filter((p) => Date.parse(p.startedAt) >= today.getTime()).map((p) => p.billId),
            ).size,
            minutes30: Math.round(
              mine
                .filter((p) => Date.parse(p.startedAt) >= since.getTime())
                .reduce((n, p) => n + this.minutes(p), 0),
            ),
            billed30: billed.reduce((n, c) => n + c.amountPaise, 0),
            accessories: this.accessoryCount.get(s.id) ?? 0,
          },
        ];
      }),
    );
  }

  /** Accessories per station the figures report (tests set it). */
  readonly accessoryCount = new Map<string, number>([
    ['s-hex', 2],
    ['s-void', 2],
  ]);

  async gameFigures(_arenaId: string, since: Date): Promise<ReadonlyMap<string, GameFigures>> {
    this.fail();
    this.reads.push('gameFigures');
    const out = new Map<string, { minutes: number; bills: Set<string>; now: number }>();
    for (const p of this.recent(since)) {
      if (!p.gameId) continue;
      const s = out.get(p.gameId) ?? { minutes: 0, bills: new Set<string>(), now: 0 };
      s.minutes += this.minutes(p);
      s.bills.add(p.billId);
      if (!p.endedAt && p.billStatus === 'active') s.now++;
      out.set(p.gameId, s);
    }
    return new Map(
      [...out].map(([id, s]) => [
        id,
        { minutes30: Math.round(s.minutes), sessions30: s.bills.size, playingNow: s.now },
      ]),
    );
  }

  async gameFans(_arenaId: string, gameId: string, since: Date, limit: number): Promise<GameFan[]> {
    this.fail();
    this.reads.push('gameFans');
    const by = new Map<string, { bills: Set<string>; minutes: number }>();
    for (const p of this.recent(since)) {
      if (p.gameId !== gameId || !this.customerList.some((c) => c.id === p.customerId)) continue;
      const f = by.get(p.customerId) ?? { bills: new Set<string>(), minutes: 0 };
      f.bills.add(p.billId);
      f.minutes += this.minutes(p);
      by.set(p.customerId, f);
    }
    return [...by]
      .map(([id, f]) => ({
        customerId: id,
        name: this.customerList.find((c) => c.id === id)?.name ?? '',
        sessions: f.bills.size,
        minutes: Math.round(f.minutes),
      }))
      .sort((a, b) => b.minutes - a.minutes || a.name.localeCompare(b.name))
      .slice(0, limit);
  }

  async activity(
    _arenaId: string,
    of: { readonly stationId?: string; readonly customerId?: string },
    since: Date,
    limit: number,
  ): Promise<Activity> {
    this.fail();
    this.reads.push('activity');
    const mine = this.playList.filter(
      (p) =>
        (!p.endedAt || Date.parse(p.startedAt) >= since.getTime()) &&
        (of.stationId ? p.resourceId === of.stationId : p.customerId === of.customerId),
    );
    const latest = new Map<string, Play>();
    for (const p of [...mine].sort((a, b) => Date.parse(b.startedAt) - Date.parse(a.startedAt))) {
      if (!latest.has(p.billId)) latest.set(p.billId, p);
    }
    const bills = [...latest.values()].slice(0, limit).map((p) => ({
      billId: p.billId,
      startedAt: p.startedAt,
      status: p.billStatus,
      billedPaise: this.visitList.find((v) => v.id === p.billId)?.billedPaise ?? null,
      customer: this.customerList.find((c) => c.id === p.customerId)?.name ?? null,
      station: this.stationList.find((s) => s.id === p.resourceId)?.name ?? null,
      game: this.gameList.find((g) => g.id === p.gameId)?.name ?? null,
    }));
    const games = new Map<string, number>();
    if (of.customerId) {
      for (const p of this.recent(since)) {
        if (p.customerId === of.customerId && p.gameId) {
          games.set(p.gameId, (games.get(p.gameId) ?? 0) + this.minutes(p));
        }
      }
    }
    return {
      bills,
      games: [...games]
        .map(([gameId, minutes]) => ({
          gameId,
          name: this.gameList.find((g) => g.id === gameId)?.name ?? '',
          minutes: Math.round(minutes),
        }))
        .sort((a, b) => b.minutes - a.minutes),
    };
  }

  async members(
    _arenaId: string,
    q: { since: Date; since30: Date; search: string; limit: number; offset: number },
  ): Promise<MemberPage> {
    this.fail();
    this.reads.push('members');
    const text = q.search.trim().toLowerCase();
    const digits = q.search.replace(/\D/g, '');
    const rows = this.customerList
      .filter(
        (c) =>
          !text ||
          c.name.toLowerCase().includes(text) ||
          (!!digits && !!c.phone && c.phone.replace(/\D/g, '').includes(digits)),
      )
      .map((c) => {
        const visits = this.visitList.filter(
          (v) =>
            v.customerId === c.id &&
            v.status !== 'voided' &&
            (v.status === 'active' || Date.parse(v.startedAt) >= q.since.getTime()),
        );
        const newest =
          visits
            .map((v) => v.startedAt)
            .sort()
            .at(-1) ?? null;
        return {
          id: c.id,
          name: c.name,
          phone: c.phone,
          birthYear: c.birthYear,
          createdAt: c.createdAt,
          visits: visits.length,
          minutes: Math.round(
            this.recent(q.since)
              .filter((p) => p.customerId === c.id)
              .reduce((n, p) => n + this.minutes(p), 0),
          ),
          spent30Paise: visits
            .filter((v) => Date.parse(v.startedAt) >= q.since30.getTime())
            .reduce((n, v) => n + (v.billedPaise ?? 0), 0),
          lastVisit:
            [c.lastVisitAt, newest]
              .filter((x): x is string => !!x)
              .sort()
              .at(-1) ?? null,
        };
      })
      .sort(
        (a, b) =>
          (b.lastVisit ?? '').localeCompare(a.lastVisit ?? '') || a.name.localeCompare(b.name),
      );
    return { total: rows.length, rows: rows.slice(q.offset, q.offset + q.limit) };
  }

  async saveStation(_arenaId: string, s: StationInput): Promise<void> {
    this.fail();
    const clash = this.stationList.find(
      (x) => x.id !== s.id && x.name.toLowerCase() === s.name.toLowerCase(),
    );
    if (clash) throw new AppError('duplicate', FLOOR_MESSAGES['duplicate']);
    this.ops.push({ kind: 'resource.upsert', payload: s });
    const i = this.stationList.findIndex((x) => x.id === s.id);
    // Like the server: an edit without a status keeps the stored one; a new station is available.
    const status = s.status ?? (i < 0 ? 'available' : this.stationList[i].status);
    const next: Station = { ...s, status, activityCodes: [...s.activityCodes] };
    if (i < 0) this.stationList.push(next);
    else this.stationList[i] = next;
  }

  async setStationStatus(_arenaId: string, id: string, status: StationStatus): Promise<void> {
    this.fail();
    const i = this.stationList.findIndex((x) => x.id === id);
    if (i < 0) throw new AppError('not_found', FLOOR_MESSAGES['not_found']);
    this.ops.push({ kind: 'resource.set_status', payload: { id, status } });
    this.stationList[i] = { ...this.stationList[i], status };
  }

  async saveGame(
    _arenaId: string,
    g: GameInput,
    playableOn: readonly string[] = [],
    baseActive?: boolean,
  ): Promise<void> {
    this.fail();
    if (this.deletedGames.has(g.id)) throw new AppError('not_found', FLOOR_MESSAGES['not_found']);
    if (this.gameList.some((x) => x.id !== g.id && x.name.toLowerCase() === g.name.toLowerCase())) {
      throw new AppError('duplicate', FLOOR_MESSAGES['duplicate']);
    }
    const stored = this.gameList.find((x) => x.id === g.id);
    if (
      stored &&
      baseActive !== undefined &&
      baseActive !== stored.active &&
      g.active !== stored.active
    ) {
      throw new AppError('stale', FLOOR_MESSAGES['stale']);
    }
    this.ops.push({
      kind: 'game.upsert',
      payload: baseActive === undefined ? g : { ...g, baseActive },
    });
    const next: Game = { ...g, aliases: [...g.aliases], platforms: [...g.platforms] };
    const i = this.gameList.findIndex((x) => x.id === g.id);
    if (i < 0) this.gameList.push(next);
    else this.gameList[i] = next;
    for (const resourceId of playableOn) this.compat(g.id, resourceId, 'playable');
  }

  async setGameCompat(
    _arenaId: string,
    gameId: string,
    resourceId: string,
    status: CompatStatus,
  ): Promise<void> {
    this.fail();
    if (!this.gameList.some((g) => g.id === gameId)) {
      throw new AppError('not_found', FLOOR_MESSAGES['not_found']);
    }
    this.compat(gameId, resourceId, status);
  }

  /** Records the real op (compatOps) and upserts the pair like the server does. */
  private compat(gameId: string, resourceId: string, status: CompatStatus): void {
    this.ops.push(...compatOps(gameId, resourceId, status));
    const row: GameCompat = { gameId, resourceId, status };
    const i = this.compatList.findIndex((c) => c.gameId === gameId && c.resourceId === resourceId);
    if (i < 0) this.compatList.push(row);
    else this.compatList[i] = row;
  }

  async setGameActive(_arenaId: string, id: string, active: boolean): Promise<void> {
    this.fail();
    const i = this.gameList.findIndex((x) => x.id === id);
    if (i < 0) throw new AppError('not_found', FLOOR_MESSAGES['not_found']);
    this.ops.push({ kind: 'game.set_active', payload: { id, active } });
    this.gameList[i] = { ...this.gameList[i], active };
  }

  async gameUsage(_arenaId: string, gameId: string): Promise<GameUsage> {
    this.fail();
    const plays = this.playList.filter((p) => p.gameId === gameId);
    return {
      playingNow: plays.filter((p) => !p.endedAt).length,
      records: plays.length + (this.bookingsByGame.get(gameId) ?? 0),
    };
  }

  /** Like game.delete: only a game no play or booking names; a gone id is a no-op. */
  async deleteGame(arenaId: string, id: string): Promise<void> {
    this.fail();
    const i = this.gameList.findIndex((x) => x.id === id);
    if (i < 0) return;
    const usage = await this.gameUsage(arenaId, id);
    if (usage.playingNow) throw new AppError('game_in_play', FLOOR_MESSAGES['game_in_play']);
    if (usage.records) throw new AppError('game_has_history', FLOOR_MESSAGES['game_has_history']);
    this.ops.push({ kind: 'game.delete', payload: { id } });
    this.gameList.splice(i, 1);
    this.compatList = this.compatList.filter((c) => c.gameId !== id);
    this.deletedGames.add(id);
  }

  private fail(): void {
    const code = this.failNext;
    if (!code) return;
    this.failNext = null;
    throw new AppError(code, FLOOR_MESSAGES[code] ?? code);
  }
}
