-- Sales corrections and audit (staff handover audit, 2026-10-14):
--   * a void needs a reason, trimmed, at most 500 characters;
--   * money collected before a void can be refunded (never more than collected), while a
--     voided bill takes no new payment;
--   * a waive writes an audit entry with the amount written off and the staff reason;
--   * payment.correct moves all or part of a payment to the method it was really taken by, as
--     an append-only refund + payment pair (money permission, reason required, audited, never
--     more than the payment, replay-safe);
--   * arena_sales / arena_sale carry what the dashboard's report needs (returning customer,
--     player-minutes, payments ledger, who/when of the void, server receipt time, history), and
--     every bill's per-method nets and ledger add up to its collected amount.
-- Bills are built through the only client write path (sync_push → op_*).
--
-- Thu 2026-10-01; the 'Happy hours' rule (PS5 started 14:00–17:00 IST = 08:30–11:30Z, 20% lower)
-- makes an hour ₹120 at 1 pad and, with this file's ₹275 2-pad rate, ₹220 at 2 pads.
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated fixture: this file's own arena, rolled back with the transaction.
insert into arenas(id, name) values ('e0000000-0000-4000-8000-000000000220'::uuid, 'pgtap 22');
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
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000220'::uuid);
insert into pricing_rules(arena_id, name, days, start_min, end_min, holiday_mode, activity_codes,
    adjust_kind, adjust_value)
  values ('e0000000-0000-4000-8000-000000000220'::uuid, 'Happy hours', '{2,3,4,5}', 840, 1020,
    'skip', '{PS5}', 'percent', -20);
update rates set price_paise = 27500
 where arena_id = 'e0000000-0000-4000-8000-000000000220'::uuid and controller_count = 2
   and activity_id = (select id from activities where arena_id = 'e0000000-0000-4000-8000-000000000220'::uuid and code = 'PS5');

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  select '00000000-0000-0000-0000-000000000000', u.id::uuid, 'authenticated', 'authenticated',
         u.email, '', now(), now(), now(), '{}', '{}', false, false
    from (values
      ('22000000-0000-0000-0000-000000000001', 'owner22@test.local'),
      ('22000000-0000-0000-0000-000000000002', 'staff22@test.local'),
      ('22000000-0000-0000-0000-000000000003', 'cashier22@test.local')) u(id, email)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000220','22000000-0000-0000-0000-000000000001','Owner','owner',
    _known_perms(), true),
  ('e0000000-0000-4000-8000-000000000220','22000000-0000-0000-0000-000000000002','Staff','staff',
    array['start','bill','discount','members'], true),
  ('e0000000-0000-4000-8000-000000000220','22000000-0000-0000-0000-000000000003','Cashier','staff',
    array['start','bill','money'], true);

create function pg_temp.r(n text) returns uuid as $$ select id from resources where name = n and arena_id = 'e0000000-0000-4000-8000-000000000220'::uuid $$ language sql;
create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.push_id(p_op text, p_kind text, p jsonb) returns jsonb as $$
  select sync_push('e0000000-0000-4000-8000-000000000220'::uuid,
    jsonb_build_array(jsonb_build_object('op_id', p_op::uuid, 'kind', p_kind, 'payload', p)),
    'pgtap') -> 'results' -> 0 $$ language sql;
create function pg_temp.push(p_kind text, p jsonb) returns jsonb as $$
  select pg_temp.push_id(gen_random_uuid()::text, p_kind, p) $$ language sql;
create function pg_temp.start(p_id text, p_seg text, p_res text, p_at text, p_end text,
    p_customer text, p_cc int) returns jsonb as $$
  select jsonb_build_object('id', p_id::uuid, 'segment_id', p_seg::uuid,
    'customer_id', p_customer::uuid, 'started_at', p_at, 'scheduled_end_at', p_end,
    'pricing_snapshot', _pricing_snapshot('e0000000-0000-4000-8000-000000000220'::uuid),
    'resource_id', pg_temp.r(p_res), 'activity_code', 'PS5', 'game_id', null,
    'controller_count', p_cc, 'allocations', '[]'::jsonb, 'moves', '[]'::jsonb) $$ language sql;
