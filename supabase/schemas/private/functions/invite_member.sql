-- invite_member(arena, email, name, role, perms) — invite someone to an arena
--
-- Lives in `private`, which the Data API does not expose: SECURITY DEFINER
-- code never sits in an API schema. Clients reach it only through the
-- SECURITY INVOKER wrapper public.invite_member (the admin dashboard calls it as
-- the signed-in owner, then has Supabase Auth e-mail the link).
--
-- Creates a one-time invitation (staff_invites) and returns
-- {invite_id, token, expires_at}. Only the token's SHA-256 is stored; it is
-- valid for 7 days. It never reads or changes the invited address's login, so
-- it says nothing about whether that address has an account. Authority is the
-- same as op_staff_update:
--   role 'staff': the caller holds Settings (_need); only an owner-level caller
--     (app_is_owner) may include money or reports.
--   role 'owner': the caller is an active role='owner' member; a co-owner gets
--     every permission.
-- A newer invite to the same address replaces the open one (the old link stops
-- working); only an owner may replace an owner invite. Refuses inviting
-- yourself. Raises 'forbidden' (42501), 'invalid_role', 'invalid_email',
-- 'invalid_name', 'invalid_permission'.
create or replace function private.invite_member (
  p_arena uuid,
  p_email text,
  p_name  text,
  p_role  text,
  p_perms text[]
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_email   text := lower(btrim(coalesce(p_email, '')));
  v_name    text := btrim(coalesce(p_name, ''));
  v_owner   boolean;
  v_perms   text[];
  v_token   text;
  v_id      uuid;
  v_expires timestamptz := statement_timestamp() + interval '7 days';
begin
  if auth.uid() is null then
    raise exception 'forbidden' using errcode = '42501', hint = 'sign in first';
  end if;
  if p_role is null or p_role not in ('staff', 'owner') then
    raise exception 'invalid_role' using hint = 'role must be staff or owner';
  end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'invalid_email' using hint = 'enter a valid e-mail address';
  end if;
  if length(v_name) < 1 or length(v_name) > 80 then
    raise exception 'invalid_name' using hint = 'the name must be 1 to 80 characters';
  end if;
  v_owner := exists (select 1 from staff_profiles where arena_id = p_arena
                       and user_id = auth.uid() and active and role = 'owner');
  if p_role = 'owner' then
    if not v_owner then
      raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can invite an owner';
    end if;
    v_perms := _known_perms();
  else
    perform _need(p_arena, 'settings');
    perform _assert_known_perms(p_perms);
    v_perms := coalesce(p_perms, '{}');
    if v_perms && array['money', 'reports', 'bill_edit', 'bill_record']
       and not private.app_is_owner(p_arena) then
      raise exception 'forbidden' using errcode = '42501',
        hint = 'only an owner can grant money, reports, or editing or adding bills';
    end if;
  end if;
  if exists (select 1 from auth.users where id = auth.uid() and lower(email) = v_email) then
    raise exception 'forbidden' using errcode = '42501', hint = 'you cannot invite yourself';
  end if;
  if not v_owner and exists (select 1 from staff_invites where arena_id = p_arena
       and email = v_email and role = 'owner' and accepted_at is null and revoked_at is null) then
    raise exception 'forbidden' using errcode = '42501',
      hint = 'an owner invited this address; only an owner can replace that invite';
  end if;
  update staff_invites set revoked_at = statement_timestamp()
   where arena_id = p_arena and email = v_email and accepted_at is null and revoked_at is null;
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into staff_invites (arena_id, email, name, role, perms, token_hash, invited_by, expires_at)
    values (p_arena, v_email, v_name, p_role, v_perms,
            extensions.digest(v_token, 'sha256'), auth.uid(), v_expires)
    returning id into v_id;
  return jsonb_build_object('invite_id', v_id, 'token', v_token, 'expires_at', v_expires);
end;
$function$;

comment on function private.invite_member(uuid, text, text, text, text[]) is 'Create a one-time invitation to the arena (staff: caller holds Settings, money/reports only from owner level; owner: caller is an owner). Returns {invite_id, token, expires_at}; only the token''s SHA-256 is stored. Never reads or changes the invited address''s login.';

grant execute
  on function "private"."invite_member"(uuid, text, text, text, text[])
  to "authenticated", "postgres", "service_role";

revoke all on function "private"."invite_member"(uuid, text, text, text, text[]) from public;

revoke all on function "private".invite_member(p_arena uuid, p_email text, p_name text, p_role text, p_perms text[]) from anon;
