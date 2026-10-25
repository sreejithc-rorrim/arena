-- Who can read money, customer and audit rows directly (dashboard queries and
-- Realtime Postgres Changes both go through these RLS policies), who may use an
-- arena's private Realtime channel, and which tables Realtime announces.
-- Devices receive their arena's rows through sync_pull (SECURITY DEFINER, active
-- members only), which these policies do not change.
begin;
create extension if not exists pgtap;
select * from no_plan();

insert into arenas(id, name) values
  ('e0000000-0000-4000-8000-000000000180', 'pgtap 18 A'),
  ('e0000000-0000-4000-8000-000000000181', 'pgtap 18 B');
-- The test catalog (activity PS5 etc.), so bill lines can reference it.
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000180');
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000181');

insert into auth.users(instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, is_sso_user, is_anonymous)
select '00000000-0000-0000-0000-000000000000', ('18000000-0000-4000-8000-00000000000' || n)::uuid,
       'authenticated', 'authenticated', 'u' || n || '-18@test.local', '', now(), now(), now(),
       '{}', '{}', false, false
  from generate_series(1, 7) n;

insert into staff_profiles(arena_id, user_id, name, role, perms, active) values
  ('e0000000-0000-4000-8000-000000000180', '18000000-0000-4000-8000-000000000001', 'Owner', 'owner', _known_perms(), true),
  ('e0000000-0000-4000-8000-000000000180', '18000000-0000-4000-8000-000000000002', 'Cashier', 'staff', array['start','bill'], true),
  ('e0000000-0000-4000-8000-000000000180', '18000000-0000-4000-8000-000000000003', 'Runner', 'staff', array['start'], true),
  ('e0000000-0000-4000-8000-000000000180', '18000000-0000-4000-8000-000000000004', 'Desk', 'staff', array['members'], true),
  ('e0000000-0000-4000-8000-000000000180', '18000000-0000-4000-8000-000000000005', 'Manager', 'staff', array['reports'], true),
  ('e0000000-0000-4000-8000-000000000180', '18000000-0000-4000-8000-000000000006', 'Gone', 'staff',
    array['start','bill','members','money','reports'], false),
  ('e0000000-0000-4000-8000-000000000181', '18000000-0000-4000-8000-000000000007', 'Owner B', 'owner', _known_perms(), true);

-- One customer, session, bill line, payment and audit entry in each arena.
insert into customers(id, arena_id, name, phone) values
  ('c1800000-0000-4000-8000-00000000000a', 'e0000000-0000-4000-8000-000000000180', 'Asha', '9800001801'),
  ('c1800000-0000-4000-8000-00000000000b', 'e0000000-0000-4000-8000-000000000181', 'Bala', '9800001802');
insert into sessions(id, arena_id, customer_id, started_at, scheduled_end_at, pricing_snapshot, policy_snapshot) values
  ('51800000-0000-4000-8000-00000000000a', 'e0000000-0000-4000-8000-000000000180', 'c1800000-0000-4000-8000-00000000000a',
   now() - interval '2 hours', now() - interval '1 hour', '{}', '{}'),
  ('51800000-0000-4000-8000-00000000000b', 'e0000000-0000-4000-8000-000000000181', 'c1800000-0000-4000-8000-00000000000b',
   now() - interval '2 hours', now() - interval '1 hour', '{}', '{}');
insert into session_charges(arena_id, session_id, segment_index, band_code, activity_code, segment_start, segment_end,
    played_minutes, billed_minutes, unit_minutes, unit_price_paise, amount_paise)
select s.arena_id, s.id, 0, 'standard', 'PS5', s.started_at, s.scheduled_end_at, 60, 60, 60, 20000, 20000
  from sessions s where s.id in ('51800000-0000-4000-8000-00000000000a', '51800000-0000-4000-8000-00000000000b');
insert into payments(arena_id, session_id, amount_paise, method, kind, created_by)
select s.arena_id, s.id, 20000, 'cash', 'payment', null
  from sessions s where s.id in ('51800000-0000-4000-8000-00000000000a', '51800000-0000-4000-8000-00000000000b');
insert into audit_log(arena_id, entity_type, entity_id, action, reason) values
  ('e0000000-0000-4000-8000-000000000180', 'session', '51800000-0000-4000-8000-00000000000a', 'void', 'test'),
  ('e0000000-0000-4000-8000-000000000181', 'session', '51800000-0000-4000-8000-00000000000b', 'void', 'test');

