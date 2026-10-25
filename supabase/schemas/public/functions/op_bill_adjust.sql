-- op_bill_adjust — sync op 'bill.adjust': set a closed bill's total and make what was collected
--   match it, audited.
--
-- Permission: money (an owner passes), or bill_edit for a bill the caller started (the
--   session's created_by); anyone else is refused (forbidden, hint 'not your bill').
-- Payload: scope ('single', the default and only value), parent_id (session id),
--   billed_amount_paise (the new total: whole paise, 0 or more), reason (required: 1–500
--   characters after trimming), method (cash | upi | card | other: how the difference was paid
--   or given back; needed when collected differs from the new total), payment_id? (id of that
--   row; generated when absent), expected_billed_paise and expected_paid_paise (the total and
--   net collected the caller saw: the difference is only recorded against those).
-- Checks / errors: forbidden (incl. 'not your bill'); invalid_payload (hint scope: any scope but
--   'single'); reason_required; reason_too_long; invalid_total (missing or
--   negative); invalid_method; not_found (hint session); not_ended (still running);
--   voided; waived (a waived bill owes nothing); stale (the bill's total or collected differs
--   from expected_*, e.g. a payment landed meanwhile; missing expected_* is stale too);
--   same_total (that total, already collected).
-- Writes, in one transaction: billed_amount_paise; when collected ≠ the new total, one ledger row
--   for the difference (a payment, or a refund carrying the reason; note 'Bill edited'); payment
--   status 'paid'; an audit_log row (action bill_adjust, before {billed_paise, paid_paise}, after
--   {billed_paise, paid_paise}). The priced charge rows and earlier payments are never touched.
--   Returns: {payment_status}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_bill_adjust (
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
  v_parent uuid := (p->>'parent_id')::uuid;
  v_new    bigint := (p->>'billed_amount_paise')::bigint;
  v_reason text := nullif(btrim(coalesce(p->>'reason', '')), '');
  v_method text := p->>'method';
  v_pay_id uuid := coalesce(nullif(p->>'payment_id', '')::uuid, gen_random_uuid());
  v_status text; v_pay text; v_old bigint; v_paid bigint; v_diff bigint;
  v_by     uuid;
  v_money  boolean := private.app_has_perm(p_arena, 'money');
begin
  if not v_money then perform _need(p_arena, 'bill_edit'); end if;
  if coalesce(p->>'scope', 'single') <> 'single' then
    raise exception 'invalid_payload' using hint = 'scope';
  end if;
  if v_reason is null then
    raise exception 'reason_required' using hint = 'say why the bill changes';
  end if;
  if length(v_reason) > 500 then raise exception 'reason_too_long' using hint = 'at most 500 characters'; end if;
  if v_new is null or v_new < 0 then
    raise exception 'invalid_total' using hint = 'the new total in whole paise, 0 or more';
  end if;

  -- Lock the bill (as op_payment does), so payments on it queue behind the change.
  select status, payment_status, billed_amount_paise, created_by into v_status, v_pay, v_old, v_by
    from sessions where id = v_parent and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'session'; end if;
  select coalesce(sum(amount_paise), 0) into v_paid from payments where session_id = v_parent;
  if not v_money and v_by is distinct from auth.uid() then
    raise exception 'forbidden' using errcode = '42501', hint = 'not your bill';
  end if;
  if v_status = 'voided' then raise exception 'voided' using hint = 'a voided bill has no total'; end if;
  if v_status <> 'completed' or v_old is null then
    raise exception 'not_ended' using hint = 'end the session first';
  end if;
  if v_pay = 'waived' then raise exception 'waived' using hint = 'a waived bill owes nothing'; end if;
  -- The difference is settled against what the caller saw, never against a payment or edit
  -- that landed since (it would turn into a refund nobody gave, or refuse real money).
  if v_old is distinct from (p->>'expected_billed_paise')::bigint
     or v_paid is distinct from (p->>'expected_paid_paise')::bigint then
    raise exception 'stale' using hint = 'the bill changed since it was loaded: reload it';
  end if;
  if v_new = v_old and v_paid = v_new then
    raise exception 'same_total' using hint = 'the bill is already that amount and paid';
  end if;

  -- What the bill says is what was collected: the difference goes in (or back) now.
  v_diff := v_new - v_paid;
  if v_diff <> 0 then
    if v_method is null or v_method not in ('cash', 'upi', 'card', 'other') then
      raise exception 'invalid_method' using hint = 'how the difference was paid or given back';
    end if;
    insert into payments(id, arena_id, session_id, amount_paise, method, kind, note, reason,
        created_by, created_at)
      values (v_pay_id, p_arena, v_parent, v_diff, v_method,
        case when v_diff < 0 then 'refund' else 'payment' end, 'Bill edited',
        v_reason, auth.uid(), v_now);
  end if;
  update sessions set billed_amount_paise = v_new, payment_status = 'paid', updated_at = v_now
    where id = v_parent;
  insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
      created_by, created_at)
    values (p_arena, 'session', v_parent, 'bill_adjust', v_reason,
      jsonb_build_object('billed_paise', v_old, 'paid_paise', v_paid),
      jsonb_build_object('billed_paise', v_new, 'paid_paise', v_new), auth.uid(), v_now);
  return jsonb_build_object('payment_status', 'paid');
end;
$function$;

comment on function public.op_bill_adjust(uuid, jsonb) is
  'Sync op bill.adjust: sets a closed bill''s total (money permission, or bill_edit on a bill the caller started; reason required) and records the difference as a payment or refund so collected matches it; audited; charges untouched.';

grant execute on function "public"."op_bill_adjust"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_bill_adjust"(uuid, jsonb) from public;

revoke all on function "public".op_bill_adjust(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_bill_adjust(p_arena uuid, p jsonb) from authenticated;
