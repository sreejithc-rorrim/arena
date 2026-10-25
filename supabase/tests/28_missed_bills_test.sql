-- Missed bills (session.record) are billed at what the customer actually paid:
--   * an app that predates paid_amount_paise (absent or null) is billed and paid the price,
--     as before;
--   * paid less, more or nothing: the bill and its one payment are the amount paid, status
--     paid, while the charge lines keep today's price and the audit entry keeps the price,
--     the amount paid and the difference (arena_sale's history carries it to the dashboard);
--   * an amount paid that is not a whole number of paise from 0 to 1000000000 is refused
--     (invalid_total), as is a missing or blank reason (reason_required), and nothing is written;
--   * the server's price check still holds (price_mismatch);
--   * the bill lists (my_bills for the floor app, arena_sales for the dashboard) carry a missed
--     bill's price as quoted_paise, null for a bill played on the floor;
--   * a bill belongs to the IST business day it closed on, in both lists alike.
-- Bills are added through the only client write path (sync_push → op_session_record).
--
-- Thu 2026-10-01, no time rules: a PS5 hour at 1 pad is ₹150 (seed rate).
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated fixture: this file's own arena, rolled back with the transaction.
insert into arenas(id, name) values ('e0000000-0000-4000-8000-000000000280'::uuid, 'pgtap 28');
insert into settings(arena_id, key, json)
  values ('e0000000-0000-4000-8000-000000000280'::uuid, 'offline_rules', '{"max_offline_hours": 100000}')
  on conflict (arena_id, key) do nothing;
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000280'::uuid);

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  values ('00000000-0000-0000-0000-000000000000', '28000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'owner28@test.local', '', now(), now(), now(), '{}', '{}',
    false, false)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000280','28000000-0000-0000-0000-000000000001','Owner','owner',
    _known_perms(), true);

create function pg_temp.r(n text) returns uuid as $$ select id from resources where name = n and arena_id = 'e0000000-0000-4000-8000-000000000280'::uuid $$ language sql;
create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.push(p_kind text, p jsonb) returns jsonb as $$
  select sync_push('e0000000-0000-4000-8000-000000000280'::uuid,
    jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', p_kind, 'payload', p)),
    'pgtap') -> 'results' -> 0 $$ language sql;
-- A missed PS5 bill at 1 pad, paid cash. p_paid null leaves paid_amount_paise out (an older
-- app); p_reason null leaves the reason out.
create function pg_temp.rec(p_id text, p_res text, p_from text, p_to text, p_billed bigint,
    p_paid jsonb, p_reason text) returns jsonb as $$
  select pg_temp.push('session.record', jsonb_strip_nulls(jsonb_build_object(
      'session_id', p_id, 'payment_id', gen_random_uuid(),
      'customer_id', 'cccccccc-0000-0000-0000-000000000028', 'resource_id', pg_temp.r(p_res),
      'activity_code', 'PS5', 'controller_count', 1, 'started_at', p_from, 'ended_at', p_to,
      'method', 'cash', 'billed_amount_paise', p_billed, 'reason', p_reason))
    || case when p_paid is null then '{}'::jsonb
            else jsonb_build_object('paid_amount_paise', p_paid) end) $$ language sql;
create function pg_temp.billed(p_id text) returns bigint as $$
  select billed_amount_paise from sessions where id = p_id::uuid $$ language sql;
create function pg_temp.paid(p_id text) returns bigint as $$
  select coalesce(sum(amount_paise), 0)::bigint from payments where session_id = p_id::uuid $$ language sql;
create function pg_temp.charged(p_id text) returns bigint as $$
  select coalesce(sum(amount_paise), 0)::bigint from session_charges where session_id = p_id::uuid $$ language sql;
create function pg_temp.audit(p_id text) returns jsonb as $$
  select after from audit_log where entity_id = p_id::uuid and action = 'record' $$ language sql;
-- The bill p_id as the floor app's My bills lists it on IST day p_day (null when not listed).
create function pg_temp.mine(p_day text, p_id text) returns jsonb as $$
  select b from jsonb_array_elements(private.my_bills('e0000000-0000-4000-8000-000000000280'::uuid,
      p_day::date)) b where b->>'id' = p_id $$ language sql;
