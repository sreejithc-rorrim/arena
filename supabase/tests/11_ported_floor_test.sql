-- Floor guarantees the pre-sync RPC suite (02 single sessions)
-- used to pin, re-asserted through the only client write path: sync_push →
-- op_*. What 07/08/10 already prove is not repeated here: not_playable,
-- payment replay/duplicate, partial→paid, overpayment, staff void refused,
-- stale writes, pricing.
--
-- Thu 2026-10-01; the 'Happy hours' rule (PS5, 20% lower) covers starts 14:00–17:00 IST = 08:30–11:30Z.
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated fixture: this file works in its OWN arena (the same starter catalog
-- seed.sql uses), so whatever else is in the database — the dev seed, arenas
-- left by the two-device suite, a half-finished run — cannot change what it
-- sees. Created inside this transaction and rolled back with it.
insert into arenas(id, name) values ('e0000000-0000-4000-8000-000000000111'::uuid, 'pgtap 11');
-- These fixtures replay fixed past dates: widen the offline window (offline_rules, default
-- 24 h) so device-stamped times from then are accepted.
insert into settings(arena_id, key, json)
  select id, 'offline_rules', '{"max_offline_hours": 100000}' from arenas where name like 'pgtap%'
  on conflict (arena_id, key) do nothing;
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000111'::uuid);
insert into pricing_rules(arena_id, name, days, start_min, end_min, holiday_mode, activity_codes,
    adjust_kind, adjust_value)
  values ('e0000000-0000-4000-8000-000000000111'::uuid, 'Happy hours', '{2,3,4,5}', 840, 1020,
    'skip', '{PS5}', 'percent', -20);
-- Two extra pads at VOID so a shared system can reach the 4-controller cap.
insert into controllers(arena_id, label, home_resource_id, current_resource_id, status)
  select r.arena_id, 'VOID-' || n, r.id, r.id, 'usable'
    from resources r, generate_series(3, 4) n
   where r.arena_id = 'e0000000-0000-4000-8000-000000000111'::uuid and r.name = 'VOID';

-- ---------------------------------------------------------------- fixture
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  values
  ('00000000-0000-0000-0000-000000000000','11000000-0000-0000-0000-000000000001','authenticated',
   'authenticated','owner11@test.local','',now(),now(),now(),'{}','{}',false,false),
  ('00000000-0000-0000-0000-000000000000','11000000-0000-0000-0000-000000000002','authenticated',
   'authenticated','staff11@test.local','',now(),now(),now(),'{}','{}',false,false)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000111'::uuid,'11000000-0000-0000-0000-000000000001','Owner','owner',
    array['start','bill','discount','members','stations','money','reports','settings'],true),
  ('e0000000-0000-4000-8000-000000000111'::uuid,'11000000-0000-0000-0000-000000000002','Staff','staff',
    array['start','bill','discount','members'],true);

create function pg_temp.r(n text) returns uuid as $$ select id from resources where name = n and arena_id = 'e0000000-0000-4000-8000-000000000111'::uuid $$ language sql;
create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.push(p_kind text, p jsonb, p_op uuid default gen_random_uuid()) returns jsonb as $$
  select sync_push('e0000000-0000-4000-8000-000000000111'::uuid,
    jsonb_build_array(jsonb_build_object('op_id', p_op, 'kind', p_kind, 'payload', p)), 'pgtap')
    -> 'results' -> 0 $$ language sql;
-- A count-only PS5 start (no tracked pads), frozen on the arena's own list.
create function pg_temp.start(p_id text, p_seg text, p_res text, p_at text, p_end text) returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'segment_id', p_seg::uuid,
    'customer_id', 'cccccccc-0000-0000-0000-000000000011',
    'started_at', p_at, 'scheduled_end_at', p_end,
    'pricing_snapshot', _pricing_snapshot('e0000000-0000-4000-8000-000000000111'::uuid),
    'resource_id', pg_temp.r(p_res), 'activity_code', 'PS5', 'game_id', null,
    'controller_count', 1, 'allocations', '[]'::jsonb, 'moves', '[]'::jsonb) $$ language sql;
