-- arena_staff(arena) — the arena's staff list for the owner dashboard
--
-- Lives in `private`, which the Data API does not expose: SECURITY DEFINER
-- code never sits in an API schema. Clients reach it only through the
-- SECURITY INVOKER wrapper public.arena_staff.
--
-- One jsonb object per staff_profiles row of p_arena: {user_id, name, email,
-- role, perms, active, invited, bills_30d, takings_30d_paise,
-- refunds_30d_paise}. email comes from auth.users (not readable by clients
-- directly); invited = the login has never signed in. The 30-day figures count
-- the payments and refunds the member recorded since
-- now() - 30 days: bills = distinct sessions they took a payment for,
-- takings = net paise (payments minus refunds), refunds = paise refunded
-- (positive). Owners first, then by name. SECURITY DEFINER.
-- Caller must be owner level in p_arena (app_is_owner), else 'forbidden'.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.arena_staff (
  p_arena uuid
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare v_since timestamptz := statement_timestamp() - interval '30 days';
begin
  if not private.app_is_owner(p_arena) then
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can list staff';
  end if;
  return coalesce((
    with money as (
      select created_by, 's:' || session_id::text as bill, amount_paise
        from payments where arena_id = p_arena and created_at >= v_since
    ), per as (
      select created_by,
             count(distinct bill) filter (where amount_paise > 0) as bills,
             coalesce(sum(amount_paise), 0) as net,
             coalesce(-sum(amount_paise) filter (where amount_paise < 0), 0) as refunds
        from money group by created_by
    )
    select jsonb_agg(jsonb_build_object(
        'user_id', s.user_id, 'name', s.name, 'email', u.email, 'role', s.role,
        'perms', to_jsonb(s.perms), 'active', s.active,
        'invited', u.last_sign_in_at is null,
        'bills_30d', coalesce(p.bills, 0), 'takings_30d_paise', coalesce(p.net, 0),
        'refunds_30d_paise', coalesce(p.refunds, 0))
      order by s.role = 'owner' desc, lower(s.name))
      from staff_profiles s
      join auth.users u on u.id = s.user_id
      left join per p on p.created_by = s.user_id
     where s.arena_id = p_arena), '[]'::jsonb);
end;
$function$;

comment on function private.arena_staff(uuid) is 'Client API (owner level): the arena''s staff with login e-mail, never-signed-in flag and 30-day bills, net takings and refunds they recorded, for the admin dashboard''s Staff screen.';

grant execute on function "private"."arena_staff"(uuid) to "authenticated", "postgres", "service_role";

revoke all on function "private"."arena_staff"(uuid) from public;

revoke all on function "private".arena_staff(p_arena uuid) from anon;