-- The bill p_id as the dashboard's Sales lists it for [p_from, p_to) (null when not listed).
create function pg_temp.listed(p_from text, p_to text, p_id text) returns jsonb as $$
  select b from jsonb_array_elements(private.arena_sales('e0000000-0000-4000-8000-000000000280'::uuid,
      p_from::timestamptz, p_to::timestamptz)) b where b->>'id' = p_id $$ language sql;

select pg_temp.as_user('28000000-0000-0000-0000-000000000001');
select is(pg_temp.push('customer.create', jsonb_build_object(
    'id','cccccccc-0000-0000-0000-000000000028','name','Kiran','phone','9800002828',
    'is_guest', false))->>'status', 'applied', 'the owner registers Kiran');
select is((private.session_quote('e0000000-0000-4000-8000-000000000280'::uuid, pg_temp.r('HEX'),
    'PS5', 1, '2026-10-01T05:30:00Z', '2026-10-01T06:30:00Z')->>'total')::bigint, 15000::bigint,
  'a PS5 hour at 1 pad is ₹150 on today''s list');

-- ------------------------------------------------------------- an older app (no amount paid)
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000001', 'HEX', '2026-10-01T05:30:00Z',
    '2026-10-01T06:30:00Z', 15000, null, 'Power cut')->'result',
  jsonb_build_object('session_id', 'a2800000-0000-0000-0000-000000000001',
    'billed_amount_paise', 15000, 'quoted_paise', 15000, 'payment_status', 'paid'),
  'an older app sends no amount paid: billed the price, as before');
select is(pg_temp.paid('a2800000-0000-0000-0000-000000000001'), 15000::bigint,
  'and paid the price');
select is((pg_temp.audit('a2800000-0000-0000-0000-000000000001')->>'difference_paise')::bigint,
  0::bigint, 'with no difference in the audit');
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000006', 'HEX', '2026-10-01T07:00:00Z',
    '2026-10-01T08:00:00Z', 15000, 'null'::jsonb, 'Power cut')->'result'->>'billed_amount_paise',
  '15000', 'an explicit null amount paid is the price too');

-- ------------------------------------------------------------------- paid less than the price
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000002', 'VOID', '2026-10-01T05:30:00Z',
    '2026-10-01T06:30:00Z', 15000, '10000'::jsonb, '  Old rate, ₹100  ')->'result',
  jsonb_build_object('session_id', 'a2800000-0000-0000-0000-000000000002',
    'billed_amount_paise', 10000, 'quoted_paise', 15000, 'payment_status', 'paid'),
  'paid ₹100 on a ₹150 price: billed ₹100, paid');
select is(pg_temp.billed('a2800000-0000-0000-0000-000000000002'), 10000::bigint,
  'the bill is the amount paid');
select is((select array_agg(amount_paise || ' ' || method || ' ' || note || ' ' || reason)
             from payments where session_id = 'a2800000-0000-0000-0000-000000000002'),
  array['10000 cash Added later Old rate, ₹100'],
  'one payment for the amount paid, noted Added later with the trimmed reason');
select is((select payment_status from sessions where id = 'a2800000-0000-0000-0000-000000000002'),
  'paid', 'the bill is settled');
select is(pg_temp.charged('a2800000-0000-0000-0000-000000000002'), 15000::bigint,
  'the charge lines keep today''s price');
select is(pg_temp.audit('a2800000-0000-0000-0000-000000000002')
    - 'method' - 'resource_id' - 'started_at' - 'ended_at',
  '{"billed_paise": 10000, "quoted_paise": 15000, "paid_paise": 10000, "difference_paise": -5000}'::jsonb,
  'the audit keeps the price, the amount paid and the difference');
select is((select reason from audit_log where entity_id = 'a2800000-0000-0000-0000-000000000002'
             and action = 'record'), 'Old rate, ₹100', 'and the reason');
select is((private.arena_sale('e0000000-0000-4000-8000-000000000280'::uuid,
    'a2800000-0000-0000-0000-000000000002'::uuid)->'history'->0->'after'->>'difference_paise')::bigint,
  -5000::bigint, 'the dashboard''s bill history carries the difference');

