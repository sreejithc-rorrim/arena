-- Server-side pricing (0013): the server re-prices every bill and refuses money
-- that is not its own, and refuses a session frozen on a price list the arena
-- never had.
--
-- Seed price list (Thu 2026-10-01): PS5 1/2 pads ₹150/₹280 per hour, plus a
--   'Happy hours' pricing rule: PS5 started Tue–Fri 14:00–17:00 IST (08:30–11:30Z)
--   is 20% lower (₹120/₹224) for the whole session. Per-minute billing, session
--   rounding scope, cash rounded to the nearest ₹1.
-- The parity of every rule with lib/domain/pricing is proven separately by a
-- Dart-vs-SQL differential run (docs/SYNC.md); these cases pin the op wiring.
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated fixture: this file works in its OWN arena (the same starter catalog
-- seed.sql uses), so whatever else is in the database — the dev seed, arenas
-- left by the two-device suite, a half-finished run — cannot change what it
-- sees. Created inside this transaction and rolled back with it.
insert into arenas(id, name) values ('e0000000-0000-4000-8000-000000000008'::uuid, 'pgtap 08');
-- These fixtures replay fixed past dates: widen the offline window (offline_rules, default
-- 24 h) so device-stamped times from then are accepted.
insert into settings(arena_id, key, json)
  select id, 'offline_rules', '{"max_offline_hours": 100000}' from arenas where name like 'pgtap%'
  on conflict (arena_id, key) do nothing;
-- Staff here waive whole bills: let them (the cap itself is tested in 08).
insert into settings(arena_id, key, json)
  select id, 'discount_options', '{"manual_max_percent": 100, "reason_required": false}' from arenas
   where name like 'pgtap%'
  on conflict (arena_id, key) do nothing;
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000008'::uuid);
insert into pricing_rules(arena_id, name, days, start_min, end_min, holiday_mode, activity_codes,
    adjust_kind, adjust_value)
  values ('e0000000-0000-4000-8000-000000000008'::uuid, 'Happy hours', '{2,3,4,5}', 840, 1020,
    'skip', '{PS5}', 'percent', -20);

-- ---------------------------------------------------------------- fixture
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  values
  ('00000000-0000-0000-0000-000000000000','11111111-1111-1111-1111-111111111111','authenticated',
   'authenticated','owner@test.local','',now(),now(),now(),'{}','{}',false,false),
  ('00000000-0000-0000-0000-000000000000','22222222-2222-2222-2222-222222222222','authenticated',
   'authenticated','staff@test.local','',now(),now(),now(),'{}','{}',false,false)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000008'::uuid,'11111111-1111-1111-1111-111111111111','Owner','owner',
    array['start','bill','discount','members','stations','money','reports','settings'],true),
  ('e0000000-0000-4000-8000-000000000008'::uuid,'22222222-2222-2222-2222-222222222222','Staff','staff',
    array['start','bill','discount','members'],true);

create function pg_temp.arena() returns uuid as $$ select 'e0000000-0000-4000-8000-000000000008'::uuid $$ language sql;
create function pg_temp.r(n text) returns uuid as $$ select id from resources where name = n and arena_id = 'e0000000-0000-4000-8000-000000000008'::uuid $$ language sql;
create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.push(p_kind text, p jsonb) returns jsonb as $$
  select sync_push(pg_temp.arena(),
    jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', p_kind, 'payload', p)), 'pgtap')
    -> 'results' -> 0 $$ language sql;
-- The price list as an in-sync device would freeze it.
create function pg_temp.snap() returns jsonb as $$ select _pricing_snapshot(pg_temp.arena()) $$ language sql;
create function pg_temp.start(p_id text, p_seg text, p_res text, p_cc int, p_at text, p_end text,
    p_snap jsonb default null) returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'segment_id', p_seg::uuid,
    'customer_id', 'cccccccc-0000-0000-0000-000000000008',
    'started_at', p_at, 'scheduled_end_at', p_end,
    'pricing_snapshot', coalesce(p_snap, pg_temp.snap()),
    'resource_id', pg_temp.r(p_res), 'activity_code', 'PS5',
    'controller_count', p_cc, 'allocations', '[]'::jsonb, 'moves', '[]'::jsonb) $$ language sql;
