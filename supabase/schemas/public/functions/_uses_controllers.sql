-- _uses_controllers(p_arena, p_activity) — does the activity use controllers?
--
-- activities.uses_controllers, false when the arena has no such activity.
-- Used by _single_supply.
-- Server-only: not executable by anon/authenticated.
create or replace function public._uses_controllers (
  p_arena    uuid,
  p_activity text
)
  returns boolean
  language sql
  stable
  security definer
  set search_path to 'public'
  AS $function$
  select coalesce((select uses_controllers from activities
                    where arena_id = p_arena and code = p_activity), false);
$function$;

comment on function public._uses_controllers(uuid, text) is 'True when the activity uses controllers; false when unknown.';

grant execute on function "public"."_uses_controllers"(uuid, text) to "postgres", "service_role";

revoke all on function "public"."_uses_controllers"(uuid, text) from public;

revoke all on function "public"._uses_controllers(p_arena uuid, p_activity text) from anon;

revoke all on function "public"._uses_controllers(p_arena uuid, p_activity text) from authenticated;
