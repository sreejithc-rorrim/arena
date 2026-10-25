-- policy.save (op_policy_save), the billing rules the dashboard's Settings → Billing rules and the
-- floor app's Billing rules screen write: the settings permission; the whole policy overwritten,
-- read from inside `policy` (a retired group_billing_mode key is ignored); a 'Default' row created when the arena has none,
-- else the oldest active row updated; a missing or bad field refused with nothing written; the
-- new rules in the pricing snapshot and the previous price list retired; replays and other
-- arenas untouched.
begin;
create extension if not exists pgtap;
select * from no_plan();

insert into arenas(id, name) values
  ('e0000000-0000-4000-8000-000000000210'::uuid, 'pgtap 21'),
  ('e0000000-0000-4000-8000-000000000211'::uuid, 'pgtap 21 neighbour');
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  select '00000000-0000-0000-0000-000000000000', u.id::uuid, 'authenticated', 'authenticated',
         u.email, '', now(), now(), now(), '{}', '{}', false, false
    from (values
      ('21000000-0000-0000-0000-000000000001', 'owner21@test.local'),
      ('21000000-0000-0000-0000-000000000002', 'manager21@test.local'),
      ('21000000-0000-0000-0000-000000000003', 'staff21@test.local')) u(id, email)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000210','21000000-0000-0000-0000-000000000001','Owner','owner',
    _known_perms(), true),
  -- Owner level for the dashboard (money, reports) but without settings.
  ('e0000000-0000-4000-8000-000000000210','21000000-0000-0000-0000-000000000002','Manager','staff',
    array['money','reports'], true),
  ('e0000000-0000-4000-8000-000000000210','21000000-0000-0000-0000-000000000003','Staff','staff',
    array['start','bill'], true);
-- The neighbour's own rules, to prove a save never reaches them.
insert into billing_policies(arena_id, name, billing_unit, grace_minutes)
  values ('e0000000-0000-4000-8000-000000000211', 'Default', 'block_60', 15);

create function pg_temp.as_user(p_uid text) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid, 'role', 'authenticated')::text, true) $$ language sql;
create function pg_temp.push(p jsonb, p_op uuid default gen_random_uuid()) returns jsonb as $$
  select sync_push('e0000000-0000-4000-8000-000000000210'::uuid,
    jsonb_build_array(jsonb_build_object('op_id', p_op, 'kind', 'policy.save', 'payload', p)),
    'pgtap') -> 'results' -> 0 $$ language sql;
-- Every field, as both apps send it, with `changes` on top.
create function pg_temp.policy(changes jsonb default '{}') returns jsonb as $$
  select jsonb_build_object('policy', '{"billing_unit":"block_15","block_rounding":"nearest",
    "grace_minutes":5,"minimum_charge_minutes":30,"early_exit":"planned","rounding_scope":"segment",
    "late_arrival":"planned","vr_unit_rounding":"prorate","money_rounding_paise":500,
    "money_rounding_dir":"up","payment_timing":"end","allow_extend_past_close":true,
    "cleaning_gap_minutes":10}'::jsonb || changes)
  $$ language sql;
create function pg_temp.saved() returns jsonb as $$
  select to_jsonb(p) - array['id','arena_id','name','active','created_at','updated_at','sync_xid']
    from billing_policies p
   where arena_id = 'e0000000-0000-4000-8000-000000000210' and active
   order by created_at limit 1 $$ language sql;
create function pg_temp.history() returns int as $$
  select count(*)::int from pricing_catalog_history
   where arena_id = 'e0000000-0000-4000-8000-000000000210' $$ language sql;

-- ------------------------------------------------ 1. permission
select is((select count(*)::int from billing_policies
    where arena_id = 'e0000000-0000-4000-8000-000000000210'), 0,
  'the arena starts without a policy row (the server prices on its defaults)');
select pg_temp.as_user('21000000-0000-0000-0000-000000000003');
select is(pg_temp.push(pg_temp.policy())->>'error', 'forbidden',
  'staff without settings cannot change the billing rules');
select pg_temp.as_user('21000000-0000-0000-0000-000000000002');
select is(pg_temp.push(pg_temp.policy())->>'error', 'forbidden',
  'nor can an owner-level manager without settings (the dashboard shows it read-only)');
select is((select count(*)::int from billing_policies
    where arena_id = 'e0000000-0000-4000-8000-000000000210'), 0, 'and nothing was written');

-- ------------------------------------------------ 2. the first save
select pg_temp.as_user('21000000-0000-0000-0000-000000000001');
create temp table snapshot_before as
  select _pricing_snapshot('e0000000-0000-4000-8000-000000000210'::uuid)->'policy' as policy;
