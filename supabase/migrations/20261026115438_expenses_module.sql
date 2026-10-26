set local check_function_bodies = off;

drop policy "p_sel_audit_log" on "public"."audit_log";

create table "public"."expense_categories" (
  "id"         uuid                     not null default gen_random_uuid(),
  "arena_id"   uuid                     not null,
  "name"       text                     not null,
  "sort_order" integer                  not null default 0,
  "active"     boolean                  not null default true,
  "created_at" timestamp with time zone not null default now(),
  "updated_at" timestamp with time zone not null default now(),
  constraint "expense_categories_name_check"
    check (((char_length(name) >= 1) AND (char_length(name) <= 40))),
  constraint "expense_categories_pkey" primary key (id)
);

alter table "public"."expense_categories"
  enable row level security;

revoke all on table "public"."expense_categories" from "anon";

create table "public"."expense_payments" (
  "id"             uuid                     not null default gen_random_uuid(),
  "arena_id"       uuid                     not null,
  "expense_id"     uuid                     not null,
  "kind"           text                     not null default 'payment'::text,
  "amount_paise"   bigint                   not null,
  "method"         text                     not null,
  "paid_on"        date                     not null,
  "paid_from"      text                     not null,
  "payer_staff_id" uuid,
  "note"           text,
  "reverses_id"    uuid,
  "created_by"     uuid,
  "created_at"     timestamp with time zone not null default now(),
  constraint "expense_payments_amount_sign_check"
    check (((amount_paise <> 0) AND ((kind = 'reversal'::text) = (amount_paise < 0)))),
  constraint "expense_payments_kind_check"
    check ((kind = ANY (ARRAY['payment'::text, 'reversal'::text]))),
  constraint "expense_payments_method_check"
    check
    ((method = ANY (ARRAY['cash'::text, 'upi'::text, 'card'::text, 'bank'::text, 'other'::text]))),
  constraint "expense_payments_note_check" check (((note IS NULL) OR (char_length(note) <= 500))),
  constraint "expense_payments_paid_from_check"
    check ((paid_from = ANY (ARRAY['company'::text, 'personal'::text]))),
  constraint "expense_payments_payer_check"
    check (((paid_from = 'personal'::text) = (payer_staff_id IS NOT NULL))),
  constraint "expense_payments_pkey" primary key (id),
  constraint "expense_payments_reversal_check" check ((((kind = 'reversal'::text) = (reverses_id IS
    NOT NULL)) AND ((kind <> 'reversal'::text) OR (btrim(COALESCE(note, ''::text)) <> ''::text)))),
  constraint "expense_payments_reverses_id_key" unique (reverses_id)
);

alter table "public"."expense_payments"
  enable row level security;

revoke all on table "public"."expense_payments" from "anon";

create table "public"."expenses" (
  "id"             uuid                     not null default gen_random_uuid(),
  "arena_id"       uuid                     not null,
  "kind"           text                     not null,
  "category_id"    uuid,
  "staff_id"       uuid,
  "period_start"   date,
  "period_end"     date,
  "title"          text                     not null,
  "amount_paise"   bigint                   not null,
  "expense_date"   date                     not null,
  "notes"          text,
  "payment_status" text                     not null default 'unpaid'::text,
  "status"         text                     not null default 'active'::text,
  "void_reason"    text,
  "created_by"     uuid,
  "created_at"     timestamp with time zone not null default now(),
  "updated_at"     timestamp with time zone not null default now(),
  constraint "expenses_amount_check" check (((amount_paise > 0) AND (amount_paise <= 1000000000))),
  constraint "expenses_kind_check" check ((kind = ANY (ARRAY['general'::text, 'salary'::text]))),
  constraint "expenses_kind_shape_check" check ((((kind = 'general'::text) AND (category_id IS
    NOT NULL) AND (period_start IS NULL) AND (period_end IS NULL)) OR
    ((kind = 'salary'::text) AND (category_id IS NULL) AND (staff_id IS
    NOT NULL) AND (period_start IS NOT NULL) AND (period_end IS
    NOT NULL) AND (period_end >= period_start) AND ((period_end - period_start) <= 61) AND
    (expense_date = period_end)))),
  constraint "expenses_notes_check" check (((notes IS NULL) OR (char_length(notes) <= 1000))),
  constraint "expenses_payment_status_check"
    check ((payment_status = ANY (ARRAY['unpaid'::text, 'partial'::text, 'paid'::text]))),
  constraint "expenses_pkey" primary key (id),
  constraint "expenses_status_check" check ((status = ANY (ARRAY['active'::text, 'voided'::text]))),
  constraint "expenses_title_check"
    check (((char_length(title) >= 1) AND (char_length(title) <= 80))),
  constraint "expenses_void_check" check ((((status = 'voided'::text) = (void_reason IS
    NOT NULL)) AND ((status <> 'voided'::text) OR (payment_status = 'unpaid'::text))))
);

alter table "public"."expenses"
  enable row level security;

revoke all on table "public"."expenses" from "anon";

create table "public"."staff_salaries" (
  "id"             uuid                     not null default gen_random_uuid(),
  "arena_id"       uuid                     not null,
  "staff_id"       uuid                     not null,
  "effective_from" date                     not null,
  "period"         text                     not null,
  "amount_paise"   bigint                   not null,
  "note"           text,
  "created_by"     uuid,
  "created_at"     timestamp with time zone not null default now(),
  "updated_at"     timestamp with time zone not null default now(),
  constraint "staff_salaries_amount_check"
    check (((amount_paise > 0) AND (amount_paise <= 1000000000))),
  constraint "staff_salaries_note_check" check (((note IS NULL) OR (char_length(note) <= 200))),
  constraint "staff_salaries_period_check"
    check ((period = ANY (ARRAY['monthly'::text, 'weekly'::text]))),
  constraint "staff_salaries_pkey" primary key (id),
  constraint "staff_salaries_staff_id_effective_from_key" unique (staff_id, effective_from)
);

alter table "public"."staff_salaries"
  enable row level security;

revoke all on table "public"."staff_salaries" from "anon";

