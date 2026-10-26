-- arena_staff_salary() — client API entry point: a SECURITY INVOKER wrapper
--
-- The Data API exposes `public`, so nothing here runs with raised privileges:
-- this runs as the caller and hands over to private.arena_staff_salary, which holds the
-- SECURITY DEFINER body and its checks (private/functions/arena_staff_salary.sql).
create or replace function public.arena_staff_salary (
  p_arena uuid,
  p_staff uuid
)
  returns jsonb
  language sql
  stable
  security invoker
  set search_path to ''
  AS $function$
  select private.arena_staff_salary(p_arena, p_staff);
$function$;

comment on function public.arena_staff_salary(uuid, uuid) is 'Client API (money): a staff member''s agreed salary history and every salary period recorded for them with payments, for the admin dashboard''s Salaries tab.';

grant execute on function "public"."arena_staff_salary"(uuid, uuid) to "authenticated", "postgres", "service_role";

revoke all on function "public"."arena_staff_salary"(uuid, uuid) from public;

revoke all on function "public"."arena_staff_salary"(uuid, uuid) from anon;
