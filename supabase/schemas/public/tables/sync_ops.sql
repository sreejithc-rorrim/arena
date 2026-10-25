-- sync_ops — server-only ledger that makes sync_push apply each device op exactly once
--
-- One row per op id ever pushed, inserted by sync_push after the op's savepoint:
-- applied (with the op's result) or rejected (with error code / detail).
-- Transient failures (serialization, deadlock, lock timeout, cancel) are not
-- recorded, so the device retries them. A re-push of a known op_id replays the
-- stored answer instead of re-running the op. Also the server's receipt time and
-- sender for every op (audit evidence). Server-only: no client grants, and RLS is
-- on with no policies (deny all); only SECURITY DEFINER sync_push touches it.
create table "public"."sync_ops" (
  "op_id"         uuid                     not null,
  "arena_id"      uuid                     not null,
  "user_id"       uuid                     not null,
  "device_id"     text,
  "kind"          text                     not null,
  "status"        text                     not null,
  "result"        jsonb,
  "error_code"    text,
  "error_message" text,
  "created_at"    timestamp with time zone not null default now(),
  "payload"       jsonb,
  constraint "sync_ops_arena_id_fkey" foreign key (arena_id) references public.arenas(id)
    on delete cascade,
  constraint "sync_ops_pkey" primary key (op_id),
  constraint "sync_ops_status_check"
    check ((status = ANY (ARRAY['applied'::text, 'rejected'::text])))
);

comment on table public.sync_ops is 'Server-only idempotency ledger for sync_push: one row per device op id with its outcome, replayed on retry. No client grants; RLS on with no policies (deny all).';

comment on column public.sync_ops.payload is 'What an applied configuration or permission op asked for (staff, arena, station types, stations, rates, billing rules, settings, holidays, pricing rules, discounts): with user_id and created_at, who changed what and when. Null for floor ops.';

comment on column public.sync_ops.op_id is 'Device-generated op id (outbox key); primary key, so an op is applied at most once. Reuse under another arena raises op_id_reused.';

comment on column public.sync_ops.arena_id is 'Arena the op was pushed to.';

comment on column public.sync_ops.user_id is 'auth.uid() of the signed-in member who pushed the op (no FK).';

comment on column public.sync_ops.device_id is 'Device identifier passed to sync_push, if any.';

comment on column public.sync_ops.kind is 'Op kind dispatched by _sync_apply, e.g. session.start, payment.record; ? if missing.';

comment on column public.sync_ops.status is 'applied or rejected. Retryable failures are never recorded.';

comment on column public.sync_ops.result is 'The op function''s jsonb result when applied; replayed verbatim on a re-push.';

comment on column public.sync_ops.error_code is 'Stable refusal code when rejected (the op''s raised message, e.g. stale or price_mismatch, or a mapped class such as forbidden / duplicate / invalid).';

comment on column public.sync_ops.error_message is 'Refusal detail when rejected (exception hint, else message).';

comment on column public.sync_ops.created_at is 'Server receipt time of the op; audit evidence independent of device clocks.';

-- RLS on with no policies: deny all to client roles (defence in depth beside the revokes).
alter table "public"."sync_ops"
  enable row level security;

create index ix_sync_ops_arena on public.sync_ops using btree (arena_id, created_at);

grant delete, insert, maintain, references, select, trigger, truncate, update
  on table "public"."sync_ops"
  to "postgres", "service_role";

revoke all on table "public".sync_ops from anon;

revoke all on table "public".sync_ops from authenticated;