create function pg_temp.as_user(p_n int) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', '18000000-0000-4000-8000-00000000000' || p_n, 'role', 'authenticated')::text, true)
$$ language sql;
-- How many rows of each sensitive table the current caller sees, as "payments/charges/customers/audit".
create function pg_temp.seen() returns text as $$
  select (select count(*) from payments) || '/' || (select count(*) from session_charges) || '/'
      || (select count(*) from customers) || '/' || (select count(*) from audit_log)
      || '/' || (select count(*) from sessions)
$$ language sql;

-- ------------------------------------------- 1. sensitive reads by permission
-- Columns: payments / session_charges / customers / audit_log / sessions.
set local role authenticated;
select pg_temp.as_user(1);
select is(pg_temp.seen(), '1/1/1/1/1', 'owner: everything of their own arena only');
select pg_temp.as_user(5);
select is(pg_temp.seen(), '1/1/1/1/1', 'owner-level manager (reports): money, customers and the audit log');
select pg_temp.as_user(2);
select is(pg_temp.seen(), '1/1/1/0/1', 'cashier (start, bill): payments, bill lines and customers; no audit log');
select pg_temp.as_user(3);
select is(pg_temp.seen(), '0/0/1/0/1', 'runner (start only): customers for check-in, no money, no audit log');
select pg_temp.as_user(4);
select is(pg_temp.seen(), '0/0/1/0/1', 'members desk: customers only, no money, no audit log');
select pg_temp.as_user(6);
select is(pg_temp.seen(), '0/0/0/0/0', 'a deactivated member sees nothing, whatever their old perms');
select pg_temp.as_user(7);
select is((select count(*)::int from payments where arena_id = 'e0000000-0000-4000-8000-000000000180'), 0,
  'another arena''s owner sees none of this arena''s payments');
select is((select count(*)::int from customers where arena_id = 'e0000000-0000-4000-8000-000000000180'), 0,
  'or its customers');
select is((select count(*)::int from audit_log where arena_id = 'e0000000-0000-4000-8000-000000000180'), 0,
  'or its audit log');
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select is(pg_temp.seen(), '0/0/0/0/0', 'a token without a user sees nothing');
reset role;
select set_config('request.jwt.claims', '', true);
select ok(not has_table_privilege('anon', 'public.' || t, 'select'), 'anon cannot read ' || t)
from unnest(array['payments', 'session_charges', 'customers', 'audit_log']) t;

select ok((select qual like '%app_arena_ids_with%' from pg_policies
            where schemaname = 'public' and tablename = t and cmd = 'SELECT'),
  t || ' is read through the permission-aware policy')
from unnest(array['payments', 'session_charges', 'customers', 'audit_log']) t;

-- ------------------------------------------- 2. private Realtime channels
select pg_temp.as_user(1);
select ok(private.can_use_arena_topic('arena:e0000000-0000-4000-8000-000000000180'),
  'a member may use their arena''s channel');
select ok(not private.can_use_arena_topic('arena:e0000000-0000-4000-8000-000000000181'),
  'but not another arena''s');
select pg_temp.as_user(3);
select ok(private.can_use_arena_topic('arena:e0000000-0000-4000-8000-000000000180'),
  'any active member (even without money perms) gets the nudges: they carry no data');
select pg_temp.as_user(6);
select ok(not private.can_use_arena_topic('arena:e0000000-0000-4000-8000-000000000180'),
  'a deactivated member may not');
select pg_temp.as_user(7);
select ok(not private.can_use_arena_topic('arena:e0000000-0000-4000-8000-000000000180'),
  'another arena''s owner may not');
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select ok(not private.can_use_arena_topic('arena:e0000000-0000-4000-8000-000000000180'),
  'nor a token without a user');
select pg_temp.as_user(1);
select ok(not private.can_use_arena_topic(t), 'malformed topic refused without error: ' || coalesce(t, 'null'))
from unnest(array['arena:not-a-uuid', 'arena:', 'e0000000-0000-4000-8000-000000000180',
  'arena:E0000000-0000-4000-8000-000000000180x', 'room:e0000000-0000-4000-8000-000000000180', null]) t;
select set_config('request.jwt.claims', '', true);

select is((select count(*)::int from pg_policies where schemaname = 'realtime' and tablename = 'messages'
            and policyname in ('arena_members_receive', 'arena_members_send')
            and roles = '{authenticated}' and coalesce(qual, with_check) like '%can_use_arena_topic%'),
  2, 'realtime.messages: receive and send policies for authenticated, both arena-membership checked');
