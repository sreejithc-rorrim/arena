-- _pr_policy(s) — the snapshot's billing policy with defaults for missing keys.
--
-- Returns the BillingPolicy.defaults JSON overlaid (jsonb ||) with s->'policy', so a key absent
-- from an older snapshot reads as the device reads it. Used by _pr_quote, _pr_session_bill,
-- _pricing_canon and _pricing_snapshot (fallback when no active policy row). Mirrors
-- BillingPolicy.defaults (domain/pricing/billing_policy.dart).
-- Server-only: not executable by anon/authenticated.
create or replace function public._pr_policy (
  s jsonb
)
  returns jsonb
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  select '{"billing_unit":"per_minute","block_rounding":"up","grace_minutes":0,
    "minimum_charge_minutes":0,"early_exit":"actual","rounding_scope":"session",
    "late_arrival":"actual","vr_unit_rounding":"up","money_rounding_paise":100,
    "money_rounding_dir":"nearest","payment_timing":"either","allow_extend_past_close":false,
    "cleaning_gap_minutes":0}'::jsonb
    || coalesce(s->'policy', '{}'::jsonb);
$function$;

comment on function public._pr_policy(jsonb) is 'Pricing: billing policy of a snapshot merged over the Dart BillingPolicy.defaults.';

grant execute on function "public"."_pr_policy"(jsonb) to "postgres", "service_role";

revoke all on function "public"."_pr_policy"(jsonb) from public;

revoke all on function "public"._pr_policy(s jsonb) from anon;

revoke all on function "public"._pr_policy(s jsonb) from authenticated;
