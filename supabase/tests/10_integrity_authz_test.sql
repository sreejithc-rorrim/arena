-- 0016: money integrity, owner/staff protection, pad-move permission,
-- same-arena references, pinned search_path, grants.
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated: two arenas of this file's own (A is the one under test, B is a
-- neighbour whose ids A must never reach). Rolled back with the transaction.
insert into arenas(id, name) values
  ('e0000000-0000-4000-8000-000000000010'::uuid, 'pgtap 10 A'),
  ('e0000000-0000-4000-8000-000000000011'::uuid, 'pgtap 10 B');
-- These fixtures replay fixed past dates: widen the offline window (offline_rules, default
-- 24 h) so device-stamped times from then are accepted.
insert into settings(arena_id, key, json)
  select id, 'offline_rules', '{"max_offline_hours": 100000}' from arenas where name like 'pgtap%'
  on conflict (arena_id, key) do nothing;
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000010'::uuid);
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000011'::uuid);

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  select '00000000-0000-0000-0000-000000000000', u.id::uuid, 'authenticated', 'authenticated',
         u.email, '', now(), now(), now(), '{}', '{}', false, false
    from (values
      ('10000000-0000-0000-0000-000000000001', 'owner10@test.local'),
      ('10000000-0000-0000-0000-000000000002', 'staff10@test.local'),
      ('10000000-0000-0000-0000-000000000003', 'money10@test.local'),
      ('10000000-0000-0000-0000-000000000004', 'none10@test.local'),
      ('10000000-0000-0000-0000-000000000005', 'later10@test.local')) u(id, email)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000010','10000000-0000-0000-0000-000000000001','Owner','owner',
    _known_perms(), true),
  -- the hosted staff default
  ('e0000000-0000-4000-8000-000000000010','10000000-0000-0000-0000-000000000002','Staff','staff',
    array['start','bill','discount','members'], true),
  -- holds money (owner level) but not settings
  ('e0000000-0000-4000-8000-000000000010','10000000-0000-0000-0000-000000000003','Cashier','staff',
    array['start','bill','money'], true),
  ('e0000000-0000-4000-8000-000000000010','10000000-0000-0000-0000-000000000004','Nobody','staff',
    '{}', true);

create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.push(p_kind text, p jsonb) returns jsonb as $$
  select sync_push('e0000000-0000-4000-8000-000000000010'::uuid,
    jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', p_kind, 'payload', p)),
    'pgtap') -> 'results' -> 0 $$ language sql;
create function pg_temp.r(p_arena text, n text) returns uuid as $$
  select id from resources where name = n and arena_id = p_arena::uuid $$ language sql;
create function pg_temp.c(l text) returns uuid as $$
  select id from controllers where label = l
     and arena_id = 'e0000000-0000-4000-8000-000000000010'::uuid $$ language sql;
create function pg_temp.pay(p_amount bigint, p_refund boolean default false) returns jsonb as $$
  select jsonb_build_object('scope','single','parent_id','5e000000-0000-0000-0000-000000000001',
    'payment_id', gen_random_uuid(), 'amount_paise', p_amount, 'method', 'cash',
    'is_refund', p_refund, 'reason', case when p_refund then 'test' end) $$ language sql;
create function pg_temp.start(p_id text, p_customer text) returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'segment_id', gen_random_uuid(),
    'customer_id', p_customer::uuid,
    'started_at', '2026-10-01T09:00:00Z', 'scheduled_end_at', '2026-10-01T10:00:00Z',
    'pricing_snapshot', _pricing_snapshot('e0000000-0000-4000-8000-000000000010'::uuid),
    'resource_id', pg_temp.r('e0000000-0000-4000-8000-000000000010', 'Pool Table 1'),
    'activity_code', 'POOL', 'game_id', null, 'controller_count', null,
    'allocations', '[]'::jsonb, 'moves', '[]'::jsonb) $$ language sql;

-- ------------------------------------------- 1. payments fit the bill
select pg_temp.as_user('10000000-0000-0000-0000-000000000002');
select is(pg_temp.push('customer.create', jsonb_build_object(
    'id','5c000000-0000-0000-0000-000000000001','name','Asha','phone','9800001010',
    'is_guest', false))->>'status', 'applied', 'staff creates a customer');
select is(pg_temp.push('session.start', pg_temp.start(
    '5e000000-0000-0000-0000-000000000001', '5c000000-0000-0000-0000-000000000001'))->>'status',
  'applied', 'staff starts a pool session');
select is(pg_temp.push('payment.record', pg_temp.pay(10000))->>'status', 'applied',
  'an advance while the session runs is not capped (no final bill yet)');

