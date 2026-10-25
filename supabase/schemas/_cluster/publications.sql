-- supabase_realtime — tables whose changes Supabase Realtime announces
--
-- Every arena table either app shows live. Postgres Changes deliver INSERT and
-- UPDATE rows only to subscribers whose RLS SELECT policy allows the row, and
-- both apps filter on arena_id. Clients subscribe to INSERT/UPDATE only:
-- Supabase neither RLS-checks nor filters DELETE events (they would carry other
-- arenas' row ids), so deletions travel as the authorized broadcast nudge on
-- the private arena channel (realtime/policies.sql). Events only trigger a
-- refetch / sync_pull; no client treats a payload as data.
alter publication "supabase_realtime" add table "public"."accessory_kinds";
alter publication "supabase_realtime" add table "public"."activities";
alter publication "supabase_realtime" add table "public"."bill_discounts";
alter publication "supabase_realtime" add table "public"."billing_policies";
alter publication "supabase_realtime" add table "public"."bookings";
alter publication "supabase_realtime" add table "public"."controller_allocations";
alter publication "supabase_realtime" add table "public"."controller_moves";
alter publication "supabase_realtime" add table "public"."controllers";
alter publication "supabase_realtime" add table "public"."customers";
alter publication "supabase_realtime" add table "public"."discounts";
alter publication "supabase_realtime" add table "public"."game_categories";
alter publication "supabase_realtime" add table "public"."game_controls";
alter publication "supabase_realtime" add table "public"."game_resources";
alter publication "supabase_realtime" add table "public"."games";
alter publication "supabase_realtime" add table "public"."holidays";
alter publication "supabase_realtime" add table "public"."payments";
alter publication "supabase_realtime" add table "public"."pricing_rules";
alter publication "supabase_realtime" add table "public"."rate_bands";
alter publication "supabase_realtime" add table "public"."rate_cards";
alter publication "supabase_realtime" add table "public"."rates";
alter publication "supabase_realtime" add table "public"."resource_activities";
alter publication "supabase_realtime" add table "public"."resources";
alter publication "supabase_realtime" add table "public"."session_charges";
alter publication "supabase_realtime" add table "public"."session_extensions";
alter publication "supabase_realtime" add table "public"."session_segments";
alter publication "supabase_realtime" add table "public"."sessions";
alter publication "supabase_realtime" add table "public"."settings";
alter publication "supabase_realtime" add table "public"."staff_profiles";