-- One charge row as the device sends it (segment_index is unique per session).
create temp sequence ch_index;
create function pg_temp.ch(p_seg text, p_band text, p_res text, p_cc int, p_s text, p_e text,
    p_played int, p_billed int, p_price int, p_amount int) returns jsonb as $$
  select jsonb_build_object('id', gen_random_uuid(), 'segment_id', p_seg::uuid,
    'segment_index', nextval('ch_index'),
    'band_code', p_band, 'activity_code', 'PS5', 'resource_id', pg_temp.r(p_res),
    'controller_count', p_cc, 'segment_start', p_s, 'segment_end', p_e,
    'played_minutes', p_played, 'billed_minutes', p_billed, 'unit_minutes', 60,
    'unit_price_paise', p_price, 'amount_paise', p_amount) $$ language sql;
create function pg_temp.end_op(p_id text, p_segs jsonb, p_sched text, p_at text, p_billed bigint,
    p_charges jsonb, p_waive boolean default false) returns jsonb as $$
  select jsonb_build_object('session_id', p_id::uuid, 'ended_at', p_at,
    'billed_amount_paise', p_billed, 'mark_waived', p_waive,
    'waive_reason', case when p_waive then 'Walked out' end, 'expected_segment_ids', p_segs,
    'expected_scheduled_end_at', p_sched, 'charges', p_charges) $$ language sql;

select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select is(pg_temp.push('customer.create', jsonb_build_object(
    'id','cccccccc-0000-0000-0000-000000000008','name','Asha','phone','9800000008',
    'is_guest', false))->>'status', 'applied', 'fixture customer');

-- ------------------------------------------- 1. the price list a session freezes
select is(pg_temp.push('session.start', pg_temp.start(
    'a8000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-000000000001','HEX', 1,
    '2026-10-01T11:00:00Z','2026-10-01T12:00:00Z',
    jsonb_set(pg_temp.snap(), '{rates}', (select jsonb_agg(r || '{"price_paise":0}')
      from jsonb_array_elements(pg_temp.snap()->'rates') r))))->>'error',
  'pricing_snapshot_mismatch', 'a forged ₹0 price list is refused at start');
select is(pg_temp.push('session.start', pg_temp.start(
    'a8000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-000000000001','HEX', 1,
    '2026-10-01T11:00:00Z','2026-10-01T12:00:00Z', '{}'::jsonb))->>'error',
  'pricing_snapshot_mismatch', 'an empty price list is refused at start');
select is((select count(*)::int from sessions where id = 'a8000000-0000-0000-0000-000000000001'), 0,
  'nothing written by the refused starts');
select is(pg_temp.push('session.start', pg_temp.start(
    'a8000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-000000000001','HEX', 1,
    '2026-10-01T11:00:00Z','2026-10-01T12:00:00Z',
    pg_temp.snap() || jsonb_build_object('rate_card_name', 'Weekday card',
      'rates', (select jsonb_agg(r order by n desc)
                  from jsonb_array_elements(pg_temp.snap()->'rates') with ordinality x(r, n)))))
    ->>'status', 'applied', 'the arena''s own list starts (card name and order do not matter)');

