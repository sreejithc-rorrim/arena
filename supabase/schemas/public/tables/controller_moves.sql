-- controller_moves — append-only location history of physical pads
--
-- One row per physical carry of a pad between stations. Written by _pad_borrow
-- (pads brought to a station inside session.start / reconfigure: kind loan, or returnHome when the target is the pad's home) and by
-- op_controller_move (explicit loan / returnHome, needs start or settings;
-- permanent re-home, needs settings). A row is appended only when the pad
-- actually changes place, so a retried move records no extra history.
create table "public"."controller_moves" (
  "id"               uuid                     not null default gen_random_uuid(),
  "arena_id"         uuid                     not null,
  "controller_id"    uuid                     not null,
  "from_resource_id" uuid                     not null,
  "to_resource_id"   uuid                     not null,
  "kind"             text                     not null,
  "session_ref"      text,
  "moved_at"         timestamp with time zone not null,
  "created_by"       uuid,
  "created_at"       timestamp with time zone not null default now(),
  "sync_xid"         xid8                     not null default pg_current_xact_id(),
  constraint "controller_moves_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "controller_moves_created_by_fkey" foreign key (created_by) references auth.users(id),
  constraint "controller_moves_kind_check"
    check ((kind = ANY (ARRAY['loan'::text, 'permanent'::text, 'returnHome'::text]))),
  constraint "controller_moves_pkey" primary key (id),
  constraint "controller_moves_controller_id_fkey" foreign key (controller_id)
    references public.controllers(id),
  constraint "controller_moves_from_resource_id_fkey" foreign key (from_resource_id)
    references public.resources(id),
  constraint "controller_moves_to_resource_id_fkey" foreign key (to_resource_id)
    references public.resources(id)
);

comment on table public.controller_moves is 'Append-only history of physical pad carries between stations (loan, permanent re-home, return home).';

comment on column public.controller_moves.arena_id is 'Owning arena (tenant); RLS shows the row only to active members of this arena.';

comment on column public.controller_moves.from_resource_id is 'Station the pad actually was at (not necessarily its home).';

comment on column public.controller_moves.to_resource_id is 'Station the pad was carried to.';

comment on column public.controller_moves.kind is 'loan (pad owes a return to its home), permanent (to_resource_id becomes its new home) or returnHome (back to its home; loan cleared).';

comment on column public.controller_moves.session_ref is 'For a loan, the borrowing session as app text ''s:<session id>'' (not an FK); null otherwise.';

comment on column public.controller_moves.moved_at is 'When the pad was carried (UTC), as reported by the device (or the server time if none was sent).';

comment on column public.controller_moves.created_by is 'auth.users id of the staff member whose sync op moved the pad.';

comment on column public.controller_moves.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); sync_pull change-feed cursor.';

alter table "public"."controller_moves"
  enable row level security;

create index ix_controller_moves_sync on public.controller_moves using btree (arena_id, sync_xid);

create index ix_moves_controller on public.controller_moves using btree (controller_id, moved_at);

-- Foreign-key index (joins and cascading deletes).
create index ix_controller_moves_created_by on public.controller_moves using btree (created_by);

create index ix_controller_moves_from_resource_id on public.controller_moves using btree (from_resource_id);

create index ix_controller_moves_to_resource_id on public.controller_moves using btree (to_resource_id);

-- Change feed: stamp sync_xid on every write; record deletes as tombstones.
create trigger t_controller_moves_sync
  before insert or update on public.controller_moves
  for each row
  execute function public.sync_stamp();

create trigger t_controller_moves_tomb
  after delete on public.controller_moves
  for each row
  execute function public.sync_record_delete();

-- Referenced pad and both stations must belong to this row's arena (cross_arena_reference, 0016).
create trigger t_same_arena
  before insert or update on public.controller_moves
  for each row
  execute function
    public._assert_same_arena('controller_id', 'controllers', 'from_resource_id', 'resources',
    'to_resource_id', 'resources');

-- Append-only: corrections are new rows (_append_only).
create trigger t_controller_moves_append_only
  before update or delete on public.controller_moves
  for each row
  execute function public._append_only();

-- Members read their arenas' rows. No write policy: clients change data only through sync_push.
create policy "p_sel_controller_moves" on "public"."controller_moves"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids() as app_arena_ids)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."controller_moves"
  to "postgres", "service_role";

revoke all on table "public"."controller_moves" from "anon";

revoke all on table "public"."controller_moves" from "authenticated";

grant select on table "public"."controller_moves" to "authenticated";