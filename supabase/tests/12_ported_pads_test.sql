-- Controller (pad) guarantees the pre-sync RPC suites (04 allocation, 05
-- borrowing, 06 explicit moves) used to pin, re-asserted through sync_push →
-- op_*: the allocation / move tables and their backstops, borrow bookkeeping
-- (location, loan owed, attributed history), all-or-nothing borrows, release
-- on reconfigure, and the controller.move op (loan / returnHome / permanent).
-- 07 already proves controller_elsewhere, controller_taken on a held pad,
-- untracked-station borrows and end/void releasing pads; 10 proves the
-- controller.move permission split.
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated fixture: this file works in its OWN arena (the same starter catalog
-- seed.sql uses), so whatever else is in the database — the dev seed, arenas
-- left by the two-device suite, a half-finished run — cannot change what it
-- sees. Created inside this transaction and rolled back with it.
insert into arenas(id, name) values ('e0000000-0000-4000-8000-000000000112'::uuid, 'pgtap 12');
-- These fixtures replay fixed past dates: widen the offline window (offline_rules, default
-- 24 h) so device-stamped times from then are accepted.
insert into settings(arena_id, key, json)
  select id, 'offline_rules', '{"max_offline_hours": 100000}' from arenas where name like 'pgtap%'
  on conflict (arena_id, key) do nothing;
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000112'::uuid);

-- ===================== schema + grants (as db owner) =====================
select has_table('public', 'controller_allocations', 'controller_allocations exists');
select has_index('public', 'controller_allocations',
  'ux_one_open_allocation_per_controller', 'one-open-per-controller unique index');
select index_is_unique('public', 'controller_allocations',
  'ux_one_open_allocation_per_controller');
select has_column('public', 'resources', 'current_mode', 'resources.current_mode (RIFT lock)');
select ok(
  (select pg_get_constraintdef(oid) from pg_constraint where conname = 'controllers_status_check')
    like '%unavailable%',
  'controllers.status allows unavailable');
select has_table('public', 'controller_moves', 'controller_moves exists');
select columns_are('public', 'controller_moves', array[
  'id','arena_id','controller_id','from_resource_id','to_resource_id','kind',
  'session_ref','moved_at','created_by','created_at','sync_xid'],
  'controller_moves = Drift ControllerMoves + arena_id/created_by/sync_xid');
select col_type_is('public','controller_moves','moved_at','timestamp with time zone',
  'moved_at is timestamptz');
select col_not_null('public','controller_moves', c, c || ' is not null')
from unnest(array['controller_id','from_resource_id','to_resource_id','kind','moved_at']) as c;
select col_is_null('public','controller_moves','session_ref','session_ref is nullable');
select has_index('public', 'controller_moves', 'ix_moves_controller',
  array['controller_id','moved_at'], 'index on (controller_id, moved_at)');
select ok(
  (select pg_get_constraintdef(oid) from pg_constraint
     where conrelid = 'public.controller_moves'::regclass and contype = 'c')
    ~ 'loan.*permanent.*returnHome',
  'kind is limited to the ControllerMoveKind codes');
select throws_ok($$
  insert into controller_moves(arena_id, controller_id, from_resource_id, to_resource_id, kind, moved_at)
  select c.arena_id, c.id, c.current_resource_id, c.home_resource_id, 'teleport', now()
  from controllers c where c.label = 'HEX-1' and c.arena_id = 'e0000000-0000-4000-8000-000000000112'::uuid $$,
  '23514', null, 'an unknown move kind is rejected by the table');
select is((select relrowsecurity from pg_class where oid = t::regclass), true,
  'RLS is enabled on ' || t)
from unnest(array['public.controller_allocations', 'public.controller_moves']) t;
select policies_are('public', 'controller_moves', array['p_sel_controller_moves'],
  'controller_moves has only the member-read policy');
select ok(has_table_privilege('authenticated', 'public.controller_moves', 'SELECT'),
  'authenticated may SELECT controller_moves (filtered by RLS)');
