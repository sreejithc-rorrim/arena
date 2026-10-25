-- Pre-release data reset — production project oilylxydibubupuqghbw
--
-- STATUS: NOT EXECUTED. Prepared 2026-10-22 from supabase/schemas; it has never
-- been run against any database (production, staging or local).
--
-- What it does, in ONE transaction:
--   * removes the activity of the arenas listed in STEP 1 (sessions, bookings,
--     payments, charges, discounts applied, pad allocations and moves, audit log,
--     attendance, leave, salary runs, op log, tombstones; customers unless kept);
--   * 'remove_arena' arenas additionally lose their configuration and people;
--   * deletes the test logins listed in STEP 1, and their staff records;
--   * never touches the schema, migrations, extensions, indexes, functions, RLS
--     policies, grants or any arena / login that is not listed.
-- The append-only guard (payments, charges, audit log, punches, pad moves, …) is
-- lifted for this transaction only and checked back on before commit. Foreign keys
-- stay enforced, so a missed dependency stops the reset instead of orphaning rows.
-- (Never delete under `set session_replication_role = replica`: that also turns off
-- every foreign-key cascade and check, so deleting an arena that way would orphan
-- all of its rows.)
--
-- By default it is a DRY RUN: it performs every step, reports what would go in its
-- error message, and rolls everything back. Only really_delete = true together with
-- confirm_text = 'DELETE PRE-RELEASE DATA' commits.
--
-- ─── RUNBOOK (only after the owner's explicit written approval) ───────────────────
--  1. Inventory: run prod_prerelease_inventory.sql Q0–Q7 in the production SQL
--     Editor; export each result (CSV) outside the repo. Decide, with the owner, which
--     arenas are test (Q2), which mode each gets, and which logins are test (Q3, Q4).
--     Anything not confirmed in writing stays.
--  2. Freeze: uninstall the app from every device used before release (the outbox of
--     an old install would re-push its test operations after the reset), and keep the
--     admin web closed. Pick a quiet window.
--  3. Backup (person with access to the project's organization):
--     a. Dashboard → Database → Backups: note the plan, the newest backup and whether
--        PITR is on. If it lists none, step 3b is the only way back.
--     b. Logical dump outside the repo (needs Docker; the password is typed, never
--        stored; the repo's `--linked` project is the OLD dev project, never use it):
--          mkdir -p ~/arena-prod-backups && chmod 700 ~/arena-prod-backups && cd ~/arena-prod-backups
--          read -rs PW   # database password from the password manager
--          URL="postgresql://postgres.oilylxydibubupuqghbw:$(jq -rn --arg p "$PW" '$p|@uri')@<session-pooler-host>:5432/postgres"
--          supabase db dump --db-url "$URL" --role-only -f roles.sql
--          supabase db dump --db-url "$URL" -f schema.sql
--          supabase db dump --db-url "$URL" --data-only --use-copy -f data.sql
--          unset PW URL
--        (<session-pooler-host>: Dashboard → Connect → Session pooler.)
--     c. Prove it restores, into a THROWAWAY stack, never the arena_ops one:
--          mkdir ~/arena-restore-test && cd ~/arena-restore-test && supabase init
--          (config.toml: project_id = "arena-restore-test", every port +1000)
--          supabase start
--          docker run --rm -v ~/arena-prod-backups:/b postgres:17 psql \
--            "postgresql://postgres:postgres@host.docker.internal:55322/postgres" \
--            --single-transaction -v ON_ERROR_STOP=1 -f /b/roles.sql -f /b/schema.sql \
--            -c 'set session_replication_role = replica' -f /b/data.sql
--        Run inventory Q0 in that stack's Studio and compare with production's Q0
--        (every table, plus auth users). Equal counts = the evidence. Then
--        `supabase stop --no-backup` and delete the folder (it holds personal data).
--  4. Fill in STEP 1 below. Paste the whole file into the production SQL Editor and
--     run it as is (dry run). Read the "DRY RUN" message: every number must match what
--     the owner approved. Re-run inventory Q0/Q1 to confirm nothing changed.
--  5. Real run: set really_delete = true and confirm_text = 'DELETE PRE-RELEASE DATA',
--     run once. The final result lists each table's rows before → after.
--  6. Verify: inventory Q0–Q7 again (Q7 must equal the step-1 baseline except the
--     auth user count), Advisors → Security, supabase/audit/security_audit.sql, then
--     the app checks (owner sign-in, invite → accept, fresh install, sync).
--  After the commit there is no undo except restoring a backup (step 3).
-- ──────────────────────────────────────────────────────────────────────────────────

begin;

set local lock_timeout = '10s';
set local statement_timeout = '15min';

-- ═══ STEP 1 of 2 — FILL IN from the saved inventory and the owner's confirmation ═══

create temp table reset_cfg (
  really_delete  boolean     not null,
  confirm_text   text        not null,
  newest_allowed timestamptz not null,
  keep_customers boolean     not null
) on commit drop;

insert into reset_cfg (really_delete, confirm_text, newest_allowed, keep_customers) values (
  false,                        -- false = dry run: does everything, reports, rolls back
  '',                           -- real run only: 'DELETE PRE-RELEASE DATA'
  '2000-01-01 00:00+05:30',     -- REPLACE: refuse if a listed arena has activity at/after this
  false                         -- true keeps the customer list of 'wipe_activity' arenas
);

create temp table reset_arenas (
  id            uuid primary key,
  expected_name text not null,
  mode          text not null check (mode in ('wipe_activity', 'remove_arena'))
) on commit drop;

-- wipe_activity: keep the arena, its configuration and its people; delete its activity.
-- remove_arena:  delete the arena and everything that belongs to it.
insert into reset_arenas (id, expected_name, mode) values
  ('00000000-0000-0000-0000-000000000000', 'REPLACE ME', 'wipe_activity');

create temp table reset_users (
  id             uuid primary key,
  expected_email text not null
) on commit drop;

-- Test logins to delete; leave commented out to delete none. Real accounts never go here.
-- insert into reset_users (id, expected_email) values
--   ('00000000-0000-0000-0000-000000000000', 'tester@example.com');

-- ═══ STEP 2 of 2 — the reset (no edits below this line) ═══

drop table if exists pg_temp.reset_report;
create temp table reset_report (
  table_name text primary key,
  before     bigint not null,
  after      bigint
) on commit preserve rows;

do $reset$
declare
  cfg  record;
  r    record;
  t    text;
  n    bigint;
  v_ts text;
  v_report text;
  -- Child tables first: each table comes after every table that points at it.
  v_activity constant text[] := array[
    'bill_discounts', 'controller_allocations', 'session_charges', 'payments',
    'session_extensions', 'session_segments', 'sessions', 'bookings',
    'customers', 'controller_moves', 'audit_log', 'attendance_entries', 'attendance_punches',
    'leave_adjustments', 'leave_requests', 'salary_deduction_decisions', 'salary_adjustments',
    'salary_run_lines', 'salary_runs'];
  -- A deleted login's staff records in a kept arena (activity is already gone).
  v_staff constant text[] := array[
    'staff_terms_acceptances', 'staff_shifts', 'staff_pay_rates', 'staff_personal_details',
    'staff_hr_profiles'];
  -- Tables guarded by t_<table>_append_only.
  v_guarded constant text[] := array[
    'payments', 'session_charges', 'bill_discounts',
    'audit_log', 'salary_adjustments', 'attendance_punches', 'controller_moves'];
begin
  select * into strict cfg from reset_cfg;

  -- G1. STEP 1 was filled in.
  if exists (select 1 from reset_arenas
              where id = '00000000-0000-0000-0000-000000000000' or expected_name = 'REPLACE ME')
     or exists (select 1 from reset_users where id = '00000000-0000-0000-0000-000000000000') then
    raise exception 'reset: replace the placeholder rows in STEP 1 first';
  end if;
  if not exists (select 1 from reset_arenas) and not exists (select 1 from reset_users) then
    raise exception 'reset: STEP 1 lists no arena and no login';
  end if;
  if cfg.newest_allowed < '2000-01-02'::timestamptz then
    raise exception 'reset: set newest_allowed in STEP 1';
  end if;

  -- G2. Every listed arena exists under exactly the expected name.
  for r in select ra.id, ra.expected_name, a.id as found, a.name
             from reset_arenas ra left join public.arenas a on a.id = ra.id loop
    if r.found is null then
      raise exception 'reset: arena % does not exist', r.id;
    elsif r.name is distinct from r.expected_name then
      raise exception 'reset: arena % is named "%", not "%"', r.id, r.name, r.expected_name;
    end if;
  end loop;

  -- G3. Every listed login exists under exactly the expected e-mail.
  for r in select ru.id, ru.expected_email, u.id as found, u.email
             from reset_users ru left join auth.users u on u.id = ru.id loop
    if r.found is null then
      raise exception 'reset: login % does not exist', r.id;
    elsif lower(r.email) is distinct from lower(r.expected_email) then
      raise exception 'reset: login % is "%", not "%"', r.id, r.email, r.expected_email;
    end if;
  end loop;

  -- G4. A login being deleted belongs to no arena outside this reset.
  for r in select u.email, a.name
             from public.staff_profiles sp
             join public.arenas a on a.id = sp.arena_id
             join auth.users u on u.id = sp.user_id
            where sp.user_id in (select id from reset_users)
              and sp.arena_id not in (select id from reset_arenas) loop
    raise exception 'reset: % is a member of arena "%", which this reset does not touch',
      r.email, r.name;
  end loop;

  -- G5. Every kept arena keeps at least one active owner.
  for r in select ra.expected_name from reset_arenas ra
            where ra.mode = 'wipe_activity'
              and not exists (select 1 from public.staff_profiles sp
                               where sp.arena_id = ra.id and sp.role = 'owner' and sp.active
                                 and sp.user_id not in (select id from reset_users)) loop
    raise exception 'reset: arena "%" would be left without an active owner', r.expected_name;
  end loop;

  -- G6. No listed arena has activity at or after newest_allowed (it could be real business).
  foreach t in array v_activity || array['sync_ops'] loop
    v_ts := (select c.column_name from information_schema.columns c
              where c.table_schema = 'public' and c.table_name = t
                and c.column_name in ('created_at', 'server_at')
              order by c.column_name = 'created_at' desc
              limit 1);
    continue when v_ts is null;
    execute format('select count(*) from public.%I where arena_id in (select id from reset_arenas) and %I >= $1',
                   t, v_ts)
      into n using cfg.newest_allowed;
    if n > 0 then
      raise exception 'reset: % has % row(s) at or after % in a listed arena: refusing',
        t, n, cfg.newest_allowed;
    end if;
  end loop;

  -- Counts before: the listed arenas' rows in every public table, the arenas, the logins.
  for r in select c.table_name::text as tn
             from information_schema.columns c
             join pg_tables pt on pt.schemaname = 'public' and pt.tablename = c.table_name
            where c.table_schema = 'public' and c.column_name = 'arena_id' loop
    execute format('select count(*) from public.%I where arena_id in (select id from reset_arenas)', r.tn)
      into n;
    insert into reset_report (table_name, before) values (r.tn, n);
  end loop;
  insert into reset_report (table_name, before)
    values ('arenas', (select count(*) from public.arenas where id in (select id from reset_arenas))),
           ('auth.users', (select count(*) from auth.users where id in (select id from reset_users)));

  -- Lift the append-only guard for this transaction only.
  foreach t in array v_guarded loop
    execute format('alter table public.%I disable trigger %I', t, 't_' || t || '_append_only');
  end loop;

  -- Activity of every listed arena (both modes), child tables first.
  foreach t in array v_activity loop
    continue when t = 'customers' and cfg.keep_customers
                  and not exists (select 1 from reset_arenas where mode = 'remove_arena');
    if t = 'customers' and cfg.keep_customers then
      delete from public.customers
       where arena_id in (select id from reset_arenas where mode = 'remove_arena');
    else
      execute format('delete from public.%I where arena_id in (select id from reset_arenas)', t);
    end if;
  end loop;

  -- Kept arenas: a deleted login's staff records and the invitations sent to it.
  foreach t in array v_staff loop
    execute format(
      'delete from public.%I where staff_id in (
         select sp.id from public.staff_profiles sp
           join reset_arenas ra on ra.id = sp.arena_id and ra.mode = %L
          where sp.user_id in (select id from reset_users))', t, 'wipe_activity');
  end loop;
  delete from public.staff_profiles sp using reset_arenas ra
   where ra.id = sp.arena_id and ra.mode = 'wipe_activity'
     and sp.user_id in (select id from reset_users);
  delete from public.staff_invites i using reset_arenas ra
   where ra.id = i.arena_id and ra.mode = 'wipe_activity'
     and i.email in (select lower(u.email) from auth.users u
                      where u.id in (select id from reset_users) and u.email is not null);

  -- remove_arena: the foreign-key cascades remove its configuration and people.
  delete from public.arenas where id in (select id from reset_arenas where mode = 'remove_arena');

  -- The listed logins (their identities, sessions and refresh tokens go with them). A row
  -- that still points at one ('no action' in inventory Q4) stops the whole reset here.
  delete from auth.users where id in (select id from reset_users);

  -- Op log and tombstones last: the deletes above wrote tombstones holding whole old rows,
  -- and reinstalled devices start from an empty cursor, so they need none of them.
  delete from public.sync_ops where arena_id in (select id from reset_arenas);
  delete from public.sync_tombstones where arena_id in (select id from reset_arenas);

  -- Put the guard back and prove it.
  foreach t in array v_guarded loop
    execute format('alter table public.%I enable trigger %I', t, 't_' || t || '_append_only');
  end loop;
  if (select count(*) from pg_trigger
       where not tgisinternal and tgenabled = 'O'
         and tgname in (select 't_' || g || '_append_only' from unnest(v_guarded) g))
     <> cardinality(v_guarded) then
    raise exception 'reset: an append-only guard is not enabled again';
  end if;

  -- Counts after.
  for r in select table_name from reset_report loop
    if r.table_name = 'arenas' then
      n := (select count(*) from public.arenas where id in (select id from reset_arenas));
    elsif r.table_name = 'auth.users' then
      n := (select count(*) from auth.users where id in (select id from reset_users));
    else
      execute format('select count(*) from public.%I where arena_id in (select id from reset_arenas)',
                     r.table_name)
        into n;
    end if;
    update reset_report set after = n where table_name = r.table_name;
  end loop;

  -- Prove the outcome: removed arenas have no rows left anywhere; kept arenas no activity.
  if exists (select 1 from reset_report where after > 0 and table_name in
               (select unnest(v_activity || array['sync_ops', 'sync_tombstones']))
               and not (table_name = 'customers' and cfg.keep_customers)) then
    raise exception 'reset: activity rows remain: %',
      (select string_agg(table_name || '=' || after, ', ') from reset_report
        where after > 0 and table_name = any (v_activity || array['sync_ops', 'sync_tombstones']));
  end if;
  for r in select c.table_name::text as tn
             from information_schema.columns c
             join pg_tables pt on pt.schemaname = 'public' and pt.tablename = c.table_name
            where c.table_schema = 'public' and c.column_name = 'arena_id' loop
    execute format('select count(*) from public.%I where arena_id in
                      (select id from reset_arenas where mode = %L)', r.tn, 'remove_arena')
      into n;
    if n > 0 then
      raise exception 'reset: % still has % row(s) of a removed arena', r.tn, n;
    end if;
  end loop;

  select string_agg(table_name || ' ' || before || '→' || after, ', ' order by table_name)
    into v_report
    from reset_report where before <> after;

  if not cfg.really_delete or cfg.confirm_text is distinct from 'DELETE PRE-RELEASE DATA' then
    raise exception 'DRY RUN, rolled back, nothing changed. Would change (rows before→after): %',
      coalesce(v_report, 'nothing');
  end if;
  raise notice 'reset: changed (rows before→after): %', coalesce(v_report, 'nothing');
end
$reset$;

commit;

-- Only reached after a real run: rows of the listed arenas / logins, before → after.
select table_name, before, after from reset_report order by table_name;
