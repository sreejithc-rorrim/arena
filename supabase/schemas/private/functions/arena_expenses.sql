-- arena_expenses(arena, first, last) — the owner dashboard's Expenses for a period
--
-- Lives in `private`, which the Data API does not expose: SECURITY DEFINER
-- code never sits in an API schema. Clients reach it only through the
-- SECURITY INVOKER wrapper public.arena_expenses.
--
-- For IST days p_first…p_last (inclusive, at most 400 days, else 'invalid_range'), a jsonb
-- object:
--   expenses — every expense whose expense_date falls in the period (voided ones too, flagged
--     by status), newest first, as _expense_json (paid split company / personal, balance,
--     payments with source and payer);
--   payments — every payment and reversal whose paid_on falls in the period, whatever the
--     expense's date, newest first: {id, expense_id, expense_title, expense_kind,
--     expense_status, category_name, staff_id, staff_name, kind, amount_paise, method, paid_on,
--     paid_from, payer_staff_id, payer_name, note, reverses_id} — the cash that left the
--     company account, or owners' own money, in the period;
--   owed_total_paise, owed_count — what is still unpaid on active expenses of any date.
-- SECURITY DEFINER. Caller must hold money in p_arena (app_has_perm; the owner holds it),
-- else 'forbidden'.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.arena_expenses (
  p_arena uuid,
  p_first date,
  p_last  date
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
begin
  if not private.app_has_perm(p_arena, 'money') then
    raise exception 'forbidden' using errcode = '42501', hint = 'needs money';
  end if;
  if p_first is null or p_last is null or p_last < p_first or p_last - p_first > 399 then
    raise exception 'invalid_range' using hint = 'first day on or before the last, at most 400 days';
  end if;
  return jsonb_build_object(
    'expenses', coalesce((
      select jsonb_agg(_expense_json(e.id) order by e.expense_date desc, e.created_at desc, e.id)
        from expenses e
       where e.arena_id = p_arena and e.expense_date between p_first and p_last), '[]'::jsonb),
    'payments', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', p.id, 'expense_id', p.expense_id, 'expense_title', e.title,
          'expense_kind', e.kind, 'expense_status', e.status, 'category_name', c.name,
          'staff_id', e.staff_id, 'staff_name', s.name,
          'kind', p.kind, 'amount_paise', p.amount_paise, 'method', p.method,
          'paid_on', p.paid_on, 'paid_from', p.paid_from,
          'payer_staff_id', p.payer_staff_id, 'payer_name', ps.name,
          'note', p.note, 'reverses_id', p.reverses_id)
          order by p.paid_on desc, p.created_at desc, p.id)
        from expense_payments p
        join expenses e on e.id = p.expense_id
        left join expense_categories c on c.id = e.category_id
        left join staff_profiles s on s.id = e.staff_id
        left join staff_profiles ps on ps.id = p.payer_staff_id
       where p.arena_id = p_arena and p.paid_on between p_first and p_last), '[]'::jsonb),
    'owed_total_paise', (
      select coalesce(sum(e.amount_paise - coalesce(t.paid, 0)), 0)
        from expenses e
        left join lateral (select sum(amount_paise) as paid from expense_payments
                            where expense_id = e.id) t on true
       where e.arena_id = p_arena and e.status = 'active' and e.payment_status <> 'paid'),
    'owed_count', (
      select count(*) from expenses
       where arena_id = p_arena and status = 'active' and payment_status <> 'paid'));
end;
$function$;

comment on function private.arena_expenses(uuid, date, date) is 'Client API (money): the arena''s expenses dated in an IST period, the payments made in it (company or owners'' own money) and what is still owed overall, for the admin dashboard''s Expenses screen. At most 400 days.';

grant execute on function "private"."arena_expenses"(uuid, date, date) to "authenticated", "postgres", "service_role";

revoke all on function "private"."arena_expenses"(uuid, date, date) from public;

revoke all on function "private"."arena_expenses"(uuid, date, date) from anon;
