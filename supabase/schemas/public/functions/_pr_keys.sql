-- _pr_keys(q, p_act, p_res, p_cc) — charge keys for every line of a _pr_quote result.
--
-- Maps each q->'lines' element through _pr_charge_key; played minutes are played_seconds / 60,
-- truncated. Returns '{}' when there are no lines. Used by _pr_session_bill to build the key
-- list checked at session end.
-- Server-only: not executable by anon/authenticated.
create or replace function public._pr_keys (
  q     jsonb,
  p_act text,
  p_res uuid,
  p_cc  integer
)
  returns text[]
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  select coalesce(array_agg(_pr_charge_key(p_act, p_res, p_cc, l->>'band',
      (l->>'start')::timestamptz, (l->>'end')::timestamptz, (l->>'played_seconds')::bigint / 60,
      (l->>'billed_minutes')::bigint, (l->>'unit_minutes')::int, (l->>'unit_price')::bigint,
      (l->>'amount')::bigint)), '{}')
    from jsonb_array_elements(q->'lines') l;
$function$;

comment on function public._pr_keys(jsonb, text, uuid, integer) is 'Pricing: _pr_charge_key of every line of a quote.';

grant execute
  on function "public"."_pr_keys"(jsonb, text, uuid, integer)
  to "postgres", "service_role";

revoke all on function "public"."_pr_keys"(jsonb, text, uuid, integer) from public;

revoke all on function "public"._pr_keys(q jsonb, p_act text, p_res uuid, p_cc integer) from anon;

revoke all on function "public"._pr_keys(q jsonb, p_act text, p_res uuid, p_cc integer) from authenticated;
