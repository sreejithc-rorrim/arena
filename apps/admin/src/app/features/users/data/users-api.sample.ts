import { AppError } from '../../../core/auth/auth-api';
import { INVITE_MESSAGES, USER_MESSAGES, UsersApi } from './users-api';
import { ArenaUser, NewUser, PendingInvite, UserChange } from './user.models';

const ALL_PERMS = [
  'start',
  'bill',
  'discount',
  'members',
  'stations',
  'money',
  'reports',
  'settings',
];

function user(
  userId: string,
  name: string,
  role: ArenaUser['role'],
  perms: readonly string[],
  stats: [number, number, number] = [0, 0, 0],
): ArenaUser {
  const email = name.split(' ')[0].toLowerCase() + '@404arena.in';
  return {
    userId,
    name,
    email,
    role,
    perms,
    active: true,
    invited: false,
    bills30d: stats[0],
    takings30dPaise: stats[1],
    refunds30dPaise: stats[2],
  };
}

/** The design's sample people (`mkArena(0)`), with fixed 30-day figures. */
export function sampleUsers(): ArenaUser[] {
  return [
    user('u0', 'Arjun Mehra', 'owner', ALL_PERMS),
    user(
      'u1',
      'Priya Nair',
      'staff',
      ['start', 'bill', 'discount', 'members'],
      [312, 4_812_000, 24_000],
    ),
    user('u2', 'Rohan Das', 'staff', ['start', 'bill'], [287, 4_390_000, 0]),
    user('u3', 'Kavya Iyer', 'staff', ['start', 'bill', 'discount'], [265, 3_975_000, 12_000]),
  ];
}

/** One open invitation of the sample arena (Neha's has expired). */
export function sampleInvites(): PendingInvite[] {
  return [
    {
      inviteId: 'i1',
      email: 'farah@404arena.in',
      name: 'Farah Khan',
      role: 'staff',
      perms: ['start', 'bill', 'members'],
      createdAt: '2026-10-12T09:00:00Z',
      expiresAt: '2026-10-19T09:00:00Z',
      expired: false,
      invitedByName: 'Arjun Mehra',
    },
    {
      inviteId: 'i0',
      email: 'neha@404arena.in',
      name: 'Neha Joshi',
      role: 'staff',
      perms: ['start', 'bill'],
      createdAt: '2026-09-30T09:00:00Z',
      expiresAt: '2026-10-07T09:00:00Z',
      expired: true,
      invitedByName: null,
    },
  ];
}

/** Deterministic in-memory UsersApi for tests and offline previews. */
export class SampleUsersApi extends UsersApi {
  users: ArenaUser[] = sampleUsers();
  invites: PendingInvite[] = sampleInvites();
  /** Every invitation sent, in order. */
  readonly sent: NewUser[] = [];
  /** Set to make the next invite / withdraw fail with this code. */
  failNext: string | null = null;
  /** Set to make the next update report that the server adjusted it. */
  adjustNext = false;
  private next = 100;

  async list(): Promise<ArenaUser[]> {
    return this.users.map((u) => ({ ...u }));
  }

  async listInvites(): Promise<PendingInvite[]> {
    return this.invites.map((i) => ({ ...i }));
  }

  async invite(_arenaId: string, u: NewUser): Promise<{ inviteId: string; expiresAt: string }> {
    this.fail(USER_MESSAGES);
    this.sent.push(u);
    const inviteId = `i${this.next++}`;
    const expiresAt = '2026-10-20T14:00:00Z';
    // A newer invitation to the same address replaces the open one.
    this.invites = [
      {
        inviteId,
        email: u.email,
        name: u.name,
        role: u.role,
        perms: u.role === 'owner' ? ALL_PERMS : [...u.perms],
        createdAt: '2026-10-13T14:00:00Z',
        expiresAt,
        expired: false,
        invitedByName: 'Arjun Mehra',
      },
      ...this.invites.filter((i) => i.email !== u.email),
    ];
    return { inviteId, expiresAt };
  }

  async revokeInvite(_arenaId: string, inviteId: string): Promise<void> {
    this.fail(INVITE_MESSAGES);
    if (!this.invites.some((i) => i.inviteId === inviteId)) {
      throw new AppError('not_found', INVITE_MESSAGES['not_found']);
    }
    this.invites = this.invites.filter((i) => i.inviteId !== inviteId);
  }

  async update(
    _arenaId: string,
    userId: string,
    change: UserChange,
  ): Promise<{ adjusted: boolean }> {
    if (!this.users.some((u) => u.userId === userId)) {
      throw new AppError('not_found', 'That person is no longer on the list. Refresh');
    }
    const adjusted = this.adjustNext;
    this.adjustNext = false;
    this.users = this.users.map((u) =>
      u.userId === userId
        ? {
            ...u,
            name: change.name,
            // An adjusted save keeps what the server decided (here: the permissions unchanged).
            perms: adjusted ? u.perms : [...change.perms],
            active: change.active,
          }
        : u,
    );
    return { adjusted };
  }

  private fail(messages: Readonly<Record<string, string>>): void {
    const code = this.failNext;
    if (!code) return;
    this.failNext = null;
    throw new AppError(code, messages[code] ?? code);
  }
}
