-- my_bills(arena, day) — the floor app's "My bills": the caller's own closed bills of one day
--
-- Lives in `private`; clients reach it only through the SECURITY INVOKER wrapper
-- public.my_bills.
--
-- The bills (single sessions, completed or voided) the caller started (created_by =
-- auth.uid()) that closed on p_day (IST business date), newest first, as a jsonb array of _sales
-- summaries — the same shape as arena_sales, so op_bill_adjust's rules read off the same fields.
-- Who: bill_edit or bill_record (owners hold both); anyone else 'forbidden'. p_day null →
-- 'invalid_range'.
-- SECURITY DEFINER.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.my_bills (
  p_arena uuid,
  p_day   date
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_from timestamptz := p_day::timestamp at time zone 'Asia/Kolkata';
begin
  if auth.uid() is null or p_arena is null
     or not (private.app_has_perm(p_arena, 'bill_edit')
             or private.app_has_perm(p_arena, 'bill_record')) then
    raise exception 'forbidden' using errcode = '42501', hint = 'needs bill_edit or bill_record';
  end if;
  if p_day is null then
    raise exception 'invalid_range' using hint = 'a day';
  end if;
  return coalesce((
    select jsonb_agg(b order by (b->>'at')::timestamptz desc, b->>'id')
      from _sales(p_arena, v_from, v_from + interval '1 day') b
     where (b->>'id')::uuid in (
             select id from sessions where arena_id = p_arena and created_by = auth.uid())),
    '[]'::jsonb);
end;
$function$;

comment on function private.my_bills(uuid, date) is 'Client API (bill_edit or bill_record): the caller''s own closed bills (sessions they started) that closed on the given IST day, newest first, as _sales summaries — the floor app''s My bills.';

grant execute on function "private"."my_bills"(uuid, date) to "authenticated", "postgres", "service_role";

revoke all on function "private"."my_bills"(uuid, date) from public;

revoke all on function "private".my_bills(p_arena uuid, p_day date) from anon;