-- End a PS5 session with one charge line of p_amount (60 minutes, p_cc pads).
create function pg_temp.end_(p_id text, p_seg text, p_res text, p_from text, p_to text,
    p_amount int, p_cc int, p_waive boolean, p_reason text) returns jsonb as $$
  select pg_temp.push('session.end', jsonb_build_object('session_id', p_id,
    'ended_at', p_to, 'billed_amount_paise', p_amount, 'mark_waived', p_waive,
    'waive_reason', p_reason,
    'expected_segment_ids', jsonb_build_array(p_seg), 'expected_scheduled_end_at', p_to,
    'charges', jsonb_build_array(jsonb_build_object('id', gen_random_uuid(),
      'segment_id', p_seg, 'segment_index', 0, 'band_code', 'standard',
      'activity_code', 'PS5', 'resource_id', pg_temp.r(p_res), 'controller_count', p_cc,
      'segment_start', p_from, 'segment_end', p_to,
      'played_minutes', 60, 'billed_minutes', 60, 'unit_minutes', 60,
      'unit_price_paise', p_amount, 'amount_paise', p_amount)))) $$ language sql;
create function pg_temp.pay(p_scope text, p_parent text, p_id text, p_amount int, p_method text)
  returns jsonb as $$
  select pg_temp.push('payment.record', jsonb_build_object('scope', p_scope, 'parent_id', p_parent,
    'payment_id', p_id::uuid, 'amount_paise', p_amount, 'method', p_method)) $$ language sql;
create function pg_temp.refund(p_scope text, p_parent text, p_amount int, p_method text, p_reason text)
  returns jsonb as $$
  select pg_temp.push('payment.record', jsonb_build_object('scope', p_scope, 'parent_id', p_parent,
    'payment_id', gen_random_uuid(), 'amount_paise', p_amount, 'method', p_method,
    'is_refund', true, 'reason', p_reason)) $$ language sql;
create function pg_temp.correct(p_scope text, p_parent text, p_payment text, p_method text,
    p_amount int, p_reason text) returns jsonb as $$
  select pg_temp.push('payment.correct', jsonb_strip_nulls(jsonb_build_object('scope', p_scope,
    'parent_id', p_parent, 'payment_id', p_payment, 'method', p_method,
    'amount_paise', p_amount, 'reason', p_reason))) $$ language sql;
create function pg_temp.sales() returns jsonb as $$
  select arena_sales('e0000000-0000-4000-8000-000000000220'::uuid,
    '2026-10-01T00:00:00Z'::timestamptz, '2026-10-02T00:00:00Z'::timestamptz) $$ language sql;
create function pg_temp.sale(p_id text) returns jsonb as $$
  select arena_sale('e0000000-0000-4000-8000-000000000220'::uuid, p_id::uuid) $$ language sql;
create function pg_temp.bill(p_id text) returns jsonb as $$
  select e from jsonb_array_elements(pg_temp.sales()) e where e->>'id' = p_id $$ language sql;
create function pg_temp.methods(p_id text) returns jsonb as $$
  select pg_temp.bill(p_id)->'methods' $$ language sql;

-- ---------------------------------------------------------------- the day's bills
-- A: HEX 09:00–10:00Z, 2 pads, ₹220, Kiran, paid ₹220 cash (really GPay: corrected below).
-- B: GHOST 10:00–11:00Z, 1 pad, ₹120, Kiran again, paid ₹120 UPI, then voided and refunded.
-- W: RIFT 09:00–10:00Z, 1 pad, ₹120, a walk-in, ₹20 cash then waived ("Birthday treat").
select pg_temp.as_user('22000000-0000-0000-0000-000000000002');
select is(pg_temp.push('customer.create', jsonb_build_object(
    'id','cccccccc-0000-0000-0000-000000000022','name','Kiran','phone','9800002222',
    'is_guest', false))->>'status', 'applied', 'staff registers Kiran');
select is(pg_temp.push('customer.create', jsonb_build_object(
    'id','cccccccc-0000-0000-0000-0000000000a2','name','Walk-in 2:30 pm',
    'is_guest', true))->>'status', 'applied', 'and a walk-in');

select is(pg_temp.push('session.start', pg_temp.start('a2200000-0000-0000-0000-00000000000a',
    'b2200000-0000-0000-0000-00000000000a', 'HEX', '2026-10-01T09:00:00Z', '2026-10-01T10:00:00Z',
    'cccccccc-0000-0000-0000-000000000022', 2))->>'status', 'applied', 'A starts on HEX with 2 pads');
