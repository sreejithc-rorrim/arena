-- Admin Sales: arena_sales (closed bills by close time) and arena_sale (one
-- bill in full). Bills are built through the only client write path
-- (sync_push → op_*), so the read side sees exactly what the floor app writes.
--
-- Thu 2026-10-01; the 'Happy hours' rule (PS5 started 14:00–17:00 IST = 08:30–11:30Z, 20% lower)
-- makes a 1-pad hour ₹120.
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated fixture: this file's own arena, rolled back with the transaction.
insert into arenas(id, name) values ('e0000000-0000-4000-8000-000000000140'::uuid, 'pgtap 14');
-- These fixtures replay fixed past dates: widen the offline window (offline_rules, default
-- 24 h) so device-stamped times from then are accepted.
insert into settings(arena_id, key, json)
  select id, 'offline_rules', '{"max_offline_hours": 100000}' from arenas where name like 'pgtap%'
  on conflict (arena_id, key) do nothing;
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000140'::uuid);
insert into pricing_rules(arena_id, name, days, start_min, end_min, holiday_mode, activity_codes,
    adjust_kind, adjust_value)
  values ('e0000000-0000-4000-8000-000000000140'::uuid, 'Happy hours', '{2,3,4,5}', 840, 1020,
    'skip', '{PS5}', 'percent', -20);

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  select '00000000-0000-0000-0000-000000000000', u.id::uuid, 'authenticated', 'authenticated',
         u.email, '', now(), now(), now(), '{}', '{}', false, false
    from (values
      ('14000000-0000-0000-0000-000000000001', 'owner14@test.local'),
      ('14000000-0000-0000-0000-000000000002', 'staff14@test.local'),
      ('14000000-0000-0000-0000-000000000003', 'cashier14@test.local')) u(id, email)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000140','14000000-0000-0000-0000-000000000001','Owner','owner',
    _known_perms(), true),
  ('e0000000-0000-4000-8000-000000000140','14000000-0000-0000-0000-000000000002','Staff','staff',
    array['start','bill','discount','members'], true),
  -- owner level through money
  ('e0000000-0000-4000-8000-000000000140','14000000-0000-0000-0000-000000000003','Cashier','staff',
    array['start','bill','money'], true);

create function pg_temp.r(n text) returns uuid as $$ select id from resources where name = n and arena_id = 'e0000000-0000-4000-8000-000000000140'::uuid $$ language sql;
create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.push(p_kind text, p jsonb) returns jsonb as $$
  select sync_push('e0000000-0000-4000-8000-000000000140'::uuid,
    jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', p_kind, 'payload', p)),
    'pgtap') -> 'results' -> 0 $$ language sql;
create function pg_temp.start(p_id text, p_seg text, p_res text, p_at text, p_end text) returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'segment_id', p_seg::uuid,
    'customer_id', 'cccccccc-0000-0000-0000-000000000014',
    'started_at', p_at, 'scheduled_end_at', p_end,
    'pricing_snapshot', _pricing_snapshot('e0000000-0000-4000-8000-000000000140'::uuid),
    'resource_id', pg_temp.r(p_res), 'activity_code', 'PS5', 'game_id', null,
    'controller_count', 1, 'allocations', '[]'::jsonb, 'moves', '[]'::jsonb) $$ language sql;
-- End a 1-pad PS5 session with one charge line of p_amount.
create function pg_temp.end_(p_id text, p_seg text, p_res text, p_from text, p_to text, p_amount int)
  returns jsonb as $$
  select pg_temp.push('session.end', jsonb_build_object('session_id', p_id,
    'ended_at', p_to, 'billed_amount_paise', p_amount, 'mark_waived', false,
    'expected_segment_ids', jsonb_build_array(p_seg), 'expected_scheduled_end_at', p_to,
    'charges', jsonb_build_array(jsonb_build_object('id', gen_random_uuid(),
      'segment_id', p_seg, 'segment_index', 0, 'band_code', 'standard',
      'activity_code', 'PS5', 'resource_id', pg_temp.r(p_res), 'controller_count', 1,
      'segment_start', p_from, 'segment_end', p_to,
      'played_minutes', 60, 'billed_minutes', 60, 'unit_minutes', 60,
      'unit_price_paise', p_amount, 'amount_paise', p_amount)))) $$ language sql;
create function pg_temp.pay(p_scope text, p_parent text, p_amount int, p_method text) returns jsonb as $$
  select pg_temp.push('payment.record', jsonb_build_object('scope', p_scope, 'parent_id', p_parent,
    'payment_id', gen_random_uuid(), 'amount_paise', p_amount, 'method', p_method)) $$ language sql;
create function pg_temp.sales(p_from text, p_to text) returns jsonb as $$
  select arena_sales('e0000000-0000-4000-8000-000000000140'::uuid, p_from::timestamptz, p_to::timestamptz)
  $$ language sql;
