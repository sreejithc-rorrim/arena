import { AppError } from '../../../core/auth/auth-api';
import {
  ACCESSORY_MESSAGES,
  AccessoriesApi,
  accessoryOps,
  kindOps,
  moveOps,
  statusOps,
} from './accessories-api';
import { Accessory, AccessoryKind, AccessoryMove, AccessoryStatus } from './accessory.models';

function acc(id: string, label: string, home: string, o: Partial<Accessory> = {}): Accessory {
  return {
    id,
    label,
    kindId: null,
    homeId: home,
    currentId: home,
    status: 'usable',
    notes: null,
    loanReturnTo: null,
    loanSessionRef: null,
    ...o,
  };
}

/**
 * Deterministic accessories on SampleFloorApi's stations: HEX-2 is lent to VOID (its
 * session owes the return), VOID-2 is faulty, GHOST-1 missing, RIFT also has a VR headset. Writes
 * apply in memory like the server would and are recorded in `ops` (move ids blanked).
 */
export class SampleAccessoriesApi extends AccessoriesApi {
  kindList: AccessoryKind[] = [
    { id: 'k-pad', name: 'Controller', countsAsController: true, sortOrder: 0, active: true },
    { id: 'k-vr', name: 'VR headset', countsAsController: false, sortOrder: 1, active: true },
  ];
  list: Accessory[] = [
    acc('c-hex-1', 'HEX-1', 's-hex', { kindId: 'k-pad' }),
    acc('c-hex-2', 'HEX-2', 's-hex', {
      kindId: 'k-pad',
      currentId: 's-void',
      loanReturnTo: 's-hex',
      loanSessionRef: 'g:b-live-void',
    }),
    acc('c-void-1', 'VOID-1', 's-void'),
    acc('c-void-2', 'VOID-2', 's-void', { status: 'faulty', notes: 'Left stick drift' }),
    acc('c-ghost-1', 'GHOST-1', 's-ghost', { status: 'missing' }),
    acc('c-rift-1', 'RIFT-1', 's-rift'),
    acc('c-rift-vr', 'RIFT VR', 's-rift', { kindId: 'k-vr' }),
  ];
  moveList: (AccessoryMove & { accessoryId: string })[] = [
    {
      accessoryId: 'c-hex-2',
      id: 'm-1',
      fromId: 's-hex',
      toId: 's-void',
      kind: 'loan',
      sessionRef: 'g:b-live-void',
      at: '2026-10-13T12:00:00Z',
    },
  ];
  /** Every write, in order, as `kind` + payload. */
  readonly ops: { kind: string; payload: unknown }[] = [];
  /** Reads of one accessory's moves, by id. */
  readonly moveReads: string[] = [];
  /** Set to make the next call fail with this code. */
  failNext: string | null = null;

  async accessories(): Promise<Accessory[]> {
    this.fail();
    return [...this.list].sort((a, b) => a.label.localeCompare(b.label));
  }

  async accessory(_arenaId: string, id: string): Promise<Accessory | null> {
    this.fail();
    return this.list.find((c) => c.id === id) ?? null;
  }

  async save(_arenaId: string, c: Accessory): Promise<void> {
    this.fail();
    this.ops.push(...accessoryOps(c));
    const existing = this.list.find((x) => x.id === c.id);
    this.list = existing ? this.list.map((x) => (x.id === c.id ? { ...c } : x)) : [...this.list, c];
  }

  async setStatus(
    _arenaId: string,
    id: string,
    status: AccessoryStatus,
    notes: string | null,
  ): Promise<void> {
    this.fail();
    this.ops.push(...statusOps(id, status, notes));
    if (!this.list.some((c) => c.id === id)) {
      throw new AppError('not_found', ACCESSORY_MESSAGES['not_found']);
    }
    this.list = this.list.map((c) => (c.id === id ? { ...c, status, notes } : c));
  }

  async move(
    _arenaId: string,
    id: string,
    kind: 'returnHome' | 'permanent',
    toId?: string,
  ): Promise<void> {
    this.fail();
    this.ops.push(
      ...moveOps(id, kind, toId).map((o) => ({
        ...o,
        payload: { ...(o.payload as object), move_id: '' },
      })),
    );
    this.list = this.list.map((c) => {
      if (c.id !== id) return c;
      const to = kind === 'returnHome' ? c.homeId : (toId as string);
      return {
        ...c,
        currentId: to,
        homeId: kind === 'permanent' ? to : c.homeId,
        loanReturnTo: null,
        loanSessionRef: null,
      };
    });
  }

  async moves(_arenaId: string, id: string, limit: number): Promise<AccessoryMove[]> {
    this.fail();
    this.moveReads.push(id);
    return this.moveList
      .filter((m) => m.accessoryId === id)
      .slice(0, limit)
      .map(({ accessoryId: _, ...m }) => m);
  }

  async kinds(): Promise<AccessoryKind[]> {
    this.fail();
    return [...this.kindList].sort((a, b) => a.sortOrder - b.sortOrder);
  }

  async saveKind(_arenaId: string, kind: AccessoryKind): Promise<void> {
    this.fail();
    this.ops.push(...kindOps(kind));
    const existing = this.kindList.some((k) => k.id === kind.id);
    this.kindList = existing
      ? this.kindList.map((k) => (k.id === kind.id ? { ...kind } : k))
      : [...this.kindList, kind];
  }

  async removeKind(_arenaId: string, id: string): Promise<'deleted' | 'retired'> {
    this.fail();
    this.ops.push({ kind: 'accessory_kind.remove', payload: { id } });
    if (this.list.some((c) => c.kindId === id)) {
      this.kindList = this.kindList.map((k) => (k.id === id ? { ...k, active: false } : k));
      return 'retired';
    }
    this.kindList = this.kindList.filter((k) => k.id !== id);
    return 'deleted';
  }

  private fail(): void {
    const code = this.failNext;
    if (!code) return;
    this.failNext = null;
    throw new AppError(code, ACCESSORY_MESSAGES[code] ?? code);
  }
}
