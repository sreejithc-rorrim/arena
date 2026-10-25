-- _sync_hidden(arena) — the sync feeds the caller may not receive
--
-- sync_pull and sync_fetch_entity are SECURITY DEFINER, so they apply the same narrowing as the
-- RLS policies on direct reads (private.app_arena_ids_with): customers need start / members /
-- money / reports; payments, charges and bill discounts need bill / money / reports; coupon
-- definitions (discounts) need discount / settings / money / reports. Role owner holds all.
-- Returns the hidden source names, sorted (the device's pull "scope": when it changes the device
-- re-reads the feed from the start, so newly granted rows arrive).
-- Server-only: not executable by anon/authenticated.
create or replace function public._sync_hidden (
  p_arena uuid
)
  returns text[]
  language sql
  stable
  set search_path to 'public'
  AS $function$
  select coalesce(array_agg(t order by t), '{}') from (
    select unnest(array['customers']) t
     where p_arena not in (select private.app_arena_ids_with(array['start', 'members', 'money', 'reports']))
    union all
    select unnest(array['bill_discounts', 'payments', 'session_charges'])
     where p_arena not in (select private.app_arena_ids_with(array['bill', 'money', 'reports']))
    union all
    select unnest(array['discounts'])
     where p_arena not in (select private.app_arena_ids_with(array['discount', 'settings', 'money', 'reports']))
  ) h;
$function$;

comment on function public._sync_hidden(uuid) is 'Internal: sync sources the caller may not receive (customers / money / coupons by permission), sorted.';

grant execute on function "public"."_sync_hidden"(uuid) to "postgres", "service_role";

revoke all on function "public"."_sync_hidden"(uuid) from public;

revoke all on function "public"."_sync_hidden"(uuid) from anon;

revoke all on function "public"."_sync_hidden"(uuid) from authenticated;
