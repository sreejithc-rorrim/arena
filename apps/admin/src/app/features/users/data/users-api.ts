import { DOCUMENT } from '@angular/common';
import { InjectionToken, Service, inject } from '@angular/core';
import type { AuthError, PostgrestError } from '@supabase/supabase-js';
import { dbError } from '../../../core/arena/arena-api';
import { AppError } from '../../../core/auth/auth-api';
import { Supabase } from '../../../core/supabase/supabase';
import { pushOps } from '../../../core/sync/push-ops';
import { Captcha } from '../../../shared/turnstile/turnstile';
import { ArenaUser, NewUser, PendingInvite, UserChange } from './user.models';

/** Where the invitation link opens: this dashboard's own origin (its /accept-invite page). */
export const INVITE_LINK_BASE = new InjectionToken<string>('INVITE_LINK_BASE', {
  providedIn: 'root',
  factory: () => inject(DOCUMENT).location.origin,
});

/**
 * The arena's users (owners and staff): read through arena_staff(); new people join only by
 * invitation. invite_member (as the owner) creates a one-time token, then Supabase Auth e-mails
 * the address a link to /accept-invite carrying it (a sign-in link for an existing login, the
 * sign-up confirmation for a new one); the person accepts there with a password they choose.
 * Open invitations are read through arena_invites() and withdrawn with revoke_invite().
 * Changes are a `staff.update` op through sync_push — the same path, permission checks and
 * history as the floor app. Tests provide SampleUsersApi.
 */
@Service({ factory: () => new SupabaseUsersApi() })
export abstract class UsersApi {
  abstract list(arenaId: string): Promise<ArenaUser[]>;
  /** The arena's open invitations, newest first (owner level). */
  abstract listInvites(arenaId: string): Promise<PendingInvite[]>;
  /**
   * E-mails an invitation (a newer one to the same address replaces the open one). The reply is
   * the same whether or not the address already has a login.
   */
  abstract invite(arenaId: string, user: NewUser): Promise<{ inviteId: string; expiresAt: string }>;
  abstract revokeInvite(arenaId: string, inviteId: string): Promise<void>;
  /** `adjusted`: the server saved something other than what was sent (reload the list). */
  abstract update(
    arenaId: string,
    userId: string,
    change: UserChange,
  ): Promise<{ adjusted: boolean }>;
  /**
   * Removes a staff member for good (`staff.remove`): their name and details are erased and their
   * bills show "Deleted member"; the same e-mail can be invited again.
   */
  abstract remove(arenaId: string, userId: string): Promise<void>;
}

/** Refusals of staff.update, invite and withdraw, worded for the Users screen. */
export const USER_MESSAGES: Readonly<Record<string, string>> = {
  owner_profile: 'That login is already an owner of this arena',
  last_settings_holder: 'Someone must keep the Settings permission',
  invalid_permission: 'Unknown permission',
  invalid_role: 'Choose Staff or Owner',
  invalid_email: 'Enter a valid email',
  invalid_name: 'Names must be 1 to 80 characters',
  invalid_input: 'Check the name and email, then try again',
  not_found: 'That person is no longer on the list. Refresh',
  forbidden: 'Only an owner can do that',
  unauthorized: 'Your session has expired. Sign in again',
  email_rate_limited: 'Too many e-mails right now. Wait a while, then try again',
  email_failed: 'The invitation e-mail could not be sent, so nothing was saved. Try again',
  signup_disabled: 'This server does not accept new logins, so the invitation was not sent',
  server_error: 'Could not create the invitation. Try again',
};

/** Supabase Auth could not send the invitation e-mail → the error to show. */
export function emailFailure(e: AuthError): AppError {
  if (e.name === 'AuthRetryableFetchError') return new AppError('network', NETWORK);
  const code = e.code ?? '';
  if (e.status === 429 || code.includes('rate_limit')) {
    return new AppError('email_rate_limited', USER_MESSAGES['email_rate_limited']);
  }
  if (code === 'signup_disabled' || code === 'otp_disabled') {
    return new AppError('signup_disabled', USER_MESSAGES['signup_disabled']);
  }
  return new AppError('email_failed', USER_MESSAGES['email_failed']);
}

/** Refusals of revoke_invite / arena_invites. */
export const INVITE_MESSAGES: Readonly<Record<string, string>> = {
  not_found: 'That invitation is no longer open. Refresh',
  forbidden: 'You need the Settings permission (an owner, for an owner invitation) to withdraw it',
};

const NETWORK = 'Could not reach the server. Check the connection and try again';

/** "only an owner can invite an owner" → "Only an owner can invite an owner". */
function sentence(hint: string): string {
  const text = hint.trim().replace(/\.$/, '');
  return text.charAt(0).toUpperCase() + text.slice(1);
}

