-- _client_time(arena, at, field) — refuse a device-stamped billing instant the server cannot trust
--
-- Session times come from the floor device (it works offline). The server bounds them
-- against its own clock: later than now + 2 minutes (clock drift) is time_in_future; older than
-- the arena's offline window is time_too_old (settings key offline_rules, max_offline_hours;
-- default 24 hours: an op that waited longer offline goes to Sync › Needs attention).
-- Lateness inside the window is not refused: the receipt time is stored (sessions.created_at,
-- ended_recorded_at) and the dashboard flags a late record. A null passes (the caller's own
-- checks handle a missing time).
-- Used by op_session_start / _reconfigure / _end.
-- Server-only: not executable by anon/authenticated.
create or replace function public._client_time (
  p_arena uuid,
  p_at    timestamptz,
  p_field text
)
  returns void
  language plpgsql
  stable
  set search_path to 'public'
  AS $function$
declare v_hours int;
begin
  if p_at > statement_timestamp() + interval '2 minutes' then
    raise exception 'time_in_future' using hint = p_field || ' is after the server''s time';
  end if;
  select coalesce((json->>'max_offline_hours')::int, 24) into v_hours
    from settings where arena_id = p_arena and key = 'offline_rules';
  v_hours := coalesce(v_hours, 24);
  if p_at < statement_timestamp() - make_interval(hours => v_hours) then
    raise exception 'time_too_old' using hint = p_field || ' is more than ' || v_hours || ' hours old';
  end if;
end;
$function$;

comment on function public._client_time(uuid, timestamptz, text) is 'Internal: raise time_in_future (> now + 2 min) or time_too_old (older than the arena''s offline window, default 24 h) for a device-stamped billing instant.';

grant execute on function "public"."_client_time"(uuid, timestamptz, text) to "postgres", "service_role";

revoke all on function "public"."_client_time"(uuid, timestamptz, text) from public;

revoke all on function "public"."_client_time"(uuid, timestamptz, text) from anon;

revoke all on function "public"."_client_time"(uuid, timestamptz, text) from authenticated;
