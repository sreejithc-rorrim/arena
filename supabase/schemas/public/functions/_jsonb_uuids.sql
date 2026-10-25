-- _jsonb_uuids(arr) — jsonb array of uuid strings -> uuid[]
--
-- Null or empty input gives '{}'; an element that is not a uuid raises
-- (22P02, reported by sync_push as 'invalid_payload'). Used by op_session_end
-- (expected_segment_ids) and op_rule_reorder.
-- Server-only: not executable by anon/authenticated.
create or replace function public._jsonb_uuids (
  p jsonb
)
  returns uuid[]
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  select coalesce(array_agg(value::text::uuid), '{}')
    from jsonb_array_elements_text(coalesce(p, '[]'::jsonb)) value;
$function$;

comment on function public._jsonb_uuids(jsonb) is 'Internal: convert a jsonb array of uuid strings to uuid[] (empty array for null).';

grant execute on function "public"."_jsonb_uuids"(jsonb) to "postgres", "service_role";

revoke all on function "public"."_jsonb_uuids"(jsonb) from public;

revoke all on function "public"._jsonb_uuids(p jsonb) from anon;

revoke all on function "public"._jsonb_uuids(p jsonb) from authenticated;
