-- _pad_allocate(p_arena, p_allocs, p_session, p_segment, ...) — record pads as in use by a session segment.
--
-- p_allocs is [{controller_id, id?}]. Raises controller_duplicate, controller_missing,
-- not_a_controller (an accessory whose kind is not a pad, see _is_pad),
-- controller_unusable (hint: status), controller_elsewhere (not at p_resource) or controller_taken
-- (already allocated, or untracked play at the station other than p_segment).
-- All checks run before any controller_allocations row is inserted. Pads are locked by the caller.
-- Used by op_session_start and op_session_reconfigure.
-- Server-only: not executable by anon/authenticated.
create or replace function public._pad_allocate (
  p_arena      uuid,
  p_allocs     jsonb,
  p_session    uuid,
  p_segment    uuid,
  p_resource   uuid,
  p_activity   text,
  p_game       uuid,
  p_started    timestamp with time zone
)
  returns void
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now timestamptz := statement_timestamp();
  v_a jsonb; v_cid uuid; v_status text; v_loc uuid; v_kind uuid;
  v_ids uuid[] := _pad_ids(p_allocs);
begin
  if coalesce(array_length(v_ids, 1), 0) = 0 then return; end if;
  if array_length(v_ids, 1) <> (select count(distinct x) from unnest(v_ids) x) then
    raise exception 'controller_duplicate';
  end if;
  for v_a in select value from jsonb_array_elements(p_allocs) loop
    v_cid := (v_a->>'controller_id')::uuid;
    select status, current_resource_id, kind_id into v_status, v_loc, v_kind
      from controllers where id = v_cid and arena_id = p_arena;
    if not found then raise exception 'controller_missing'; end if;
    if not _is_pad(v_kind) then raise exception 'not_a_controller'; end if;
    if v_status <> 'usable' then raise exception 'controller_unusable' using hint = v_status; end if;
    if v_loc <> p_resource then raise exception 'controller_elsewhere'; end if;
    if exists (select 1 from controller_allocations where controller_id = v_cid and ended_at is null) then
      raise exception 'controller_taken';
    end if;
    if _untracked_busy(p_arena, p_resource, array_remove(array[p_segment], null)) then
      raise exception 'controller_taken' using hint = 'untracked_player';
    end if;
  end loop;
  for v_a in select value from jsonb_array_elements(p_allocs) loop
    insert into controller_allocations(id, arena_id, controller_id, scope, session_id,
        segment_id, resource_id, activity_code, game_id, started_at, created_by, created_at)
      values (coalesce(nullif(v_a->>'id','')::uuid, gen_random_uuid()), p_arena,
        (v_a->>'controller_id')::uuid, 'single', p_session, p_segment, p_resource, p_activity,
        p_game, p_started, auth.uid(), v_now);
  end loop;
end;
$function$;

comment on function public._pad_allocate(uuid, jsonb, uuid, uuid, uuid, text, uuid, timestamp with time zone) is 'Validates and inserts controller allocations for a session segment.';

grant execute
  on function
    "public"."_pad_allocate"(uuid, jsonb, uuid, uuid, uuid, text, uuid, timestamp with time zone)
  to "postgres", "service_role";

revoke all
  on function
    "public"."_pad_allocate"(uuid, jsonb, uuid, uuid, uuid, text, uuid, timestamp with time zone)
  from public;

revoke all on function "public"._pad_allocate(p_arena uuid, p_allocs jsonb, p_session uuid, p_segment uuid, p_resource uuid, p_activity text, p_game uuid, p_started timestamp with time zone) from anon;

revoke all on function "public"._pad_allocate(p_arena uuid, p_allocs jsonb, p_session uuid, p_segment uuid, p_resource uuid, p_activity text, p_game uuid, p_started timestamp with time zone) from authenticated;