create function pg_temp.pay(p_session text, p_amount bigint, p_refund boolean default false,
    p_reason text default null) returns jsonb as $$
  select jsonb_build_object('scope','single','parent_id', p_session::uuid,
    'payment_id', gen_random_uuid(), 'amount_paise', p_amount, 'method','cash',
    'is_refund', p_refund, 'reason', p_reason) $$ language sql;

select pg_temp.as_user('11000000-0000-0000-0000-000000000002');
select is(pg_temp.push('customer.create', jsonb_build_object(
    'id','cccccccc-0000-0000-0000-000000000011','name','Kiran','phone','9800001111',
    'is_guest', false))->>'status', 'applied', 'staff creates a customer');

-- ------------------------------------------- 1. start keeps the device's ids
select is(pg_temp.push('session.start', pg_temp.start(
    'a1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-000000000001','HEX',
    '2026-10-01T09:00:00Z','2026-10-01T10:00:00Z'), 'f1100000-0000-0000-0000-000000000001')
    ->>'status', 'applied', 'staff starts HEX');
select ok(exists(select 1 from session_segments where id = 'b1100000-0000-0000-0000-000000000001'
            and session_id = 'a1100000-0000-0000-0000-000000000001' and idx = 0),
  'the session and its segment 0 are stored under the device''s ids');
select is((select count(*)::int from session_segments
            where session_id = 'a1100000-0000-0000-0000-000000000001' and ended_at is null), 1,
  'exactly one open segment after start');
select is((select policy_snapshot from sessions where id = 'a1100000-0000-0000-0000-000000000001'),
  _pricing_snapshot('e0000000-0000-4000-8000-000000000111'::uuid)->'policy',
  'policy_snapshot is materialised from pricing_snapshot->policy');

-- ------------------------------------------- 2. a retried start is replayed
select is(pg_temp.push('session.start', pg_temp.start(
    'a1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-000000000001','HEX',
    '2026-10-01T09:00:00Z','2026-10-01T10:00:00Z'), 'f1100000-0000-0000-0000-000000000001')
    ->>'replayed', 'true', 'the same op pushed again is replayed, not re-applied');
select is((select count(*)::int from sessions where arena_id = 'e0000000-0000-4000-8000-000000000111'::uuid),
  1, 'no second session row');

-- ------------------------------------------- 3. one open segment per station
select is(pg_temp.push('session.start', pg_temp.start(
    'a1100000-0000-0000-0000-000000000002','b1100000-0000-0000-0000-000000000002','HEX',
    '2026-10-01T09:05:00Z','2026-10-01T10:00:00Z'))->>'error', 'resource_busy',
  'a second session on a busy station is refused');
select is((select count(*)::int from sessions where id = 'a1100000-0000-0000-0000-000000000002'), 0,
  'and nothing was written');

-- ------------------------------------------- 4. payment input rules
select is(pg_temp.push('payment.record', pg_temp.pay('a1100000-0000-0000-0000-000000000001', 10000))
    ->>'status', 'applied', 'an advance is taken while HEX runs');
select is(pg_temp.push('payment.record', pg_temp.pay('a1100000-0000-0000-0000-000000000001', 0))
    ->>'error', 'amount_zero', 'a zero payment is refused');
select is(pg_temp.push('payment.record', pg_temp.pay('a1100000-0000-0000-0000-000000000001', 5000, true))
    ->>'error', 'refund_reason_required', 'a refund without a reason is refused');
select is(pg_temp.push('payment.record', pg_temp.pay('a1100000-0000-0000-0000-000000000001', 5000, true,
    'overcharge'))->>'status', 'applied', 'a refund with a reason is accepted');
select is((select amount_paise::text || ' ' || kind from payments
            where session_id = 'a1100000-0000-0000-0000-000000000001' and reason = 'overcharge'),
  '-5000 refund', 'the refund is stored as a negative refund row');
select is((select count(*)::int from payments where session_id = 'a1100000-0000-0000-0000-000000000001'),
  2, 'the refused payments wrote nothing');

