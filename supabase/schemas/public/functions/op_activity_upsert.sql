-- op_activity_upsert — sync op 'activity.upsert': create or edit a station type (activity).
--
-- Permission: settings.
-- Payload: id, code?, name, uses_controllers, uses_games, duration_model
-- ('hourly' | 'unit' | 'flat_hourly'), sort_order?, active?, overtime_grace_minutes? (0–240;
-- absent keeps the saved value, 0 for a new type, so an older client cannot reset it). A happy_hour_eligible key
-- from older clients is ignored (happy hours are pricing rules).
-- The code is the type's stable business key (segments, rates, bookings and
-- pricing snapshots refer to it): 1–12 of A–Z, 0–9, _ after upper-casing, and it
-- cannot change once the type exists. Retiring a type is active = false.
-- code may be omitted: an existing type keeps its own, and a new one gets one
-- derived from the name (letters and digits upper-cased, other runs → _, cut to
-- 12, with _2, _3 … appended when taken), so the owner never has to type one.
-- Checks / errors: forbidden; invalid_code; invalid_name (1–40 characters);
-- not_found (hint activity: the id belongs to another arena); code_locked
-- (changing an existing type's code); activity_busy (switching
-- uses_controllers while a session of this type is running);
-- duplicate (code already used by another type); invalid (bad duration_model).
-- Writes: activities. A price-list change: _sync_apply retires the previous
-- catalog into pricing_catalog_history. Returns: {}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_activity_upsert (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_id   uuid := (p->>'id')::uuid;
  v_code text := upper(btrim(coalesce(p->>'code', '')));
  v_name text := btrim(coalesce(p->>'name', ''));
  v_pads boolean := coalesce((p->>'uses_controllers')::boolean, false);
  v_old  activities%rowtype;
  v_base text;
  v_n    int := 1;
begin
  perform _need(p_arena, 'settings');
  if v_code = '' then
    select code into v_code from activities where id = v_id and arena_id = p_arena;
    if v_code is null then
      v_base := left(btrim(regexp_replace(upper(v_name), '[^A-Z0-9]+', '_', 'g'), '_'), 12);
      if v_base = '' then v_base := 'TYPE'; end if;
      v_code := v_base;
      while exists (select 1 from activities where arena_id = p_arena and code = v_code) loop
        v_n := v_n + 1;
        v_code := left(v_base, 12 - char_length(v_n::text) - 1) || '_' || v_n;
      end loop;
    end if;
  end if;
  if v_code !~ '^[A-Z0-9_]{1,12}$' then
    raise exception 'invalid_code' using hint = 'A–Z, 0–9 or _, up to 12';
  end if;
  if char_length(v_name) not between 1 and 40 then
    raise exception 'invalid_name' using hint = '1–40 characters';
  end if;
  if exists (select 1 from activities where id = v_id and arena_id <> p_arena) then
    raise exception 'not_found' using hint = 'activity';
  end if;

  select * into v_old from activities where id = v_id and arena_id = p_arena for update;
  if found then
    if v_old.code <> v_code then
      raise exception 'code_locked' using hint = v_old.code;
    end if;
    if v_old.uses_controllers <> v_pads
       and exists (select 1 from session_segments
                    where arena_id = p_arena and activity_code = v_code and ended_at is null) then
      raise exception 'activity_busy' using hint = v_code;
    end if;
  end if;

  insert into activities(id, arena_id, code, name, uses_controllers, uses_games, duration_model,
      sort_order, active, overtime_grace_minutes)
    values (v_id, p_arena, v_code, v_name, v_pads,
      coalesce((p->>'uses_games')::boolean, false),
      coalesce(p->>'duration_model', 'hourly'),
      coalesce((p->>'sort_order')::int, 0),
      coalesce((p->>'active')::boolean, true),
      coalesce((p->>'overtime_grace_minutes')::int, v_old.overtime_grace_minutes, 0))
  on conflict (id) do update set
    name = excluded.name, uses_controllers = excluded.uses_controllers,
    uses_games = excluded.uses_games, duration_model = excluded.duration_model,
    sort_order = excluded.sort_order, overtime_grace_minutes = excluded.overtime_grace_minutes,
    active = excluded.active, updated_at = statement_timestamp()
  where activities.arena_id = p_arena;
  return '{}'::jsonb;
end;
$function$;

comment on function public.op_activity_upsert(uuid, jsonb) is
  'Sync op activity.upsert: creates or edits a station type (activity); its code is fixed once created.';

grant execute on function "public"."op_activity_upsert"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_activity_upsert"(uuid, jsonb) from public;

revoke all on function "public".op_activity_upsert(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_activity_upsert(p_arena uuid, p jsonb) from authenticated;
