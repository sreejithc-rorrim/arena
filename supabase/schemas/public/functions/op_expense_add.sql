-- op_expense_add — sync op 'expense.add': record an expense (a cost or a period's salary),
--   optionally with its first payment, in one transaction.
--
-- Permission: money.
-- Payload: expense_id (from the client), kind ('general' | 'salary'), title, amount_paise
--   (what is owed), notes?; a cost: category_id, expense_date, staff_id?; a salary: staff_id,
--   period_start, period_end (its expense_date is period_end); payment? — an object as
--   _expense_pay takes it: payment_id, amount_paise, method, paid_on, paid_from, payer_staff_id
--   (personal only), note?.
-- Checks / errors: forbidden; invalid_payload (hint expense_id); every check of _expense_check
--   (incl. salary_period_taken: no person has two salaries for the same days) and, with a
--   payment, of _expense_pay (incl. overpayment and the funding-source checks).
-- Writes: expenses; an audit_log row (entity expense, action add, after = its fields); the
--   payment, when given. Nothing else is generated or paid. Returns: {payment_status}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_expense_add (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now    timestamptz := statement_timestamp();
  v_e      expenses%rowtype;
  v_status text := 'unpaid';
begin
  perform _need(p_arena, 'money');
  v_e.id := nullif(p->>'expense_id', '')::uuid;
  if v_e.id is null then raise exception 'invalid_payload' using hint = 'expense_id'; end if;
  v_e.arena_id := p_arena;
  v_e.kind := p->>'kind';
  v_e.title := nullif(btrim(coalesce(p->>'title', '')), '');
  v_e.amount_paise := (p->>'amount_paise')::bigint;
  v_e.notes := nullif(btrim(coalesce(p->>'notes', '')), '');
  v_e.staff_id := nullif(p->>'staff_id', '')::uuid;
  if v_e.kind = 'salary' then
    v_e.period_start := nullif(p->>'period_start', '')::date;
    v_e.period_end := nullif(p->>'period_end', '')::date;
    v_e.expense_date := v_e.period_end;
  else
    v_e.category_id := nullif(p->>'category_id', '')::uuid;
    v_e.expense_date := nullif(p->>'expense_date', '')::date;
  end if;
  perform _expense_check(p_arena, v_e.kind, v_e.category_id, v_e.staff_id, v_e.period_start,
    v_e.period_end, v_e.title, v_e.amount_paise, v_e.expense_date, v_e.notes, true, true, v_e.id);

  insert into expenses(id, arena_id, kind, category_id, staff_id, period_start, period_end, title,
      amount_paise, expense_date, notes, created_by, created_at, updated_at)
    values (v_e.id, p_arena, v_e.kind, v_e.category_id, v_e.staff_id, v_e.period_start,
      v_e.period_end, v_e.title, v_e.amount_paise, v_e.expense_date, v_e.notes, auth.uid(),
      v_now, v_now);
  insert into audit_log(arena_id, entity_type, entity_id, action, after, created_by, created_at)
    values (p_arena, 'expense', v_e.id, 'add', _expense_fields(v_e), auth.uid(), v_now);

  if jsonb_typeof(p->'payment') = 'object' then
    perform 1 from expenses where id = v_e.id for update;
    v_status := _expense_pay(p_arena, v_e.id, p->'payment');
  end if;
  return jsonb_build_object('payment_status', v_status);
end;
$function$;

comment on function public.op_expense_add(uuid, jsonb) is
  'Sync op expense.add (money): records a cost or a staff member''s salary for a period, optionally with its first payment (company or an owner''s personal money); audited.';

grant execute on function "public"."op_expense_add"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_expense_add"(uuid, jsonb) from public;

revoke all on function "public"."op_expense_add"(uuid, jsonb) from anon;

revoke all on function "public"."op_expense_add"(uuid, jsonb) from authenticated;
