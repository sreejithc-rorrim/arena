-- _expense_fields(expense) — the editable fields of an expense as jsonb, for audit_log
--
-- What op_expense_add records as `after` and op_expense_update compares (and records the
-- changed keys of) as `before` / `after`: title, category_id, staff_id, period_start,
-- period_end, amount_paise, expense_date, notes.
-- Server-only: not executable by anon/authenticated.
create or replace function public._expense_fields (
  p_e public.expenses
)
  returns jsonb
  language sql
  immutable
  set search_path to 'public'
  AS $function$
  select jsonb_build_object(
    'title', p_e.title, 'category_id', p_e.category_id, 'staff_id', p_e.staff_id,
    'period_start', p_e.period_start, 'period_end', p_e.period_end,
    'amount_paise', p_e.amount_paise, 'expense_date', p_e.expense_date, 'notes', p_e.notes);
$function$;

comment on function public._expense_fields(public.expenses) is 'Internal (expense ops): an expense''s editable fields as jsonb, for its audit_log before / after.';

grant execute on function "public"."_expense_fields"(public.expenses) to "postgres", "service_role";

revoke all on function "public"."_expense_fields"(public.expenses) from public;

revoke all on function "public"."_expense_fields"(public.expenses) from anon;

revoke all on function "public"."_expense_fields"(public.expenses) from authenticated;