create or replace function private.arena_expense (
  p_arena uuid,
  p_id    uuid
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
begin
  if not private.app_has_perm(p_arena, 'money') then
    raise exception 'forbidden' using errcode = '42501', hint = 'needs money';
  end if;
  if not exists (select 1 from expenses where id = p_id and arena_id = p_arena) then
    raise exception 'not_found' using hint = 'expense';
  end if;
  return _expense_json(p_id) || jsonb_build_object('history', coalesce((
    select jsonb_agg(jsonb_build_object(
        'action', a.action, 'reason', a.reason, 'before', a.before, 'after', a.after,
        'at', a.created_at, 'by_name', s.name)
        order by a.created_at, a.id)
      from audit_log a
      left join staff_profiles s on s.user_id = a.created_by and s.arena_id = a.arena_id
     where a.arena_id = p_arena and a.entity_type = 'expense' and a.entity_id = p_id), '[]'::jsonb));
end;
$function$;

create or replace function private.arena_expenses (
  p_arena uuid,
  p_first date,
  p_last  date
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
begin
  if not private.app_has_perm(p_arena, 'money') then
    raise exception 'forbidden' using errcode = '42501', hint = 'needs money';
  end if;
  if p_first is null or p_last is null or p_last < p_first or p_last - p_first > 399 then
    raise exception 'invalid_range' using hint = 'first day on or before the last, at most 400 days';
  end if;
  return jsonb_build_object(
    'expenses', coalesce((
      select jsonb_agg(_expense_json(e.id) order by e.expense_date desc, e.created_at desc, e.id)
        from expenses e
       where e.arena_id = p_arena and e.expense_date between p_first and p_last), '[]'::jsonb),
    'payments', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', p.id, 'expense_id', p.expense_id, 'expense_title', e.title,
          'expense_kind', e.kind, 'expense_status', e.status, 'category_name', c.name,
          'staff_id', e.staff_id, 'staff_name', s.name,
          'kind', p.kind, 'amount_paise', p.amount_paise, 'method', p.method,
          'paid_on', p.paid_on, 'paid_from', p.paid_from,
          'payer_staff_id', p.payer_staff_id, 'payer_name', ps.name,
          'note', p.note, 'reverses_id', p.reverses_id)
          order by p.paid_on desc, p.created_at desc, p.id)
        from expense_payments p
        join expenses e on e.id = p.expense_id
        left join expense_categories c on c.id = e.category_id
        left join staff_profiles s on s.id = e.staff_id
        left join staff_profiles ps on ps.id = p.payer_staff_id
       where p.arena_id = p_arena and p.paid_on between p_first and p_last), '[]'::jsonb),
    'owed_total_paise', (
      select coalesce(sum(e.amount_paise - coalesce(t.paid, 0)), 0)
        from expenses e
        left join lateral (select sum(amount_paise) as paid from expense_payments
                            where expense_id = e.id) t on true
       where e.arena_id = p_arena and e.status = 'active' and e.payment_status <> 'paid'),
    'owed_count', (
      select count(*) from expenses
       where arena_id = p_arena and status = 'active' and payment_status <> 'paid'));
end;
$function$;

create or replace function private.arena_staff_salary (
  p_arena uuid,
  p_staff uuid
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare v_name text; v_removed timestamptz;
begin
  if not private.app_has_perm(p_arena, 'money') then
    raise exception 'forbidden' using errcode = '42501', hint = 'needs money';
  end if;
  select name, removed_at into v_name, v_removed
    from staff_profiles where id = p_staff and arena_id = p_arena;
  if not found then raise exception 'not_found' using hint = 'staff'; end if;
  return jsonb_build_object(
    'staff_id', p_staff, 'name', v_name, 'removed', v_removed is not null,
    'salaries', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', s.id, 'effective_from', s.effective_from, 'period', s.period,
          'amount_paise', s.amount_paise, 'note', s.note)
          order by s.effective_from desc)
        from staff_salaries s where s.staff_id = p_staff and s.arena_id = p_arena), '[]'::jsonb),
    'periods', coalesce((
      select jsonb_agg(_expense_json(e.id) order by e.period_start desc, e.created_at desc)
        from expenses e
       where e.arena_id = p_arena and e.staff_id = p_staff and e.kind = 'salary'), '[]'::jsonb));
end;
$function$;

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

revoke all
  on function
    "public"."_expense_check"(uuid, text, uuid, uuid, date, date, text, bigint, date, text, boolean,
    boolean, uuid)
  from public, "anon", "authenticated";

create or replace function public._expense_fields (
  p_e public.expenses
)
  returns jsonb
  language sql
  immutable
  set search_path to 'public'
  AS $function$
  select jsonb_build_object(
    'title', p_e.title, 'category_id', p_e.category_id, 'staff_id', p_e.staff_id,
    'period_start', p_e.period_start, 'period_end', p_e.period_end,
    'amount_paise', p_e.amount_paise, 'expense_date', p_e.expense_date, 'notes', p_e.notes);
$function$;

revoke all
  on function "public"."_expense_fields"(public.expenses)
  from public, "anon", "authenticated";

create or replace function public._expense_json (
  p_id uuid
)
  returns jsonb
  language sql
  stable
  set search_path to 'public'
  AS $function$
  select jsonb_build_object(
    'id', e.id, 'kind', e.kind, 'title', e.title,
    'category_id', e.category_id, 'category_name', c.name,
    'staff_id', e.staff_id, 'staff_name', s.name,
    'period_start', e.period_start, 'period_end', e.period_end,
    'amount_paise', e.amount_paise,
    'paid_paise', coalesce(t.paid, 0),
    'paid_company_paise', coalesce(t.company, 0),
    'paid_personal_paise', coalesce(t.personal, 0),
    'balance_paise', case when e.status = 'voided' then 0 else e.amount_paise - coalesce(t.paid, 0) end,
    'payment_status', e.payment_status, 'status', e.status, 'void_reason', e.void_reason,
    'expense_date', e.expense_date, 'notes', e.notes,
    'created_by', e.created_by, 'created_by_name', cb.name,
    'created_at', e.created_at, 'updated_at', e.updated_at,
    'payments', coalesce(t.rows, '[]'::jsonb))
    from expenses e
    left join expense_categories c on c.id = e.category_id
    left join staff_profiles s on s.id = e.staff_id
    left join staff_profiles cb on cb.user_id = e.created_by and cb.arena_id = e.arena_id
    left join lateral (
      select sum(p.amount_paise) as paid,
             sum(p.amount_paise) filter (where p.paid_from = 'company') as company,
             sum(p.amount_paise) filter (where p.paid_from = 'personal') as personal,
             jsonb_agg(jsonb_build_object(
               'id', p.id, 'kind', p.kind, 'amount_paise', p.amount_paise, 'method', p.method,
               'paid_on', p.paid_on, 'paid_from', p.paid_from,
               'payer_staff_id', p.payer_staff_id, 'payer_name', ps.name,
               'note', p.note, 'reverses_id', p.reverses_id,
               'reversed', exists (select 1 from expense_payments r where r.reverses_id = p.id),
               'created_by_name', pb.name, 'created_at', p.created_at)
               order by p.created_at, p.id) as rows
        from expense_payments p
        left join staff_profiles ps on ps.id = p.payer_staff_id
        left join staff_profiles pb on pb.user_id = p.created_by and pb.arena_id = p.arena_id
       where p.expense_id = e.id
    ) t on true
   where e.id = p_id;
$function$;

revoke all on function "public"."_expense_json"(uuid) from public, "anon", "authenticated";

create or replace function public._expense_pay (
  p_arena   uuid,
  p_expense uuid,
  p         jsonb
)
  returns text
  language plpgsql
  set search_path to 'public'
  AS $function$
