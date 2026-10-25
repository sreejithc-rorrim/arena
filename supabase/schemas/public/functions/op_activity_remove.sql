-- op_activity_remove — sync op 'activity.remove': delete a station type if never used, else retire it.
--
-- Permission: settings.
-- Payload: id.
-- A type no session, charge, pad allocation or booking ever
-- referred to is deleted with its prices and station links (devices get the
-- tombstones). A type with any such history is retired instead (active =
-- false), so past bills keep it. Either way any station mode lock on it is
-- cleared. Idempotent: an id that is already gone returns {removed: 'deleted'}.
-- Checks / errors: forbidden; not_found (hint activity: the id belongs to
-- another arena); activity_has_stations (hint: how many stations that are not
-- disabled still offer it — move or remove them first).
-- Writes: activities (delete or active), resources.current_mode. A price-list
-- change: _sync_apply retires the previous catalog into pricing_catalog_history.
-- Returns: {removed: 'deleted' | 'retired'}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_activity_remove (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_id       uuid := (p->>'id')::uuid;
  v_code     text;
  v_stations int;
begin
  perform _need(p_arena, 'settings');
  if exists (select 1 from activities where id = v_id and arena_id <> p_arena) then
    raise exception 'not_found' using hint = 'activity';
  end if;
  select code into v_code from activities where id = v_id and arena_id = p_arena for update;
  if not found then return jsonb_build_object('removed', 'deleted'); end if;

  select count(*) into v_stations
    from resource_activities ra join resources r on r.id = ra.resource_id
   where ra.activity_id = v_id and r.status <> 'disabled';
  if v_stations > 0 then
    raise exception 'activity_has_stations' using hint = v_stations::text;
  end if;

  update resources set current_mode = null, updated_at = statement_timestamp()
   where arena_id = p_arena and current_mode = v_code;

  if exists (select 1 from session_segments where arena_id = p_arena and activity_code = v_code)
     or exists (select 1 from session_charges where arena_id = p_arena and activity_code = v_code)
     or exists (select 1 from controller_allocations where arena_id = p_arena and activity_code = v_code)
     or exists (select 1 from bookings where arena_id = p_arena and activity_id = v_id) then
    update activities set active = false, updated_at = statement_timestamp() where id = v_id;
    return jsonb_build_object('removed', 'retired');
  end if;

  delete from activities where id = v_id;
  return jsonb_build_object('removed', 'deleted');
end;
$function$;

comment on function public.op_activity_remove(uuid, jsonb) is
  'Sync op activity.remove: deletes a never-used station type with its prices, or retires a used one so past bills keep it.';

grant execute on function "public"."op_activity_remove"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_activity_remove"(uuid, jsonb) from public;

revoke all on function "public".op_activity_remove(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_activity_remove(p_arena uuid, p jsonb) from authenticated;
