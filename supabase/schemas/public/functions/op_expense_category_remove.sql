-- op_expense_category_remove — sync op 'expense_category.remove': delete an unused category, else retire it.
--
-- Permission: money.
-- Payload: id.
-- A category no expense uses is deleted; one still on some expense (voided ones included) is
-- retired (active = false) so those expenses keep it. Idempotent: an id that is already gone
-- returns {removed: 'deleted'}.
-- Checks / errors: forbidden; not_found (hint expense_category: the id belongs to another arena).
-- Writes: expense_categories. Returns: {removed: 'deleted' | 'retired'}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_expense_category_remove (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare v_id uuid := (p->>'id')::uuid;
begin
  perform _need(p_arena, 'money');
  if exists (select 1 from expense_categories where id = v_id and arena_id <> p_arena) then
    raise exception 'not_found' using hint = 'expense_category';
  end if;
  perform 1 from expense_categories where id = v_id and arena_id = p_arena for update;
  if not found then return jsonb_build_object('removed', 'deleted'); end if;

  if exists (select 1 from expenses where category_id = v_id) then
    update expense_categories set active = false, updated_at = statement_timestamp() where id = v_id;
    return jsonb_build_object('removed', 'retired');
  end if;
  delete from expense_categories where id = v_id;
  return jsonb_build_object('removed', 'deleted');
end;
$function$;

comment on function public.op_expense_category_remove(uuid, jsonb) is
  'Sync op expense_category.remove (money): deletes an expense category nothing uses, or retires one still in use.';

grant execute on function "public"."op_expense_category_remove"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_expense_category_remove"(uuid, jsonb) from public;

revoke all on function "public"."op_expense_category_remove"(uuid, jsonb) from anon;

revoke all on function "public"."op_expense_category_remove"(uuid, jsonb) from authenticated;
