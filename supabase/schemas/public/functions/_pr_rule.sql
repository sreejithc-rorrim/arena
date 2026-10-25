-- _pr_rule(s, p_act, p_at) — the pricing rule of snapshot s that applies to p_act started at p_at.
--
-- Judged in Asia/Kolkata on p_at (the session's start): the IST weekday must be in
-- days, the whole minute of day (seconds dropped) in [start_min, end_min), the IST date inside [valid_from, valid_until],
-- holiday_mode against s.holidays (only / skip / any), and p_act in activity_codes (empty = all).
-- The first match by priority, then name, then id (code-point order, collate "C", as the
-- floor app compares) wins; null when s has no rules or none match.
-- Used by _pr_quote. Server-only: not executable by anon/authenticated.
create or replace function public._pr_rule (
  s     jsonb,
  p_act text,
  p_at  timestamp with time zone
)
  returns jsonb
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  with t as (
    select _pr_ist_date(p_at) as d,
           floor(extract(epoch from (p_at at time zone 'UTC') + interval '330 minutes'
              - _pr_ist_date(p_at)::timestamp) / 60)::int as m
  )
  select r from t, jsonb_array_elements(coalesce(s->'rules', '[]'::jsonb)) r
   where r->'days' @> to_jsonb(extract(isodow from t.d)::int)
     and t.m >= (r->>'start_min')::int and t.m < (r->>'end_min')::int
     and (r->>'valid_from' is null or t.d >= (r->>'valid_from')::date)
     and (r->>'valid_until' is null or t.d <= (r->>'valid_until')::date)
     and case r->>'holiday_mode'
           when 'only' then coalesce(s->'holidays', '[]'::jsonb) ? t.d::text
           when 'skip' then not coalesce(s->'holidays', '[]'::jsonb) ? t.d::text
           else true end
     and (jsonb_array_length(coalesce(r->'activity_codes', '[]'::jsonb)) = 0
          or r->'activity_codes' ? p_act)
   order by (r->>'priority')::int, r->>'name' collate "C", r->>'id' collate "C"
   limit 1;
$function$;

comment on function public._pr_rule(jsonb, text, timestamp with time zone) is 'Pricing: the snapshot''s first-priority rule matching an activity started at an instant (IST weekday, minute, dates, holidays), or null.';

grant execute on function "public"."_pr_rule"(jsonb, text, timestamp with time zone) to "postgres", "service_role";

revoke all on function "public"."_pr_rule"(jsonb, text, timestamp with time zone) from public;

revoke all on function "public"._pr_rule(s jsonb, p_act text, p_at timestamp with time zone) from anon;

revoke all on function "public"._pr_rule(s jsonb, p_act text, p_at timestamp with time zone) from authenticated;
