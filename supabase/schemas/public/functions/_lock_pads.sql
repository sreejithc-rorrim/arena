-- _lock_pads(p_arena, p_ids) — row-lock the given controllers in id order.
--
-- SELECT ... ORDER BY id FOR UPDATE on the arena's controllers. Callers lock stations first
-- (_lock_resources), then pads; the fixed order prevents deadlocks between concurrent ops.
-- Used by op_session_start, op_session_reconfigure and op_controller_move.
-- Server-only: not executable by anon/authenticated.
create or replace function public._lock_pads (
  p_arena uuid,
  p_ids   uuid[]
)
  returns void
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
begin
  perform 1 from controllers
    where arena_id = p_arena and id = any(p_ids)
    order by id for update;
end;
$function$;

comment on function public._lock_pads(uuid, uuid[]) is 'Locks the given controller rows in id order (always after the stations).';

grant execute on function "public"."_lock_pads"(uuid, uuid[]) to "postgres", "service_role";

revoke all on function "public"."_lock_pads"(uuid, uuid[]) from public;

revoke all on function "public"._lock_pads(p_arena uuid, p_ids uuid[]) from anon;

revoke all on function "public"._lock_pads(p_arena uuid, p_ids uuid[]) from authenticated;