-- ------------------------------------------- 2. happy hours rule: wrong bills refused
-- HEX, 1 pad, 16:30–17:30 IST: started inside happy hours, so the whole hour is 20% lower
-- (₹120), also the half hour after the window closes.
select is(pg_temp.push('session.end', pg_temp.end_op('a8000000-0000-0000-0000-000000000001',
    '["b8000000-0000-0000-0000-000000000001"]', '2026-10-01T12:00:00Z', '2026-10-01T12:00:00Z', 13500,
    jsonb_build_array(
      pg_temp.ch('b8000000-0000-0000-0000-000000000001','standard','HEX',1,
        '2026-10-01T11:00:00Z','2026-10-01T11:30:00Z',30,30,12000,6000),
      pg_temp.ch('b8000000-0000-0000-0000-000000000001','standard','HEX',1,
        '2026-10-01T11:30:00Z','2026-10-01T12:00:00Z',30,30,15000,7500))))->>'error',
  'price_mismatch', 'a bill split at the window end (₹135) is refused: the start decides');
select matches(pg_temp.push('session.end', pg_temp.end_op('a8000000-0000-0000-0000-000000000001',
    '["b8000000-0000-0000-0000-000000000001"]', '2026-10-01T12:00:00Z', '2026-10-01T12:00:00Z', 0,
    '[]'::jsonb))->>'detail', 'server 12000 paise, device 0 paise',
  'the refusal names the server''s bill and the device''s');
select is(pg_temp.push('session.end', pg_temp.end_op('a8000000-0000-0000-0000-000000000001',
    '["b8000000-0000-0000-0000-000000000001"]', '2026-10-01T12:00:00Z', '2026-10-01T12:00:00Z', 12000,
    jsonb_build_array(pg_temp.ch('b8000000-0000-0000-0000-000000000001','standard','HEX',1,
      '2026-10-01T11:00:00Z','2026-10-01T12:00:00Z',60,60,15000,12000))))->>'error',
  'price_mismatch', 'the right total over invented charge rows is refused');
select is(pg_temp.push('session.end', pg_temp.end_op('a8000000-0000-0000-0000-000000000001',
    '["b8000000-0000-0000-0000-000000000001"]', '2026-10-01T12:00:00Z', '2026-10-01T12:00:00Z', 15000,
    '[]'::jsonb))->>'error', 'price_mismatch', 'the rule-free price (over-billing) is refused too (0 paise tolerance)');
select is((select status from sessions where id = 'a8000000-0000-0000-0000-000000000001'), 'active',
  'after the refusals the session is still running');
select is((select count(*)::int from session_charges where session_id = 'a8000000-0000-0000-0000-000000000001'), 0,
  'and has no charge rows');
select ok((select ended_at is null from session_segments where id = 'b8000000-0000-0000-0000-000000000001'),
  'and its segment is still open (the refused op rolled back whole)');
select is(pg_temp.push('session.end', pg_temp.end_op('a8000000-0000-0000-0000-000000000001',
    '["b8000000-0000-0000-0000-000000000001"]', '2026-10-01T12:00:00Z', '2026-10-01T10:59:00Z', 0,
    '[]'::jsonb))->>'error', 'invalid', 'an end before the session started is refused');
select is(pg_temp.push('session.end', pg_temp.end_op('a8000000-0000-0000-0000-000000000001',
    '["b8000000-0000-0000-0000-000000000001"]', '2026-10-01T12:00:00Z', '2026-10-01T12:00:00Z', 12000,
    jsonb_build_array(pg_temp.ch('b8000000-0000-0000-0000-000000000001','standard','HEX',1,
      '2026-10-01T11:00:00Z','2026-10-01T12:00:00Z',60,60,12000,12000))))->>'status',
  'applied', 'the whole hour at the happy hours price is accepted');
select is((select billed_amount_paise from sessions where id = 'a8000000-0000-0000-0000-000000000001'),
  12000::bigint, 'billed ₹120');

-- ------------------------------------------- 3. extension + switch + cash rounding
-- RIFT, Fri 18:30 IST (standard). 2 pads 13:00–13:30Z, then 1 pad to 14:15Z.
select is(pg_temp.push('session.start', pg_temp.start(
    'a8000000-0000-0000-0000-000000000002','b8000000-0000-0000-0000-000000000002','RIFT', 2,
    '2026-10-02T13:00:00Z','2026-10-02T14:00:00Z'))->>'status', 'applied', 'RIFT starts with 2 pads');
