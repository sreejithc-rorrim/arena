-- Station accessories: owner-defined accessory_kinds, controllers.kind_id, and the rule that only
-- pads (no kind, or a kind with counts_as_controller) are allocated, borrowed or counted, while
-- every accessory can still be moved (loan / return home / permanent) with its history kept.
-- Also: activity.upsert derives a type code from the name when none is given.
begin;
create extension if not exists pgtap;
select * from no_plan();

insert into arenas(id, name) values ('e0000000-0000-4000-8000-000000000123'::uuid, 'pgtap 23');
-- These fixtures replay fixed past dates: widen the offline window (offline_rules, default
-- 24 h) so device-stamped times from then are accepted.
insert into settings(arena_id, key, json)
  select id, 'offline_rules', '{"max_offline_hours": 100000}' from arenas where name like 'pgtap%'
  on conflict (arena_id, key) do nothing;
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000123'::uuid);

-- ===================== schema + grants
select has_table('public', 'accessory_kinds', 'accessory_kinds exists');
select has_column('public', 'controllers', 'kind_id', 'controllers.kind_id exists');
select col_is_null('public', 'controllers', 'kind_id', 'kind_id is nullable (null = pad)');
select is((select relrowsecurity from pg_class where oid = 'public.accessory_kinds'::regclass), true,
  'RLS is enabled on accessory_kinds');
select ok(has_table_privilege('authenticated', 'public.accessory_kinds', 'SELECT'),
  'authenticated may SELECT accessory_kinds (filtered by RLS)');
select ok(not has_table_privilege(r, 'public.accessory_kinds', p), r || ' has no ' || p)
from unnest(array['authenticated','anon']) as r,
     unnest(array['INSERT','UPDATE','DELETE','TRUNCATE']) as p;
select ok(not has_table_privilege('anon', 'public.accessory_kinds', 'SELECT'), 'anon cannot read kinds');
select ok(exists (select 1 from _sync_sources() where name = 'accessory_kinds'),
  'accessory_kinds is in the change feed');

-- ===================== fixture
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  values
  ('00000000-0000-0000-0000-000000000000','23000000-0000-0000-0000-000000000001','authenticated',
   'authenticated','owner23@test.local','',now(),now(),now(),'{}','{}',false,false),
  ('00000000-0000-0000-0000-000000000000','23000000-0000-0000-0000-000000000002','authenticated',
   'authenticated','staff23@test.local','',now(),now(),now(),'{}','{}',false,false)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000123'::uuid,'23000000-0000-0000-0000-000000000001','Owner','owner',
    array['start','bill','discount','members','stations','money','reports','settings'],true),
  ('e0000000-0000-4000-8000-000000000123'::uuid,'23000000-0000-0000-0000-000000000002','Staff','staff',
    array['start','bill','discount','members'],true);

create function pg_temp.r(n text) returns uuid as $$ select id from resources where name = n and arena_id = 'e0000000-0000-4000-8000-000000000123'::uuid $$ language sql;
create function pg_temp.c(l text) returns uuid as $$ select id from controllers where label = l and arena_id = 'e0000000-0000-4000-8000-000000000123'::uuid $$ language sql;
create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.push(p_kind text, p jsonb) returns jsonb as $$
  select sync_push('e0000000-0000-4000-8000-000000000123'::uuid,
    jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', p_kind, 'payload', p)), 'pgtap')
    -> 'results' -> 0 $$ language sql;
create function pg_temp.acc(p_id text, p_label text, p_home text, p_kind text) returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'label', p_label, 'home_resource_id', pg_temp.r(p_home),
    'current_resource_id', pg_temp.r(p_home), 'kind_id', p_kind::uuid) $$ language sql;
create function pg_temp.start(p_id text, p_seg text, p_res text, p_allocs jsonb, p_moves jsonb default '[]')
  returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'segment_id', p_seg::uuid,
    'customer_id', 'cccccccc-0000-0000-0000-000000000023',
    'started_at', '2026-10-01T09:00:00Z', 'scheduled_end_at', '2026-10-01T12:00:00Z',
    'pricing_snapshot', _pricing_snapshot('e0000000-0000-4000-8000-000000000123'::uuid),
    'resource_id', pg_temp.r(p_res), 'activity_code', 'PS5', 'game_id', null,
    'controller_count', jsonb_array_length(p_allocs), 'allocations', p_allocs, 'moves', p_moves)
  $$ language sql;

-- ===================== kinds
select pg_temp.as_user('23000000-0000-0000-0000-000000000002');
select is(pg_temp.push('accessory_kind.upsert', jsonb_build_object(
    'id','ac000000-0000-0000-0000-000000000001','name','VR headset'))->>'error', 'forbidden',
  'staff without settings cannot add a kind');

