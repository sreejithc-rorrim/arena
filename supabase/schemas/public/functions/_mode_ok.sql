-- _mode_ok(p_arena, p_resource, p_activity) — refuse an activity the station is not in mode for.
--
-- Raises 'mode_locked' (hint: the current mode) when resources.current_mode is set and differs
-- from p_activity; a null mode or missing station passes. Used by _single_supply.
-- Server-only: not executable by anon/authenticated.
create or replace function public._mode_ok (
  p_arena    uuid,
  p_resource uuid,
  p_activity text
)
  returns void
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare v_mode text;
begin
  select current_mode into v_mode from resources where id = p_resource and arena_id = p_arena;
  if v_mode is not null and v_mode <> p_activity then
    raise exception 'mode_locked' using hint = v_mode;
  end if;
end;
$function$;

comment on function public._mode_ok(uuid, uuid, text) is 'Raises mode_locked when the station is locked to a different activity mode.';

grant execute on function "public"."_mode_ok"(uuid, uuid, text) to "postgres", "service_role";

revoke all on function "public"."_mode_ok"(uuid, uuid, text) from public;

revoke all on function "public"._mode_ok(p_arena uuid, p_resource uuid, p_activity text) from anon;

revoke all on function "public"._mode_ok(p_arena uuid, p_resource uuid, p_activity text) from authenticated;
