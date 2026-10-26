-- arena_expense(arena, id) — one expense with its payments and history, for its detail pane
--
-- Lives in `private`, which the Data API does not expose: SECURITY DEFINER
-- code never sits in an API schema. Clients reach it only through the
-- SECURITY INVOKER wrapper public.arena_expense.
--
-- _expense_json of the expense plus history: its audit_log rows (add, update, payment_reverse,
-- void) oldest first, {action, reason, before, after, at, by_name}.
-- SECURITY DEFINER. Caller must hold money in p_arena (app_has_perm), else 'forbidden';
-- 'not_found' (hint expense) when the arena has no such expense.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.arena_expense (
  p_arena uuid,
  p_id    uuid
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
begin
  if not private.app_has_perm(p_arena, 'money') then
    raise exception 'forbidden' using errcode = '42501', hint = 'needs money';
  end if;
  if not exists (select 1 from expenses where id = p_id and arena_id = p_arena) then
    raise exception 'not_found' using hint = 'expense';
  end if;
  return _expense_json(p_id) || jsonb_build_object('history', coalesce((
    select jsonb_agg(jsonb_build_object(
        'action', a.action, 'reason', a.reason, 'before', a.before, 'after', a.after,
        'at', a.created_at, 'by_name', s.name)
        order by a.created_at, a.id)
      from audit_log a
      left join staff_profiles s on s.user_id = a.created_by and s.arena_id = a.arena_id
     where a.arena_id = p_arena and a.entity_type = 'expense' and a.entity_id = p_id), '[]'::jsonb));
end;
$function$;

comment on function private.arena_expense(uuid, uuid) is 'Client API (money): one expense with its payments (source and payer) and its audit history, for the admin dashboard''s expense detail.';

grant execute on function "private"."arena_expense"(uuid, uuid) to "authenticated", "postgres", "service_role";

revoke all on function "private"."arena_expense"(uuid, uuid) from public;

revoke all on function "private"."arena_expense"(uuid, uuid) from anon;
