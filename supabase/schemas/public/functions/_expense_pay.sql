-- _expense_pay(arena, expense, payment) — record one payment toward an expense
--
-- Shared by op_expense_add (its optional `payment`) and op_expense_pay. The caller has locked
-- the expense row (for update), checked it is active and checked its person. Payment fields:
-- payment_id (the row id, from the client), amount_paise, method, paid_on, paid_from, payer_staff_id
-- (personal only), note?.
-- Errors: invalid_payload (hint payment_id); amount_zero; amount_negative; invalid_method (cash,
-- upi, card, bank, other); date_required; date_in_future (after today, IST);
-- date_out_of_range (before 1 Jan 2000); invalid_paid_from (company or personal);
-- payer_not_allowed (a company payment names nobody); payer_required (a personal one names its
-- owner); not_found (hint payer: not a profile of this arena); payer_not_owner (the payer is not
-- an active owner of this arena); note_too_long (200); overpayment (more than is still owed,
-- whatever the source). Inserts the payment, recomputes the expense's payment_status and
-- returns it.
-- Server-only: not executable by anon/authenticated.
create or replace function public._expense_pay (
  p_arena   uuid,
  p_expense uuid,
  p         jsonb
)
  returns text
  language plpgsql
  set search_path to 'public'
  AS $function$
declare
  v_now    timestamptz := statement_timestamp();
  v_id     uuid := nullif(p->>'payment_id', '')::uuid;
  v_amount bigint := (p->>'amount_paise')::bigint;
  v_method text := p->>'method';
  v_on     date := nullif(p->>'paid_on', '')::date;
  v_from   text := p->>'paid_from';
  v_payer  uuid := nullif(p->>'payer_staff_id', '')::uuid;
  v_note   text := nullif(btrim(coalesce(p->>'note', '')), '');
  v_total  bigint; v_paid bigint; v_status text;
  v_role   text; v_active boolean; v_removed timestamptz;
begin
  if v_id is null then raise exception 'invalid_payload' using hint = 'payment_id'; end if;
  if v_amount is null or v_amount = 0 then raise exception 'amount_zero' using hint = 'more than ₹0'; end if;
  if v_amount < 0 then raise exception 'amount_negative' using hint = 'more than ₹0'; end if;
  if v_method is null or v_method not in ('cash', 'upi', 'card', 'bank', 'other') then
    raise exception 'invalid_method' using hint = 'cash, upi, card, bank or other';
  end if;
  if v_on is null then raise exception 'date_required' using hint = 'the day it was paid'; end if;
  if v_on > _pr_ist_date(v_now) then
    raise exception 'date_in_future' using hint = 'record a payment on or after the day it is made';
  end if;
  if v_on < date '2000-01-01' then
    raise exception 'date_out_of_range' using hint = 'on or after 1 Jan 2000';
  end if;

  -- Funding source: the company's account names nobody; personal money names its owner.
  if v_from is null or v_from not in ('company', 'personal') then
    raise exception 'invalid_paid_from' using hint = 'company or personal';
  end if;
  if v_from = 'company' and v_payer is not null then
    raise exception 'payer_not_allowed' using hint = 'a company payment names nobody';
  end if;
  if v_from = 'personal' then
    if v_payer is null then raise exception 'payer_required' using hint = 'say which owner paid'; end if;
    select role, active, removed_at into v_role, v_active, v_removed
      from staff_profiles where id = v_payer and arena_id = p_arena;
    if not found then raise exception 'not_found' using hint = 'payer'; end if;
    if v_role <> 'owner' or not v_active or v_removed is not null then
      raise exception 'payer_not_owner' using hint = 'personal money is paid by an owner of this arena';
    end if;
  end if;
  if v_note is not null and char_length(v_note) > 200 then
    raise exception 'note_too_long' using hint = 'at most 200 characters';
  end if;

  select amount_paise into v_total from expenses where id = p_expense;
  select coalesce(sum(amount_paise), 0) into v_paid from expense_payments where expense_id = p_expense;
  if v_paid + v_amount > v_total then
    raise exception 'overpayment'
      using hint = case when v_total - v_paid <= 0 then 'this expense is already paid'
                        else 'only ' || _rupees(v_total - v_paid) || ' is due' end;
  end if;

  insert into expense_payments(id, arena_id, expense_id, kind, amount_paise, method, paid_on,
      paid_from, payer_staff_id, note, created_by, created_at)
    values (v_id, p_arena, p_expense, 'payment', v_amount, v_method, v_on,
      v_from, v_payer, v_note, auth.uid(), v_now);
  v_status := _payment_status(v_total, v_paid + v_amount);
  update expenses set payment_status = v_status, updated_at = v_now where id = p_expense;
  return v_status;
end;
$function$;

comment on function public._expense_pay(uuid, uuid, jsonb) is 'Internal (op_expense_add / op_expense_pay): validate and record one payment (amount, method, day, company or an owner''s personal money) toward a locked expense, never more than is owed; returns the new payment status.';

grant execute on function "public"."_expense_pay"(uuid, uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."_expense_pay"(uuid, uuid, jsonb) from public;

revoke all on function "public"."_expense_pay"(uuid, uuid, jsonb) from anon;

revoke all on function "public"."_expense_pay"(uuid, uuid, jsonb) from authenticated;