select is((select count(*)::int from pg_policies where schemaname = 'realtime' and tablename = 'messages'
            and 'anon' = any(roles)), 0, 'and nothing for anon');
select ok(not has_function_privilege('anon', 'private.can_use_arena_topic(text)', 'execute'),
  'anon cannot call the channel check');

-- ------------------------------------------- 3. the publication
select is((select array_agg(tablename::text order by tablename) from pg_publication_tables
            where pubname = 'supabase_realtime' and schemaname = 'public'),
  array['accessory_kinds', 'activities', 'bill_discounts', 'billing_policies', 'bookings',
        'controller_allocations', 'controller_moves', 'controllers', 'customers', 'discounts',
        'game_categories', 'game_controls', 'game_resources', 'games',
        'holidays', 'payments', 'pricing_rules', 'rate_bands', 'rate_cards', 'rates',
        'resource_activities', 'resources', 'session_charges', 'session_extensions',
        'session_segments', 'sessions', 'settings', 'staff_profiles'],
  'Realtime announces every arena table the apps show live');
select is((select count(*)::int from pg_publication_tables pt
             join pg_class c on c.relname = pt.tablename
             join pg_namespace n on n.oid = c.relnamespace and n.nspname = pt.schemaname
            where pt.pubname = 'supabase_realtime' and not c.relrowsecurity), 0,
  'every announced table has RLS on (Postgres Changes are filtered by it)');
select is((select count(*)::int from pg_publication_tables
            where pubname = 'supabase_realtime' and tablename in ('staff_invites', 'sync_ops', 'audit_log')),
  0, 'invites, the op ledger and the audit log are never announced');

-- ---------------------------------------------------------------- sync_pull narrows the same way
-- The feeds sync_pull leaves out for the caller (its scope). The fixture rows are in this test's
-- own open transaction, which a pull never includes, so the rows themselves are checked through
-- sync_fetch_entity below; both filter with _sync_hidden.
create function pg_temp.pulled() returns text as $$
  select array(select jsonb_array_elements_text(p->'scope'))::text
    from (select public.sync_pull('e0000000-0000-4000-8000-000000000180', '0', 2000) p) x
$$ language sql;
set local role authenticated;
select pg_temp.as_user(1);
select is(pg_temp.pulled(), '{}', 'sync_pull: the owner gets everything');
select pg_temp.as_user(2);
select is(pg_temp.pulled(), '{discounts}', 'sync_pull: bill gets money and customers, not coupons');
select pg_temp.as_user(3);
select is(pg_temp.pulled(), '{bill_discounts,discounts,payments,session_charges}',
  'sync_pull: start alone gets sessions and customers, no money');
select pg_temp.as_user(4);
select is(pg_temp.pulled(), '{bill_discounts,discounts,payments,session_charges}',
  'sync_pull: members alone gets customers, no money');
select pg_temp.as_user(5);
select is(pg_temp.pulled(), '{}', 'sync_pull: reports (owner level) gets everything');
create function pg_temp.fetched() returns text as $$
  select array(select r->>'t' from jsonb_array_elements(f->0->'rows') r order by 1)::text
    from (select public.sync_fetch_entity('e0000000-0000-4000-8000-000000000180',
      '[{"type":"session","id":"51800000-0000-4000-8000-00000000000a"}]'::jsonb) f) x
$$ language sql;
select is(pg_temp.fetched(), '{payments,session_charges,sessions}', 'sync_fetch_entity: reports gets the whole bill');
select pg_temp.as_user(3);
select is(pg_temp.fetched(), '{sessions}', 'sync_fetch_entity: start alone gets the session, not its money');
reset role;

-- ---------------------------------------------------------------- money and audit rows are append-only
select throws_ok($$ update payments set amount_paise = 1 where session_id = '51800000-0000-4000-8000-00000000000a' $$,
  '55000', 'append_only', 'a payment is never edited, even by the database owner');
select throws_ok($$ delete from session_charges where session_id = '51800000-0000-4000-8000-00000000000a' $$,
  '55000', 'append_only', 'nor a bill line deleted');
select throws_ok($$ delete from sessions where id = '51800000-0000-4000-8000-00000000000a' $$,
  '55000', 'append_only', 'deleting a session with payments is refused (no cascade erases the ledger)');
select throws_ok($$ delete from audit_log where arena_id = 'e0000000-0000-4000-8000-000000000180' $$,
  '55000', 'append_only', 'the audit log is never deleted');

select * from finish();
rollback;
