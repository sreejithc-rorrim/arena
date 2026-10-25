-- _sales(arena, from, to, id) — closed bills of an arena as one jsonb object each
--
-- A bill is a sessions row (kind is always 'single') that is no longer
-- active: completed or voided. Its time `at` is when
-- it closed: actual_ended_at, or for a bill voided while it ran (never ended)
-- the void (updated_at). With p_id set, returns that one bill (any time);
-- otherwise the bills with p_from <= at < p_to. Each object:
--   {kind, id, at, started_at, ended_at, recorded_at, status, payment_status,
--    customer, guest, returning, stations[], activities[], games[], players,
--    player_minutes, billed_paise, paid_paise, refunded_paise,
--    methods{method: net paise}, payments[], started_by, void_reason,
--    voided_at, voided_by, discount_paise, discount}
-- stations/activities/games are names in play order; recorded_at is when the
-- server received the start (the device stamps started_at; see sessions);
-- returning is true when the customer (never a walk-in guest) has an earlier
-- completed bill in this arena; players is the session's largest controller
-- count (1 when the activity has no controllers); player_minutes is the time
-- played times the players on it (segments x controllers); paid_paise is
-- the net of the payments ledger (refunds negative), refunded_paise the money
-- given back as a positive sum (the refund rows of a payment-method correction
-- are not refunds and are left out), methods the net per payment method,
-- payments[] the ledger in time order {id, at, amount_paise, method, refund,
-- correction, reason, note, by} where correction marks the two rows each
-- payment.correct wrote (op_payment_correct; their ids are in its audit entry);
-- started_by / voided_by / by are staff names; voided_at / voided_by come from
-- the first void in the audit log; discount is the bill_discounts row {source,
-- name, code, discount_id, value_kind, value, base_paise, amount_paise, reason,
-- by} or null, discount_paise its amount (0 without one). Unordered. Shared body of arena_sales and
-- arena_sale, which check the caller. Server-only: not executable by
-- anon/authenticated.
create or replace function public._sales (
  p_arena uuid,
  p_from  timestamptz,
  p_to    timestamptz,
  p_id    uuid default null
)
  returns setof jsonb
  language sql
  stable
  set search_path to 'public'
  AS $function$
  select jsonb_build_object(
      'kind', 'single', 'id', s.id, 'at', b.at,
      'started_at', s.started_at, 'ended_at', s.actual_ended_at, 'recorded_at', s.created_at, 'end_recorded_at', s.ended_recorded_at,
      'status', s.status, 'payment_status', s.payment_status,
      'customer', c.name, 'guest', c.is_guest,
      'returning', not c.is_guest and
        exists (select 1 from sessions o
                 where o.customer_id = s.customer_id and o.arena_id = s.arena_id
                   and o.id <> s.id and o.status = 'completed' and o.started_at < s.started_at),
      'stations', seg.stations, 'activities', seg.activities, 'games', seg.games,
      'players', seg.players, 'player_minutes', seg.player_minutes,
      'billed_paise', s.billed_amount_paise, 'paid_paise', pay.net,
      'refunded_paise', pay.refunded, 'methods', pay.methods, 'payments', pay.ledger,
      'started_by', sp.name, 'void_reason', s.void_reason,
      'voided_at', vd.at, 'voided_by', vd.by,
      'discount_paise', coalesce(dsc.amount, 0), 'discount', dsc.j)
    from sessions s
    cross join lateral (select coalesce(s.actual_ended_at, s.updated_at) as at) b
    join customers c on c.id = s.customer_id
    left join staff_profiles sp on sp.arena_id = s.arena_id and sp.user_id = s.created_by
    cross join lateral (
      select coalesce((select jsonb_agg(x.name order by x.first)
                         from (select r.name, min(g.idx) as first
                                 from session_segments g join resources r on r.id = g.resource_id
                                where g.session_id = s.id group by r.name) x), '[]'::jsonb) as stations,
             coalesce((select jsonb_agg(x.name order by x.first)
                         from (select a.name, min(g.idx) as first
                                 from session_segments g
                                 join activities a on a.arena_id = g.arena_id and a.code = g.activity_code
                                where g.session_id = s.id group by a.name) x), '[]'::jsonb) as activities,
             coalesce((select jsonb_agg(x.name order by x.first)
                         from (select gm.name, min(g.idx) as first
                                 from session_segments g join games gm on gm.id = g.game_id
                                where g.session_id = s.id group by gm.name) x), '[]'::jsonb) as games,
             coalesce((select max(g.controller_count) from session_segments g
                        where g.session_id = s.id), 1) as players,
             coalesce((select round(sum(extract(epoch from (coalesce(g.ended_at, b.at) - g.started_at))
                                        / 60.0 * coalesce(g.controller_count, 1)))::int
                         from session_segments g where g.session_id = s.id), 0) as player_minutes
    ) seg
    cross join lateral (
      select coalesce(array_agg(x.id), '{}'::uuid[]) as ids
        from audit_log l
        cross join lateral (values ((l.after->>'refund_id')::uuid), ((l.after->>'payment_id')::uuid)) x(id)
       where l.arena_id = s.arena_id and l.entity_type = 'session' and l.entity_id = s.id
         and l.action = 'payment_correct'
    ) corr
    cross join lateral (
      select coalesce(sum(p.amount_paise), 0) as net,
             coalesce(-sum(p.amount_paise) filter (where p.amount_paise < 0
                                                    and p.id <> all (corr.ids)), 0) as refunded,
             coalesce((select jsonb_object_agg(m.method, m.net)
                         from (select method, sum(amount_paise) as net from payments
                                where session_id = s.id group by method) m), '{}'::jsonb) as methods,
             coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'at', q.created_at,
                                 'amount_paise', q.amount_paise, 'method', q.method,
                                 'refund', q.kind = 'refund', 'correction', q.id = any (corr.ids),
                                 'reason', q.reason, 'note', q.note, 'by', sq.name)
                               order by q.created_at, q.id)
                         from payments q
                         left join staff_profiles sq on sq.arena_id = q.arena_id and sq.user_id = q.created_by
                        where q.session_id = s.id), '[]'::jsonb) as ledger
        from payments p where p.session_id = s.id
    ) pay
    left join lateral (
      select l.created_at as at, sv.name as by
        from audit_log l
        left join staff_profiles sv on sv.arena_id = l.arena_id and sv.user_id = l.created_by
       where l.arena_id = s.arena_id and l.entity_type = 'session' and l.entity_id = s.id
         and l.action = 'void'
       order by l.created_at limit 1
    ) vd on true
    left join lateral (
      select d.amount_paise as amount,
             jsonb_build_object('source', d.source, 'name', d.name, 'code', d.code,
               'discount_id', d.discount_id, 'value_kind', d.value_kind, 'value', d.value,
               'base_paise', d.base_paise, 'amount_paise', d.amount_paise, 'reason', d.reason,
               'by', sd.name) as j
        from bill_discounts d
        left join staff_profiles sd on sd.arena_id = d.arena_id and sd.user_id = d.applied_by
       where d.session_id = s.id
    ) dsc on true
   where s.arena_id = p_arena and s.status <> 'active'
     and (case when p_id is null then b.at >= p_from and b.at < p_to else s.id = p_id end);
$function$;

comment on function public._sales(uuid, timestamptz, timestamptz, uuid) is 'Closed bills (completed or voided sessions) of an arena as jsonb summaries with their payments ledger, by close time range or by id. Server-only body of arena_sales / arena_sale.';

grant execute on function "public"."_sales"(uuid, timestamptz, timestamptz, uuid) to "postgres", "service_role";

revoke all on function "public"."_sales"(uuid, timestamptz, timestamptz, uuid) from public;

revoke all on function "public"._sales(p_arena uuid, p_from timestamptz, p_to timestamptz, p_id uuid) from anon;

revoke all on function "public"._sales(p_arena uuid, p_from timestamptz, p_to timestamptz, p_id uuid) from authenticated;