-- The bill becomes final: ₹300 (set directly; pricing is 08's subject).
update sessions set status = 'completed', billed_amount_paise = 30000,
       actual_ended_at = '2026-10-01T10:00:00Z'
 where id = '5e000000-0000-0000-0000-000000000001';
update session_segments set ended_at = '2026-10-01T10:00:00Z'
 where session_id = '5e000000-0000-0000-0000-000000000001';

select is(pg_temp.push('payment.record', pg_temp.pay(25000))->>'error', 'overpayment',
  'collecting ₹250 on ₹200 still due is refused');
select is(pg_temp.push('payment.record', pg_temp.pay(25000))->>'detail', 'only ₹200.00 is due',
  'and the reason names what is due');
select is(pg_temp.push('payment.record', pg_temp.pay(20000))->'result'->>'payment_status', 'paid',
  'the exact balance is accepted and settles the bill');
select is(pg_temp.push('payment.record', pg_temp.pay(100))->>'error', 'overpayment',
  'a second device collecting again on a settled bill is refused');
select is((select sum(amount_paise)::bigint from payments
            where session_id = '5e000000-0000-0000-0000-000000000001'), 30000::bigint,
  'collected exactly the bill');
select is(pg_temp.push('payment.record', pg_temp.pay(40000, true))->>'error', 'refund_exceeds_paid',
  'a refund larger than what was collected is refused');
select is(pg_temp.push('payment.record', pg_temp.pay(5000, true))->>'status', 'applied',
  'a refund within what was collected is accepted');
select is((select payment_status from sessions where id = '5e000000-0000-0000-0000-000000000001'),
  'partial', 'and the bill is partly paid again');

-- ------------------------------------------- 2. pad moves need a floor role
select pg_temp.as_user('10000000-0000-0000-0000-000000000004');
select is(pg_temp.push('controller.move', jsonb_build_object('controller_id', pg_temp.c('VOID-1'),
    'kind','loan','to_resource_id', pg_temp.r('e0000000-0000-4000-8000-000000000010','HEX'),
    'at','2026-10-01T09:00:00Z','move_id', gen_random_uuid()))->>'error', 'forbidden',
  'a member with no permissions cannot carry pads');
select pg_temp.as_user('10000000-0000-0000-0000-000000000002');
select is(pg_temp.push('controller.move', jsonb_build_object('controller_id', pg_temp.c('VOID-1'),
    'kind','loan','to_resource_id', pg_temp.r('e0000000-0000-4000-8000-000000000010','HEX'),
    'at','2026-10-01T09:00:00Z','move_id', gen_random_uuid()))->>'status', 'applied',
  'staff with start can loan a pad');
select is(pg_temp.push('controller.move', jsonb_build_object('controller_id', pg_temp.c('VOID-1'),
    'kind','permanent','to_resource_id', pg_temp.r('e0000000-0000-4000-8000-000000000010','HEX'),
    'at','2026-10-01T09:00:00Z','move_id', gen_random_uuid()))->>'error', 'forbidden',
  'but re-homing a pad still needs settings');

-- ------------------------------------------- 3. staff profiles
-- People join by invitation only (17_staff_invites_test.sql). The old route
-- that linked logins by e-mail with owner level alone, skipping Settings
-- (add_staff_by_email / add_member_by_email), is gone.
select pg_temp.as_user('10000000-0000-0000-0000-000000000003');
select throws_ok($$ select invite_member('e0000000-0000-4000-8000-000000000010',
    'later10@test.local', 'Later', 'staff', array['start']) $$, '42501', 'forbidden',
  'owner level (money) without Settings cannot invite: the same rule as staff.update');
select ok((select active and perms @> _known_perms() from staff_profiles
            where user_id = '10000000-0000-0000-0000-000000000001'),
  'the owner keeps every permission');
select pg_temp.as_user('10000000-0000-0000-0000-000000000001');
select throws_ok($$ select invite_member('e0000000-0000-4000-8000-000000000010',
    'later10@test.local', 'Later', 'staff', array['start','superuser']) $$, 'P0001', 'invalid_permission',
  'unknown permission codes are refused');
select pg_temp.as_user('10000000-0000-0000-0000-000000000002');
select throws_ok($$ select invite_member('e0000000-0000-4000-8000-000000000010',
    'later10@test.local', 'Later', 'staff', array['start','settings']) $$, '42501', 'forbidden',
  'plain staff cannot invite or promote anyone');
select pg_temp.as_user('10000000-0000-0000-0000-000000000001');
select is(pg_temp.push('staff.update', jsonb_build_object('user_id','10000000-0000-0000-0000-000000000002',
    'name','Staff','perms','["start","root"]'::jsonb,'active',true))->>'error', 'invalid_permission',
  'staff.update refuses unknown permission codes');
-- Access changes are audited with before and after; the op itself is kept in sync_ops.
select is(pg_temp.push('staff.update', jsonb_build_object('user_id','10000000-0000-0000-0000-000000000002',
    'perms','["start","bill"]'::jsonb))->>'status', 'applied', 'the owner gives Staff bill');
select is((select (before->'perms')::text || ' -> ' || (after->'perms')::text from audit_log
            where entity_type = 'staff_profile' and action = 'access'
              and arena_id = 'e0000000-0000-4000-8000-000000000010'),
  '["start", "bill", "discount", "members"] -> ["start", "bill"]',
  'the access change is audited with before and after');
select is((select payload->'perms' from sync_ops where kind = 'staff.update' and status = 'applied'
            and arena_id = 'e0000000-0000-4000-8000-000000000010'
            and payload->>'user_id' = '10000000-0000-0000-0000-000000000002'),
  '["start", "bill"]'::jsonb, 'and sync_ops keeps what the op asked for');
-- Back as the rest of this file expects (that change is audited too).
select pg_temp.push('staff.update', jsonb_build_object('user_id','10000000-0000-0000-0000-000000000002',
  'perms','["start","bill","discount","members"]'::jsonb));
-- A partial staff.update keeps what it leaves out: it never wipes someone's
-- permissions or silently reactivates them.
update staff_profiles set active = false, perms = array['start']
 where user_id = '10000000-0000-0000-0000-000000000004';
select is(pg_temp.push('staff.update', jsonb_build_object(
    'user_id', '10000000-0000-0000-0000-000000000004', 'name', 'Nobody Two'))->>'status', 'applied',
  'a rename-only staff.update is applied');
select is((select name || ':' || active || ':' || array_to_string(perms, ',') from staff_profiles
            where user_id = '10000000-0000-0000-0000-000000000004'), 'Nobody Two:false:start',
  'and leaves active and perms exactly as they were');

-- ------------------------------------------- 4. nothing reaches another arena
select pg_temp.as_user('10000000-0000-0000-0000-000000000002');
insert into customers(id, arena_id, name, phone)
  values ('5c000000-0000-0000-0000-0000000000bb', 'e0000000-0000-4000-8000-000000000011', 'B''s', '9800001011');
select is(pg_temp.push('session.start', pg_temp.start(
    '5e000000-0000-0000-0000-000000000002', '5c000000-0000-0000-0000-0000000000bb'))->>'error',
  'missing_reference', 'a session cannot point at another arena''s customer');
select is((select count(*)::int from sessions where id = '5e000000-0000-0000-0000-000000000002'), 0,
  'and nothing was written');
select pg_temp.as_user('10000000-0000-0000-0000-000000000001');
select is(pg_temp.push('resource.upsert', jsonb_build_object(
    'id', pg_temp.r('e0000000-0000-4000-8000-000000000011','HEX'), 'name','HEX','kind','station',
    'activity_codes','[]'::jsonb))->>'error', 'not_found',
  'an owner cannot edit another arena''s station by id');
select is((select count(*)::int from resource_activities
            where resource_id = pg_temp.r('e0000000-0000-4000-8000-000000000011','HEX')), 1,
  'and that station keeps its activity links');
select is(pg_temp.push('game.set_compat', jsonb_build_object(
    'game_id', (select id from games where arena_id = 'e0000000-0000-4000-8000-000000000011' limit 1),
    'resource_id', pg_temp.r('e0000000-0000-4000-8000-000000000010','HEX'),
    'status','compatible'))->>'error', 'missing_reference',
  'a compatibility row cannot pair this arena''s station with another arena''s game');

-- ------------------------------------------- 5. hygiene
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'public' and p.prokind = 'f'
              and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
              and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')),
  0, 'every public function pins its search_path');
select ok(not has_function_privilege('authenticated', f, 'execute'), 'not client-callable: ' || f)
  from unnest(array['op_payment(uuid,jsonb)',
    'op_staff_update(uuid,jsonb)',
    'op_controller_move(uuid,jsonb)',
    'op_resource_upsert(uuid,jsonb)',
    '_sync_apply(uuid,text,jsonb)',
    '_assert_same_arena()', '_known_perms()', '_assert_known_perms(text[])', '_rupees(bigint)']) f;
select ok(not has_function_privilege('anon', 'invite_member(uuid,text,text,text,text[])', 'execute'),
  'anon cannot call invite_member');
select ok(has_function_privilege('authenticated', 'invite_member(uuid,text,text,text,text[])', 'execute'),
  'signed-in members can (it checks Settings itself)');

select * from finish();
rollback;
