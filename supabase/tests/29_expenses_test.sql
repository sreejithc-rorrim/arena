-- Expenses (owner dashboard): what the arena owes and pays outside customer bills.
--   * categories are per arena (unique name in any case); a used one is retired, an unused one
--     deleted; a retired one takes no new expenses but its expenses stay editable;
--   * an expense needs a title, an amount from 1 paise to ₹1 crore, a date, and a category
--     (cost) or a staff member and period of at most 62 days (salary, dated its last day);
--     one active salary per person per day; a voided period can be recorded again;
--   * payments never exceed what is owed, whatever their source; an advance is a payment
--     before the period ends; a replayed op or a reused payment id never pays twice;
--   * each payment is from the company account (names nobody) or personal money (names an
--     active owner of this arena), and one expense can mix both;
--   * a reversal mirrors its payment (source, payer, method, day; table trigger backstop) and
--     a payment is reversed once; payments are never edited or deleted;
--   * a void needs a reason and, when money was paid, reverse_payments; repeating it is a no-op;
--   * edits, reversals, voids and agreed salaries are audited (only what changed on an edit);
--   * a money holder who is not an owner cannot record, pay, edit or void their own salary;
--   * only money holders of the arena read or write any of it (RPCs and RLS), and the audit
--     log's expense and salary rows are hidden from reports-only members.
-- All writes go through the only client write path (sync_push → op_expense_*).
begin;
create extension if not exists pgtap;
select * from no_plan();

-- Isolated fixture: arena A (this file's) and arena B, rolled back with the transaction.
insert into arenas(id, name) values
  ('e0000000-0000-4000-8000-000000000290'::uuid, 'pgtap 29'),
  ('e0000000-0000-4000-8000-000000000291'::uuid, 'pgtap 29 other');
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
    created_at,updated_at,raw_app_meta_data,raw_user_meta_data,is_sso_user,is_anonymous)
  select '00000000-0000-0000-0000-000000000000', ('29000000-0000-4000-8000-00000000000' || n)::uuid,
    'authenticated', 'authenticated', 'user' || n || '@pgtap29.test', '', now(), now(), now(),
    '{}', '{}', false, false
    from generate_series(1, 7) n
  on conflict (id) do nothing;
-- 1 Asha and 2 Bina own A; 3 Mira holds money; 4 Ravi works the floor; 5 Rina reads reports;
-- 6 Omar owns B; 7 was removed from A.
insert into staff_profiles(id, arena_id, user_id, name, role, perms, active, removed_at) values
  ('5a290000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000290',
    '29000000-0000-4000-8000-000000000001', 'Asha', 'owner', _known_perms(), true, null),
  ('5a290000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000290',
    '29000000-0000-4000-8000-000000000002', 'Bina', 'owner', _known_perms(), true, null),
  ('5a290000-0000-4000-8000-000000000003', 'e0000000-0000-4000-8000-000000000290',
    '29000000-0000-4000-8000-000000000003', 'Mira', 'staff', array['money'], true, null),
  ('5a290000-0000-4000-8000-000000000004', 'e0000000-0000-4000-8000-000000000290',
    '29000000-0000-4000-8000-000000000004', 'Ravi', 'staff', array['start', 'bill'], true, null),
  ('5a290000-0000-4000-8000-000000000005', 'e0000000-0000-4000-8000-000000000290',
    '29000000-0000-4000-8000-000000000005', 'Rina', 'staff', array['reports'], true, null),
  ('5a290000-0000-4000-8000-000000000006', 'e0000000-0000-4000-8000-000000000291',
    '29000000-0000-4000-8000-000000000006', 'Omar', 'owner', _known_perms(), true, null),
  ('5a290000-0000-4000-8000-000000000007', 'e0000000-0000-4000-8000-000000000290',
    '29000000-0000-4000-8000-000000000007', 'Deleted member', 'staff', array['start'], false, now());
-- An audit row that is not an expense's, for the reports-only read below.
insert into audit_log(arena_id, entity_type, entity_id, action, reason)
  values ('e0000000-0000-4000-8000-000000000290', 'session', gen_random_uuid(), 'void', 'pgtap');

