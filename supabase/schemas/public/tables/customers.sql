-- customers — people who play at the arena (members and one-off walk-in guests)
--
-- Row ids are generated on the device. Written by op_customer_create
-- (customer.create) and op_customer_update (customer.update, refused as 'stale'
-- if the row changed since the device's base_version); op_session_start
-- bumps last_visit_at. A phone number is unique within an arena:
-- on create, a clashing phone is dropped from the new row and logged to audit_log
-- rather than failing the op. Visit/spend statistics are derived, not stored.
create table "public"."customers" (
  "id"            uuid                     not null default gen_random_uuid(),
  "arena_id"      uuid                     not null,
  "name"          text                     not null,
  "phone"         text,
  "notes"         text,
  "last_visit_at" timestamp with time zone,
  "is_guest"      boolean                  not null default false,
  "created_at"    timestamp with time zone not null default now(),
  "updated_at"    timestamp with time zone not null default now(),
  "sync_xid"      xid8                     not null default pg_current_xact_id(),
  "birth_year"    smallint,
  constraint "customers_birth_year_check" check (((birth_year >= 1900) AND (birth_year <= 2100))),
  constraint "customers_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "customers_pkey" primary key (id)
);

comment on table public.customers is 'Customers of an arena: registered members and per-visit walk-in guest records. Referenced by sessions and bookings.';

comment on column public.customers.arena_id is 'Owning arena (tenant). RLS limits reads to arenas the caller is an active member of.';

comment on column public.customers.phone is 'Contact number, trimmed; null when unknown. Unique per arena when set (ux_customer_phone).';

comment on column public.customers.last_visit_at is 'Start time of the customer''s latest session (UTC); set by op_session_start.';

comment on column public.customers.birth_year is 'Year of birth given at registration, for age checks (age ratings); null when not given. Written by customer.create / customer.update only when the key is sent; ops refuse a future year.';

comment on column public.customers.is_guest is 'True for a walk-in started without registering: one record per visit, kept out of the members directory.';

comment on column public.customers.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); change-feed cursor for sync_pull. Also the base_version a device sends with customer.update.';

alter table "public"."customers"
  enable row level security;

-- Members directory: registered customers only, guests excluded.
create index ix_customers_directory on public.customers using btree (arena_id, name)
  where (is_guest = false);

-- Case-insensitive name search.
create index ix_customers_name on public.customers using btree (arena_id, lower(name));

create index ix_customers_sync on public.customers using btree (arena_id, sync_xid);

-- One customer per phone number within an arena (null phones allowed).
create unique index ux_customer_phone on public.customers using btree (arena_id, phone)
  where (phone is not null);

create trigger t_customers_sync
  before insert or update on public.customers
  for each row
  execute function public.sync_stamp();

create trigger t_customers_tomb
  after delete on public.customers
  for each row
  execute function public.sync_record_delete();

create trigger t_customers_updated
  before update on public.customers
  for each row
  execute function public.set_updated_at();

-- Readable by an active member holding start or members (check-in, member records), or owner level (money/reports).
-- No write policy: clients change data only through sync_push.
create policy "p_sel_customers" on "public"."customers"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids_with(ARRAY['start'::text, 'members'::text, 'money'::text, 'reports'::text]) as app_arena_ids_with)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."customers"
  to "postgres", "service_role";

revoke all on table "public"."customers" from "anon";

revoke all on table "public"."customers" from "authenticated";

grant select on table "public"."customers" to "authenticated";