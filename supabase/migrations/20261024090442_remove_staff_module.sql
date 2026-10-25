set local check_function_bodies = off;

alter table "public"."attendance_entries"
  drop constraint "attendance_entries_arena_id_fkey";

alter table "public"."attendance_entries"
  drop constraint "attendance_entries_created_by_fkey";

alter table "public"."attendance_entries"
  drop constraint "attendance_entries_in_punch_id_fkey";

alter table "public"."attendance_entries"
  drop constraint "attendance_entries_out_punch_id_fkey";

alter table "public"."attendance_entries"
  drop constraint "attendance_entries_replaces_id_fkey";

alter table "public"."attendance_entries"
  drop constraint "attendance_entries_staff_id_fkey";

alter table "public"."attendance_punches"
  drop constraint "attendance_punches_arena_id_fkey";

alter table "public"."attendance_punches"
  drop constraint "attendance_punches_created_by_fkey";

alter table "public"."attendance_punches"
  drop constraint "attendance_punches_staff_id_fkey";

alter table "public"."attendance_requests"
  drop constraint "attendance_requests_arena_id_fkey";

alter table "public"."attendance_requests"
  drop constraint "attendance_requests_created_by_fkey";

alter table "public"."attendance_requests"
  drop constraint "attendance_requests_decided_by_fkey";

alter table "public"."attendance_requests"
  drop constraint "attendance_requests_entry_id_fkey";

alter table "public"."attendance_requests"
  drop constraint "attendance_requests_result_entry_id_fkey";

alter table "public"."attendance_requests"
  drop constraint "attendance_requests_staff_id_fkey";

alter table "public"."leave_adjustments"
  drop constraint "leave_adjustments_arena_id_fkey";

alter table "public"."leave_adjustments"
  drop constraint "leave_adjustments_created_by_fkey";

alter table "public"."leave_adjustments"
  drop constraint "leave_adjustments_staff_id_fkey";

alter table "public"."leave_requests"
  drop constraint "leave_requests_arena_id_fkey";

alter table "public"."leave_requests"
  drop constraint "leave_requests_created_by_fkey";

alter table "public"."leave_requests"
  drop constraint "leave_requests_decided_by_fkey";

alter table "public"."leave_requests"
  drop constraint "leave_requests_staff_id_fkey";

alter table "public"."pay_policies"
  drop constraint "pay_policies_arena_id_fkey";

alter table "public"."pay_policies"
  drop constraint "pay_policies_created_by_fkey";

alter table "public"."salary_adjustments"
  drop constraint "salary_adjustments_arena_id_fkey";

alter table "public"."salary_adjustments"
  drop constraint "salary_adjustments_created_by_fkey";

alter table "public"."salary_adjustments"
  drop constraint "salary_adjustments_reverses_id_fkey";

alter table "public"."salary_adjustments"
  drop constraint "salary_adjustments_run_id_fkey";

alter table "public"."salary_adjustments"
  drop constraint "salary_adjustments_staff_id_fkey";

alter table "public"."salary_deduction_decisions"
  drop constraint "salary_deduction_decisions_arena_id_fkey";

alter table "public"."salary_deduction_decisions"
  drop constraint "salary_deduction_decisions_decided_by_fkey";

alter table "public"."salary_deduction_decisions"
  drop constraint "salary_deduction_decisions_run_id_fkey";

alter table "public"."salary_deduction_decisions"
  drop constraint "salary_deduction_decisions_staff_id_fkey";

alter table "public"."salary_run_lines"
  drop constraint "salary_run_lines_arena_id_fkey";

alter table "public"."salary_run_lines"
  drop constraint "salary_run_lines_run_id_fkey";

alter table "public"."salary_run_lines"
  drop constraint "salary_run_lines_staff_id_fkey";

alter table "public"."salary_runs"
  drop constraint "salary_runs_arena_id_fkey";

alter table "public"."salary_runs"
  drop constraint "salary_runs_created_by_fkey";