select pg_temp.as_user('23000000-0000-0000-0000-000000000001');
select is(pg_temp.push('accessory_kind.upsert', jsonb_build_object(
    'id','ac000000-0000-0000-0000-000000000001','name','VR headset'))->>'status', 'applied',
  'owner adds VR headset (not a controller by default)');
select is(pg_temp.push('accessory_kind.upsert', jsonb_build_object(
    'id','ac000000-0000-0000-0000-000000000002','name','Controller','counts_as_controller',true))->>'status',
  'applied', 'owner adds Controller (counts as a controller)');
select is(pg_temp.push('accessory_kind.upsert', jsonb_build_object(
    'id','ac000000-0000-0000-0000-000000000003','name',' vr HEADSET '))->>'error', 'duplicate',
  'a kind name is unique ignoring case and spaces');
select is(pg_temp.push('accessory_kind.upsert', jsonb_build_object(
    'id','ac000000-0000-0000-0000-000000000003','name',''))->>'error', 'invalid_name',
  'a blank name is refused');

-- ===================== accessories on a station
select is(pg_temp.push('controller.upsert', pg_temp.acc('ad000000-0000-0000-0000-000000000001',
    'RIFT-VR', 'RIFT', 'ac000000-0000-0000-0000-000000000001'))->>'status', 'applied',
  'a VR headset is added to RIFT');
select is(pg_temp.push('controller.upsert', pg_temp.acc('ad000000-0000-0000-0000-000000000002',
    'HEX-P3', 'HEX', 'ac000000-0000-0000-0000-000000000002'))->>'status', 'applied',
  'a third pad (Controller kind) is added to HEX');
select is((select kind_id from controllers where id = 'ad000000-0000-0000-0000-000000000001'),
  'ac000000-0000-0000-0000-000000000001'::uuid, 'the headset keeps its kind');

-- An edit that omits kind_id (an older floor app) keeps the kind.
select is(pg_temp.push('controller.upsert', jsonb_build_object('id','ad000000-0000-0000-0000-000000000001',
    'label','RIFT-VR1','home_resource_id',pg_temp.r('RIFT'),'current_resource_id',pg_temp.r('RIFT')))->>'status',
  'applied', 'an edit without kind_id applies');
select is((select kind_id from controllers where id = 'ad000000-0000-0000-0000-000000000001'),
  'ac000000-0000-0000-0000-000000000001'::uuid, '…and the kind is kept');

-- Supply counts only pads (no pad is allocated yet, so every usable pad is free).
select is(_free_pads_at('e0000000-0000-4000-8000-000000000123'::uuid, pg_temp.r('RIFT')),
  (select count(*)::int from controllers where current_resource_id = pg_temp.r('RIFT')
     and status = 'usable' and kind_id is null),
  'the headset is not counted as a usable pad at RIFT');
select is(_free_pads_at('e0000000-0000-4000-8000-000000000123'::uuid, pg_temp.r('HEX')),
  (select count(*)::int from controllers where current_resource_id = pg_temp.r('HEX') and status = 'usable'),
  'a Controller-kind accessory counts as a pad at HEX');

-- ===================== a non-pad cannot be allocated or borrowed by a start
select pg_temp.as_user('23000000-0000-0000-0000-000000000002');
select is(pg_temp.push('customer.create', jsonb_build_object(
    'id','cccccccc-0000-0000-0000-000000000023','name','Asha','phone','9800002323',
    'is_guest', false))->>'status', 'applied', 'staff creates a customer');
select is(pg_temp.push('session.start', pg_temp.start(
    'a2300000-0000-0000-0000-000000000001','b2300000-0000-0000-0000-000000000001','RIFT',
    jsonb_build_array(jsonb_build_object('id','a2310000-0000-0000-0000-000000000001',
      'controller_id','ad000000-0000-0000-0000-000000000001'))))->>'error', 'not_a_controller',
  'allocating the VR headset as a pad is refused');
select is(pg_temp.push('session.start', pg_temp.start(
    'a2300000-0000-0000-0000-000000000002','b2300000-0000-0000-0000-000000000002','HEX',
    jsonb_build_array(jsonb_build_object('id','a2310000-0000-0000-0000-000000000002',
      'controller_id','ad000000-0000-0000-0000-000000000001')),
    jsonb_build_array(jsonb_build_object('id','d2310000-0000-0000-0000-000000000001',
      'controller_id','ad000000-0000-0000-0000-000000000001'))))->>'error', 'not_a_controller',
  'borrowing the VR headset into a session is refused');
