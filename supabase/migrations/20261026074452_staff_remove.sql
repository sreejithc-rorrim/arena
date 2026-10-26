set local check_function_bodies = off;

alter table "public"."staff_profiles"
  add column "removed_at" timestamp with time zone;

create or replace function private.accept_invite (
  p_invite uuid,
  p_token  text
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_inv       staff_invites%rowtype;
  v_email     text;
  v_confirmed timestamptz;
  v_allowed   boolean;
begin
  if auth.uid() is null then
    raise exception 'forbidden' using errcode = '42501', hint = 'sign in first';
  end if;
  select * into v_inv from staff_invites where id = p_invite for update;
  if not found or p_token is null
     or extensions.digest(p_token, 'sha256') <> v_inv.token_hash then
    raise exception 'invite_invalid' using hint = 'this invitation link is not valid';
  end if;
  if v_inv.accepted_at is not null then
    raise exception 'invite_used' using hint = 'this invitation was already accepted';
  end if;
  if v_inv.revoked_at is not null then
    raise exception 'invite_revoked' using hint = 'this invitation was withdrawn';
  end if;
  if v_inv.expires_at <= statement_timestamp() then
    raise exception 'invite_expired' using hint = 'ask for a new invitation';
  end if;
  select lower(email), email_confirmed_at into v_email, v_confirmed
    from auth.users where id = auth.uid();
  if v_email is distinct from v_inv.email then
    raise exception 'invite_wrong_account' using errcode = '42501',
      hint = 'sign in with the e-mail address the invitation was sent to';
  end if;
  if v_confirmed is null then
    raise exception 'email_not_confirmed' using hint = 'confirm your e-mail address first';
  end if;
  -- The inviter's authority is re-checked now: an invite from someone who has
  -- since lost Settings (or ownership) must not still work.
  if v_inv.role = 'owner' then
    v_allowed := exists (select 1 from staff_profiles where arena_id = v_inv.arena_id
                           and user_id = v_inv.invited_by and active and role = 'owner');
  else
    v_allowed := exists (select 1 from staff_profiles where arena_id = v_inv.arena_id
                           and user_id = v_inv.invited_by and active
                           and (role = 'owner' or 'settings' = any(perms))
                           and (not (v_inv.perms && array['money', 'reports'])
                                or role = 'owner' or perms && array['money', 'reports']));
  end if;
  if not v_allowed then
    raise exception 'invite_invalid'
      using hint = 'the person who invited you can no longer add members';
  end if;
  if exists (select 1 from staff_profiles where arena_id = v_inv.arena_id
              and user_id = auth.uid() and role = 'owner') then
    raise exception 'owner_profile' using hint = 'you are already an owner of this arena';
  end if;
  insert into staff_profiles (arena_id, user_id, name, role, perms, active)
    values (v_inv.arena_id, auth.uid(), v_inv.name, v_inv.role, v_inv.perms, true)
  on conflict (user_id, arena_id) do update
    set name = excluded.name, role = excluded.role, perms = excluded.perms, active = true,
        removed_at = null, updated_at = statement_timestamp();
  perform _assert_settings_holder(v_inv.arena_id);
  update staff_invites set accepted_at = statement_timestamp(), accepted_by = auth.uid()
   where id = v_inv.id;
  return jsonb_build_object(
    'arena_id', v_inv.arena_id,
    'arena_name', (select name from arenas where id = v_inv.arena_id),
    'role', v_inv.role);
end;
$function$;

create or replace function private.arena_staff (
  p_arena uuid
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare v_since timestamptz := statement_timestamp() - interval '30 days';
begin
  if not private.app_is_owner(p_arena) then
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can list staff';
  end if;
  return coalesce((
    with money as (
      select created_by, 's:' || session_id::text as bill, amount_paise
        from payments where arena_id = p_arena and created_at >= v_since
    ), per as (
      select created_by,
             count(distinct bill) filter (where amount_paise > 0) as bills,
             coalesce(sum(amount_paise), 0) as net,
             coalesce(-sum(amount_paise) filter (where amount_paise < 0), 0) as refunds
        from money group by created_by
    )
    select jsonb_agg(jsonb_build_object(
        'user_id', s.user_id, 'name', s.name,
        'email', case when s.removed_at is null then u.email
                      else left(u.email, 1) || '•••@' || split_part(u.email, '@', 2) end,
        'role', s.role, 'perms', to_jsonb(s.perms), 'active', s.active,
        'removed', s.removed_at is not null,
        'invited', u.last_sign_in_at is null,
        'bills_30d', coalesce(p.bills, 0), 'takings_30d_paise', coalesce(p.net, 0),
        'refunds_30d_paise', coalesce(p.refunds, 0))
      order by s.role = 'owner' desc, lower(s.name))
      from staff_profiles s
      join auth.users u on u.id = s.user_id
      left join per p on p.created_by = s.user_id
     where s.arena_id = p_arena), '[]'::jsonb);
end;
$function$;

create or replace function public._sync_apply (
  p_arena uuid,
  p_kind  text,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare v_before jsonb; v_res jsonb;
begin
  -- A price-list change retires the previous catalog into
  -- pricing_catalog_history, so a session priced on it still validates.
  if p_kind in ('rate.upsert', 'rate.delete', 'policy.save', 'settings.save',
                'holiday.upsert', 'holiday.delete', 'activity.upsert', 'activity.remove',
                'rule.upsert', 'rule.delete', 'rule.reorder') then
    v_before := _pricing_canon(_pricing_snapshot(p_arena));
  end if;

  -- Dispatch: one op kind -> one op_* function. Unknown kinds return null and
  -- sync_push rejects them.
  v_res := case p_kind
      when 'session.start'        then op_session_start(p_arena, p)
      when 'session.reconfigure'  then op_session_reconfigure(p_arena, p)
      when 'session.extend'       then op_session_extend(p_arena, p)
      when 'session.end'          then op_session_end(p_arena, p)
      when 'session.void'         then op_session_void(p_arena, p)
      when 'session.record'       then op_session_record(p_arena, p)
      when 'payment.record'       then op_payment(p_arena, p)
      when 'payment.correct'      then op_payment_correct(p_arena, p)
      when 'bill.adjust'          then op_bill_adjust(p_arena, p)
      when 'controller.move'      then op_controller_move(p_arena, p)
      when 'controller.upsert'    then op_controller_upsert(p_arena, p)
      when 'controller.set_status' then op_controller_set_status(p_arena, p)
      when 'accessory_kind.upsert' then op_accessory_kind_upsert(p_arena, p)
      when 'accessory_kind.remove' then op_accessory_kind_remove(p_arena, p)
      when 'customer.create'      then op_customer_create(p_arena, p)
      when 'customer.update'      then op_customer_update(p_arena, p)
      when 'booking.create'       then op_booking_create(p_arena, p)
      when 'booking.update'       then op_booking_update(p_arena, p)
      when 'booking.set_status'   then op_booking_set_status(p_arena, p)
      when 'game.upsert'          then op_game_upsert(p_arena, p)
      when 'game.set_active'      then op_game_set_active(p_arena, p)
      when 'game.delete'          then op_game_delete(p_arena, p)
      when 'game.replace_controls' then op_game_replace_controls(p_arena, p)
      when 'game.set_compat'      then op_game_set_compat(p_arena, p)
      when 'resource.upsert'      then op_resource_upsert(p_arena, p)
      when 'resource.set_status'  then op_resource_set_status(p_arena, p)
      when 'resource.set_mode'    then op_resource_set_mode(p_arena, p)
      when 'activity.upsert'      then op_activity_upsert(p_arena, p)
      when 'activity.remove'      then op_activity_remove(p_arena, p)
      when 'rate.upsert'          then op_rate_upsert(p_arena, p)
      when 'rate.delete'          then op_rate_delete(p_arena, p)
      when 'policy.save'          then op_policy_save(p_arena, p)
      when 'settings.save'        then op_settings_save(p_arena, p)
      when 'holiday.upsert'       then op_holiday_upsert(p_arena, p)
      when 'holiday.delete'       then op_holiday_delete(p_arena, p)
      when 'rule.upsert'          then op_rule_upsert(p_arena, p)
      when 'rule.delete'          then op_rule_delete(p_arena, p)
      when 'rule.reorder'         then op_rule_reorder(p_arena, p)
      when 'discount.upsert'      then op_discount_upsert(p_arena, p)
      when 'discount.set_active'  then op_discount_set_active(p_arena, p)
      when 'discount.delete'      then op_discount_delete(p_arena, p)
      when 'staff.update'         then op_staff_update(p_arena, p)
      when 'staff.remove'         then op_staff_remove(p_arena, p)
      when 'arena.update'         then op_arena_update(p_arena, p)
      when 'staff_details.save'   then op_staff_details_save(p_arena, p)
      when 'terms.publish'        then op_terms_publish(p_arena, p)
      when 'terms.accept'         then op_terms_accept(p_arena, p)
      else null
    end;

  if v_before is not null and v_before <> _pricing_canon(_pricing_snapshot(p_arena)) then
    insert into pricing_catalog_history(arena_id, canon, retired_at)
      values (p_arena, v_before, statement_timestamp())
    on conflict (arena_id, canon_md5) do update set retired_at = excluded.retired_at;
  end if;
  return v_res;
end;
$function$;

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

create or replace function public.op_staff_update (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  -- money / reports make a member "owner level" (app_is_owner, and the app's
  -- AppUser.isOwner). Only an owner-level member may hand them out or take them away.
  c_owner_perms constant text[] := array['money', 'reports'];
  v_user   uuid    := (p->>'user_id')::uuid;
  -- A field the op leaves out keeps its current value: a partial update must
  -- never wipe someone's permissions or silently reactivate them.
  v_perms  text[]  := case when p ? 'perms'
                        then array(select jsonb_array_elements_text(coalesce(p->'perms', '[]'::jsonb))) end;
  v_active boolean := (p->>'active')::boolean;
  v_role   text;
  v_old_perms  text[];
  v_old_active boolean;
  v_adj    boolean := false;
begin
  perform _need(p_arena, 'settings');
  -- A removed member (op_staff_remove) is gone: only a new invitation brings them back.
  select role, perms, active into v_role, v_old_perms, v_old_active from staff_profiles
    where arena_id = p_arena and user_id = v_user and removed_at is null for update;
  if not found then raise exception 'not_found' using hint = 'staff'; end if;
  v_perms := coalesce(v_perms, v_old_perms);
  v_active := coalesce(v_active, v_old_active);
  perform _assert_known_perms(v_perms);

  if v_role = 'owner' then
    if not exists (select 1 from staff_profiles where arena_id = p_arena
         and user_id = auth.uid() and active and role = 'owner') then
      raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can change an owner';
    end if;
    -- The server already treats a role owner as holding everything
    -- (app_has_perm); the app reads the perms list. Keep the list complete and
    -- the profile active so both agree and the arena always has an owner.
    -- Removing an owner is an operator action on the database, not an op.
    v_adj := not (v_perms @> _known_perms()) or not v_active;
    v_perms := _known_perms();
    v_active := true;
  else
    -- Nobody changes their own access: a Settings holder could otherwise grant
    -- themselves money/reports and become owner level.
    if v_user = auth.uid()
       and (not (v_perms @> v_old_perms and v_old_perms @> v_perms) or v_active <> v_old_active) then
      raise exception 'forbidden' using errcode = '42501',
        hint = 'you cannot change your own permissions';
    end if;
    -- Owner-level perms, and owner-level members, are managed by owners only.
    if not private.app_is_owner(p_arena)
       and (v_old_perms && c_owner_perms
            or ('money' = any(v_perms)) <> ('money' = any(v_old_perms))
            or ('reports' = any(v_perms)) <> ('reports' = any(v_old_perms))) then
      raise exception 'forbidden' using errcode = '42501',
        hint = 'only an owner can grant money or reports, or change an owner-level member';
    end if;
    -- Editing closed bills or adding missed ones records money: owners only hand out
    -- bill_edit and bill_record.
    if not private.app_is_owner(p_arena)
       and (('bill_edit' = any(v_perms)) <> ('bill_edit' = any(v_old_perms))
            or ('bill_record' = any(v_perms)) <> ('bill_record' = any(v_old_perms))) then
      raise exception 'forbidden' using errcode = '42501',
        hint = 'only an owner can grant or remove editing or adding bills';
    end if;
  end if;

  update staff_profiles set name = coalesce(nullif(btrim(p->>'name'), ''), name),
      perms = v_perms, active = v_active,
      sort_order = coalesce((p->>'sort_order')::int, sort_order),
      updated_at = statement_timestamp()
    where arena_id = p_arena and user_id = v_user;
  perform _assert_settings_holder(p_arena);
  -- Access changes are audited with the before and after (permissions edit in place).
  insert into audit_log(arena_id, entity_type, entity_id, action, before, after, created_by, created_at)
    select p_arena, 'staff_profile', s.id, 'access',
           jsonb_build_object('perms', to_jsonb(v_old_perms), 'active', v_old_active),
           jsonb_build_object('perms', to_jsonb(s.perms), 'active', s.active),
           auth.uid(), statement_timestamp()
      from staff_profiles s
     where s.arena_id = p_arena and s.user_id = v_user
       and (s.perms is distinct from v_old_perms or s.active is distinct from v_old_active);
  -- adjusted = the device wrote something else: it refetches the staff list.
  return case when v_adj then '{"adjusted": true}'::jsonb else '{}'::jsonb end;
end;
$function$;

comment on column "public"."staff_profiles"."removed_at" is 'Set when the member was removed (op_staff_remove): the row is kept so their bills keep a creator, but the name is replaced by ''Deleted member'', access is off and personal details are erased. Cleared when the same login accepts a new invitation.';

comment on function "public"."op_staff_remove"(uuid, jsonb) is 'Sync op staff.remove (Settings): safe delete of a staff member. Keeps the profile row for history but renames it ''Deleted member'', turns access off, erases personal details and anonymises this arena''s invitations to them; the same e-mail can be invited again.';

revoke all on function "public"."op_staff_remove"(uuid, jsonb) from public;

grant execute on function "public"."op_staff_remove"(uuid, jsonb) to "postgres", "service_role";
