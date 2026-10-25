-- controller_allocations — append-only timeline of which physical pad is in whose hands
--
-- One row per pad handed to a single-session segment (scope single). Inserted by
-- _pad_allocate inside session.start / reconfigure; ended_at is set when that
-- segment closes (reconfigure, end, void).
-- A pad is in at most one open allocation: ux_one_open_allocation_per_controller
-- plus trigger assert_controller_free_for_allocation (raises controller_taken).
create table "public"."controller_allocations" (
  "id"            uuid                     not null default gen_random_uuid(),
  "arena_id"      uuid                     not null,
  "controller_id" uuid                     not null,
  "scope"         text                     not null,
  "session_id"    uuid,
  "segment_id"    uuid,
  "resource_id"   uuid                     not null,
  "activity_code" text                     not null,
  "game_id"       uuid,
  "started_at"    timestamp with time zone not null,
  "ended_at"      timestamp with time zone,
  "request_id"    text,
  "created_by"    uuid,
  "created_at"    timestamp with time zone not null default now(),
  "sync_xid"      xid8                     not null default pg_current_xact_id(),
  constraint "controller_allocations_arena_id_activity_code_fkey"
    foreign key (arena_id, activity_code) references public.activities(arena_id, code),
  constraint "controller_allocations_arena_id_fkey" foreign key (arena_id)
    references public.arenas(id) on delete cascade,
  constraint "controller_allocations_check"
    check (((ended_at IS NULL) OR (ended_at >= started_at))),
  constraint "controller_allocations_created_by_fkey" foreign key (created_by)
    references auth.users(id),
  constraint "controller_allocations_pkey" primary key (id),
  constraint "controller_allocations_scope_check"
    check ((scope = 'single'::text)),
  constraint "controller_allocations_controller_id_fkey" foreign key (controller_id)
    references public.controllers(id),
  constraint "controller_allocations_game_id_fkey" foreign key (game_id)
    references public.games(id),
  constraint "controller_allocations_resource_id_fkey" foreign key (resource_id)
    references public.resources(id),
  constraint "controller_allocations_segment_id_fkey" foreign key (segment_id)
    references public.session_segments(id),
  constraint "controller_allocations_session_id_fkey" foreign key (session_id)
    references public.sessions(id) on delete cascade
);

comment on table public.controller_allocations is 'Append-only per-pad timeline: which physical controller was used by which session segment, where, and when. An open row (ended_at null) means the pad is in a player''s hands.';

comment on column public.controller_allocations.arena_id is 'Owning arena (tenant); RLS shows the row only to active members of this arena.';

comment on column public.controller_allocations.scope is 'Always single (session_id + segment_id set); kept for the device''s row shape.';

comment on column public.controller_allocations.session_id is 'Single session holding the pad (scope single).';

comment on column public.controller_allocations.segment_id is 'Session segment the pad belongs to (scope single); closed with it.';

comment on column public.controller_allocations.resource_id is 'Station where the pad is used; may differ from the pad''s home after a borrow.';

comment on column public.controller_allocations.activity_code is 'Activity business code of the play the pad was used for.';

comment on column public.controller_allocations.started_at is 'When the pad was handed out (UTC; the segment start).';

comment on column public.controller_allocations.ended_at is 'When the pad was released (UTC); null = still in use.';

comment on column public.controller_allocations.request_id is 'Legacy idempotency key from the pre-sync RPCs; sync ops leave it null (they are idempotent by sync_ops.op_id).';

comment on column public.controller_allocations.created_by is 'auth.users id of the staff member whose sync op allocated the pad.';

comment on column public.controller_allocations.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); sync_pull change-feed cursor.';

alter table "public"."controller_allocations"
  enable row level security;

create index ix_alloc_open_by_resource on public.controller_allocations using btree (resource_id)
  where (ended_at is null);

-- Legacy request_id lookup (pre-sync RPCs); sync ops leave request_id null.
create index ix_alloc_request on public.controller_allocations using btree (arena_id, request_id)
  where (request_id is not null);

create index ix_alloc_session on public.controller_allocations using btree (session_id);

create index ix_controller_allocations_sync on public.controller_allocations
  using btree (arena_id, sync_xid);

-- A physical pad can be in at most one open allocation.
create unique index ux_one_open_allocation_per_controller on public.controller_allocations
  using btree (controller_id)
  where (ended_at is null);

-- Foreign-key index (joins and cascading deletes).
create index ix_controller_allocations_created_by on public.controller_allocations using btree (created_by);

create index ix_controller_allocations_game_id on public.controller_allocations using btree (game_id);

create index ix_controller_allocations_segment_id on public.controller_allocations using btree (segment_id);

create index ix_controller_allocations_activity on public.controller_allocations using btree (arena_id, activity_code);

-- Change feed: stamp sync_xid on every write; record deletes as tombstones.
create trigger t_controller_allocations_sync
  before insert or update on public.controller_allocations
  for each row
  execute function public.sync_stamp();

create trigger t_controller_allocations_tomb
  after delete on public.controller_allocations
  for each row
  execute function public.sync_record_delete();

-- Opening an allocation locks the controller row and raises controller_taken if
-- the pad already has an open allocation (clear error ahead of the unique index).
create trigger t_controller_free
  before insert or update of controller_id, ended_at on public.controller_allocations
  for each row
  execute function public.assert_controller_free_for_allocation();

-- Every referenced row (pad, station, game, session, segment)
-- must belong to this row's arena (cross_arena_reference, 0016).
create trigger t_same_arena
  before insert or update on public.controller_allocations
  for each row
  execute function
    public._assert_same_arena('controller_id', 'controllers', 'game_id', 'games', 'resource_id',
    'resources', 'segment_id', 'session_segments', 'session_id', 'sessions');

-- Members read their arenas' rows. No write policy: clients change data only through sync_push.
create policy "p_sel_controller_allocations" on "public"."controller_allocations"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids() as app_arena_ids)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."controller_allocations"
  to "postgres", "service_role";

revoke all on table "public"."controller_allocations" from "anon";

revoke all on table "public"."controller_allocations" from "authenticated";

grant select on table "public"."controller_allocations" to "authenticated";