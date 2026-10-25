-- Discounts and coupons: discount.* ops, the discount_options setting, the optional discount on
-- session.end (_discount_apply), its record (bill_discounts), the sales summary and
-- the owner's usage report.
--
-- Seed list: PS5 standard 1 pad ₹150/h, 2 pads ₹280/h, no pricing rules; Thu 2026-10-01,
-- 18:30–19:30 IST (13:00–14:00Z). Cash rounded to ₹1.
begin;
create extension if not exists pgtap;
select * from no_plan();

insert into arenas(id, name) values ('e0000000-0000-4000-8000-000000000125'::uuid, 'pgtap 25');
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
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000125'::uuid);

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  values
  ('00000000-0000-0000-0000-000000000000','25000000-0000-0000-0000-000000000001','authenticated',
   'authenticated','owner25@test.local','',now(),now(),now(),'{}','{}',false,false),
  ('00000000-0000-0000-0000-000000000000','25000000-0000-0000-0000-000000000002','authenticated',
   'authenticated','staff25@test.local','',now(),now(),now(),'{}','{}',false,false),
  ('00000000-0000-0000-0000-000000000000','25000000-0000-0000-0000-000000000003','authenticated',
   'authenticated','floor25@test.local','',now(),now(),now(),'{}','{}',false,false)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000125'::uuid,'25000000-0000-0000-0000-000000000001','Owner','owner',
    array['start','bill','discount','members','stations','money','reports','settings'],true),
  ('e0000000-0000-4000-8000-000000000125'::uuid,'25000000-0000-0000-0000-000000000002','Staff','staff',
    array['start','bill','discount','members'],true),
  ('e0000000-0000-4000-8000-000000000125'::uuid,'25000000-0000-0000-0000-000000000003','Floor','staff',
    array['start','bill'],true);

create function pg_temp.arena() returns uuid as $$ select 'e0000000-0000-4000-8000-000000000125'::uuid $$ language sql;
create function pg_temp.r(n text) returns uuid as $$ select id from resources where name = n and arena_id = 'e0000000-0000-4000-8000-000000000125'::uuid $$ language sql;
create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.owner() returns void as $$ select pg_temp.as_user('25000000-0000-0000-0000-000000000001') $$ language sql;
create function pg_temp.staff() returns void as $$ select pg_temp.as_user('25000000-0000-0000-0000-000000000002') $$ language sql;
create function pg_temp.push(p_kind text, p jsonb) returns jsonb as $$
  select sync_push(pg_temp.arena(),
    jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', p_kind, 'payload', p)), 'pgtap')
    -> 'results' -> 0 $$ language sql;
-- A 1-pad PS5 session on station p_res, 18:30–19:30 IST on day p_day (2026-10-p_day).
create function pg_temp.start(p_n int, p_res text, p_day int default 1) returns jsonb as $$
  select pg_temp.push('session.start', jsonb_build_object(
    'id', ('a2500000-0000-0000-0000-00000000000' || p_n)::uuid,
    'segment_id', ('b2500000-0000-0000-0000-00000000000' || p_n)::uuid,
    'customer_id','cccccccc-0000-0000-0000-000000000025',
    'started_at', format('2026-10-%sT13:00:00Z', lpad(p_day::text, 2, '0')),
    'scheduled_end_at', format('2026-10-%sT14:00:00Z', lpad(p_day::text, 2, '0')),
    'pricing_snapshot', _pricing_snapshot(pg_temp.arena()), 'resource_id', pg_temp.r(p_res),
    'activity_code','PS5','controller_count',1,'allocations','[]'::jsonb,'moves','[]'::jsonb)) $$ language sql;
create function pg_temp.end_op(p_n int, p_res text, p_billed bigint, p_disc jsonb,
    p_day int default 1, p_waive boolean default false) returns jsonb as $$
  select pg_temp.push('session.end', jsonb_build_object(
    'session_id', ('a2500000-0000-0000-0000-00000000000' || p_n)::uuid,
    'ended_at', format('2026-10-%sT14:00:00Z', lpad(p_day::text, 2, '0')),
    'billed_amount_paise', p_billed, 'mark_waived', p_waive,
    'waive_reason', case when p_waive then 'Walked out' end,
    'expected_segment_ids', jsonb_build_array(('b2500000-0000-0000-0000-00000000000' || p_n)::uuid),
    'expected_scheduled_end_at', format('2026-10-%sT14:00:00Z', lpad(p_day::text, 2, '0')),
    'charges', jsonb_build_array(jsonb_build_object('id', gen_random_uuid(),
      'segment_id', ('b2500000-0000-0000-0000-00000000000' || p_n)::uuid, 'segment_index', 0,
      'band_code','standard','activity_code','PS5','resource_id',pg_temp.r(p_res),'controller_count',1,
      'segment_start', format('2026-10-%sT13:00:00Z', lpad(p_day::text, 2, '0')),
      'segment_end', format('2026-10-%sT14:00:00Z', lpad(p_day::text, 2, '0')),
      'played_minutes',60,'billed_minutes',60,'unit_minutes',60,'unit_price_paise',15000,
      'amount_paise',15000)))
    || case when p_disc is null then '{}'::jsonb else jsonb_build_object('discount', p_disc) end)
  $$ language sql;
create function pg_temp.disc(p_id text, p_kind text, p_name text, p_vkind text, p_value bigint,
    p_extra jsonb default '{}') returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'kind', p_kind, 'name', p_name,
    'value_kind', p_vkind, 'value', p_value) || p_extra $$ language sql;

