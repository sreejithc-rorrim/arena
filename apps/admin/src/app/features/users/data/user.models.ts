export type UserRole = 'owner' | 'staff';

/** One person with access to the arena, as arena_staff() reports it. Money in integer paise. */
export interface ArenaUser {
  readonly userId: string;
  readonly name: string;
  readonly email: string;
  readonly role: UserRole;
  readonly perms: readonly string[];
  readonly active: boolean;
  /** The login has never signed in. */
  readonly invited: boolean;
  readonly bills30d: number;
  readonly takings30dPaise: number;
  readonly refunds30dPaise: number;
}

/**
 * The permissions a Settings holder toggles for staff: the floor ones in the design's order
 * (`const PERMS`) plus `bill_edit` / `bill_record` (owner-granted, like money / reports —
 * OWNER_ONLY_PERMS: edit one's own closed bills, add missed ones, in the floor app). Owners hold
 * every permission and show no toggles. Neither bill one is in the invite default.
 */
export const FLOOR_PERMS = [
  { code: 'start', label: 'Start sessions', sub: 'Open a session on a free station' },
  { code: 'bill', label: 'Take payment', sub: 'Close bills in Cash or UPI' },
  { code: 'discount', label: 'Give discounts', sub: 'Up to the staff discount limit' },
  { code: 'members', label: 'Register members', sub: 'Add new members with consent' },
  {
    code: 'bill_edit',
    label: 'Edit own bills',
    sub: 'Change the amount of bills they started, with a comment (floor app)',
  },
  {
    code: 'bill_record',
    label: 'Add missed bills',
    sub: 'Add a bill for play that was never started in the app, with a reason (floor app)',
  },
] as const;

/** Permissions only an owner may grant or take away (the server refuses anyone else). */
export const OWNER_ONLY_PERMS: readonly string[] = ['bill_edit', 'bill_record'];

/** What a new staff login starts with (the design's invite default). */
export const DEFAULT_STAFF_PERMS: readonly string[] = ['start', 'bill', 'members'];

export type UserStatus = 'Owner' | 'Off' | 'Invited' | 'Active';

export function userStatus(u: ArenaUser): UserStatus {
  if (!u.active) return 'Off';
  if (u.invited) return 'Invited';
  return u.role === 'owner' ? 'Owner' : 'Active';
}

/**
 * An invitation to join the arena (Supabase Auth e-mails a one-time link; the person chooses their
 * own password and joins when they accept it). Nobody chooses a password for anyone else.
 */
export interface NewUser {
  readonly role: UserRole;
  readonly name: string;
  readonly email: string;
  /** Staff only; owners always hold every permission. */
  readonly perms: readonly string[];
}

/** An invitation not yet accepted or withdrawn, as arena_invites() reports it. */
export interface PendingInvite {
  readonly inviteId: string;
  readonly email: string;
  readonly name: string;
  readonly role: UserRole;
  readonly perms: readonly string[];
  readonly createdAt: string;
  readonly expiresAt: string;
  /** Past expires_at: the link no longer works (send a new invitation). */
  readonly expired: boolean;
  /** The inviter's name in this arena; null when they are no longer a member. */
  readonly invitedByName: string | null;
}

/** How long an invitation link works (set by the server; shown in the copy). */
export const INVITE_DAYS = 7;

export interface UserChange {
  readonly name: string;
  readonly perms: readonly string[];
  readonly active: boolean;
}
