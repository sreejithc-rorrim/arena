-- _same_ids(a, b) — do two uuid arrays hold the same set of ids?
--
-- Compares as sets: order and duplicates are ignored, null counts as empty.
-- Used by op_session_end to check that the segments
-- the device priced are exactly the ones the server holds.
-- Server-only: not executable by anon/authenticated.
create or replace function public._same_ids (
  a uuid[],
  b uuid[]
)
  returns boolean
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  select coalesce((select array_agg(distinct x order by x) from unnest(a) x), '{}')
       = coalesce((select array_agg(distinct x order by x) from unnest(b) x), '{}');
$function$;

comment on function public._same_ids(uuid[], uuid[]) is 'Internal: true when both uuid arrays contain the same distinct ids, ignoring order and duplicates (null is treated as empty).';

grant execute on function "public"."_same_ids"(uuid[], uuid[]) to "postgres", "service_role";

revoke all on function "public"."_same_ids"(uuid[], uuid[]) from public;

revoke all on function "public"._same_ids(a uuid[], b uuid[]) from anon;

revoke all on function "public"._same_ids(a uuid[], b uuid[]) from authenticated;
