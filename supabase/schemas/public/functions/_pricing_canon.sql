-- _pricing_canon(s) — reduce a pricing snapshot to what pricing depends on, in a fixed order.
--
-- Builds {rates, activities, policy, hours, holidays, closed_days[, rules]}: rates and activities sorted,
-- policy filled from _pr_policy defaults, open hours for ISO days 1-7 (non-object -> null),
-- holidays and closed_days de-duplicated and sorted, rules (only when there are any) in priority
-- order with their days and activity codes sorted. Card name and list order are dropped, and so are
-- keys pricing no longer reads (an activity's happy_eligible, hours.happy from before happy hour
-- became a pricing rule, policy.group_billing_mode from before group sessions were removed).
-- Used by _assert_snapshot and by _sync_apply (records a replaced list in pricing_catalog_history).
-- Server-only: not executable by anon/authenticated.
create or replace function public._pricing_canon (
  s jsonb
)
  returns jsonb
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  select jsonb_build_object(
    'rates', coalesce((select jsonb_agg(jsonb_build_object('a', r->>'activity_code',
        'b', r->>'band', 'c', (r->>'controller_count')::int, 'u', (r->>'unit_minutes')::int,
        'p', (r->>'price_paise')::bigint)
        order by r->>'activity_code', r->>'band', coalesce((r->>'controller_count')::int, -1),
                 (r->>'unit_minutes')::int, (r->>'price_paise')::bigint)
        from jsonb_array_elements(coalesce(s->'rates', '[]'::jsonb)) r), '[]'::jsonb),
    'activities', coalesce((select jsonb_agg(jsonb_build_object('code', a->>'code',
        'model', a->>'duration_model',
        -- Absent (an older device or snapshot) = no grace.
        'grace', coalesce((a->>'overtime_grace_minutes')::int, 0))
        order by a->>'code', a->>'duration_model')
        from jsonb_array_elements(coalesce(s->'activities', '[]'::jsonb)) a), '[]'::jsonb),
    -- group_billing_mode: dropped, so a device snapshot that still carries it matches.
    'policy', _pr_policy(s) - 'group_billing_mode',
    'hours', (select jsonb_object_agg(kind, (select jsonb_object_agg(d::text,
        case when jsonb_typeof(s->'hours'->kind->(d::text)) = 'object'
             then jsonb_build_object('start', (s->'hours'->kind->(d::text)->>'start')::int,
                                     'end', (s->'hours'->kind->(d::text)->>'end')::int)
             else 'null'::jsonb end) from generate_series(1, 7) d))
        from unnest(array['open']) kind),
    'holidays', coalesce((select jsonb_agg(distinct x order by x)
        from jsonb_array_elements_text(coalesce(s->'holidays', '[]'::jsonb)) x), '[]'::jsonb),
    'closed_days', coalesce((select jsonb_agg(distinct x order by x)
        from jsonb_array_elements_text(coalesce(s->'closed_days', '[]'::jsonb)) x), '[]'::jsonb))
  -- Rules only when the snapshot has any, so a rule-free canon is unchanged.
  || coalesce((select jsonb_build_object('rules', jsonb_agg(jsonb_build_object(
        'id', r->>'id', 'name', r->>'name', 'priority', (r->>'priority')::int,
        'days', (select jsonb_agg(distinct d::int order by d::int)
                   from jsonb_array_elements_text(r->'days') d),
        'start_min', (r->>'start_min')::int, 'end_min', (r->>'end_min')::int,
        'holiday_mode', r->>'holiday_mode', 'valid_from', r->>'valid_from',
        'valid_until', r->>'valid_until',
        'activity_codes', coalesce((select jsonb_agg(distinct c order by c)
                   from jsonb_array_elements_text(r->'activity_codes') c), '[]'::jsonb),
        'adjust_kind', r->>'adjust_kind', 'adjust_value', (r->>'adjust_value')::int)
        order by (r->>'priority')::int, r->>'name' collate "C", r->>'id' collate "C"))
        from jsonb_array_elements(coalesce(s->'rules', '[]'::jsonb)) r
        having count(*) > 0), '{}'::jsonb);
$function$;

comment on function public._pricing_canon(jsonb) is 'Pricing: canonical form of a snapshot (sorted, defaults filled, card name dropped) for equality checks.';

grant execute on function "public"."_pricing_canon"(jsonb) to "postgres", "service_role";

revoke all on function "public"."_pricing_canon"(jsonb) from public;

revoke all on function "public"._pricing_canon(s jsonb) from anon;

revoke all on function "public"._pricing_canon(s jsonb) from authenticated;