-- ------------------------------------------- 5. end writes its charges once
-- HEX, 1 pad, 09:00–10:00Z starts in happy hours: ₹150 − 20% = ₹120. ₹50 net paid → partial.
select is(pg_temp.push('session.end', jsonb_build_object('session_id','a1100000-0000-0000-0000-000000000001',
    'ended_at','2026-10-01T10:00:00Z', 'billed_amount_paise', 12000, 'mark_waived', false,
    'expected_segment_ids', jsonb_build_array('b1100000-0000-0000-0000-000000000001'),
    'expected_scheduled_end_at','2026-10-01T10:00:00Z',
    'charges', jsonb_build_array(jsonb_build_object('id','c1100000-0000-0000-0000-000000000001',
      'segment_id','b1100000-0000-0000-0000-000000000001','segment_index',0,'band_code','standard',
      'activity_code','PS5','resource_id', pg_temp.r('HEX'),'controller_count',1,
      'segment_start','2026-10-01T09:00:00Z','segment_end','2026-10-01T10:00:00Z',
      'played_minutes',60,'billed_minutes',60,'unit_minutes',60,'unit_price_paise',12000,
      'amount_paise',12000))))->'result'->>'payment_status', 'partial',
  'HEX ends: ₹50 net paid of ₹120 → partial');
select is(pg_temp.push('session.end', jsonb_build_object('session_id','a1100000-0000-0000-0000-000000000001',
    'ended_at','2026-10-01T10:00:00Z', 'billed_amount_paise', 12000,
    'expected_segment_ids', jsonb_build_array('b1100000-0000-0000-0000-000000000001'),
    'expected_scheduled_end_at','2026-10-01T10:00:00Z',
    'charges', jsonb_build_array(jsonb_build_object('id','c1100000-0000-0000-0000-000000000002',
      'segment_id','b1100000-0000-0000-0000-000000000001','segment_index',1,'band_code','standard',
      'activity_code','PS5','resource_id', pg_temp.r('HEX'),'controller_count',1,
      'segment_start','2026-10-01T09:00:00Z','segment_end','2026-10-01T10:00:00Z',
      'played_minutes',60,'billed_minutes',60,'unit_minutes',60,'unit_price_paise',12000,
      'amount_paise',12000))))->>'error', 'not_active', 'ending it again is refused');
select is((select count(*)::int from session_charges where session_id = 'a1100000-0000-0000-0000-000000000001'),
  1, 'exactly one charge row after two ends');
select is(pg_temp.push('session.start', pg_temp.start(
    'a1100000-0000-0000-0000-000000000003','b1100000-0000-0000-0000-000000000003','HEX',
    '2026-10-01T11:00:00Z','2026-10-01T12:00:00Z'))->>'status', 'applied',
  'HEX is free after the end: a new session starts there');

-- ------------------------------------------- 6. owner void
select pg_temp.as_user('11000000-0000-0000-0000-000000000001');
select is(pg_temp.push('session.void', jsonb_build_object('session_id','a1100000-0000-0000-0000-000000000003',
    'reason','test correction','at','2026-10-01T11:10:00Z'))->>'status', 'applied', 'owner voids the new HEX session');
select is((select status || ': ' || void_reason from sessions where id = 'a1100000-0000-0000-0000-000000000003'),
  'voided: test correction', 'it is voided, with the reason on record');
select ok((select ended_at = '2026-10-01T11:10:00Z' from session_segments
            where id = 'b1100000-0000-0000-0000-000000000003'),
  'the void closed the open segment at the void time');
select is(pg_temp.push('session.void', jsonb_build_object('session_id','a1100000-0000-0000-0000-000000000003',
    'reason','again'))->'result'->>'adjusted', 'true', 'voiding a voided session is a no-op (adjusted)');
select is((select count(*)::int from audit_log where entity_id = 'a1100000-0000-0000-0000-000000000003'), 1,
  'the void wrote exactly one audit row');
select is((select void_reason from sessions where id = 'a1100000-0000-0000-0000-000000000003'),
  'test correction', 'and the second void did not overwrite the reason');

select * from finish();
rollback;
