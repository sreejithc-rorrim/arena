-- _pr_quote(s, p_act, p_cc, p_start, p_end, p_rule_at) — price one interval for one activity / controller count.
--
-- Port of PricingService.quote (domain/pricing/pricing_service.dart) on snapshot s. Returns {subtotal,
-- amount (cash-rounded), lines:[{start, end, band, played_seconds, billed_minutes, units, unit_minutes,
-- unit_price, amount}]}, or null when p_end < p_start, the activity is not in s, or a band has no rate.
-- Applies grace (free when <= grace_minutes), minimum charge (extends the billed end only),
-- per-minute / block / VR-unit billing and the session-or-segment rounding scope. Every interval is
-- one line at the 'standard' band: time-of-day prices such as happy hours are pricing rules.
-- Pricing rules: the rule matching p_act at p_rule_at (the session's start; p_start when
-- null) adjusts every band's unit price before billing (_pr_rule, _pr_rule_price); the result then
-- carries rule: {name, adjust_kind, adjust_value}. A snapshot without rules prices as before.
-- Used by _pr_session_bill and op_session_extend.
-- Server-only: not executable by anon/authenticated.
create or replace function public._pr_quote (
  s       jsonb,
  p_act   text,
  p_cc    integer,
  p_start   timestamp with time zone,
  p_end     timestamp with time zone,
  p_rule_at timestamp with time zone default null
)
  returns jsonb
  language plpgsql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
declare
  pol jsonb := _pr_policy(s);
  v_act jsonb;
  v_total bigint; v_min bigint; v_bend timestamptz;
  bs timestamptz[]; be timestamptz[]; bb text[];
  n int; i int;
  v_rate jsonb; v_price bigint; v_um int; v_us bigint; v_sec bigint; v_played bigint;
  v_num bigint; v_den bigint; v_billed bigint; v_units bigint; v_block int;
  v_sum_num bigint := 0; v_common bigint; v_mixed boolean := false; v_seg_sum bigint := 0;
  v_amount bigint; v_sub bigint;
  v_lines jsonb := '[]'::jsonb;
  v_rule jsonb;
begin
  if p_end < p_start then return null; end if;
  select a into v_act from jsonb_array_elements(coalesce(s->'activities', '[]'::jsonb)) a
   where a->>'code' = p_act limit 1;
  if v_act is null then return null; end if;
  v_rule := _pr_rule(s, p_act, coalesce(p_rule_at, p_start));

  v_total := _pr_secs(p_start, p_end);
  -- Grace: free when under the grace period.
  if v_total <= (pol->>'grace_minutes')::int * 60 then
    return jsonb_build_object('subtotal', 0, 'amount', 0, 'lines', '[]'::jsonb);
  end if;
  -- Minimum charge: bill at least this much by extending the billed interval.
  v_min := (pol->>'minimum_charge_minutes')::int * 60;
  v_bend := case when v_total < v_min then p_start + make_interval(secs => v_min) else p_end end;

  -- One billed piece at the standard band (lines keep the band for the charge rows).
  bs := array[p_start]; be := array[v_bend]; bb := array['standard']; n := 1;

  for i in 1 .. n loop
    v_rate := _pr_rate(s, p_act, bb[i], p_cc);
    if v_rate is null then return null; end if;
    v_um := (v_rate->>'unit_minutes')::int;
    v_price := _pr_rule_price((v_rate->>'price_paise')::bigint, v_um, v_rule);
    v_us := v_um::bigint * 60;
    v_sec := _pr_secs(bs[i], be[i]);
    -- Played time counts only the real [p_start, p_end]; the billed piece may run past p_end.
    v_played := case when least(p_end, be[i]) > greatest(p_start, bs[i])
                     then _pr_secs(greatest(p_start, bs[i]), least(p_end, be[i])) else 0 end;
    v_units := 0;
    if v_act->>'duration_model' = 'unit' then
      case pol->>'vr_unit_rounding'
        when 'prorate' then
          v_num := v_price * v_sec; v_den := v_us; v_billed := _pr_div(v_sec, 60);
        when 'nearest' then
          v_units := _pr_div(v_sec, v_us);
          v_num := v_price * v_units; v_den := 1; v_billed := v_units * v_um;
        else -- up
          v_units := (v_sec + v_us - 1) / v_us;
          v_num := v_price * v_units; v_den := 1; v_billed := v_units * v_um;
      end case;
    elsif pol->>'billing_unit' = 'per_minute' then
      v_num := v_price * v_sec; v_den := v_us; v_billed := _pr_div(v_sec, 60);
    else
      v_block := case pol->>'billing_unit' when 'block_15' then 15 when 'block_30' then 30 else 60 end;
      v_billed := (v_sec + 59) / 60;   -- whole minutes first
      v_billed := case when pol->>'block_rounding' = 'up' then _pr_ceil_step(v_billed, v_block)
                       else _pr_round_step(v_billed, v_block) end;
      v_num := v_price * v_billed; v_den := v_um;
    end if;

    -- Rounding scope: keep the exact numerator over a common denominator so 'session' scope
    -- rounds once (below); 'segment' scope or mixed denominators sum the per-line paise.
    v_common := coalesce(v_common, v_den);
    if v_den <> v_common then v_mixed := true; end if;
    v_sum_num := v_sum_num + v_num;
    v_amount := _pr_div(v_num, v_den);
    v_seg_sum := v_seg_sum + v_amount;
    v_lines := v_lines || jsonb_build_object('start', bs[i], 'end', be[i], 'band', bb[i],
      'played_seconds', v_played, 'billed_minutes', v_billed, 'units', v_units,
      'unit_minutes', v_um, 'unit_price', v_price, 'amount', v_amount);
  end loop;

  v_sub := case when pol->>'rounding_scope' = 'segment' or v_mixed then v_seg_sum
                else _pr_div(v_sum_num, coalesce(v_common, 1)) end;
  return jsonb_build_object('subtotal', v_sub,
    'amount', _pr_money(v_sub, (pol->>'money_rounding_paise')::int, pol->>'money_rounding_dir'),
    'lines', v_lines)
    || case when v_rule is null then '{}'::jsonb
            else jsonb_build_object('rule', jsonb_build_object('name', v_rule->>'name',
              'adjust_kind', v_rule->>'adjust_kind', 'adjust_value', (v_rule->>'adjust_value')::int)) end;
end;
$function$;

comment on function public._pr_quote(jsonb, text, integer, timestamp with time zone, timestamp with time zone, timestamp with time zone) is 'Pricing: quotes one interval for one activity and controller count on a snapshot (lines, subtotal, cash-rounded amount); port of PricingService.quote.';

grant execute
  on function "public"."_pr_quote"(jsonb, text, integer, timestamp with time zone, timestamp
    with time zone, timestamp with time zone)
  to "postgres", "service_role";

revoke all
  on function "public"."_pr_quote"(jsonb, text, integer, timestamp with time zone, timestamp
    with time zone, timestamp with time zone)
  from public;

revoke all on function "public"._pr_quote(s jsonb, p_act text, p_cc integer, p_start timestamp with time zone, p_end timestamp with time zone, p_rule_at timestamp with time zone) from anon;

revoke all on function "public"._pr_quote(s jsonb, p_act text, p_cc integer, p_start timestamp with time zone, p_end timestamp with time zone, p_rule_at timestamp with time zone) from authenticated;
