-- _station_free_for_single(p_resource) — refuse a station that already has open play.
--
-- Raises 'resource_busy' if any open session segment is on the station.
-- Used by op_session_start and op_session_reconfigure (when moving to another station).
-- Server-only: not executable by anon/authenticated.
create or replace function public._station_free_for_single (
  p_resource uuid
)
  returns void
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
begin
  if exists (select 1 from session_segments where resource_id = p_resource and ended_at is null) then
    raise exception 'resource_busy';
  end if;
end;
$function$;

comment on function public._station_free_for_single(uuid) is 'Raises resource_busy when the station has an open session segment.';

grant execute on function "public"."_station_free_for_single"(uuid) to "postgres", "service_role";

revoke all on function "public"."_station_free_for_single"(uuid) from public;

revoke all on function "public"._station_free_for_single(p_resource uuid) from anon;

revoke all on function "public"._station_free_for_single(p_resource uuid) from authenticated;
