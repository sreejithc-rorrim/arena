-- _assert_snapshot(p_arena, s) — refuse a device price list that is not the arena's.
--
-- Passes when _pricing_canon(s) equals the canon of _pricing_snapshot(p_arena), or of a list in
-- pricing_catalog_history retired within _pricing_grace() (looked up by canon_md5, then canon).
-- Otherwise, or when s is null / not an object, raises 'pricing_snapshot_mismatch'.
-- Called after the op body by op_session_start, so earlier refusals keep their codes.
-- Server-only: not executable by anon/authenticated.
create or replace function public._assert_snapshot (
  p_arena uuid,
  s       jsonb
)
  returns void
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare c jsonb := _pricing_canon(s);
begin
  if s is null or jsonb_typeof(s) <> 'object' then
    raise exception 'pricing_snapshot_mismatch' using hint = 'no price list was sent';
  end if;
  if c = _pricing_canon(_pricing_snapshot(p_arena)) then return; end if;
  if exists (select 1 from pricing_catalog_history
              where arena_id = p_arena and canon_md5 = md5(c::text) and canon = c
                and retired_at >= statement_timestamp() - _pricing_grace()) then
    return;
  end if;
  raise exception 'pricing_snapshot_mismatch'
    using hint = 'the price list on this device is not the arena''s; sync and start again';
end;
$function$;

comment on function public._assert_snapshot(uuid, jsonb) is 'Pricing: raises pricing_snapshot_mismatch unless a device snapshot equals the arena''s live or recently retired price list.';

grant execute on function "public"."_assert_snapshot"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."_assert_snapshot"(uuid, jsonb) from public;

revoke all on function "public"._assert_snapshot(p_arena uuid, s jsonb) from anon;

revoke all on function "public"._assert_snapshot(p_arena uuid, s jsonb) from authenticated;
