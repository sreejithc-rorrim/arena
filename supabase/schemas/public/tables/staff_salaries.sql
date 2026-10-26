-- staff_salaries — a staff member's agreed salary, from a date
--
-- One row per (staff member, effective_from): monthly or weekly, in integer paise. A raise is a
-- new row from a later date, so earlier periods keep the amount they were agreed at; setting the
-- same date again corrects that row (audited). The amount only prefills the salary an owner
-- records for a period (expenses kind 'salary'): nothing is generated or paid from it.
-- Written by op_staff_salary_set (money). Read by money holders only. Not in sync_pull: no pay
-- data reaches the floor app.
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
  constraint "staff_salaries_pkey" primary key (id),
  constraint "staff_salaries_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "staff_salaries_staff_id_fkey" foreign key (staff_id) references public.staff_profiles(id),
  constraint "staff_salaries_created_by_fkey" foreign key (created_by) references auth.users(id),
  constraint "staff_salaries_staff_id_effective_from_key" unique (staff_id, effective_from),
  constraint "staff_salaries_period_check" check ((period = ANY (ARRAY['monthly'::text, 'weekly'::text]))),
  constraint "staff_salaries_amount_check" check (((amount_paise > 0) AND (amount_paise <= 1000000000))),
  constraint "staff_salaries_note_check" check (((note IS NULL) OR (char_length(note) <= 200)))
);

comment on table public.staff_salaries is 'Agreed salary per staff member from an effective date (monthly or weekly, paise). Prefills recorded salaries; never pays anything. Money holders only.';

comment on column public.staff_salaries.arena_id is 'Owning arena (tenant). RLS limits reads to money holders of this arena.';

comment on column public.staff_salaries.staff_id is 'staff_profiles row of the person.';

comment on column public.staff_salaries.effective_from is 'IST day from which this salary applies, until a later row takes over.';

comment on column public.staff_salaries.period is 'monthly (a calendar month) or weekly (Monday to Sunday).';

comment on column public.staff_salaries.amount_paise is 'Agreed salary per period in integer paise: more than 0, at most ₹1 crore.';

alter table "public"."staff_salaries"
  enable row level security;

create index ix_staff_salaries_arena on public.staff_salaries using btree (arena_id);

create index ix_staff_salaries_created_by on public.staff_salaries using btree (created_by);

create trigger t_staff_salaries_updated
  before update on public.staff_salaries
  for each row
  execute function public.set_updated_at();

-- The person must belong to this row's arena (cross_arena_reference).
create trigger t_same_arena
  before insert or update on public.staff_salaries
  for each row
  execute function public._assert_same_arena('staff_id', 'staff_profiles');

-- Readable by money holders only (the owner holds every permission).
-- No write policy: clients change data only through sync_push.
create policy "p_sel_staff_salaries" on "public"."staff_salaries"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids_with(ARRAY['money'::text]) as app_arena_ids_with)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."staff_salaries"
  to "postgres", "service_role";

revoke all on table "public"."staff_salaries" from "anon";

revoke all on table "public"."staff_salaries" from "authenticated";

grant select on table "public"."staff_salaries" to "authenticated";
