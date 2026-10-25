-- _lock_resources(p_arena, p_ids) — row-lock the given stations in id order.
--
-- SELECT ... ORDER BY id FOR UPDATE on the arena's resources. Always taken before _lock_pads;
-- the fixed order prevents deadlocks between concurrent ops.
-- Used by op_session_start, op_session_reconfigure, op_controller_move, op_resource_upsert and
-- op_resource_set_status.
-- Server-only: not executable by anon/authenticated.
create or replace function public._lock_resources (
  p_arena uuid,
  p_ids   uuid[]
)
  returns void
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
begin
  perform 1 from resources
    where arena_id = p_arena and id = any(p_ids)
    order by id for update;
end;
$function$;

comment on function public._lock_resources(uuid, uuid[]) is 'Locks the given station (resource) rows in id order (always before the pads).';

grant execute on function "public"."_lock_resources"(uuid, uuid[]) to "postgres", "service_role";

revoke all on function "public"."_lock_resources"(uuid, uuid[]) from public;

revoke all on function "public"._lock_resources(p_arena uuid, p_ids uuid[]) from anon;

revoke all on function "public"._lock_resources(p_arena uuid, p_ids uuid[]) from authenticated;