alter table "public"."salary_runs"
  drop constraint "salary_runs_finalised_by_fkey";

alter table "public"."shifts"
  drop constraint "shifts_arena_id_fkey";

alter table "public"."staff_holidays"
  drop constraint "staff_holidays_arena_id_fkey";

alter table "public"."staff_hr_profiles"
  drop constraint "staff_hr_profiles_arena_id_fkey";

alter table "public"."staff_hr_profiles"
  drop constraint "staff_hr_profiles_staff_id_fkey";

alter table "public"."staff_pay_rates"
  drop constraint "staff_pay_rates_arena_id_fkey";

alter table "public"."staff_pay_rates"
  drop constraint "staff_pay_rates_created_by_fkey";

alter table "public"."staff_pay_rates"
  drop constraint "staff_pay_rates_staff_id_fkey";

alter table "public"."staff_shifts"
  drop constraint "staff_shifts_arena_id_fkey";

alter table "public"."staff_shifts"
  drop constraint "staff_shifts_shift_id_fkey";

alter table "public"."staff_shifts"
  drop constraint "staff_shifts_staff_id_fkey";

drop function "private"."attendance_days"(uuid, date, date, uuid);

drop function "private"."leave_balances"(uuid, uuid);

drop function "public"."_att_blocks"(uuid, date);

drop function "public"."_att_close_stale"(uuid, uuid, timestamp with time zone);

drop function "public"."_att_close_time"(uuid, date, timestamp with time zone);

drop function "public"."_att_day"(uuid, date, timestamp with time zone);

drop function "public"."_att_work_date"(uuid, timestamp with time zone);

drop function "public"."_attendance_rules"(uuid);

drop function "public"."_attendance_settings"(jsonb);

drop function
  "public"."_geo_distance_m"(double precision, double precision, double precision, double precision);

drop function "public"."_leave_balance"(uuid, date);

drop function "public"."_leave_rules"(uuid);

drop function "public"."_leave_rules_settings"(jsonb);

drop function "public"."_leave_working_days"(uuid, date, date, text);

drop function "public"."_leave_year_start"(uuid, date);

drop function "public"."_own_record"(uuid, uuid);

drop function "public"."_pay_build_line"(uuid, uuid);

drop function "public"."_pay_draft"(uuid, uuid);

drop function "public"."_pay_policy"(uuid, date);

drop function "public"."_pay_policy_settings"(jsonb);

drop function "public"."_pay_rebuild_run"(uuid, uuid);

drop function "public"."_period_finalised"(uuid, date, date);

drop function "public"."_staff_hr"(uuid);

drop function "public"."_work_hours"(uuid);

drop function "public"."_work_hours_settings"(jsonb);

drop function "public"."attendance_days"(uuid, date, date, uuid);

drop function "public"."leave_balances"(uuid, uuid);

drop function "public"."op_attendance_correct"(uuid, jsonb);

drop function "public"."op_attendance_punch"(uuid, jsonb);

drop function "public"."op_attendance_request"(uuid, jsonb);

drop function "public"."op_attendance_request_decide"(uuid, jsonb);

drop function "public"."op_attendance_review"(uuid, jsonb);

drop function "public"."op_hr_profile_save"(uuid, jsonb);

drop function "public"."op_leave_adjust"(uuid, jsonb);

drop function "public"."op_leave_cancel"(uuid, jsonb);

drop function "public"."op_leave_decide"(uuid, jsonb);

drop function "public"."op_leave_record"(uuid, jsonb);

drop function "public"."op_leave_request"(uuid, jsonb);

drop function "public"."op_pay_policy_add"(uuid, jsonb);

drop function "public"."op_pay_rate_add"(uuid, jsonb);

drop function "public"."op_salary_adjustment_add"(uuid, jsonb);

drop function "public"."op_salary_adjustment_reverse"(uuid, jsonb);

drop function "public"."op_salary_run_create"(uuid, jsonb);

drop function "public"."op_salary_run_discard"(uuid, jsonb);

