-- Security hardening: the client roles' surface, RLS shape, owner-level
-- permissions, and the integrity checks added with the declarative schema.
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated: two arenas of this file's own (A is under test, B is a neighbour
-- whose ids A must never reach). Rolled back with the transaction.
insert into arenas(id, name) values
  ('e0000000-0000-4000-8000-000000000130'::uuid, 'pgtap 13 A'),
  ('e0000000-0000-4000-8000-000000000131'::uuid, 'pgtap 13 B');
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000130'::uuid);
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000131'::uuid);

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  select '00000000-0000-0000-0000-000000000000', u.id::uuid, 'authenticated', 'authenticated',
         u.email, '', now(), now(), now(), '{}', '{}', false, false
    from (values
      ('13000000-0000-0000-0000-000000000001', 'owner13@test.local'),
      ('13000000-0000-0000-0000-000000000002', 'manager13@test.local'),
      ('13000000-0000-0000-0000-000000000003', 'cashier13@test.local'),
      ('13000000-0000-0000-0000-000000000004', 'floor13@test.local')) u(id, email)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000130','13000000-0000-0000-0000-000000000001','Owner','owner',
    _known_perms(), true),
  -- runs Settings but is not owner level (no money / reports)
  ('e0000000-0000-4000-8000-000000000130','13000000-0000-0000-0000-000000000002','Manager','staff',
    array['start','bill','settings'], true),
  -- owner level through money
  ('e0000000-0000-4000-8000-000000000130','13000000-0000-0000-0000-000000000003','Cashier','staff',
    array['start','bill','money'], true),
  ('e0000000-0000-4000-8000-000000000130','13000000-0000-0000-0000-000000000004','Floor','staff',
    array['start'], true);

create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.push(p_kind text, p jsonb) returns jsonb as $$
  select sync_push('e0000000-0000-4000-8000-000000000130'::uuid,
    jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', p_kind, 'payload', p)),
    'pgtap') -> 'results' -> 0 $$ language sql;
create function pg_temp.staff(p_uid text, p_name text, p_perms text[], p_active boolean default true)
  returns jsonb as $$
  select jsonb_build_object('user_id', p_uid, 'name', p_name, 'perms', to_jsonb(p_perms),
    'active', p_active) $$ language sql;
create function pg_temp.perms(p_uid text) returns text[] as $$
  select perms from staff_profiles where user_id = p_uid::uuid
     and arena_id = 'e0000000-0000-4000-8000-000000000130' $$ language sql;

-- ------------------------------------------- 1. anon reaches nothing
select is((select count(*)::int from pg_class c
            where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','v','S')
              and (has_table_privilege('anon', c.oid, 'select,insert,update,delete,truncate,references,trigger')
                   or (c.relkind = 'S' and has_sequence_privilege('anon', c.oid, 'usage,select,update')))),
  0, 'anon has no privilege on any table, view or sequence');
select is((select count(*)::int from pg_proc p
            where p.pronamespace = 'public'::regnamespace
              and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
              and has_function_privilege('anon', p.oid, 'execute')),
  0, 'anon can execute no function');

-- ------------------------------------------- 2. authenticated: RLS-gated reads, RPC writes
select is((select count(*)::int from pg_class c
            where c.relnamespace = 'public'::regnamespace and c.relkind in ('r','v')
              and has_table_privilege('authenticated', c.oid, 'insert,update,delete,truncate,references,trigger')),
  0, 'signed-in users cannot write, truncate or reference any table directly');
select is((select count(*)::int from pg_class c
            where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
              and has_table_privilege('authenticated', c.oid, 'select')
              and not c.relrowsecurity),
  0, 'every table a signed-in user can read has RLS enabled');
select is((select count(*)::int from pg_class c
            where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and not c.relrowsecurity),
  0, 'every public table has RLS enabled');
select is((select count(*)::int from pg_policies
            where schemaname = 'public' and roles <> array['authenticated']::name[]),
  0, 'every policy targets authenticated only (never public / anon)');
select is((select count(*)::int from pg_policies where schemaname = 'public' and cmd <> 'SELECT'),
  0, 'there are only read policies: writes go through sync_push');
select ok(not has_table_privilege('authenticated', f, 'select'), f || ' is server-only')
  from unnest(array['sync_ops', 'sync_tombstones', 'pricing_catalog_history',
    'sync_v_arenas', 'sync_v_bookings', 'sync_v_rates', 'sync_v_resource_activities']) f;
