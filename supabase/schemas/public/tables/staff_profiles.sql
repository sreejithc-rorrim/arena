-- staff_profiles — membership of an auth user in an arena, with role and permissions
--
-- One row per (auth user, arena). Active rows are what app_arena_ids() returns, so
-- this table drives every RLS policy and op_* permission check (app_has_perm,
-- app_is_owner). Written by bootstrap_owner (first owner), add_staff_by_email
-- (owner links an existing login) and op_staff_update (staff.update). A
-- role='owner' row always holds every known perm and stays active, and every arena
-- must keep an active member holding 'settings' (_assert_settings_holder).
create table "public"."staff_profiles" (
  "id"         uuid                     not null default gen_random_uuid(),
  "arena_id"   uuid                     not null,
  "user_id"    uuid                     not null,
  "name"       text                     not null,
  "role"       text                     not null default 'staff'::text,
  "perms"      text[]                   not null default '{}'::text[],
  "active"     boolean                  not null default true,
  "sort_order" integer                  not null default 0,
  "created_at" timestamp with time zone not null default now(),
  "updated_at" timestamp with time zone not null default now(),
  "sync_xid"   xid8                     not null default pg_current_xact_id(),
  constraint "staff_profiles_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "staff_profiles_pkey" primary key (id),
  constraint "staff_profiles_role_check" check ((role = ANY (ARRAY['owner'::text, 'staff'::text]))),
  -- A login has at most one profile per arena.
  constraint "staff_profiles_user_id_arena_id_key" unique (user_id, arena_id),
  constraint "staff_profiles_user_id_fkey" foreign key (user_id) references auth.users(id)
    on delete cascade
);

comment on table public.staff_profiles is 'Membership of an auth user in an arena: display name, role and permission codes. Active rows grant read access (app_arena_ids) and op_* permissions.';

comment on column public.staff_profiles.arena_id is 'Owning arena (tenant). RLS limits reads to arenas the caller is an active member of.';

comment on column public.staff_profiles.user_id is 'The Supabase Auth login (auth.users.id) this profile belongs to.';

comment on column public.staff_profiles.role is '''owner'' or ''staff''. An owner implicitly holds every permission (app_has_perm); op_staff_update keeps an owner''s perms complete and the row active.';

comment on column public.staff_profiles.perms is 'Permission codes from _known_perms(): start, bill, discount, members, stations, money, reports, settings, bill_edit, bill_record. Holding money or reports makes the member owner level (app_is_owner).';

comment on column public.staff_profiles.active is 'False revokes all access server-side: app_arena_ids and the permission helpers only consider active rows.';

comment on column public.staff_profiles.sync_xid is 'Id of the transaction that last wrote the row (set by trigger sync_stamp); change-feed cursor for sync_pull.';

alter table "public"."staff_profiles"
  enable row level security;

create index ix_staff_profiles_sync on public.staff_profiles using btree (arena_id, sync_xid);

-- Serves app_arena_ids() / app_has_perm(), which look rows up by auth.uid().
create index ix_staff_user on public.staff_profiles using btree (user_id);

create trigger t_staff_profiles_sync
  before insert or update on public.staff_profiles
  for each row
  execute function public.sync_stamp();

-- Deleted rows leave a sync_tombstones entry so devices drop them on pull.
create trigger t_staff_profiles_tomb
  after delete on public.staff_profiles
  for each row
  execute function public.sync_record_delete();

create trigger t_staff_updated
  before update on public.staff_profiles
  for each row
  execute function public.set_updated_at();

-- Members see the whole roster of their own arena(s); writes go through
-- sync_push / add_staff_by_email only.
create policy "p_sel_staff" on "public"."staff_profiles"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids() as app_arena_ids)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."staff_profiles"
  to "postgres", "service_role";

revoke all on table "public"."staff_profiles" from "anon";

revoke all on table "public"."staff_profiles" from "authenticated";

grant select on table "public"."staff_profiles" to "authenticated";