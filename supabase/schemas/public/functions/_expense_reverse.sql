-- _expense_reverse(arena, payment, reversal_id, reason) — undo one payment with a reversal row
--
-- Shared by op_expense_payment_reverse and op_expense_void. The caller has locked the
-- payment's expense and checked the reason. The reversal copies the payment's expense, method,
-- day, source and payer with the opposite amount (_expense_payment_check holds the table to
-- that), so it comes off the same bucket — company, or that owner — in the same period.
-- Errors: not_found (hint payment: no payment with that id in this arena, or a reversal);
-- already_reversed. Returns the amount reversed (positive paise). The caller recomputes the
-- expense's payment status.
-- Server-only: not executable by anon/authenticated.
create or replace function public._expense_reverse (
  p_arena    uuid,
  p_payment  uuid,
  p_reversal uuid,
  p_reason   text
)
  returns bigint
  language plpgsql
  set search_path to 'public'
  AS $function$
declare v_orig expense_payments%rowtype;
begin
  select * into v_orig from expense_payments where id = p_payment and arena_id = p_arena;
  if not found or v_orig.kind <> 'payment' then raise exception 'not_found' using hint = 'payment'; end if;
  if exists (select 1 from expense_payments where reverses_id = p_payment) then
    raise exception 'already_reversed' using hint = 'this payment was already reversed';
  end if;
  insert into expense_payments(id, arena_id, expense_id, kind, amount_paise, method, paid_on,
      paid_from, payer_staff_id, note, reverses_id, created_by, created_at)
    values (p_reversal, p_arena, v_orig.expense_id, 'reversal', -v_orig.amount_paise,
      v_orig.method, v_orig.paid_on, v_orig.paid_from, v_orig.payer_staff_id, p_reason,
      p_payment, auth.uid(), statement_timestamp());
  return v_orig.amount_paise;
end;
$function$;

comment on function public._expense_reverse(uuid, uuid, uuid, text) is 'Internal (op_expense_payment_reverse / op_expense_void): insert the reversal of one payment, keeping its method, day, source and payer; refuses a payment already reversed.';

grant execute on function "public"."_expense_reverse"(uuid, uuid, uuid, text) to "postgres", "service_role";

revoke all on function "public"."_expense_reverse"(uuid, uuid, uuid, text) from public;

revoke all on function "public"."_expense_reverse"(uuid, uuid, uuid, text) from anon;

revoke all on function "public"."_expense_reverse"(uuid, uuid, uuid, text) from authenticated;
