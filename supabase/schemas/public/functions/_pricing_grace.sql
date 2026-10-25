-- _pricing_grace() — how long a replaced price list is still accepted.
--
-- Returns 72 hours: a session.start snapshot equal to a pricing_catalog_history
-- entry retired within this window is accepted (a device that went offline on the old list).
-- Used by _assert_snapshot.
-- Server-only: not executable by anon/authenticated.
create or replace function public._pricing_grace()
  returns interval
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  select interval '72 hours';
$function$;

comment on function public._pricing_grace() is 'Pricing: window (72 hours) during which a retired price list is still accepted at session start.';

grant execute on function "public"."_pricing_grace"() to "postgres", "service_role";

revoke all on function "public"."_pricing_grace"() from public;

revoke all on function "public"._pricing_grace() from anon;

revoke all on function "public"._pricing_grace() from authenticated;
