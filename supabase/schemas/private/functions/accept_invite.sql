-- accept_invite(invite, token) — the invited person joins the arena
--
-- Lives in `private`, which the Data API does not expose: SECURITY DEFINER
-- code never sits in an API schema. Clients reach it only through the
-- SECURITY INVOKER wrapper public.accept_invite (the admin dashboard's
-- /accept-invite page, opened from the e-mailed link).
--
-- Checks, in this order (the token first, so a wrong token learns nothing):
--   the caller is signed in; the invite exists and the token's SHA-256 matches
--   ('invite_invalid'); it is not accepted ('invite_used'), withdrawn
--   ('invite_revoked') or past expires_at ('invite_expired'); the caller's auth
--   e-mail is the invited address ('invite_wrong_account', 42501) and is
--   confirmed ('email_not_confirmed'); whoever invited still holds the
--   authority the invite needs (same rules as invite_member, else
--   'invite_invalid'); the caller is not already an owner here
--   ('owner_profile').
-- Then upserts the caller's staff_profiles row in the invite's arena (role,
-- perms and name from the invite, active; a removed member's kept row comes back,
-- removed_at cleared) — the only arena it can touch — keeps
-- someone holding Settings (_assert_settings_holder) and marks the invite
-- accepted, so the token works once. Returns {arena_id, arena_name, role}.
create or replace function private.accept_invite (
  p_invite uuid,
  p_token  text
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_inv       staff_invites%rowtype;
  v_email     text;
  v_confirmed timestamptz;
  v_allowed   boolean;
begin
  if auth.uid() is null then
    raise exception 'forbidden' using errcode = '42501', hint = 'sign in first';
  end if;
  select * into v_inv from staff_invites where id = p_invite for update;
  if not found or p_token is null
     or extensions.digest(p_token, 'sha256') <> v_inv.token_hash then
    raise exception 'invite_invalid' using hint = 'this invitation link is not valid';
  end if;
  if v_inv.accepted_at is not null then
    raise exception 'invite_used' using hint = 'this invitation was already accepted';
  end if;
  if v_inv.revoked_at is not null then
    raise exception 'invite_revoked' using hint = 'this invitation was withdrawn';
  end if;
  if v_inv.expires_at <= statement_timestamp() then
    raise exception 'invite_expired' using hint = 'ask for a new invitation';
  end if;
  select lower(email), email_confirmed_at into v_email, v_confirmed
    from auth.users where id = auth.uid();
  if v_email is distinct from v_inv.email then
    raise exception 'invite_wrong_account' using errcode = '42501',
      hint = 'sign in with the e-mail address the invitation was sent to';
  end if;
  if v_confirmed is null then
    raise exception 'email_not_confirmed' using hint = 'confirm your e-mail address first';
  end if;
  -- The inviter's authority is re-checked now: an invite from someone who has
  -- since lost Settings (or ownership) must not still work.
  if v_inv.role = 'owner' then
    v_allowed := exists (select 1 from staff_profiles where arena_id = v_inv.arena_id
                           and user_id = v_inv.invited_by and active and role = 'owner');
  else
    v_allowed := exists (select 1 from staff_profiles where arena_id = v_inv.arena_id
                           and user_id = v_inv.invited_by and active
                           and (role = 'owner' or 'settings' = any(perms))
                           and (not (v_inv.perms && array['money', 'reports'])
                                or role = 'owner' or perms && array['money', 'reports']));
  end if;
  if not v_allowed then
    raise exception 'invite_invalid'
      using hint = 'the person who invited you can no longer add members';
  end if;
  if exists (select 1 from staff_profiles where arena_id = v_inv.arena_id
              and user_id = auth.uid() and role = 'owner') then
    raise exception 'owner_profile' using hint = 'you are already an owner of this arena';
  end if;
  insert into staff_profiles (arena_id, user_id, name, role, perms, active)
    values (v_inv.arena_id, auth.uid(), v_inv.name, v_inv.role, v_inv.perms, true)
  on conflict (user_id, arena_id) do update
    set name = excluded.name, role = excluded.role, perms = excluded.perms, active = true,
        removed_at = null, updated_at = statement_timestamp();
  perform _assert_settings_holder(v_inv.arena_id);
  update staff_invites set accepted_at = statement_timestamp(), accepted_by = auth.uid()
   where id = v_inv.id;
  return jsonb_build_object(
    'arena_id', v_inv.arena_id,
    'arena_name', (select name from arenas where id = v_inv.arena_id),
    'role', v_inv.role);
end;
$function$;

comment on function private.accept_invite(uuid, text) is 'The invited, confirmed login (auth e-mail = invited address) presents the one-time token and joins the invite''s arena with its role and permissions. Single use; refuses wrong, used, withdrawn or expired invites, the wrong account, and invites whose inviter lost the authority.';

grant execute
  on function "private"."accept_invite"(uuid, text)
  to "authenticated", "postgres", "service_role";

revoke all on function "private"."accept_invite"(uuid, text) from public;

revoke all on function "private".accept_invite(p_invite uuid, p_token text) from anon;
