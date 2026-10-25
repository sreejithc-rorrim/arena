-- sync_fetch_entity() — client API entry point: a SECURITY INVOKER wrapper
--
-- The Data API exposes `public`, so nothing here runs with raised privileges:
-- this runs as the caller and hands over to private.sync_fetch_entity, which holds the
-- SECURITY DEFINER body and its checks (private/functions/sync_fetch_entity.sql). Same
-- name, arguments and result as before, so the apps call it unchanged.
create or replace function public.sync_fetch_entity (
  p_arena uuid,
  p_refs  jsonb
)
  returns jsonb
  language sql
  stable
  security invoker
  set search_path to ''
  AS $function$
  select private.sync_fetch_entity(p_arena, p_refs);
$function$;

comment on function public.sync_fetch_entity(uuid, jsonb) is 'Client API (sync): for each {type, id} ref, return the server''s current rows for that whole entity (session, controller, customer or booking) so a device can replace its copy after a refused op.';

grant execute on function "public"."sync_fetch_entity"(uuid, jsonb) to "authenticated", "postgres", "service_role";

revoke all on function "public"."sync_fetch_entity"(uuid, jsonb) from public;

revoke all on function "public".sync_fetch_entity(p_arena uuid, p_refs jsonb) from anon;
