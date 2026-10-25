-- _pr_money(v, step, dir) — apply the policy's cash rounding to a paise amount.
--
-- step <= 1: v unchanged; dir 'up': _pr_ceil_step; any other dir: _pr_round_step (nearest, ties up).
-- Callers pass the policy's money_rounding_paise / money_rounding_dir. Used by _pr_quote ('amount'),
-- _pr_session_bill ('total'). Mirrors applyMoneyRounding (rounding.dart).
-- Server-only: not executable by anon/authenticated.
create or replace function public._pr_money (
  v    bigint,
  step integer,
  dir  text
)
  returns bigint
  language sql
  immutable
  strict
  set search_path to 'public', 'extensions'
  AS $function$
  select case when step <= 1 then v
              when dir = 'up' then _pr_ceil_step(v, step)
              else _pr_round_step(v, step) end;
$function$;

comment on function public._pr_money(bigint, integer, text) is 'Pricing: cash-rounds a paise amount to step, up or to nearest; port of Dart applyMoneyRounding.';

grant execute on function "public"."_pr_money"(bigint, integer, text) to "postgres", "service_role";

revoke all on function "public"."_pr_money"(bigint, integer, text) from public;

revoke all on function "public"._pr_money(v bigint, step integer, dir text) from anon;

revoke all on function "public"._pr_money(v bigint, step integer, dir text) from authenticated;
