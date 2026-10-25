-- op_policy_save — sync op 'policy.save': save the arena's billing policy.
--
-- Permission: settings.
-- Payload: policy {billing_unit, block_rounding, grace_minutes, minimum_charge_minutes,
--   early_exit, rounding_scope, late_arrival, vr_unit_rounding, money_rounding_paise,
--   money_rounding_dir, payment_timing, allow_extend_past_close, cleaning_gap_minutes}; every
--   listed field is overwritten; any other key (e.g. a retired group_billing_mode) is ignored.
-- Checks / errors: forbidden; invalid_payload / invalid (bad values, constraint failures).
-- Writes: billing_policies (the oldest active one; a 'Default' row is created if none; _sync_apply
--   then retires the previous price list into pricing_catalog_history). Returns: {}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_policy_save (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare j jsonb := p->'policy'; v_id uuid;
begin
  perform _need(p_arena, 'settings');
  select id into v_id from billing_policies where arena_id = p_arena and active
    order by created_at limit 1 for update;
  if not found then
    insert into billing_policies(arena_id, name) values (p_arena, 'Default') returning id into v_id;
  end if;
  update billing_policies set
      billing_unit = j->>'billing_unit', block_rounding = j->>'block_rounding',
      grace_minutes = (j->>'grace_minutes')::int,
      minimum_charge_minutes = (j->>'minimum_charge_minutes')::int,
      early_exit = j->>'early_exit', rounding_scope = j->>'rounding_scope',
      late_arrival = j->>'late_arrival', vr_unit_rounding = j->>'vr_unit_rounding',
      money_rounding_paise = (j->>'money_rounding_paise')::int,
      money_rounding_dir = j->>'money_rounding_dir', payment_timing = j->>'payment_timing',
      allow_extend_past_close = (j->>'allow_extend_past_close')::boolean,
      cleaning_gap_minutes = (j->>'cleaning_gap_minutes')::int,
      updated_at = statement_timestamp()
    where id = v_id;
  return '{}'::jsonb;
end;
$function$;

comment on function public.op_policy_save(uuid, jsonb) is
  'Sync op policy.save: overwrites the arena''s active billing policy (creating a default one if missing).';

grant execute on function "public"."op_policy_save"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_policy_save"(uuid, jsonb) from public;

revoke all on function "public".op_policy_save(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_policy_save(p_arena uuid, p jsonb) from authenticated;