select ok(not has_table_privilege(r, 'public.controller_moves', p),
  r || ' has no ' || p || ' on controller_moves')
from unnest(array['authenticated','anon']) as r,
     unnest(array['INSERT','UPDATE','DELETE','TRUNCATE']) as p;
select ok(not has_table_privilege(r, 'public.controller_allocations', 'TRUNCATE'),
  r || ' cannot TRUNCATE controller_allocations')
from unnest(array['authenticated','anon']) as r;

-- The race backstop: even a DIRECT insert (bypassing every op, as the table
-- owner) cannot open a second allocation for a pad that already has one.
-- RIFT-2 is used only here and stays held for the rest of the file.
select lives_ok($$
  insert into controller_allocations(id, arena_id, controller_id, scope, resource_id, activity_code, started_at)
  select gen_random_uuid(), c.arena_id, c.id, 'single', c.current_resource_id, 'PS5', now()
  from controllers c where c.label = 'RIFT-2' and c.arena_id = 'e0000000-0000-4000-8000-000000000112'::uuid $$,
  'a first open allocation inserts');
select throws_ok($$
  insert into controller_allocations(id, arena_id, controller_id, scope, resource_id, activity_code, started_at)
  select gen_random_uuid(), c.arena_id, c.id, 'single', c.current_resource_id, 'PS5', now()
  from controllers c where c.label = 'RIFT-2' and c.arena_id = 'e0000000-0000-4000-8000-000000000112'::uuid $$,
  'controller_taken', 'a second OPEN allocation for the same pad is rejected');

-- ---------------------------------------------------------------- fixture
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  values
  ('00000000-0000-0000-0000-000000000000','12000000-0000-0000-0000-000000000001','authenticated',
   'authenticated','owner12@test.local','',now(),now(),now(),'{}','{}',false,false),
  ('00000000-0000-0000-0000-000000000000','12000000-0000-0000-0000-000000000002','authenticated',
   'authenticated','staff12@test.local','',now(),now(),now(),'{}','{}',false,false)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000112'::uuid,'12000000-0000-0000-0000-000000000001','Owner','owner',
    array['start','bill','discount','members','stations','money','reports','settings'],true),
  ('e0000000-0000-4000-8000-000000000112'::uuid,'12000000-0000-0000-0000-000000000002','Staff','staff',
    array['start','bill','discount','members'],true);
-- VOID-2 is out of service.
update controllers set status = 'faulty'
 where label = 'VOID-2' and arena_id = 'e0000000-0000-4000-8000-000000000112'::uuid;

create function pg_temp.r(n text) returns uuid as $$ select id from resources where name = n and arena_id = 'e0000000-0000-4000-8000-000000000112'::uuid $$ language sql;
create function pg_temp.c(l text) returns uuid as $$ select id from controllers where label = l and arena_id = 'e0000000-0000-4000-8000-000000000112'::uuid $$ language sql;
create function pg_temp.pad(p_id text, p_label text) returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'controller_id', pg_temp.c(p_label)) $$ language sql;
create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.push(p_kind text, p jsonb, p_op uuid default gen_random_uuid()) returns jsonb as $$
  select sync_push('e0000000-0000-4000-8000-000000000112'::uuid,
    jsonb_build_array(jsonb_build_object('op_id', p_op, 'kind', p_kind, 'payload', p)), 'pgtap')
    -> 'results' -> 0 $$ language sql;
create function pg_temp.start(p_id text, p_seg text, p_res text, p_at text, p_allocs jsonb,
    p_moves jsonb default '[]') returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'segment_id', p_seg::uuid,
    'customer_id', 'cccccccc-0000-0000-0000-000000000012',
    'started_at', p_at, 'scheduled_end_at', '2026-10-01T12:00:00Z',
    'pricing_snapshot', _pricing_snapshot('e0000000-0000-4000-8000-000000000112'::uuid),
    'resource_id', pg_temp.r(p_res), 'activity_code', 'PS5', 'game_id', null,
    'controller_count', jsonb_array_length(p_allocs), 'allocations', p_allocs, 'moves', p_moves)
  $$ language sql;
