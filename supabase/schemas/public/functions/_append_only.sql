-- _append_only() — trigger: money, audit and evidence rows are never edited or deleted
--
-- BEFORE UPDATE OR DELETE row trigger (t_<table>_append_only) on payments, session_charges,
-- bill_discounts, audit_log and controller_moves. Corrections are new rows (refunds, reversals,
-- superseding entries), so no op changes these; the trigger makes that hold against a
-- dashboard / SQL-editor delete, a cascade from a deleted session or arena, a script or a
-- future op bug. Raises append_only. An operator who must really remove test data uses
-- supabase/audit/prod_prerelease_reset.sql, which disables these triggers inside its own
-- transaction with foreign keys still enforced (docs/DEPLOY_SUPABASE.md, Backups). Never
-- `session_replication_role = replica`: it also skips every foreign-key cascade and check.
-- Server-only: not executable by anon/authenticated.
create or replace function public._append_only()
  returns trigger
  language plpgsql
  set search_path to 'public'
  AS $function$
begin
  raise exception 'append_only' using errcode = '55000',
    hint = tg_table_name || ' rows are never ' || lower(tg_op) || 'd: record a correction instead';
end;
$function$;

comment on function public._append_only() is 'Trigger (before update or delete on money, audit and evidence tables): raise append_only; corrections are new rows.';

grant execute on function "public"."_append_only"() to "postgres", "service_role";

revoke all on function "public"."_append_only"() from public;

revoke all on function "public"."_append_only"() from anon;

revoke all on function "public"."_append_only"() from authenticated;
