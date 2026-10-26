-- op_expense_payment_reverse — sync op 'expense.payment_reverse': undo a mistaken payment, audited.
--
-- Permission: money.
-- Payload: payment_id (the payment to undo), reversal_id? (the new row's id, from the client;
--   generated when absent), reason (required: 1–500 characters after trimming).
-- Nothing is edited or deleted: a reversal row with the opposite amount is added, keeping the
--   payment's method, day, source and payer (_expense_reverse), so it comes off the same
--   company or owner total in the same period.
-- Checks / errors: forbidden; reason_required; reason_too_long; not_found (hint payment); the
--   person checks of _expense_staff_check; already_reversed.
-- Writes: expense_payments (the reversal); the expense's payment_status; an audit_log row
--   (entity expense, action payment_reverse, reason, before / after {paid_paise}, after also
--   {payment_id}). Returns: {payment_status}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_expense_payment_reverse (
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
  v_pay    uuid := nullif(p->>'payment_id', '')::uuid;
  v_rev    uuid := coalesce(nullif(p->>'reversal_id', '')::uuid, gen_random_uuid());
  v_reason text := nullif(btrim(coalesce(p->>'reason', '')), '');
  v_exp    uuid;
  v_e      expenses%rowtype;
  v_amount bigint; v_paid bigint; v_status text;
begin
  perform _need(p_arena, 'money');
  if v_reason is null then raise exception 'reason_required' using hint = 'say why the payment is reversed'; end if;
  if length(v_reason) > 500 then raise exception 'reason_too_long' using hint = 'at most 500 characters'; end if;
  select expense_id into v_exp from expense_payments where id = v_pay and arena_id = p_arena;
  if not found then raise exception 'not_found' using hint = 'payment'; end if;
  select * into v_e from expenses where id = v_exp for update;
  if v_e.staff_id is not null then perform _expense_staff_check(p_arena, v_e.staff_id, false); end if;

  v_amount := _expense_reverse(p_arena, v_pay, v_rev, v_reason);
  select coalesce(sum(amount_paise), 0) into v_paid from expense_payments where expense_id = v_exp;
  v_status := _payment_status(v_e.amount_paise, v_paid);
  update expenses set payment_status = v_status, updated_at = v_now where id = v_exp;
  insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
      created_by, created_at)
    values (p_arena, 'expense', v_exp, 'payment_reverse', v_reason,
      jsonb_build_object('paid_paise', v_paid + v_amount),
      jsonb_build_object('paid_paise', v_paid, 'payment_id', v_pay), auth.uid(), v_now);
  return jsonb_build_object('payment_status', v_status);
end;
$function$;

comment on function public.op_expense_payment_reverse(uuid, jsonb) is
  'Sync op expense.payment_reverse (money): undoes a mistaken expense payment with a reversal row that keeps its method, day, source and payer; reason required; audited.';

grant execute on function "public"."op_expense_payment_reverse"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_expense_payment_reverse"(uuid, jsonb) from public;

revoke all on function "public"."op_expense_payment_reverse"(uuid, jsonb) from anon;

revoke all on function "public"."op_expense_payment_reverse"(uuid, jsonb) from authenticated;
