-- arena_activity(arena, resource, customer, since, limit) — a station's or member's recent play
--
-- Lives in `private`; clients reach it only through the SECURITY INVOKER wrapper
-- public.arena_activity. Read when the dashboard opens one station or member.
--
-- Exactly one of p_resource / p_customer. Returns {bills, games}:
--   bills — the newest p_limit (1–50, default 6) bills with play on the station
--           (or of the member) that started since p_since, or are running:
--           [{bill_id, kind (always 'single'), started_at, status, billed_paise, customer (null for
--           a walk-in), station, game}] (station / game of that bill's latest
--           play there); voided bills included, so the list shows them as Void;
--   games — for a member: [{game_id, name, minutes}] minutes per game played
--           since p_since (bills not voided), most first; [] for a station.
-- SECURITY DEFINER. Caller must be owner level in p_arena (app_is_owner), else
-- 'forbidden'; 'invalid' unless exactly one of p_resource / p_customer is set.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.arena_activity (
  p_arena    uuid,
  p_resource uuid,
  p_customer uuid,
  p_since    timestamp with time zone,
  p_limit    integer default 6
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare v_out jsonb;
begin
  if not private.app_is_owner(p_arena) then
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can read play history';
  end if;
  if (p_resource is null) = (p_customer is null) then
    raise exception 'invalid' using hint = 'one of station or member';
  end if;

  with pl as (
    select 'single' as kind, g.session_id as bill_id, s.status, s.customer_id, g.resource_id,
           g.game_id, g.started_at, s.billed_amount_paise as billed
      from session_segments g join sessions s on s.id = g.session_id
     where g.arena_id = p_arena and (g.started_at >= p_since or g.ended_at is null)
       and (g.resource_id = p_resource or s.customer_id = p_customer)
  ), latest as (
    select distinct on (kind, bill_id) * from pl order by kind, bill_id, started_at desc
  )
  select jsonb_build_object(
    'bills', coalesce((select jsonb_agg(jsonb_build_object('bill_id', l.bill_id, 'kind', l.kind,
        'started_at', l.started_at, 'status', l.status, 'billed_paise', l.billed,
        'customer', case when c.is_guest then null else c.name end, 'station', r.name,
        'game', gm.name) order by l.started_at desc, l.bill_id)
        from (select * from latest order by started_at desc, bill_id
               limit least(greatest(coalesce(p_limit, 6), 1), 50)) l
        left join customers c on c.id = l.customer_id
        left join resources r on r.id = l.resource_id
        left join games gm on gm.id = l.game_id), '[]'::jsonb),
    'games', case when p_customer is null then '[]'::jsonb else coalesce((
        select jsonb_agg(jsonb_build_object('game_id', t.game_id, 'name', gm.name,
            'minutes', round(t.minutes)) order by t.minutes desc, gm.name)
          from (select game_id, sum(minutes) as minutes from _plays(p_arena, p_since)
                 where customer_id = p_customer and game_id is not null group by game_id) t
          join games gm on gm.id = t.game_id), '[]'::jsonb) end)
    into v_out;
  return v_out;
end;
$function$;

comment on function private.arena_activity(uuid, uuid, uuid, timestamp with time zone, integer) is 'Client API (owner level): a station''s or member''s newest bills and (for a member) minutes per game, read when the dashboard opens it.';

grant execute
  on function "private"."arena_activity"(uuid, uuid, uuid, timestamp with time zone, integer)
  to "authenticated", "postgres", "service_role";

revoke all
  on function "private"."arena_activity"(uuid, uuid, uuid, timestamp with time zone, integer)
  from public;

revoke all on function "private".arena_activity(p_arena uuid, p_resource uuid, p_customer uuid, p_since timestamp with time zone, p_limit integer) from anon;
