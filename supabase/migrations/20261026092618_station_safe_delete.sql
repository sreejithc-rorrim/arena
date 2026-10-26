set local check_function_bodies = off;

alter table "public"."resources"
  drop constraint "resources_arena_id_name_key";

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
  v_old    text;
begin
  perform _need(p_arena, 'settings');
  perform _lock_resources(p_arena, array[v_id]);
  select status into v_old from resources where id = v_id and arena_id = p_arena;
  if not found then
    raise exception 'not_found' using hint = 'resource';
  end if;
  if v_old = 'disabled' then
    if v_status = 'disabled' then return '{}'::jsonb; end if;
    raise exception 'not_found' using hint = 'resource removed';
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

create or replace function public.op_resource_upsert (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare v_id uuid := (p->>'id')::uuid; v_code text; v_old text;
begin
  perform _need(p_arena, 'settings');
  -- An id that belongs to another arena is "not found" here, never overwritten.
  if exists (select 1 from resources where id = v_id and arena_id <> p_arena) then
    raise exception 'not_found' using hint = 'resource';
  end if;
  perform _lock_resources(p_arena, array[v_id]);
  select status into v_old from resources where id = v_id and arena_id = p_arena;
  -- Removal is final (resource.set_status disabled): a removed station is never edited again.
  if v_old = 'disabled' then
    raise exception 'not_found' using hint = 'resource removed';
  end if;
  if found and p ? 'status' and (p->>'status') is distinct from v_old
     and (p->>'status') is distinct from 'available'
     and exists (select 1 from session_segments
                  where arena_id = p_arena and resource_id = v_id and ended_at is null) then
    raise exception 'resource_busy' using hint = 'in use';
  end if;
  insert into resources(id, arena_id, name, kind, status, sort_order)
    values (v_id, p_arena, p->>'name', p->>'kind', coalesce(p->>'status', 'available'),
      coalesce((p->>'sort_order')::int, 0))
  on conflict (id) do update set name = excluded.name, kind = excluded.kind,
      status = case when p ? 'status' then excluded.status else resources.status end,
      sort_order = excluded.sort_order, updated_at = statement_timestamp()
    where resources.arena_id = p_arena;
  -- The station supports exactly the listed activities.
  delete from resource_activities ra using activities a
   where ra.resource_id = v_id and a.id = ra.activity_id
     and not (a.code = any(array(select jsonb_array_elements_text(coalesce(p->'activity_codes','[]'::jsonb)))));
  for v_code in select jsonb_array_elements_text(coalesce(p->'activity_codes', '[]'::jsonb)) loop
    insert into resource_activities(arena_id, resource_id, activity_id)
      values (p_arena, v_id, _activity_id(p_arena, v_code))
    on conflict (resource_id, activity_id) do nothing;
  end loop;
  return '{}'::jsonb;
end;
$function$;

create unique index ux_resources_name on public.resources using btree (arena_id, name)
  where (status <> 'disabled'::text);

comment on column "public"."resources"."name" is 'Display name (e.g. HEX, Pool Table 1), unique among the arena''s stations still on the floor (ux_resources_name): a removed one frees it, while its bills keep it.';

comment on column "public"."resources"."status" is 'One of available, maintenance, temporarily_unavailable, disabled. Set by resource.upsert / resource.set_status. disabled = removed (a safe delete): final, the row stays for history and its name is free again.';

comment on function "public"."op_resource_set_status"(uuid, jsonb) is 'Sync op resource.set_status: puts a station in or out of service or removes it for good (disabled, which frees its name); refuses anything but available while a session is on it (resource_busy), and any change to a removed station (not_found).';
