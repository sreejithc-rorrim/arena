-- The multi-device write path (0010–0012): sync_push → op_* → sync_pull.
--
-- Covers the critical controller scenario end to end on the server:
--   HEX runs HEX-1, HEX-2 + VOID-1, VOID-2 (borrowed). A new customer wants VOID:
--   VOID-1/2 cannot be allocated again; GHOST pads can be borrowed; when the
--   venue runs out the op is refused with a clear code; ending keeps the
--   allocation + return history. Then count-only sessions, permissions, idempotency, stale writes, check-in and the feed.
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated fixture: this file works in its OWN arena (the same starter catalog
-- seed.sql uses), so whatever else is in the database — the dev seed, arenas
-- left by the two-device suite, a half-finished run — cannot change what it
-- sees. Created inside this transaction and rolled back with it.
insert into arenas(id, name) values ('e0000000-0000-4000-8000-000000000007'::uuid, 'pgtap 07');
-- These fixtures replay fixed past dates: widen the offline window (offline_rules, default
-- 24 h) so device-stamped times from then are accepted.
insert into settings(arena_id, key, json)
  select id, 'offline_rules', '{"max_offline_hours": 100000}' from arenas where name like 'pgtap%'
  on conflict (arena_id, key) do nothing;
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000007'::uuid);
-- Happy hours are a pricing rule: Tue–Fri 14:00–17:00 IST (08:30–11:30Z), not on holidays,
-- PS5, 20% lower for the whole session when it starts inside the window.
insert into pricing_rules(arena_id, name, days, start_min, end_min, holiday_mode, activity_codes,
    adjust_kind, adjust_value)
  values ('e0000000-0000-4000-8000-000000000007'::uuid, 'Happy hours', '{2,3,4,5}', 840, 1020,
    'skip', '{PS5}', 'percent', -20);

-- ---------------------------------------------------------------- fixture
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  values
  ('00000000-0000-0000-0000-000000000000','11111111-1111-1111-1111-111111111111','authenticated',
   'authenticated','owner@test.local','',now(),now(),now(),'{}','{}',false,false),
  ('00000000-0000-0000-0000-000000000000','22222222-2222-2222-2222-222222222222','authenticated',
   'authenticated','staff@test.local','',now(),now(),now(),'{}','{}',false,false),
  ('00000000-0000-0000-0000-000000000000','33333333-3333-3333-3333-333333333333','authenticated',
   'authenticated','nobill@test.local','',now(),now(),now(),'{}','{}',false,false)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000007'::uuid,'11111111-1111-1111-1111-111111111111','Owner','owner',
    array['start','bill','discount','members','stations','money','reports','settings'],true),
  ('e0000000-0000-4000-8000-000000000007'::uuid,'22222222-2222-2222-2222-222222222222','Staff','staff',
    array['start','bill','discount','members'],true),
  ('e0000000-0000-4000-8000-000000000007'::uuid,'33333333-3333-3333-3333-333333333333','Starter','staff',
    array['start'],true);

create function pg_temp.r(n text) returns uuid as $$ select id from resources where name = n and arena_id = 'e0000000-0000-4000-8000-000000000007'::uuid $$ language sql;
create function pg_temp.c(l text) returns uuid as $$ select id from controllers where label = l and arena_id = 'e0000000-0000-4000-8000-000000000007'::uuid $$ language sql;
create function pg_temp.g(n text) returns uuid as $$ select id from games where name = n and arena_id = 'e0000000-0000-4000-8000-000000000007'::uuid $$ language sql;
create function pg_temp.pad(p_id text, p_label text) returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'controller_id', pg_temp.c(p_label)) $$ language sql;
create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.push(p_kind text, p jsonb, p_op uuid default gen_random_uuid()) returns jsonb as $$
  select sync_push('e0000000-0000-4000-8000-000000000007'::uuid,
    jsonb_build_array(jsonb_build_object('op_id', p_op, 'kind', p_kind, 'payload', p)), 'pgtap')
    -> 'results' -> 0 $$ language sql;
create function pg_temp.start(p_id text, p_seg text, p_res text, p_cc int, p_allocs jsonb,
    p_moves jsonb default '[]', p_game text default 'EA SPORTS FC 25', p_booking uuid default null)
returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'segment_id', p_seg::uuid,
    'customer_id', 'cccccccc-0000-0000-0000-000000000001',
    'booking_id', p_booking,
    'started_at', '2026-10-01T09:00:00Z', 'scheduled_end_at', '2026-10-01T10:00:00Z',
    -- The arena's own price list, as an in-sync device would freeze it (0013).
    'pricing_snapshot', _pricing_snapshot('e0000000-0000-4000-8000-000000000007'::uuid),
    'resource_id', pg_temp.r(p_res), 'activity_code', 'PS5', 'game_id', pg_temp.g(p_game),
    'controller_count', p_cc, 'allocations', p_allocs, 'moves', p_moves) $$ language sql;

select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select is(pg_temp.push('customer.create', jsonb_build_object(
    'id','cccccccc-0000-0000-0000-000000000001','name','Ravi','phone','9800000001',
    'is_guest', false))->>'status', 'applied', 'staff creates a customer through sync_push');

-- ------------------------------------------- 1. HEX takes HEX-1/2 + borrows VOID-1/2
select is(pg_temp.push('session.start', pg_temp.start(
    'aaaaaaaa-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001','HEX', 4,
    jsonb_build_array(pg_temp.pad('a1000000-0000-0000-0000-000000000001','HEX-1'),
                      pg_temp.pad('a1000000-0000-0000-0000-000000000002','HEX-2'),
                      pg_temp.pad('a1000000-0000-0000-0000-000000000003','VOID-1'),
                      pg_temp.pad('a1000000-0000-0000-0000-000000000004','VOID-2')),
    jsonb_build_array(pg_temp.pad('dd100000-0000-0000-0000-000000000001','VOID-1'),
                      pg_temp.pad('dd100000-0000-0000-0000-000000000002','VOID-2'))))
    ->>'status', 'applied', 'HEX starts with HEX-1, HEX-2 and borrowed VOID-1, VOID-2');
select is((select count(*)::int from controller_allocations
            where session_id = 'aaaaaaaa-0000-0000-0000-000000000001' and ended_at is null),
  4, 'four open allocations for the HEX session, with the device ids');
select ok(exists(select 1 from controller_allocations where id = 'a1000000-0000-0000-0000-000000000003'),
  'server uses the allocation id the device generated');
select is((select current_resource_id from controllers where label = 'VOID-1' and arena_id = 'e0000000-0000-4000-8000-000000000007'::uuid), pg_temp.r('HEX'),
  'VOID-1 is physically at HEX after the borrow');
select is((select count(*)::int from controller_moves where session_ref = 's:aaaaaaaa-0000-0000-0000-000000000001'),
  2, 'two loan moves recorded with the device move ids');

-- ------------------------------------------- 2. VOID cannot re-use VOID-1/2
select is(pg_temp.push('session.start', pg_temp.start(
    'aaaaaaaa-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000002','VOID', 2,
    jsonb_build_array(pg_temp.pad('a2000000-0000-0000-0000-000000000001','VOID-1'),
                      pg_temp.pad('a2000000-0000-0000-0000-000000000002','VOID-2'))))
    ->>'error', 'controller_elsewhere', 'VOID-1/2 are not at VOID: refused');
select is(pg_temp.push('session.start', pg_temp.start(
    'aaaaaaaa-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000002','VOID', 2,
    jsonb_build_array(pg_temp.pad('a2000000-0000-0000-0000-000000000001','VOID-1'),
                      pg_temp.pad('a2000000-0000-0000-0000-000000000002','VOID-2')),
    jsonb_build_array(pg_temp.pad('dd200000-0000-0000-0000-000000000001','VOID-1'),
                      pg_temp.pad('dd200000-0000-0000-0000-000000000002','VOID-2'))))
    ->>'error', 'controller_taken', 'carrying VOID-1/2 back from HEX is refused: they are in use');
select is(pg_temp.push('session.start', pg_temp.start(
    'aaaaaaaa-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000002','VOID', 2, '[]'))
    ->>'error', 'controllers_unavailable', 'count-only start at VOID: no free pads there, refused');
select is((select count(*)::int from sessions where id = 'aaaaaaaa-0000-0000-0000-000000000002'), 0,
  'no half-written session after the refusals');