select is((select count(*)::int from pg_class c
            where c.relnamespace = 'public'::regnamespace and c.relkind = 'v'
              and not coalesce('security_invoker=true' = any(c.reloptions), false)),
  0, 'every view runs with the caller''s privileges (security_invoker)');
select is(
  (select array_agg(p.proname::text order by p.proname) from pg_proc p
    where p.pronamespace = 'public'::regnamespace
      and has_function_privilege('authenticated', p.oid, 'execute')),
  array['accept_invite', 'accessory_kind_catalog', 'app_is_owner', 'arena_activity', 'arena_discount_usage', 'arena_game_fans',
        'arena_game_stats', 'arena_invites', 'arena_members', 'arena_overview', 'arena_pricing', 'arena_sale',
        'arena_sales', 'arena_staff', 'arena_station_stats', 'create_my_arena', 'invite_member',
        'my_arenas', 'my_bills', 'revoke_invite', 'session_quote', 'station_type_catalog',
        'sync_fetch_entity', 'sync_pull', 'sync_push'],
  'the client API is exactly these functions');
-- Security Advisor lints 0028/0029: no SECURITY DEFINER function in an exposed
-- schema is executable by a client role. The bodies live in `private`; public
-- holds SECURITY INVOKER wrappers.
select is((select array_agg(p.proname::text order by p.proname) from pg_proc p
            where p.pronamespace = 'public'::regnamespace and p.prosecdef
              and (has_function_privilege('authenticated', p.oid, 'execute')
                   or has_function_privilege('anon', p.oid, 'execute'))),
  null, 'no client-executable SECURITY DEFINER function in public (lints 0028/0029)');
select ok(has_function_privilege('authenticated', 'private.' || f, 'execute')
          and not has_function_privilege('anon', 'private.' || f, 'execute'),
  'private.' || f || ' is reachable by the invoker wrapper / RLS, never by anon')
from unnest(array['my_arenas()', 'sync_push(uuid,jsonb,text)', 'sync_pull(uuid,text,integer)',
  'app_arena_ids()', 'app_has_perm(uuid,text)', 'app_is_owner(uuid)']) f;
select ok(has_schema_privilege('authenticated', 'private', 'usage')
          and not has_schema_privilege('anon', 'private', 'usage'),
  'private: usage for authenticated (policies run as the caller), none for anon');
select hasnt_function('public', f, f || ' is an RLS helper, not client API')
from unnest(array['app_arena_ids', 'app_has_perm']) f;

-- ------------------------------------------- 3. secure by default
select is((select count(*)::int from pg_default_acl d, aclexplode(d.defaclacl) a
            where d.defaclnamespace = 'public'::regnamespace
              and d.defaclrole = 'postgres'::regrole
              and a.grantee in ('anon'::regrole, 'authenticated'::regrole)),
  0, 'new objects created by postgres grant nothing to anon / authenticated');

-- ------------------------------------------- 4. owner-level permissions
-- A Settings holder (not owner level) manages floor staff…
select pg_temp.as_user('13000000-0000-0000-0000-000000000002');
select is(pg_temp.push('staff.update', pg_temp.staff('13000000-0000-0000-0000-000000000004',
    'Floor', array['start','bill']))->>'status', 'applied',
  'a Settings holder can change a floor member''s perms');
-- …but cannot hand out, or reach, owner level.
select is(pg_temp.push('staff.update', pg_temp.staff('13000000-0000-0000-0000-000000000002',
    'Manager', array['start','bill','settings','money']))->>'error', 'forbidden',
  'a Settings holder cannot grant themselves money');
select is(pg_temp.perms('13000000-0000-0000-0000-000000000002'), array['start','bill','settings'],
  'and their perms are unchanged');
select is(pg_temp.push('staff.update', pg_temp.staff('13000000-0000-0000-0000-000000000004',
    'Floor', array['start','reports']))->>'error', 'forbidden',
  'a Settings holder cannot grant reports to someone else');
select is(pg_temp.push('staff.update', pg_temp.staff('13000000-0000-0000-0000-000000000003',
    'Cashier', array['start','bill']))->>'error', 'forbidden',
  'a Settings holder cannot change an owner-level member');
select is(pg_temp.perms('13000000-0000-0000-0000-000000000003'), array['start','bill','money'],
  'the owner-level member is untouched');
select is(pg_temp.push('staff.update', pg_temp.staff('13000000-0000-0000-0000-000000000002',
    'Manager', array['start','bill','settings'], false))->>'error', 'forbidden',
  'nobody deactivates themselves');
