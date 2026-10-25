-- controllers — station accessories (game pads, VR headsets, wheels …), tracked by station
--
-- One row per labelled accessory; the dashboard calls them accessories. kind_id
-- (accessory_kinds) says what it is: only pads (no kind, or a kind with
-- counts_as_controller) are allocated to players and borrowed by session starts;
-- the rest are tracked physically (home, location, moves, status) only. home_resource_id is the station it belongs to,
-- current_resource_id where it physically is now. Moving a pad away from home on
-- loan records the return it owes (loan_return_to / loan_session_ref) and appends
-- a controller_moves row. Written by op_controller_upsert / op_controller_set_status
-- (settings), op_controller_move (controller.move) and the borrow step of session
-- starts (_pad_borrow); seeded by _seed_arena_catalog. Per-player use is
-- in controller_allocations (at most one open allocation per pad).
create table "public"."controllers" (
  "id"                  uuid                     not null default gen_random_uuid(),
  "arena_id"            uuid                     not null,
  "label"               text                     not null,
  "home_resource_id"    uuid                     not null,
  "current_resource_id" uuid                     not null,
  "status"              text                     not null default 'usable'::text,
  "notes"               text,
  "loan_return_to"      text,
  "loan_session_ref"    text,
  "kind_id"             uuid,
  "created_at"          timestamp with time zone not null default now(),
  "updated_at"          timestamp with time zone not null default now(),
  "sync_xid"            xid8                     not null default pg_current_xact_id(),
  constraint "controllers_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "controllers_pkey" primary key (id),
  constraint "controllers_status_check"
    check
    ((status = ANY (ARRAY['usable'::text, 'faulty'::text, 'missing'::text, 'retired'::text,
    'unavailable'::text]))),
  -- No on-delete action: a station that still has pads homed or parked at it
  -- cannot be deleted.
  constraint "controllers_current_resource_id_fkey" foreign key (current_resource_id)
    references public.resources(id),
  constraint "controllers_home_resource_id_fkey" foreign key (home_resource_id)
    references public.resources(id),
  -- A kind in use is retired, never deleted (op_accessory_kind_remove).
  constraint "controllers_kind_id_fkey" foreign key (kind_id) references public.accessory_kinds(id)
);

comment on table public.controllers is 'Station accessories (pads, headsets, wheels …): label, kind, home station, current location, condition and any outstanding loan.';

comment on column public.controllers.kind_id is 'What the accessory is (accessory_kinds). Null = a game pad. Only pads (null, or a kind with counts_as_controller) can be allocated or borrowed by a session start.';

comment on column public.controllers.arena_id is 'Owning arena (tenant). RLS limits reads to arenas the caller is an active member of.';

comment on column public.controllers.label is 'The marking on the pad (e.g. HEX-1), which staff use to find it.';

comment on column public.controllers.home_resource_id is 'Station the pad belongs to and is returned to. Changed only by a permanent move (re-homing, needs settings).';

comment on column public.controllers.current_resource_id is 'Station where the pad physically is now; equals home_resource_id unless it has been moved.';

comment on column public.controllers.status is 'One of usable, faulty, missing, retired, unavailable. Only usable pads count as free and can be borrowed or allocated. While the arena has any non-retired pad, count-only starts are checked against free pads at the station (_inventory_tracked).';

comment on column public.controllers.notes is 'Why the pad is in its current status (e.g. stick drift).';

comment on column public.controllers.loan_return_to is 'Set while the pad is on loan away from home: the home station id (uuid as text) it must go back to; null otherwise.';

comment on column public.controllers.loan_session_ref is 'Set while on loan: the session that owes the return, as s:<sessionId> (app reference string, not a foreign key).';

comment on column public.controllers.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); change-feed cursor for sync_pull.';

alter table "public"."controllers"
  enable row level security;

-- Pads at a station, by status (free/usable pad counts).
create index ix_controllers_at_station on public.controllers
  using btree (current_resource_id, status);

create index ix_controllers_sync on public.controllers using btree (arena_id, sync_xid);

-- Foreign-key index (joins and cascading deletes).
create index ix_controllers_home_resource_id on public.controllers using btree (home_resource_id);

create index ix_controllers_kind_id on public.controllers using btree (kind_id);

create trigger t_controllers_sync
  before insert or update on public.controllers
  for each row
  execute function public.sync_stamp();

create trigger t_controllers_tomb
  after delete on public.controllers
  for each row
  execute function public.sync_record_delete();

create trigger t_controllers_updated
  before update on public.controllers
  for each row
  execute function public.set_updated_at();

-- Both stations and the kind must belong to the pad's arena (raises cross_arena_reference).
create trigger t_same_arena
  before insert or update on public.controllers
  for each row
  execute function
    public._assert_same_arena('current_resource_id', 'resources', 'home_resource_id', 'resources',
      'kind_id', 'accessory_kinds');

create policy "p_sel_controllers" on "public"."controllers"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids() as app_arena_ids)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."controllers"
  to "postgres", "service_role";

revoke all on table "public"."controllers" from "anon";

revoke all on table "public"."controllers" from "authenticated";

grant select on table "public"."controllers" to "authenticated";