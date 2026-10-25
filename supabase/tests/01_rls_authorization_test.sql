-- Owner vs staff authorization, enforced on the backend.
--
-- Since 0012 there is exactly one client write path — sync_push — so this file
-- checks the other half: members can READ their arena (RLS), nobody (owner
-- included) can WRITE a table directly, the retired pre-sync RPCs are not
-- executable by clients, and non-members see nothing. Op-level permissions are
-- in 07/10/11.
--
-- Note: function grants are asserted with has_function_privilege rather than by
-- calling a revoked function under SET ROLE: in the local Supabase image a
-- superuser session that SET ROLEs to a supautils hint role (anon/authenticated)
-- and hits "permission denied for function" crashes the backend. The same call
-- through PostgREST returns a clean 403 (verified), so this is a test-harness
-- concern, not a production one.
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated fixture: this file works in its OWN arena (the same starter catalog
-- seed.sql uses), so whatever else is in the database — the dev seed, arenas
-- left by the two-device suite, a half-finished run — cannot change what it
-- sees. Created inside this transaction and rolled back with it.
insert into arenas(id, name) values ('e0000000-0000-4000-8000-000000000001'::uuid, 'pgtap 01');
select _seed_arena_catalog('e0000000-0000-4000-8000-000000000001'::uuid);

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,
    email_confirmed_at,created_at,updated_at,raw_app_meta_data,raw_user_meta_data,
    is_sso_user,is_anonymous)
  values ('00000000-0000-0000-0000-000000000000','11111111-1111-1111-1111-111111111111',
      'authenticated','authenticated','owner@test.local','',now(),now(),now(),'{}','{}',false,false),
    ('00000000-0000-0000-0000-000000000000','22222222-2222-2222-2222-222222222222',
      'authenticated','authenticated','staff@test.local','',now(),now(),now(),'{}','{}',false,false),
    ('00000000-0000-0000-0000-000000000000','33333333-3333-3333-3333-333333333333',
      'authenticated','authenticated','x3@test.local','',now(),now(),now(),'{}','{}',false,false)
  on conflict (id) do nothing;
insert into staff_profiles(arena_id,user_id,name,role,perms,active) values
  ('e0000000-0000-4000-8000-000000000001'::uuid,'11111111-1111-1111-1111-111111111111'::uuid,'Owner','owner',
    array['start','bill','discount','members','stations','money','reports','settings'],true),
  ('e0000000-0000-4000-8000-000000000001'::uuid,'22222222-2222-2222-2222-222222222222'::uuid,'Staff','staff',
    array['start','bill','discount','members'],true);

-- ===================== grants (no role switch needed) =====================
select ok(not has_table_privilege('authenticated', 'public.' || t, 'INSERT')
       and not has_table_privilege('authenticated', 'public.' || t, 'UPDATE')
       and not has_table_privilege('authenticated', 'public.' || t, 'DELETE'),
  'no direct client writes on ' || t)
from unnest(array[
  'arenas','staff_profiles','activities','resources','resource_activities','controllers',
  'customers','rate_cards','rate_bands','rates','billing_policies','holidays',
  'game_categories','games','game_controls','game_resources','bookings','settings',
  'sessions','session_segments','session_extensions','session_charges','payments',
  'controller_allocations','controller_moves','audit_log']) t;

select ok(not has_function_privilege('authenticated', f, 'EXECUTE'),
  'internal function not client-executable: ' || f)
from unnest(array['op_session_start(uuid,jsonb)', '_sync_apply(uuid,text,jsonb)']) f;

-- The pre-sync RPCs (0003–0009) are retired and dropped: their guarantees are
-- asserted through sync_push in 11/12. The *_v1 bodies that 0013/0016 wrapped
-- are folded into their op_* functions and dropped too.
select hasnt_function('public', f, 'retired function is gone: ' || f)
from unnest(array[
  'start_session', 'end_session', 'extend_session', 'reconfigure_session', 'void_session',
  'record_payment', 'create_group', 'add_assignment', 'end_assignment', 'switch_assignment',
  'end_group', 'extend_group', 'void_group', 'record_group_payment', 'allocate_controllers',
  'release_controllers', 'borrow_controllers', 'move_controller', 'assert_group_colocation_ok',
  'claim_arena', 'create_arena', 'app_owner_arena_ids', '_group_arena_active',
  '_op_session_start_v1', '_op_session_extend_v1', '_op_session_end_v1', '_op_group_create_v1',
  '_op_group_end_v1', '_op_group_extend_v1', '_op_payment_v1', '_op_resource_upsert_v1',
  '_op_staff_update_v1', '_op_controller_move_v1', '_sync_apply_v1']) f;

