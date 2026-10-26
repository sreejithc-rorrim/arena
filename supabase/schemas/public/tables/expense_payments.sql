-- expense_payments — append-only money paid toward an expense, and reversals of mistakes
--
-- One row per payment (positive) or reversal (negative, the exact opposite of one payment, with
-- a reason). Their sum is what an expense has had paid. Every row says where the money came
-- from: paid_from 'company' (the arena's account; no payer) or 'personal' (an owner's own
-- money; payer_staff_id is that owner's staff_profiles row). One expense may mix sources across
-- payments. A reversal mirrors its payment exactly — same expense, source, payer, method and
-- day, opposite amount (_expense_payment_check) — so each source's totals stay right in the
-- period the money moved. The client-generated id is the primary key, so a re-sent payment
-- cannot double. Written by op_expense_add / op_expense_pay / op_expense_payment_reverse /
-- op_expense_void (money). Read by money holders only. Not in sync_pull.
create table "public"."expense_payments" (
  "id"             uuid                     not null default gen_random_uuid(),
  "arena_id"       uuid                     not null,
  "expense_id"     uuid                     not null,
  "kind"           text                     not null default 'payment'::text,
  "amount_paise"   bigint                   not null,
  "method"         text                     not null,
  "paid_on"        date                     not null,
  "paid_from"      text                     not null,
  "payer_staff_id" uuid,
  "note"           text,
  "reverses_id"    uuid,
  "created_by"     uuid,
  "created_at"     timestamp with time zone not null default now(),
  constraint "expense_payments_pkey" primary key (id),
  constraint "expense_payments_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "expense_payments_expense_id_fkey" foreign key (expense_id) references public.expenses(id),
  constraint "expense_payments_payer_staff_id_fkey" foreign key (payer_staff_id)
    references public.staff_profiles(id),
  constraint "expense_payments_reverses_id_fkey" foreign key (reverses_id)
    references public.expense_payments(id),
  constraint "expense_payments_created_by_fkey" foreign key (created_by) references auth.users(id),
  -- A payment is reversed at most once.
  constraint "expense_payments_reverses_id_key" unique (reverses_id),
  constraint "expense_payments_kind_check" check ((kind = ANY (ARRAY['payment'::text, 'reversal'::text]))),
  -- Payments are positive, reversals negative; zero is never recorded.
  constraint "expense_payments_amount_sign_check"
    check (((amount_paise <> 0) AND ((kind = 'reversal'::text) = (amount_paise < 0)))),
  constraint "expense_payments_method_check"
    check ((method = ANY (ARRAY['cash'::text, 'upi'::text, 'card'::text, 'bank'::text, 'other'::text]))),
  constraint "expense_payments_paid_from_check"
    check ((paid_from = ANY (ARRAY['company'::text, 'personal'::text]))),
  -- A personal payment names its payer; a company one names nobody.
  constraint "expense_payments_payer_check"
    check (((paid_from = 'personal'::text) = (payer_staff_id IS NOT NULL))),
  -- A reversal points at the payment it undoes and carries the reason in note.
  constraint "expense_payments_reversal_check"
    check ((((kind = 'reversal'::text) = (reverses_id IS NOT NULL))
      AND ((kind <> 'reversal'::text) OR (btrim(COALESCE(note, ''::text)) <> ''::text)))),
  constraint "expense_payments_note_check" check (((note IS NULL) OR (char_length(note) <= 500)))
);

comment on table public.expense_payments is 'Append-only payments toward expenses and reversals of mistaken ones, each with its funding source (company account or an owner''s own money). Money holders only.';

comment on column public.expense_payments.arena_id is 'Owning arena (tenant). RLS limits reads to money holders of this arena.';

comment on column public.expense_payments.amount_paise is 'Signed integer paise: positive for a payment, negative for a reversal (minus the payment it undoes), never zero.';

comment on column public.expense_payments.method is 'cash, upi, card, bank or other.';

comment on column public.expense_payments.paid_on is 'IST day the money was paid (a reversal: its payment''s day). Cash totals count by this date.';

comment on column public.expense_payments.paid_from is 'company (the arena''s account) or personal (an owner''s own money: payer_staff_id says whose).';

comment on column public.expense_payments.payer_staff_id is 'staff_profiles row of the owner who paid personally; null for a company payment.';

comment on column public.expense_payments.note is 'Free-text note on a payment; the reason on a reversal (required).';

comment on column public.expense_payments.reverses_id is 'The payment this reversal undoes; null on a payment. Unique: a payment is reversed at most once.';

comment on column public.expense_payments.created_by is 'auth.users id of the member whose op recorded the row.';

alter table "public"."expense_payments"
  enable row level security;

create index ix_expense_payments_expense on public.expense_payments using btree (expense_id, created_at);

create index ix_expense_payments_arena_paid_on on public.expense_payments using btree (arena_id, paid_on);

-- Foreign-key indexes.
create index ix_expense_payments_payer on public.expense_payments using btree (payer_staff_id);

create index ix_expense_payments_created_by on public.expense_payments using btree (created_by);

-- Expense and payer must belong to this row's arena (cross_arena_reference).
create trigger t_same_arena
  before insert or update on public.expense_payments
  for each row
  execute function public._assert_same_arena('expense_id', 'expenses', 'payer_staff_id', 'staff_profiles');

-- A reversal mirrors its payment exactly (_expense_payment_check).
create trigger t_expense_payments_check
  before insert on public.expense_payments
  for each row
  execute function public._expense_payment_check();

-- Append-only: corrections are new rows (_append_only).
create trigger t_expense_payments_append_only
  before update or delete on public.expense_payments
  for each row
  execute function public._append_only();

-- Readable by money holders only (the owner holds every permission).
-- No write policy: clients change data only through sync_push.
create policy "p_sel_expense_payments" on "public"."expense_payments"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids_with(ARRAY['money'::text]) as app_arena_ids_with)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."expense_payments"
  to "postgres", "service_role";

revoke all on table "public"."expense_payments" from "anon";

revoke all on table "public"."expense_payments" from "authenticated";

grant select on table "public"."expense_payments" to "authenticated";