drop function "public"."op_salary_run_finalise"(uuid, jsonb);

drop function "public"."op_salary_run_recalculate"(uuid, jsonb);

drop function "public"."op_salary_run_set_deduction"(uuid, jsonb);

drop function "public"."op_shift_assign"(uuid, jsonb);

drop function "public"."op_shift_unassign"(uuid, jsonb);

drop function "public"."op_shift_upsert"(uuid, jsonb);

drop function "public"."op_staff_holiday_delete"(uuid, jsonb);

drop function "public"."op_staff_holiday_upsert"(uuid, jsonb);

drop table "public"."attendance_entries";

drop table "public"."attendance_punches";

drop table "public"."attendance_requests";

drop table "public"."leave_adjustments";

drop table "public"."leave_requests";

drop table "public"."pay_policies";

drop table "public"."salary_adjustments";

drop table "public"."salary_deduction_decisions";

drop table "public"."salary_run_lines";

drop table "public"."salary_runs";

drop table "public"."shifts";

drop table "public"."staff_holidays";

drop table "public"."staff_hr_profiles";

drop table "public"."staff_pay_rates";

drop table "public"."staff_shifts";

create or replace function private.invite_member (
  p_arena uuid,
  p_email text,
  p_name  text,
  p_role  text,
  p_perms text[]
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_email   text := lower(btrim(coalesce(p_email, '')));
  v_name    text := btrim(coalesce(p_name, ''));
  v_owner   boolean;
  v_perms   text[];
  v_token   text;
  v_id      uuid;
  v_expires timestamptz := statement_timestamp() + interval '7 days';
begin
  if auth.uid() is null then
    raise exception 'forbidden' using errcode = '42501', hint = 'sign in first';
  end if;
  if p_role is null or p_role not in ('staff', 'owner') then
    raise exception 'invalid_role' using hint = 'role must be staff or owner';
  end if;
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'invalid_email' using hint = 'enter a valid e-mail address';
  end if;
  if length(v_name) < 1 or length(v_name) > 80 then
    raise exception 'invalid_name' using hint = 'the name must be 1 to 80 characters';
  end if;
  v_owner := exists (select 1 from staff_profiles where arena_id = p_arena
                       and user_id = auth.uid() and active and role = 'owner');
  if p_role = 'owner' then
    if not v_owner then
      raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can invite an owner';
    end if;
    v_perms := _known_perms();
  else
    perform _need(p_arena, 'settings');
    perform _assert_known_perms(p_perms);
    v_perms := coalesce(p_perms, '{}');
    if v_perms && array['money', 'reports', 'bill_edit', 'bill_record']
       and not private.app_is_owner(p_arena) then
      raise exception 'forbidden' using errcode = '42501',
        hint = 'only an owner can grant money, reports, or editing or adding bills';
    end if;
  end if;
  if exists (select 1 from auth.users where id = auth.uid() and lower(email) = v_email) then
    raise exception 'forbidden' using errcode = '42501', hint = 'you cannot invite yourself';
  end if;
  if not v_owner and exists (select 1 from staff_invites where arena_id = p_arena
       and email = v_email and role = 'owner' and accepted_at is null and revoked_at is null) then
    raise exception 'forbidden' using errcode = '42501',
      hint = 'an owner invited this address; only an owner can replace that invite';
  end if;
  update staff_invites set revoked_at = statement_timestamp()
   where arena_id = p_arena and email = v_email and accepted_at is null and revoked_at is null;
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into staff_invites (arena_id, email, name, role, perms, token_hash, invited_by, expires_at)
    values (p_arena, v_email, v_name, p_role, v_perms,
            extensions.digest(v_token, 'sha256'), auth.uid(), v_expires)
    returning id into v_id;
  return jsonb_build_object('invite_id', v_id, 'token', v_token, 'expires_at', v_expires);
end;
$function$;

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

create or replace function public._create_arena_with_owner (
  p_user       uuid,
  p_arena_name text,
  p_owner_name text
)
  returns uuid
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare v_arena uuid;
begin
  insert into arenas(name) values (coalesce(nullif(btrim(p_arena_name), ''), 'Arena'))
    returning id into v_arena;
  insert into staff_profiles(arena_id, user_id, name, role, perms, active)
    values (v_arena, p_user, coalesce(nullif(btrim(p_owner_name), ''), 'Owner'), 'owner',
      _known_perms(), true);
  return v_arena;
end;
$function$;

create or replace function public._known_perms()
  returns text[]
  language sql
  immutable
  set search_path to 'public'
  AS $function$
  select array['start','bill','discount','members','stations','money','reports','settings',
               'bill_edit','bill_record'];
$function$;

create or replace function public._sync_apply (
  p_arena uuid,
  p_kind  text,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare v_before jsonb; v_res jsonb;
begin
  -- A price-list change retires the previous catalog into
  -- pricing_catalog_history, so a session priced on it still validates.
  if p_kind in ('rate.upsert', 'rate.delete', 'policy.save', 'settings.save',
                'holiday.upsert', 'holiday.delete', 'activity.upsert', 'activity.remove',
                'rule.upsert', 'rule.delete', 'rule.reorder') then
    v_before := _pricing_canon(_pricing_snapshot(p_arena));
  end if;

  -- Dispatch: one op kind -> one op_* function. Unknown kinds return null and
  -- sync_push rejects them.
  v_res := case p_kind
      when 'session.start'        then op_session_start(p_arena, p)
      when 'session.reconfigure'  then op_session_reconfigure(p_arena, p)
      when 'session.extend'       then op_session_extend(p_arena, p)
      when 'session.end'          then op_session_end(p_arena, p)
      when 'session.void'         then op_session_void(p_arena, p)
      when 'session.record'       then op_session_record(p_arena, p)
      when 'payment.record'       then op_payment(p_arena, p)
      when 'payment.correct'      then op_payment_correct(p_arena, p)
      when 'bill.adjust'          then op_bill_adjust(p_arena, p)
      when 'group.create'         then op_group_create(p_arena, p)
      when 'group.add'            then op_group_add(p_arena, p)
      when 'group.switch'         then op_group_switch(p_arena, p)
      when 'group.end_player'     then op_group_end_player(p_arena, p)
      when 'group.extend'         then op_group_extend(p_arena, p)
      when 'group.end'            then op_group_end(p_arena, p)
      when 'group.void'           then op_group_void(p_arena, p)
      when 'controller.move'      then op_controller_move(p_arena, p)
      when 'controller.upsert'    then op_controller_upsert(p_arena, p)
      when 'controller.set_status' then op_controller_set_status(p_arena, p)
      when 'accessory_kind.upsert' then op_accessory_kind_upsert(p_arena, p)
      when 'accessory_kind.remove' then op_accessory_kind_remove(p_arena, p)
      when 'customer.create'      then op_customer_create(p_arena, p)
      when 'customer.update'      then op_customer_update(p_arena, p)
      when 'booking.create'       then op_booking_create(p_arena, p)
      when 'booking.update'       then op_booking_update(p_arena, p)
      when 'booking.set_status'   then op_booking_set_status(p_arena, p)
      when 'game.upsert'          then op_game_upsert(p_arena, p)
      when 'game.set_active'      then op_game_set_active(p_arena, p)
      when 'game.delete'          then op_game_delete(p_arena, p)
      when 'game.replace_controls' then op_game_replace_controls(p_arena, p)
      when 'game.set_compat'      then op_game_set_compat(p_arena, p)
      when 'resource.upsert'      then op_resource_upsert(p_arena, p)
      when 'resource.set_status'  then op_resource_set_status(p_arena, p)
      when 'resource.set_mode'    then op_resource_set_mode(p_arena, p)
      when 'activity.upsert'      then op_activity_upsert(p_arena, p)
      when 'activity.remove'      then op_activity_remove(p_arena, p)
      when 'rate.upsert'          then op_rate_upsert(p_arena, p)
      when 'rate.delete'          then op_rate_delete(p_arena, p)
      when 'policy.save'          then op_policy_save(p_arena, p)
      when 'settings.save'        then op_settings_save(p_arena, p)
      when 'holiday.upsert'       then op_holiday_upsert(p_arena, p)
      when 'holiday.delete'       then op_holiday_delete(p_arena, p)
      when 'rule.upsert'          then op_rule_upsert(p_arena, p)
      when 'rule.delete'          then op_rule_delete(p_arena, p)
      when 'rule.reorder'         then op_rule_reorder(p_arena, p)
      when 'discount.upsert'      then op_discount_upsert(p_arena, p)
      when 'discount.set_active'  then op_discount_set_active(p_arena, p)
      when 'discount.delete'      then op_discount_delete(p_arena, p)
      when 'staff.update'         then op_staff_update(p_arena, p)
      when 'arena.update'         then op_arena_update(p_arena, p)
      when 'staff_details.save'   then op_staff_details_save(p_arena, p)
      when 'terms.publish'        then op_terms_publish(p_arena, p)
      when 'terms.accept'         then op_terms_accept(p_arena, p)
      else null
    end;

  if v_before is not null and v_before <> _pricing_canon(_pricing_snapshot(p_arena)) then
    insert into pricing_catalog_history(arena_id, canon, retired_at)
      values (p_arena, v_before, statement_timestamp())
    on conflict (arena_id, canon_md5) do update set retired_at = excluded.retired_at;
  end if;
  return v_res;
end;
$function$;

create or replace function public.op_settings_save (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare v_json jsonb := p->'json';
begin
  perform _need(p_arena, 'settings');
  if (p->>'key') not in ('business_hours', 'floor_options', 'discount_options', 'venue_profile',
                         'offline_rules') then
    raise exception 'setting_not_shared' using hint = coalesce(p->>'key', 'null');
  end if;
  if p->>'key' = 'floor_options' then
    v_json := _floor_options(p->'json');
  elsif p->>'key' = 'discount_options' then
    v_json := _discount_options(p->'json');
  elsif p->>'key' = 'venue_profile' then
    v_json := _venue_profile(p->'json');
  elsif p->>'key' = 'offline_rules' then
    v_json := _offline_rules(p->'json');
  end if;
  insert into settings(arena_id, key, json) values (p_arena, p->>'key', v_json)
  on conflict (arena_id, key) do update set json = excluded.json, updated_at = statement_timestamp();
  return '{}'::jsonb;
end;
$function$;

create or replace function public.op_staff_update (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  -- money / reports make a member "owner level" (app_is_owner, and the app's
  -- AppUser.isOwner). Only an owner-level member may hand them out or take them away.
  c_owner_perms constant text[] := array['money', 'reports'];
  v_user   uuid    := (p->>'user_id')::uuid;
  -- A field the op leaves out keeps its current value: a partial update must
  -- never wipe someone's permissions or silently reactivate them.
  v_perms  text[]  := case when p ? 'perms'
                        then array(select jsonb_array_elements_text(coalesce(p->'perms', '[]'::jsonb))) end;
  v_active boolean := (p->>'active')::boolean;
  v_role   text;
  v_old_perms  text[];
  v_old_active boolean;
  v_adj    boolean := false;
begin
  perform _need(p_arena, 'settings');
  select role, perms, active into v_role, v_old_perms, v_old_active from staff_profiles
    where arena_id = p_arena and user_id = v_user for update;
  if not found then raise exception 'not_found' using hint = 'staff'; end if;
  v_perms := coalesce(v_perms, v_old_perms);
  v_active := coalesce(v_active, v_old_active);
  perform _assert_known_perms(v_perms);

  if v_role = 'owner' then
    if not exists (select 1 from staff_profiles where arena_id = p_arena
         and user_id = auth.uid() and active and role = 'owner') then
      raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can change an owner';
    end if;
    -- The server already treats a role owner as holding everything
    -- (app_has_perm); the app reads the perms list. Keep the list complete and
    -- the profile active so both agree and the arena always has an owner.
    -- Removing an owner is an operator action on the database, not an op.
    v_adj := not (v_perms @> _known_perms()) or not v_active;
    v_perms := _known_perms();
    v_active := true;
  else
    -- Nobody changes their own access: a Settings holder could otherwise grant
    -- themselves money/reports and become owner level.
    if v_user = auth.uid()
       and (not (v_perms @> v_old_perms and v_old_perms @> v_perms) or v_active <> v_old_active) then
      raise exception 'forbidden' using errcode = '42501',
        hint = 'you cannot change your own permissions';
    end if;
    -- Owner-level perms, and owner-level members, are managed by owners only.
    if not private.app_is_owner(p_arena)
       and (v_old_perms && c_owner_perms
            or ('money' = any(v_perms)) <> ('money' = any(v_old_perms))
            or ('reports' = any(v_perms)) <> ('reports' = any(v_old_perms))) then
      raise exception 'forbidden' using errcode = '42501',
        hint = 'only an owner can grant money or reports, or change an owner-level member';
    end if;
    -- Editing closed bills or adding missed ones records money: owners only hand out
    -- bill_edit and bill_record.
    if not private.app_is_owner(p_arena)
       and (('bill_edit' = any(v_perms)) <> ('bill_edit' = any(v_old_perms))
            or ('bill_record' = any(v_perms)) <> ('bill_record' = any(v_old_perms))) then
      raise exception 'forbidden' using errcode = '42501',
        hint = 'only an owner can grant or remove editing or adding bills';
    end if;
  end if;

  update staff_profiles set name = coalesce(nullif(btrim(p->>'name'), ''), name),
      perms = v_perms, active = v_active,
      sort_order = coalesce((p->>'sort_order')::int, sort_order),
      updated_at = statement_timestamp()
    where arena_id = p_arena and user_id = v_user;
  perform _assert_settings_holder(p_arena);
  -- Access changes are audited with the before and after (permissions edit in place).
  insert into audit_log(arena_id, entity_type, entity_id, action, before, after, created_by, created_at)
    select p_arena, 'staff_profile', s.id, 'access',
           jsonb_build_object('perms', to_jsonb(v_old_perms), 'active', v_old_active),
           jsonb_build_object('perms', to_jsonb(s.perms), 'active', s.active),
           auth.uid(), statement_timestamp()
      from staff_profiles s
     where s.arena_id = p_arena and s.user_id = v_user
       and (s.perms is distinct from v_old_perms or s.active is distinct from v_old_active);
  -- adjusted = the device wrote something else: it refetches the staff list.
  return case when v_adj then '{"adjusted": true}'::jsonb else '{}'::jsonb end;
end;
$function$;

comment on column "public"."staff_profiles"."perms" is 'Permission codes from _known_perms(): start, bill, discount, members, stations, money, reports, settings, bill_edit, bill_record. Holding money or reports makes the member owner level (app_is_owner).';

comment on column "public"."sync_ops"."payload" is 'What an applied configuration or permission op asked for (staff, arena, station types, stations, rates, billing rules, settings, holidays, pricing rules, discounts): with user_id and created_at, who changed what and when. Null for floor ops.';

comment on function "private"."app_my_staff_ids"() is 'Staff profile ids of the signed-in user (active only); the own-rows test of the RLS policies on staff records (personal details, terms acceptances).';

comment on function "public"."_create_arena_with_owner"(uuid, text, text) is
  'Internal: create an empty arena (no catalog: the owner adds station types, prices, stations, games and controllers on the dashboard) and make the given login its owner with every permission. Shared by bootstrap_owner and create_my_arena; callers validate the login first.';

comment on function "public"."_known_perms"() is 'The permission codes a staff profile may hold: start, bill, discount, members, stations, money, reports, settings, bill_edit, bill_record.';