select is(pg_temp.end_('a2200000-0000-0000-0000-00000000000a', 'b2200000-0000-0000-0000-00000000000a',
    'HEX', '2026-10-01T09:00:00Z', '2026-10-01T10:00:00Z', 22000, 2, false, null)->>'status',
  'applied', 'A ends at ₹220');
select is(pg_temp.pay('single', 'a2200000-0000-0000-0000-00000000000a',
    'd2200000-0000-0000-0000-00000000000a', 22000, 'cash')->'result'->>'payment_status', 'paid',
  'A: ₹220 recorded as cash');

select is(pg_temp.push('session.start', pg_temp.start('a2200000-0000-0000-0000-00000000000b',
    'b2200000-0000-0000-0000-00000000000b', 'GHOST', '2026-10-01T10:00:00Z', '2026-10-01T11:00:00Z',
    'cccccccc-0000-0000-0000-000000000022', 1))->>'status', 'applied', 'B starts on GHOST');
select is(pg_temp.end_('a2200000-0000-0000-0000-00000000000b', 'b2200000-0000-0000-0000-00000000000b',
    'GHOST', '2026-10-01T10:00:00Z', '2026-10-01T11:00:00Z', 12000, 1, false, null)->>'status',
  'applied', 'B ends at ₹120');
select is(pg_temp.pay('single', 'a2200000-0000-0000-0000-00000000000b',
    'd2200000-0000-0000-0000-00000000000b', 12000, 'upi')->>'status', 'applied', 'B: ₹120 UPI');

select is(pg_temp.push('session.start', pg_temp.start('a2200000-0000-0000-0000-0000000000c1',
    'b2200000-0000-0000-0000-0000000000c1', 'RIFT', '2026-10-01T09:00:00Z', '2026-10-01T10:00:00Z',
    'cccccccc-0000-0000-0000-0000000000a2', 1))->>'status', 'applied', 'W starts on RIFT');
select is(pg_temp.pay('single', 'a2200000-0000-0000-0000-0000000000c1',
    'd2200000-0000-0000-0000-0000000000c1', 2000, 'cash')->>'status', 'applied',
  'W: ₹20 cash taken while it runs');
select is(pg_temp.end_('a2200000-0000-0000-0000-0000000000c1', 'b2200000-0000-0000-0000-0000000000c1',
    'RIFT', '2026-10-01T09:00:00Z', '2026-10-01T10:00:00Z', 12000, 1, true, '  Birthday treat ')
    ->'result'->>'payment_status', 'waived', 'W ends waived, with a reason');

-- ---------------------------------------------------------------- waives are audited
select is((select (reason, before, after)::text from audit_log
            where entity_id = 'a2200000-0000-0000-0000-0000000000c1' and action = 'waive'),
  ('Birthday treat', '{"paid_paise": 2000, "billed_paise": 12000}'::jsonb,
   '{"written_off_paise": 10000}'::jsonb)::text,
  'W''s waive: trimmed reason, billed and paid before, ₹100 written off');
select is((select created_by::text from audit_log
            where entity_id = 'a2200000-0000-0000-0000-0000000000c1' and action = 'waive'),
  '22000000-0000-0000-0000-000000000002', 'recorded as the staff member who waived it');
select is((select count(*)::int from audit_log
            where arena_id = 'e0000000-0000-4000-8000-000000000220' and action = 'waive'), 1,
  'only the waived bill has a waive entry');

-- ---------------------------------------------------------------- a void needs a reason
select pg_temp.as_user('22000000-0000-0000-0000-000000000001');
select is(pg_temp.push('session.void', jsonb_build_object('session_id','a2200000-0000-0000-0000-00000000000b'))
    ->>'error', 'void_reason_required', 'a void with no reason is refused');
select is(pg_temp.push('session.void', jsonb_build_object('session_id','a2200000-0000-0000-0000-00000000000b',
    'reason', '   '))->>'error', 'void_reason_required', 'so is a blank reason');
select is(pg_temp.push('session.void', jsonb_build_object('session_id','a2200000-0000-0000-0000-00000000000b',
    'reason', repeat('x', 501)))->>'error', 'reason_too_long', 'and a reason over 500 characters');