-- ------------------------------------------------------------------- paid more than the price
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000003', 'GHOST', '2026-10-01T05:30:00Z',
    '2026-10-01T06:30:00Z', 15000, '17000'::jsonb, 'Old rate, ₹170')->'result'->>'billed_amount_paise',
  '17000', 'paid ₹170 on a ₹150 price: billed ₹170');
select is(pg_temp.paid('a2800000-0000-0000-0000-000000000003'), 17000::bigint,
  'and paid ₹170');
select is((pg_temp.audit('a2800000-0000-0000-0000-000000000003')->>'difference_paise')::bigint,
  2000::bigint, 'the audit difference is +₹20');

-- --------------------------------------------------------------------------------- paid nothing
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000004', 'RIFT', '2026-10-01T05:30:00Z',
    '2026-10-01T06:30:00Z', 15000, '0'::jsonb, 'Free game, owner''s friend')->'result',
  jsonb_build_object('session_id', 'a2800000-0000-0000-0000-000000000004',
    'billed_amount_paise', 0, 'quoted_paise', 15000, 'payment_status', 'paid'),
  'paid nothing: billed ₹0, settled');
select is((select count(*) from payments where session_id = 'a2800000-0000-0000-0000-000000000004'),
  0::bigint, 'with no payment row');
select is((pg_temp.audit('a2800000-0000-0000-0000-000000000004')->>'difference_paise')::bigint,
  -15000::bigint, 'the audit difference is the whole price');

-- ---------------------------------------------------- the bill lists carry the price (quoted_paise)
select is((select jsonb_build_array(b->'billed_paise', b->'paid_paise', b->'quoted_paise')
             from pg_temp.mine('2026-10-01', 'a2800000-0000-0000-0000-000000000002') b),
  '[10000, 10000, 15000]'::jsonb,
  'My bills shows the amount paid as billed and paid, and today''s price next to it');
select is((pg_temp.listed('2026-09-30T18:30:00Z', '2026-10-01T18:30:00Z',
    'a2800000-0000-0000-0000-000000000002')->>'quoted_paise')::bigint, 15000::bigint,
  'so does Sales');
select is((pg_temp.mine('2026-10-01', 'a2800000-0000-0000-0000-000000000004')->>'quoted_paise')::bigint,
  15000::bigint, 'a ₹0 missed bill (no payment row) still carries its price');
select is(pg_temp.push('session.start', jsonb_build_object(
    'id', 'a2800000-0000-0000-0000-000000000005', 'segment_id', 'b2800000-0000-0000-0000-000000000005',
    'customer_id', 'cccccccc-0000-0000-0000-000000000028', 'started_at', '2026-10-01T11:00:00Z',
    'scheduled_end_at', '2026-10-01T12:00:00Z',
    'pricing_snapshot', _pricing_snapshot('e0000000-0000-4000-8000-000000000280'::uuid),
    'resource_id', pg_temp.r('HEX'), 'activity_code', 'PS5', 'game_id', null,
    'controller_count', 1, 'allocations', '[]'::jsonb, 'moves', '[]'::jsonb))->>'status',
  'applied', 'a bill started on the floor');
select is(pg_temp.push('session.end', jsonb_build_object(
    'session_id', 'a2800000-0000-0000-0000-000000000005', 'ended_at', '2026-10-01T12:00:00Z',
    'billed_amount_paise', 15000, 'mark_waived', false, 'waive_reason', null,
    'expected_segment_ids', jsonb_build_array('b2800000-0000-0000-0000-000000000005'),
    'expected_scheduled_end_at', '2026-10-01T12:00:00Z',
    'charges', jsonb_build_array(jsonb_build_object('id', gen_random_uuid(),
      'segment_id', 'b2800000-0000-0000-0000-000000000005', 'segment_index', 0,
      'band_code', 'standard', 'activity_code', 'PS5', 'resource_id', pg_temp.r('HEX'),
      'controller_count', 1, 'segment_start', '2026-10-01T11:00:00Z',
      'segment_end', '2026-10-01T12:00:00Z', 'played_minutes', 60, 'billed_minutes', 60,
      'unit_minutes', 60, 'unit_price_paise', 15000, 'amount_paise', 15000))))->>'status',
  'applied', 'and ended at ₹150');
