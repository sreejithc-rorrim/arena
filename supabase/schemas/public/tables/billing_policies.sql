-- billing_policies — the arena's configurable billing rules
--
-- One knob per column (rounding, grace, minimum charge, early exit, payment
-- timing …); defaults are the documented assumptions in
-- docs/OWNER_CONFIRMATION.md. The server uses the oldest active row
-- (order by created_at) and falls back to _pr_policy defaults when none exists.
-- Written by op_policy_save (policy.save), which updates that row or creates
-- 'Default'; seeded by _seed_arena_catalog. Part of the pricing snapshot, so
-- saving it retires the previous price list into pricing_catalog_history.
create table "public"."billing_policies" (
  "id"                      uuid                     not null default gen_random_uuid(),
  "arena_id"                uuid                     not null,
  "name"                    text                     not null,
  "active"                  boolean                  not null default true,
  "billing_unit"            text                     not null default 'per_minute'::text,
  "block_rounding"          text                     not null default 'up'::text,
  "grace_minutes"           integer                  not null default 0,
  "minimum_charge_minutes"  integer                  not null default 0,
  "early_exit"              text                     not null default 'actual'::text,
  "rounding_scope"          text                     not null default 'session'::text,
  "late_arrival"            text                     not null default 'actual'::text,
  "vr_unit_rounding"        text                     not null default 'up'::text,
  "money_rounding_paise"    integer                  not null default 100,
  "money_rounding_dir"      text                     not null default 'nearest'::text,
  "payment_timing"          text                     not null default 'either'::text,
  "allow_extend_past_close" boolean                  not null default false,
  "cleaning_gap_minutes"    integer                  not null default 0,
  "created_at"              timestamp with time zone not null default now(),
  "updated_at"              timestamp with time zone not null default now(),
  "sync_xid"                xid8                     not null default pg_current_xact_id(),
  constraint "billing_policies_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "billing_policies_billing_unit_check"
    check
    ((billing_unit = ANY (ARRAY['per_minute'::text, 'block_15'::text, 'block_30'::text,
    'block_60'::text]))),
  constraint "billing_policies_block_rounding_check"
    check ((block_rounding = ANY (ARRAY['up'::text, 'nearest'::text]))),
  constraint "billing_policies_early_exit_check"
    check ((early_exit = ANY (ARRAY['actual'::text, 'planned'::text]))),
  constraint "billing_policies_late_arrival_check"
    check ((late_arrival = ANY (ARRAY['actual'::text, 'planned'::text]))),
  constraint "billing_policies_money_rounding_dir_check"
    check ((money_rounding_dir = ANY (ARRAY['nearest'::text, 'up'::text]))),
  constraint "billing_policies_payment_timing_check"
    check ((payment_timing = ANY (ARRAY['either'::text, 'start'::text, 'end'::text]))),
  constraint "billing_policies_pkey" primary key (id),
  constraint "billing_policies_rounding_scope_check"
    check ((rounding_scope = ANY (ARRAY['session'::text, 'segment'::text]))),
  constraint "billing_policies_vr_unit_rounding_check"
    check ((vr_unit_rounding = ANY (ARRAY['up'::text, 'nearest'::text, 'prorate'::text])))
);

comment on table public.billing_policies is 'Configurable billing rules for an arena. The oldest active row is the live policy and is captured into every session''s pricing snapshot.';

comment on column public.billing_policies.arena_id is 'Owning arena (tenant). RLS limits reads to arenas the caller is an active member of.';

comment on column public.billing_policies.active is 'Only active rows are considered; the oldest active one (by created_at) is used.';

comment on column public.billing_policies.billing_unit is 'per_minute (prorated by the second), or block_15 / block_30 / block_60 (billed minutes rounded to the block per block_rounding). Ignored for unit-model activities.';

comment on column public.billing_policies.block_rounding is 'How billed minutes are rounded to a block: up or nearest.';

comment on column public.billing_policies.grace_minutes is 'Play of this many minutes or less is free (checked per priced interval).';

comment on column public.billing_policies.minimum_charge_minutes is 'Shortest billable time: shorter play is billed as if it lasted this many minutes.';

comment on column public.billing_policies.early_exit is 'If a customer leaves early, bill the time actually played (actual) or the full booked duration (planned). Snapshotted with the policy; not applied by the server pricer.';

comment on column public.billing_policies.rounding_scope is 'Where price math is rounded to whole paise: once on the session total (session) or separately for each segment (segment).';

comment on column public.billing_policies.late_arrival is 'Bill a late arrival from the actual or the planned start. Snapshotted with the policy; not applied by the server pricer.';

comment on column public.billing_policies.vr_unit_rounding is 'For unit-model activities: round played time up to whole units, to the nearest unit, or prorate.';

comment on column public.billing_policies.money_rounding_paise is 'Final cash total is rounded to a multiple of this many paise (100 = 1 rupee); 1 or less means no rounding.';

comment on column public.billing_policies.money_rounding_dir is 'Direction of the final cash rounding: nearest or up.';

comment on column public.billing_policies.payment_timing is 'When payment may be recorded: either, start or end. Snapshotted with the policy; not enforced server-side.';

comment on column public.billing_policies.allow_extend_past_close is 'When false an extension stops at closing time (applied by the app''s session planner).';

comment on column public.billing_policies.cleaning_gap_minutes is 'Minutes a resource is held free after a session ends. Stored setting; not enforced server-side.';

comment on column public.billing_policies.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); change-feed cursor for sync_pull.';

alter table "public"."billing_policies"
  enable row level security;

create index ix_billing_policies_sync on public.billing_policies using btree (arena_id, sync_xid);

create trigger t_billing_policies_sync
  before insert or update on public.billing_policies
  for each row
  execute function public.sync_stamp();

create trigger t_billing_policies_tomb
  after delete on public.billing_policies
  for each row
  execute function public.sync_record_delete();

create trigger t_billing_policies_updated
  before update on public.billing_policies
  for each row
  execute function public.set_updated_at();

create policy "p_sel_billing_policies" on "public"."billing_policies"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids() as app_arena_ids)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."billing_policies"
  to "postgres", "service_role";

revoke all on table "public"."billing_policies" from "anon";

revoke all on table "public"."billing_policies" from "authenticated";

grant select on table "public"."billing_policies" to "authenticated";