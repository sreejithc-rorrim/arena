-- arena_expenses() — client API entry point: a SECURITY INVOKER wrapper
--
-- The Data API exposes `public`, so nothing here runs with raised privileges:
-- this runs as the caller and hands over to private.arena_expenses, which holds the
-- SECURITY DEFINER body and its checks (private/functions/arena_expenses.sql).
create or replace function public.arena_expenses (
  p_arena uuid,
  p_first date,
  p_last  date
)
  returns jsonb
  language sql
  stable
  security invoker
  set search_path to ''
  AS $function$
  select private.arena_expenses(p_arena, p_first, p_last);
$function$;

comment on function public.arena_expenses(uuid, date, date) is 'Client API (money): the arena''s expenses dated in an IST period, the payments made in it (company or owners'' own money) and what is still owed overall, for the admin dashboard''s Expenses screen. At most 400 days.';

grant execute on function "public"."arena_expenses"(uuid, date, date) to "authenticated", "postgres", "service_role";

revoke all on function "public"."arena_expenses"(uuid, date, date) from public;

revoke all on function "public"."arena_expenses"(uuid, date, date) from anon;
