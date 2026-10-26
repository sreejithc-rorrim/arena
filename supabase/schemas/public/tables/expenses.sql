-- expenses — what the arena owes or spent: a running cost or one staff member's salary for a period
--
-- kind 'general': a cost in an owner-defined category (rent, electricity …), optionally linked
-- to a staff member. kind 'salary': one staff member's salary for period_start…period_end
-- (at most 62 days); its expense_date is the period's last day, and active salary periods of
-- one person never overlap, so a month's salary cannot be recorded twice. amount_paise is what
-- is owed; what was paid is the sum of its expense_payments rows (append-only), and
-- payment_status is recomputed from that sum under a row lock by every op that touches it.
-- Nothing is generated: an owner records each expense and each payment.
-- Written by op_expense_add / op_expense_update / op_expense_pay / op_expense_payment_reverse /
-- op_expense_void (money); every change is audited (audit_log, entity_type 'expense'). A voided
-- expense keeps its row (status 'voided', void_reason) and nothing paid. Read by money holders
-- only. Not in sync_pull: the floor app never sees expenses or salaries.
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
  constraint "expenses_pkey" primary key (id),
  constraint "expenses_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "expenses_category_id_fkey" foreign key (category_id) references public.expense_categories(id),
  constraint "expenses_staff_id_fkey" foreign key (staff_id) references public.staff_profiles(id),
  constraint "expenses_created_by_fkey" foreign key (created_by) references auth.users(id),
  constraint "expenses_kind_check" check ((kind = ANY (ARRAY['general'::text, 'salary'::text]))),
  -- A cost has a category and no period; a salary has a person and a period (at most 62 days)
  -- ending on its expense date, and no category.
  constraint "expenses_kind_shape_check" check ((
    ((kind = 'general'::text) AND (category_id IS NOT NULL) AND (period_start IS NULL)
      AND (period_end IS NULL))
    OR ((kind = 'salary'::text) AND (category_id IS NULL) AND (staff_id IS NOT NULL)
      AND (period_start IS NOT NULL) AND (period_end IS NOT NULL)
      AND (period_end >= period_start) AND ((period_end - period_start) <= 61)
      AND (expense_date = period_end)))),
  constraint "expenses_title_check" check ((char_length(title) >= 1 and char_length(title) <= 80)),
  -- More than ₹0, at most ₹1 crore per entry (a typo guard).
  constraint "expenses_amount_check" check (((amount_paise > 0) AND (amount_paise <= 1000000000))),
  constraint "expenses_notes_check" check (((notes IS NULL) OR (char_length(notes) <= 1000))),
  constraint "expenses_payment_status_check"
    check ((payment_status = ANY (ARRAY['unpaid'::text, 'partial'::text, 'paid'::text]))),
  constraint "expenses_status_check" check ((status = ANY (ARRAY['active'::text, 'voided'::text]))),
  -- A void carries its reason, and a voided expense has nothing paid (its payments are reversed).
  constraint "expenses_void_check" check ((((status = 'voided'::text) = (void_reason IS NOT NULL))
    AND ((status <> 'voided'::text) OR (payment_status = 'unpaid'::text)))),
  -- One person's active salary periods never overlap (no salary recorded twice).
  constraint "expenses_salary_no_overlap" exclude using gist (staff_id with =,
    daterange(period_start, period_end, '[]'::text) with &&)
    where (((kind = 'salary'::text) AND (status = 'active'::text)))
);

comment on table public.expenses is 'Arena expenses: running costs by category and staff salaries by period. amount_paise is owed; payments are expense_payments rows. Money holders only.';

comment on column public.expenses.arena_id is 'Owning arena (tenant). RLS limits reads to money holders of this arena.';

comment on column public.expenses.kind is 'general (a cost in a category) or salary (one staff member''s pay for a period).';

comment on column public.expenses.category_id is 'expense_categories row of a general expense; null for a salary.';

comment on column public.expenses.staff_id is 'staff_profiles row: the person paid (required for a salary, optional for a cost).';

comment on column public.expenses.period_start is 'First day (IST) of the salary period; null for a cost.';

comment on column public.expenses.period_end is 'Last day (IST) of the salary period, at most 62 days after it starts; null for a cost.';

comment on column public.expenses.amount_paise is 'What is owed, in integer paise: more than 0, at most ₹1 crore. Never below what was paid.';

comment on column public.expenses.expense_date is 'IST business day the expense belongs to (a salary: its period''s last day). Period totals count by this date.';

comment on column public.expenses.payment_status is 'unpaid, partial or paid: recomputed from the sum of expense_payments against amount_paise by the ops.';

comment on column public.expenses.status is 'active or voided (op_expense_void: reason required, payments reversed, audited).';

comment on column public.expenses.created_by is 'auth.users id of the member whose op recorded the expense.';

alter table "public"."expenses"
  enable row level security;

create index ix_expenses_arena_date on public.expenses using btree (arena_id, expense_date);

create index ix_expenses_staff on public.expenses using btree (staff_id, period_start);

-- Foreign-key indexes.
create index ix_expenses_category on public.expenses using btree (category_id);

create index ix_expenses_created_by on public.expenses using btree (created_by);

-- What is still owed, any date (arena_expenses owed totals).
create index ix_expenses_owed on public.expenses using btree (arena_id)
  where ((status = 'active'::text) AND (payment_status <> 'paid'::text));

create trigger t_expenses_updated
  before update on public.expenses
  for each row
  execute function public.set_updated_at();

-- Category and person must belong to this row's arena (cross_arena_reference).
create trigger t_same_arena
  before insert or update on public.expenses
  for each row
  execute function public._assert_same_arena('category_id', 'expense_categories', 'staff_id', 'staff_profiles');

-- Readable by money holders only (the owner holds every permission): salaries and notes stay
-- with them. No write policy: clients change data only through sync_push.
create policy "p_sel_expenses" on "public"."expenses"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids_with(ARRAY['money'::text]) as app_arena_ids_with)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."expenses"
  to "postgres", "service_role";

revoke all on table "public"."expenses" from "anon";

revoke all on table "public"."expenses" from "authenticated";

grant select on table "public"."expenses" to "authenticated";