declare
  v_now    timestamptz := statement_timestamp();
  v_id     uuid := nullif(p->>'payment_id', '')::uuid;
  v_amount bigint := (p->>'amount_paise')::bigint;
  v_method text := p->>'method';
  v_on     date := nullif(p->>'paid_on', '')::date;
  v_from   text := p->>'paid_from';
  v_payer  uuid := nullif(p->>'payer_staff_id', '')::uuid;
  v_note   text := nullif(btrim(coalesce(p->>'note', '')), '');
  v_total  bigint; v_paid bigint; v_status text;
  v_role   text; v_active boolean; v_removed timestamptz;
begin
  if v_id is null then raise exception 'invalid_payload' using hint = 'payment_id'; end if;
  if v_amount is null or v_amount = 0 then raise exception 'amount_zero' using hint = 'more than ₹0'; end if;
  if v_amount < 0 then raise exception 'amount_negative' using hint = 'more than ₹0'; end if;
  if v_method is null or v_method not in ('cash', 'upi', 'card', 'bank', 'other') then
    raise exception 'invalid_method' using hint = 'cash, upi, card, bank or other';
  end if;
  if v_on is null then raise exception 'date_required' using hint = 'the day it was paid'; end if;
  if v_on > _pr_ist_date(v_now) then
    raise exception 'date_in_future' using hint = 'record a payment on or after the day it is made';
  end if;
  if v_on < date '2000-01-01' then
    raise exception 'date_out_of_range' using hint = 'on or after 1 Jan 2000';
  end if;

  -- Funding source: the company's account names nobody; personal money names its owner.
  if v_from is null or v_from not in ('company', 'personal') then
    raise exception 'invalid_paid_from' using hint = 'company or personal';
  end if;
  if v_from = 'company' and v_payer is not null then
    raise exception 'payer_not_allowed' using hint = 'a company payment names nobody';
  end if;
  if v_from = 'personal' then
    if v_payer is null then raise exception 'payer_required' using hint = 'say which owner paid'; end if;
    select role, active, removed_at into v_role, v_active, v_removed
      from staff_profiles where id = v_payer and arena_id = p_arena;
    if not found then raise exception 'not_found' using hint = 'payer'; end if;
    if v_role <> 'owner' or not v_active or v_removed is not null then
      raise exception 'payer_not_owner' using hint = 'personal money is paid by an owner of this arena';
    end if;
  end if;
  if v_note is not null and char_length(v_note) > 200 then
    raise exception 'note_too_long' using hint = 'at most 200 characters';
  end if;

  select amount_paise into v_total from expenses where id = p_expense;
  select coalesce(sum(amount_paise), 0) into v_paid from expense_payments where expense_id = p_expense;
  if v_paid + v_amount > v_total then
    raise exception 'overpayment'
      using hint = case when v_total - v_paid <= 0 then 'this expense is already paid'
                        else 'only ' || _rupees(v_total - v_paid) || ' is due' end;
  end if;

  insert into expense_payments(id, arena_id, expense_id, kind, amount_paise, method, paid_on,
      paid_from, payer_staff_id, note, created_by, created_at)
    values (v_id, p_arena, p_expense, 'payment', v_amount, v_method, v_on,
      v_from, v_payer, v_note, auth.uid(), v_now);
  v_status := _payment_status(v_total, v_paid + v_amount);
  update expenses set payment_status = v_status, updated_at = v_now where id = p_expense;
  return v_status;
end;
$function$;

revoke all
  on function "public"."_expense_pay"(uuid, uuid, jsonb)
  from public, "anon", "authenticated";

create or replace function public._expense_payment_check()
  returns trigger
  language plpgsql
  set search_path to 'public'
  AS $function$
declare v_orig expense_payments%rowtype;
begin
  if new.kind = 'reversal' then
    select * into v_orig from expense_payments where id = new.reverses_id;
    if not found or v_orig.kind <> 'payment' or v_orig.expense_id <> new.expense_id
       or new.amount_paise <> -v_orig.amount_paise or new.paid_from <> v_orig.paid_from
       or new.payer_staff_id is distinct from v_orig.payer_staff_id
       or new.method <> v_orig.method or new.paid_on <> v_orig.paid_on then
      raise exception 'reversal_mismatch' using errcode = '23514',
        hint = 'a reversal mirrors one payment: same expense, source, payer, method and day, opposite amount';
    end if;
  end if;
  return new;
end;
$function$;

revoke all on function "public"."_expense_payment_check"() from public, "anon", "authenticated";

create or replace function public._expense_reverse (
  p_arena    uuid,
  p_payment  uuid,
  p_reversal uuid,
  p_reason   text
)
  returns bigint
  language plpgsql
  set search_path to 'public'
  AS $function$
declare v_orig expense_payments%rowtype;
begin
  select * into v_orig from expense_payments where id = p_payment and arena_id = p_arena;
  if not found or v_orig.kind <> 'payment' then raise exception 'not_found' using hint = 'payment'; end if;
  if exists (select 1 from expense_payments where reverses_id = p_payment) then
    raise exception 'already_reversed' using hint = 'this payment was already reversed';
  end if;
  insert into expense_payments(id, arena_id, expense_id, kind, amount_paise, method, paid_on,
      paid_from, payer_staff_id, note, reverses_id, created_by, created_at)
    values (p_reversal, p_arena, v_orig.expense_id, 'reversal', -v_orig.amount_paise,
      v_orig.method, v_orig.paid_on, v_orig.paid_from, v_orig.payer_staff_id, p_reason,
      p_payment, auth.uid(), statement_timestamp());
  return v_orig.amount_paise;
end;
$function$;

revoke all
  on function "public"."_expense_reverse"(uuid, uuid, uuid, text)
  from public, "anon", "authenticated";

create or replace function public._expense_staff_check (
  p_arena uuid,
  p_staff uuid,
  p_new   boolean
)
  returns void
  language plpgsql
  stable
  set search_path to 'public'
  AS $function$
declare v_user uuid; v_removed timestamptz;
begin
  select user_id, removed_at into v_user, v_removed
    from staff_profiles where id = p_staff and arena_id = p_arena;
  if not found then raise exception 'not_found' using hint = 'staff'; end if;
  if p_new and v_removed is not null then
    raise exception 'staff_removed' using hint = 'this member was removed from the team';
  end if;
  if v_user = auth.uid() and not exists (
       select 1 from staff_profiles
        where arena_id = p_arena and user_id = auth.uid() and role = 'owner' and active) then
    raise exception 'own_record' using hint = 'only an owner records your own salary or expenses';
  end if;
end;
$function$;

