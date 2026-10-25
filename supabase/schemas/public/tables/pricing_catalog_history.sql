-- pricing_catalog_history — recently replaced price lists, for offline devices
--
-- When an op changes the arena's price list (rates, policy, business hours or
-- holidays), _sync_apply stores the previous list here in canonical form
-- (_pricing_canon). session.start accepts a device's pricing
-- snapshot if it equals the live list or one retired within _pricing_grace()
-- (72 h) (_assert_snapshot). Server-only: no RLS policy, no client grants, not
-- synced. One row per distinct list; re-retiring it refreshes retired_at.
create table "public"."pricing_catalog_history" (
  "arena_id"   uuid                     not null,
  "canon"      jsonb                    not null,
  "retired_at" timestamp with time zone not null,
  constraint "pricing_catalog_history_arena_id_fkey" foreign key (arena_id)
    references public.arenas(id) on delete cascade
);

comment on table public.pricing_catalog_history is 'Price lists retired by a pricing change, kept so a device that went offline holding the old list can still start sessions within the grace window. Server-only.';

comment on column public.pricing_catalog_history.arena_id is 'Owning arena (tenant). No client access: RLS is enabled with no policy and grants are revoked.';

comment on column public.pricing_catalog_history.canon is 'The retired price list in _pricing_canon form (rates, activities, policy, hours, holidays, closed_days), compared for equality with a device snapshot.';

comment on column public.pricing_catalog_history.retired_at is 'When the list was last replaced (statement time); entries older than _pricing_grace() are no longer accepted.';

-- RLS on with no policy: invisible to anon/authenticated even if granted.
alter table "public"."pricing_catalog_history"
  enable row level security;

-- Hash of canon, so the key stays small however large the price list is.
alter table "public"."pricing_catalog_history"
  add column "canon_md5" text generated always as (md5((canon)::text)) stored not null;

comment on column public.pricing_catalog_history.canon_md5 is 'md5 of canon::text (generated). Part of the primary key; lookups match it and then compare canon itself.';

-- One row per distinct list per arena; _sync_apply upserts on it.
alter table "public"."pricing_catalog_history"
  add constraint "pricing_catalog_history_pkey" primary key (arena_id, canon_md5);

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."pricing_catalog_history"
  to "postgres", "service_role";

revoke all on table "public".pricing_catalog_history from anon;

revoke all on table "public".pricing_catalog_history from authenticated;