create function pg_temp.as_user(p_n int) returns void as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', '29000000-0000-4000-8000-00000000000' || p_n, 'role', 'authenticated')::text, true)
$$ language sql;
-- Ids: sp = staff profile, e = expense, c = category, f = payment, r = reversal.
create function pg_temp.sp(p_n int) returns uuid as $$
  select case when p_n is not null then ('5a290000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid end $$ language sql;
create function pg_temp.e(p_n int) returns uuid as $$
  select ('ee290000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$ language sql;
create function pg_temp.c(p_n int) returns uuid as $$
  select ('ca290000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$ language sql;
create function pg_temp.f(p_n int) returns uuid as $$
  select ('fa290000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$ language sql;
create function pg_temp.r(p_n int) returns uuid as $$
  select ('fb290000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$ language sql;
create function pg_temp.op(p_arena text, p_op uuid, p_kind text, p jsonb) returns jsonb as $$
  select sync_push(p_arena::uuid,
    jsonb_build_array(jsonb_build_object('op_id', p_op, 'kind', p_kind, 'payload', p)),
    'pgtap') -> 'results' -> 0 $$ language sql;
create function pg_temp.push(p_kind text, p jsonb) returns jsonb as $$
  select pg_temp.op('e0000000-0000-4000-8000-000000000290', gen_random_uuid(), p_kind, p) $$ language sql;
create function pg_temp.err(p_kind text, p jsonb) returns text as $$
  select pg_temp.push(p_kind, p) ->> 'error' $$ language sql;
create function pg_temp.payment(p_id uuid, p_amount bigint, p_from text, p_payer int, p_on text,
    p_method text) returns jsonb as $$
  select jsonb_build_object('payment_id', coalesce(p_id, gen_random_uuid()), 'amount_paise', p_amount,
    'method', p_method, 'paid_on', p_on, 'paid_from', p_from, 'payer_staff_id', pg_temp.sp(p_payer)) $$ language sql;
create function pg_temp.pay(p_exp uuid, p_id uuid, p_amount bigint, p_from text, p_payer int,
    p_on text, p_method text) returns jsonb as $$
  select pg_temp.push('expense.pay', jsonb_build_object('expense_id', p_exp)
    || pg_temp.payment(p_id, p_amount, p_from, p_payer, p_on, p_method)) $$ language sql;
-- A valid cost (Rent, ₹10) that is never written, changed by p to probe one refusal.
create function pg_temp.cost(p jsonb) returns jsonb as $$
  select jsonb_build_object('expense_id', pg_temp.e(255), 'kind', 'general', 'category_id', pg_temp.c(1),
    'title', 'Test', 'amount_paise', 1000, 'expense_date', '2026-10-01') || p $$ language sql;
create function pg_temp.salary(p_id uuid, p_staff int, p_from text, p_to text, p_amount bigint)
  returns jsonb as $$
  select jsonb_build_object('expense_id', p_id, 'kind', 'salary', 'staff_id', pg_temp.sp(p_staff),
    'period_start', p_from, 'period_end', p_to, 'title', 'Salary', 'amount_paise', p_amount) $$ language sql;
-- The rent (expense 2) as the edit form sends it, changed by p.
create function pg_temp.rent(p jsonb) returns jsonb as $$
  select jsonb_build_object('expense_id', pg_temp.e(2), 'category_id', pg_temp.c(1),
    'title', 'Rent October', 'amount_paise', 4000000, 'expense_date', '2026-10-01') || p $$ language sql;
create function pg_temp.paid(p_exp uuid) returns bigint as $$
  select coalesce(sum(amount_paise), 0)::bigint from expense_payments where expense_id = p_exp $$ language sql;
create function pg_temp.list() returns jsonb as $$
  select private.arena_expenses('e0000000-0000-4000-8000-000000000290'::uuid, '2026-09-01', '2026-10-31') $$ language sql;

-- ---------------------------------------------------------------- categories
select is(jsonb_array_length(expense_category_catalog()), 10, 'the catalog offers ten standard categories');
select pg_temp.as_user(1);
select is(pg_temp.push('expense_category.upsert', jsonb_build_object('id', pg_temp.c(1), 'name', 'Rent'))->>'status',
  'applied', 'the owner adds Rent');
select is(pg_temp.push('expense_category.upsert', jsonb_build_object('id', pg_temp.c(2), 'name', 'Electricity'))->>'status',
  'applied', 'and Electricity');
select is(pg_temp.push('expense_category.upsert', jsonb_build_object('id', pg_temp.c(4), 'name', 'Water'))->>'status',
  'applied', 'and Water');
select is(pg_temp.push('expense_category.upsert', jsonb_build_object('id', pg_temp.c(3), 'name', 'Old'))->>'status',
  'applied', 'and one more');
select is(pg_temp.err('expense_category.upsert', jsonb_build_object('id', pg_temp.c(5), 'name', 'rent')),
  'duplicate', 'a second Rent in any case is refused');
select is(pg_temp.err('expense_category.upsert', jsonb_build_object('id', pg_temp.c(5), 'name', '  ')),
  'invalid_name', 'a blank name is refused');
select is(pg_temp.push('expense_category.remove', jsonb_build_object('id', pg_temp.c(3)))->'result'->>'removed',
  'deleted', 'an unused category is deleted');
select is((select count(*)::int from expense_categories where id = pg_temp.c(3)), 0, 'and is gone');
select pg_temp.as_user(4);
select is(pg_temp.err('expense_category.upsert', jsonb_build_object('id', pg_temp.c(5), 'name', 'Snacks')),
  'forbidden', 'floor staff cannot add a category');
select pg_temp.as_user(6);
select is(pg_temp.op('e0000000-0000-4000-8000-000000000291', gen_random_uuid(), 'expense_category.upsert',
    jsonb_build_object('id', pg_temp.c(9), 'name', 'Rent'))->>'status',
  'applied', 'another arena has its own Rent');
select is(pg_temp.op('e0000000-0000-4000-8000-000000000291', gen_random_uuid(), 'expense_category.upsert',
    jsonb_build_object('id', pg_temp.c(1), 'name', 'Taken'))->>'error',
  'not_found', 'and cannot rename this arena''s');
select is((select name from expense_categories where id = pg_temp.c(1)), 'Rent', 'which keeps its name');
select is(pg_temp.op('e0000000-0000-4000-8000-000000000291', gen_random_uuid(), 'expense.add',
    jsonb_build_object('expense_id', pg_temp.e(9), 'kind', 'general', 'category_id', pg_temp.c(9),
      'title', 'Rent B', 'amount_paise', 100000, 'expense_date', '2026-10-01'))->>'status',
  'applied', 'arena B records its own rent');

-- ---------------------------------------------------------------- costs
select pg_temp.as_user(1);
select is(pg_temp.push('expense.add', jsonb_build_object('expense_id', pg_temp.e(1), 'kind', 'general',
    'category_id', pg_temp.c(2), 'title', 'Electricity October', 'amount_paise', 230000,
    'expense_date', '2026-10-05', 'notes', 'KSEB bill',
    'payment', pg_temp.payment(null, 230000, 'company', null, '2026-10-05', 'upi')))->'result'->>'payment_status',
  'paid', 'electricity ₹2,300 paid by UPI from the company account as it is added: paid');
select is(pg_temp.push('expense.add', jsonb_build_object('expense_id', pg_temp.e(2), 'kind', 'general',
    'category_id', pg_temp.c(1), 'title', 'Rent October', 'amount_paise', 4000000,
    'expense_date', '2026-10-01'))->'result'->>'payment_status',
  'unpaid', 'rent ₹40,000 added unpaid');
select is((select after->>'amount_paise' from audit_log where entity_id = pg_temp.e(2) and action = 'add'),
  '4000000', 'adding is audited');
select is(pg_temp.err('expense.add', pg_temp.cost('{"title": "  "}')), 'title_required', 'a title is required');
select is(pg_temp.err('expense.add', pg_temp.cost(jsonb_build_object('title', repeat('x', 81)))),
  'title_too_long', 'of at most 80 characters');
select is(pg_temp.err('expense.add', pg_temp.cost('{"amount_paise": 0}')), 'amount_invalid', 'a zero amount is refused');
select is(pg_temp.err('expense.add', pg_temp.cost('{"amount_paise": -500}')), 'amount_invalid', 'so is a negative one');
select is(pg_temp.err('expense.add', pg_temp.cost('{"amount_paise": 1000000001}')), 'amount_invalid',
  'and one over ₹1 crore');
select is(pg_temp.err('expense.add', pg_temp.cost('{"amount_paise": "abc"}')), 'invalid_payload',
  'and one that is not a whole number of paise');
select is(pg_temp.err('expense.add', pg_temp.cost('{"category_id": null}')), 'category_required', 'a cost needs a category');
select is(pg_temp.err('expense.add', pg_temp.cost(jsonb_build_object('category_id', pg_temp.c(9)))), 'not_found',
  'of this arena');
select is(pg_temp.err('expense.add', pg_temp.cost('{"expense_date": null}')), 'date_required', 'and a date');
select is(pg_temp.err('expense.add', pg_temp.cost('{"expense_date": "2099-01-01"}')), 'date_out_of_range',
  'no more than a year ahead');
select is(pg_temp.err('expense.add', pg_temp.cost('{"kind": "loan"}')), 'invalid_kind', 'a cost or a salary only');
select is(pg_temp.err('expense.add', pg_temp.cost(jsonb_build_object('notes', repeat('n', 1001)))), 'notes_too_long',
  'notes of at most 1000 characters');
select is((select count(*)::int from expenses where id = pg_temp.e(255)), 0, 'a refused expense writes nothing');

-- ---------------------------------------------------------------- payments and sources
select is(pg_temp.pay(pg_temp.e(2), pg_temp.f(1), 1500000, 'personal', 1, '2026-10-02', 'upi')->'result'->>'payment_status',
  'partial', 'Asha pays ₹15,000 of the rent from her own money: part paid');
select is(pg_temp.pay(pg_temp.e(2), null, 3000000, 'company', null, '2026-10-03', 'cash')->>'error',
  'overpayment', 'paying ₹30,000 more is refused');
select is(pg_temp.pay(pg_temp.e(2), null, 3000000, 'company', null, '2026-10-03', 'cash')->>'detail',
  'only ₹25000.00 is due', 'with what is still due');
select is(pg_temp.pay(pg_temp.e(2), null, 1000, 'company', 1, '2026-10-03', 'cash')->>'error',
  'payer_not_allowed', 'a company payment names nobody');
select is(pg_temp.pay(pg_temp.e(2), null, 1000, 'personal', null, '2026-10-03', 'cash')->>'error',
  'payer_required', 'a personal payment names who paid');
select is(pg_temp.pay(pg_temp.e(2), null, 1000, 'personal', 4, '2026-10-03', 'cash')->>'error',
  'payer_not_owner', 'and that is an owner, not staff');
select is(pg_temp.pay(pg_temp.e(2), null, 1000, 'personal', 7, '2026-10-03', 'cash')->>'error',
  'payer_not_owner', 'or a removed member');
select is(pg_temp.pay(pg_temp.e(2), null, 1000, 'personal', 6, '2026-10-03', 'cash')->>'error',
  'not_found', 'or another arena''s owner');
select is(pg_temp.pay(pg_temp.e(2), null, 1000, 'friend', null, '2026-10-03', 'cash')->>'error',
  'invalid_paid_from', 'money comes from the company or personally');
select is(pg_temp.pay(pg_temp.e(2), null, 1000, 'company', null, '2026-10-03', 'cheque')->>'error',
  'invalid_method', 'by cash, UPI, card, bank or other');
select is(pg_temp.pay(pg_temp.e(2), null, 1000, 'company', null, (_pr_ist_date(now()) + 1)::text, 'cash')->>'error',
  'date_in_future', 'not dated tomorrow');
select is(pg_temp.pay(pg_temp.e(2), null, 1000, 'company', null, '1999-12-31', 'cash')->>'error',
  'date_out_of_range', 'or before 2000');
select is(pg_temp.pay(pg_temp.e(2), null, 0, 'company', null, '2026-10-03', 'cash')->>'error',
  'amount_zero', 'a zero payment is refused');
select is(pg_temp.pay(pg_temp.e(2), null, -100, 'company', null, '2026-10-03', 'cash')->>'error',
  'amount_negative', 'so is a negative one');
select is(pg_temp.err('expense.pay', jsonb_build_object('expense_id', pg_temp.e(2))
    || pg_temp.payment(null, 1000, 'company', null, '2026-10-03', 'cash') || jsonb_build_object('note', repeat('n', 201))),
  'note_too_long', 'a note of at most 200 characters');
select is(pg_temp.err('expense.pay', jsonb_build_object('expense_id', pg_temp.e(2))
    || pg_temp.payment(null, 1000, 'company', null, '2026-10-03', 'cash') || '{"payment_id": null}'),
  'invalid_payload', 'a payment carries its own id');
select is(pg_temp.paid(pg_temp.e(2)), 1500000::bigint, 'refused payments pay nothing');

select is(pg_temp.op('e0000000-0000-4000-8000-000000000290', 'a0290000-0000-4000-8000-000000000001', 'expense.pay',
    jsonb_build_object('expense_id', pg_temp.e(2))
      || pg_temp.payment(pg_temp.f(2), 500000, 'company', null, '2026-10-03', 'cash'))->>'status',
  'applied', 'a ₹5,000 company payment');
select is(pg_temp.op('e0000000-0000-4000-8000-000000000290', 'a0290000-0000-4000-8000-000000000001', 'expense.pay',
    jsonb_build_object('expense_id', pg_temp.e(2))
      || pg_temp.payment(pg_temp.f(2), 500000, 'company', null, '2026-10-03', 'cash'))->>'replayed',
  'true', 'sent again is replayed');
select is(pg_temp.pay(pg_temp.e(2), pg_temp.f(2), 500000, 'company', null, '2026-10-03', 'cash')->>'error',
  'duplicate', 'and a new op reusing its payment id is refused');
select is(pg_temp.paid(pg_temp.e(2)), 2000000::bigint, 'so it is counted once');

-- ---------------------------------------------------------------- edits
select is(pg_temp.err('expense.update', pg_temp.rent('{"amount_paise": 1900000}')), 'amount_below_paid',
  'the amount cannot drop below what is paid');
select is(pg_temp.push('expense.update', pg_temp.rent('{"amount_paise": 4500000, "notes": "with maintenance"}'))
    ->'result'->>'payment_status',
  'partial', 'the owner corrects the rent to ₹45,000');
select is((select before from audit_log where entity_id = pg_temp.e(2) and action = 'update'),
  '{"amount_paise": 4000000, "notes": null}'::jsonb, 'the edit is audited with only what changed: before');
select is((select after from audit_log where entity_id = pg_temp.e(2) and action = 'update'),
  '{"amount_paise": 4500000, "notes": "with maintenance"}'::jsonb, 'and after');
select is(pg_temp.push('expense.update', pg_temp.rent('{"amount_paise": 4500000, "notes": "with maintenance"}'))->>'status',
  'applied', 'saving it unchanged');
select is((select count(*)::int from audit_log where entity_id = pg_temp.e(2) and action = 'update'), 1,
  'writes no second audit row');
select is(pg_temp.err('expense.update', pg_temp.rent(jsonb_build_object('expense_id', pg_temp.e(255)))), 'not_found',
  'an unknown expense cannot be edited');

-- ---------------------------------------------------------------- agreed salary
select is(pg_temp.push('staff_salary.set', jsonb_build_object('staff_id', pg_temp.sp(4),
    'effective_from', '2026-09-01', 'period', 'monthly', 'amount_paise', 1700000))->>'status',
  'applied', 'Ravi''s agreed salary is ₹17,000 a month from September');
select is(pg_temp.push('staff_salary.set', jsonb_build_object('staff_id', pg_temp.sp(4),
    'effective_from', '2026-09-01', 'period', 'monthly', 'amount_paise', 1800000))->>'status',
  'applied', 'setting the same day again corrects it');
select is((select count(*)::int from staff_salaries where staff_id = pg_temp.sp(4)), 1, 'without a second row');
select is((select (before->>'amount_paise') || '>' || (after->>'amount_paise') from audit_log
            where entity_type = 'staff_salary' and action = 'update'),
  '1700000>1800000', 'and the correction is audited');
select is(pg_temp.push('staff_salary.set', jsonb_build_object('staff_id', pg_temp.sp(4),
    'effective_from', '2026-10-01', 'period', 'monthly', 'amount_paise', 1850000))->>'status',
  'applied', 'a raise from October is a new row');
select is(pg_temp.err('staff_salary.set', jsonb_build_object('staff_id', pg_temp.sp(7),
    'effective_from', '2026-10-01', 'period', 'monthly', 'amount_paise', 1000000)),
  'staff_removed', 'a removed member gets no new salary');
select is(pg_temp.err('staff_salary.set', jsonb_build_object('staff_id', pg_temp.sp(4),
    'effective_from', '2026-10-01', 'period', 'daily', 'amount_paise', 1000000)),
  'invalid_salary_period', 'salaries are monthly or weekly');
select is(pg_temp.err('staff_salary.set', jsonb_build_object('staff_id', pg_temp.sp(4),
    'effective_from', '2026-10-01', 'period', 'monthly', 'amount_paise', 0)),
  'amount_invalid', 'and more than ₹0');
select is(pg_temp.err('staff_salary.set', jsonb_build_object(
    'effective_from', '2026-10-01', 'period', 'monthly', 'amount_paise', 1000000)),
  'staff_required', 'for someone');

-- ---------------------------------------------------------------- salary periods
select is(pg_temp.push('expense.add', pg_temp.salary(pg_temp.e(3), 4, '2026-09-01', '2026-09-30', 1800000))
    ->'result'->>'payment_status',
  'unpaid', 'Ravi''s September salary of ₹18,000 is recorded');
select is((select expense_date::text from expenses where id = pg_temp.e(3)), '2026-09-30',
  'dated the last day of the period');
select is(pg_temp.err('expense.add', pg_temp.salary(pg_temp.e(255), 4, '2026-09-15', '2026-10-14', 1800000)),
  'salary_period_taken', 'a period overlapping September is refused');
select is(pg_temp.err('expense.add', pg_temp.salary(pg_temp.e(255), 4, '2026-10-31', '2026-10-01', 1800000)),
  'invalid_period', 'a period ending before it starts is refused');
select is(pg_temp.err('expense.add', pg_temp.salary(pg_temp.e(255), 4, '2026-01-01', '2026-03-31', 1800000)),
  'invalid_period', 'so is one longer than 62 days');
select is(pg_temp.err('expense.add', pg_temp.salary(pg_temp.e(255), 4, '2026-08-01', null, 1800000)),
  'period_required', 'a salary needs its period');
select is(pg_temp.err('expense.add', pg_temp.salary(pg_temp.e(255), null, '2026-08-01', '2026-08-31', 1800000)),
  'staff_required', 'and its person');
select is(pg_temp.err('expense.add', pg_temp.salary(pg_temp.e(255), 6, '2026-08-01', '2026-08-31', 1800000)),
  'not_found', 'of this arena');
select is(pg_temp.err('expense.add', pg_temp.salary(pg_temp.e(255), 7, '2026-08-01', '2026-08-31', 1800000)),
  'staff_removed', 'still on the team');

select is(pg_temp.pay(pg_temp.e(3), pg_temp.f(3), 1000000, 'company', null, '2026-09-30', 'cash')->'result'->>'payment_status',
  'partial', '₹10,000 of it from the company account');
select is(pg_temp.pay(pg_temp.e(3), pg_temp.f(4), 800000, 'personal', 2, '2026-10-01', 'upi')->'result'->>'payment_status',
  'paid', 'and ₹8,000 from Bina''s own money: paid');
select is((select jsonb_build_object('paid', j->'paid_paise', 'company', j->'paid_company_paise',
            'personal', j->'paid_personal_paise', 'balance', j->'balance_paise')
             from (select _expense_json(pg_temp.e(3)) j) x),
  '{"paid": 1800000, "company": 1000000, "personal": 800000, "balance": 0}'::jsonb,
  '₹18,000 paid = ₹10,000 company + ₹8,000 personal, nothing due');
select is((select p->>'payer_name' from jsonb_array_elements(_expense_json(pg_temp.e(3))->'payments') p
            where p->>'id' = pg_temp.f(4)::text),
  'Bina', 'the personal payment names Bina');
select is(pg_temp.pay(pg_temp.e(3), null, 100, 'company', null, '2026-10-01', 'cash')->>'detail',
  'this expense is already paid', 'a paid salary takes no more');

select is(pg_temp.push('expense.add', pg_temp.salary(pg_temp.e(4), 4, '2026-10-01', '2026-10-31', 1850000)
    || jsonb_build_object('payment', pg_temp.payment(null, 500000, 'company', null, '2026-10-10', 'cash')))
    ->'result'->>'payment_status',
  'partial', 'October''s ₹18,500 is recorded with a ₹5,000 advance paid on the 10th');
select ok((select bool_and(p.paid_on < e.period_end) from expense_payments p join expenses e on e.id = p.expense_id
            where e.id = pg_temp.e(4)),
  'the advance is paid before the period ends');
select is(pg_temp.err('expense.update', pg_temp.salary(pg_temp.e(4), 4, '2026-09-15', '2026-10-31', 1850000)),
  'salary_period_taken', 'October cannot be stretched over September');
select is(pg_temp.push('expense.update', pg_temp.salary(pg_temp.e(4), 4, '2026-10-01', '2026-10-31', 1850000)
    || '{"notes": "night shift"}')->>'status',
  'applied', 'but its own period is no clash with itself');

-- ---------------------------------------------------------------- own salary
select pg_temp.as_user(3);
select is(pg_temp.err('expense.add', pg_temp.salary(pg_temp.e(5), 3, '2026-09-01', '2026-09-30', 2000000)),
  'own_record', 'Mira (money, not an owner) cannot record her own salary');
select is(pg_temp.err('staff_salary.set', jsonb_build_object('staff_id', pg_temp.sp(3),
    'effective_from', '2026-09-01', 'period', 'monthly', 'amount_paise', 2000000)),
  'own_record', 'or set it');
select is(pg_temp.push('expense.add', jsonb_build_object('expense_id', pg_temp.e(6), 'kind', 'general',
    'category_id', pg_temp.c(4), 'title', 'Water cans', 'amount_paise', 50000, 'expense_date', '2026-10-06',
    'payment', pg_temp.payment(null, 50000, 'company', null, '2026-10-06', 'upi')))->'result'->>'payment_status',
  'paid', 'but records the water bill');
select is(_expense_json(pg_temp.e(6))->>'created_by_name', 'Mira', 'under her name');
select pg_temp.as_user(1);
select is(pg_temp.push('expense.add', pg_temp.salary(pg_temp.e(5), 3, '2026-09-01', '2026-09-30', 2000000))->>'status',
  'applied', 'an owner records Mira''s September salary');
select is(pg_temp.pay(pg_temp.e(5), pg_temp.f(5), 700000, 'personal', 1, '2026-10-04', 'cash')->'result'->>'payment_status',
  'partial', 'and pays ₹7,000 of it personally');
select pg_temp.as_user(3);
select is(pg_temp.pay(pg_temp.e(5), null, 1000, 'company', null, '2026-10-04', 'cash')->>'error',
  'own_record', 'Mira cannot pay her own salary');
select is(pg_temp.err('expense.update', pg_temp.salary(pg_temp.e(5), 3, '2026-09-01', '2026-09-30', 2500000)),
  'own_record', 'raise it');
select is(pg_temp.err('expense.payment_reverse', jsonb_build_object('payment_id', pg_temp.f(5), 'reason', 'x')),
  'own_record', 'reverse its payments');
select is(pg_temp.err('expense.void', jsonb_build_object('expense_id', pg_temp.e(5), 'reason', 'x',
    'reverse_payments', true)),
  'own_record', 'or void it');

-- ---------------------------------------------------------------- reversals
select pg_temp.as_user(1);
select is(pg_temp.err('expense.payment_reverse', jsonb_build_object('payment_id', pg_temp.f(4))),
  'reason_required', 'a reversal needs a reason');
select is(pg_temp.push('expense.payment_reverse', jsonb_build_object('payment_id', pg_temp.f(4),
    'reversal_id', pg_temp.r(4), 'reason', 'Paid twice by mistake'))->'result'->>'payment_status',
  'partial', 'reversing Bina''s ₹8,000 leaves the salary part paid');
select is((select jsonb_build_object('amount', amount_paise, 'from', paid_from, 'payer', payer_staff_id,
            'method', method, 'on', paid_on, 'reverses', reverses_id)
             from expense_payments where id = pg_temp.r(4)),
  jsonb_build_object('amount', -800000, 'from', 'personal', 'payer', pg_temp.sp(2), 'method', 'upi',
    'on', '2026-10-01', 'reverses', pg_temp.f(4)),
  'the reversal keeps the source, payer, method and day of the payment it undoes');
select is((_expense_json(pg_temp.e(3))->>'balance_paise')::bigint, 800000::bigint, 'so ₹8,000 is due again');
select is((select reason from audit_log where entity_id = pg_temp.e(3) and action = 'payment_reverse'),
  'Paid twice by mistake', 'the reversal is audited with its reason');
select is(pg_temp.err('expense.payment_reverse', jsonb_build_object('payment_id', pg_temp.f(4), 'reason', 'again')),
  'already_reversed', 'a payment is reversed once');
select is(pg_temp.err('expense.payment_reverse', jsonb_build_object('payment_id', pg_temp.r(4), 'reason', 'undo')),
  'not_found', 'and a reversal is not itself reversed');
select throws_ok($$ insert into expense_payments(id, arena_id, expense_id, kind, amount_paise, method, paid_on,
      paid_from, note, reverses_id)
    values (gen_random_uuid(), 'e0000000-0000-4000-8000-000000000290', pg_temp.e(3), 'reversal', -1000000,
      'upi', '2026-09-30', 'company', 'wrong method', pg_temp.f(3)) $$,
  '23514', 'reversal_mismatch', 'the table refuses a reversal that does not mirror its payment');
select throws_ok($$ update expense_payments set note = 'edited' where id = pg_temp.f(3) $$,
  '55000', 'append_only', 'payments are never edited');
select throws_ok($$ delete from expense_payments where id = pg_temp.f(3) $$,
  '55000', 'append_only', 'or deleted');

-- ---------------------------------------------------------------- voids
select is(pg_temp.err('expense.void', jsonb_build_object('expense_id', pg_temp.e(2), 'reason', 'Duplicate entry')),
  'expense_has_payments', 'an expense with payments is not voided without reversing them');
select is(pg_temp.err('expense.void', jsonb_build_object('expense_id', pg_temp.e(2), 'reverse_payments', true)),
  'void_reason_required', 'a void needs a reason');
select is(pg_temp.push('expense.void', jsonb_build_object('expense_id', pg_temp.e(2), 'reason', 'Duplicate entry',
    'reverse_payments', true))->'result',
  '{"status": "voided", "reversed": 2}'::jsonb, 'voiding the rent with its payments reverses both');
select is((select string_agg(r.paid_from || '/' || coalesce(s.name, '-') || '/' || r.amount_paise, ', '
                    order by r.amount_paise)
             from expense_payments r left join staff_profiles s on s.id = r.payer_staff_id
            where r.expense_id = pg_temp.e(2) and r.kind = 'reversal'),
  'personal/Asha/-1500000, company/-/-500000', 'each reversal keeps its payment''s source and payer');
select is(pg_temp.paid(pg_temp.e(2)), 0::bigint, 'nothing stays paid on it');
select is((select status || '/' || payment_status || '/' || void_reason from expenses where id = pg_temp.e(2)),
  'voided/unpaid/Duplicate entry', 'it is voided with its reason');
select is(pg_temp.push('expense.void', jsonb_build_object('expense_id', pg_temp.e(2), 'reason', 'Duplicate entry',
    'reverse_payments', true))->'result',
  '{"status": "voided", "reversed": 0}'::jsonb, 'voiding it again changes nothing');
select is(pg_temp.pay(pg_temp.e(2), null, 1000, 'company', null, '2026-10-03', 'cash')->>'error',
  'voided', 'a voided expense takes no payment');
select is(pg_temp.err('expense.update', pg_temp.rent('{"amount_paise": 4500000, "notes": "edit"}')),
  'voided', 'and no edit');
select is((select string_agg(h->>'action' || ' by ' || (h->>'by_name'), ', ' order by n)
             from jsonb_array_elements(private.arena_expense('e0000000-0000-4000-8000-000000000290',
               pg_temp.e(2))->'history') with ordinality as x(h, n)),
  'add by Asha, update by Asha, void by Asha', 'its history lists the add, the edit and the void');
select is(pg_temp.push('expense.add', pg_temp.salary(pg_temp.e(7), 4, '2026-11-01', '2026-11-30', 1850000))->>'status',
  'applied', 'Ravi''s November is recorded');
select is(pg_temp.push('expense.void', jsonb_build_object('expense_id', pg_temp.e(7), 'reason', 'Too early'))
    ->'result'->>'reversed',
  '0', 'and voided before any payment');
select is(pg_temp.push('expense.add', pg_temp.salary(pg_temp.e(8), 4, '2026-11-01', '2026-11-30', 1850000))->>'status',
  'applied', 'a voided period can be recorded again');
select is(pg_temp.push('expense.void', jsonb_build_object('expense_id', pg_temp.e(8), 'reason', 'Too early'))->>'status',
  'applied', 'and voided again');

-- ---------------------------------------------------------------- retired category
select is(pg_temp.push('expense_category.remove', jsonb_build_object('id', pg_temp.c(2)))->'result'->>'removed',
  'retired', 'a category in use is retired, not deleted');
select is(pg_temp.err('expense.add', pg_temp.cost(jsonb_build_object('category_id', pg_temp.c(2)))),
  'category_retired', 'a retired category takes no new expense');
select is(pg_temp.push('expense.update', jsonb_build_object('expense_id', pg_temp.e(1), 'category_id', pg_temp.c(2),
    'title', 'Electricity October', 'amount_paise', 230000, 'expense_date', '2026-10-05',
    'notes', 'KSEB bill, meter 2'))->>'status',
  'applied', 'but its expenses stay editable');

-- ---------------------------------------------------------------- who may read and write
select pg_temp.as_user(4);
select is(pg_temp.err('expense.add', pg_temp.cost('{}')), 'forbidden', 'floor staff cannot add an expense');
select is(pg_temp.pay(pg_temp.e(3), null, 1000, 'company', null, '2026-10-03', 'cash')->>'error',
  'forbidden', 'pay one');
select is(pg_temp.err('expense.void', jsonb_build_object('expense_id', pg_temp.e(3), 'reason', 'x')),
  'forbidden', 'or void one');
select is(pg_temp.err('staff_salary.set', jsonb_build_object('staff_id', pg_temp.sp(4),
    'effective_from', '2026-11-01', 'period', 'monthly', 'amount_paise', 9900000)),
  'forbidden', 'or set a salary');
select throws_ok($$ select pg_temp.list() $$, '42501', 'forbidden', 'nor list expenses');
select throws_ok($$ select private.arena_expense('e0000000-0000-4000-8000-000000000290', pg_temp.e(1)) $$,
  '42501', 'forbidden', 'read one');
select throws_ok($$ select private.arena_staff_salary('e0000000-0000-4000-8000-000000000290', pg_temp.sp(4)) $$,
  '42501', 'forbidden', 'or read their own salary record');
select pg_temp.as_user(6);
select throws_ok($$ select pg_temp.list() $$, '42501', 'forbidden', 'another arena''s owner cannot list them');
select throws_ok($$ select pg_temp.pay(pg_temp.e(3), null, 1000, 'company', null, '2026-10-03', 'cash') $$,
  '42501', 'forbidden', 'or pay into them');
select is(jsonb_array_length(private.arena_expenses('e0000000-0000-4000-8000-000000000291', '2026-09-01',
    '2026-10-31')->'expenses'), 1, 'and lists only their own');
select pg_temp.as_user(1);
select throws_ok($$ select private.arena_expenses('e0000000-0000-4000-8000-000000000290', '2026-10-31', '2026-10-01') $$,
  'invalid_range', 'a range ending before it starts is refused');
select throws_ok($$ select private.arena_expenses('e0000000-0000-4000-8000-000000000290', '2025-09-01', '2026-10-31') $$,
  'invalid_range', 'as is one over 400 days');

-- ---------------------------------------------------------------- totals, September–October
select is(jsonb_array_length(pg_temp.list()->'expenses'), 6, 'six expenses dated in the range, the voided rent among them');
select is((select sum((e->>'amount_paise')::bigint)::bigint from jsonb_array_elements(pg_temp.list()->'expenses') e
            where e->>'status' = 'active'),
  5930000::bigint, 'incurred, voids left out: ₹59,300');
select is(jsonb_array_length(pg_temp.list()->'payments'), 11, 'eleven payment rows by payment date, reversals included');
select is((select jsonb_object_agg(k, v) from (
             select p->>'paid_from' k, sum((p->>'amount_paise')::bigint) v
               from jsonb_array_elements(pg_temp.list()->'payments') p group by 1) x),
  '{"company": 1780000, "personal": 700000}'::jsonb,
  'paid out: ₹17,800 from the company account, ₹7,000 personally (net of reversals)');
select is((select string_agg(n || ' ' || v, ', ' order by n) from (
             select p->>'payer_name' n, sum((p->>'amount_paise')::bigint) v
               from jsonb_array_elements(pg_temp.list()->'payments') p
              where p->>'paid_from' = 'personal' group by 1) x),
  'Asha 700000, Bina 0', 'owner contributions: Asha ₹7,000, Bina ₹0 after her reversal');
select is((select sum((p->>'amount_paise')::bigint)::bigint from jsonb_array_elements(pg_temp.list()->'payments') p
            where p->>'expense_kind' = 'salary'),
  2200000::bigint, 'salaries paid: ₹22,000');
select is((select (l->>'owed_total_paise') || '/' || (l->>'owed_count') from (select pg_temp.list() l) x),
  '3450000/3', 'still owed, any date: ₹34,500 on three salaries');
select is((select jsonb_build_object('salaries', jsonb_array_length(s->'salaries'),
            'current', s->'salaries'->0->'amount_paise', 'periods', jsonb_array_length(s->'periods'))
             from (select private.arena_staff_salary('e0000000-0000-4000-8000-000000000290', pg_temp.sp(4)) s) x),
  '{"salaries": 2, "current": 1850000, "periods": 4}'::jsonb,
  'Ravi: two agreed salaries (₹18,500 now) and four periods, the voided Novembers included');

-- ---------------------------------------------------------------- row-level reads
-- Columns: expenses / expense_payments / staff_salaries / expense_categories /
-- audit rows of expenses and salaries / other audit rows.
create function pg_temp.seen() returns text as $$
  select (select count(*) from expenses) || '/' || (select count(*) from expense_payments)
      || '/' || (select count(*) from staff_salaries) || '/' || (select count(*) from expense_categories)
      || '/' || (select count(*) from audit_log where entity_type in ('expense', 'staff_salary'))
      || '/' || (select count(*) from audit_log where entity_type not in ('expense', 'staff_salary'))
$$ language sql;
set local role authenticated;
select pg_temp.as_user(1);
select is(pg_temp.seen(), '8/11/2/3/18/1', 'an owner sees all of their arena''s expenses');
select pg_temp.as_user(3);
select is(pg_temp.seen(), '8/11/2/3/18/1', 'so does a money holder');
select pg_temp.as_user(5);
select is(pg_temp.seen(), '0/0/0/0/0/1', 'a reports-only member sees none, not even their audit rows');
select pg_temp.as_user(4);
select is(pg_temp.seen(), '0/0/0/0/0/0', 'floor staff see none');
select pg_temp.as_user(7);
select is(pg_temp.seen(), '0/0/0/0/0/0', 'nor does a removed member');
select pg_temp.as_user(6);
select is(pg_temp.seen(), '1/0/0/1/1/0', 'another arena''s owner sees only their own');
reset role;

select * from finish();
rollback;
