-- _pricing_snapshot(p_arena) — the arena's current price list in PricingSnapshot.toJson() shape.
--
-- What an in-sync device would freeze into a new session: standard rates from sync_v_rates (active
-- cards; rows of the retired happy band are left out, as the floor app leaves them out),
-- activities, the oldest-created active billing_policies row (else _pr_policy defaults),
-- settings.business_hours (else BusinessHours.current() defaults), all holidays, and closed ones
-- as closed_days, plus rules (active pricing_rules in priority order) only when there are any.
-- Compared via _pricing_canon by _assert_snapshot and _sync_apply.
-- Server-only: not executable by anon/authenticated.
create or replace function public._pricing_snapshot (
  p_arena uuid
)
  returns jsonb
  language sql
  stable
  security definer
  set search_path to 'public'
  AS $function$
  select jsonb_build_object(
    'rate_card_name', 'Current',
    'rates', coalesce((select jsonb_agg(jsonb_build_object('activity_code', activity_code,
        'band', band, 'controller_count', controller_count, 'unit_minutes', unit_minutes,
        'price_paise', price_paise)) from sync_v_rates
        where arena_id = p_arena and band = 'standard'), '[]'::jsonb),
    'activities', coalesce((select jsonb_agg(jsonb_build_object('code', code,
        'duration_model', duration_model, 'overtime_grace_minutes', overtime_grace_minutes))
        from activities where arena_id = p_arena), '[]'::jsonb),
    'policy', coalesce((select jsonb_build_object('billing_unit', billing_unit,
        'block_rounding', block_rounding, 'grace_minutes', grace_minutes,
        'minimum_charge_minutes', minimum_charge_minutes, 'early_exit', early_exit,
        'rounding_scope', rounding_scope, 'late_arrival', late_arrival,
        'vr_unit_rounding', vr_unit_rounding, 'money_rounding_paise', money_rounding_paise,
        'money_rounding_dir', money_rounding_dir, 'payment_timing', payment_timing,
        'allow_extend_past_close', allow_extend_past_close,
        'cleaning_gap_minutes', cleaning_gap_minutes)
        from billing_policies where arena_id = p_arena and active order by created_at limit 1),
        _pr_policy('{}'::jsonb)),
    -- BusinessHours.current() when the owner never saved hours.
    'hours', coalesce((select json from settings where arena_id = p_arena and key = 'business_hours'),
      '{"open":{"1":null,"2":{"start":840,"end":1380},"3":{"start":840,"end":1380},
                "4":{"start":840,"end":1380},"5":{"start":840,"end":1380},
                "6":{"start":840,"end":1380},"7":{"start":840,"end":1380}}}'::jsonb),
    'holidays', coalesce((select jsonb_agg(day::text) from holidays where arena_id = p_arena), '[]'::jsonb),
    'closed_days', coalesce((select jsonb_agg(day::text) from holidays
        where arena_id = p_arena and closed), '[]'::jsonb))
  -- Active pricing rules, only when there are any: an arena without rules keeps
  -- exactly the snapshot (and canon) floor apps built before rules produce.
  || coalesce((select jsonb_build_object('rules', jsonb_agg(jsonb_build_object(
        'id', r.id, 'name', r.name, 'priority', r.priority, 'days', to_jsonb(r.days),
        'start_min', r.start_min, 'end_min', r.end_min, 'holiday_mode', r.holiday_mode,
        'valid_from', r.valid_from, 'valid_until', r.valid_until,
        'activity_codes', to_jsonb(r.activity_codes), 'adjust_kind', r.adjust_kind,
        'adjust_value', r.adjust_value)
        order by r.priority, r.name collate "C", r.id::text collate "C"))
        from pricing_rules r where r.arena_id = p_arena and r.active
        having count(*) > 0), '{}'::jsonb);
$function$;

comment on function public._pricing_snapshot(uuid) is 'Pricing: the arena''s current price list built from its catalog, in the device''s PricingSnapshot JSON shape.';

grant execute on function "public"."_pricing_snapshot"(uuid) to "postgres", "service_role";

revoke all on function "public"."_pricing_snapshot"(uuid) from public;

revoke all on function "public"._pricing_snapshot(p_arena uuid) from anon;

revoke all on function "public"._pricing_snapshot(p_arena uuid) from authenticated;