create function pg_temp.sale(p_id text) returns jsonb as $$
  select arena_sale('e0000000-0000-4000-8000-000000000140'::uuid, p_id::uuid) $$ language sql;
create function pg_temp.bill(p_list jsonb, p_id text) returns jsonb as $$
  select e from jsonb_array_elements(p_list) e where e->>'id' = p_id $$ language sql;

-- ---------------------------------------------------------------- the day's bills
-- A: HEX 09:00–10:00Z, ₹120, paid ₹100 UPI + ₹20 cash.
-- B: GHOST 10:00–11:00Z, ₹120 paid cash, then voided by the owner.
-- C: still running on HEX (not a bill yet).
-- D: started on GHOST at 12:00Z and voided while it ran (never ended).
select pg_temp.as_user('14000000-0000-0000-0000-000000000002');
select is(pg_temp.push('customer.create', jsonb_build_object(
    'id','cccccccc-0000-0000-0000-000000000014','name','Kiran','phone','9800001414',
    'is_guest', false))->>'status', 'applied', 'staff creates a customer');

select is(pg_temp.push('session.start', pg_temp.start('a1400000-0000-0000-0000-00000000000a',
    'b1400000-0000-0000-0000-00000000000a', 'HEX', '2026-10-01T09:00:00Z', '2026-10-01T10:00:00Z'))
    ->>'status', 'applied', 'A starts on HEX');
select is(pg_temp.end_('a1400000-0000-0000-0000-00000000000a', 'b1400000-0000-0000-0000-00000000000a',
    'HEX', '2026-10-01T09:00:00Z', '2026-10-01T10:00:00Z', 12000)->>'status', 'applied', 'A ends at ₹120');
select is(pg_temp.pay('single', 'a1400000-0000-0000-0000-00000000000a', 10000, 'upi')->>'status', 'applied',
  'A: ₹100 by UPI');
select is(pg_temp.pay('single', 'a1400000-0000-0000-0000-00000000000a', 2000, 'cash')->'result'->>'payment_status',
  'paid', 'A: ₹20 cash → paid');

select is(pg_temp.push('session.start', pg_temp.start('a1400000-0000-0000-0000-00000000000b',
    'b1400000-0000-0000-0000-00000000000b', 'GHOST', '2026-10-01T10:00:00Z', '2026-10-01T11:00:00Z'))
    ->>'status', 'applied', 'B starts on GHOST');
select is(pg_temp.end_('a1400000-0000-0000-0000-00000000000b', 'b1400000-0000-0000-0000-00000000000b',
    'GHOST', '2026-10-01T10:00:00Z', '2026-10-01T11:00:00Z', 12000)->>'status', 'applied', 'B ends at ₹120');
select is(pg_temp.pay('single', 'a1400000-0000-0000-0000-00000000000b', 12000, 'cash')->>'status', 'applied',
  'B: ₹120 cash');

select is(pg_temp.push('session.start', pg_temp.start('a1400000-0000-0000-0000-00000000000c',
    'b1400000-0000-0000-0000-00000000000c', 'HEX', '2026-10-01T10:15:00Z', '2026-10-01T12:00:00Z'))
    ->>'status', 'applied', 'C starts on HEX and keeps running');
select is(pg_temp.push('session.start', pg_temp.start('a1400000-0000-0000-0000-00000000000d',
    'b1400000-0000-0000-0000-00000000000d', 'GHOST', '2026-10-01T12:00:00Z', '2026-10-01T13:00:00Z'))
    ->>'status', 'applied', 'D starts on GHOST');

select pg_temp.as_user('14000000-0000-0000-0000-000000000001');
select is(pg_temp.push('session.void', jsonb_build_object('session_id','a1400000-0000-0000-0000-00000000000b',
    'reason','Duplicate bill'))->>'status', 'applied', 'the owner voids B after it was paid');
select is(pg_temp.push('session.void', jsonb_build_object('session_id','a1400000-0000-0000-0000-00000000000d',
    'reason','Wrong station'))->>'status', 'applied', 'and voids D while it runs');

-- ---------------------------------------------------------------- who may read
select pg_temp.as_user('14000000-0000-0000-0000-000000000002');
select throws_ok($$ select pg_temp.sales('2026-10-01T00:00:00Z', '2026-10-02T00:00:00Z') $$,
  '42501', 'forbidden', 'staff without money/reports cannot list sales');
select throws_ok($$ select pg_temp.sale('a1400000-0000-0000-0000-00000000000a') $$,
  '42501', 'forbidden', 'nor read a bill');
select pg_temp.as_user('14000000-0000-0000-0000-000000000003');
select is(jsonb_array_length(pg_temp.sales('2026-10-01T00:00:00Z', '2026-10-02T00:00:00Z')), 2,
  'owner level through money can list sales');
select ok(not has_function_privilege('anon', 'arena_sales(uuid,timestamptz,timestamptz)', 'EXECUTE')
       and not has_function_privilege('anon', 'arena_sale(uuid,uuid)', 'EXECUTE'),
  'neither is callable signed out');

