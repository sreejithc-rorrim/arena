-- resources — bookable places on the floor: stations, tables and rooms
--
-- A session segment occupies one resource; at most one open occupant per
-- resource is enforced elsewhere (session_segments trigger and index). Written by op_resource_upsert
-- (resource.upsert, which also replaces its resource_activities links),
-- op_resource_set_status and op_resource_set_mode; seeded by
-- _seed_arena_catalog. Controllers have a home and a current resource here.
create table "public"."resources" (
  "id"           uuid                     not null default gen_random_uuid(),
  "arena_id"     uuid                     not null,
  "name"         text                     not null,
  "kind"         text                     not null default 'station'::text,
  "status"       text                     not null default 'available'::text,
  "sort_order"   integer                  not null default 0,
  "created_at"   timestamp with time zone not null default now(),
  "updated_at"   timestamp with time zone not null default now(),
  "current_mode" text,
  "sync_xid"     xid8                     not null default pg_current_xact_id(),
  constraint "resources_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "resources_arena_id_name_key" unique (arena_id, name),
  constraint "resources_kind_check"
    check ((kind = ANY (ARRAY['station'::text, 'table'::text, 'room'::text]))),
  constraint "resources_pkey" primary key (id),
  constraint "resources_status_check"
    check
    ((status = ANY (ARRAY['available'::text, 'maintenance'::text, 'temporarily_unavailable'::text,
    'disabled'::text])))
);

comment on table public.resources is 'Bookable places on the floor (gaming stations, pool tables, rooms). Sessions, bookings and controllers point at them.';

comment on column public.resources.arena_id is 'Owning arena (tenant). RLS limits reads to arenas the caller is an active member of.';

comment on column public.resources.name is 'Display name, unique within the arena (e.g. HEX, Pool Table 1).';

comment on column public.resources.kind is 'One of station, table, room.';

comment on column public.resources.status is 'One of available, maintenance, temporarily_unavailable, disabled. Set by resource.upsert / resource.set_status.';

comment on column public.resources.current_mode is 'Activity code the resource is locked to (e.g. a PS5/VR station in VR mode); null = not mode-locked. Starts for another activity are refused (_mode_ok); changed by resource.set_mode only while nothing is open on it.';

comment on column public.resources.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); change-feed cursor for sync_pull.';

alter table "public"."resources"
  enable row level security;

create index ix_resources_sync on public.resources using btree (arena_id, sync_xid);

create trigger t_resources_sync
  before insert or update on public.resources
  for each row
  execute function public.sync_stamp();

create trigger t_resources_tomb
  after delete on public.resources
  for each row
  execute function public.sync_record_delete();

create trigger t_resources_updated
  before update on public.resources
  for each row
  execute function public.set_updated_at();

create policy "p_sel_resources" on "public"."resources"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids() as app_arena_ids)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."resources"
  to "postgres", "service_role";

revoke all on table "public"."resources" from "anon";

revoke all on table "public"."resources" from "authenticated";

grant select on table "public"."resources" to "authenticated";