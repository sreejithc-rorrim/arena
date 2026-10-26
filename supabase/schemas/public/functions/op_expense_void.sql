-- op_expense_void — sync op 'expense.void': cancel an expense recorded by mistake, audited.
--
-- Permission: money.
-- Payload: expense_id, reason (required: 1–500 characters after trimming),
--   reverse_payments (true to also reverse what was paid toward it).
-- The row stays (status 'voided', void_reason) and counts in no total. An expense with
--   payments is voided only with reverse_payments: each payment gets a reversal keeping its
--   source and payer (_expense_reverse), so the cash totals move back too. Idempotent: an
--   expense already voided keeps its first reason and returns {status: 'voided'}.
-- Checks / errors: forbidden; void_reason_required; reason_too_long; not_found (hint expense);
--   the person checks of _expense_staff_check; expense_has_payments.
-- Writes: the reversals; the expense (status, void_reason, payment_status 'unpaid'); an audit_log
--   row (entity expense, action void, reason, before {amount_paise, paid_paise, payment_status},
--   after {status, reversed_payments}). Returns: {status, reversed}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_expense_void (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now     timestamptz := statement_timestamp();
  v_id      uuid := nullif(p->>'expense_id', '')::uuid;
  v_reason  text := nullif(btrim(coalesce(p->>'reason', '')), '');
  v_reverse boolean := coalesce((p->>'reverse_payments')::boolean, false);
  v_e       expenses%rowtype;
  v_paid    bigint;
  v_n       int := 0;
  r         record;
begin
  perform _need(p_arena, 'money');
  if v_reason is null then raise exception 'void_reason_required' using hint = 'say why the expense is voided'; end if;
  if length(v_reason) > 500 then raise exception 'reason_too_long' using hint = 'at most 500 characters'; end if;
  select * into v_e from expenses where id = v_id and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'expense'; end if;
  if v_e.status = 'voided' then return jsonb_build_object('status', 'voided', 'reversed', 0); end if;
  if v_e.staff_id is not null then perform _expense_staff_check(p_arena, v_e.staff_id, false); end if;

  select coalesce(sum(amount_paise), 0) into v_paid from expense_payments where expense_id = v_id;
  if v_paid <> 0 and not v_reverse then
    raise exception 'expense_has_payments'
      using hint = _rupees(v_paid) || ' is recorded as paid: reverse it with the void';
  end if;
  for r in select p.id from expense_payments p
            where p.expense_id = v_id and p.kind = 'payment'
              and not exists (select 1 from expense_payments x where x.reverses_id = p.id)
            order by p.created_at, p.id loop
    perform _expense_reverse(p_arena, r.id, gen_random_uuid(), v_reason);
    v_n := v_n + 1;
  end loop;

  update expenses set status = 'voided', void_reason = v_reason, payment_status = 'unpaid',
      updated_at = v_now
    where id = v_id;
  insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
      created_by, created_at)
    values (p_arena, 'expense', v_id, 'void', v_reason,
      jsonb_build_object('amount_paise', v_e.amount_paise, 'paid_paise', v_paid,
        'payment_status', v_e.payment_status),
      jsonb_build_object('status', 'voided', 'reversed_payments', v_n), auth.uid(), v_now);
  return jsonb_build_object('status', 'voided', 'reversed', v_n);
end;
$function$;

comment on function public.op_expense_void(uuid, jsonb) is
  'Sync op expense.void (money): cancels an expense (reason required), reversing its payments with their sources when asked; audited; the row stays.';

grant execute on function "public"."op_expense_void"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_expense_void"(uuid, jsonb) from public;

revoke all on function "public"."op_expense_void"(uuid, jsonb) from anon;

revoke all on function "public"."op_expense_void"(uuid, jsonb) from authenticated;
