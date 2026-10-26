-- op_expense_category_upsert — sync op 'expense_category.upsert': create or edit an expense category.
--
-- Permission: money.
-- Payload: id, name, sort_order?, active?.
-- Checks / errors: forbidden; invalid_name (1–40 characters); not_found (hint
--   expense_category: the id belongs to another arena); duplicate (name already used, ignoring
--   case: ux_expense_categories_name).
-- Writes: expense_categories. Returns: {}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_expense_category_upsert (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_id   uuid := (p->>'id')::uuid;
  v_name text := btrim(coalesce(p->>'name', ''));
begin
  perform _need(p_arena, 'money');
  if char_length(v_name) not between 1 and 40 then
    raise exception 'invalid_name' using hint = '1–40 characters';
  end if;
  if exists (select 1 from expense_categories where id = v_id and arena_id <> p_arena) then
    raise exception 'not_found' using hint = 'expense_category';
  end if;

  insert into expense_categories(id, arena_id, name, sort_order, active)
    values (v_id, p_arena, v_name, coalesce((p->>'sort_order')::int, 0),
      coalesce((p->>'active')::boolean, true))
  on conflict (id) do update set
    name = excluded.name, sort_order = excluded.sort_order, active = excluded.active,
    updated_at = statement_timestamp()
  where expense_categories.arena_id = p_arena;
  return '{}'::jsonb;
end;
$function$;

comment on function public.op_expense_category_upsert(uuid, jsonb) is
  'Sync op expense_category.upsert (money): creates or edits an expense category (Rent, Electricity …).';

grant execute on function "public"."op_expense_category_upsert"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_expense_category_upsert"(uuid, jsonb) from public;

revoke all on function "public"."op_expense_category_upsert"(uuid, jsonb) from anon;

revoke all on function "public"."op_expense_category_upsert"(uuid, jsonb) from authenticated;
