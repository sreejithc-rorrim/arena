-- arena_station_stats(arena, today, since, to) — per-station figures for the Stations screen
--
-- Lives in `private`; clients reach it only through the SECURITY INVOKER wrapper
-- public.arena_station_stats.
--
-- Returns {station id: {billed_today, sessions_today, minutes_30, billed_30,
-- accessories}} for every station of the arena: billed_* sum the charge lines of
-- bills that were not voided by segment start in [p_today, p_to) / [p_since, p_to);
-- sessions_today counts bills with play on the station started since p_today;
-- minutes_30 the play there since p_since (open play up to now); accessories the
-- accessories homed there that are not retired. SECURITY DEFINER. Caller must be
-- owner level in p_arena (app_is_owner), else 'forbidden'.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.arena_station_stats (
  p_arena uuid,
  p_today timestamp with time zone,
  p_since timestamp with time zone,
  p_to    timestamp with time zone
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
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can read station figures';
  end if;
  if p_since is null or p_today is null or p_to is null or p_to <= p_since
     or p_to - p_since > interval '400 days' then
    raise exception 'invalid_range' using hint = 'up to 400 days';
  end if;

  with ch as (
    select ch.resource_id, ch.segment_start, ch.amount_paise from session_charges ch
      join sessions s on s.id = ch.session_id
     where ch.arena_id = p_arena and s.status <> 'voided'
       and ch.segment_start >= p_since and ch.segment_start < p_to
  ), pl as (
    select * from _plays(p_arena, p_since)
  )
  select coalesce(jsonb_object_agg(r.id, jsonb_build_object(
      'billed_today', coalesce((select sum(amount_paise) from ch
                                 where ch.resource_id = r.id and ch.segment_start >= p_today), 0),
      'sessions_today', (select count(distinct (pl.kind, pl.bill_id)) from pl
                          where pl.resource_id = r.id and pl.started_at >= p_today),
      'minutes_30', coalesce((select round(sum(pl.minutes)) from pl
                               where pl.resource_id = r.id and pl.started_at >= p_since), 0),
      'billed_30', coalesce((select sum(amount_paise) from ch where ch.resource_id = r.id), 0),
      'accessories', (select count(*) from controllers c
                       where c.home_resource_id = r.id and c.status <> 'retired'))), '{}'::jsonb)
    into v_out
    from resources r where r.arena_id = p_arena;
  return v_out;
end;
$function$;

comment on function private.arena_station_stats(uuid, timestamp with time zone, timestamp with time zone, timestamp with time zone) is 'Client API (owner level): per-station billed today / 30 days, sessions today, minutes played and accessory count, aggregated on the server.';

grant execute
  on function
    "private"."arena_station_stats"(uuid, timestamp with time zone, timestamp with time zone,
    timestamp with time zone)
  to "authenticated", "postgres", "service_role";

revoke all
  on function
    "private"."arena_station_stats"(uuid, timestamp with time zone, timestamp with time zone,
    timestamp with time zone)
  from public;

revoke all on function "private".arena_station_stats(p_arena uuid, p_today timestamp with time zone, p_since timestamp with time zone, p_to timestamp with time zone) from anon;
