-- sync_fetch_entity(arena, refs) — the server's current rows for whole entities
--
-- Lives in `private`, which the Data API does not expose: SECURITY DEFINER
-- code never sits in an API schema. Clients reach it only through the
-- SECURITY INVOKER wrapper public.sync_fetch_entity.
--
-- Used by a device after the server refuses one of its ops: it replaces its
-- copy of the affected entity with these rows. p_refs is a jsonb array of
-- {type, id}, type in session | controller | customer | booking.
-- Returns [{ref, rows: [{t: table name, r: row}]}], one entry per ref; an
-- unknown type or missing id gives rows = []. SECURITY DEFINER; any active
-- member of p_arena may call it (no permission check), else 'forbidden' (42501).
-- Client API: callable by signed-in users (authenticated).
create or replace function private.sync_fetch_entity (
  p_arena uuid,
  p_refs  jsonb
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_ref    jsonb;
  v_id     uuid;
  v_rows   jsonb;
  v_out    jsonb := '[]'::jsonb;
  v_hidden text[];
begin
  -- `not in` is NULL (not true) for a null arena, so test membership explicitly.
  if p_arena is null or not exists (select 1 from private.app_arena_ids() a where a = p_arena) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  for v_ref in select value from jsonb_array_elements(coalesce(p_refs, '[]'::jsonb)) loop
    v_id := nullif(v_ref->>'id', '')::uuid;
    -- controller_moves point at their session via session_ref
    -- ('s:<session id>'), not a uuid column.
    v_rows := case v_ref->>'type'
      when 'session' then (
        select coalesce(jsonb_agg(x), '[]'::jsonb) from (
          select jsonb_build_object('t','sessions','r',to_jsonb(s)) x from sessions s where s.arena_id = p_arena and s.id = v_id
          union all select jsonb_build_object('t','session_segments','r',to_jsonb(s)) from session_segments s where s.arena_id = p_arena and s.session_id = v_id
          union all select jsonb_build_object('t','session_extensions','r',to_jsonb(s)) from session_extensions s where s.arena_id = p_arena and s.session_id = v_id
          union all select jsonb_build_object('t','session_charges','r',to_jsonb(s)) from session_charges s where s.arena_id = p_arena and s.session_id = v_id
          union all select jsonb_build_object('t','payments','r',to_jsonb(s)) from payments s where s.arena_id = p_arena and s.session_id = v_id
          union all select jsonb_build_object('t','controller_allocations','r',to_jsonb(s)) from controller_allocations s where s.arena_id = p_arena and s.session_id = v_id
          union all select jsonb_build_object('t','controller_moves','r',to_jsonb(s)) from controller_moves s where s.arena_id = p_arena and s.session_ref = 's:' || v_id::text
        ) q)
      when 'controller' then (
        select coalesce(jsonb_agg(x), '[]'::jsonb) from (
          select jsonb_build_object('t','controllers','r',to_jsonb(s)) x from controllers s where s.arena_id = p_arena and s.id = v_id
          union all select jsonb_build_object('t','controller_moves','r',to_jsonb(s)) from controller_moves s where s.arena_id = p_arena and s.controller_id = v_id
          union all select jsonb_build_object('t','controller_allocations','r',to_jsonb(s)) from controller_allocations s where s.arena_id = p_arena and s.controller_id = v_id and s.ended_at is null
        ) q)
      when 'customer' then (
        select coalesce(jsonb_agg(jsonb_build_object('t','customers','r',to_jsonb(s))), '[]'::jsonb)
          from customers s where s.arena_id = p_arena and s.id = v_id)
      when 'booking' then (
        select coalesce(jsonb_agg(jsonb_build_object('t','bookings','r',to_jsonb(s))), '[]'::jsonb)
          from sync_v_bookings s where s.arena_id = p_arena and s.id = v_id)
      else '[]'::jsonb
    end;
    -- Customers, money and coupons only for those who may read them (as sync_pull).
    v_hidden := coalesce(v_hidden, _sync_hidden(p_arena));
    select coalesce(jsonb_agg(e), '[]'::jsonb) into v_rows
      from jsonb_array_elements(v_rows) e where e->>'t' <> all(v_hidden);
    v_out := v_out || jsonb_build_array(jsonb_build_object('ref', v_ref, 'rows', v_rows));
  end loop;
  return v_out;
end;
$function$;

comment on function private.sync_fetch_entity(uuid, jsonb) is 'Client API (sync): for each {type, id} ref, return the server''s current rows for that whole entity (session, controller, customer or booking) so a device can replace its copy after a refused op.';

grant execute
  on function "private"."sync_fetch_entity"(uuid, jsonb)
  to "authenticated", "postgres", "service_role";

revoke all on function "private"."sync_fetch_entity"(uuid, jsonb) from public;

revoke all on function "private".sync_fetch_entity(p_arena uuid, p_refs jsonb) from anon;
