-- _station_usable(p_arena, p_resource) — require the station to exist and be 'available'.
--
-- Raises 'resource_missing' or 'resource_unavailable' (hint: its status).
-- Used by op_session_start and op_session_reconfigure.
-- Server-only: not executable by anon/authenticated.
create or replace function public._station_usable (
  p_arena    uuid,
  p_resource uuid
)
  returns void
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare v_status text;
begin
  select status into v_status from resources where id = p_resource and arena_id = p_arena;
  if not found then raise exception 'resource_missing'; end if;
  if v_status <> 'available' then
    raise exception 'resource_unavailable' using hint = v_status;
  end if;
end;
$function$;

comment on function public._station_usable(uuid, uuid) is 'Raises resource_missing or resource_unavailable unless the station exists and is available.';

grant execute on function "public"."_station_usable"(uuid, uuid) to "postgres", "service_role";

revoke all on function "public"."_station_usable"(uuid, uuid) from public;

revoke all on function "public"._station_usable(p_arena uuid, p_resource uuid) from anon;

revoke all on function "public"._station_usable(p_arena uuid, p_resource uuid) from authenticated;