create function pg_temp.mv(p_label text, p_kind text, p_to text default null,
    p_ref text default null, p_move text default null, p_at text default null) returns jsonb as $$
  select jsonb_build_object('controller_id', pg_temp.c(p_label), 'kind', p_kind,
    'to_resource_id', pg_temp.r(p_to), 'session_ref', p_ref, 'move_id', p_move::uuid, 'at', p_at)
  $$ language sql;
-- Each pad's move history, oldest first.
create function pg_temp.moves(p_label text) returns table(kind text, session_ref text,
    from_res uuid, to_res uuid) as $$
  select m.kind, m.session_ref, m.from_resource_id, m.to_resource_id
    from controller_moves m where m.controller_id = pg_temp.c(p_label)
   order by m.moved_at, m.created_at, m.kind $$ language sql;

select pg_temp.as_user('12000000-0000-0000-0000-000000000002');
select is(pg_temp.push('customer.create', jsonb_build_object(
    'id','cccccccc-0000-0000-0000-000000000012','name','Meera','phone','9800001212',
    'is_guest', false))->>'status', 'applied', 'staff creates a customer');

-- ------------------------------------------- 1. a borrow moves the pad and owes its return
select is(pg_temp.push('session.start', pg_temp.start(
    'a1200000-0000-0000-0000-000000000001','b1200000-0000-0000-0000-000000000001','HEX',
    '2026-10-01T09:00:00Z',
    jsonb_build_array(pg_temp.pad('a1210000-0000-0000-0000-000000000001','HEX-1'),
                      pg_temp.pad('a1210000-0000-0000-0000-000000000002','GHOST-1')),
    jsonb_build_array(pg_temp.pad('d1210000-0000-0000-0000-000000000001','GHOST-1'))),
    'f1200000-0000-0000-0000-000000000001')->>'status', 'applied',
  'HEX starts with HEX-1 and GHOST-1 borrowed');
select ok((select current_resource_id = pg_temp.r('HEX') and home_resource_id = pg_temp.r('GHOST')
             and loan_return_to = pg_temp.r('GHOST')::text
             and loan_session_ref = 's:a1200000-0000-0000-0000-000000000001'
             from controllers where id = pg_temp.c('GHOST-1')),
  'GHOST-1 is at HEX, still homed at GHOST, owing its return to the session');
select results_eq($$
  select id, from_resource_id, to_resource_id, kind, session_ref, moved_at, created_by
    from controller_moves where controller_id = pg_temp.c('GHOST-1') $$,
  $$ values ('d1210000-0000-0000-0000-000000000001'::uuid, pg_temp.r('GHOST'), pg_temp.r('HEX'),
             'loan'::text, 's:a1200000-0000-0000-0000-000000000001'::text,
             '2026-10-01T09:00:00Z'::timestamptz, '12000000-0000-0000-0000-000000000002'::uuid) $$,
  'one loan GHOST -> HEX under the device move id, at the start time, attributed to staff');
select is((select resource_id from controller_allocations
            where controller_id = pg_temp.c('GHOST-1') and ended_at is null), pg_temp.r('HEX'),
  'the borrowed pad''s open allocation is at HEX');

-- ------------------------------------------- 2. a retried start neither re-borrows nor re-allocates
select is(pg_temp.push('session.start', pg_temp.start(
    'a1200000-0000-0000-0000-000000000001','b1200000-0000-0000-0000-000000000001','HEX',
    '2026-10-01T09:00:00Z',
    jsonb_build_array(pg_temp.pad('a1210000-0000-0000-0000-000000000001','HEX-1'),
                      pg_temp.pad('a1210000-0000-0000-0000-000000000002','GHOST-1')),
    jsonb_build_array(pg_temp.pad('d1210000-0000-0000-0000-000000000001','GHOST-1'))),
    'f1200000-0000-0000-0000-000000000001')->>'replayed', 'true', 'the same op pushed again is replayed');
