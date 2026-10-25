-- audit_log — append-only record of sensitive actions and sync-time adjustments
--
-- Written by:
--   op_session_void (entity session, action void, with the owner's required reason);
--   op_session_end on a waive (action waive, the staff reason when
--     given, before {billed_paise, paid_paise}, after {written_off_paise});
--   op_payment_correct (action payment_correct, the required reason, before
--     {payment_id, method, amount_paise}, after {method, amount_paise, refund_id,
--     payment_id});
--   op_bill_adjust (action bill_adjust, the required reason, before {billed_paise, paid_paise},
--     after {billed_paise, paid_paise});
--   op_customer_create (entity customer, action duplicate_phone_on_sync, when a
--     phone already belongs to another customer and the new row is kept without it).
-- Refunds are not repeated here: each is its own append-only payments row with a
-- reason and who recorded it. Only owner-level members (money / reports) can read
-- it; it has no sync_xid, so it is not part of the sync_pull change feed.
create table "public"."audit_log" (
  "id"          uuid                     not null default gen_random_uuid(),
  "arena_id"    uuid                     not null,
  "entity_type" text                     not null,
  "entity_id"   uuid                     not null,
  "action"      text                     not null,
  "reason"      text,
  "before"      jsonb,
  "after"       jsonb,
  "created_at"  timestamp with time zone not null default now(),
  "created_by"  uuid,
  constraint "audit_log_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "audit_log_created_by_fkey" foreign key (created_by) references auth.users(id),
  constraint "audit_log_pkey" primary key (id)
);

comment on table public.audit_log is 'Append-only audit trail of voids, waives, payment-method corrections and sync-time data adjustments, per arena. Not part of the sync change feed.';

comment on column public.audit_log.arena_id is 'Owning arena (tenant); RLS shows the row only to active members of this arena.';

comment on column public.audit_log.entity_type is 'Kind of row acted on, e.g. session or customer.';

comment on column public.audit_log.entity_id is 'Id of the row acted on (no FK; entity_type names its table).';

comment on column public.audit_log.action is 'What happened: void, waive, payment_correct, bill_adjust or duplicate_phone_on_sync.';

comment on column public.audit_log.reason is 'Human reason (the void or correction reason, the waive reason when given, or a system explanation).';

comment on column public.audit_log.before is 'Relevant state before the action, if recorded.';

comment on column public.audit_log.after is 'Relevant state after the action, if recorded (e.g. the clashing phone and existing customer id).';

comment on column public.audit_log.created_by is 'auth.users id of the staff member whose sync op caused the entry.';


-- Append-only: corrections are new rows (_append_only).
create trigger t_audit_log_append_only
  before update or delete on public.audit_log
  for each row
  execute function public._append_only();
alter table "public"."audit_log"
  enable row level security;

create index ix_audit_entity on public.audit_log using btree (arena_id, entity_type, entity_id);

-- Foreign-key index (joins and cascading deletes).
create index ix_audit_log_created_by on public.audit_log using btree (created_by);

-- Readable by an active member holding owner level (money/reports) only: voids and sync adjustments are an owner's record.
-- No write policy: clients change data only through sync_push.
create policy "p_sel_audit_log" on "public"."audit_log"
  for select
  to authenticated
  using ((arena_id in ( select private.app_arena_ids_with(ARRAY['money'::text, 'reports'::text]) as app_arena_ids_with)));

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."audit_log"
  to "postgres", "service_role";

revoke all on table "public"."audit_log" from "anon";

revoke all on table "public"."audit_log" from "authenticated";

grant select on table "public"."audit_log" to "authenticated";