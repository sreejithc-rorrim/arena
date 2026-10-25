-- _seg_priced(arena, resource, snapshot, activity, controllers) — can this segment be billed?
--
-- A single session's segment is billed from the session's frozen snapshot; a (type, controller
-- count) with no rate in it would bill ₹0. Refuses no_rate when the snapshot has no rate for the
-- pair in any band, and activity_not_offered when the station lists the types it offers
-- (resource_activities) and this is not one of them (a station with no list offers any).
-- Used by op_session_start, op_session_reconfigure and op_session_record.
-- Server-only: not executable by anon/authenticated.
create or replace function public._seg_priced (
  p_arena    uuid,
  p_resource uuid,
  p_snapshot jsonb,
  p_act      text,
  p_cc       integer
)
  returns void
  language plpgsql
  stable
  set search_path to 'public'
  AS $function$
begin
  if exists (select 1 from resource_activities where resource_id = p_resource)
     and not exists (select 1 from resource_activities ra join activities a on a.id = ra.activity_id
                      where ra.resource_id = p_resource and a.arena_id = p_arena and a.code = p_act) then
    raise exception 'activity_not_offered' using hint = coalesce(p_act, 'null');
  end if;
  if not exists (select 1 from jsonb_array_elements(coalesce(p_snapshot->'rates', '[]'::jsonb)) r
                  where r->>'activity_code' = p_act
                    and (r->>'controller_count')::int is not distinct from p_cc) then
    raise exception 'no_rate'
      using hint = coalesce(p_act, 'null') || ' with ' || coalesce(p_cc::text, 'no') || ' controllers';
  end if;
end;
$function$;

comment on function public._seg_priced(uuid, uuid, jsonb, text, integer) is 'Internal: raise activity_not_offered or no_rate unless a single-session segment can be billed from the snapshot.';

grant execute on function "public"."_seg_priced"(uuid, uuid, jsonb, text, integer) to "postgres", "service_role";

revoke all on function "public"."_seg_priced"(uuid, uuid, jsonb, text, integer) from public;

revoke all on function "public"."_seg_priced"(uuid, uuid, jsonb, text, integer) from anon;

revoke all on function "public"."_seg_priced"(uuid, uuid, jsonb, text, integer) from authenticated;