select is((select count(*)::int from controller_allocations
            where session_id = 'a1200000-0000-0000-0000-000000000001'), 2, 'still two allocations');
select is((select count(*)::int from controller_moves where controller_id = pg_temp.c('GHOST-1')), 1,
  'still one move');

-- ------------------------------------------- 4. borrows are all-or-nothing
select is(pg_temp.push('session.start', pg_temp.start(
    'a1200000-0000-0000-0000-000000000002','b1200000-0000-0000-0000-000000000002','RIFT',
    '2026-10-01T09:10:00Z',
    jsonb_build_array(pg_temp.pad('a1230000-0000-0000-0000-000000000001','GHOST-2'),
                      pg_temp.pad('a1230000-0000-0000-0000-000000000002','HEX-1')),
    jsonb_build_array(pg_temp.pad('d1230000-0000-0000-0000-000000000001','GHOST-2'),
                      pg_temp.pad('d1230000-0000-0000-0000-000000000002','HEX-1'))))
    ->>'error', 'controller_taken', 'a start whose second borrow hits a held pad is refused');
select is((select current_resource_id from controllers where id = pg_temp.c('GHOST-2')), pg_temp.r('GHOST'),
  'the first pad in the refused op stayed home');
select is((select count(*)::int from controller_moves where controller_id = pg_temp.c('GHOST-2')), 0,
  'and has no move history');
select is(pg_temp.push('session.start', pg_temp.start(
    'a1200000-0000-0000-0000-000000000002','b1200000-0000-0000-0000-000000000002','RIFT',
    '2026-10-01T09:10:00Z',
    jsonb_build_array(pg_temp.pad('a1230000-0000-0000-0000-000000000003','VOID-2')),
    jsonb_build_array(pg_temp.pad('d1230000-0000-0000-0000-000000000003','VOID-2'))))
    ->>'error', 'controller_unusable', 'a faulty pad cannot be borrowed');
select is((select current_resource_id from controllers where id = pg_temp.c('VOID-2')), pg_temp.r('VOID'),
  'and it stays where it is');

-- ------------------------------------------- 5. a pad already at the station is not moved
select is(pg_temp.push('session.start', pg_temp.start(
    'a1200000-0000-0000-0000-000000000002','b1200000-0000-0000-0000-000000000002','RIFT',
    '2026-10-01T09:10:00Z',
    jsonb_build_array(pg_temp.pad('a1230000-0000-0000-0000-000000000004','RIFT-1')),
    jsonb_build_array(pg_temp.pad('d1230000-0000-0000-0000-000000000004','RIFT-1'))))
    ->'result'->>'adjusted', 'true', '"borrowing" RIFT-1 into RIFT applies, flagged adjusted');
select is((select count(*)::int from controller_moves where controller_id = pg_temp.c('RIFT-1')), 0,
  'and records no move');

-- ------------------------------------------- 6. reconfigure releases; a borrow home clears the loan
select is(pg_temp.push('session.reconfigure', jsonb_build_object(
    'session_id','a1200000-0000-0000-0000-000000000001','at','2026-10-01T09:30:00Z',
    'expected_segment_id','b1200000-0000-0000-0000-000000000001',
    'new_segment_id','b1200000-0000-0000-0000-000000000003','resource_id', pg_temp.r('HEX'),
    'activity_code','PS5','controller_count',1,
    'allocations', jsonb_build_array(pg_temp.pad('a1210000-0000-0000-0000-000000000003','HEX-1')),
    'moves','[]'::jsonb))->>'status', 'applied', 'HEX drops to one pad (HEX-1) at 09:30Z');
select is((select count(*)::int from controller_allocations
            where controller_id = pg_temp.c('GHOST-1') and ended_at = '2026-10-01T09:30:00Z'), 1,
  'GHOST-1''s allocation was closed at the switch');
