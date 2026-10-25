-- _sync_sources() — the tables in the change feed and the relation each is read from
--
-- Returns (name, rel): name is the table name the device sees in a change's
-- `t`; rel is the table or sync_v_* view sync_pull reads it from (the views
-- shape a few tables for the device, e.g. bookings carry activity_code).
-- Every rel must expose arena_id and sync_xid. Used by sync_pull; a table
-- missing here never reaches devices.
-- Server-only: not executable by anon/authenticated.
create or replace function public._sync_sources()
  returns table (
    name text,
    rel  text
  )
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  values
    ('arenas','sync_v_arenas'), ('staff_profiles','staff_profiles'),
    ('activities','activities'), ('resources','resources'),
    ('resource_activities','sync_v_resource_activities'), ('controllers','controllers'),
    ('customers','customers'), ('rates','sync_v_rates'),
    ('billing_policies','billing_policies'), ('holidays','holidays'),
    ('game_categories','game_categories'), ('games','games'),
    ('game_controls','game_controls'), ('game_resources','game_resources'),
    ('bookings','sync_v_bookings'), ('sessions','sessions'),
    ('session_segments','session_segments'), ('session_extensions','session_extensions'),
    ('session_charges','session_charges'), ('payments','payments'),
    ('controller_allocations','controller_allocations'),
    ('controller_moves','controller_moves'), ('settings','settings'),
    ('accessory_kinds','accessory_kinds'), ('pricing_rules','pricing_rules'),
    ('discounts','discounts'), ('bill_discounts','bill_discounts')
$function$;

comment on function public._sync_sources() is 'Internal (sync_pull): list of (table name, source relation) pairs that make up the sync change feed.';

grant execute on function "public"."_sync_sources"() to "postgres", "service_role";

revoke all on function "public"."_sync_sources"() from public;

revoke all on function "public"._sync_sources() from anon;

revoke all on function "public"._sync_sources() from authenticated;
