-- op_session_record — sync op 'session.record': add a single session that was played but never
--   started in the app (a missed bill), already ended, priced and paid in full.
--
-- Permission: bill_record (an owner passes). The caller is the session's created_by, so it is
--   theirs to edit later with bill_edit (bill.adjust).
-- Payload: session_id, payment_id (client uuids: a resend replays), customer_id, resource_id,
--   activity_code, game_id?, controller_count?, started_at, ended_at (any past date, at most
--   24 h long), method (cash | upi | card | other), billed_amount_paise (the total the caller
--   was shown: session_quote), reason (required: 1–500 characters after trimming).
-- Pricing: the arena's CURRENT price list (_pricing_snapshot; older lists are not kept), frozen on
--   the session like a normal start; the whole played time is billed (no booked end to stop at);
--   charge rows are built from the server's own quote.
-- Checks / errors: forbidden; reason_required; reason_too_long; invalid_payload; invalid_method;
--   time_in_future; invalid_time (end not after start, or over 24 h); not_found (customer /
--   station / game); activity_not_offered; no_rate; overlap (the station has a session
--   recorded in that time); price_mismatch (the total differs from the server's).
-- Writes, in one transaction: sessions (completed; scheduled end = actual end; ended_recorded_at
--   = now), one closed session_segments row, session_charges, one payments row for the total
--   (note 'Added later', the reason) when it is above 0, payment_status 'paid', and an audit_log
--   row (action record). No controllers are allocated: pads are not tracked for the past.
--   Returns: {session_id, billed_amount_paise, payment_status}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_session_record (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now      timestamptz := statement_timestamp();
  v_id       uuid := (p->>'session_id')::uuid;
  v_pay_id   uuid := (p->>'payment_id')::uuid;
  v_customer uuid := (p->>'customer_id')::uuid;
  v_res      uuid := (p->>'resource_id')::uuid;
  v_act      text := p->>'activity_code';
  v_game     uuid := nullif(p->>'game_id', '')::uuid;
  v_cc       integer := nullif(p->>'controller_count', '')::int;
  v_start    timestamptz := (p->>'started_at')::timestamptz;
  v_end      timestamptz := (p->>'ended_at')::timestamptz;
  v_method   text := p->>'method';
  v_billed   bigint := (p->>'billed_amount_paise')::bigint;
  v_reason   text := nullif(btrim(coalesce(p->>'reason', '')), '');
  v_snap jsonb; v_seg uuid := gen_random_uuid(); q jsonb; l jsonb; v_bill jsonb;
  v_total bigint; v_pay text;
begin
  perform _need(p_arena, 'bill_record');
  if v_reason is null then
    raise exception 'reason_required' using hint = 'say why the bill is added later';
  end if;
  if length(v_reason) > 500 then raise exception 'reason_too_long' using hint = 'at most 500 characters'; end if;
  if v_id is null or v_pay_id is null or v_customer is null or v_res is null or v_act is null
     or v_start is null or v_end is null or v_billed is null or v_billed < 0
     or (v_cc is not null and v_cc not between 1 and 4) then
    raise exception 'invalid_payload';
  end if;
  if v_method is null or v_method not in ('cash', 'upi', 'card', 'other') then
    raise exception 'invalid_method' using hint = 'how the bill was paid';
  end if;
  if v_end > v_now + interval '2 minutes' then
    raise exception 'time_in_future' using hint = 'ended_at';
  end if;
  if v_end <= v_start or v_end - v_start > interval '24 hours' then
    raise exception 'invalid_time' using hint = 'the end must be after the start, at most 24 h later';
  end if;
  if not exists (select 1 from customers where id = v_customer and arena_id = p_arena) then
    raise exception 'not_found' using hint = 'customer';
  end if;
  -- Lock the station so two missed bills for the same time cannot both pass the overlap check.
  perform 1 from resources where id = v_res and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'station'; end if;
  if v_game is not null and not exists (select 1 from games where id = v_game and arena_id = p_arena) then
    raise exception 'not_found' using hint = 'game';
  end if;
  if exists (select 1 from session_segments
              where resource_id = v_res and arena_id = p_arena
                and tstzrange(started_at, coalesce(ended_at, 'infinity')) && tstzrange(v_start, v_end)) then
    raise exception 'overlap' using hint = 'the station already has play recorded in that time';
  end if;

  v_snap := _pricing_snapshot(p_arena);
  perform _seg_priced(p_arena, v_res, v_snap, v_act, v_cc);

  insert into sessions(id, arena_id, customer_id, status, payment_status, started_at,
      scheduled_end_at, actual_ended_at, pricing_snapshot, policy_snapshot, billed_amount_paise,
      created_at, updated_at, created_by, ended_recorded_at)
    values (v_id, p_arena, v_customer, 'completed', 'unpaid', v_start, v_end, v_end, v_snap,
      v_snap->'policy', v_billed, v_now, v_now, auth.uid(), v_now);
  insert into session_segments(id, arena_id, session_id, idx, resource_id, activity_code, game_id,
      controller_count, started_at, ended_at, created_at)
    values (v_seg, p_arena, v_id, 0, v_res, v_act, v_game, v_cc, v_start, v_end, v_now);

  -- Charge rows straight from the server's quote (the same lines _pr_session_bill keys).
  q := _pr_quote(v_snap, v_act, v_cc, v_start, v_end, v_start);
  for l in select value from jsonb_array_elements(coalesce(q->'lines', '[]'::jsonb)) loop
    insert into session_charges(id, arena_id, session_id, segment_id, segment_index, band_code,
        activity_code, resource_id, controller_count, segment_start, segment_end, played_minutes,
        billed_minutes, unit_minutes, unit_price_paise, amount_paise, created_at)
      values (gen_random_uuid(), p_arena, v_id, v_seg, 0, l->>'band', v_act, v_res, v_cc,
        (l->>'start')::timestamptz, (l->>'end')::timestamptz,
        ((l->>'played_seconds')::bigint / 60)::int, (l->>'billed_minutes')::int,
        (l->>'unit_minutes')::int, (l->>'unit_price')::bigint, (l->>'amount')::bigint, v_now);
  end loop;
  v_bill := _pr_session_bill(v_id, v_end, true);
  v_total := (v_bill->>'total')::bigint;
  if v_total is distinct from v_billed then
    perform _price_mismatch('bill', v_total, v_billed);
  end if;

  if v_total > 0 then
    insert into payments(id, arena_id, session_id, amount_paise, method, kind, note, reason,
        created_by, created_at)
      values (v_pay_id, p_arena, v_id, v_total, v_method, 'payment', 'Added later', v_reason,
        auth.uid(), v_now);
  end if;
  v_pay := _payment_status(v_total, v_total);
  update sessions set payment_status = v_pay where id = v_id;

  update customers set last_visit_at = greatest(coalesce(last_visit_at, v_start), v_start)
    where id = v_customer;
  if v_game is not null then
    update games set last_played_at = greatest(coalesce(last_played_at, v_start), v_start)
      where id = v_game;
  end if;

  insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
      created_by, created_at)
    values (p_arena, 'session', v_id, 'record', v_reason, null,
      jsonb_build_object('billed_paise', v_total, 'method', v_method, 'resource_id', v_res,
        'started_at', v_start, 'ended_at', v_end),
      auth.uid(), v_now);
  return jsonb_build_object('session_id', v_id, 'billed_amount_paise', v_total,
    'payment_status', v_pay);
end;
$function$;

comment on function public.op_session_record(uuid, jsonb) is
  'Sync op session.record: add a missed single session after the fact (bill_record), already ended, priced on the current price list and paid in full; overlap-checked against the station''s recorded play; audited with the required reason.';

grant execute on function "public"."op_session_record"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_session_record"(uuid, jsonb) from public;

revoke all on function "public".op_session_record(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_session_record(p_arena uuid, p jsonb) from authenticated;
