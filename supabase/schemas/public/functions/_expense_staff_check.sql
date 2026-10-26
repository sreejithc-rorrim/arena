-- _expense_staff_check(arena, staff, newly_chosen) — refuse a person an expense may not name
--
-- Used by the expense and salary ops whenever an expense or agreed salary names a staff member
-- (staff_profiles.id). Errors: not_found (hint staff: not a profile of this arena);
-- staff_removed (only when newly_chosen: the member was removed from the team, so nothing new
-- is recorded for them; their past expenses stay editable); own_record (the caller is that
-- person and not an owner: only an owner records or pays their own salary or expenses, S7).
-- Server-only: not executable by anon/authenticated.
create or replace function public._expense_staff_check (
  p_arena uuid,
  p_staff uuid,
  p_new   boolean
)
  returns void
  language plpgsql
  stable
  set search_path to 'public'
  AS $function$
declare v_user uuid; v_removed timestamptz;
begin
  select user_id, removed_at into v_user, v_removed
    from staff_profiles where id = p_staff and arena_id = p_arena;
  if not found then raise exception 'not_found' using hint = 'staff'; end if;
  if p_new and v_removed is not null then
    raise exception 'staff_removed' using hint = 'this member was removed from the team';
  end if;
  if v_user = auth.uid() and not exists (
       select 1 from staff_profiles
        where arena_id = p_arena and user_id = auth.uid() and role = 'owner' and active) then
    raise exception 'own_record' using hint = 'only an owner records your own salary or expenses';
  end if;
end;
$function$;

comment on function public._expense_staff_check(uuid, uuid, boolean) is 'Internal (expense ops): refuse a staff member of another arena (not_found), a removed one when newly chosen (staff_removed), or the caller''s own record unless they are an owner (own_record).';

grant execute on function "public"."_expense_staff_check"(uuid, uuid, boolean) to "postgres", "service_role";

revoke all on function "public"."_expense_staff_check"(uuid, uuid, boolean) from public;

revoke all on function "public"."_expense_staff_check"(uuid, uuid, boolean) from anon;

revoke all on function "public"."_expense_staff_check"(uuid, uuid, boolean) from authenticated;