-- ===================== schema + grants
select has_table('public', 'discounts', 'discounts exists');
select has_table('public', 'bill_discounts', 'bill_discounts exists');
select ok(not has_table_privilege(r, t, p), r || ' has no ' || p || ' on ' || t)
from unnest(array['authenticated','anon']) as r,
     unnest(array['public.discounts','public.bill_discounts']) as t,
     unnest(array['INSERT','UPDATE','DELETE','TRUNCATE']) as p;
select ok((select qual from pg_policies where tablename = 'bill_discounts') like '%app_arena_ids_with%',
  'bill_discounts are readable only with bill, money or reports');
select ok(not has_function_privilege('authenticated', f, 'execute'), f || ' is not client-callable')
  from unnest(array['_discount_apply(uuid,jsonb,jsonb,timestamptz,uuid)',
    '_discount_options(jsonb)','op_discount_upsert(uuid,jsonb)']) f;

-- ===================== catalog ops
select pg_temp.staff();
select is(pg_temp.push('discount.upsert', pg_temp.disc('d2500000-0000-0000-0000-000000000001',
    'coupon','Diwali','percent',20,'{"code":"diwali20"}'))->>'error', 'forbidden',
  'staff without settings cannot create a coupon');
select pg_temp.owner();
select is(pg_temp.push('discount.upsert', pg_temp.disc('d2500000-0000-0000-0000-000000000009',
    'coupon','Bad','percent',20,'{"code":"x"}'))->>'error', 'invalid_code', 'a 1-letter code is refused');
select is(pg_temp.push('discount.upsert', pg_temp.disc('d2500000-0000-0000-0000-000000000009',
    'preset','Bad','percent',101))->>'error', 'invalid_discount', 'over 100% is refused');
select is(pg_temp.push('discount.upsert', pg_temp.disc('d2500000-0000-0000-0000-000000000009',
    'preset','Bad','flat',100,'{"activity_codes":["NOPE"]}'))->>'error', 'unknown_type',
  'an unknown type is refused');
select is(pg_temp.push('discount.upsert', pg_temp.disc('d2500000-0000-0000-0000-000000000001',
    'coupon','Diwali','percent',20,
    '{"code":" diwali20 ","max_discount_paise":2500,"max_uses":1,"valid_until":"2026-10-31T18:29:59Z"}'))
    ->>'status', 'applied', 'owner creates DIWALI20: 20%, at most ₹25, once, until 31 Oct');
select is((select code from discounts where id = 'd2500000-0000-0000-0000-000000000001'), 'DIWALI20',
  'the code is stored trimmed and upper-cased');