select ok(has_function_privilege('authenticated', f, 'EXECUTE'), 'client API: ' || f)
from unnest(array['sync_push(uuid,jsonb,text)', 'sync_pull(uuid,text,integer)',
  'sync_fetch_entity(uuid,jsonb)', 'my_arenas()',
  'invite_member(uuid,text,text,text,text[])', 'create_my_arena(text,text)',
  'arena_staff(uuid)', 'accept_invite(uuid,text)', 'revoke_invite(uuid,uuid)', 'arena_invites(uuid)',
  'arena_sales(uuid,timestamptz,timestamptz)', 'arena_sale(uuid,uuid)', 'arena_pricing(uuid)']) f;
-- The only app route to ownership is create_my_arena (confirmed login, one arena
-- each); the operator tool and the shared body stay server-only.
select ok(not has_function_privilege('authenticated', f, 'EXECUTE'), 'not client API: ' || f)
from unnest(array['bootstrap_owner(text,text,text)', '_create_arena_with_owner(uuid,text,text)',
  '_sales(uuid,timestamptz,timestamptz,uuid)']) f;

-- my_arenas included: a 42501 on it means the app called without a sign-in
-- (refused refresh → publishable key only); the fix is the app, never a grant.
select ok(not has_function_privilege('anon', f, 'EXECUTE'), 'anon cannot call ' || f)
from unnest(array['sync_push(uuid,jsonb,text)', 'sync_pull(uuid,text,integer)',
  'bootstrap_owner(text,text,text)', 'create_my_arena(text,text)', 'my_arenas()']) f;

-- ===================== as STAFF (reads) =====================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is((select count(*)::int from rates), 7, 'staff can READ config (rates)');
select is((select count(*)::int from staff_profiles), 2, 'staff can READ the roster');
select throws_ok($$ insert into customers(arena_id,name) values ('e0000000-0000-4000-8000-000000000001'::uuid,'x') $$,
  '42501', NULL, 'staff CANNOT insert a customer directly (sync_push only)');
reset role;
select set_config('request.jwt.claims','', true);

-- ===================== as OWNER (reads, no direct writes) =====================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select throws_ok($$
  insert into rates(arena_id,rate_card_id,activity_id,band_id,unit_minutes,price_paise)
    select 'e0000000-0000-4000-8000-000000000001'::uuid, rc.id, a.id, b.id, 60, 9900
    from rate_cards rc, activities a, rate_bands b
    where a.code='LOUNGE' and b.code='standard' limit 1 $$,
  '42501', NULL, 'even an owner CANNOT write config directly (sync_push only)');
select throws_ok($$
  insert into staff_profiles(arena_id,user_id,name,role,perms)
    values ('e0000000-0000-4000-8000-000000000001'::uuid,'33333333-3333-3333-3333-333333333333','X','staff','{}') $$,
  '42501', NULL, 'even an owner CANNOT insert staff_profiles directly');
select throws_ok($$ delete from sessions where arena_id='e0000000-0000-4000-8000-000000000001'::uuid $$,
  '42501', NULL, 'nobody can delete sessions (append-only)');
reset role;
select set_config('request.jwt.claims','', true);

-- ===================== as NON-MEMBER =====================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"99999999-9999-9999-9999-999999999999","role":"authenticated"}', true);
select is((select count(*)::int from sessions), 0, 'non-member sees no sessions');
select is((select count(*)::int from rates), 0, 'non-member sees no config');
select is((select count(*)::int from staff_profiles), 0, 'non-member sees no roster');
reset role;
select set_config('request.jwt.claims','', true);

select * from finish();
rollback;
