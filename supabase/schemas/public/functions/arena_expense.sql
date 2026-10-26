-- arena_expense() — client API entry point: a SECURITY INVOKER wrapper
--
-- The Data API exposes `public`, so nothing here runs with raised privileges:
-- this runs as the caller and hands over to private.arena_expense, which holds the
-- SECURITY DEFINER body and its checks (private/functions/arena_expense.sql).
create or replace function public.arena_expense (
  p_arena uuid,
  p_id    uuid
)
  returns jsonb
  language sql
  stable
  security invoker
  set search_path to ''
  AS $function$
  select private.arena_expense(p_arena, p_id);
$function$;

comment on function public.arena_expense(uuid, uuid) is 'Client API (money): one expense with its payments (source and payer) and its audit history, for the admin dashboard''s expense detail.';

grant execute on function "public"."arena_expense"(uuid, uuid) to "authenticated", "postgres", "service_role";

revoke all on function "public"."arena_expense"(uuid, uuid) from public;

revoke all on function "public"."arena_expense"(uuid, uuid) from anon;
