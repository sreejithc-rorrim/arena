-- _discount_apply(p_arena, p_disc, p_bill, p_at, p_session) — apply one discount to a session's bill.
--
-- p_disc is the `discount` of a session.end payload:
--   {id?, discount_id? | code? | manual: {value_kind, value}, reason?, amount_paise}.
-- p_bill is the server's bill (_pr_session_bill: subtotal, by_activity); p_at the
-- bill's end instant, at which validity is judged; p_session the session billed.
-- Preset / coupon: must be active (discount_inactive), inside [valid_from, valid_until]
-- (discount_not_started / coupon_expired), under max_uses counting non-voided bills
-- (coupon_used_up), on a subtotal ≥ min_bill_paise (discount_min_bill) and on a bill with charges of
-- its station types (discount_scope). A code that matches no coupon: coupon_unknown.
-- Manual: needs the discount permission; percent 1–100 or flat ≥ 1 paise (invalid_discount); a
-- caller without settings is held to settings.discount_options.manual_max_percent of the subtotal
-- (discount_over_limit) and, when reason_required, must give a reason (discount_reason_required).
-- Amount: percent = round-half-up(base × value / 100) capped by max_discount_paise; flat = value;
-- never above base, where base = the subtotal of the in-scope types (whole subtotal when unscoped).
-- The device's amount_paise must equal it (price_mismatch, hint discount). Inserts the
-- bill_discounts row and returns the amount. Used by op_session_end.
-- Server-only: not executable by anon/authenticated.
create or replace function public._discount_apply (
  p_arena   uuid,
  p_disc    jsonb,
  p_bill    jsonb,
  p_at      timestamp with time zone,
  p_session uuid
)
  returns bigint
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_sub    bigint := (p_bill->>'subtotal')::bigint;
  v_d      discounts%rowtype;
  v_manual jsonb := p_disc->'manual';
  v_reason text := nullif(btrim(coalesce(p_disc->>'reason', '')), '');
  v_opts   jsonb;
  v_source text; v_name text; v_code text; v_vkind text; v_value bigint;
  v_base   bigint; v_amount bigint; v_max int; v_uses int;
begin
  if v_manual is not null then
    perform _need(p_arena, 'discount');
    v_vkind := v_manual->>'value_kind';
    v_value := (v_manual->>'value')::bigint;
    if v_value is null or not ((v_vkind = 'percent' and v_value between 1 and 100)
                               or (v_vkind = 'flat' and v_value >= 1)) then
      raise exception 'invalid_discount';
    end if;
    v_source := 'manual'; v_name := 'Manual discount'; v_base := v_sub;
  else
    if p_disc ? 'code' then
      select * into v_d from discounts
       where arena_id = p_arena and kind = 'coupon' and code = upper(btrim(p_disc->>'code')) for update;
      if not found then raise exception 'coupon_unknown'; end if;
    else
      select * into v_d from discounts
       where arena_id = p_arena and id = (p_disc->>'discount_id')::uuid for update;
      if not found then raise exception 'not_found' using hint = 'discount'; end if;
    end if;
    if not v_d.active then raise exception 'discount_inactive'; end if;
    if v_d.valid_from is not null and p_at < v_d.valid_from then
      raise exception 'discount_not_started' using hint = v_d.valid_from::text;
    end if;
    if v_d.valid_until is not null and p_at > v_d.valid_until then
      raise exception 'coupon_expired' using hint = v_d.valid_until::text;
    end if;
    if v_d.max_uses is not null then
      select count(*) into v_uses from bill_discounts b
        join sessions s on s.id = b.session_id
       where b.discount_id = v_d.id and s.status <> 'voided';
      if v_uses >= v_d.max_uses then raise exception 'coupon_used_up'; end if;
    end if;
    if v_d.min_bill_paise is not null and v_sub < v_d.min_bill_paise then
      raise exception 'discount_min_bill' using hint = v_d.min_bill_paise::text;
    end if;
    v_base := case when cardinality(v_d.activity_codes) = 0 then v_sub
                   else coalesce((select sum(value::bigint) from jsonb_each_text(p_bill->'by_activity')
                                   where key = any(v_d.activity_codes)), 0) end;
    if v_base <= 0 and cardinality(v_d.activity_codes) > 0 then
      raise exception 'discount_scope';
    end if;
    v_source := v_d.kind; v_name := v_d.name; v_code := v_d.code;
    v_vkind := v_d.value_kind; v_value := v_d.value;
  end if;

  v_amount := case when v_vkind = 'percent' then _pr_div(v_base * v_value, 100) else v_value end;
  if v_d.max_discount_paise is not null then v_amount := least(v_amount, v_d.max_discount_paise); end if;
  v_amount := greatest(0, least(v_amount, v_base));

  if v_source = 'manual' then
    select json into v_opts from settings where arena_id = p_arena and key = 'discount_options';
    if not private.app_has_perm(p_arena, 'settings') then
      v_max := coalesce((v_opts->>'manual_max_percent')::int, 0);
      if v_amount > _pr_div(v_sub * v_max, 100) then
        raise exception 'discount_over_limit' using hint = v_max::text || '%';
      end if;
    end if;
    if coalesce((v_opts->>'reason_required')::boolean, false) and v_reason is null then
      raise exception 'discount_reason_required';
    end if;
  end if;

  if (p_disc->>'amount_paise')::bigint is distinct from v_amount then
    perform _price_mismatch('discount', v_amount, (p_disc->>'amount_paise')::bigint);
  end if;

  insert into bill_discounts(id, arena_id, session_id, discount_id, source, name, code,
      value_kind, value, base_paise, amount_paise, reason, applied_by, applied_at)
    values (coalesce(nullif(p_disc->>'id', '')::uuid, gen_random_uuid()), p_arena, p_session,
      v_d.id, v_source, v_name, v_code, v_vkind, v_value, v_base, v_amount, v_reason, auth.uid(), p_at);
  return v_amount;
end;
$function$;

comment on function public._discount_apply(uuid, jsonb, jsonb, timestamp with time zone, uuid) is 'Validates a preset, coupon or manual discount against a bill, records it in bill_discounts and returns the paise taken off.';

grant execute
  on function "public"."_discount_apply"(uuid, jsonb, jsonb, timestamp with time zone, uuid)
  to "postgres", "service_role";

revoke all
  on function "public"."_discount_apply"(uuid, jsonb, jsonb, timestamp with time zone, uuid)
  from public;

revoke all on function "public"._discount_apply(p_arena uuid, p_disc jsonb, p_bill jsonb, p_at timestamp with time zone, p_session uuid) from anon;

revoke all on function "public"._discount_apply(p_arena uuid, p_disc jsonb, p_bill jsonb, p_at timestamp with time zone, p_session uuid) from authenticated;