select is(pg_temp.push('session.extend', jsonb_build_object('session_id','a8000000-0000-0000-0000-000000000002',
    'extension_id', gen_random_uuid(), 'added_minutes', 30, 'old_end_at','2026-10-02T14:00:00Z',
    'new_end_at','2026-10-02T14:30:00Z', 'added_amount_paise', 0))->>'error', 'price_mismatch',
  'an extension quoted at ₹0 is refused');
select is(pg_temp.push('session.extend', jsonb_build_object('session_id','a8000000-0000-0000-0000-000000000002',
    'extension_id', gen_random_uuid(), 'added_minutes', 30, 'old_end_at','2026-10-02T14:00:00Z',
    'new_end_at','2026-10-02T13:30:00Z', 'added_amount_paise', 0))->>'error', 'invalid',
  'an extension that moves the end backwards is refused');
select is(pg_temp.push('session.extend', jsonb_build_object('session_id','a8000000-0000-0000-0000-000000000002',
    'extension_id', gen_random_uuid(), 'added_minutes', 30, 'old_end_at','2026-10-02T14:00:00Z',
    'new_end_at','2026-10-02T14:30:00Z', 'added_amount_paise', 14000))->>'status', 'applied',
  'the planner''s +30 min at the 2-pad rate (₹140) is accepted');
select is(pg_temp.push('session.reconfigure', jsonb_build_object('session_id','a8000000-0000-0000-0000-000000000002',
    'at','2026-10-02T13:30:00Z','expected_segment_id','b8000000-0000-0000-0000-000000000002',
    'new_segment_id','b8000000-0000-0000-0000-000000000003','resource_id', pg_temp.r('RIFT'),
    'activity_code','PS5','controller_count',1,'allocations','[]'::jsonb,'moves','[]'::jsonb))
    ->>'status', 'applied', 'down to 1 pad at 13:30Z');
-- ₹140.00 + ₹112.50 = ₹252.50 → cash-rounded once to ₹253 (not per segment).
select is(pg_temp.push('session.end', pg_temp.end_op('a8000000-0000-0000-0000-000000000002',
    '["b8000000-0000-0000-0000-000000000002","b8000000-0000-0000-0000-000000000003"]',
    '2026-10-02T14:30:00Z', '2026-10-02T14:15:00Z', 25200,
    jsonb_build_array(
      pg_temp.ch('b8000000-0000-0000-0000-000000000002','standard','RIFT',2,
        '2026-10-02T13:00:00Z','2026-10-02T13:30:00Z',30,30,28000,14000),
      pg_temp.ch('b8000000-0000-0000-0000-000000000003','standard','RIFT',1,
        '2026-10-02T13:30:00Z','2026-10-02T14:15:00Z',45,45,15000,11250))))->>'error',
  'price_mismatch', 'rounding the total down a rupee is refused');
select is(pg_temp.push('session.end', pg_temp.end_op('a8000000-0000-0000-0000-000000000002',
    '["b8000000-0000-0000-0000-000000000002","b8000000-0000-0000-0000-000000000003"]',
    '2026-10-02T14:30:00Z', '2026-10-02T14:15:00Z', 25300,
    jsonb_build_array(
      pg_temp.ch('b8000000-0000-0000-0000-000000000003','standard','RIFT',1,
        '2026-10-02T13:30:00Z','2026-10-02T14:15:00Z',45,45,15000,11250),
      pg_temp.ch('b8000000-0000-0000-0000-000000000002','standard','RIFT',2,
        '2026-10-02T13:00:00Z','2026-10-02T13:30:00Z',30,30,28000,14000))))->>'status',
  'applied', 'two segments, rounded once to ₹253, accepted (row order is the device''s)');

