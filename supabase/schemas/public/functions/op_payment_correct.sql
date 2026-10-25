-- op_payment_correct — sync op 'payment.correct': move all or part of a recorded payment to the
--   method it was really taken by (cash keyed in as UPI, …), without rewriting history.
--
-- Permission: money (an owner passes). Floor staff cannot correct recorded money.
-- Payload: scope ('single', the default and only value), parent_id (session id), payment_id (the
--   payment being corrected), method (the right method), amount_paise? (default: what is still
--   left to move of that payment), reason (required: 1–500 characters after trimming),
--   refund_id?, new_payment_id? (ids of the two rows written; generated when absent).
-- Checks / errors: forbidden; invalid_payload (hint scope: any scope but 'single');
--   reason_required; reason_too_long; invalid_method; not_found (hint session / payment); not_a_payment (a refund row cannot be moved); same_method;
--   already_corrected (all of that payment was moved before); amount_invalid (not above zero,
--   or more than is left to move); duplicate (an id reused).
-- Writes, in one transaction: a refund on the old method (−amount) and a payment on the new
--   method (+amount) in payments, both carrying the reason and the note
--   'Method correction'; an audit_log row (action payment_correct, before {payment_id, method,
--   amount_paise}, after {method, amount_paise, refund_id, payment_id}). The bill's net, its
--   payment status and the takings do not change; only the per-method split does. Allowed on
--   any bill status (money collected on a voided bill is corrected the same way).
-- Returns: {moved_paise, refund_id, payment_id}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_payment_correct (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now       timestamptz := statement_timestamp();
  v_parent    uuid := (p->>'parent_id')::uuid;
  v_payment   uuid := (p->>'payment_id')::uuid;
  v_method    text := p->>'method';
  v_reason    text := nullif(btrim(coalesce(p->>'reason', '')), '');
  v_refund_id uuid := coalesce(nullif(p->>'refund_id', '')::uuid, gen_random_uuid());
  v_new_id    uuid := coalesce(nullif(p->>'new_payment_id', '')::uuid, gen_random_uuid());
  v_old_method text; v_old_amount bigint; v_was_refund boolean;
  v_moved bigint; v_left bigint; v_amount bigint;
begin
  perform _need(p_arena, 'money');
  if coalesce(p->>'scope', 'single') <> 'single' then
    raise exception 'invalid_payload' using hint = 'scope';
  end if;
  if v_reason is null then
    raise exception 'reason_required' using hint = 'say what was recorded wrongly';
  end if;
  if length(v_reason) > 500 then raise exception 'reason_too_long' using hint = 'at most 500 characters'; end if;
  if v_method is null or v_method not in ('cash', 'upi', 'card', 'other') then
    raise exception 'invalid_method';
  end if;

  -- Lock the bill (as op_payment does), so payments and corrections on it queue here.
  perform 1 from sessions where id = v_parent and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'session'; end if;
  select method, amount_paise, kind = 'refund' into v_old_method, v_old_amount, v_was_refund
    from payments where id = v_payment and session_id = v_parent and arena_id = p_arena;
  if not found then raise exception 'not_found' using hint = 'payment'; end if;
  if v_was_refund then
    raise exception 'not_a_payment' using hint = 'only a payment can be moved to another method';
  end if;
  if v_method = v_old_method then
    raise exception 'same_method' using hint = 'that payment is already recorded as ' || v_old_method;
  end if;

  -- What earlier corrections already moved out of this payment.
  select coalesce(sum((after->>'amount_paise')::bigint), 0) into v_moved
    from audit_log
   where arena_id = p_arena and entity_type = 'session' and entity_id = v_parent
     and action = 'payment_correct' and before->>'payment_id' = v_payment::text;
  v_left := v_old_amount - v_moved;
  if v_left <= 0 then
    raise exception 'already_corrected' using hint = 'all of this payment was already moved';
  end if;
  v_amount := coalesce((p->>'amount_paise')::bigint, v_left);
  if v_amount <= 0 or v_amount > v_left then
    raise exception 'amount_invalid' using hint = 'at most ' || _rupees(v_left) || ' can be moved';
  end if;

  insert into payments(id, arena_id, session_id, amount_paise, method, kind, note, reason,
      created_by, created_at)
    values
      (v_refund_id, p_arena, v_parent, -v_amount, v_old_method, 'refund', 'Method correction',
        v_reason, auth.uid(), v_now),
      (v_new_id, p_arena, v_parent, v_amount, v_method, 'payment', 'Method correction',
        v_reason, auth.uid(), v_now);

  insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
      created_by, created_at)
    values (p_arena, 'session', v_parent, 'payment_correct', v_reason,
      jsonb_build_object('payment_id', v_payment, 'method', v_old_method,
        'amount_paise', v_old_amount),
      jsonb_build_object('method', v_method, 'amount_paise', v_amount,
        'refund_id', v_refund_id, 'payment_id', v_new_id),
      auth.uid(), v_now);
  return jsonb_build_object('moved_paise', v_amount, 'refund_id', v_refund_id,
    'payment_id', v_new_id);
end;
$function$;

comment on function public.op_payment_correct(uuid, jsonb) is
  'Sync op payment.correct: moves all or part of a recorded payment to another method (money permission, reason required) as an append-only refund + payment pair, audited; the bill''s net never changes.';

grant execute on function "public"."op_payment_correct"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_payment_correct"(uuid, jsonb) from public;

revoke all on function "public".op_payment_correct(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_payment_correct(p_arena uuid, p jsonb) from authenticated;
