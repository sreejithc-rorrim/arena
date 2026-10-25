-- op_session_end — sync op 'session.end': end an active single session and store its final bill.
--
-- Permission: bill; plus discount when mark_waived.
-- Payload: session_id, ended_at, billed_amount_paise, mark_waived?, waive_reason?,
--   charge_overtime? (default false: time past the booked end is not billed),
--   end_moved? ({from, reason}: staff set ended_at earlier than `from`, the time they ended it;
--   the reason is required and the move is audited),
--   expected_segment_ids[], expected_scheduled_end_at, charges[] (one row per priced piece),
--   discount? ({id?, discount_id? | code? | manual: {value_kind, value}, reason?, amount_paise}:
--   validated and recorded by _discount_apply; billed = cash-rounded subtotal − discount).
-- Checks / errors: forbidden; time_in_future, time_too_old (_client_time: device time after now + 2 min or
--   over 24 h old); end_reason_required, reason_too_long (end_moved without a reason, or over 500
--   characters); invalid_time (end_moved.from missing or not after ended_at); waive_reason_required; waive_over_limit (below owner level, a
--   write-off above discount_options.manual_max_percent of the bill); not_found; not_active; stale (segments or scheduled end differ
--   from what the device saw); invalid_time; price_mismatch (total or charge rows differ from
--   the server's re-pricing on the frozen snapshot, 0 paise tolerance).
-- Writes: session_segments / controller_allocations (ended), session_charges, sessions
--   (completed, actual_ended_at, billed_amount_paise, payment_status), on a waive an
--   audit_log row (action waive: billed, paid, written off, reason), and on end_moved one
--   (action end_moved: before {ended_at, billed_paise as priced at `from`}, after {ended_at,
--   billed_paise}, reason). Returns: {payment_status}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_session_end (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now timestamptz := statement_timestamp();
  v_session uuid := (p->>'session_id')::uuid;
  v_ended timestamptz := (p->>'ended_at')::timestamptz;
  v_waive boolean := coalesce((p->>'mark_waived')::boolean, false);
  v_billed bigint := (p->>'billed_amount_paise')::bigint;
  v_status text; v_end timestamptz; v_segs uuid[]; v_paid bigint; v_pay text; v_c jsonb;
  v_bill jsonb; v_keys text[]; v_disc bigint := 0; v_total bigint; pol jsonb;
  v_moved boolean := jsonb_typeof(p->'end_moved') = 'object';
  v_from timestamptz := (p->'end_moved'->>'from')::timestamptz;
  v_end_reason text := nullif(btrim(coalesce(p->'end_moved'->>'reason', '')), '');
  v_from_bill bigint;
begin
  perform _need(p_arena, 'bill');
  perform _client_time(p_arena, v_ended, 'ended_at');
  if v_waive then
    perform _need(p_arena, 'discount');
    if nullif(btrim(coalesce(p->>'waive_reason', '')), '') is null then
      raise exception 'waive_reason_required';
    end if;
  end if;
  -- An end set earlier than when staff ended it lowers the bill: it needs a reason and is audited.
  if v_moved then
    if v_end_reason is null then
      raise exception 'end_reason_required' using hint = 'say why the end was moved earlier';
    end if;
    if length(v_end_reason) > 500 then
      raise exception 'reason_too_long' using hint = 'at most 500 characters';
    end if;
    if v_from is null or v_from <= v_ended then
      raise exception 'invalid_time' using hint = 'end_moved.from must be after ended_at';
    end if;
    perform _client_time(p_arena, v_from, 'end_moved.from');
  end if;
  select status, scheduled_end_at into v_status, v_end
    from sessions where id = v_session and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'session'; end if;
  if v_status <> 'active' then raise exception 'not_active' using hint = v_status; end if;
  select coalesce(array_agg(id), '{}') into v_segs from session_segments where session_id = v_session;
  if not _same_ids(v_segs, _jsonb_uuids(p->'expected_segment_ids'))
     or v_end is distinct from (p->>'expected_scheduled_end_at')::timestamptz then
    raise exception 'stale' using hint = 'the session was changed on another device';
  end if;
  -- What the bill would have been at the original end (segments are still open here).
  if v_moved then
    v_from_bill := (_pr_session_bill(v_session, v_from,
      coalesce((p->>'charge_overtime')::boolean, false))->>'total')::bigint;
  end if;

  update session_segments set ended_at = v_ended where session_id = v_session and ended_at is null;
  update controller_allocations set ended_at = v_ended where session_id = v_session and ended_at is null;
  for v_c in select value from jsonb_array_elements(coalesce(p->'charges', '[]'::jsonb)) loop
    insert into session_charges(id, arena_id, session_id, segment_id, segment_index, band_code,
        activity_code, resource_id, controller_count, segment_start, segment_end, played_minutes,
        billed_minutes, unit_minutes, unit_price_paise, amount_paise, created_at)
      values ((v_c->>'id')::uuid, p_arena, v_session, nullif(v_c->>'segment_id','')::uuid,
        (v_c->>'segment_index')::int, v_c->>'band_code', v_c->>'activity_code',
        nullif(v_c->>'resource_id','')::uuid, nullif(v_c->>'controller_count','')::int,
        (v_c->>'segment_start')::timestamptz, (v_c->>'segment_end')::timestamptz,
        (v_c->>'played_minutes')::int, (v_c->>'billed_minutes')::int,
        (v_c->>'unit_minutes')::int, (v_c->>'unit_price_paise')::bigint,
        (v_c->>'amount_paise')::bigint, v_now);
  end loop;
  select coalesce(sum(amount_paise), 0) into v_paid from payments where session_id = v_session;
  v_pay := case when v_waive then 'waived' else _payment_status(v_billed, v_paid) end;
  update sessions set status = 'completed', actual_ended_at = v_ended,
      billed_amount_paise = v_billed, payment_status = v_pay, updated_at = v_now,
      ended_recorded_at = v_now
    where id = v_session;
  -- A waive writes off what was not paid: audited with the amount and the staff reason
  -- (waive_reason, required: waive_reason_required).
  if v_waive then
    insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
        created_by, created_at)
      values (p_arena, 'session', v_session, 'waive',
        nullif(btrim(coalesce(p->>'waive_reason', '')), ''),
        jsonb_build_object('billed_paise', v_billed, 'paid_paise', v_paid),
        jsonb_build_object('written_off_paise', greatest(coalesce(v_billed, 0) - v_paid, 0)),
        auth.uid(), v_now);
  end if;
  if v_moved then
    insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
        created_by, created_at)
      values (p_arena, 'session', v_session, 'end_moved', v_end_reason,
        jsonb_build_object('ended_at', v_from, 'billed_paise', v_from_bill),
        jsonb_build_object('ended_at', v_ended, 'billed_paise', v_billed),
        auth.uid(), v_now);
  end if;

  -- Server-side pricing (0013): re-price the bill from the stored segments and
  -- refuse the op unless the total AND every charge row match exactly.
  if exists (select 1 from session_segments where session_id = v_session and ended_at < started_at) then
    raise exception 'invalid_time' using hint = 'the end is before the current segment started';
  end if;
  v_bill := _pr_session_bill(v_session, v_ended, coalesce((p->>'charge_overtime')::boolean, false));
  v_total := (v_bill->>'total')::bigint;
  -- A discount (preset, coupon or manual) comes off the subtotal before cash rounding.
  if jsonb_typeof(p->'discount') = 'object' then
    if v_waive then raise exception 'invalid_discount' using hint = 'a waived bill takes no discount'; end if;
    v_disc := _discount_apply(p_arena, p->'discount', v_bill, v_ended, v_session);
    select _pr_policy(pricing_snapshot) into pol from sessions where id = v_session;
    v_total := _pr_money((v_bill->>'subtotal')::bigint - v_disc, (pol->>'money_rounding_paise')::int,
      pol->>'money_rounding_dir');
  end if;
  -- Below owner level a waive is capped like a manual discount.
  if v_waive then perform _waive_check(p_arena, v_billed, v_paid); end if;
  if v_total is distinct from v_billed then
    perform _price_mismatch('bill', v_total, v_billed);
  end if;
  select coalesce(array_agg(k order by k), '{}') into v_keys from (
    select _pr_charge_key(activity_code, resource_id, controller_count, band_code, segment_start,
      segment_end, played_minutes, billed_minutes, unit_minutes, unit_price_paise, amount_paise) k
      from session_charges where session_id = v_session) t;
  if v_keys <> array(select jsonb_array_elements_text(v_bill->'keys')) then
    raise exception 'price_mismatch' using hint = 'charge rows differ from the server''s bill';
  end if;
  return jsonb_build_object('payment_status', v_pay);
end;
$function$;

grant execute on function "public"."op_session_end"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_session_end"(uuid, jsonb) from public;

revoke all on function "public".op_session_end(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_session_end(p_arena uuid, p jsonb) from authenticated;
