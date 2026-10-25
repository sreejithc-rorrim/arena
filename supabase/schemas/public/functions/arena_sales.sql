-- arena_sales() — client API entry point: a SECURITY INVOKER wrapper
--
-- The Data API exposes `public`, so nothing here runs with raised privileges:
-- this runs as the caller and hands over to private.arena_sales, which holds the
-- SECURITY DEFINER body and its checks (private/functions/arena_sales.sql). Same
-- name, arguments and result as before, so the apps call it unchanged.
create or replace function public.arena_sales (
  p_arena uuid,
  p_from  timestamptz,
  p_to    timestamptz
)
  returns jsonb
  language sql
  stable
  security invoker
  set search_path to ''
  AS $function$
  select private.arena_sales(p_arena, p_from, p_to);
$function$;

comment on function public.arena_sales(uuid, timestamptz, timestamptz) is 'Client API (owner level): the arena''s closed bills (sessions, completed or voided) that closed in [from, to), newest first, for the admin dashboard''s Sales screen. At most 93 days.';

grant execute on function "public"."arena_sales"(uuid, timestamptz, timestamptz) to "authenticated", "postgres", "service_role";

revoke all on function "public"."arena_sales"(uuid, timestamptz, timestamptz) from public;

revoke all on function "public".arena_sales(p_arena uuid, p_from timestamptz, p_to timestamptz) from anon;