select is((select policy->>'billing_unit' from snapshot_before), 'per_minute',
  'before any save the snapshot carries the defaults');
create temp table op1 as select gen_random_uuid() as id;
select is(pg_temp.push(pg_temp.policy(), (select id from op1))->>'status', 'applied',
  'the owner saves the billing rules');
select results_eq(
  $$ select name, active from billing_policies
      where arena_id = 'e0000000-0000-4000-8000-000000000210' $$,
  $$ values ('Default', true) $$, 'a Default policy row is created for the arena');
select is(pg_temp.saved(), pg_temp.policy()->'policy',
  'every field is stored as sent (read from inside policy)');
select is(_pricing_snapshot('e0000000-0000-4000-8000-000000000210'::uuid)->'policy',
  pg_temp.policy()->'policy', 'new sessions are priced on the new rules (pricing snapshot)');
select is(pg_temp.history(), 1, 'the previous price list is retired, so a session priced on it still validates');
select ok(exists(select 1 from pricing_catalog_history
    where arena_id = 'e0000000-0000-4000-8000-000000000210'
      and canon->'policy'->>'billing_unit' = 'per_minute'), '... with the old rules in it');

-- ------------------------------------------------ 3. replay and no-op
select is(pg_temp.push(pg_temp.policy(), (select id from op1))->>'replayed', 'true',
  'the same op id replays its answer');
select is(pg_temp.push(pg_temp.policy())->>'status', 'applied', 'saving the same rules again is fine');
select is(pg_temp.history(), 1, '... and retires nothing (the price list did not change)');

-- ------------------------------------------------ 4. a retired key from an older client
select is(pg_temp.push(pg_temp.policy(jsonb_build_object('group_billing_mode', 'shared_controller_pool')))
    ->>'status', 'applied', 'a policy still carrying group_billing_mode is accepted ...');
select is(pg_temp.saved(), pg_temp.policy()->'policy', '... and the key is ignored');

-- ------------------------------------------------ 5. refusals write nothing
select is(pg_temp.push(pg_temp.policy())->>'status', 'applied', 'back to the full rules');
create temp table before_refusals as select pg_temp.saved() as p;
select is(pg_temp.push(pg_temp.policy() #- '{policy,billing_unit}')->>'error', 'invalid',
  'a policy missing a field is refused (every field is overwritten)');
select is(pg_temp.push(pg_temp.policy('{"billing_unit":"block_7"}'))->>'error', 'invalid',
  'an unknown billing unit is refused');
select is(pg_temp.push(pg_temp.policy('{"money_rounding_dir":"down"}'))->>'error', 'invalid',
  'an unknown rounding direction is refused');
select is(pg_temp.push(pg_temp.policy('{"grace_minutes":"five"}'))->>'error', 'invalid_payload',
  'a grace period that is not a number is refused');
select is(pg_temp.push('{}'::jsonb)->>'error', 'invalid', 'a payload without policy is refused');
select is(pg_temp.saved(), (select p from before_refusals), 'and none of the refused saves changed the rules');

-- ------------------------------------------------ 6. the oldest active row is the live one
insert into billing_policies(arena_id, name, created_at, billing_unit)
  values ('e0000000-0000-4000-8000-000000000210', 'Later', now() + interval '1 hour', 'block_30');
select is(pg_temp.push(pg_temp.policy('{"grace_minutes":15}'))->>'status', 'applied',
  'with two active rows the save still applies');
select is(pg_temp.saved()->>'grace_minutes', '15', 'the oldest active row (the live one) is updated');
select results_eq(
  $$ select billing_unit, grace_minutes from billing_policies
      where arena_id = 'e0000000-0000-4000-8000-000000000210' and name = 'Later' $$,
  $$ values ('block_30', 0) $$, 'the newer row is left alone');

-- ------------------------------------------------ 7. other arenas
select results_eq(
  $$ select billing_unit, grace_minutes from billing_policies
      where arena_id = 'e0000000-0000-4000-8000-000000000211' $$,
  $$ values ('block_60', 15) $$, 'the neighbour arena''s rules are untouched');
select throws_ok(
  $$ select sync_push('e0000000-0000-4000-8000-000000000211'::uuid,
       jsonb_build_array(jsonb_build_object('op_id', gen_random_uuid(), 'kind', 'policy.save',
         'payload', pg_temp.policy())), 'pgtap') $$,
  '42501', 'forbidden', 'the owner cannot save rules in an arena they are not a member of');

select * from finish();
rollback;
