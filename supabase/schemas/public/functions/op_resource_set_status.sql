-- op_resource_set_status — sync op 'resource.set_status': put a station in service, take it out
--   (maintenance, temporarily_unavailable) or remove it (disabled).
--
-- Permission: settings.
-- Payload: id, status ('available' | 'maintenance' | 'temporarily_unavailable' | 'disabled').
-- A station someone is on (an open session segment) can only be made available:
-- taking it away would strand a live session (resource_busy), the rule both apps apply before
-- sending. The station row is locked first (_lock_resources, as a start does), so a start racing
-- this either commits first and this is refused, or waits and then finds the station out of
-- service (resource_unavailable).
-- Checks / errors: forbidden; not_found (hint resource); resource_busy (hint: open session);
--   invalid (status outside resources_status_check).
-- Writes: resources.status. Returns: {}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_resource_set_status (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_id     uuid := (p->>'id')::uuid;
  v_status text := p->>'status';
begin
  perform _need(p_arena, 'settings');
  perform _lock_resources(p_arena, array[v_id]);
  if not exists (select 1 from resources where id = v_id and arena_id = p_arena) then
    raise exception 'not_found' using hint = 'resource';
  end if;
  if v_status is distinct from 'available' then
    if exists (select 1 from session_segments
                where arena_id = p_arena and resource_id = v_id and ended_at is null) then
      raise exception 'resource_busy' using hint = 'open session';
    end if;
  end if;
  update resources set status = v_status, updated_at = statement_timestamp()
    where id = v_id and arena_id = p_arena;
  return '{}'::jsonb;
end;
$function$;

comment on function public.op_resource_set_status(uuid, jsonb) is
  'Sync op resource.set_status: puts a station in or out of service or removes it; refuses anything but available while a session is on it (resource_busy).';

grant execute
  on function "public"."op_resource_set_status"(uuid, jsonb)
  to "postgres", "service_role";

revoke all on function "public"."op_resource_set_status"(uuid, jsonb) from public;

revoke all on function "public".op_resource_set_status(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_resource_set_status(p_arena uuid, p jsonb) from authenticated;
