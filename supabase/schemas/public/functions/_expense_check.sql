-- _expense_check(...) — refuse an expense whose fields break the rules
--
-- Shared by op_expense_add and op_expense_update, given the expense as it would be saved
-- (p_id: its id; p_date is ignored for a salary, whose day is its period's last day).
-- Errors: invalid_kind; title_required; title_too_long (80); amount_invalid (more than ₹0, at
-- most ₹1 crore); notes_too_long (1000); category_required / not_found (hint category) /
-- category_retired (only when p_new_category) for a cost; staff_required / period_required /
-- invalid_period (last day on or after the first, at most 62 days) for a salary;
-- date_required; date_out_of_range (1 Jan 2000 to a year from today, IST); the person checks
-- of _expense_staff_check; salary_period_taken (another active salary of the same person
-- overlaps the period — checked under a per-person advisory lock, so two pushes for the same
-- month queue and the second is refused here rather than by the exclusion constraint, whose
-- 23P01 sync_push would only report as server_error).
-- Server-only: not executable by anon/authenticated.
create or replace function public._expense_check (
  p_arena        uuid,
  p_kind         text,
  p_category     uuid,
  p_staff        uuid,
  p_start        date,
  p_end          date,
  p_title        text,
  p_amount       bigint,
  p_date         date,
  p_notes        text,
  p_new_category boolean,
  p_new_staff    boolean,
  p_id           uuid
)
  returns void
  language plpgsql
  set search_path to 'public'
  AS $function$
declare
  v_today  date := _pr_ist_date(statement_timestamp());
  v_date   date := case when p_kind = 'salary' then p_end else p_date end;
  v_active boolean;
begin
  if p_kind is null or p_kind not in ('general', 'salary') then
    raise exception 'invalid_kind' using hint = 'general or salary';
  end if;
  if p_title is null then raise exception 'title_required' using hint = 'say what it is for'; end if;
  if char_length(p_title) > 80 then
    raise exception 'title_too_long' using hint = 'at most 80 characters';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'amount_invalid' using hint = 'more than ₹0';
  end if;
  if p_amount > 1000000000 then
    raise exception 'amount_invalid' using hint = 'at most ₹1,00,00,000 per entry';
  end if;
  if p_notes is not null and char_length(p_notes) > 1000 then
    raise exception 'notes_too_long' using hint = 'at most 1000 characters';
  end if;

  if p_kind = 'general' then
    if p_category is null then raise exception 'category_required' using hint = 'pick a category'; end if;
    select active into v_active from expense_categories where id = p_category and arena_id = p_arena;
    if not found then raise exception 'not_found' using hint = 'category'; end if;
    if p_new_category and not v_active then
      raise exception 'category_retired' using hint = 'this category is turned off: pick another';
    end if;
  else
    if p_staff is null then raise exception 'staff_required' using hint = 'pick the person paid'; end if;
    if p_start is null or p_end is null then
      raise exception 'period_required' using hint = 'the first and last day of the salary period';
    end if;
    if p_end < p_start or p_end - p_start > 61 then
      raise exception 'invalid_period' using hint = 'the last day on or after the first, at most 62 days';
    end if;
  end if;

  if v_date is null then raise exception 'date_required' using hint = 'the day the expense belongs to'; end if;
  if v_date < date '2000-01-01' or v_date > v_today + 366 then
    raise exception 'date_out_of_range' using hint = 'between 1 Jan 2000 and a year from today';
  end if;
  if p_staff is not null then perform _expense_staff_check(p_arena, p_staff, p_new_staff); end if;

  if p_kind = 'salary' then
    perform pg_advisory_xact_lock(hashtextextended('expense_salary:' || p_staff::text, 0));
    if exists (select 1 from expenses
                where staff_id = p_staff and kind = 'salary' and status = 'active'
                  and id is distinct from p_id
                  and daterange(period_start, period_end, '[]') && daterange(p_start, p_end, '[]')) then
      raise exception 'salary_period_taken'
        using hint = 'a salary is already recorded for this person for part of this period';
    end if;
  end if;
end;
$function$;

comment on function public._expense_check(uuid, text, uuid, uuid, date, date, text, bigint, date, text, boolean, boolean, uuid) is 'Internal (op_expense_add / op_expense_update): refuse an expense whose kind, title, amount, notes, category, person, period or day break the rules, or a salary period that overlaps one already recorded.';

grant execute on function "public"."_expense_check"(uuid, text, uuid, uuid, date, date, text, bigint, date, text, boolean, boolean, uuid) to "postgres", "service_role";

revoke all on function "public"."_expense_check"(uuid, text, uuid, uuid, date, date, text, bigint, date, text, boolean, boolean, uuid) from public;

revoke all on function "public"."_expense_check"(uuid, text, uuid, uuid, date, date, text, bigint, date, text, boolean, boolean, uuid) from anon;

revoke all on function "public"."_expense_check"(uuid, text, uuid, uuid, date, date, text, bigint, date, text, boolean, boolean, uuid) from authenticated;
