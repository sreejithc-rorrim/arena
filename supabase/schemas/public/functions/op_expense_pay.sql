-- op_expense_pay — sync op 'expense.pay': record a payment toward an expense.
--
-- Permission: money.
-- Payload: expense_id, payment_id (from the client: a re-sent payment cannot double),
--   amount_paise, method (cash | upi | card | bank | other), paid_on (IST day, not after
--   today), paid_from ('company' | 'personal'), payer_staff_id (the owner's staff_profiles id;
--   personal only), note?.
-- An expense may be paid in several payments from different sources; all of them count toward
--   what is owed. A payment before a salary period ends is an advance on it.
-- Checks / errors: forbidden; not_found (hint expense); voided; the person checks of
--   _expense_staff_check; every check of _expense_pay (incl. overpayment, payer_required,
--   payer_not_allowed, payer_not_owner).
-- Writes: expense_payments; the expense's payment_status. Returns: {payment_status}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_expense_pay (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_id uuid := nullif(p->>'expense_id', '')::uuid;
  v_e  expenses%rowtype;
begin
  perform _need(p_arena, 'money');
  -- Lock the expense so two payments on it queue here and the second sees the first.
  select * into v_e from expenses where id = v_id and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'expense'; end if;
  if v_e.status = 'voided' then raise exception 'voided' using hint = 'a voided expense takes no payments'; end if;
  if v_e.staff_id is not null then perform _expense_staff_check(p_arena, v_e.staff_id, false); end if;
  return jsonb_build_object('payment_status', _expense_pay(p_arena, v_id, p));
end;
$function$;

comment on function public.op_expense_pay(uuid, jsonb) is
  'Sync op expense.pay (money): records one payment toward an expense from the company account or an owner''s personal money, never more than is owed.';

grant execute on function "public"."op_expense_pay"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_expense_pay"(uuid, jsonb) from public;

revoke all on function "public"."op_expense_pay"(uuid, jsonb) from anon;

revoke all on function "public"."op_expense_pay"(uuid, jsonb) from authenticated;