select is(pg_temp.push('discount.upsert', pg_temp.disc('d2500000-0000-0000-0000-000000000002',
    'coupon','Copy','flat',100,'{"code":"DIWALI20"}'))->>'error', 'duplicate', 'a code is unique');
select is(pg_temp.push('discount.upsert', pg_temp.disc('d2500000-0000-0000-0000-000000000003',
    'preset','Student','percent',10,'{"code":"IGNORED"}'))->>'status', 'applied',
  'owner creates the Student 10% preset');
select is((select code from discounts where id = 'd2500000-0000-0000-0000-000000000003'), null,
  'a preset has no code');
select is(pg_temp.push('discount.upsert', pg_temp.disc('d2500000-0000-0000-0000-000000000004',
    'coupon','Pool only','flat',5000,'{"code":"POOL50","activity_codes":["POOL"]}'))->>'status', 'applied',
  'owner creates POOL50 (POOL only)');
select is(pg_temp.push('discount.upsert', pg_temp.disc('d2500000-0000-0000-0000-000000000005',
    'preset','Big spender','flat',2000,'{"min_bill_paise":20000}'))->>'status', 'applied',
  'owner creates a ₹20 preset for bills of ₹200 or more');
select is(pg_temp.push('discount.upsert', pg_temp.disc('d2500000-0000-0000-0000-000000000006',
    'coupon','Old','percent',50,'{"code":"SUMMER","valid_until":"2026-09-30T18:29:59Z"}'))->>'status',
  'applied', 'owner creates SUMMER, expired at the end of September');
select is(pg_temp.push('settings.save', jsonb_build_object('key','discount_options',
    'json', jsonb_build_object('manual_max_percent', 101, 'reason_required', true)))->>'error',
  'invalid_discount_options', 'a manual cap over 100% is refused');
select is(pg_temp.push('settings.save', jsonb_build_object('key','discount_options',
    'json', jsonb_build_object('manual_max_percent', 10, 'reason_required', true)))->>'status',
  'applied', 'staff may take off at most 10% by hand, with a reason');

-- ===================== a coupon on a session
select pg_temp.staff();
select is(pg_temp.push('customer.create', jsonb_build_object(
    'id','cccccccc-0000-0000-0000-000000000025','name','Neha','phone','9800002525',
    'is_guest', false))->>'status', 'applied', 'staff creates a customer');
select is(pg_temp.start(1, 'HEX')->>'status', 'applied', 'session 1 starts on HEX');
select is(pg_temp.end_op(1, 'HEX', 12000, '{"code":"diwali20","amount_paise":3000}')->>'error',
  'price_mismatch', '20% of ₹150 without the ₹25 cap is refused');
select is(pg_temp.end_op(1, 'HEX', 12500, '{"code":"NOPE","amount_paise":2500}')->>'error',
  'coupon_unknown', 'an unknown code is refused');
select is(pg_temp.end_op(1, 'HEX', 7500, '{"code":"SUMMER","amount_paise":7500}')->>'error',
  'coupon_expired', 'an expired coupon is refused');
select is(pg_temp.end_op(1, 'HEX', 10000, '{"code":"POOL50","amount_paise":5000}')->>'error',
  'discount_scope', 'a POOL coupon on a PS5 bill is refused');
select is(pg_temp.end_op(1, 'HEX', 13000,
    '{"discount_id":"d2500000-0000-0000-0000-000000000005","amount_paise":2000}')->>'error',
  'discount_min_bill', 'a preset needing ₹200 on a ₹150 bill is refused');
select is(pg_temp.end_op(1, 'HEX', 12500, '{"code":"DIWALI20","amount_paise":2500}', 1, true)->>'error',
  'invalid_discount', 'a waived bill takes no discount');
select is(pg_temp.end_op(1, 'HEX', 15000, '{"code":"DIWALI20","amount_paise":2500}')->>'error',
  'price_mismatch', 'billing the full ₹150 with a discount is refused');