select is((select count(*)::int from controller_allocations
            where controller_id = pg_temp.c('HEX-1') and ended_at is null), 1,
  'HEX-1 carried over into the new segment, held once');
select is(pg_temp.push('session.start', pg_temp.start(
    'a1200000-0000-0000-0000-000000000003','b1200000-0000-0000-0000-000000000004','GHOST',
    '2026-10-01T10:00:00Z',
    jsonb_build_array(pg_temp.pad('a1240000-0000-0000-0000-000000000001','GHOST-1')),
    jsonb_build_array(pg_temp.pad('d1240000-0000-0000-0000-000000000001','GHOST-1'))))
    ->>'status', 'applied', 'the released GHOST-1 is carried home and allocated again at GHOST');
select ok((select current_resource_id = pg_temp.r('GHOST') and loan_return_to is null
             and loan_session_ref is null from controllers where id = pg_temp.c('GHOST-1')),
  'arriving home clears loan_return_to / loan_session_ref');
select results_eq($$ select * from pg_temp.moves('GHOST-1') $$,
  $$ values ('loan'::text, 's:a1200000-0000-0000-0000-000000000001'::text, pg_temp.r('GHOST'), pg_temp.r('HEX')),
            ('returnHome'::text, null::text, pg_temp.r('HEX'), pg_temp.r('GHOST')) $$,
  'GHOST-1''s timeline is loan then returnHome (append-only, no session_ref on the return)');

-- ------------------------------------------- 7. controller.move as staff
select is(pg_temp.push('controller.move', pg_temp.mv('VOID-1', 'permanent', 'RIFT'))->>'error',
  'forbidden', 'staff cannot re-home a pad');
select ok((select home_resource_id = pg_temp.r('VOID') and current_resource_id = pg_temp.r('VOID')
             from controllers where id = pg_temp.c('VOID-1')),
  'the refused permanent move left the pad home');
select is(pg_temp.push('controller.move', pg_temp.mv('VOID-1', 'loan', 'RIFT', 's:rift-session',
    'd1250000-0000-0000-0000-000000000001', '2026-10-01T10:00:00Z'))->'result'->>'moved', 'true',
  'staff loans VOID-1 to RIFT');
select ok((select current_resource_id = pg_temp.r('RIFT') and home_resource_id = pg_temp.r('VOID')
             and loan_return_to = pg_temp.r('VOID')::text and loan_session_ref = 's:rift-session'
             from controllers where id = pg_temp.c('VOID-1')),
  'the loaned pad is at RIFT, still homed at VOID, owing its return');
select results_eq($$
  select id, moved_at, created_by from controller_moves where controller_id = pg_temp.c('VOID-1') $$,
  $$ values ('d1250000-0000-0000-0000-000000000001'::uuid, '2026-10-01T10:00:00Z'::timestamptz,
             '12000000-0000-0000-0000-000000000002'::uuid) $$,
  'one history row under the device move id, at the move time, attributed to staff');
select is(pg_temp.push('controller.move', pg_temp.mv('VOID-1', 'loan', 'RIFT', 's:rift-session',
    'd1250000-0000-0000-0000-000000000002', '2026-10-01T10:01:00Z'))->'result'->>'moved', 'false',
  'repeating the loan (pad already there) reports no move');
select is((select count(*)::int from controller_moves where controller_id = pg_temp.c('VOID-1')), 1,
  'and records no history');
select is(pg_temp.push('controller.move', pg_temp.mv('VOID-1', 'returnHome', 'HEX', 's:ignored',
    'd1250000-0000-0000-0000-000000000003', '2026-10-01T10:30:00Z'))->'result'->>'moved', 'true',
  'staff returns VOID-1 (the destination given is ignored)');
select ok((select current_resource_id = pg_temp.r('VOID') and loan_return_to is null
             and loan_session_ref is null from controllers where id = pg_temp.c('VOID-1')),
  'the returned pad is home with its loan cleared');