select is((select status from sessions where id = 'a2200000-0000-0000-0000-00000000000b'), 'completed',
  'B is untouched by the refused voids');
select is(pg_temp.push('session.void', jsonb_build_object('session_id','a2200000-0000-0000-0000-00000000000b',
    'reason', '  Duplicate bill '))->>'status', 'applied', 'the owner voids B with a reason');
select is((select void_reason from sessions where id = 'a2200000-0000-0000-0000-00000000000b'),
  'Duplicate bill', 'the reason is stored trimmed');
select is((select (reason, created_by)::text from audit_log
            where entity_id = 'a2200000-0000-0000-0000-00000000000b' and action = 'void'),
  ('Duplicate bill', '22000000-0000-0000-0000-000000000001'::uuid)::text,
  'and audited with who voided it');

-- ---------------------------------------------------------------- refunds after a void
select pg_temp.as_user('22000000-0000-0000-0000-000000000002');
select is(pg_temp.pay('single', 'a2200000-0000-0000-0000-00000000000b',
    'd2200000-0000-0000-0000-0000000000b2', 1000, 'cash')->>'error', 'voided',
  'a voided bill takes no new payment');
select is(pg_temp.refund('single', 'a2200000-0000-0000-0000-00000000000b', 12000, 'upi',
    'Returned to customer')->>'status', 'applied',
  'but the ₹120 collected before the void can be refunded');
select is(pg_temp.refund('single', 'a2200000-0000-0000-0000-00000000000b', 100, 'cash', 'again')
    ->>'error', 'refund_exceeds_paid', 'never more than was collected');
select is((select payment_status from sessions where id = 'a2200000-0000-0000-0000-00000000000b'), 'paid',
  'the refund does not touch a voided bill''s payment status');
select is((select coalesce(sum(amount_paise), 0)::int from payments
            where session_id = 'a2200000-0000-0000-0000-00000000000b'), 0,
  'B now nets to nothing: the till reconciles');

-- ---------------------------------------------------------------- payment.correct
select is(pg_temp.correct('single', 'a2200000-0000-0000-0000-00000000000a',
    'd2200000-0000-0000-0000-00000000000a', 'upi', null, 'Paid by GPay')->>'error', 'forbidden',
  'floor staff without Money cannot correct recorded money');
select pg_temp.as_user('22000000-0000-0000-0000-000000000003');
select is(pg_temp.correct('single', 'a2200000-0000-0000-0000-00000000000a',
    'd2200000-0000-0000-0000-00000000000a', 'upi', null, null)->>'error', 'reason_required',
  'a correction needs a reason');
select is(pg_temp.correct('single', 'a2200000-0000-0000-0000-00000000000a',
    'd2200000-0000-0000-0000-00000000000a', 'cash', null, 'x')->>'error', 'same_method',
  'moving cash to cash is refused');
select is(pg_temp.correct('single', 'a2200000-0000-0000-0000-00000000000a',
    'd2200000-0000-0000-0000-00000000000a', 'gpay', null, 'x')->>'error', 'invalid_method',
  'an unknown method is refused');
select is(pg_temp.correct('single', 'a2200000-0000-0000-0000-00000000000a',
    'd2200000-0000-0000-0000-00000000000b', 'card', null, 'x')->>'error', 'not_found',
  'a payment of another bill is not found under this one');
select is(pg_temp.correct('single', 'a2200000-0000-0000-0000-00000000000a',
    'd2200000-0000-0000-0000-00000000000a', 'upi', 30000, 'x')->>'error', 'amount_invalid',
  'more than the payment cannot be moved');
select is(pg_temp.correct('single', 'a2200000-0000-0000-0000-00000000000a',
    'd2200000-0000-0000-0000-00000000000a', 'upi', 0, 'x')->>'error', 'amount_invalid',
  'nor nothing');

select is(pg_temp.push_id('f2200000-0000-0000-0000-000000000001', 'payment.correct', jsonb_build_object(
    'parent_id', 'a2200000-0000-0000-0000-00000000000a', 'payment_id', 'd2200000-0000-0000-0000-00000000000a',
    'method', 'upi', 'amount_paise', 12000, 'reason', 'Keyed as cash; ₹120 was GPay',
    'refund_id', 'e2200000-0000-0000-0000-000000000001',
    'new_payment_id', 'e2200000-0000-0000-0000-000000000002'))->'result',
  '{"moved_paise": 12000, "refund_id": "e2200000-0000-0000-0000-000000000001", "payment_id": "e2200000-0000-0000-0000-000000000002"}'::jsonb,
  'the cashier moves ₹120 of A''s cash payment to UPI');
