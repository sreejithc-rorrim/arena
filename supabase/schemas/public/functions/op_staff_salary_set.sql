-- op_staff_salary_set — sync op 'staff_salary.set': a staff member's agreed salary from a date, audited.
--
-- Permission: money.
-- Payload: id? (the new row's id, from the client), staff_id, effective_from (IST day),
--   period ('monthly' | 'weekly'), amount_paise, note?.
-- A new date adds a row (a raise keeps the history); the same date again corrects that row.
--   The salary only prefills what an owner records for a period: nothing is generated or paid.
-- Checks / errors: forbidden; staff_required; the person checks of _expense_staff_check (a
--   removed member gets no new salary; only an owner sets their own); date_required;
--   date_out_of_range (1 Jan 2000 to a year from today); invalid_salary_period;
--   amount_invalid (more than ₹0, at most ₹1 crore); note_too_long (200).
-- Writes: staff_salaries; an audit_log row (entity staff_salary, action set with after, or
--   update with before / after). The same values again write nothing. Returns: {id}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_staff_salary_set (
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
  v_id     uuid := coalesce(nullif(p->>'id', '')::uuid, gen_random_uuid());
  v_staff  uuid := nullif(p->>'staff_id', '')::uuid;
  v_from   date := nullif(p->>'effective_from', '')::date;
  v_period text := p->>'period';
  v_amount bigint := (p->>'amount_paise')::bigint;
  v_note   text := nullif(btrim(coalesce(p->>'note', '')), '');
  v_old    staff_salaries%rowtype;
begin
  perform _need(p_arena, 'money');
  if v_staff is null then raise exception 'staff_required' using hint = 'pick the person'; end if;
  perform _expense_staff_check(p_arena, v_staff, true);
  if v_from is null then raise exception 'date_required' using hint = 'the day the salary applies from'; end if;
  if v_from < date '2000-01-01' or v_from > _pr_ist_date(v_now) + 366 then
    raise exception 'date_out_of_range' using hint = 'between 1 Jan 2000 and a year from today';
  end if;
  if v_period is null or v_period not in ('monthly', 'weekly') then
    raise exception 'invalid_salary_period' using hint = 'monthly or weekly';
  end if;
  if v_amount is null or v_amount <= 0 then
    raise exception 'amount_invalid' using hint = 'more than ₹0';
  end if;
  if v_amount > 1000000000 then
    raise exception 'amount_invalid' using hint = 'at most ₹1,00,00,000';
  end if;
  if v_note is not null and char_length(v_note) > 200 then
    raise exception 'note_too_long' using hint = 'at most 200 characters';
  end if;

  select * into v_old from staff_salaries
    where staff_id = v_staff and effective_from = v_from and arena_id = p_arena for update;
  if found then
    if (v_old.period, v_old.amount_paise, v_old.note) is not distinct from (v_period, v_amount, v_note) then
      return jsonb_build_object('id', v_old.id);
    end if;
    update staff_salaries set period = v_period, amount_paise = v_amount, note = v_note,
        updated_at = v_now
      where id = v_old.id;
    insert into audit_log(arena_id, entity_type, entity_id, action, before, after, created_by, created_at)
      values (p_arena, 'staff_salary', v_old.id, 'update',
        jsonb_build_object('period', v_old.period, 'amount_paise', v_old.amount_paise, 'note', v_old.note),
        jsonb_build_object('period', v_period, 'amount_paise', v_amount, 'note', v_note),
        auth.uid(), v_now);
    return jsonb_build_object('id', v_old.id);
  end if;

  insert into staff_salaries(id, arena_id, staff_id, effective_from, period, amount_paise, note,
      created_by, created_at, updated_at)
    values (v_id, p_arena, v_staff, v_from, v_period, v_amount, v_note, auth.uid(), v_now, v_now);
  insert into audit_log(arena_id, entity_type, entity_id, action, after, created_by, created_at)
    values (p_arena, 'staff_salary', v_id, 'set',
      jsonb_build_object('staff_id', v_staff, 'effective_from', v_from, 'period', v_period,
        'amount_paise', v_amount, 'note', v_note),
      auth.uid(), v_now);
  return jsonb_build_object('id', v_id);
end;
$function$;

comment on function public.op_staff_salary_set(uuid, jsonb) is
  'Sync op staff_salary.set (money): sets a staff member''s agreed salary (monthly or weekly) from a date, or corrects that date''s row; audited; pays nothing.';

grant execute on function "public"."op_staff_salary_set"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_staff_salary_set"(uuid, jsonb) from public;

revoke all on function "public"."op_staff_salary_set"(uuid, jsonb) from anon;

revoke all on function "public"."op_staff_salary_set"(uuid, jsonb) from authenticated;