-- ---------------------------------------------------------------- range rules
select pg_temp.as_user('14000000-0000-0000-0000-000000000001');
select throws_ok($$ select pg_temp.sales('2026-10-02T00:00:00Z', '2026-10-01T00:00:00Z') $$,
  'invalid_range', 'to before from is refused');
select throws_ok($$ select pg_temp.sales('2026-06-01T00:00:00Z', '2026-10-01T00:00:00Z') $$,
  'invalid_range', 'more than 93 days is refused');
select is(jsonb_array_length(pg_temp.sales('2026-09-30T00:00:00Z', '2026-10-01T00:00:00Z')), 0,
  'nothing closed the day before');
select is((select string_agg(e->>'id', ',') from jsonb_array_elements(
            pg_temp.sales('2026-10-01T00:00:00Z', '2026-10-02T00:00:00Z')) e),
  'a1400000-0000-0000-0000-00000000000b,a1400000-0000-0000-0000-00000000000a',
  'the day lists B, A: closed bills only, newest close first');
select is(jsonb_array_length(pg_temp.sales('2026-10-01T09:00:00Z', '2026-10-01T10:00:00Z')), 0,
  'the range is half-open: A closing at 10:00 is not in [09:00, 10:00)');
select is(jsonb_array_length(pg_temp.sales('2026-10-01T10:00:00Z', '2026-10-01T10:00:01Z')), 1,
  'but A is in [10:00, 10:00:01)');

-- ---------------------------------------------------------------- the summaries
create temp table day as select pg_temp.sales('2026-10-01T00:00:00Z', '2026-10-02T00:00:00Z') as l;
select is((select pg_temp.bill(l, 'a1400000-0000-0000-0000-00000000000a')
            - array['at','started_at','ended_at','recorded_at','end_recorded_at','payments'] from day),
  jsonb_build_object('kind','single','id','a1400000-0000-0000-0000-00000000000a',
    'status','completed','payment_status','paid','customer','Kiran','guest',false,
    'returning', false,
    'stations', jsonb_build_array('HEX'), 'activities', jsonb_build_array('PlayStation 5'),
    'games', '[]'::jsonb, 'players', 1, 'player_minutes', 60,
    'billed_paise', 12000, 'paid_paise', 12000, 'refunded_paise', 0,
    'methods', jsonb_build_object('upi', 10000, 'cash', 2000),
    'started_by', 'Staff', 'void_reason', null, 'voided_at', null, 'voided_by', null,
    'discount_paise', 0, 'discount', null),
  'A: billed ₹120, paid by method, station, activity, started by Staff');
select is((select (pg_temp.bill(l, 'a1400000-0000-0000-0000-00000000000a')->>'at')::timestamptz from day),
  '2026-10-01T10:00:00Z'::timestamptz, 'A closed at its end');
select is((select pg_temp.bill(l, 'a1400000-0000-0000-0000-00000000000b')->>'status' || ' / '
              || (pg_temp.bill(l, 'a1400000-0000-0000-0000-00000000000b')->>'void_reason') || ' / '
              || (pg_temp.bill(l, 'a1400000-0000-0000-0000-00000000000b')->>'paid_paise') from day),
  'voided / Duplicate bill / 12000', 'B is listed voided with its reason; the cash taken stays on it');

-- ---------------------------------------------------------------- one bill in full
select is(jsonb_array_length(pg_temp.sale('a1400000-0000-0000-0000-00000000000a')->'lines'), 1,
  'A has its one charge line');
select is(pg_temp.sale('a1400000-0000-0000-0000-00000000000a')->'lines'->0->>'station', 'HEX',
  'the line names its station');
select is((select string_agg(e->>'method' || ':' || (e->>'amount_paise') || ':' || (e->>'by'), ',')
             from jsonb_array_elements(pg_temp.sale('a1400000-0000-0000-0000-00000000000a')->'payments') e),
  'upi:10000:Staff,cash:2000:Staff', 'A''s payments in order, with who took them');
select is(pg_temp.sale('a1400000-0000-0000-0000-00000000000a')->'voided', 'null'::jsonb,
  'A is not voided');
select is((pg_temp.sale('a1400000-0000-0000-0000-00000000000b')->'voided') - 'at'::text,
  jsonb_build_object('by','Owner','reason','Duplicate bill'), 'B: who voided it and why');
select is(pg_temp.sale('a1400000-0000-0000-0000-00000000000d')->>'ended_at', null,
  'D, voided while it ran, is a bill that never ended');
select throws_ok($$ select pg_temp.sale('a1400000-0000-0000-0000-00000000000c') $$,
  'not_found', 'a running session is not a bill yet');
select throws_ok($$ select pg_temp.sale(gen_random_uuid()::text) $$,
  'not_found', 'an unknown id is not found');

select * from finish();
rollback;