-- ------------------------------------------- 3. borrow from GHOST and start at VOID
select is(pg_temp.push('session.start', pg_temp.start(
    'aaaaaaaa-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000002','VOID', 2,
    jsonb_build_array(pg_temp.pad('a2000000-0000-0000-0000-000000000003','GHOST-1'),
                      pg_temp.pad('a2000000-0000-0000-0000-000000000004','GHOST-2')),
    jsonb_build_array(pg_temp.pad('dd200000-0000-0000-0000-000000000003','GHOST-1'),
                      pg_temp.pad('dd200000-0000-0000-0000-000000000004','GHOST-2'))))
    ->>'status', 'applied', 'VOID starts with GHOST-1/2 borrowed in the same op');
select is((select count(*)::int from controller_allocations a join controllers c on c.id = a.controller_id
            where c.arena_id = 'e0000000-0000-4000-8000-000000000007'::uuid and a.ended_at is null and c.label in ('VOID-1','VOID-2')), 2,
  'VOID-1/2 are each still held exactly once (by HEX)');

-- ------------------------------------------- 4. venue short → clear refusal
select is(pg_temp.push('session.start', pg_temp.start(
    'aaaaaaaa-0000-0000-0000-000000000003','bbbbbbbb-0000-0000-0000-000000000003','RIFT', 4,
    jsonb_build_array(pg_temp.pad('a3000000-0000-0000-0000-000000000001','RIFT-1'),
                      pg_temp.pad('a3000000-0000-0000-0000-000000000002','RIFT-2'),
                      pg_temp.pad('a3000000-0000-0000-0000-000000000003','GHOST-1'),
                      pg_temp.pad('a3000000-0000-0000-0000-000000000004','GHOST-2')),
    jsonb_build_array(pg_temp.pad('dd300000-0000-0000-0000-000000000001','GHOST-1'),
                      pg_temp.pad('dd300000-0000-0000-0000-000000000002','GHOST-2'))))
    ->>'error', 'controller_taken', 'four at RIFT when only two pads are free venue-wide: refused');
select is((select count(*)::int from controller_allocations
            where controller_id in (pg_temp.c('RIFT-1'), pg_temp.c('RIFT-2'))), 0,
  'the refused op allocated nothing (all-or-nothing)');

-- ------------------------------------------- 5. permissions
select pg_temp.as_user('33333333-3333-3333-3333-333333333333');
select is(pg_temp.push('payment.record', jsonb_build_object('scope','single',
    'parent_id','aaaaaaaa-0000-0000-0000-000000000002','payment_id','e0000000-0000-0000-0000-000000000009',
    'amount_paise', 10000, 'method','cash'))->>'error', 'forbidden',
  'a member without bill cannot take a payment (server-enforced)');
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select is(pg_temp.push('session.void', jsonb_build_object(
    'session_id','aaaaaaaa-0000-0000-0000-000000000002','reason','x'))->>'error', 'forbidden',
  'staff cannot void');
select is(pg_temp.push('rate.upsert', jsonb_build_object('activity_code','PS5','band','standard',
    'controller_count',1,'unit_minutes',60,'price_paise',1))->>'error', 'forbidden',
  'staff cannot change pricing');
select is((select price_paise from sync_v_rates where arena_id = 'e0000000-0000-4000-8000-000000000007'::uuid and activity_code='PS5' and band='standard'
            and controller_count = 1), 15000::bigint, 'price unchanged');

-- ------------------------------------------- 6. idempotency + payments never duplicate
select is(pg_temp.push('payment.record', jsonb_build_object('scope','single',
    'parent_id','aaaaaaaa-0000-0000-0000-000000000002','payment_id','e0000000-0000-0000-0000-000000000001',
    'amount_paise', 20000, 'method','cash'), 'f0000000-0000-0000-0000-000000000001')->>'status',
  'applied', 'payment recorded');
select is(pg_temp.push('payment.record', jsonb_build_object('scope','single',
    'parent_id','aaaaaaaa-0000-0000-0000-000000000002','payment_id','e0000000-0000-0000-0000-000000000001',
    'amount_paise', 20000, 'method','cash'), 'f0000000-0000-0000-0000-000000000001')->>'replayed',
  'true', 'the same op pushed again (timeout retry) is replayed, not re-applied');