select is(pg_temp.push('staff.update', pg_temp.staff('13000000-0000-0000-0000-000000000002',
    'Manager (renamed)', array['start','bill','settings']))->>'status', 'applied',
  'renaming yourself, with the same perms, is fine');

-- An owner can grant owner-level perms.
select pg_temp.as_user('13000000-0000-0000-0000-000000000001');
select is(pg_temp.push('staff.update', pg_temp.staff('13000000-0000-0000-0000-000000000002',
    'Manager', array['start','bill','settings','reports']))->>'status', 'applied',
  'an owner can grant reports');
select is(pg_temp.perms('13000000-0000-0000-0000-000000000002'),
  array['start','bill','settings','reports'], 'and it is stored');

-- An owner-level member still cannot change their own perms.
select pg_temp.as_user('13000000-0000-0000-0000-000000000003');
select is(pg_temp.push('staff.update', pg_temp.staff('13000000-0000-0000-0000-000000000003',
    'Cashier', array['start','bill','money','settings']))->>'error', 'forbidden',
  'an owner-level member cannot change their own perms');

-- …and cannot rewrite them by inviting themselves either.
select throws_ok($$ select invite_member('e0000000-0000-4000-8000-000000000130'::uuid,
    'cashier13@test.local', 'Cashier', 'staff', array['start','bill','money','settings']) $$,
  '42501', null, 'invite_member refuses a route to the caller''s own perms');
select is(pg_temp.perms('13000000-0000-0000-0000-000000000003'), array['start','bill','money'],
  'and their perms are unchanged');

-- ------------------------------------------- 5. membership guard is null-safe
select pg_temp.as_user('13000000-0000-0000-0000-000000000001');
select throws_ok($$ select sync_push(null, '[]'::jsonb, 'pgtap') $$, '42501', null,
  'sync_push with a null arena is refused');
select throws_ok($$ select sync_pull(null, '0', 10) $$, '42501', null,
  'sync_pull with a null arena is refused');

-- ------------------------------------------- 6. cross-arena ids are "not found"
select is(pg_temp.push('game.upsert', jsonb_build_object(
    'id', (select id from games where arena_id = 'e0000000-0000-4000-8000-000000000131' limit 1),
    'name', 'Hijacked'))->>'error', 'not_found',
  'game.upsert with another arena''s game id is refused, not silently skipped');
select is(pg_temp.push('controller.upsert', jsonb_build_object(
    'id', (select id from controllers where arena_id = 'e0000000-0000-4000-8000-000000000131' limit 1),
    'label', 'Hijacked'))->>'error', 'not_found',
  'controller.upsert with another arena''s pad id is refused');

-- ------------------------------------------- 7. integrity checks
select throws_ok($$ update rates set unit_minutes = 0
                     where arena_id = 'e0000000-0000-4000-8000-000000000130' $$, '23514', null,
  'a rate cannot have a zero-minute unit');
insert into customers(id, arena_id, name) values
  ('5c000000-0000-0000-0000-000000000013', 'e0000000-0000-4000-8000-000000000130', 'Asha');
insert into sessions(id, arena_id, customer_id, status, payment_status, started_at,
    scheduled_end_at, pricing_snapshot, policy_snapshot)
  values ('5e000000-0000-0000-0000-000000000013', 'e0000000-0000-4000-8000-000000000130',
    '5c000000-0000-0000-0000-000000000013', 'active', 'unpaid', '2026-10-01T09:00:00Z',
    '2026-10-01T10:00:00Z', '{}', '{}');
select throws_ok($$ insert into payments(arena_id, session_id, amount_paise, method)
                     values ('e0000000-0000-4000-8000-000000000130',
                             '5e000000-0000-0000-0000-000000000013', 0, 'cash') $$, '23514', null,
  'a zero payment is never recorded');
select throws_ok($$ insert into payments(arena_id, session_id, amount_paise, method, kind, reason)
                     values ('e0000000-0000-4000-8000-000000000130',
                             '5e000000-0000-0000-0000-000000000013', 500, 'cash', 'refund', 'x') $$,
  '23514', null, 'a refund must be negative');
select throws_ok($$ insert into payments(arena_id, session_id, amount_paise, method)
                     values ('e0000000-0000-4000-8000-000000000130',
                             '5e000000-0000-0000-0000-000000000013', -500, 'cash') $$,
  '23514', null, 'a payment must be positive');

select * from finish();
rollback;
