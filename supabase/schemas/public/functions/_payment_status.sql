-- _payment_status(billed, paid) — payment status of a bill, in paise
--
-- 'paid' when paid >= billed, 'partial' when something but not all is paid,
-- else 'unpaid'. A null billed (no final bill yet) is 'partial' if anything
-- was paid, else 'unpaid'. Used by op_payment, op_session_record and
-- op_session_end ('waived' is decided by the caller, not here).
-- Server-only: not executable by anon/authenticated.
create or replace function public._payment_status (
  p_billed bigint,
  p_paid   bigint
)
  returns text
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  select case
    when p_billed is null then (case when p_paid > 0 then 'partial' else 'unpaid' end)
    when p_paid >= p_billed then 'paid'
    when p_paid > 0 then 'partial'
    else 'unpaid' end;
$function$;

comment on function public._payment_status(bigint, bigint) is 'Internal: paid / partial / unpaid from billed and paid amounts in paise; a null billed amount gives partial or unpaid.';

grant execute on function "public"."_payment_status"(bigint, bigint) to "postgres", "service_role";

revoke all on function "public"."_payment_status"(bigint, bigint) from public;

revoke all on function "public"._payment_status(p_billed bigint, p_paid bigint) from anon;

revoke all on function "public"._payment_status(p_billed bigint, p_paid bigint) from authenticated;
