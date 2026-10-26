-- arena_staff_salary(arena, staff) — one staff member's agreed salary and salary history
--
-- Lives in `private`, which the Data API does not expose: SECURITY DEFINER
-- code never sits in an API schema. Clients reach it only through the
-- SECURITY INVOKER wrapper public.arena_staff_salary.
--
-- {staff_id, name, removed, salaries, periods}: salaries — their staff_salaries rows, latest
-- effective_from first {id, effective_from, period, amount_paise, note}; periods — every salary
-- recorded for them (voided ones too, flagged by status), latest period first, as _expense_json
-- (owed, paid company / personal, balance, payments).
-- SECURITY DEFINER. Caller must hold money in p_arena (app_has_perm), else 'forbidden';
-- 'not_found' (hint staff) when the arena has no such member.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.arena_staff_salary (
  p_arena uuid,
  p_staff uuid
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare v_name text; v_removed timestamptz;
begin
  if not private.app_has_perm(p_arena, 'money') then
    raise exception 'forbidden' using errcode = '42501', hint = 'needs money';
  end if;
  select name, removed_at into v_name, v_removed
    from staff_profiles where id = p_staff and arena_id = p_arena;
  if not found then raise exception 'not_found' using hint = 'staff'; end if;
  return jsonb_build_object(
    'staff_id', p_staff, 'name', v_name, 'removed', v_removed is not null,
    'salaries', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', s.id, 'effective_from', s.effective_from, 'period', s.period,
          'amount_paise', s.amount_paise, 'note', s.note)
          order by s.effective_from desc)
        from staff_salaries s where s.staff_id = p_staff and s.arena_id = p_arena), '[]'::jsonb),
    'periods', coalesce((
      select jsonb_agg(_expense_json(e.id) order by e.period_start desc, e.created_at desc)
        from expenses e
       where e.arena_id = p_arena and e.staff_id = p_staff and e.kind = 'salary'), '[]'::jsonb));
end;
$function$;

comment on function private.arena_staff_salary(uuid, uuid) is 'Client API (money): a staff member''s agreed salary history and every salary period recorded for them with payments, for the admin dashboard''s Salaries tab.';

grant execute on function "private"."arena_staff_salary"(uuid, uuid) to "authenticated", "postgres", "service_role";

revoke all on function "private"."arena_staff_salary"(uuid, uuid) from public;

revoke all on function "private"."arena_staff_salary"(uuid, uuid) from anon;