select is(pg_temp.push_id('f2200000-0000-0000-0000-000000000001', 'payment.correct', jsonb_build_object(
    'parent_id', 'a2200000-0000-0000-0000-00000000000a', 'payment_id', 'd2200000-0000-0000-0000-00000000000a',
    'method', 'upi', 'amount_paise', 12000, 'reason', 'Keyed as cash; ₹120 was GPay'))->>'replayed', 'true',
  'a resent correction is replayed');
select results_eq(
  $$ select method, amount_paise::int, kind, reason from payments
      where session_id = 'a2200000-0000-0000-0000-00000000000a' order by created_at, amount_paise $$,
  $$ values ('cash', 22000, 'payment', null::text),
            ('cash', -12000, 'refund', 'Keyed as cash; ₹120 was GPay'),
            ('upi', 12000, 'payment', 'Keyed as cash; ₹120 was GPay') $$,
  'written once: the original stays, a cash refund and a UPI payment carry the reason');
select is(pg_temp.methods('a2200000-0000-0000-0000-00000000000a'),
  '{"upi": 12000, "cash": 10000}'::jsonb, 'A''s split is now ₹100 cash + ₹120 UPI');
select is((select (payment_status, billed_amount_paise)::text from sessions
            where id = 'a2200000-0000-0000-0000-00000000000a'), '(paid,22000)',
  'the bill and its status do not change');
select is(pg_temp.correct('single', 'a2200000-0000-0000-0000-00000000000a',
    'd2200000-0000-0000-0000-00000000000a', 'upi', 10001, 'x')->>'error', 'amount_invalid',
  'only the ₹100 left of that payment can still move');
select is(pg_temp.correct('single', 'a2200000-0000-0000-0000-00000000000a',
    'd2200000-0000-0000-0000-00000000000a', 'upi', null, 'Rest was GPay too')->'result'->>'moved_paise',
  '10000', 'with no amount, what is left moves');
select is(pg_temp.methods('a2200000-0000-0000-0000-00000000000a'),
  '{"upi": 22000, "cash": 0}'::jsonb, 'A is all UPI now');
select is(pg_temp.correct('single', 'a2200000-0000-0000-0000-00000000000a',
    'd2200000-0000-0000-0000-00000000000a', 'card', null, 'x')->>'error', 'already_corrected',
  'a payment cannot be moved twice over');
select is(pg_temp.correct('single', 'a2200000-0000-0000-0000-00000000000a',
    'e2200000-0000-0000-0000-000000000001', 'card', null, 'x')->>'error', 'not_a_payment',
  'a refund row cannot be moved');
select ok(not has_function_privilege('authenticated', 'op_payment_correct(uuid,jsonb)', 'EXECUTE')
       and not has_function_privilege('anon', 'op_payment_correct(uuid,jsonb)', 'EXECUTE'),
  'the op is reachable only through sync_push');

-- ---------------------------------------------------------------- what the dashboard reads
select pg_temp.as_user('22000000-0000-0000-0000-000000000001');
select is(jsonb_array_length(pg_temp.sales()), 3, 'the day lists A, B and W');
select is((select (b->>'returning', b->>'players', b->>'player_minutes', b->>'voided_at' is null)::text
             from pg_temp.bill('a2200000-0000-0000-0000-00000000000a') b),
  '(false,2,120,t)', 'A: Kiran''s first visit, 2 players, 120 player-minutes, not voided');
select is((select (b->>'paid_paise', b->>'refunded_paise')::text
             from pg_temp.bill('a2200000-0000-0000-0000-00000000000a') b),
  '(22000,0)', 'A: a method correction is not a refund: nothing was given back');
select is((select (b->>'returning', b->>'voided_by', b->>'paid_paise', b->>'refunded_paise')::text
             from pg_temp.bill('a2200000-0000-0000-0000-00000000000b') b),
  '(true,Owner,0,12000)', 'B: a returning customer; voided by the owner; refunded in full');
