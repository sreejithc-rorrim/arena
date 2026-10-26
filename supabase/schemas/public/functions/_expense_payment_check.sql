-- _expense_payment_check() — trigger: a reversal mirrors exactly one payment
--
-- BEFORE INSERT row trigger (t_expense_payments_check) on expense_payments. A reversal must
-- undo a payment (kind 'payment') of the same expense with the opposite amount and keep its
-- source, payer, method and day, so company and personal totals stay right in the period the
-- money moved. The ops copy those fields (_expense_reverse); this refuses anything else written
-- by a script or a future op bug. Raises reversal_mismatch (23514). Not SECURITY DEFINER.
-- Server-only: not executable by anon/authenticated.
create or replace function public._expense_payment_check()
  returns trigger
  language plpgsql
  set search_path to 'public'
  AS $function$
declare v_orig expense_payments%rowtype;
begin
  if new.kind = 'reversal' then
    select * into v_orig from expense_payments where id = new.reverses_id;
    if not found or v_orig.kind <> 'payment' or v_orig.expense_id <> new.expense_id
       or new.amount_paise <> -v_orig.amount_paise or new.paid_from <> v_orig.paid_from
       or new.payer_staff_id is distinct from v_orig.payer_staff_id
       or new.method <> v_orig.method or new.paid_on <> v_orig.paid_on then
      raise exception 'reversal_mismatch' using errcode = '23514',
        hint = 'a reversal mirrors one payment: same expense, source, payer, method and day, opposite amount';
    end if;
  end if;
  return new;
end;
$function$;

comment on function public._expense_payment_check() is 'Trigger (before insert on expense_payments): a reversal must mirror one payment of the same expense (opposite amount; same source, payer, method and day), else reversal_mismatch.';

grant execute on function "public"."_expense_payment_check"() to "postgres", "service_role";

revoke all on function "public"."_expense_payment_check"() from public;

revoke all on function "public"."_expense_payment_check"() from anon;

revoke all on function "public"."_expense_payment_check"() from authenticated;
