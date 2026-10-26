-- _expense_json(id) — one expense with its payments, as the dashboard reads it
--
-- Used by arena_expenses, arena_expense and arena_staff_salary (which check the caller). Paid
-- figures are net of reversals: paid_paise = paid_company_paise + paid_personal_paise, and
-- balance_paise = amount_paise − paid_paise (0 for a voided expense). Names come from
-- staff_profiles (a removed member reads 'Deleted member'). Each payment says whether it has
-- been reversed. Null when there is no such expense.
-- Server-only: not executable by anon/authenticated.
create or replace function public._expense_json (
  p_id uuid
)
  returns jsonb
  language sql
  stable
  set search_path to 'public'
  AS $function$
  select jsonb_build_object(
    'id', e.id, 'kind', e.kind, 'title', e.title,
    'category_id', e.category_id, 'category_name', c.name,
    'staff_id', e.staff_id, 'staff_name', s.name,
    'period_start', e.period_start, 'period_end', e.period_end,
    'amount_paise', e.amount_paise,
    'paid_paise', coalesce(t.paid, 0),
    'paid_company_paise', coalesce(t.company, 0),
    'paid_personal_paise', coalesce(t.personal, 0),
    'balance_paise', case when e.status = 'voided' then 0 else e.amount_paise - coalesce(t.paid, 0) end,
    'payment_status', e.payment_status, 'status', e.status, 'void_reason', e.void_reason,
    'expense_date', e.expense_date, 'notes', e.notes,
    'created_by', e.created_by, 'created_by_name', cb.name,
    'created_at', e.created_at, 'updated_at', e.updated_at,
    'payments', coalesce(t.rows, '[]'::jsonb))
    from expenses e
    left join expense_categories c on c.id = e.category_id
    left join staff_profiles s on s.id = e.staff_id
    left join staff_profiles cb on cb.user_id = e.created_by and cb.arena_id = e.arena_id
    left join lateral (
      select sum(p.amount_paise) as paid,
             sum(p.amount_paise) filter (where p.paid_from = 'company') as company,
             sum(p.amount_paise) filter (where p.paid_from = 'personal') as personal,
             jsonb_agg(jsonb_build_object(
               'id', p.id, 'kind', p.kind, 'amount_paise', p.amount_paise, 'method', p.method,
               'paid_on', p.paid_on, 'paid_from', p.paid_from,
               'payer_staff_id', p.payer_staff_id, 'payer_name', ps.name,
               'note', p.note, 'reverses_id', p.reverses_id,
               'reversed', exists (select 1 from expense_payments r where r.reverses_id = p.id),
               'created_by_name', pb.name, 'created_at', p.created_at)
               order by p.created_at, p.id) as rows
        from expense_payments p
        left join staff_profiles ps on ps.id = p.payer_staff_id
        left join staff_profiles pb on pb.user_id = p.created_by and pb.arena_id = p.arena_id
       where p.expense_id = e.id
    ) t on true
   where e.id = p_id;
$function$;

comment on function public._expense_json(uuid) is 'Internal (expense reads): one expense with category, person, paid (company / personal, net of reversals), balance and its payments with source and payer, as jsonb.';

grant execute on function "public"."_expense_json"(uuid) to "postgres", "service_role";

revoke all on function "public"."_expense_json"(uuid) from public;

revoke all on function "public"."_expense_json"(uuid) from anon;

revoke all on function "public"."_expense_json"(uuid) from authenticated;
