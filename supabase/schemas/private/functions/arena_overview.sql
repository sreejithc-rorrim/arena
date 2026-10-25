-- arena_overview(arena, from, to, prev_from, prev_to, bucket, today) — the Overview's figures
--
-- Lives in `private`; clients reach it only through the SECURITY INVOKER wrapper
-- public.arena_overview. Everything is aggregated here, so the dashboard reads a
-- few hundred bytes instead of every bill of the period and the one before it.
--
-- Bills are the closed ones of _sales, by close time; voided bills never count.
-- Returns:
--   totals    {takings_paise (collected), bills, minutes (bill start → end),
--              discount_paise, discounts (bills with one)} over [p_from, p_to);
--   previous  {takings_paise, bills, minutes} over [p_prev_from, p_prev_to);
--   buckets   [{start, paise}] collected per IST p_bucket ('hour' | 'day' |
--              'month'), start = the bucket's first instant, empty ones left out;
--   methods   {method: {paise (net), bills (paid some that way)}};
--   by_type   {activity code: billed paise} from charge lines by segment start;
--   top_games [{name, minutes}] five most played (a bill's time shared between
--              its games);
--   by_staff  [{name, bills, paise}] by who started the bill, most collected first;
--   latest    the eight newest bills closed since p_today (any status), as
--              _sales objects.
-- Ranges are capped at 400 days ('invalid_range'). SECURITY DEFINER. Caller must
-- be owner level in p_arena (app_is_owner), else 'forbidden'.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.arena_overview (
  p_arena     uuid,
  p_from      timestamp with time zone,
  p_to        timestamp with time zone,
  p_prev_from timestamp with time zone,
  p_prev_to   timestamp with time zone,
  p_bucket    text,
  p_today     timestamp with time zone
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare v_out jsonb;
begin
  if not private.app_is_owner(p_arena) then
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can read sales';
  end if;
  if p_from is null or p_to is null or p_to <= p_from or p_to - p_from > interval '400 days'
     or p_prev_from is null or p_prev_to is null or p_prev_to < p_prev_from
     or p_prev_to - p_prev_from > interval '400 days'
     or p_bucket is null or p_bucket not in ('hour', 'day', 'month') then
    raise exception 'invalid_range' using hint = 'up to 400 days; bucket hour, day or month';
  end if;

  with cur as (
    select x as b, (x->>'at')::timestamptz as at from _sales(p_arena, p_from, p_to) x
  ), live as (
    select b, at from cur where b->>'status' <> 'voided'
  ), prev as (
    select x as b from _sales(p_arena, p_prev_from, p_prev_to) x where x->>'status' <> 'voided'
  )
  select jsonb_build_object(
    'totals', (select jsonb_build_object(
        'takings_paise', coalesce(sum((b->>'paid_paise')::bigint), 0),
        'bills', count(*),
        'minutes', coalesce(sum(_bill_minutes(b)), 0),
        'discount_paise', coalesce(sum((b->>'discount_paise')::bigint), 0),
        'discounts', count(*) filter (where (b->>'discount_paise')::bigint > 0)) from live),
    'previous', (select jsonb_build_object(
        'takings_paise', coalesce(sum((b->>'paid_paise')::bigint), 0),
        'bills', count(*),
        'minutes', coalesce(sum(_bill_minutes(b)), 0)) from prev),
    'buckets', coalesce((select jsonb_agg(jsonb_build_object('start', k, 'paise', paise) order by k)
        from (select date_trunc(p_bucket, at at time zone 'Asia/Kolkata') at time zone 'Asia/Kolkata' as k,
                     sum((b->>'paid_paise')::bigint) as paise
                from live group by 1) t), '[]'::jsonb),
    'methods', coalesce((select jsonb_object_agg(m, jsonb_build_object('paise', paise, 'bills', bills))
        from (select e.key as m, sum(e.value::bigint) as paise,
                     count(*) filter (where e.value::bigint > 0) as bills
                from live, jsonb_each_text(b->'methods') e group by e.key) t), '{}'::jsonb),
    'by_type', coalesce((select jsonb_object_agg(code, paise)
        from (select ch.activity_code as code, sum(ch.amount_paise) as paise
                from session_charges ch
                join sessions s on s.id = ch.session_id
               where ch.arena_id = p_arena and s.status <> 'voided'
                 and ch.segment_start >= p_from and ch.segment_start < p_to
              group by ch.activity_code) t), '{}'::jsonb),
    'top_games', coalesce((select jsonb_agg(jsonb_build_object('name', name, 'minutes', round(minutes))
                             order by minutes desc, name)
        from (select g.value as name,
                     sum(_bill_minutes(b)::numeric / jsonb_array_length(b->'games')) as minutes
                from live, jsonb_array_elements_text(b->'games') g
               group by g.value order by 2 desc, 1 limit 5) t), '[]'::jsonb),
    'by_staff', coalesce((select jsonb_agg(jsonb_build_object('name', name, 'bills', bills, 'paise', paise)
                            order by paise desc, name)
        from (select b->>'started_by' as name, count(*) as bills,
                     sum((b->>'paid_paise')::bigint) as paise
                from live where b->>'started_by' is not null group by 1) t), '[]'::jsonb),
    'latest', coalesce((select jsonb_agg(b order by at desc, b->>'id' desc)
        from (select b, at from cur where at >= p_today order by at desc, b->>'id' desc limit 8) t),
        '[]'::jsonb))
  into v_out;
  return v_out;
end;
$function$;

comment on function private.arena_overview(uuid, timestamp with time zone, timestamp with time zone, timestamp with time zone, timestamp with time zone, text, timestamp with time zone) is 'Client API (owner level): the Overview''s aggregated figures for a period and the one before it (totals, takings buckets, payment split, by type, top games, by staff, latest bills).';

grant execute
  on function
    "private"."arena_overview"(uuid, timestamp with time zone, timestamp with time zone,
    timestamp with time zone, timestamp with time zone, text, timestamp with time zone)
  to "authenticated", "postgres", "service_role";

revoke all
  on function
    "private"."arena_overview"(uuid, timestamp with time zone, timestamp with time zone,
    timestamp with time zone, timestamp with time zone, text, timestamp with time zone)
  from public;

revoke all on function "private".arena_overview(p_arena uuid, p_from timestamp with time zone, p_to timestamp with time zone, p_prev_from timestamp with time zone, p_prev_to timestamp with time zone, p_bucket text, p_today timestamp with time zone) from anon;
