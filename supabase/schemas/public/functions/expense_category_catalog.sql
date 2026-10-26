-- expense_category_catalog() — client API: the global list of ready-made expense categories
--
-- What an owner picks from in Expenses › Categories → Standard categories (their own stay
-- available). Picking one sends the ordinary expense_category.upsert with that name, and the
-- owner's copy is then theirs to rename or retire: nothing here is checked by any op. Staff
-- salary is not here: salaries are recorded per person and period (expenses kind 'salary').
-- Each entry: name (an expense_categories name, 1–40 characters).
-- Data lives in the function body so it ships with the schema to every environment.
-- Reads no table; runs as the caller.
create or replace function public.expense_category_catalog ()
  returns jsonb
  language sql
  immutable
  security invoker
  set search_path to ''
  AS $function$
  select '[
    {"name": "Rent"},
    {"name": "Electricity"},
    {"name": "Internet"},
    {"name": "Water"},
    {"name": "Repairs"},
    {"name": "Maintenance"},
    {"name": "Equipment"},
    {"name": "Cleaning"},
    {"name": "Supplies"},
    {"name": "Other"}
  ]'::jsonb;
$function$;

comment on function public.expense_category_catalog() is 'Client API: the global catalog of ready-made expense categories (name) an owner picks from; reads no table.';

revoke all on function "public"."expense_category_catalog"() from public;

revoke all on function "public"."expense_category_catalog"() from anon;

revoke all on function "public"."expense_category_catalog"() from authenticated;

grant execute on function "public"."expense_category_catalog"() to "authenticated", "postgres", "service_role";