select is(pg_temp.push('controller.move', pg_temp.mv('VOID-1', 'returnHome'))->'result'->>'moved', 'false',
  'returning a pad already home is a no-op');
select results_eq($$ select * from pg_temp.moves('VOID-1') $$,
  $$ values ('loan'::text, 's:rift-session'::text, pg_temp.r('VOID'), pg_temp.r('RIFT')),
            ('returnHome'::text, null::text, pg_temp.r('RIFT'), pg_temp.r('VOID')) $$,
  'the timeline is loan then returnHome, with no session_ref on the return');

-- A pad held by an open allocation cannot be moved — not even "returned".
select is(pg_temp.push('controller.move', pg_temp.mv('HEX-1', 'loan', 'VOID', 's:void-session'))
    ->>'error', 'controller_in_use', 'a pad in use cannot be loaned away');
select is(pg_temp.push('controller.move', pg_temp.mv('HEX-1', 'returnHome'))->>'error',
  'controller_in_use', 'a pad in use cannot be returned');
select is((select current_resource_id from controllers where id = pg_temp.c('HEX-1')), pg_temp.r('HEX'),
  'and it stays where it is');

-- Bad input.
select is(pg_temp.push('controller.move', pg_temp.mv('HEX-2', 'teleport', 'VOID'))->>'error',
  'move_kind_invalid', 'an unknown move kind is refused');
select is(pg_temp.push('controller.move', pg_temp.mv('HEX-2', 'loan'))->>'error',
  'resource_missing', 'a loan needs a destination');
select is(pg_temp.push('controller.move', pg_temp.mv('HEX-2', 'loan')
    || jsonb_build_object('to_resource_id', gen_random_uuid()))->>'error',
  'resource_missing', 'a loan to an unknown station is refused');
select is(pg_temp.push('controller.move', jsonb_build_object('controller_id', gen_random_uuid(),
    'kind','returnHome'))->>'error', 'controller_missing', 'an unknown pad is refused');

select is(pg_temp.push('controller.move', pg_temp.mv('HEX-2', 'loan', 'RIFT', 's:rift-session'))
    ->'result'->>'moved', 'true', 'HEX-2 is loaned to RIFT');

-- ------------------------------------------- 8. controller.move as owner (permanent)
select pg_temp.as_user('12000000-0000-0000-0000-000000000001');
select is(pg_temp.push('controller.move', pg_temp.mv('VOID-1', 'permanent', 'RIFT', 's:ignored'))
    ->'result'->>'moved', 'true', 'the owner moves VOID-1 permanently to RIFT');
select ok((select current_resource_id = pg_temp.r('RIFT') and home_resource_id = pg_temp.r('RIFT')
             and loan_return_to is null and loan_session_ref is null
             from controllers where id = pg_temp.c('VOID-1')),
  'the pad now lives at RIFT and owes no return');
select results_eq($$
  select from_resource_id, to_resource_id, session_ref, created_by from controller_moves
   where controller_id = pg_temp.c('VOID-1') and kind = 'permanent' $$,
  $$ values (pg_temp.r('VOID'), pg_temp.r('RIFT'), null::text,
             '12000000-0000-0000-0000-000000000001'::uuid) $$,
  'one permanent VOID -> RIFT move, no session_ref, attributed to the owner');
-- Re-homing a loaned pad where it already is: no move, but it is homed there
-- and the loan is cleared (as on the device).
select is(pg_temp.push('controller.move', pg_temp.mv('HEX-2', 'permanent', 'RIFT'))
    ->'result'->>'moved', 'false', 'a permanent move to where the pad already is records no move');
select ok((select home_resource_id = pg_temp.r('RIFT') and current_resource_id = pg_temp.r('RIFT')
             and loan_return_to is null and loan_session_ref is null
             from controllers where id = pg_temp.c('HEX-2')),
  'but it re-homes the pad and clears its loan');
select is((select count(*)::int from controller_moves where controller_id = pg_temp.c('HEX-2')), 1,
  'HEX-2 history is just the loan');

select * from finish();
rollback;