select ok((select (b->>'voided_at')::timestamptz is not null and (b->>'recorded_at')::timestamptz is not null
             from pg_temp.bill('a2200000-0000-0000-0000-00000000000b') b),
  'B carries when it was voided and when the server received it');
select is((select (b->>'returning', b->>'guest', b->>'payment_status')::text
             from pg_temp.bill('a2200000-0000-0000-0000-0000000000c1') b),
  '(false,true,waived)', 'W: a walk-in is never "returning"');
-- (The two rows of one correction share a timestamp; within it, the refund is listed first here.)
select is((select string_agg((e->>'method') || ':' || (e->>'amount_paise') || ':' || (e->>'refund')
                             || ':' || (e->>'correction') || ':' || coalesce(e->>'by', '-'), ','
                             order by (e->>'at')::timestamptz, (e->>'refund')::boolean desc)
             from jsonb_array_elements(pg_temp.bill('a2200000-0000-0000-0000-00000000000a')->'payments') e),
  'cash:22000:false:false:Staff,cash:-12000:true:true:Cashier,upi:12000:false:true:Cashier,cash:-10000:true:true:Cashier,upi:10000:false:true:Cashier',
  'A''s ledger in the list: every row, in time order, who recorded it, the correction rows marked');
select is((select string_agg((e->>'amount_paise') || ':' || (e->>'correction'), ',')
             from jsonb_array_elements(pg_temp.bill('a2200000-0000-0000-0000-00000000000b')->'payments') e),
  '12000:false,-12000:false', 'B''s refund is a real refund, not a correction');

-- Every bill reconciles: per-method nets and the ledger both add up to what was collected;
-- refunds are the negative rows that are not corrections; correction rows net to zero.
select is((select count(*)::int from jsonb_array_elements(pg_temp.sales()) b
            where (b->>'paid_paise')::bigint <> (select coalesce(sum(v::bigint), 0)
                                                    from jsonb_each_text(b->'methods') m(k, v))
               or (b->>'paid_paise')::bigint <> (select coalesce(sum((e->>'amount_paise')::bigint), 0)
                                                    from jsonb_array_elements(b->'payments') e)
               or (b->>'refunded_paise')::bigint <> (select coalesce(-sum((e->>'amount_paise')::bigint), 0)
                                                        from jsonb_array_elements(b->'payments') e
                                                       where (e->>'amount_paise')::bigint < 0
                                                         and not (e->>'correction')::boolean)
               or 0 <> (select coalesce(sum((e->>'amount_paise')::bigint), 0)
                          from jsonb_array_elements(b->'payments') e
                         where (e->>'correction')::boolean)), 0,
  'for every bill: methods = ledger = collected; refunds = non-correction negative rows; corrections net to 0');
select is((select sum((b->>'paid_paise')::bigint)::int from jsonb_array_elements(pg_temp.sales()) b),
  (select coalesce(sum(amount_paise), 0)::int from payments
    where arena_id = 'e0000000-0000-4000-8000-000000000220'),
  'the day''s collected (all bills) equals the raw payments ledger');

select is((select string_agg((h->>'action') || ':' || coalesce(h->>'by', '-') || ':'
                             || (h->'before'->>'method') || '>' || (h->'after'->>'method') || ':'
                             || (h->'after'->>'amount_paise'), ',')
             from jsonb_array_elements(pg_temp.sale('a2200000-0000-0000-0000-00000000000a')->'history') h),
  'payment_correct:Cashier:cash>upi:12000,payment_correct:Cashier:cash>upi:10000',
  'A''s history: both corrections, who, from and to, how much');
select is((select string_agg((h->>'action') || ':' || (h->>'by') || ':' || (h->>'reason'), ',')
             from jsonb_array_elements(pg_temp.sale('a2200000-0000-0000-0000-00000000000b')->'history') h),
  'void:Owner:Duplicate bill', 'B''s history: the void, who and why');
select is((select (h->>'action') || ':' || (h->>'reason') || ':' || (h->'after'->>'written_off_paise')
             from jsonb_array_elements(pg_temp.sale('a2200000-0000-0000-0000-0000000000c1')->'history') h),
  'waive:Birthday treat:10000', 'W''s history: the waive, why and how much was written off');
select is(jsonb_array_length(pg_temp.sale('a2200000-0000-0000-0000-00000000000b')->'payments'), 2,
  'the detail still carries the payments ledger');

select * from finish();
rollback;
