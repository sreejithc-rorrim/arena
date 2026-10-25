-- arena_members(arena, since, since_30, search, limit, offset) — one page of the Members screen
--
-- Lives in `private`; clients reach it only through the SECURITY INVOKER wrapper
-- public.arena_members.
--
-- Registered members (walk-in guests left out) matching p_search (part of the
-- name, ignoring case, or digits of the phone; null/blank = all), newest visit
-- first then by name, p_limit (1–200, default 50) from p_offset. Returns
-- {total, rows: [{id, name, phone, birth_year, created_at, visits, minutes,
-- spent_30_paise, last_visit}]}: visits = bills not voided started since p_since
-- (or running); minutes = their play; spent_30_paise = what those started since
-- p_since_30 were billed; last_visit = the later of customers.last_visit_at and
-- the newest such bill's start. SECURITY DEFINER. Caller must be owner level in
-- p_arena (app_is_owner), else 'forbidden'.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.arena_members (
  p_arena    uuid,
  p_since    timestamp with time zone,
  p_since_30 timestamp with time zone,
  p_search   text default null,
  p_limit    integer default 50,
  p_offset   integer default 0
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_q      text := nullif(lower(btrim(coalesce(p_search, ''))), '');
  v_digits text := nullif(regexp_replace(coalesce(p_search, ''), '\D', '', 'g'), '');
  v_out    jsonb;
begin
  if not private.app_is_owner(p_arena) then
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can read members';
  end if;

  with m as (
    select c.* from customers c
     where c.arena_id = p_arena and not c.is_guest
       and (v_q is null or position(v_q in lower(c.name)) > 0
            or (v_digits is not null
                and position(v_digits in regexp_replace(coalesce(c.phone, ''), '\D', '', 'g')) > 0))
  ), b as (
    select s.customer_id as cid, s.started_at, s.billed_amount_paise as billed from sessions s
     where s.arena_id = p_arena and s.status <> 'voided' and (s.started_at >= p_since or s.status = 'active')
  ), pl as (
    select customer_id, sum(minutes) as minutes from _plays(p_arena, p_since) group by customer_id
  ), s as (
    select m.id, m.name, m.phone, m.birth_year, m.created_at,
           (select count(*) from b where b.cid = m.id) as visits,
           coalesce((select round(pl.minutes) from pl where pl.customer_id = m.id), 0) as minutes,
           coalesce((select sum(b.billed) from b where b.cid = m.id and b.started_at >= p_since_30), 0)
             as spent,
           greatest(m.last_visit_at, (select max(b.started_at) from b where b.cid = m.id)) as last_visit
      from m
  )
  select jsonb_build_object(
    'total', (select count(*) from s),
    'rows', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'phone', phone,
        'birth_year', birth_year, 'created_at', created_at, 'visits', visits, 'minutes', minutes,
        'spent_30_paise', spent, 'last_visit', last_visit) order by last_visit desc nulls last, name, id)
        from (select * from s order by last_visit desc nulls last, name, id
               limit least(greatest(coalesce(p_limit, 50), 1), 200)
               offset greatest(coalesce(p_offset, 0), 0)) p), '[]'::jsonb))
    into v_out;
  return v_out;
end;
$function$;

comment on function private.arena_members(uuid, timestamp with time zone, timestamp with time zone, text, integer, integer) is 'Client API (owner level): one searched page of registered members with their visits, minutes, 30-day spend and last visit, aggregated on the server.';

grant execute
  on function
    "private"."arena_members"(uuid, timestamp with time zone, timestamp with time zone, text,
    integer, integer)
  to "authenticated", "postgres", "service_role";

revoke all
  on function
    "private"."arena_members"(uuid, timestamp with time zone, timestamp with time zone, text,
    integer, integer)
  from public;

revoke all on function "private".arena_members(p_arena uuid, p_since timestamp with time zone, p_since_30 timestamp with time zone, p_search text, p_limit integer, p_offset integer) from anon;
