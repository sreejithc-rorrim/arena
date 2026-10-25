-- pricing_rules — day/time price adjustments on top of the rate card ("Weekend evening +20%")
--
-- Owner-defined per arena. A rule matches a session by the session's
-- START instant in Asia/Kolkata: weekday in days, minute of day in
-- [start_min, end_min), holiday_mode against the holidays list, the date inside
-- [valid_from, valid_until], and the activity in activity_codes (empty = every
-- type). The first active match by priority (lowest number first) adjusts every
-- unit price of that session's charges for the whole session (_pr_rule,
-- _pr_rule_price): percent changes the price by adjust_value %, per_hour adds
-- adjust_value paise per hour (pro rata to the rate's unit). Never below ₹0.
-- Active rules are part of the pricing snapshot. Written by op_rule_upsert /
-- op_rule_delete / op_rule_reorder (settings).
create table "public"."pricing_rules" (
  "id"             uuid                     not null default gen_random_uuid(),
  "arena_id"       uuid                     not null,
  "name"           text                     not null,
  "priority"       integer                  not null default 0,
  "active"         boolean                  not null default true,
  "days"           smallint[]               not null,
  "start_min"      integer                  not null,
  "end_min"        integer                  not null,
  "holiday_mode"   text                     not null default 'any'::text,
  "valid_from"     date,
  "valid_until"    date,
  "activity_codes" text[]                   not null default '{}'::text[],
  "adjust_kind"    text                     not null,
  "adjust_value"   integer                  not null,
  "created_at"     timestamp with time zone not null default now(),
  "updated_at"     timestamp with time zone not null default now(),
  "sync_xid"       xid8                     not null default pg_current_xact_id(),
  constraint "pricing_rules_pkey" primary key (id),
  constraint "pricing_rules_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "pricing_rules_name_check" check ((char_length(name) >= 1 and char_length(name) <= 40)),
  constraint "pricing_rules_days_check"
    check ((cardinality(days) >= 1 and days <@ ARRAY[1, 2, 3, 4, 5, 6, 7]::smallint[])),
  constraint "pricing_rules_window_check"
    check ((start_min >= 0 and start_min < end_min and end_min <= 1440)),
  constraint "pricing_rules_holiday_mode_check"
    check ((holiday_mode = ANY (ARRAY['any'::text, 'only'::text, 'skip'::text]))),
  constraint "pricing_rules_valid_check"
    check (((valid_from is null) or (valid_until is null) or (valid_from <= valid_until))),
  constraint "pricing_rules_adjust_check"
    check ((((adjust_kind = 'percent'::text) and (adjust_value >= -100) and (adjust_value <= 500)
             and (adjust_value <> 0))
         or ((adjust_kind = 'per_hour'::text) and (adjust_value >= -10000000)
             and (adjust_value <= 10000000) and (adjust_value <> 0))))
);

comment on table public.pricing_rules is 'Day/time price adjustments: the first active match by priority, judged at the session start (IST), changes every unit price of the session by a percent or paise per hour. Part of the pricing snapshot.';

comment on column public.pricing_rules.arena_id is 'Owning arena (tenant). RLS limits reads to arenas the caller is an active member of.';

comment on column public.pricing_rules.priority is 'Lower wins: when several active rules match a session start, only the lowest priority (then name, then id) applies.';

comment on column public.pricing_rules.days is 'ISO weekdays the rule applies on (1 = Monday … 7 = Sunday), judged on the IST date of the session start.';

comment on column public.pricing_rules.start_min is 'Window start in minutes after IST midnight (inclusive); the session start minute must be in [start_min, end_min).';

comment on column public.pricing_rules.end_min is 'Window end in minutes after IST midnight (exclusive, at most 1440).';

comment on column public.pricing_rules.holiday_mode is 'any = holidays do not matter; only = applies only on a listed holiday; skip = never on a listed holiday.';

comment on column public.pricing_rules.valid_from is 'First IST date the rule applies (inclusive); null = no start.';

comment on column public.pricing_rules.valid_until is 'Last IST date the rule applies (inclusive); null = no end.';

comment on column public.pricing_rules.activity_codes is 'Station types (activities.code) the rule applies to; empty = every type.';

comment on column public.pricing_rules.adjust_kind is 'percent: unit price × (100 + adjust_value) / 100; per_hour: unit price + adjust_value paise per 60 minutes of the rate''s unit.';

comment on column public.pricing_rules.adjust_value is 'Signed: positive raises the price, negative lowers it. Percent −100…500, per_hour in paise; never 0.';

comment on column public.pricing_rules.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); change-feed cursor for sync_pull.';

alter table "public"."pricing_rules"
  enable row level security;

create index ix_pricing_rules_arena_priority on public.pricing_rules using btree (arena_id, priority);

create index ix_pricing_rules_sync on public.pricing_rules using btree (arena_id, sync_xid);

create trigger t_pricing_rules_sync
  before insert or update on public.pricing_rules
  for each row
  execute function public.sync_stamp();

create trigger t_pricing_rules_tomb
  after delete on public.pricing_rules
  for each row
  execute function public.sync_record_delete();

create trigger t_pricing_rules_updated
  before update on public.pricing_rules
  for each row
  execute function public.set_updated_at();

create policy "p_sel_pricing_rules" on "public"."pricing_rules"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids() as app_arena_ids)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."pricing_rules"
  to "postgres", "service_role";

revoke all on table "public"."pricing_rules" from "anon";

revoke all on table "public"."pricing_rules" from "authenticated";

grant select on table "public"."pricing_rules" to "authenticated";