select is(pg_temp.push('payment.record', jsonb_build_object('scope','single',
    'parent_id','aaaaaaaa-0000-0000-0000-000000000002','payment_id','e0000000-0000-0000-0000-000000000001',
    'amount_paise', 20000, 'method','cash'))->>'error', 'duplicate',
  'the same payment under a NEW op id is refused by its primary key');
select is((select count(*)::int from payments where session_id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  1, 'exactly one payment row');

-- ------------------------------------------- 7. stale writes are refused
select is(pg_temp.push('session.extend', jsonb_build_object('session_id','aaaaaaaa-0000-0000-0000-000000000002',
    'extension_id', gen_random_uuid(), 'added_minutes', 30, 'old_end_at','2026-10-01T09:30:00Z',
    'new_end_at','2026-10-01T10:00:00Z','added_amount_paise', 0))->>'error', 'stale',
  'extend from an end the server no longer has: stale');
select is(pg_temp.push('session.extend', jsonb_build_object('session_id','aaaaaaaa-0000-0000-0000-000000000002',
    'extension_id','e1000000-0000-0000-0000-000000000001', 'added_minutes', 30,
    'old_end_at','2026-10-01T10:00:00Z', 'new_end_at','2026-10-01T10:30:00Z',
    'added_amount_paise', 11200))->>'status', 'applied', 'extend from the current end applies');
select is(pg_temp.push('session.end', jsonb_build_object('session_id','aaaaaaaa-0000-0000-0000-000000000002',
    'ended_at','2026-10-01T10:30:00Z', 'billed_amount_paise', 42000, 'mark_waived', false,
    'expected_segment_ids', jsonb_build_array('bbbbbbbb-0000-0000-0000-000000000002'),
    'expected_scheduled_end_at','2026-10-01T10:00:00Z', 'charges','[]'::jsonb))->>'error', 'stale',
  'end priced before the extension: stale');

-- ------------------------------------------- 8. end releases pads, history preserved
select is(pg_temp.push('session.end', jsonb_build_object('session_id','aaaaaaaa-0000-0000-0000-000000000002',
    'ended_at','2026-10-01T10:30:00Z', 'billed_amount_paise', 33600, 'mark_waived', false,
    'expected_segment_ids', jsonb_build_array('bbbbbbbb-0000-0000-0000-000000000002'),
    'expected_scheduled_end_at','2026-10-01T10:30:00Z',
    'charges', jsonb_build_array(jsonb_build_object('id','c1000000-0000-0000-0000-000000000001',
      'segment_id','bbbbbbbb-0000-0000-0000-000000000002','segment_index',0,'band_code','standard',
      'activity_code','PS5','resource_id', pg_temp.r('VOID'),'controller_count',2,
      'segment_start','2026-10-01T09:00:00Z','segment_end','2026-10-01T10:30:00Z',
      'played_minutes',90,'billed_minutes',90,'unit_minutes',60,'unit_price_paise',22400,
      'amount_paise',33600)))) ->>'status', 'applied', 'VOID session ends (happy hours rule, 2 pads)');
select is((select count(*)::int from controller_allocations
            where session_id = 'aaaaaaaa-0000-0000-0000-000000000002' and ended_at is null), 0,
  'ending released both pads');
select is((select count(*)::int from controller_allocations
            where session_id = 'aaaaaaaa-0000-0000-0000-000000000002' and ended_at = '2026-10-01T10:30:00Z'),
  2, 'allocation history kept, closed at the end time');
select is((select payment_status from sessions where id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  'partial', 'payment status recomputed at end');
select is(pg_temp.push('controller.move', jsonb_build_object('controller_id', pg_temp.c('GHOST-1'),
    'kind','returnHome','at','2026-10-01T10:31:00Z','move_id','d0000000-0000-0000-0000-000000000001'))
    ->>'status', 'applied', 'GHOST-1 returned home');
select is((select count(*)::int from controller_moves where controller_id = pg_temp.c('GHOST-1')), 2,
  'GHOST-1 history: loan out + return home');
select is((select current_resource_id from controllers where label='GHOST-1' and arena_id = 'e0000000-0000-4000-8000-000000000007'::uuid), pg_temp.r('GHOST'),
  'GHOST-1 is home');
select is(pg_temp.push('session.end', jsonb_build_object('session_id','aaaaaaaa-0000-0000-0000-000000000002',
    'ended_at','2026-10-01T10:40:00Z', 'billed_amount_paise', 42000,
    'expected_segment_ids', jsonb_build_array('bbbbbbbb-0000-0000-0000-000000000002'),
    'expected_scheduled_end_at','2026-10-01T10:30:00Z', 'charges','[]'::jsonb))->>'error',
  'not_active', 'a second device ending the same session is refused (no second set of charges)');

-- ------------------------------------------- 9. a count-only (legacy) session guards its pads
select is(pg_temp.push('session.start', pg_temp.start(
    'aaaaaaaa-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000004','RIFT', 2, '[]'))
    ->>'status', 'applied', 'count-only start at RIFT (two free pads there)');
select is(pg_temp.push('session.start', pg_temp.start(
    'aaaaaaaa-0000-0000-0000-000000000005','bbbbbbbb-0000-0000-0000-000000000005','VOID', 1,
    jsonb_build_array(pg_temp.pad('a5000000-0000-0000-0000-000000000001','RIFT-1')),
    jsonb_build_array(pg_temp.pad('dd500000-0000-0000-0000-000000000001','RIFT-1'))))
    ->>'error', 'controller_taken', 'cannot borrow from a station whose count-only player may hold the pad');

-- ------------------------------------------- 10. booking check-in is atomic + single
select is(pg_temp.push('booking.create', jsonb_build_object('id','b0000000-0000-0000-0000-000000000001',
    'customer_id','cccccccc-0000-0000-0000-000000000001','activity_code','PS5',
    'resource_id', pg_temp.r('GHOST'), 'scheduled_start','2026-10-01T12:00:00Z',
    'scheduled_end','2026-10-01T13:00:00Z'))->>'status', 'applied', 'booking created');
select is(pg_temp.push('booking.create', jsonb_build_object('id','b0000000-0000-0000-0000-000000000002',
    'activity_code','PS5','resource_id', pg_temp.r('GHOST'), 'scheduled_start','2026-10-01T12:30:00Z',
    'scheduled_end','2026-10-01T13:30:00Z'))->>'error', 'booking_conflict',
  'overlapping booking on the same station from another device: refused');
select is(pg_temp.push('session.start', pg_temp.start(
    'aaaaaaaa-0000-0000-0000-000000000006','bbbbbbbb-0000-0000-0000-000000000006','GHOST', 1,
    jsonb_build_array(pg_temp.pad('a6000000-0000-0000-0000-000000000001','GHOST-1')), '[]',
    'EA SPORTS FC 25', 'b0000000-0000-0000-0000-000000000001'))->>'error', 'not_playable',
  'EA FC is not playable on GHOST (seed override) — refused before check-in');
select is((select status from bookings where id='b0000000-0000-0000-0000-000000000001'), 'booked',
  'a refused check-in leaves the booking open');
select is(pg_temp.push('session.start', pg_temp.start(
    'aaaaaaaa-0000-0000-0000-000000000006','bbbbbbbb-0000-0000-0000-000000000006','GHOST', 1,
    jsonb_build_array(pg_temp.pad('a6000000-0000-0000-0000-000000000001','GHOST-1')), '[]',
    'Tekken 8', 'b0000000-0000-0000-0000-000000000001'))->>'status', 'applied',
  'check-in starts the session');
select is((select status from bookings where id='b0000000-0000-0000-0000-000000000001'), 'checked_in',
  'and checks the booking in, in the same transaction');
select is(pg_temp.push('session.start', pg_temp.start(
    'aaaaaaaa-0000-0000-0000-000000000007','bbbbbbbb-0000-0000-0000-000000000007','VOID', 0, '[]',
    '[]', 'Tekken 8', 'b0000000-0000-0000-0000-000000000001'))->>'error', 'booking_not_open',
  'a second device checking in the same booking is refused');

-- ------------------------------------------- 12. owner void releases pads
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is(pg_temp.push('session.void', jsonb_build_object('session_id','aaaaaaaa-0000-0000-0000-000000000001',
    'reason','test', 'at','2026-10-01T09:30:00Z'))->>'status', 'applied', 'owner voids HEX');
select is((select count(*)::int from controller_allocations a
            where a.controller_id in (pg_temp.c('HEX-1'),pg_temp.c('HEX-2'),pg_temp.c('VOID-1'),pg_temp.c('VOID-2'))
              and a.ended_at is null), 0, 'void released HEX-1/2 and VOID-1/2');
select is(pg_temp.push('rate.upsert', jsonb_build_object('activity_code','PS5','band','standard',
    'controller_count',1,'unit_minutes',60,'price_paise',16000))->>'status', 'applied',
  'owner changes a price');
-- 0016: an owner profile always holds every permission and stays active, so
-- the owner switching themselves off (the last Settings holder here) applies
-- as a no-op on access, flagged adjusted so the device refetches.
select is(pg_temp.push('staff.update', jsonb_build_object('user_id','11111111-1111-1111-1111-111111111111',
    'name','Owner','perms','["start"]'::jsonb,'active',false))->'result'->>'adjusted', 'true',
  'an owner cannot switch themselves off or drop their permissions (adjusted)');
select ok((select active and perms @> _known_perms() from staff_profiles
            where arena_id = 'e0000000-0000-4000-8000-000000000007'
              and user_id = '11111111-1111-1111-1111-111111111111'),
  'the owner is still active with every permission');

-- ------------------------------------------- 13. the feed
-- This file's arena and everything above were written in THIS (still open)
-- transaction, so the commit-safe window must hold all of it back: another
-- device may only ever see committed rows. (The end-to-end feed across
-- committed transactions is proven by the two-device suite, tool/sync_it.sh.)
select is(jsonb_array_length(
    sync_pull('e0000000-0000-4000-8000-000000000007'::uuid, '0', 100000)->'changes'), 0,
  'nothing written by a still-open transaction is in the feed (commit-safe window)');
select ok((select (r->>'has_more')::boolean = false
             from (select sync_pull('e0000000-0000-4000-8000-000000000007'::uuid, '0', 100000) r) q),
  'and the empty window is complete, not a cut page');
select is(pg_temp.push('rate.delete', jsonb_build_object('activity_code','LOUNGE','band','standard'))->>'status',
  'applied', 'owner deletes a rate');
select ok(exists(select 1 from sync_tombstones where table_name = 'rates'
    and row_key->>'controller_count' is null and row_key->>'price_paise' = '200000'),
  'the delete leaves a tombstone for the feed');
select is(jsonb_array_length(sync_fetch_entity('e0000000-0000-4000-8000-000000000007'::uuid,
    '[{"type":"session","id":"aaaaaaaa-0000-0000-0000-000000000099"}]')->0->'rows'), 0,
  'fetching a session the server never had returns no rows (device drops its copy)');

select pg_temp.as_user('99999999-9999-9999-9999-999999999999');
select throws_ok($$ select sync_push('e0000000-0000-4000-8000-000000000007'::uuid, '[]'::jsonb) $$, '42501', null,
  'a non-member cannot push');
select throws_ok($$ select sync_pull('e0000000-0000-4000-8000-000000000007'::uuid) $$, '42501', null,
  'a non-member cannot pull');

-- ---------------------------------------------------------------- a bad op never blocks the batch
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is((select array(select r->>'status' || ':' || coalesce(r->>'error', '')
                          from jsonb_array_elements(sync_push('e0000000-0000-4000-8000-000000000007'::uuid,
    jsonb_build_array(
      jsonb_build_object('op_id', 'not-a-uuid', 'kind', 'customer.create', 'payload', '{}'::jsonb),
      jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'no.such_op', 'payload', '{}'::jsonb)),
    'pgtap')->'results') r)::text),
  '{rejected:invalid_op_id,rejected:unknown_op}',
  'a malformed op id is refused on its own and the next op still runs');
select throws_ok($$ select sync_push('e0000000-0000-4000-8000-000000000007'::uuid,
    (select jsonb_agg(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'no.such_op'))
       from generate_series(1, 201)), 'pgtap') $$,
  '54000', 'batch_too_large', 'more than 200 ops in one push is refused');

select * from finish();
rollback;
