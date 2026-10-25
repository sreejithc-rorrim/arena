-- op_payment — sync op 'payment.record': record a payment or refund against a session bill.
--
-- Permission: bill; plus discount for a refund.
-- Payload: scope ('single', the default and only value), parent_id (session id), payment_id,
--   amount_paise, is_refund?, method ('cash' | 'upi' | 'card' | 'other'), note, reason (required
--   for a refund).
-- Checks / errors: forbidden; invalid_payload (hint scope: any scope but 'single'); refund_exceeds_paid (refund larger than what was collected);
--   overpayment (payment beyond a final, non-waived bill); amount_zero; refund_reason_required;
--   amount_negative (negative amount that is not a refund); invalid_method; not_found (hint
--   session); voided (a payment on a voided bill — a refund is allowed there, so money
--   collected before the void can be given back and the till reconciles); duplicate
--   (payment_id reused).
-- Writes: payments (a refund is stored negative); the parent's payment_status
--   unless it is 'waived' or the bill is voided. Returns: {payment_status}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_payment (
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
  v_scope  text    := coalesce(p->>'scope', 'single');
  v_parent uuid    := (p->>'parent_id')::uuid;
  v_refund boolean := coalesce((p->>'is_refund')::boolean, false);
  v_amount bigint  := (p->>'amount_paise')::bigint;
  v_status text; v_pay text; v_billed bigint; v_paid bigint;
begin
  -- Permission refusals keep their own code, ahead of any balance check.
  perform _need(p_arena, 'bill');
  if v_refund then perform _need(p_arena, 'discount'); end if;
  if v_scope <> 'single' then raise exception 'invalid_payload' using hint = 'scope'; end if;

  -- Balance (0016). Lock the parent so two pushes for the same bill queue here
  -- and the second sees the first one's payment.
  select status, payment_status, billed_amount_paise into v_status, v_pay, v_billed
    from sessions where id = v_parent and arena_id = p_arena for update;
  if found then
    select coalesce(sum(amount_paise), 0) into v_paid
      from payments where session_id = v_parent;
  end if;

  -- A payment on a voided bill is refused as such, ahead of the balance check (which
  -- would otherwise call it an overpayment on a bill that was paid before the void).
  if v_status = 'voided' and not v_refund then
    raise exception 'voided' using hint = 'a voided bill takes no payments; a refund is allowed';
  end if;

  -- v_paid is null when the parent was not found; not_found is raised further down.
  if v_paid is not null and coalesce(v_amount, 0) <> 0 then
    if v_refund then
      if v_paid - abs(v_amount) < 0 then
        raise exception 'refund_exceeds_paid'
          using hint = 'only ' || _rupees(greatest(v_paid, 0)) || ' was collected';
      end if;
    elsif v_amount > 0 and v_billed is not null and v_pay <> 'waived'
          and v_paid + v_amount > v_billed then
      raise exception 'overpayment'
        using hint = case when v_billed - v_paid <= 0 then 'this bill is already paid'
                          else 'only ' || _rupees(v_billed - v_paid) || ' is due' end;
    end if;
  end if;

  -- Amount, sign, refund reason and method.
  if v_amount is null or v_amount = 0 then raise exception 'amount_zero'; end if;
  if v_refund then
    if coalesce(btrim(p->>'reason'), '') = '' then raise exception 'refund_reason_required'; end if;
    v_amount := -abs(v_amount);
  elsif v_amount < 0 then
    raise exception 'amount_negative';
  end if;
  if (p->>'method') not in ('cash','upi','card','other') then raise exception 'invalid_method'; end if;

  -- Record the payment and recompute the parent's payment status (a waived bill
  -- keeps 'waived').
  select status, payment_status, billed_amount_paise into v_status, v_pay, v_billed
    from sessions where id = v_parent and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'session'; end if;
  if v_status = 'voided' and not v_refund then
    raise exception 'voided' using hint = 'a voided bill takes no payments; a refund is allowed';
  end if;
  insert into payments(id, arena_id, session_id, amount_paise, method, kind, note, reason,
      created_by, created_at)
    values ((p->>'payment_id')::uuid, p_arena, v_parent, v_amount, p->>'method',
      case when v_refund then 'refund' else 'payment' end, p->>'note', p->>'reason',
      auth.uid(), v_now);
  if v_pay <> 'waived' and v_status <> 'voided' then
    select coalesce(sum(amount_paise), 0) into v_paid from payments where session_id = v_parent;
    v_pay := _payment_status(v_billed, v_paid);
    update sessions set payment_status = v_pay, updated_at = v_now where id = v_parent;
  end if;
  return jsonb_build_object('payment_status', v_pay);
end;
$function$;

comment on function public.op_payment(uuid, jsonb) is
  'Sync op payment.record: records a payment or refund on a session, refusing overpayment of a final bill or a refund beyond what was paid.';

grant execute on function "public"."op_payment"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_payment"(uuid, jsonb) from public;

revoke all on function "public".op_payment(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_payment(p_arena uuid, p jsonb) from authenticated;
