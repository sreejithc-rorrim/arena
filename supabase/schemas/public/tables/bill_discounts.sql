-- bill_discounts — the discount applied to a bill (append-only, at most one per bill)
--
-- Written by _discount_apply when session.end carries a discount.
-- Keeps a snapshot of what was applied (name, code, value) so later edits to
-- the discount never change past bills, the amount taken off, the part of the
-- bill it applied to (base_paise), who applied it and why. discount_id is null
-- for a manual discount. A voided bill keeps its row, but it no longer counts
-- toward the discount's max_uses.
create table "public"."bill_discounts" (
  "id"           uuid                     not null default gen_random_uuid(),
  "arena_id"     uuid                     not null,
  "session_id"   uuid                     not null,
  "discount_id"  uuid,
  "source"       text                     not null,
  "name"         text                     not null,
  "code"         text,
  "value_kind"   text                     not null,
  "value"        bigint                   not null,
  "base_paise"   bigint                   not null,
  "amount_paise" bigint                   not null,
  "reason"       text,
  "applied_by"   uuid,
  "applied_at"   timestamp with time zone not null,
  "created_at"   timestamp with time zone not null default now(),
  "sync_xid"     xid8                     not null default pg_current_xact_id(),
  constraint "bill_discounts_pkey" primary key (id),
  constraint "bill_discounts_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "bill_discounts_session_id_fkey" foreign key (session_id) references public.sessions(id)
    on delete cascade,
  -- Past bills keep their discount: a used discount is never deleted (op_discount_delete).
  constraint "bill_discounts_discount_id_fkey" foreign key (discount_id) references public.discounts(id),
  constraint "bill_discounts_source_check"
    check ((source = ANY (ARRAY['preset'::text, 'coupon'::text, 'manual'::text]))),
  constraint "bill_discounts_manual_check" check (((source = 'manual'::text) = (discount_id is null))),
  constraint "bill_discounts_value_kind_check"
    check ((value_kind = ANY (ARRAY['percent'::text, 'flat'::text]))),
  constraint "bill_discounts_amount_check"
    check (((amount_paise >= 0) and (amount_paise <= base_paise)))
);

comment on table public.bill_discounts is 'The discount applied to a session''s bill, with a snapshot of the discount, the amount taken off, who applied it and why. Append-only; one per bill.';

comment on column public.bill_discounts.arena_id is 'Owning arena (tenant). RLS limits reads to members holding bill, money or reports.';

comment on column public.bill_discounts.discount_id is 'The preset or coupon used; null for a manual discount.';

comment on column public.bill_discounts.source is 'preset, coupon or manual (typed in by staff with the discount permission).';

comment on column public.bill_discounts.name is 'Discount name at the time (manual: "Manual discount").';

comment on column public.bill_discounts.code is 'Coupon code used; null otherwise.';

comment on column public.bill_discounts.base_paise is 'The part of the bill subtotal the discount applied to (its station types; the whole subtotal when unscoped).';

comment on column public.bill_discounts.amount_paise is 'Paise taken off the subtotal before cash rounding.';

comment on column public.bill_discounts.reason is 'Why it was given (required for manual discounts when Settings ask for a reason).';

comment on column public.bill_discounts.applied_at is 'When the bill ended (device-reported end instant): the moment validity is judged at.';

comment on column public.bill_discounts.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); change-feed cursor for sync_pull.';

alter table "public"."bill_discounts"
  enable row level security;

create unique index ux_bill_discounts_session on public.bill_discounts using btree (session_id)
  where (session_id is not null);

create index ix_bill_discounts_discount on public.bill_discounts using btree (discount_id, applied_at);

create index ix_bill_discounts_sync on public.bill_discounts using btree (arena_id, sync_xid);

create trigger t_bill_discounts_sync
  before insert or update on public.bill_discounts
  for each row
  execute function public.sync_stamp();

create trigger t_bill_discounts_tomb
  after delete on public.bill_discounts
  for each row
  execute function public.sync_record_delete();

create trigger t_same_arena
  before insert or update on public.bill_discounts
  for each row
  execute function
    public._assert_same_arena('session_id', 'sessions', 'discount_id', 'discounts');

-- Append-only: corrections are new rows (_append_only).
create trigger t_bill_discounts_append_only
  before update or delete on public.bill_discounts
  for each row
  execute function public._append_only();

create policy "p_sel_bill_discounts" on "public"."bill_discounts"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids_with(ARRAY['bill'::text, 'money'::text, 'reports'::text]) as app_arena_ids_with)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."bill_discounts"
  to "postgres", "service_role";

revoke all on table "public"."bill_discounts" from "anon";

revoke all on table "public"."bill_discounts" from "authenticated";

grant select on table "public"."bill_discounts" to "authenticated";