class SupabaseUsersApi extends UsersApi {
  private readonly supabase = inject(Supabase);
  private readonly linkBase = inject(INVITE_LINK_BASE);
  private readonly captcha = inject(Captcha);

  async list(arenaId: string): Promise<ArenaUser[]> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('arena_staff', { p_arena: arenaId });
    if (error) throw dbError(error);
    return (data as Record<string, unknown>[]).map((r) => ({
      userId: String(r['user_id']),
      name: String(r['name']),
      email: String(r['email'] ?? ''),
      role: r['role'] === 'owner' ? 'owner' : 'staff',
      perms: (r['perms'] as string[] | null) ?? [],
      active: r['active'] === true,
      invited: r['invited'] === true,
      bills30d: Number(r['bills_30d'] ?? 0),
      takings30dPaise: Number(r['takings_30d_paise'] ?? 0),
      refunds30dPaise: Number(r['refunds_30d_paise'] ?? 0),
    }));
  }

  async listInvites(arenaId: string): Promise<PendingInvite[]> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('arena_invites', { p_arena: arenaId });
    if (error) throw inviteError(error);
    return ((data as Record<string, unknown>[] | null) ?? []).map((r) => ({
      inviteId: String(r['invite_id']),
      email: String(r['email'] ?? ''),
      name: String(r['name'] ?? ''),
      role: r['role'] === 'owner' ? 'owner' : 'staff',
      perms: (r['perms'] as string[] | null) ?? [],
      createdAt: String(r['created_at']),
      expiresAt: String(r['expires_at']),
      expired: r['expired'] === true,
      invitedByName: r['invited_by_name'] == null ? null : String(r['invited_by_name']),
    }));
  }

  async invite(arenaId: string, user: NewUser): Promise<{ inviteId: string; expiresAt: string }> {
    const client = await this.supabase.client();
    const { data, error } = await client.rpc('invite_member', {
      p_arena: arenaId,
      p_email: user.email,
      p_name: user.name,
      p_role: user.role,
      p_perms: user.perms,
    });
    if (error) throw inviteRefusal(error);
    const made = data as { invite_id: string; token: string; expires_at: string };
    const link = new URL('/accept-invite', this.linkBase);
    link.searchParams.set('invite', made.invite_id);
    link.searchParams.set('token', made.token);
    // A throwaway client: sending the e-mail never touches the owner's own sign-in.
    const mailer = await this.supabase.isolatedClient();
    const { error: sendError } = await mailer.auth.signInWithOtp({
      email: user.email,
      options: {
        shouldCreateUser: true,
        emailRedirectTo: link.href,
        data: { name: user.name },
        captchaToken: this.captcha.take(),
      },
    });
    if (sendError) {
      // Nothing went out: take the invitation back so the list never shows one nobody received.
      await client.rpc('revoke_invite', { p_arena: arenaId, p_invite: made.invite_id });
      throw emailFailure(sendError);
    }
    return { inviteId: String(made.invite_id), expiresAt: String(made.expires_at) };
  }

  async revokeInvite(arenaId: string, inviteId: string): Promise<void> {
    const client = await this.supabase.client();
    const { error } = await client.rpc('revoke_invite', { p_arena: arenaId, p_invite: inviteId });
    if (error) throw inviteError(error);
  }

  async update(
    arenaId: string,
    userId: string,
    change: UserChange,
  ): Promise<{ adjusted: boolean }> {
    const [result] = await pushOps(
      await this.supabase.client(),
      arenaId,
      [
        {
          kind: 'staff.update',
          payload: {
            user_id: userId,
            name: change.name,
            perms: change.perms,
            active: change.active,
          },
        },
      ],
      USER_MESSAGES,
    );
    return { adjusted: result?.['adjusted'] === true };
  }

  async remove(arenaId: string, userId: string): Promise<void> {
    await pushOps(
      await this.supabase.client(),
      arenaId,
      [{ kind: 'staff.remove', payload: { user_id: userId } }],
      USER_MESSAGES,
    );
  }
}

/** invite_member refused: its reason (`forbidden` carries the server's hint) or the generic one. */
function inviteRefusal(e: PostgrestError): AppError {
  if (e.code === '42501') {
    return new AppError('forbidden', e.hint ? sentence(e.hint) : USER_MESSAGES['forbidden']);
  }
  if (e.code === 'P0001' && USER_MESSAGES[e.message]) {
    return new AppError(e.message, USER_MESSAGES[e.message]);
  }
  return dbError(e);
}

function inviteError(e: PostgrestError): AppError {
  const error = dbError(e);
  return INVITE_MESSAGES[error.code]
    ? new AppError(error.code, INVITE_MESSAGES[error.code])
    : error;
}
