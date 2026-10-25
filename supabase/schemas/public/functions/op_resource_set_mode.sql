-- op_resource_set_mode — sync op 'resource.set_mode': lock a station to one activity, or clear the
--   lock.
--
-- Permission: settings.
-- Payload: id, mode (activity code; empty/null clears the lock).
-- Checks / errors: forbidden; not_found (hint resource); mode_switch_busy (station has an open
--   session segment).
-- Writes: resources.current_mode. Returns: {}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_resource_set_mode (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare v_id uuid := (p->>'id')::uuid;
begin
  perform _need(p_arena, 'settings');
  perform 1 from resources where id = v_id and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'resource'; end if;
  if exists (select 1 from session_segments where resource_id = v_id and ended_at is null) then
    raise exception 'mode_switch_busy';
  end if;
  update resources set current_mode = nullif(p->>'mode',''), updated_at = statement_timestamp()
    where id = v_id;
  return '{}'::jsonb;
end;
$function$;

comment on function public.op_resource_set_mode(uuid, jsonb) is
  'Sync op resource.set_mode: sets or clears a station''s activity mode lock while it is idle.';

grant execute on function "public"."op_resource_set_mode"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_resource_set_mode"(uuid, jsonb) from public;

revoke all on function "public".op_resource_set_mode(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_resource_set_mode(p_arena uuid, p jsonb) from authenticated;