select is(pg_temp.end_op(1, 'HEX', 12500,
    '{"id":"e2500000-0000-0000-0000-000000000001","code":"DIWALI20","amount_paise":2500}')->>'status',
  'applied', 'DIWALI20 takes ₹25 off: billed ₹125');
select results_eq($$ select source, name, code, value_kind, value, base_paise, amount_paise, applied_by
     from bill_discounts where session_id = 'a2500000-0000-0000-0000-000000000001' $$,
  $$ values ('coupon'::text, 'Diwali'::text, 'DIWALI20'::text, 'percent'::text, 20::bigint,
             15000::bigint, 2500::bigint, '25000000-0000-0000-0000-000000000002'::uuid) $$,
  'the bill keeps a copy of the coupon, the amount and who applied it');
select is((select billed_amount_paise from sessions where id = 'a2500000-0000-0000-0000-000000000001'),
  12500::bigint, 'the session is billed ₹125');

-- ===================== use limit, freed by a void
select is(pg_temp.start(2, 'VOID')->>'status', 'applied', 'session 2 starts on VOID');
select is(pg_temp.end_op(2, 'VOID', 12500, '{"code":"DIWALI20","amount_paise":2500}')->>'error',
  'coupon_used_up', 'DIWALI20 (once) cannot be used again');
select pg_temp.owner();
select is(pg_temp.push('session.void', jsonb_build_object(
    'session_id','a2500000-0000-0000-0000-000000000001','reason','test bill'))->>'status', 'applied',
  'owner voids session 1');
select pg_temp.staff();
select is(pg_temp.end_op(2, 'VOID', 12500, '{"code":"DIWALI20","amount_paise":2500}')->>'status',
  'applied', 'a voided bill no longer counts: DIWALI20 is used on session 2');

-- ===================== manual discounts
select is(pg_temp.start(3, 'GHOST')->>'status', 'applied', 'session 3 starts on GHOST');
select pg_temp.as_user('25000000-0000-0000-0000-000000000003');
select is(pg_temp.end_op(3, 'GHOST', 13500,
    '{"manual":{"value_kind":"percent","value":10},"reason":"regular","amount_paise":1500}')->>'error',
  'forbidden', 'staff without the discount permission cannot discount by hand');
select pg_temp.staff();
select is(pg_temp.end_op(3, 'GHOST', 12000,
    '{"manual":{"value_kind":"percent","value":20},"reason":"regular","amount_paise":3000}')->>'error',
  'discount_over_limit', '20% is over the 10% staff limit');
select is(pg_temp.end_op(3, 'GHOST', 13000,
    '{"manual":{"value_kind":"flat","value":2000},"reason":"regular","amount_paise":2000}')->>'error',
  'discount_over_limit', '₹20 off ₹150 (13%) is over the limit too');
select is(pg_temp.end_op(3, 'GHOST', 13500,
    '{"manual":{"value_kind":"percent","value":10},"amount_paise":1500}')->>'error',
  'discount_reason_required', 'a manual discount needs a reason');
select is(pg_temp.end_op(3, 'GHOST', 13500,
    '{"manual":{"value_kind":"percent","value":10},"reason":"regular","amount_paise":1500}')->>'status',
  'applied', '10% by hand with a reason: billed ₹135');
select results_eq($$ select source, discount_id, name, reason from bill_discounts
     where session_id = 'a2500000-0000-0000-0000-000000000003' $$,
  $$ values ('manual'::text, null::uuid, 'Manual discount'::text, 'regular'::text) $$,
  'the manual discount is recorded with its reason');
select pg_temp.owner();
select is(pg_temp.start(4, 'HEX', 2)->>'status', 'applied', 'owner starts session 4 (Fri)');
select is(pg_temp.end_op(4, 'HEX', 7500,
    '{"manual":{"value_kind":"percent","value":50},"reason":"friend","amount_paise":7500}', 2)->>'status',
  'applied', 'an owner (settings) is not held to the staff limit');

