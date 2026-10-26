-- expense_categories — what an expense is for (Rent, Electricity, Repairs …), per arena
--
-- Owner-defined; nothing is seeded (owners pick from expense_category_catalog() or add their
-- own). Salaries are not a category: an expenses row of kind 'salary' is grouped as "Staff
-- salary" by itself. A category some expense uses is retired (active = false), never deleted.
-- Written by op_expense_category_upsert / op_expense_category_remove (money). Read by money
-- holders only. Not in sync_pull: the floor app never sees expenses.
create table "public"."expense_categories" (
  "id"         uuid                     not null default gen_random_uuid(),
  "arena_id"   uuid                     not null,
  "name"       text                     not null,
  "sort_order" integer                  not null default 0,
  "active"     boolean                  not null default true,
  "created_at" timestamp with time zone not null default now(),
  "updated_at" timestamp with time zone not null default now(),
  constraint "expense_categories_pkey" primary key (id),
  constraint "expense_categories_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "expense_categories_name_check" check ((char_length(name) >= 1 and char_length(name) <= 40))
);

comment on table public.expense_categories is 'Owner-defined expense categories per arena (Rent, Electricity …); retired, not deleted, once an expense uses one.';

comment on column public.expense_categories.arena_id is 'Owning arena (tenant). RLS limits reads to money holders of this arena.';

comment on column public.expense_categories.name is 'Display name, 1–40 characters, unique per arena ignoring case.';

comment on column public.expense_categories.active is 'False once retired: kept for the expenses that use it, not offered for new ones.';

alter table "public"."expense_categories"
  enable row level security;

-- Names are unique per arena ignoring case.
create unique index ux_expense_categories_name on public.expense_categories
  using btree (arena_id, lower(name));

create trigger t_expense_categories_updated
  before update on public.expense_categories
  for each row
  execute function public.set_updated_at();

-- Readable by money holders only (the owner holds every permission).
-- No write policy: clients change data only through sync_push.
create policy "p_sel_expense_categories" on "public"."expense_categories"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids_with(ARRAY['money'::text]) as app_arena_ids_with)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."expense_categories"
  to "postgres", "service_role";

revoke all on table "public"."expense_categories" from "anon";

revoke all on table "public"."expense_categories" from "authenticated";

grant select on table "public"."expense_categories" to "authenticated";
