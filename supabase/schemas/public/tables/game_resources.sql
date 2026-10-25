-- game_resources — per-station availability of each game
--
-- One row per (game, resource): whether that title can be played there right now.
-- A start or reconfigure that names a game is refused
-- (not_playable) unless the row exists with status 'playable' (_game_playable);
-- no row is treated as not installed.
-- Written by op_game_set_compat (game.set_compat); seeded by _seed_arena_catalog.
-- Keyed by the pair, so it has no id or created_at. Both ends must be in the
-- row's arena (t_same_arena).
create table "public"."game_resources" (
  "arena_id"    uuid                     not null,
  "game_id"     uuid                     not null,
  "resource_id" uuid                     not null,
  "status"      text                     not null,
  "notes"       text,
  "updated_at"  timestamp with time zone default now(),
  "sync_xid"    xid8                     not null default pg_current_xact_id(),
  constraint "game_resources_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "game_resources_pkey" primary key (game_id, resource_id),
  constraint "game_resources_status_check"
    check
    ((status = ANY (ARRAY['playable'::text, 'not_playable'::text, 'not_installed'::text,
    'maintenance'::text, 'temporarily_unavailable'::text]))),
  constraint "game_resources_game_id_fkey" foreign key (game_id) references public.games(id)
    on delete cascade,
  constraint "game_resources_resource_id_fkey" foreign key (resource_id)
    references public.resources(id) on delete cascade
);

comment on table public.game_resources is 'Compatibility matrix: whether a game can be played on a given resource. Only status playable allows a session on that game there.';

comment on column public.game_resources.arena_id is 'Owning arena (tenant). RLS limits reads to arenas the caller is an active member of.';

comment on column public.game_resources.status is 'One of playable, not_playable, not_installed, maintenance, temporarily_unavailable. Anything but playable (or a missing row) blocks the game on that resource.';

comment on column public.game_resources.notes is 'Staff note explaining the status (e.g. why it is not playable).';

comment on column public.game_resources.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); change-feed cursor for sync_pull.';

alter table "public"."game_resources"
  enable row level security;

-- Games available at a station, filtered by status.
create index ix_game_resources_resource on public.game_resources using btree (resource_id, status);

create index ix_game_resources_sync on public.game_resources using btree (arena_id, sync_xid);

create trigger t_game_resources_sync
  before insert or update on public.game_resources
  for each row
  execute function public.sync_stamp();

create trigger t_game_resources_tomb
  after delete on public.game_resources
  for each row
  execute function public.sync_record_delete();

create trigger t_game_resources_updated
  before update on public.game_resources
  for each row
  execute function public.set_updated_at();

-- The game and the resource must belong to the row's arena
-- (raises cross_arena_reference).
create trigger t_same_arena
  before insert or update on public.game_resources
  for each row
  execute function public._assert_same_arena('game_id', 'games', 'resource_id', 'resources');

create policy "p_sel_game_resources" on "public"."game_resources"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids() as app_arena_ids)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."game_resources"
  to "postgres", "service_role";

revoke all on table "public"."game_resources" from "anon";

revoke all on table "public"."game_resources" from "authenticated";

grant select on table "public"."game_resources" to "authenticated";