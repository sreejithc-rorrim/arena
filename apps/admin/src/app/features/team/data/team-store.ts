import { Service, computed, inject, signal } from '@angular/core';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { LoginScope } from '../../../core/auth/login-scope';
import { TeamApi } from './team-api';
import { TeamMember } from './team.models';

/** The current arena's staff profiles for Team, read again after a name or access change. */
@Service()
export class TeamStore {
  private readonly api = inject(TeamApi);
  private readonly arena = inject(ArenaContext);

  readonly staff = signal<readonly TeamMember[] | null>(null);
  readonly loading = signal(false);
  readonly loadError = signal('');
  readonly nameOfUser = computed(
    () => new Map((this.staff() ?? []).map((s) => [s.userId, s.name])),
  );

  private loadedArena: string | null = null;
  private latest = 0;

  constructor() {
    inject(LoginScope).onEnd(() => {
      this.latest++;
      this.loadedArena = null;
      this.staff.set(null);
      this.loading.set(false);
      this.loadError.set('');
    });
  }

  async load(force = false): Promise<void> {
    const arenaId = this.arena.current().id;
    if (!arenaId || (!force && this.loadedArena === arenaId)) return;
    if (this.loadedArena !== arenaId) this.staff.set(null);
    const call = ++this.latest;
    this.loading.set(true);
    this.loadError.set('');
    try {
      const staff = await this.api.load(arenaId);
      if (call !== this.latest) return;
      this.staff.set(staff);
      this.loadedArena = arenaId;
    } catch (e) {
      if (call === this.latest) this.loadError.set(toAppError(e).message);
    } finally {
      if (call === this.latest) this.loading.set(false);
    }
  }

  async refresh(): Promise<void> {
    if (this.loadedArena || this.loadError()) await this.load(true);
  }
}