select is(pg_temp.mine('2026-10-01', 'a2800000-0000-0000-0000-000000000005')->'quoted_paise',
  'null'::jsonb, 'a bill played on the floor has no missed-bill price');

-- ------------------------------------------------------------------ the business day is IST's
-- 23:30 IST Thu 1 Oct → 00:30 IST Fri 2 Oct (18:00–19:00 UTC, still 1 Oct in UTC): the bill
-- closed on Fri 2 Oct, and both lists put it there.
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000007', 'HEX', '2026-10-01T18:00:00Z',
    '2026-10-01T19:00:00Z',
    (private.session_quote('e0000000-0000-4000-8000-000000000280'::uuid, pg_temp.r('HEX'), 'PS5', 1,
      '2026-10-01T18:00:00Z', '2026-10-01T19:00:00Z')->>'total')::bigint,
    '10000'::jsonb, 'Late game, power cut')->>'status', 'applied',
  'a missed bill that ends after IST midnight');
select ok(pg_temp.mine('2026-10-02', 'a2800000-0000-0000-0000-000000000007') is not null,
  'My bills lists it on the IST day it closed (Fri 2 Oct)');
select ok(pg_temp.mine('2026-10-01', 'a2800000-0000-0000-0000-000000000007') is null,
  'and not on its UTC date (Thu 1 Oct)');
select ok(pg_temp.listed('2026-10-01T18:30:00Z', '2026-10-02T18:30:00Z',
    'a2800000-0000-0000-0000-000000000007') is not null,
  'Sales lists it on IST Fri 2 Oct as well');
select ok(pg_temp.listed('2026-09-30T18:30:00Z', '2026-10-01T18:30:00Z',
    'a2800000-0000-0000-0000-000000000007') is null,
  'and not on Thu 1 Oct');

-- --------------------------------------------------------------------------------- refusals
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000011', 'HEX', '2026-10-01T09:00:00Z',
    '2026-10-01T10:00:00Z', 15000, '-100'::jsonb, 'Old rate')->>'error', 'invalid_total',
  'a negative amount paid is refused');
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000012', 'HEX', '2026-10-01T09:00:00Z',
    '2026-10-01T10:00:00Z', 15000, '12.5'::jsonb, 'Old rate')->>'error', 'invalid_total',
  'so is a fraction of a paisa');
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000013', 'HEX', '2026-10-01T09:00:00Z',
    '2026-10-01T10:00:00Z', 15000, '"15000"'::jsonb, 'Old rate')->>'error', 'invalid_total',
  'and an amount sent as text');
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000014', 'HEX', '2026-10-01T09:00:00Z',
    '2026-10-01T10:00:00Z', 15000, 'true'::jsonb, 'Old rate')->>'error', 'invalid_total',
  'and one that is not a number at all');
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000015', 'HEX', '2026-10-01T09:00:00Z',
    '2026-10-01T10:00:00Z', 15000, '1000000001'::jsonb, 'Old rate')->>'error', 'invalid_total',
  'and one above ₹1,00,00,000');
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000016', 'HEX', '2026-10-01T09:00:00Z',
    '2026-10-01T10:00:00Z', 15000, '10000'::jsonb, null)->>'error', 'reason_required',
  'a missing reason is refused');
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000017', 'HEX', '2026-10-01T09:00:00Z',
    '2026-10-01T10:00:00Z', 15000, '10000'::jsonb, '   ')->>'error', 'reason_required',
  'so is a blank one');
select is(pg_temp.rec('a2800000-0000-0000-0000-000000000018', 'HEX', '2026-10-01T09:00:00Z',
    '2026-10-01T10:00:00Z', 14000, '10000'::jsonb, 'Old rate')->>'error', 'price_mismatch',
  'the price shown must still be the server''s');
select is((select count(*) from sessions
            where id::text between 'a2800000-0000-0000-0000-000000000011'
                               and 'a2800000-0000-0000-0000-000000000018'),
  0::bigint, 'nothing is written for a refused bill');

select * from finish();
rollback;
