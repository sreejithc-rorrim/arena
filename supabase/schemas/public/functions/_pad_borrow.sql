-- _pad_borrow(p_arena, p_moves, p_resource, p_session_ref, p_at) — move pads to a station for a session.
--
-- Per move: the accessory must be a pad (_is_pad, else not_a_controller); a pad already at
-- p_resource is skipped and counted; otherwise it must exist, be usable,
-- unallocated, and its station free of untracked play (controller_missing / controller_unusable /
-- controller_taken). Moves it and logs controller_moves as 'returnHome' when p_resource is its home,
-- else 'loan' (loan_return_to = home, loan_session_ref = p_session_ref). Returns the skip count.
-- Pads are locked by the caller. Used by op_session_start and op_session_reconfigure.
-- Server-only: not executable by anon/authenticated.
create or replace function public._pad_borrow (
  p_arena       uuid,
  p_moves       jsonb,
  p_resource    uuid,
  p_session_ref text,
  p_at          timestamp with time zone
)
  returns integer
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now  timestamptz := statement_timestamp();
  v_m    jsonb;
  v_cid  uuid;
  v_status text; v_loc uuid; v_home uuid; v_kind uuid; v_return boolean;
  v_skipped int := 0;
begin
  for v_m in select value from jsonb_array_elements(coalesce(p_moves, '[]'::jsonb)) loop
    v_cid := (v_m->>'controller_id')::uuid;
    select status, current_resource_id, home_resource_id, kind_id into v_status, v_loc, v_home, v_kind
      from controllers where id = v_cid and arena_id = p_arena;
    if not found then raise exception 'controller_missing'; end if;
    if not _is_pad(v_kind) then raise exception 'not_a_controller'; end if;
    if v_loc = p_resource then v_skipped := v_skipped + 1; continue; end if;
    if v_status <> 'usable' then raise exception 'controller_unusable' using hint = v_status; end if;
    if exists (select 1 from controller_allocations where controller_id = v_cid and ended_at is null) then
      raise exception 'controller_taken';
    end if;
    if _untracked_busy(p_arena, v_loc) then
      raise exception 'controller_taken' using hint = 'station_in_use';
    end if;
    v_return := v_home = p_resource;
    update controllers
       set current_resource_id = p_resource,
           loan_return_to   = case when v_return then null else v_home::text end,
           loan_session_ref = case when v_return then null else p_session_ref end,
           updated_at = v_now
     where id = v_cid;
    insert into controller_moves(id, arena_id, controller_id, from_resource_id, to_resource_id,
        kind, session_ref, moved_at, created_by, created_at)
      values (coalesce(nullif(v_m->>'id','')::uuid, gen_random_uuid()), p_arena, v_cid, v_loc,
        p_resource, case when v_return then 'returnHome' else 'loan' end,
        case when v_return then null else p_session_ref end, p_at, auth.uid(), v_now);
  end loop;
  return v_skipped;
end;
$function$;

comment on function public._pad_borrow(uuid, jsonb, uuid, text, timestamp with time zone) is 'Moves pads to a station for a session, recording loans and returns home; returns how many were already there.';

grant execute
  on function "public"."_pad_borrow"(uuid, jsonb, uuid, text, timestamp with time zone)
  to "postgres", "service_role";

revoke all
  on function "public"."_pad_borrow"(uuid, jsonb, uuid, text, timestamp with time zone)
  from public;

revoke all on function "public"._pad_borrow(p_arena uuid, p_moves jsonb, p_resource uuid, p_session_ref text, p_at timestamp with time zone) from anon;

revoke all on function "public"._pad_borrow(p_arena uuid, p_moves jsonb, p_resource uuid, p_session_ref text, p_at timestamp with time zone) from authenticated;