revoke all
  on function "public"."_expense_staff_check"(uuid, uuid, boolean)
  from public, "anon", "authenticated";

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
      when 'staff.remove'         then op_staff_remove(p_arena, p)
      when 'arena.update'         then op_arena_update(p_arena, p)
      when 'staff_details.save'   then op_staff_details_save(p_arena, p)
      when 'terms.publish'        then op_terms_publish(p_arena, p)
      when 'terms.accept'         then op_terms_accept(p_arena, p)
      when 'expense_category.upsert' then op_expense_category_upsert(p_arena, p)
      when 'expense_category.remove' then op_expense_category_remove(p_arena, p)
      when 'expense.add'             then op_expense_add(p_arena, p)
      when 'expense.update'          then op_expense_update(p_arena, p)
      when 'expense.pay'             then op_expense_pay(p_arena, p)
      when 'expense.payment_reverse' then op_expense_payment_reverse(p_arena, p)
      when 'expense.void'            then op_expense_void(p_arena, p)
      when 'staff_salary.set'        then op_staff_salary_set(p_arena, p)
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

create or replace function public.arena_expense (
  p_arena uuid,
  p_id    uuid
)
  returns jsonb
  language sql
  stable
  set search_path to ''
  AS $function$
  select private.arena_expense(p_arena, p_id);
$function$;

revoke all on function "public"."arena_expense"(uuid, uuid) from public, "anon";

create or replace function public.arena_expenses (
  p_arena uuid,
  p_first date,
  p_last  date
)
  returns jsonb
  language sql
  stable
  set search_path to ''
  AS $function$
  select private.arena_expenses(p_arena, p_first, p_last);
$function$;

revoke all on function "public"."arena_expenses"(uuid, date, date) from public, "anon";

create or replace function public.arena_staff_salary (
  p_arena uuid,
  p_staff uuid
)
  returns jsonb
  language sql
  stable
  set search_path to ''
  AS $function$
  select private.arena_staff_salary(p_arena, p_staff);
$function$;

revoke all on function "public"."arena_staff_salary"(uuid, uuid) from public, "anon";

create or replace function public.expense_category_catalog()
  returns jsonb
  language sql
  immutable
  set search_path to ''
  AS $function$
  select '[
    {"name": "Rent"},
    {"name": "Electricity"},
    {"name": "Internet"},
    {"name": "Water"},
    {"name": "Repairs"},
    {"name": "Maintenance"},
    {"name": "Equipment"},
    {"name": "Cleaning"},
    {"name": "Supplies"},
    {"name": "Other"}
  ]'::jsonb;
$function$;

revoke all on function "public"."expense_category_catalog"() from public, "anon";