-- ------------------------------------------- 4. waived
-- VOID, Sat (no happy hours) 10:00–11:00Z, 1 pad = ₹150.
select is(pg_temp.push('session.start', pg_temp.start(
    'a8000000-0000-0000-0000-000000000004','b8000000-0000-0000-0000-000000000004','VOID', 1,
    '2026-10-03T10:00:00Z','2026-10-03T11:00:00Z'))->>'status', 'applied', 'VOID starts');
select is(pg_temp.push('session.end', pg_temp.end_op('a8000000-0000-0000-0000-000000000004',
    '["b8000000-0000-0000-0000-000000000004"]', '2026-10-03T11:00:00Z', '2026-10-03T11:00:00Z', 0,
    '[]'::jsonb, true))->>'error', 'price_mismatch',
  'waiving does not skip pricing: a ₹0 bill marked waived is refused');
select is(pg_temp.push('session.end', pg_temp.end_op('a8000000-0000-0000-0000-000000000004',
    '["b8000000-0000-0000-0000-000000000004"]', '2026-10-03T11:00:00Z', '2026-10-03T11:00:00Z', 15000,
    jsonb_build_array(pg_temp.ch('b8000000-0000-0000-0000-000000000004','standard','VOID',1,
      '2026-10-03T10:00:00Z','2026-10-03T11:00:00Z',60,60,15000,15000)), true))->>'status',
  'applied', 'the real bill, waived, is accepted');
select is((select payment_status || ' ' || billed_amount_paise from sessions
            where id = 'a8000000-0000-0000-0000-000000000004'), 'waived 15000',
  'waived, with the true amount on record');

-- ------------------------------------------- 6. a device offline across a price change
create temp table old_list as select pg_temp.snap() as s;
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select is(pg_temp.push('rate.upsert', jsonb_build_object('activity_code','PS5','band','standard',
    'controller_count',1,'unit_minutes',60,'price_paise',16000))->>'status', 'applied',
  'owner raises the 1-pad price');
select is((select count(*)::int from pricing_catalog_history where arena_id = pg_temp.arena()), 1,
  'the replaced list is kept');
select is(pg_temp.push('settings.save', jsonb_build_object('key','business_hours',
    'json', pg_temp.snap()->'hours'))->>'status', 'applied', 'saving unchanged hours');
select is((select count(*)::int from pricing_catalog_history where arena_id = pg_temp.arena()), 1,
  'a save that changes nothing records no version');
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select is(pg_temp.push('session.start', pg_temp.start(
    'a8000000-0000-0000-0000-000000000006','b8000000-0000-0000-0000-000000000006','HEX', 1,
    '2026-10-03T12:00:00Z','2026-10-03T13:00:00Z', (select s from old_list)))->>'status', 'applied',
  'a start frozen on the list replaced minutes ago is accepted (offline device)');
update pricing_catalog_history set retired_at = statement_timestamp() - interval '73 hours';
select is(pg_temp.push('session.start', pg_temp.start(
    'a8000000-0000-0000-0000-000000000007','b8000000-0000-0000-0000-000000000007','RIFT', 1,
    '2026-10-03T12:00:00Z','2026-10-03T13:00:00Z', (select s from old_list)))->>'error',
  'pricing_snapshot_mismatch', 'a list replaced more than 72 h ago is refused');
select is(pg_temp.push('session.start', pg_temp.start(
    'a8000000-0000-0000-0000-000000000007','b8000000-0000-0000-0000-000000000007','RIFT', 1,
    '2026-10-03T12:00:00Z','2026-10-03T13:00:00Z'))->>'status', 'applied', 'the live list starts');
-- The old-list session is billed from ITS snapshot (₹150), not today's ₹160.
select is(pg_temp.push('session.end', pg_temp.end_op('a8000000-0000-0000-0000-000000000006',
    '["b8000000-0000-0000-0000-000000000006"]', '2026-10-03T13:00:00Z', '2026-10-03T13:00:00Z', 15000,
    jsonb_build_array(pg_temp.ch('b8000000-0000-0000-0000-000000000006','standard','HEX',1,
      '2026-10-03T12:00:00Z','2026-10-03T13:00:00Z',60,60,15000,15000))))->>'status',
  'applied', 'a session is priced from the list it was started on');

