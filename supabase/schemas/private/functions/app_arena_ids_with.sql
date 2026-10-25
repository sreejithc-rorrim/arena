-- app_arena_ids_with(perms) — arenas where the caller may read sensitive rows
--
-- Lives in `private` (not exposed by the Data API). The membership test for the
-- RLS policies on money, customer and audit tables: the arena_id of every
-- active staff_profiles row of auth.uid() whose role is owner or that holds any
-- of p_any. Policies call it as `arena_id in (select private.app_arena_ids_with(...))`
-- so it runs once per query. Who needs what (direct reads by the dashboard and
-- Realtime Postgres Changes; devices get their data through sync_pull):
--   payments, session_charges:
--       bill (floor billing) or money / reports (owner level);
--   customers: start or members (check-in, members) or money / reports;
--   audit_log: money / reports (owner level) only.
-- Executable by authenticated because RLS policies run as the caller.
create or replace function private.app_arena_ids_with (
  p_any text[]
)
  returns SETOF uuid
  language sql
  stable
  security definer
  set search_path to 'public'
  AS $function$
  select arena_id from staff_profiles
   where user_id = auth.uid() and active and (role = 'owner' or perms && p_any);
$function$;

comment on function private.app_arena_ids_with(text[]) is 'Arena ids where the signed-in user is an active owner or holds any of the given permissions; the membership test of the RLS policies on money, customer and audit tables.';

grant execute
  on function "private"."app_arena_ids_with"(text[])
  to "authenticated", "postgres", "service_role";

revoke all on function "private"."app_arena_ids_with"(text[]) from public;

revoke all on function "private".app_arena_ids_with(p_any text[]) from anon;
