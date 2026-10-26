-- op_expense_update — sync op 'expense.update': change an expense's details, audited.
--
-- Permission: money.
-- Payload: expense_id and the full set of editable fields as they should be: title,
--   amount_paise, notes?, staff_id?; a cost: category_id, expense_date; a salary: staff_id,
--   period_start, period_end (its expense_date follows period_end). The kind never changes.
-- Payments are never edited here: the amount owed may change, but never below what is
--   already paid (reverse a payment first).
-- Checks / errors: forbidden; not_found (hint expense); voided; the person checks of
--   _expense_staff_check on the current person; every check of _expense_check (a retired
--   category or removed person only when newly chosen); amount_below_paid.
-- Writes: the expense (payment_status recomputed); an audit_log row (entity expense, action
--   update, before / after = the changed fields only). No change at all writes nothing.
--   Returns: {payment_status}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_expense_update (
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
  v_id     uuid := nullif(p->>'expense_id', '')::uuid;
  v_old    expenses%rowtype;
  v_new    expenses%rowtype;
  v_paid   bigint;
  v_before jsonb; v_after jsonb; v_b jsonb; v_a jsonb;
begin
  perform _need(p_arena, 'money');
  select * into v_old from expenses where id = v_id and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'expense'; end if;
  if v_old.status = 'voided' then raise exception 'voided' using hint = 'a voided expense cannot change'; end if;
  if v_old.staff_id is not null then perform _expense_staff_check(p_arena, v_old.staff_id, false); end if;

  v_new := v_old;
  v_new.title := nullif(btrim(coalesce(p->>'title', '')), '');
  v_new.amount_paise := (p->>'amount_paise')::bigint;
  v_new.notes := nullif(btrim(coalesce(p->>'notes', '')), '');
  v_new.staff_id := nullif(p->>'staff_id', '')::uuid;
  if v_old.kind = 'salary' then
    v_new.period_start := nullif(p->>'period_start', '')::date;
    v_new.period_end := nullif(p->>'period_end', '')::date;
    v_new.expense_date := v_new.period_end;
  else
    v_new.category_id := nullif(p->>'category_id', '')::uuid;
    v_new.expense_date := nullif(p->>'expense_date', '')::date;
  end if;
  perform _expense_check(p_arena, v_new.kind, v_new.category_id, v_new.staff_id,
    v_new.period_start, v_new.period_end, v_new.title, v_new.amount_paise, v_new.expense_date,
    v_new.notes, v_new.category_id is distinct from v_old.category_id,
    v_new.staff_id is distinct from v_old.staff_id, v_id);

  select coalesce(sum(amount_paise), 0) into v_paid from expense_payments where expense_id = v_id;
  if v_new.amount_paise < v_paid then
    raise exception 'amount_below_paid'
      using hint = _rupees(v_paid) || ' is already paid: reverse a payment first';
  end if;

  v_before := _expense_fields(v_old);
  v_after := _expense_fields(v_new);
  if v_before = v_after then return jsonb_build_object('payment_status', v_old.payment_status); end if;
  select jsonb_object_agg(k, v_before->k), jsonb_object_agg(k, v_after->k) into v_b, v_a
    from jsonb_object_keys(v_after) k where v_before->k is distinct from v_after->k;

  v_new.payment_status := _payment_status(v_new.amount_paise, v_paid);
  update expenses set title = v_new.title, amount_paise = v_new.amount_paise, notes = v_new.notes,
      staff_id = v_new.staff_id, category_id = v_new.category_id,
      period_start = v_new.period_start, period_end = v_new.period_end,
      expense_date = v_new.expense_date, payment_status = v_new.payment_status, updated_at = v_now
    where id = v_id;
  insert into audit_log(arena_id, entity_type, entity_id, action, before, after, created_by, created_at)
    values (p_arena, 'expense', v_id, 'update', v_b, v_a, auth.uid(), v_now);
  return jsonb_build_object('payment_status', v_new.payment_status);
end;
$function$;

comment on function public.op_expense_update(uuid, jsonb) is
  'Sync op expense.update (money): changes an expense''s details (never its kind, never the amount below what is paid; payments untouched); audited with the changed fields.';

grant execute on function "public"."op_expense_update"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_expense_update"(uuid, jsonb) from public;

revoke all on function "public"."op_expense_update"(uuid, jsonb) from anon;

revoke all on function "public"."op_expense_update"(uuid, jsonb) from authenticated;