create or replace function public.op_expense_add (
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
  v_e      expenses%rowtype;
  v_status text := 'unpaid';
begin
  perform _need(p_arena, 'money');
  v_e.id := nullif(p->>'expense_id', '')::uuid;
  if v_e.id is null then raise exception 'invalid_payload' using hint = 'expense_id'; end if;
  v_e.arena_id := p_arena;
  v_e.kind := p->>'kind';
  v_e.title := nullif(btrim(coalesce(p->>'title', '')), '');
  v_e.amount_paise := (p->>'amount_paise')::bigint;
  v_e.notes := nullif(btrim(coalesce(p->>'notes', '')), '');
  v_e.staff_id := nullif(p->>'staff_id', '')::uuid;
  if v_e.kind = 'salary' then
    v_e.period_start := nullif(p->>'period_start', '')::date;
    v_e.period_end := nullif(p->>'period_end', '')::date;
    v_e.expense_date := v_e.period_end;
  else
    v_e.category_id := nullif(p->>'category_id', '')::uuid;
    v_e.expense_date := nullif(p->>'expense_date', '')::date;
  end if;
  perform _expense_check(p_arena, v_e.kind, v_e.category_id, v_e.staff_id, v_e.period_start,
    v_e.period_end, v_e.title, v_e.amount_paise, v_e.expense_date, v_e.notes, true, true, v_e.id);

  insert into expenses(id, arena_id, kind, category_id, staff_id, period_start, period_end, title,
      amount_paise, expense_date, notes, created_by, created_at, updated_at)
    values (v_e.id, p_arena, v_e.kind, v_e.category_id, v_e.staff_id, v_e.period_start,
      v_e.period_end, v_e.title, v_e.amount_paise, v_e.expense_date, v_e.notes, auth.uid(),
      v_now, v_now);
  insert into audit_log(arena_id, entity_type, entity_id, action, after, created_by, created_at)
    values (p_arena, 'expense', v_e.id, 'add', _expense_fields(v_e), auth.uid(), v_now);

  if jsonb_typeof(p->'payment') = 'object' then
    perform 1 from expenses where id = v_e.id for update;
    v_status := _expense_pay(p_arena, v_e.id, p->'payment');
  end if;
  return jsonb_build_object('payment_status', v_status);
end;
$function$;

revoke all on function "public"."op_expense_add"(uuid, jsonb) from public, "anon", "authenticated";

create or replace function public.op_expense_category_remove (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare v_id uuid := (p->>'id')::uuid;
begin
  perform _need(p_arena, 'money');
  if exists (select 1 from expense_categories where id = v_id and arena_id <> p_arena) then
    raise exception 'not_found' using hint = 'expense_category';
  end if;
  perform 1 from expense_categories where id = v_id and arena_id = p_arena for update;
  if not found then return jsonb_build_object('removed', 'deleted'); end if;

  if exists (select 1 from expenses where category_id = v_id) then
    update expense_categories set active = false, updated_at = statement_timestamp() where id = v_id;
    return jsonb_build_object('removed', 'retired');
  end if;
  delete from expense_categories where id = v_id;
  return jsonb_build_object('removed', 'deleted');
end;
$function$;

revoke all
  on function "public"."op_expense_category_remove"(uuid, jsonb)
  from public, "anon", "authenticated";

create or replace function public.op_expense_category_upsert (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_id   uuid := (p->>'id')::uuid;
  v_name text := btrim(coalesce(p->>'name', ''));
begin
  perform _need(p_arena, 'money');
  if char_length(v_name) not between 1 and 40 then
    raise exception 'invalid_name' using hint = '1–40 characters';
  end if;
  if exists (select 1 from expense_categories where id = v_id and arena_id <> p_arena) then
    raise exception 'not_found' using hint = 'expense_category';
  end if;

  insert into expense_categories(id, arena_id, name, sort_order, active)
    values (v_id, p_arena, v_name, coalesce((p->>'sort_order')::int, 0),
      coalesce((p->>'active')::boolean, true))
  on conflict (id) do update set
    name = excluded.name, sort_order = excluded.sort_order, active = excluded.active,
    updated_at = statement_timestamp()
  where expense_categories.arena_id = p_arena;
  return '{}'::jsonb;
end;
$function$;

revoke all
  on function "public"."op_expense_category_upsert"(uuid, jsonb)
  from public, "anon", "authenticated";

create or replace function public.op_expense_pay (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_id uuid := nullif(p->>'expense_id', '')::uuid;
  v_e  expenses%rowtype;
begin
  perform _need(p_arena, 'money');
  -- Lock the expense so two payments on it queue here and the second sees the first.
  select * into v_e from expenses where id = v_id and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'expense'; end if;
  if v_e.status = 'voided' then raise exception 'voided' using hint = 'a voided expense takes no payments'; end if;
  if v_e.staff_id is not null then perform _expense_staff_check(p_arena, v_e.staff_id, false); end if;
  return jsonb_build_object('payment_status', _expense_pay(p_arena, v_id, p));
end;
$function$;

revoke all on function "public"."op_expense_pay"(uuid, jsonb) from public, "anon", "authenticated";

create or replace function public.op_expense_payment_reverse (
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
  v_pay    uuid := nullif(p->>'payment_id', '')::uuid;
  v_rev    uuid := coalesce(nullif(p->>'reversal_id', '')::uuid, gen_random_uuid());
  v_reason text := nullif(btrim(coalesce(p->>'reason', '')), '');
  v_exp    uuid;
  v_e      expenses%rowtype;
  v_amount bigint; v_paid bigint; v_status text;
begin
  perform _need(p_arena, 'money');
  if v_reason is null then raise exception 'reason_required' using hint = 'say why the payment is reversed'; end if;
  if length(v_reason) > 500 then raise exception 'reason_too_long' using hint = 'at most 500 characters'; end if;
  select expense_id into v_exp from expense_payments where id = v_pay and arena_id = p_arena;
  if not found then raise exception 'not_found' using hint = 'payment'; end if;
  select * into v_e from expenses where id = v_exp for update;
  if v_e.staff_id is not null then perform _expense_staff_check(p_arena, v_e.staff_id, false); end if;

  v_amount := _expense_reverse(p_arena, v_pay, v_rev, v_reason);
  select coalesce(sum(amount_paise), 0) into v_paid from expense_payments where expense_id = v_exp;
  v_status := _payment_status(v_e.amount_paise, v_paid);
  update expenses set payment_status = v_status, updated_at = v_now where id = v_exp;
  insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
      created_by, created_at)
    values (p_arena, 'expense', v_exp, 'payment_reverse', v_reason,
      jsonb_build_object('paid_paise', v_paid + v_amount),
      jsonb_build_object('paid_paise', v_paid, 'payment_id', v_pay), auth.uid(), v_now);
  return jsonb_build_object('payment_status', v_status);
end;
$function$;

revoke all
  on function "public"."op_expense_payment_reverse"(uuid, jsonb)
  from public, "anon", "authenticated";

create or replace function public.op_expense_update (
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
  v_id     uuid := nullif(p->>'expense_id', '')::uuid;
  v_old    expenses%rowtype;
  v_new    expenses%rowtype;
  v_paid   bigint;
  v_before jsonb; v_after jsonb; v_b jsonb; v_a jsonb;
begin
  perform _need(p_arena, 'money');
  select * into v_old from expenses where id = v_id and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'expense'; end if;
  if v_old.status = 'voided' then raise exception 'voided' using hint = 'a voided expense cannot change'; end if;
  if v_old.staff_id is not null then perform _expense_staff_check(p_arena, v_old.staff_id, false); end if;

  v_new := v_old;
  v_new.title := nullif(btrim(coalesce(p->>'title', '')), '');
  v_new.amount_paise := (p->>'amount_paise')::bigint;
  v_new.notes := nullif(btrim(coalesce(p->>'notes', '')), '');
  v_new.staff_id := nullif(p->>'staff_id', '')::uuid;
  if v_old.kind = 'salary' then
    v_new.period_start := nullif(p->>'period_start', '')::date;
    v_new.period_end := nullif(p->>'period_end', '')::date;
    v_new.expense_date := v_new.period_end;
  else
    v_new.category_id := nullif(p->>'category_id', '')::uuid;
    v_new.expense_date := nullif(p->>'expense_date', '')::date;
  end if;
  perform _expense_check(p_arena, v_new.kind, v_new.category_id, v_new.staff_id,
    v_new.period_start, v_new.period_end, v_new.title, v_new.amount_paise, v_new.expense_date,
    v_new.notes, v_new.category_id is distinct from v_old.category_id,
    v_new.staff_id is distinct from v_old.staff_id, v_id);

  select coalesce(sum(amount_paise), 0) into v_paid from expense_payments where expense_id = v_id;
  if v_new.amount_paise < v_paid then
    raise exception 'amount_below_paid'
      using hint = _rupees(v_paid) || ' is already paid: reverse a payment first';
  end if;

  v_before := _expense_fields(v_old);
  v_after := _expense_fields(v_new);
  if v_before = v_after then return jsonb_build_object('payment_status', v_old.payment_status); end if;
  select jsonb_object_agg(k, v_before->k), jsonb_object_agg(k, v_after->k) into v_b, v_a
    from jsonb_object_keys(v_after) k where v_before->k is distinct from v_after->k;

  v_new.payment_status := _payment_status(v_new.amount_paise, v_paid);
  update expenses set title = v_new.title, amount_paise = v_new.amount_paise, notes = v_new.notes,
      staff_id = v_new.staff_id, category_id = v_new.category_id,
      period_start = v_new.period_start, period_end = v_new.period_end,
      expense_date = v_new.expense_date, payment_status = v_new.payment_status, updated_at = v_now
    where id = v_id;
  insert into audit_log(arena_id, entity_type, entity_id, action, before, after, created_by, created_at)
    values (p_arena, 'expense', v_id, 'update', v_b, v_a, auth.uid(), v_now);
  return jsonb_build_object('payment_status', v_new.payment_status);
end;
$function$;

revoke all
  on function "public"."op_expense_update"(uuid, jsonb)
  from public, "anon", "authenticated";

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

revoke all on function "public"."op_expense_void"(uuid, jsonb) from public, "anon", "authenticated";

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

revoke all
  on function "public"."op_staff_salary_set"(uuid, jsonb)
  from public, "anon", "authenticated";

alter table "public"."expense_categories"
  add constraint "expense_categories_arena_id_fkey" foreign key (arena_id)
    references public.arenas(id) on delete cascade;

alter table "public"."expense_payments"
  add constraint "expense_payments_arena_id_fkey" foreign key (arena_id)
    references public.arenas(id) on delete cascade;

alter table "public"."expense_payments"
  add constraint "expense_payments_created_by_fkey" foreign key (created_by)
    references auth.users(id);

alter table "public"."expense_payments"
  add constraint "expense_payments_payer_staff_id_fkey" foreign key (payer_staff_id)
    references public.staff_profiles(id);

alter table "public"."expense_payments"
  add constraint "expense_payments_reverses_id_fkey" foreign key (reverses_id)
    references public.expense_payments(id);

alter table "public"."expenses"
  add constraint "expenses_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade;

alter table "public"."expenses"
  add constraint "expenses_category_id_fkey" foreign key (category_id)
    references public.expense_categories(id);

alter table "public"."expenses"
  add constraint "expenses_created_by_fkey" foreign key (created_by) references auth.users(id);

alter table "public"."expense_payments"
  add constraint "expense_payments_expense_id_fkey" foreign key (expense_id)
    references public.expenses(id);

alter table "public"."expenses"
  add constraint "expenses_salary_no_overlap" EXCLUDE using gist (staff_id
    with =,
    daterange(period_start, period_end, '[]'::text) with &&)
    where (((kind = 'salary'::text) AND (status = 'active'::text)));

alter table "public"."expenses"
  add constraint "expenses_staff_id_fkey" foreign key (staff_id)
    references public.staff_profiles(id);

alter table "public"."staff_salaries"
  add constraint "staff_salaries_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade;

alter table "public"."staff_salaries"
  add constraint "staff_salaries_created_by_fkey" foreign key (created_by) references auth.users(id);

alter table "public"."staff_salaries"
  add constraint "staff_salaries_staff_id_fkey" foreign key (staff_id)
    references public.staff_profiles(id);

create index ix_expense_payments_arena_paid_on on public.expense_payments
  using btree (arena_id, paid_on);

create index ix_expense_payments_created_by on public.expense_payments using btree (created_by);

create index ix_expense_payments_expense on public.expense_payments
  using btree (expense_id, created_at);

create index ix_expense_payments_payer on public.expense_payments using btree (payer_staff_id);

create index ix_expenses_arena_date on public.expenses using btree (arena_id, expense_date);

create index ix_expenses_category on public.expenses using btree (category_id);

create index ix_expenses_created_by on public.expenses using btree (created_by);

create index ix_expenses_owed on public.expenses using btree (arena_id)
  where ((status = 'active'::text) AND (payment_status <> 'paid'::text));

create index ix_expenses_staff on public.expenses using btree (staff_id, period_start);

create index ix_staff_salaries_arena on public.staff_salaries using btree (arena_id);

create index ix_staff_salaries_created_by on public.staff_salaries using btree (created_by);

create unique index ux_expense_categories_name on public.expense_categories
  using btree (arena_id, lower(name));

create trigger t_expense_categories_updated
  before update on public.expense_categories
  for each row
  execute function public.set_updated_at();

create trigger t_expense_payments_append_only
  before delete or update on public.expense_payments
  for each row
  execute function public._append_only();

create trigger t_expense_payments_check
  before insert on public.expense_payments
  for each row
  execute function public._expense_payment_check();

create trigger t_same_arena
  before insert or update on public.expense_payments
  for each row
  execute function
    public._assert_same_arena('expense_id', 'expenses', 'payer_staff_id', 'staff_profiles');

create trigger t_expenses_updated
  before update on public.expenses
  for each row
  execute function public.set_updated_at();

create trigger t_same_arena
  before insert or update on public.expenses
  for each row
  execute function
    public._assert_same_arena('category_id', 'expense_categories', 'staff_id', 'staff_profiles');

create trigger t_same_arena
  before insert or update on public.staff_salaries
  for each row
  execute function public._assert_same_arena('staff_id', 'staff_profiles');

create trigger t_staff_salaries_updated
  before update on public.staff_salaries
  for each row
  execute function public.set_updated_at();

create policy "p_sel_audit_log" on "public"."audit_log"
  for select
  to "authenticated"
  using
    (((arena_id in ( select private.app_arena_ids_with(ARRAY['money'::text, 'reports'::text]) as
    app_arena_ids_with)) AND
    ((entity_type <> all (ARRAY['expense'::text, 'staff_salary'::text])) or (arena_id in ( select
    private.app_arena_ids_with(ARRAY['money'::text]) as app_arena_ids_with)))));

create policy "p_sel_expense_categories" on "public"."expense_categories"
  for select
  to "authenticated"
  using
    ((arena_id in ( select private.app_arena_ids_with(ARRAY['money'::text]) as app_arena_ids_with)));

create policy "p_sel_expense_payments" on "public"."expense_payments"
  for select
  to "authenticated"
  using
    ((arena_id in ( select private.app_arena_ids_with(ARRAY['money'::text]) as app_arena_ids_with)));

create policy "p_sel_expenses" on "public"."expenses"
  for select
  to "authenticated"
  using
    ((arena_id in ( select private.app_arena_ids_with(ARRAY['money'::text]) as app_arena_ids_with)));

create policy "p_sel_staff_salaries" on "public"."staff_salaries"
  for select
  to "authenticated"
  using
    ((arena_id in ( select private.app_arena_ids_with(ARRAY['money'::text]) as app_arena_ids_with)));

comment on column "public"."expense_categories"."active" is 'False once retired: kept for the expenses that use it, not offered for new ones.';

comment on column "public"."expense_categories"."arena_id" is 'Owning arena (tenant). RLS limits reads to money holders of this arena.';

comment on column "public"."expense_categories"."name" is 'Display name, 1–40 characters, unique per arena ignoring case.';

comment on column "public"."expense_payments"."amount_paise" is 'Signed integer paise: positive for a payment, negative for a reversal (minus the payment it undoes), never zero.';

comment on column "public"."expense_payments"."arena_id" is 'Owning arena (tenant). RLS limits reads to money holders of this arena.';

comment on column "public"."expense_payments"."created_by" is 'auth.users id of the member whose op recorded the row.';

comment on column "public"."expense_payments"."method" is 'cash, upi, card, bank or other.';

comment on column "public"."expense_payments"."note" is 'Free-text note on a payment; the reason on a reversal (required).';

comment on column "public"."expense_payments"."paid_from" is 'company (the arena''s account) or personal (an owner''s own money: payer_staff_id says whose).';

comment on column "public"."expense_payments"."paid_on" is 'IST day the money was paid (a reversal: its payment''s day). Cash totals count by this date.';

comment on column "public"."expense_payments"."payer_staff_id" is 'staff_profiles row of the owner who paid personally; null for a company payment.';

comment on column "public"."expense_payments"."reverses_id" is 'The payment this reversal undoes; null on a payment. Unique: a payment is reversed at most once.';

comment on column "public"."expenses"."amount_paise" is 'What is owed, in integer paise: more than 0, at most ₹1 crore. Never below what was paid.';

comment on column "public"."expenses"."arena_id" is 'Owning arena (tenant). RLS limits reads to money holders of this arena.';

comment on column "public"."expenses"."category_id" is 'expense_categories row of a general expense; null for a salary.';

comment on column "public"."expenses"."created_by" is 'auth.users id of the member whose op recorded the expense.';

comment on column "public"."expenses"."expense_date" is 'IST business day the expense belongs to (a salary: its period''s last day). Period totals count by this date.';

comment on column "public"."expenses"."kind" is 'general (a cost in a category) or salary (one staff member''s pay for a period).';

comment on column "public"."expenses"."payment_status" is 'unpaid, partial or paid: recomputed from the sum of expense_payments against amount_paise by the ops.';

comment on column "public"."expenses"."period_end" is 'Last day (IST) of the salary period, at most 62 days after it starts; null for a cost.';

comment on column "public"."expenses"."period_start" is 'First day (IST) of the salary period; null for a cost.';

comment on column "public"."expenses"."staff_id" is 'staff_profiles row: the person paid (required for a salary, optional for a cost).';

comment on column "public"."expenses"."status" is 'active or voided (op_expense_void: reason required, payments reversed, audited).';

comment on column "public"."staff_salaries"."amount_paise" is 'Agreed salary per period in integer paise: more than 0, at most ₹1 crore.';

comment on column "public"."staff_salaries"."arena_id" is 'Owning arena (tenant). RLS limits reads to money holders of this arena.';

comment on column "public"."staff_salaries"."effective_from" is 'IST day from which this salary applies, until a later row takes over.';

comment on column "public"."staff_salaries"."period" is 'monthly (a calendar month) or weekly (Monday to Sunday).';

comment on column "public"."staff_salaries"."staff_id" is 'staff_profiles row of the person.';

comment on function "private"."arena_expense"(uuid, uuid) is 'Client API (money): one expense with its payments (source and payer) and its audit history, for the admin dashboard''s expense detail.';

comment on function "private"."arena_expenses"(uuid, date, date) is 'Client API (money): the arena''s expenses dated in an IST period, the payments made in it (company or owners'' own money) and what is still owed overall, for the admin dashboard''s Expenses screen. At most 400 days.';

comment on function "private"."arena_staff_salary"(uuid, uuid) is 'Client API (money): a staff member''s agreed salary history and every salary period recorded for them with payments, for the admin dashboard''s Salaries tab.';

comment on function
  "public"."_expense_check"(uuid, text, uuid, uuid, date, date, text, bigint, date, text, boolean,
  boolean, uuid) is 'Internal (op_expense_add / op_expense_update): refuse an expense whose kind, title, amount, notes, category, person, period or day break the rules, or a salary period that overlaps one already recorded.';

comment on function "public"."_expense_fields"(public.expenses) is 'Internal (expense ops): an expense''s editable fields as jsonb, for its audit_log before / after.';

comment on function "public"."_expense_json"(uuid) is 'Internal (expense reads): one expense with category, person, paid (company / personal, net of reversals), balance and its payments with source and payer, as jsonb.';

comment on function "public"."_expense_pay"(uuid, uuid, jsonb) is 'Internal (op_expense_add / op_expense_pay): validate and record one payment (amount, method, day, company or an owner''s personal money) toward a locked expense, never more than is owed; returns the new payment status.';

comment on function "public"."_expense_payment_check"() is 'Trigger (before insert on expense_payments): a reversal must mirror one payment of the same expense (opposite amount; same source, payer, method and day), else reversal_mismatch.';

comment on function "public"."_expense_reverse"(uuid, uuid, uuid, text) is 'Internal (op_expense_payment_reverse / op_expense_void): insert the reversal of one payment, keeping its method, day, source and payer; refuses a payment already reversed.';

comment on function "public"."_expense_staff_check"(uuid, uuid, boolean) is
  'Internal (expense ops): refuse a staff member of another arena (not_found), a removed one when newly chosen (staff_removed), or the caller''s own record unless they are an owner (own_record).';

comment on function "public"."arena_expense"(uuid, uuid) is 'Client API (money): one expense with its payments (source and payer) and its audit history, for the admin dashboard''s expense detail.';

comment on function "public"."arena_expenses"(uuid, date, date) is 'Client API (money): the arena''s expenses dated in an IST period, the payments made in it (company or owners'' own money) and what is still owed overall, for the admin dashboard''s Expenses screen. At most 400 days.';

comment on function "public"."arena_staff_salary"(uuid, uuid) is 'Client API (money): a staff member''s agreed salary history and every salary period recorded for them with payments, for the admin dashboard''s Salaries tab.';

comment on function "public"."expense_category_catalog"() is 'Client API: the global catalog of ready-made expense categories (name) an owner picks from; reads no table.';

comment on function "public"."op_expense_add"(uuid, jsonb) is 'Sync op expense.add (money): records a cost or a staff member''s salary for a period, optionally with its first payment (company or an owner''s personal money); audited.';

comment on function "public"."op_expense_category_remove"(uuid, jsonb) is 'Sync op expense_category.remove (money): deletes an expense category nothing uses, or retires one still in use.';

comment on function "public"."op_expense_category_upsert"(uuid, jsonb) is 'Sync op expense_category.upsert (money): creates or edits an expense category (Rent, Electricity …).';

comment on function "public"."op_expense_pay"(uuid, jsonb) is 'Sync op expense.pay (money): records one payment toward an expense from the company account or an owner''s personal money, never more than is owed.';

comment on function "public"."op_expense_payment_reverse"(uuid, jsonb) is 'Sync op expense.payment_reverse (money): undoes a mistaken expense payment with a reversal row that keeps its method, day, source and payer; reason required; audited.';

comment on function "public"."op_expense_update"(uuid, jsonb) is 'Sync op expense.update (money): changes an expense''s details (never its kind, never the amount below what is paid; payments untouched); audited with the changed fields.';

comment on function "public"."op_expense_void"(uuid, jsonb) is 'Sync op expense.void (money): cancels an expense (reason required), reversing its payments with their sources when asked; audited; the row stays.';

comment on function "public"."op_staff_salary_set"(uuid, jsonb) is 'Sync op staff_salary.set (money): sets a staff member''s agreed salary (monthly or weekly) from a date, or corrects that date''s row; audited; pays nothing.';

comment on table "public"."expense_categories" is 'Owner-defined expense categories per arena (Rent, Electricity …); retired, not deleted, once an expense uses one.';

comment on table "public"."expense_payments" is 'Append-only payments toward expenses and reversals of mistaken ones, each with its funding source (company account or an owner''s own money). Money holders only.';

comment on table "public"."expenses" is 'Arena expenses: running costs by category and staff salaries by period. amount_paise is owed; payments are expense_payments rows. Money holders only.';

comment on table "public"."staff_salaries" is 'Agreed salary per staff member from an effective date (monthly or weekly, paise). Prefills recorded salaries; never pays anything. Money holders only.';

revoke all on function "private"."arena_expense"(uuid, uuid) from public;

grant execute on function "private"."arena_expense"(uuid, uuid) to "authenticated";

revoke all on function "private"."arena_expense"(uuid, uuid) from "postgres";

grant execute on function "private"."arena_expense"(uuid, uuid) to "postgres";

grant execute on function "private"."arena_expense"(uuid, uuid) to "service_role";

revoke all on function "private"."arena_expenses"(uuid, date, date) from public;

grant execute on function "private"."arena_expenses"(uuid, date, date) to "authenticated";

revoke all on function "private"."arena_expenses"(uuid, date, date) from "postgres";

grant execute on function "private"."arena_expenses"(uuid, date, date) to "postgres";

grant execute on function "private"."arena_expenses"(uuid, date, date) to "service_role";

revoke all on function "private"."arena_staff_salary"(uuid, uuid) from public;

grant execute on function "private"."arena_staff_salary"(uuid, uuid) to "authenticated";

revoke all on function "private"."arena_staff_salary"(uuid, uuid) from "postgres";

grant execute on function "private"."arena_staff_salary"(uuid, uuid) to "postgres";

grant execute on function "private"."arena_staff_salary"(uuid, uuid) to "service_role";

revoke all
  on function
    "public"."_expense_check"(uuid, text, uuid, uuid, date, date, text, bigint, date, text, boolean,
    boolean, uuid)
  from "postgres";

grant execute
  on function
    "public"."_expense_check"(uuid, text, uuid, uuid, date, date, text, bigint, date, text, boolean,
    boolean, uuid)
  to "postgres";

grant execute
  on function
    "public"."_expense_check"(uuid, text, uuid, uuid, date, date, text, bigint, date, text, boolean,
    boolean, uuid)
  to "service_role";

revoke all on function "public"."_expense_fields"(public.expenses) from "postgres";

grant execute on function "public"."_expense_fields"(public.expenses) to "postgres";

grant execute on function "public"."_expense_fields"(public.expenses) to "service_role";

revoke all on function "public"."_expense_json"(uuid) from "postgres";

grant execute on function "public"."_expense_json"(uuid) to "postgres";

grant execute on function "public"."_expense_json"(uuid) to "service_role";

revoke all on function "public"."_expense_pay"(uuid, uuid, jsonb) from "postgres";

grant execute on function "public"."_expense_pay"(uuid, uuid, jsonb) to "postgres";

grant execute on function "public"."_expense_pay"(uuid, uuid, jsonb) to "service_role";

revoke all on function "public"."_expense_payment_check"() from "postgres";

grant execute on function "public"."_expense_payment_check"() to "postgres";

grant execute on function "public"."_expense_payment_check"() to "service_role";

revoke all on function "public"."_expense_reverse"(uuid, uuid, uuid, text) from "postgres";

grant execute on function "public"."_expense_reverse"(uuid, uuid, uuid, text) to "postgres";

grant execute on function "public"."_expense_reverse"(uuid, uuid, uuid, text) to "service_role";

revoke all on function "public"."_expense_staff_check"(uuid, uuid, boolean) from "postgres";

grant execute on function "public"."_expense_staff_check"(uuid, uuid, boolean) to "postgres";

grant execute on function "public"."_expense_staff_check"(uuid, uuid, boolean) to "service_role";

grant execute on function "public"."arena_expense"(uuid, uuid) to "authenticated";

revoke all on function "public"."arena_expense"(uuid, uuid) from "postgres";

grant execute on function "public"."arena_expense"(uuid, uuid) to "postgres";

grant execute on function "public"."arena_expense"(uuid, uuid) to "service_role";

grant execute on function "public"."arena_expenses"(uuid, date, date) to "authenticated";

revoke all on function "public"."arena_expenses"(uuid, date, date) from "postgres";

grant execute on function "public"."arena_expenses"(uuid, date, date) to "postgres";

grant execute on function "public"."arena_expenses"(uuid, date, date) to "service_role";

grant execute on function "public"."arena_staff_salary"(uuid, uuid) to "authenticated";

revoke all on function "public"."arena_staff_salary"(uuid, uuid) from "postgres";

grant execute on function "public"."arena_staff_salary"(uuid, uuid) to "postgres";

grant execute on function "public"."arena_staff_salary"(uuid, uuid) to "service_role";

grant execute on function "public"."expense_category_catalog"() to "authenticated";

revoke all on function "public"."expense_category_catalog"() from "postgres";

grant execute on function "public"."expense_category_catalog"() to "postgres";

grant execute on function "public"."expense_category_catalog"() to "service_role";

revoke all on function "public"."op_expense_add"(uuid, jsonb) from "postgres";

grant execute on function "public"."op_expense_add"(uuid, jsonb) to "postgres";

grant execute on function "public"."op_expense_add"(uuid, jsonb) to "service_role";

revoke all on function "public"."op_expense_category_remove"(uuid, jsonb) from "postgres";

grant execute on function "public"."op_expense_category_remove"(uuid, jsonb) to "postgres";

grant execute on function "public"."op_expense_category_remove"(uuid, jsonb) to "service_role";

revoke all on function "public"."op_expense_category_upsert"(uuid, jsonb) from "postgres";

grant execute on function "public"."op_expense_category_upsert"(uuid, jsonb) to "postgres";

grant execute on function "public"."op_expense_category_upsert"(uuid, jsonb) to "service_role";

revoke all on function "public"."op_expense_pay"(uuid, jsonb) from "postgres";

grant execute on function "public"."op_expense_pay"(uuid, jsonb) to "postgres";

grant execute on function "public"."op_expense_pay"(uuid, jsonb) to "service_role";

revoke all on function "public"."op_expense_payment_reverse"(uuid, jsonb) from "postgres";

grant execute on function "public"."op_expense_payment_reverse"(uuid, jsonb) to "postgres";

grant execute on function "public"."op_expense_payment_reverse"(uuid, jsonb) to "service_role";

revoke all on function "public"."op_expense_update"(uuid, jsonb) from "postgres";

grant execute on function "public"."op_expense_update"(uuid, jsonb) to "postgres";

grant execute on function "public"."op_expense_update"(uuid, jsonb) to "service_role";

revoke all on function "public"."op_expense_void"(uuid, jsonb) from "postgres";

grant execute on function "public"."op_expense_void"(uuid, jsonb) to "postgres";

grant execute on function "public"."op_expense_void"(uuid, jsonb) to "service_role";

revoke all on function "public"."op_staff_salary_set"(uuid, jsonb) from "postgres";

grant execute on function "public"."op_staff_salary_set"(uuid, jsonb) to "postgres";

grant execute on function "public"."op_staff_salary_set"(uuid, jsonb) to "service_role";

revoke all on table "public"."expense_categories" from "authenticated";

grant select on table "public"."expense_categories" to "authenticated";

revoke all on table "public"."expense_categories" from "postgres";

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."expense_categories"
  to "postgres";

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."expense_categories"
  to "service_role";

revoke all on table "public"."expense_payments" from "authenticated";

grant select on table "public"."expense_payments" to "authenticated";

revoke all on table "public"."expense_payments" from "postgres";

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."expense_payments"
  to "postgres";

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."expense_payments"
  to "service_role";

revoke all on table "public"."expenses" from "authenticated";

grant select on table "public"."expenses" to "authenticated";

revoke all on table "public"."expenses" from "postgres";

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."expenses"
  to "postgres";

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."expenses"
  to "service_role";

revoke all on table "public"."staff_salaries" from "authenticated";

grant select on table "public"."staff_salaries" to "authenticated";

revoke all on table "public"."staff_salaries" from "postgres";

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."staff_salaries"
  to "postgres";

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."staff_salaries"
  to "service_role";