-- ===================== a preset (Student 10%) on session 6 (GHOST, Sat)
select pg_temp.staff();
select is(pg_temp.start(6, 'GHOST', 3)->>'status', 'applied', 'session 6 starts on GHOST (Sat)');
select is(pg_temp.end_op(6, 'GHOST', 13500,
    '{"discount_id":"d2500000-0000-0000-0000-000000000003","amount_paise":1500}', 3)->>'status',
  'applied', 'Student 10% on the ₹150 bill: ₹135');
select is((select amount_paise from bill_discounts where session_id = 'a2500000-0000-0000-0000-000000000006'),
  1500::bigint, 'the preset''s discount is recorded');

-- ===================== sales and usage report
select pg_temp.owner();
select is((select b->>'discount_paise' from _sales(pg_temp.arena(), null, null,
            'a2500000-0000-0000-0000-000000000002') b), '2500', 'the sales summary carries the discount');
select is((select b->'discount'->>'code' from _sales(pg_temp.arena(), null, null,
            'a2500000-0000-0000-0000-000000000002') b), 'DIWALI20', '…and which coupon it was');
select is((arena_discount_usage(pg_temp.arena(), 'd2500000-0000-0000-0000-000000000001')->>'uses')::int, 2,
  'DIWALI20 was used on 2 bills');
select is((arena_discount_usage(pg_temp.arena(), 'd2500000-0000-0000-0000-000000000001')->>'active_uses')::int,
  1, '…1 of them not voided');
create temp table pg1 as select arena_discount_usage(pg_temp.arena(),
  'd2500000-0000-0000-0000-000000000001', 1) as u;
select is((select jsonb_array_length(u->'rows') from pg1), 1, 'one row per page');
select ok((select u->>'next' is not null from pg1), '…with a cursor to the next page');
select is((select array_agg(b order by b) from (
    select (u->'rows'->0->>'bill_id') b from pg1
    union all
    select arena_discount_usage(pg_temp.arena(), 'd2500000-0000-0000-0000-000000000001', 1,
             (select u->>'next' from pg1))->'rows'->0->>'bill_id') t),
  array['a2500000-0000-0000-0000-000000000001','a2500000-0000-0000-0000-000000000002'],
  'the next page holds the other bill, though both ended at the same instant');
select is((select jsonb_array_length(arena_discount_usage(pg_temp.arena(),
    'd2500000-0000-0000-0000-000000000001', 1, (select u->>'next' from pg1))->'rows')), 1,
  'the last page has the last row');
select pg_temp.staff();
select throws_ok($$ select arena_discount_usage(pg_temp.arena(), 'd2500000-0000-0000-0000-000000000001') $$,
  '42501', null, 'staff cannot read the usage report');

-- ===================== deleting and turning off
select pg_temp.owner();
select is(pg_temp.push('discount.delete', jsonb_build_object('id','d2500000-0000-0000-0000-000000000001'))
    ->>'error', 'discount_used', 'a used coupon cannot be deleted');
select is(pg_temp.push('discount.set_active', jsonb_build_object('id','d2500000-0000-0000-0000-000000000001',
    'active', false))->>'status', 'applied', '…but can be turned off');
select is(pg_temp.push('discount.upsert', pg_temp.disc('d2500000-0000-0000-0000-000000000003',
    'coupon','Student','percent',10,'{"code":"STUDENT"}'))->>'error', 'kind_locked',
  'a used preset cannot become a coupon');
select is(pg_temp.push('discount.delete', jsonb_build_object('id','d2500000-0000-0000-0000-000000000004'))
    ->>'status', 'applied', 'an unused coupon is deleted');
select is((select count(*)::int from discounts where id = 'd2500000-0000-0000-0000-000000000004'), 0, '…and gone');

select pg_temp.staff();
select is(pg_temp.start(5, 'RIFT', 2)->>'status', 'applied', 'session 5 starts on RIFT');
select is(pg_temp.end_op(5, 'RIFT', 12500, '{"code":"DIWALI20","amount_paise":2500}', 2)->>'error',
  'discount_inactive', 'a turned-off coupon is refused');

select * from finish();
rollback;
