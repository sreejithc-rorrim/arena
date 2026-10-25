-- _pad_origins(p_arena, p_ids) — distinct current stations of the given pads.
--
-- Tells callers which stations to lock before borrowing pads, and is re-read after locking to
-- detect a pad that moved meanwhile ('retry'). Used by op_session_start and
-- op_session_reconfigure.
-- Server-only: not executable by anon/authenticated.
create or replace function public._pad_origins (
  p_arena uuid,
  p_ids   uuid[]
)
  returns uuid[]
  language sql
  stable
  security definer
  set search_path to 'public'
  AS $function$
  select coalesce(array_agg(distinct current_resource_id), '{}')
    from controllers where arena_id = p_arena and id = any(p_ids);
$function$;

comment on function public._pad_origins(uuid, uuid[]) is 'Distinct current stations of the given controllers.';

grant execute on function "public"."_pad_origins"(uuid, uuid[]) to "postgres", "service_role";

revoke all on function "public"."_pad_origins"(uuid, uuid[]) from public;

revoke all on function "public"._pad_origins(p_arena uuid, p_ids uuid[]) from anon;

revoke all on function "public"._pad_origins(p_arena uuid, p_ids uuid[]) from authenticated;
