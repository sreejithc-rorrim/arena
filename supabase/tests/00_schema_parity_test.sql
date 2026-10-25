-- Schema parity: the Postgres schema is a strict superset of Drift v11.
-- Runs as the db owner; no auth needed.
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated fixture: this file works in its OWN arena (the same starter catalog
-- seed.sql uses), so whatever else is in the database — the dev seed, arenas
-- left by the two-device suite, a half-finished run — cannot change what it
-- sees. Created inside this transaction and rolled back with it.
insert into arenas(id, name) values ('e0000000-0000-4000-8000-000000000000'::uuid, 'pgtap 00');
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000000'::uuid);

-- Tables that must exist (incl. the ones 0004 adds and the previously-missing
-- controllers table).
select has_table('public', t, 'table ' || t || ' exists')
from unnest(array[
  'arenas','staff_profiles','activities','resources','controllers',
  'resource_activities','customers','rate_cards','rate_bands','rates',
  'billing_policies','holidays','game_categories','games','game_controls',
  'game_resources','bookings','sessions','session_segments','session_extensions',
  'session_charges','payments','settings','audit_log'
]) as t;

-- The Drift parent owns no per-stretch config: these live on the open segment.
select hasnt_column('public','sessions', c, 'sessions must not carry ' || c)
from unnest(array['resource_id','activity_id','game_id','controller_count']) as c;

-- Money is bigint paise everywhere.
select col_type_is('public','payments','amount_paise','bigint','payments.amount_paise is bigint');
select col_type_is('public','session_charges','amount_paise','bigint','session_charges.amount_paise is bigint');
select col_type_is('public','rates','price_paise','bigint','rates.price_paise is bigint');
select col_type_is('public','sessions','billed_amount_paise','bigint','sessions.billed_amount_paise is bigint');

-- Time is timestamptz; snapshots are jsonb.
select col_type_is('public','sessions','started_at','timestamp with time zone','started_at is timestamptz');
select col_type_is('public','sessions','pricing_snapshot','jsonb','pricing_snapshot is jsonb');
select col_type_is('public','sessions','policy_snapshot','jsonb','policy_snapshot is jsonb');

-- staff_profiles mirrors Drift users (perms + active); no plaintext pin column.
select has_column('public','staff_profiles','perms','staff_profiles has perms');
select has_column('public','staff_profiles','active','staff_profiles has active');
select hasnt_column('public','staff_profiles','pin','no plaintext pin on staff_profiles');

-- resources.status widened to the full ResourceStatus enum.
select ok(
  (select pg_get_constraintdef(oid) from pg_constraint where conname='resources_status_check')
    like '%temporarily_unavailable%',
  'resources.status CHECK includes temporarily_unavailable');

-- games carries play_modes + max_local_players + last_played_at (exactly once).
select has_column('public','games','play_modes','games.play_modes');
select has_column('public','games','max_local_players','games.max_local_players');
select has_column('public','games','last_played_at','games.last_played_at');

-- Composite (arena_id, activity_code) FKs to activities(arena_id, code).
select ok(exists(
  select 1 from pg_constraint
   where contype='f' and conrelid = ('public.'||t)::regclass
     and pg_get_constraintdef(oid) like '%activities(arena_id, code)%'),
  t || ' has composite activity FK')
from unnest(array['session_segments','session_charges']) as t;

-- Idempotency: request_id partial-unique indexes on every table a retry can hit.
select has_index('public', t, 'ux_' || base || '_request', t || ' has request_id unique index')
from (values
  ('sessions','sessions'),('session_extensions','extensions'),('payments','payments'),
  ('session_segments','segments')
) as x(t, base);

-- One-open-segment-per-resource partial unique index (mirrors Drift).
select has_index('public','session_segments','ux_one_open_segment_per_resource',
  'session_segments one-open-per-resource unique index');

-- No DELETE policy anywhere (history is append-only).
select is(
  (select count(*)::int from pg_policies where schemaname='public' and cmd='DELETE'),
  0, 'no DELETE policy exists on any table');

select * from finish();
rollback;
