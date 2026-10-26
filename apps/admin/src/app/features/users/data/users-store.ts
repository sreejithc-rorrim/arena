import { Service, computed, inject, signal } from '@angular/core';
import { ArenaContext } from '../../../core/arena/arena-context';
import { toAppError } from '../../../core/auth/auth-api';
import { LoginScope } from '../../../core/auth/login-scope';
import { UsersApi } from './users-api';
import { ArenaUser, NewUser, PendingInvite, UserChange } from './user.models';

/**
 * The current arena's users and open invitations. Every change goes to the server first; the
 * lists then show what the server accepted (a refusal leaves them unchanged and is reported to
 * the caller).
 */
@Service()
export class UsersStore {
  private readonly api = inject(UsersApi);
  private readonly arena = inject(ArenaContext);

  readonly users = signal<readonly ArenaUser[]>([]);
  readonly owners = computed(() => this.users().filter((u) => u.role === 'owner'));
  readonly staff = computed(() => this.users().filter((u) => u.role === 'staff'));
  readonly byId = computed(() => new Map(this.users().map((u) => [u.userId, u])));
  /** Open invitations, newest first. */
  readonly invites = signal<readonly PendingInvite[]>([]);
  readonly loading = signal(false);
  readonly loadError = signal('');
  /** The invitations could not be read (the people list still shows). */
  readonly invitesError = signal('');
  /** userId of a user (or inviteId of an invitation) with a change in flight. */
  readonly saving = signal<string | null>(null);
  private loadedArena: string | null = null;
  private outOfDate = false;
  /** Each load's number; only the newest one's answer lands (a switch of arena mid-load). */
  private latest = 0;

  constructor() {
    // Sign-out or another login: the people and invitations leave memory; a read in flight does
    // not land.
    inject(LoginScope).onEnd(() => {
      this.latest++;
      this.loadedArena = null;
      this.users.set([]);
      this.invites.set([]);
      this.loading.set(false);
      this.loadError.set('');
      this.invitesError.set('');
      this.saving.set(null);
    });
  }

  /** Loads the current arena's users and invitations (again on an arena switch, or forced). */
  async load(force = false): Promise<void> {
    const arenaId = this.arena.current().id;
    if (!arenaId || (!force && !this.outOfDate && this.loadedArena === arenaId)) return;
    if (this.loadedArena !== arenaId) {
      this.users.set([]);
      this.invites.set([]);
    }
    this.outOfDate = false;
    const call = ++this.latest;
    this.loading.set(true);
    this.loadError.set('');
    try {
      const [users] = await Promise.all([this.api.list(arenaId), this.loadInvites(arenaId)]);
      if (call !== this.latest) return;
      this.users.set(users);
      this.loadedArena = arenaId;
    } catch (e) {
      if (call === this.latest) this.loadError.set(toAppError(e).message);
    } finally {
      if (call === this.latest) this.loading.set(false);
    }
  }

  /**
   * Marks the data out of date without reading it (a live update while no screen shows it): the
   * next screen that loads it reads it again, instead of a download nobody looks at.
   */
  stale(): void {
    this.outOfDate = true;
  }

  /** Reads both lists again if a screen has loaded them (live updates). */
  async refresh(): Promise<void> {
    if (this.loadedArena) await this.load(true);
  }

  /** E-mails the invitation, then shows it under the open invitations. */
  async invite(user: NewUser): Promise<{ inviteId: string; expiresAt: string }> {
    const arenaId = this.arena.current().id;
    const result = await this.api.invite(arenaId, user);
    await this.loadInvites(arenaId);
    return result;
  }

  async revoke(invite: PendingInvite): Promise<void> {
    const arenaId = this.arena.current().id;
    this.saving.set(invite.inviteId);
    try {
      await this.api.revokeInvite(arenaId, invite.inviteId);
    } finally {
      // Withdrawn, or gone already: either way show what is still open.
      await this.loadInvites(arenaId);
      this.saving.set(null);
    }
  }

  async change(user: ArenaUser, change: Partial<UserChange>): Promise<void> {
    const next: UserChange = {
      name: change.name ?? user.name,
      perms: change.perms ?? user.perms,
      active: change.active ?? user.active,
    };
    this.saving.set(user.userId);
    try {
      const { adjusted } = await this.api.update(this.arena.current().id, user.userId, next);
      if (adjusted) {
        // The server saved something else (e.g. kept a last Settings holder): show its version.
        await this.load(true);
      } else {
        this.users.update((list) =>
          list.map((u) => (u.userId === user.userId ? { ...u, ...next } : u)),
        );
      }
    } finally {
      this.saving.set(null);
    }
  }

  /** Removes a staff member for good, then reads the list again (their row is anonymised). */
  async remove(user: ArenaUser): Promise<void> {
    this.saving.set(user.userId);
    try {
      await this.api.remove(this.arena.current().id, user.userId);
      await this.load(true);
    } finally {
      this.saving.set(null);
    }
  }

  private async loadInvites(arenaId: string): Promise<void> {
    this.invitesError.set('');
    try {
      const invites = await this.api.listInvites(arenaId);
      if (this.arena.current().id === arenaId) this.invites.set(invites);
    } catch (e) {
      this.invitesError.set(toAppError(e).message);
    }
  }
}
