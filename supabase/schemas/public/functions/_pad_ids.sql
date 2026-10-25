-- _pad_ids(p) — controller ids of a jsonb array of pad objects.
--
-- Collects e->>'controller_id' of each element as uuid[]; '{}' for null or empty. Parses the
-- 'moves' and 'allocations' payloads of op_session_start, op_session_reconfigure and
-- _pad_allocate.
-- Server-only: not executable by anon/authenticated.
create or replace function public._pad_ids (
  p jsonb
)
  returns uuid[]
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  select coalesce(array_agg((e->>'controller_id')::uuid), '{}')
    from jsonb_array_elements(coalesce(p, '[]'::jsonb)) e;
$function$;

comment on function public._pad_ids(jsonb) is 'Extracts controller_id values from a jsonb array as uuid[].';

grant execute on function "public"."_pad_ids"(jsonb) to "postgres", "service_role";

revoke all on function "public"."_pad_ids"(jsonb) from public;

revoke all on function "public"._pad_ids(p jsonb) from anon;

revoke all on function "public"._pad_ids(p jsonb) from authenticated;