select is((select current_resource_id from controllers where id = 'ad000000-0000-0000-0000-000000000001'),
  pg_temp.r('RIFT'), 'the refused borrow left the headset at RIFT');

-- A Controller-kind pad is allocated normally.
select is(pg_temp.push('session.start', pg_temp.start(
    'a2300000-0000-0000-0000-000000000003','b2300000-0000-0000-0000-000000000003','HEX',
    jsonb_build_array(jsonb_build_object('id','a2310000-0000-0000-0000-000000000003',
      'controller_id','ad000000-0000-0000-0000-000000000002'))))->>'status', 'applied',
  'a Controller-kind pad is allocated');

-- ===================== kind changes while held
select pg_temp.as_user('23000000-0000-0000-0000-000000000001');
select is(pg_temp.push('accessory_kind.upsert', jsonb_build_object(
    'id','ac000000-0000-0000-0000-000000000002','name','Controller','counts_as_controller',false))->>'error',
  'accessory_kind_busy', 'a held kind cannot stop counting as a controller');
select is(pg_temp.push('controller.upsert', pg_temp.acc('ad000000-0000-0000-0000-000000000002',
    'HEX-P3', 'HEX', 'ac000000-0000-0000-0000-000000000001'))->>'error', 'controller_in_use',
  'a held pad cannot be turned into a headset');

-- ===================== every accessory can be moved, with history
select is(pg_temp.push('controller.move', jsonb_build_object(
    'controller_id','ad000000-0000-0000-0000-000000000001','kind','loan',
    'to_resource_id',pg_temp.r('GHOST'),'move_id','d2320000-0000-0000-0000-000000000001',
    'at','2026-10-01T10:00:00Z'))->>'status', 'applied', 'the headset is lent to GHOST');
select is(pg_temp.push('controller.move', jsonb_build_object(
    'controller_id','ad000000-0000-0000-0000-000000000001','kind','returnHome',
    'move_id','d2320000-0000-0000-0000-000000000002','at','2026-10-01T11:00:00Z'))->>'status', 'applied',
  'and returned home');
select results_eq($$ select kind, to_resource_id from controller_moves
     where controller_id = 'ad000000-0000-0000-0000-000000000001' order by moved_at $$,
  $$ values ('loan'::text, pg_temp.r('GHOST')), ('returnHome'::text, pg_temp.r('RIFT')) $$,
  'the headset''s move history is kept');

-- ===================== removing kinds
select is(pg_temp.push('accessory_kind.remove', jsonb_build_object(
    'id','ac000000-0000-0000-0000-000000000001'))->'result'->>'removed', 'retired',
  'a kind still on an accessory is retired');
select is((select active from accessory_kinds where id = 'ac000000-0000-0000-0000-000000000001'), false,
  '…and is inactive');
select is(pg_temp.push('controller.upsert', pg_temp.acc('ad000000-0000-0000-0000-000000000003',
    'GHOST-VR', 'GHOST', 'ac000000-0000-0000-0000-000000000001'))->>'error', 'kind_retired',
  'a new accessory cannot take a retired kind');
select is(pg_temp.push('accessory_kind.upsert', jsonb_build_object(
    'id','ac000000-0000-0000-0000-000000000004','name','Steering wheel'))->>'status', 'applied',
  'owner adds Steering wheel');
select is(pg_temp.push('accessory_kind.remove', jsonb_build_object(
    'id','ac000000-0000-0000-0000-000000000004'))->'result'->>'removed', 'deleted',
  'an unused kind is deleted');

-- ===================== type code derived from the name
select is(pg_temp.push('activity.upsert', jsonb_build_object(
    'id','ae000000-0000-0000-0000-000000000001','name','Racing Simulator'))->>'status', 'applied',
  'a type can be added with only a name');
select is((select code from activities where id = 'ae000000-0000-0000-0000-000000000001'), 'RACING_SIMUL',
  'its code is derived from the name (12 characters)');
select is(pg_temp.push('activity.upsert', jsonb_build_object(
    'id','ae000000-0000-0000-0000-000000000002','name','Racing simulator!'))->>'status', 'applied',
  'a second type with the same name stem');
select is((select code from activities where id = 'ae000000-0000-0000-0000-000000000002'), 'RACING_SIM_2',
  'gets a numbered code');
select is(pg_temp.push('activity.upsert', jsonb_build_object(
    'id','ae000000-0000-0000-0000-000000000001','name','Racing Sim'))->>'status', 'applied',
  'renaming without a code applies');
select is((select code from activities where id = 'ae000000-0000-0000-0000-000000000001'), 'RACING_SIMUL',
  '…and keeps the existing code');

select * from finish();
rollback;
