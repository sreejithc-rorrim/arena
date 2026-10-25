-- session_segments — one stretch of a single session on one station/game/controller setup
--
-- A session is a parent row plus segments; the open segment (ended_at null) is
-- where the player is now. op_session_start inserts idx 0; op_session_reconfigure
-- (switch station / change game / change controllers) closes the open segment
-- and inserts idx + 1; op_session_end / op_session_void close it. At most one
-- open segment per station: ux_one_open_segment_per_resource plus trigger
-- assert_resource_free_for_segment.
create table "public"."session_segments" (
  "id"               uuid                     not null default gen_random_uuid(),
  "arena_id"         uuid                     not null,
  "session_id"       uuid                     not null,
  "idx"              integer                  not null,
  "resource_id"      uuid                     not null,
  "activity_code"    text                     not null,
  "game_id"          uuid,
  "controller_count" integer,
  "started_at"       timestamp with time zone not null,
  "ended_at"         timestamp with time zone,
  "request_id"       text,
  "created_at"       timestamp with time zone not null default now(),
  "sync_xid"         xid8                     not null default pg_current_xact_id(),
  constraint "session_segments_arena_id_activity_code_fkey" foreign key (arena_id, activity_code)
    references public.activities(arena_id, code),
  constraint "session_segments_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "session_segments_check" check (((ended_at IS NULL) OR (ended_at >= started_at))),
  -- 4 = controller port capacity of one station.
  constraint "session_segments_controller_count_check"
    check (((controller_count >= 1) AND (controller_count <= 4))),
  constraint "session_segments_game_id_fkey" foreign key (game_id) references public.games(id),
  constraint "session_segments_pkey" primary key (id),
  constraint "session_segments_resource_id_fkey" foreign key (resource_id)
    references public.resources(id),
  constraint "session_segments_session_id_idx_key" unique (session_id, idx),
  constraint "session_segments_session_id_fkey" foreign key (session_id)
    references public.sessions(id) on delete cascade
);

comment on table public.session_segments is 'One stretch of a single session on one station, activity, game and controller count. The open segment (ended_at null) is where the session is now; at most one open segment per station.';

comment on column public.session_segments.arena_id is 'Owning arena (tenant); RLS shows the row only to active members of this arena.';

comment on column public.session_segments.idx is '0-based position of the segment within its session (start = 0, each reconfigure + 1); unique per session.';

comment on column public.session_segments.resource_id is 'Station (resource) played on during this segment.';

comment on column public.session_segments.activity_code is 'Activity business code (not uuid), tied to the arena''s catalog by the composite FK; selects the rate from the session''s pricing_snapshot.';

comment on column public.session_segments.controller_count is 'Controllers in use on the station (1 to 4, the port capacity); selects the controller-count rate. Null when not applicable.';

comment on column public.session_segments.started_at is 'Segment start (UTC), as reported by the device.';

comment on column public.session_segments.ended_at is 'Segment end (UTC); null = the open segment.';

comment on column public.session_segments.request_id is 'Legacy idempotency key from the pre-sync RPCs; sync ops leave it null (they are idempotent by sync_ops.op_id).';

comment on column public.session_segments.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); sync_pull change-feed cursor.';

alter table "public"."session_segments"
  enable row level security;

create index ix_segments_resource_time on public.session_segments
  using btree (resource_id, started_at);

create index ix_segments_session on public.session_segments using btree (session_id, idx);

create index ix_session_segments_sync on public.session_segments using btree (arena_id, sync_xid);

-- One open segment per station (t_segment_resource_free raises the clearer
-- resource_busy first).
create unique index ux_one_open_segment_per_resource on public.session_segments
  using btree (resource_id)
  where (ended_at is null);

-- Legacy request_id idempotency (pre-sync RPCs); sync ops leave request_id null.
create unique index ux_segments_request on public.session_segments
  using btree (arena_id, request_id)
  where (request_id is not null);

-- Foreign-key index (joins and cascading deletes).
create index ix_session_segments_game_id on public.session_segments using btree (game_id);

create index ix_session_segments_activity on public.session_segments using btree (arena_id, activity_code);

-- Referenced game, station and session must belong to this row's arena (cross_arena_reference, 0016).
create trigger t_same_arena
  before insert or update on public.session_segments
  for each row
  execute function
    public._assert_same_arena('game_id', 'games', 'resource_id', 'resources', 'session_id',
    'sessions');

-- Opening a segment locks the station row and raises resource_busy if any other
-- open segment is on it.
create trigger t_segment_resource_free
  before insert or update of resource_id, ended_at on public.session_segments
  for each row
  execute function public.assert_resource_free_for_segment();

-- Change feed: stamp sync_xid on every write; record deletes as tombstones.
create trigger t_session_segments_sync
  before insert or update on public.session_segments
  for each row
  execute function public.sync_stamp();

create trigger t_session_segments_tomb
  after delete on public.session_segments
  for each row
  execute function public.sync_record_delete();

-- Members read their arenas' rows. No write policy: clients change data only through sync_push.
create policy "p_sel_session_segments" on "public"."session_segments"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids() as app_arena_ids)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."session_segments"
  to "postgres", "service_role";

revoke all on table "public"."session_segments" from "anon";

revoke all on table "public"."session_segments" from "authenticated";

grant select on table "public"."session_segments" to "authenticated";