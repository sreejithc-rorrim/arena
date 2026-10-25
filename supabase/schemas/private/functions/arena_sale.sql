-- arena_sale(arena, id) — one bill in full for the owner dashboard
--
-- Lives in `private`, which the Data API does not expose: SECURITY DEFINER
-- code never sits in an API schema. Clients reach it only through the
-- SECURITY INVOKER wrapper public.arena_sale.
--
-- The _sales summary of the closed session p_id, plus:
--   lines[]      — its charge lines in time order: {player, station,
--                  activity, band, controllers, start, end, played_minutes,
--                  billed_minutes, unit_minutes, unit_price_paise,
--                  amount_paise} (player is always null);
--   extensions[] — {at, added_minutes, added_amount_paise, reason, by};
--   history[]    — every audit_log entry of the bill in time order: {at,
--                  action (void | waive | payment_correct), by, reason, before,
--                  after};
--   voided       — {at, by, reason} from the first void in the audit log, or
--                  null;
--   rule         — the pricing rule the bill was priced with (judged at its
--                  start on its frozen snapshot): {name, adjust_kind,
--                  adjust_value}, or null.
-- The payments ledger (payments[]) comes with the _sales summary.
-- `by` is the staff name of the login that did it. 'not_found' when p_id is not
-- a closed bill of p_arena. SECURITY DEFINER. Caller must be owner level in
-- p_arena (app_is_owner), else 'forbidden'.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.arena_sale (
  p_arena uuid,
  p_id    uuid
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare v_bill jsonb;
begin
  if not private.app_is_owner(p_arena) then
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can read sales';
  end if;
  select b into v_bill from _sales(p_arena, null, null, p_id) b;
  if v_bill is null then raise exception 'not_found' using hint = 'bill'; end if;

  v_bill := v_bill || jsonb_build_object(
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
          'player', null, 'station', r.name, 'activity', coalesce(a.name, ch.activity_code),
          'band', ch.band_code, 'controllers', ch.controller_count,
          'start', ch.segment_start, 'end', ch.segment_end,
          'played_minutes', ch.played_minutes, 'billed_minutes', ch.billed_minutes,
          'unit_minutes', ch.unit_minutes, 'unit_price_paise', ch.unit_price_paise,
          'amount_paise', ch.amount_paise)
        order by ch.segment_start, ch.segment_index)
        from session_charges ch
        left join resources r on r.id = ch.resource_id
        left join activities a on a.arena_id = ch.arena_id and a.code = ch.activity_code
       where ch.session_id = p_id), '[]'::jsonb),
    'extensions', coalesce((
      select jsonb_agg(jsonb_build_object('at', e.created_at, 'added_minutes', e.added_minutes,
          'added_amount_paise', e.added_amount_paise, 'reason', e.reason, 'by', sp.name)
        order by e.created_at)
        from session_extensions e
        left join staff_profiles sp on sp.arena_id = e.arena_id and sp.user_id = e.created_by
       where e.session_id = p_id), '[]'::jsonb),
    'rule', (
      select _pr_rule(s.pricing_snapshot, g.activity_code, s.started_at)
        from sessions s
        join lateral (select activity_code from session_segments
                       where session_id = s.id order by idx limit 1) g on true
       where s.id = p_id));

  return v_bill || jsonb_build_object(
    'history', coalesce((
      select jsonb_agg(jsonb_build_object('at', l.created_at, 'action', l.action, 'by', sp.name,
          'reason', l.reason, 'before', l.before, 'after', l.after)
        order by l.created_at, l.id)
        from audit_log l
        left join staff_profiles sp on sp.arena_id = l.arena_id and sp.user_id = l.created_by
       where l.arena_id = p_arena and l.entity_id = p_id
         and l.entity_type = 'session'),
      '[]'::jsonb),
    'voided', (
      select jsonb_build_object('at', l.created_at, 'by', sp.name, 'reason', l.reason)
        from audit_log l
        left join staff_profiles sp on sp.arena_id = l.arena_id and sp.user_id = l.created_by
       where l.arena_id = p_arena and l.entity_id = p_id and l.action = 'void'
       order by l.created_at limit 1));
end;
$function$;

comment on function private.arena_sale(uuid, uuid) is 'Client API (owner level): one closed bill with its charge lines, extensions, payments ledger, audit history and void record, for the admin dashboard''s Sales detail.';

grant execute on function "private"."arena_sale"(uuid, uuid) to "authenticated", "postgres", "service_role";

revoke all on function "private"."arena_sale"(uuid, uuid) from public;

revoke all on function "private".arena_sale(p_arena uuid, p_id uuid) from anon;
