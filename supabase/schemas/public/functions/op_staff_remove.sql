-- op_staff_remove(arena, op) — staff.remove: take a staff member off the team for good
--
-- A safe delete. The staff_profiles row stays, because bills, payments and the
-- audit trail point at the login, but everything that identifies the person in
-- this arena is erased: the name becomes 'Deleted member', access goes off with
-- no permissions, removed_at is set, their staff_personal_details row is deleted,
-- and this arena's invitations to them keep no name or e-mail (open ones are
-- withdrawn). The login itself is untouched (it may belong to other arenas), so
-- the same address can be invited again: accept_invite brings the row back.
-- Same authority as turning access off with staff.update: Settings; never an
-- owner (an operator action), never yourself; an owner-level member, or one
-- holding bill_edit / bill_record, only by an owner. Someone must keep Settings.
-- Removing an already removed member is a no-op. Audited without the name.
create or replace function public.op_staff_remove (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_user    uuid := (p->>'user_id')::uuid;
  v_staff   staff_profiles%rowtype;
  v_email   text;
begin
  perform _need(p_arena, 'settings');
  select * into v_staff from staff_profiles
    where arena_id = p_arena and user_id = v_user for update;
  if not found then raise exception 'not_found' using hint = 'staff'; end if;
  if v_staff.removed_at is not null then return '{}'::jsonb; end if;
  if v_staff.role = 'owner' then
    raise exception 'forbidden' using errcode = '42501',
      hint = 'an owner cannot be removed here';
  end if;
  if v_user = auth.uid() then
    raise exception 'forbidden' using errcode = '42501', hint = 'you cannot remove yourself';
  end if;
  if not private.app_is_owner(p_arena)
     and v_staff.perms && array['money', 'reports', 'bill_edit', 'bill_record'] then
    raise exception 'forbidden' using errcode = '42501',
      hint = 'only an owner can remove someone with money, reports or bill access';
  end if;

  select lower(email) into v_email from auth.users where id = v_user;

  update staff_profiles set name = 'Deleted member', perms = '{}', active = false,
      removed_at = statement_timestamp(), updated_at = statement_timestamp()
    where id = v_staff.id;
  delete from staff_personal_details where staff_id = v_staff.id;
  -- Invitations keep no name or address; one still open stops working.
  update staff_invites
     set name = 'Deleted member',
         email = 'deleted-' || replace(id::text, '-', '') || '@deleted.invalid',
         revoked_at = case when accepted_at is null and revoked_at is null
                           then statement_timestamp() else revoked_at end
   where arena_id = p_arena and (accepted_by = v_user or email = v_email);
  perform _assert_settings_holder(p_arena);

  insert into audit_log(arena_id, entity_type, entity_id, action, before, after, created_by, created_at)
    values (p_arena, 'staff_profile', v_staff.id, 'remove',
            jsonb_build_object('perms', to_jsonb(v_staff.perms), 'active', v_staff.active),
            jsonb_build_object('removed', true),
            auth.uid(), statement_timestamp());
  return '{}'::jsonb;
end;
$function$;

comment on function public.op_staff_remove(uuid, jsonb) is 'Sync op staff.remove (Settings): safe delete of a staff member. Keeps the profile row for history but renames it ''Deleted member'', turns access off, erases personal details and anonymises this arena''s invitations to them; the same e-mail can be invited again.';

grant execute on function "public"."op_staff_remove"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_staff_remove"(uuid, jsonb) from public;

revoke all on function "public".op_staff_remove(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_staff_remove(p_arena uuid, p jsonb) from authenticated;