-- ------------------------------------------- 7. no client surface
select ok(not has_function_privilege('authenticated', f, 'execute'), f || ' is not client-callable')
  from unnest(array['_pr_quote(jsonb,text,int,timestamptz,timestamptz,timestamptz)',
    '_pr_rule(jsonb,text,timestamptz)','_pr_rule_price(bigint,int,jsonb)',
    '_pr_session_bill(uuid,timestamptz,boolean)',
    '_pricing_snapshot(uuid)','_assert_snapshot(uuid,jsonb)','op_session_end(uuid,jsonb)',
    'op_session_start(uuid,jsonb)','op_session_extend(uuid,jsonb)',
    '_sync_apply(uuid,text,jsonb)']) f;
select ok(not has_table_privilege('authenticated', 'pricing_catalog_history', 'select'),
  'price-list history is server-only');

-- ---------------------------------------------------------------- device times are bounded
select pg_temp.as_user('22222222-2222-2222-2222-222222222222');
select is(pg_temp.push('session.start', pg_temp.start('a0800000-0000-0000-0000-0000000000f1',
    'b0800000-0000-0000-0000-0000000000f1', 'RIFT', 1, (now() + interval '1 hour')::text,
    (now() + interval '2 hours')::text))->>'error', 'time_in_future',
  'a start dated an hour ahead of the server is refused');
update settings set json = '{"max_offline_hours": 24}'
 where arena_id = pg_temp.arena() and key = 'offline_rules';
select is(pg_temp.push('session.start', pg_temp.start('a0800000-0000-0000-0000-0000000000f2',
    'b0800000-0000-0000-0000-0000000000f2', 'RIFT', 1, (now() - interval '25 hours')::text,
    (now() - interval '24 hours')::text))->>'error', 'time_too_old',
  'a start older than the offline window is refused');
select is(pg_temp.push('session.start', pg_temp.start('a0800000-0000-0000-0000-0000000000f3',
    'b0800000-0000-0000-0000-0000000000f3', 'VOID', null, (now() - interval '10 minutes')::text,
    (now() + interval '50 minutes')::text))->>'error', 'no_rate',
  'a PS5 start with no controller count has no rate and is refused (no ₹0 segments)');
select is(pg_temp.push('session.start', pg_temp.start('a0800000-0000-0000-0000-0000000000f4',
    'b0800000-0000-0000-0000-0000000000f4', 'VOID', 1, (now() - interval '10 minutes')::text,
    (now() + interval '50 minutes')::text))->>'status', 'applied',
  'a start inside the window, with a rate, is accepted');
select ok((select ended_recorded_at is null from sessions where id = 'a0800000-0000-0000-0000-0000000000f4'),
  'no end receipt time while it runs');

-- ---------------------------------------------------------------- waives above the manual cap: owner level only
update settings set json = '{"manual_max_percent": 10, "reason_required": false}'
 where arena_id = pg_temp.arena() and key = 'discount_options';
select throws_ok($$ select _waive_check(pg_temp.arena(), 10000, 0) $$, 'P0001', 'waive_over_limit',
  'staff cannot write off a whole bill above the 10% cap');
select lives_ok($$ select _waive_check(pg_temp.arena(), 10000, 9000) $$,
  'staff may write off up to the cap (₹10 of ₹100)');
select throws_ok($$ select _waive_check(pg_temp.arena(), 10000, 8999) $$, 'P0001', 'waive_over_limit',
  'one paisa over the cap is refused (exact, no rounding)');
select pg_temp.as_user('11111111-1111-1111-1111-111111111111');
select lives_ok($$ select _waive_check(pg_temp.arena(), 10000, 0) $$, 'the owner waives any amount');

select * from finish();
rollback;
