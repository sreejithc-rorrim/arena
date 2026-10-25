-- _plays(p_arena, p_since) — play on the floor: session segments as one list
--
-- One row per segment (kind 'single', bill = its session) that started at or after p_since,
-- plus every one still open; rows of voided
-- bills are left out. minutes is the time played up to its end, or up to now while it runs.
-- Shared body of the dashboard's station / game / member reads (arena_station_stats,
-- arena_game_stats, arena_members, arena_member_games, arena_game_fans, arena_recent_bills).
-- Server-only: not executable by anon/authenticated.
create or replace function public._plays (
  p_arena uuid,
  p_since timestamp with time zone
)
  returns table (
    kind          text,
    bill_id       uuid,
    bill_status   text,
    customer_id   uuid,
    resource_id   uuid,
    activity_code text,
    game_id       uuid,
    started_at    timestamp with time zone,
    ended_at      timestamp with time zone,
    minutes       numeric
  )
  language sql
  stable
  set search_path to 'public'
  AS $function$
  select 'single', g.session_id, s.status, s.customer_id, g.resource_id, g.activity_code, g.game_id,
         g.started_at, g.ended_at,
         greatest(0, extract(epoch from (coalesce(g.ended_at, now()) - g.started_at)) / 60)
    from session_segments g join sessions s on s.id = g.session_id
   where g.arena_id = p_arena and s.status <> 'voided'
     and (g.started_at >= p_since or g.ended_at is null);
$function$;

comment on function public._plays(uuid, timestamp with time zone) is 'Internal (dashboard reads): session segments of non-voided bills started since an instant or still open, with minutes played.';

grant execute on function "public"."_plays"(uuid, timestamp with time zone) to "postgres", "service_role";

revoke all on function "public"."_plays"(uuid, timestamp with time zone) from public;

revoke all on function "public"._plays(p_arena uuid, p_since timestamp with time zone) from anon;

revoke all on function "public"._plays(p_arena uuid, p_since timestamp with time zone) from authenticated;
