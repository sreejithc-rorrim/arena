-- _create_arena_with_owner(user, arena_name, owner_name) — insert an empty arena, make user its owner
--
-- Shared body of bootstrap_owner (operator) and create_my_arena (self-serve
-- sign-up). Inserts a new arenas row (name defaults to 'Arena') and adds a
-- role='owner' staff profile for p_user holding every permission in _known_perms() (name
-- defaults to 'Owner'). The arena starts with no catalog: the owner adds
-- station types and prices, stations, controllers and games on the dashboard.
-- Callers check the login (exists, confirmed) and any limits first. Not
-- idempotent: every call creates another arena. Returns the new arena id.
-- SECURITY DEFINER. Server-only: not executable by anon/authenticated.
create or replace function public._create_arena_with_owner (
  p_user       uuid,
  p_arena_name text,
  p_owner_name text
)
  returns uuid
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare v_arena uuid;
begin
  insert into arenas(name) values (coalesce(nullif(btrim(p_arena_name), ''), 'Arena'))
    returning id into v_arena;
  insert into staff_profiles(arena_id, user_id, name, role, perms, active)
    values (v_arena, p_user, coalesce(nullif(btrim(p_owner_name), ''), 'Owner'), 'owner',
      _known_perms(), true);
  return v_arena;
end;
$function$;

comment on function public._create_arena_with_owner(uuid, text, text) is 'Internal: create an empty arena (no catalog: the owner adds station types, prices, stations, games and controllers on the dashboard) and make the given login its owner with every permission. Shared by bootstrap_owner and create_my_arena; callers validate the login first.';

grant execute on function "public"."_create_arena_with_owner"(uuid, text, text) to "postgres", "service_role";

revoke all on function "public"."_create_arena_with_owner"(uuid, text, text) from public;

revoke all on function "public"._create_arena_with_owner(p_user uuid, p_arena_name text, p_owner_name text) from anon;

revoke all on function "public"._create_arena_with_owner(p_user uuid, p_arena_name text, p_owner_name text) from authenticated;
