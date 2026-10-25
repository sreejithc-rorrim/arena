-- _offline_rules(p) — validate the arena's offline window (settings key 'offline_rules')
--
-- Shape: {max_offline_hours: n}, nothing else. n = 1–720 whole hours: how old a device-stamped
-- session time may be when it reaches the server (_client_time refuses older ones as
-- time_too_old). Without the setting the window is 24 hours.
-- Raises invalid_offline_rules (hint names the field) otherwise.
-- Server-only: used by op_settings_save; not executable by anon/authenticated.
create or replace function public._offline_rules (
  p jsonb
)
  returns jsonb
  language plpgsql
  immutable
  set search_path to 'public'
  AS $function$
declare v numeric;
begin
  if p is null or jsonb_typeof(p) <> 'object'
     or exists (select 1 from jsonb_object_keys(p) k where k <> 'max_offline_hours')
     or jsonb_typeof(p->'max_offline_hours') is distinct from 'number' then
    raise exception 'invalid_offline_rules' using hint = 'an object of max_offline_hours';
  end if;
  v := (p->>'max_offline_hours')::numeric;
  if v % 1 <> 0 or v < 1 or v > 720 then
    raise exception 'invalid_offline_rules' using hint = 'max_offline_hours: 1–720';
  end if;
  return jsonb_build_object('max_offline_hours', v::int);
end;
$function$;

comment on function public._offline_rules(jsonb) is 'Internal: validate settings key offline_rules ({max_offline_hours: 1–720}); raises invalid_offline_rules.';

grant execute on function "public"."_offline_rules"(jsonb) to "postgres", "service_role";

revoke all on function "public"."_offline_rules"(jsonb) from public;

revoke all on function "public"."_offline_rules"(jsonb) from anon;

revoke all on function "public"."_offline_rules"(jsonb) from authenticated;
