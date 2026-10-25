-- games — the arena's game library
--
-- One row per title the arena offers. Written by op_game_upsert (game.upsert),
-- op_game_set_active (game.set_active: archive / restore) and op_game_delete
-- (game.delete: only a game nothing ever referred to; a used game is archived instead,
-- since session_segments and controller_allocations keep pointing at
-- it with no cascade); op_session_start and op_session_reconfigure bump
-- last_played_at. max_local_players caps the controllers one system may use on this game
-- (players_exceeded otherwise). Per-station availability lives in game_resources, button
-- guides in game_controls (both deleted with the game).
create table "public"."games" (
  "id"                uuid                     not null default gen_random_uuid(),
  "arena_id"          uuid                     not null,
  "name"              text                     not null,
  "aliases"           text[]                   not null default '{}'::text[],
  "category_id"       uuid,
  "platforms"         text[]                   not null default '{}'::text[],
  "max_local_players" integer                  not null default 1,
  "active"            boolean                  not null default true,
  "last_played_at"    timestamp with time zone,
  "created_at"        timestamp with time zone not null default now(),
  "updated_at"        timestamp with time zone not null default now(),
  "sync_xid"          xid8                     not null default pg_current_xact_id(),
  "age_rating"        smallint,
  "media"             text,
  "play_modes"        text[]                   not null default '{single}'::text[],
  constraint "games_age_rating_check"
    check (((age_rating >= 3) AND (age_rating <= 18))),
  constraint "games_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "games_arena_id_name_key" unique (arena_id, name),
  -- Deleting a category leaves its games uncategorised.
  constraint "games_category_id_fkey" foreign key (category_id)
    references public.game_categories(id) on delete set null,
  constraint "games_max_local_players_check"
    check (((max_local_players >= 1) AND (max_local_players <= 8))),
  constraint "games_media_check"
    check ((media = ANY (ARRAY['digital'::text, 'disc'::text]))),
  constraint "games_pkey" primary key (id),
  constraint "games_play_modes_check"
    check (((cardinality(play_modes) >= 1) AND (play_modes <@ ARRAY['story'::text, 'single'::text, 'local'::text, 'online'::text])))
);

comment on table public.games is 'Game titles in an arena''s library, with search aliases, platforms, player limits and an active flag.';

comment on column public.games.arena_id is 'Owning arena (tenant). RLS limits reads to arenas the caller is an active member of.';

comment on column public.games.age_rating is 'Minimum age the title is rated for, a whole number of years from 3 to 18; null when not set. Shown on the admin dashboard; the floor app does not read it yet.';

comment on column public.games.media is 'How the arena owns the title: digital or disc; null when not set. Shown on the admin dashboard; the floor app does not read it yet.';

comment on column public.games.aliases is 'Alternative names used for search (e.g. FIFA for EA SPORTS FC 25).';

comment on column public.games.category_id is 'Optional game_categories row; set to null if the category is deleted.';

comment on column public.games.platforms is 'Platform tags the title runs on (e.g. PS5, PSVR2). Free text; not validated.';

comment on column public.games.play_modes is 'How the title can be played, one or more of story (story mode / campaign), single (single player, e.g. against the computer), local (local multiplayer), online (online multiplayer); listed in that order.';

comment on column public.games.max_local_players is 'Most players (controllers) one system may use at once on this title, 1-8. Starts and reconfigures above it are refused with players_exceeded.';

comment on column public.games.active is 'False archives the title: hidden from new sessions and bookings on every device, kept for the sessions, bills and bookings that refer to it (game.set_active).';

comment on column public.games.last_played_at is 'Start time (UTC) of the latest session segment on this game.';

comment on column public.games.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); change-feed cursor for sync_pull.';

alter table "public"."games"
  enable row level security;

create index ix_games_active on public.games using btree (arena_id, active);

create index ix_games_sync on public.games using btree (arena_id, sync_xid);

-- Foreign-key index (joins and cascading deletes).
create index ix_games_category_id on public.games using btree (category_id);

create trigger t_games_sync
  before insert or update on public.games
  for each row
  execute function public.sync_stamp();

create trigger t_games_tomb
  after delete on public.games
  for each row
  execute function public.sync_record_delete();

create trigger t_games_updated
  before update on public.games
  for each row
  execute function public.set_updated_at();

-- The category must belong to the game's arena (raises cross_arena_reference).
create trigger t_same_arena
  before insert or update on public.games
  for each row
  execute function public._assert_same_arena('category_id', 'game_categories');

create policy "p_sel_games" on "public"."games"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids() as app_arena_ids)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."games"
  to "postgres", "service_role";

revoke all on table "public"."games" from "anon";

revoke all on table "public"."games" from "authenticated";

grant select on table "public"."games" to "authenticated";