-- sync_push(arena, ops, device) — apply a batch of device outbox ops, each exactly once
--
-- Lives in `private`, which the Data API does not expose: SECURITY DEFINER
-- code never sits in an API schema. Clients reach it only through the
-- SECURITY INVOKER wrapper public.sync_push.
--
-- p_ops = [{op_id, kind, payload}], applied in order. An op_id already in
-- sync_ops returns its stored outcome (replayed=true); otherwise _sync_apply
-- runs it in its own subtransaction and the outcome is recorded in sync_ops
-- ('applied' + result, or 'rejected' + error code/detail). A transient SQLSTATE
-- (lock / serialization 40xxx, 55P03, connection 08xxx, resources 53xxx,
-- internal XXxxx) yields status 'retry', is not recorded, and stops the batch so
-- order is kept: a resend can still apply it. An op whose op_id is not a uuid
-- (invalid_op_id) or belongs to another arena or op kind (op_id_reused) is refused on its
-- own, unrecorded, without aborting the rest. At most 200 ops per call
-- (batch_too_large, 54000). A statement timeout still aborts the whole call
-- (PL/pgSQL cannot catch it safely): devices halve their batch and resend.
-- Returns {results: [{op_id, status, result|error, detail, replayed}], server_time}.
-- SECURITY DEFINER; gate: active member of p_arena, else 'forbidden'. op_* check perms.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.sync_push (
  p_arena  uuid,
  p_ops    jsonb,
  p_device text  default null::text
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_op jsonb; v_id uuid; v_kind text; v_prev sync_ops; v_res jsonb;
  v_out jsonb := '[]'::jsonb;
  v_state text; v_msg text; v_hint text; v_code text;
begin
  -- `not in` is NULL (not true) for a null arena, so test membership explicitly.
  if auth.uid() is null or p_arena is null
     or not exists (select 1 from private.app_arena_ids() a where a = p_arena) then
    raise exception 'forbidden' using errcode = '42501', hint = 'not an active member of this arena';
  end if;
  if jsonb_typeof(p_ops) = 'array' and jsonb_array_length(p_ops) > 200 then
    raise exception 'batch_too_large' using errcode = '54000', hint = 'at most 200 ops per push';
  end if;
  for v_op in select value from jsonb_array_elements(coalesce(p_ops, '[]'::jsonb)) loop
    v_kind := v_op->>'kind';
    if coalesce(v_op->>'op_id', '')
         !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      v_out := v_out || jsonb_build_array(jsonb_build_object('op_id', v_op->'op_id',
        'status', 'rejected', 'error', 'invalid_op_id', 'replayed', false));
      continue;
    end if;
    v_id := (v_op->>'op_id')::uuid;
    -- Two pushes of the same op (a retry racing the original) queue here.
    perform pg_advisory_xact_lock(hashtextextended(v_id::text, 0));
    select * into v_prev from sync_ops where op_id = v_id;
    if found then
      if v_prev.arena_id <> p_arena or v_prev.kind <> coalesce(v_kind, '?') then
        v_out := v_out || jsonb_build_array(jsonb_build_object('op_id', v_id,
          'status', 'rejected', 'error', 'op_id_reused', 'replayed', false));
        continue;
      end if;
      v_out := v_out || jsonb_build_array(jsonb_build_object('op_id', v_id,
        'status', v_prev.status, 'result', v_prev.result, 'error', v_prev.error_code,
        'detail', v_prev.error_message, 'replayed', true));
      continue;
    end if;
    begin
      v_res := _sync_apply(p_arena, v_kind, coalesce(v_op->'payload', '{}'::jsonb));
      if v_res is null then raise exception 'unknown_op' using hint = coalesce(v_kind, 'null'); end if;
      -- Configuration and permission ops keep what they asked for (audit).
      insert into sync_ops(op_id, arena_id, user_id, device_id, kind, status, result, payload)
        values (v_id, p_arena, auth.uid(), p_device, v_kind, 'applied', v_res,
          case when split_part(v_kind, '.', 1) in ('staff', 'arena', 'activity', 'resource', 'rate',
                 'policy', 'settings', 'holiday', 'rule', 'discount')
               then v_op->'payload' end);
      v_out := v_out || jsonb_build_array(jsonb_build_object('op_id', v_id,
        'status', 'applied', 'result', v_res, 'replayed', false));
    exception when others then
      get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text,
        v_hint = pg_exception_hint;
      -- Transient (serialization failure, deadlock, lock not available, query
      -- cancelled, connection, out of resources, internal): not recorded, so the
      -- device resends this op and the rest later.
      if left(v_state, 2) in ('40', '08', '53', 'XX') or v_state in ('55P03', '57014') then
        v_out := v_out || jsonb_build_array(jsonb_build_object('op_id', v_id,
          'status', 'retry', 'error', v_state));
        exit;
      end if;
      -- Stable error code for the device: a plain `raise exception '<code>'`
      -- (P0001) passes its message through; known SQLSTATEs are mapped.
      v_code := case
        when v_state = '42501' then 'forbidden'
        when v_state = '23505' then 'duplicate'
        when v_state = '23503' then 'missing_reference'
        when v_state in ('23514', '23502') then 'invalid'
        when v_state like '22%' then 'invalid_payload'
        when v_state = 'P0001' then v_msg
        else 'server_error' end;
      insert into sync_ops(op_id, arena_id, user_id, device_id, kind, status, error_code, error_message)
        values (v_id, p_arena, auth.uid(), p_device, coalesce(v_kind, '?'), 'rejected', v_code,
          coalesce(v_hint, v_msg));
      v_out := v_out || jsonb_build_array(jsonb_build_object('op_id', v_id,
        'status', 'rejected', 'error', v_code, 'detail', coalesce(v_hint, v_msg), 'replayed', false));
    end;
  end loop;
  return jsonb_build_object('results', v_out, 'server_time', clock_timestamp());
end;
$function$;

comment on function private.sync_push(uuid, jsonb, text) is 'Client API (sync): apply a batch of device ops in order, each at most once per op_id (recorded in sync_ops), and return each op''s status: applied, rejected (with error code) or retry.';

grant execute
  on function "private"."sync_push"(uuid, jsonb, text)
  to "authenticated", "postgres", "service_role";

revoke all on function "private"."sync_push"(uuid, jsonb, text) from public;

revoke all on function "private".sync_push(p_arena uuid, p_ops jsonb, p_device text) from anon;
