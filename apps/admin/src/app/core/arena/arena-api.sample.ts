import { AppError } from '../auth/auth-api';
import { ARENA_MESSAGES, ArenaApi, ArenaDetails, Membership } from './arena-api';

const ALL = [
  'start',
  'bill',
  'discount',
  'members',
  'stations',
  'money',
  'reports',
  'settings',
];

/** Deterministic in-memory ArenaApi for tests: the design's two arenas, owned by the caller. */
export class SampleArenaApi extends ArenaApi {
  memberships: Membership[];
  /** Area and phone per arena (the name lives on the membership). */
  extra: Record<string, { area: string; phone: string }> = {
    a1: { area: 'Koramangala', phone: '080 4110 2209' },
  };

  constructor(owned = true) {
    super();
    this.memberships = owned
      ? [
          {
            arenaId: 'a1',
            arenaName: '404 Arena Koramangala',
            name: 'Arjun Mehra',
            role: 'owner',
            perms: ALL,
            active: true,
          },
          {
            arenaId: 'a2',
            arenaName: '404 Arena Indiranagar',
            name: 'Arjun Mehra',
            role: 'owner',
            perms: ALL,
            active: true,
          },
        ]
      : [];
  }

  async myArenas(): Promise<Membership[]> {
    return [...this.memberships];
  }

  async createArena(arenaName: string, ownerName: string): Promise<string> {
    if (this.memberships.some((m) => m.role === 'owner')) {
      throw new AppError('arena_limit', 'This login already owns an arena');
    }
    const id = `a${this.memberships.length + 1}`;
    this.memberships.push({
      arenaId: id,
      arenaName,
      name: ownerName,
      role: 'owner',
      perms: ALL,
      active: true,
    });
    return id;
  }

  async details(arenaId: string): Promise<ArenaDetails> {
    const m = this.memberships.find((x) => x.arenaId === arenaId);
    if (!m) throw new AppError('not_found', 'That is no longer there. Refresh');
    const e = this.extra[arenaId] ?? { area: '', phone: '' };
    return { name: m.arenaName, area: e.area, phone: e.phone };
  }

  async saveDetails(arenaId: string, d: ArenaDetails): Promise<void> {
    const name = d.name.trim();
    if (!name || name.length > 80)
      throw new AppError('invalid_name', ARENA_MESSAGES['invalid_name']);
    if (d.phone && !/^[0-9+() -]{6,20}$/.test(d.phone.trim())) {
      throw new AppError('invalid_phone', ARENA_MESSAGES['invalid_phone']);
    }
    this.memberships = this.memberships.map((m) =>
      m.arenaId === arenaId ? { ...m, arenaName: name } : m,
    );
    this.extra[arenaId] = { area: d.area.trim(), phone: d.phone.trim() };
  }
}
