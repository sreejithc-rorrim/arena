set local check_function_bodies = off;

alter publication "supabase_realtime" drop table "public"."group_assignments";

alter publication "supabase_realtime" drop table "public"."group_charges";

alter publication "supabase_realtime" drop table "public"."group_extensions";

alter publication "supabase_realtime" drop table "public"."group_payments";

alter publication "supabase_realtime" drop table "public"."group_sessions";

drop trigger "t_same_arena" on "public"."bill_discounts";

drop trigger "t_same_arena" on "public"."controller_allocations";

drop index "public"."ix_alloc_assignment";

drop index "public"."ix_alloc_group";

drop index "public"."ux_bill_discounts_group";

alter table "public"."bill_discounts"
  drop constraint "bill_discounts_group_id_fkey";

alter table "public"."bill_discounts"
  drop constraint "bill_discounts_one_bill_check";

alter table "public"."billing_policies"
  drop constraint "billing_policies_group_billing_mode_check";

alter table "public"."controller_allocations"
  drop constraint "controller_allocations_assignment_id_fkey";

alter table "public"."controller_allocations"
  drop constraint "controller_allocations_group_id_fkey";

alter table "public"."controller_allocations"
  drop constraint "controller_allocations_scope_check";

alter table "public"."group_assignments"
  drop constraint "group_assignments_arena_id_activity_code_fkey";

alter table "public"."group_assignments"
  drop constraint "group_assignments_arena_id_fkey";

alter table "public"."group_assignments"
  drop constraint "group_assignments_game_id_fkey";

alter table "public"."group_assignments"
  drop constraint "group_assignments_group_id_fkey";

alter table "public"."group_assignments"
  drop constraint "group_assignments_resource_id_fkey";

alter table "public"."group_charges"
  drop constraint "group_charges_arena_id_activity_code_fkey";

alter table "public"."group_charges"
  drop constraint "group_charges_arena_id_fkey";

alter table "public"."group_charges"
  drop constraint "group_charges_assignment_id_fkey";

alter table "public"."group_charges"
  drop constraint "group_charges_group_id_fkey";

alter table "public"."group_charges"
  drop constraint "group_charges_resource_id_fkey";

alter table "public"."group_extensions"
  drop constraint "group_extensions_arena_id_fkey";

alter table "public"."group_extensions"
  drop constraint "group_extensions_created_by_fkey";

alter table "public"."group_extensions"
  drop constraint "group_extensions_group_id_fkey";

alter table "public"."group_payments"
  drop constraint "group_payments_arena_id_fkey";

alter table "public"."group_payments"
  drop constraint "group_payments_created_by_fkey";

alter table "public"."group_payments"
  drop constraint "group_payments_group_id_fkey";

alter table "public"."group_sessions"
  drop constraint "group_sessions_arena_id_fkey";

alter table "public"."group_sessions"
  drop constraint "group_sessions_created_by_fkey";

alter table "public"."group_sessions"
  drop constraint "group_sessions_primary_customer_id_fkey";

drop function "public"."_discount_apply"(uuid, jsonb, jsonb, timestamp with time zone, uuid, uuid);

drop function "public"."_group_active"(uuid, uuid);

drop function
  "public"."_group_assignable"(uuid, uuid, uuid, text, uuid, integer, integer, integer, integer);

drop function "public"."_group_lock"(uuid, jsonb, uuid[]);

drop function "public"."_group_place"(uuid, uuid, jsonb, timestamp with time zone, integer, integer);

drop function
  "public"."_pad_allocate"(uuid, jsonb, text, uuid, uuid, uuid, uuid, integer, text, uuid, text,
  uuid, timestamp with time zone);

drop function "public"."_pr_group_bill"(uuid, timestamp with time zone, timestamp with time zone);

drop function "public"."_pr_sweep"(jsonb, uuid, uuid, timestamp with time zone, boolean, timestamp
  with time zone);

drop function "public"."_usable_pads_at"(uuid, uuid);

drop function "public"."op_group_add"(uuid, jsonb);

drop function "public"."op_group_create"(uuid, jsonb);

drop function "public"."op_group_end"(uuid, jsonb);

drop function "public"."op_group_end_player"(uuid, jsonb);

drop function "public"."op_group_extend"(uuid, jsonb);

drop function "public"."op_group_switch"(uuid, jsonb);

drop function "public"."op_group_void"(uuid, jsonb);

alter table "public"."bill_discounts"
  drop column "group_id";

alter table "public"."billing_policies"
  drop column "group_billing_mode";

alter table "public"."controller_allocations"
  drop column "assignment_id";

alter table "public"."controller_allocations"
  drop column "group_id";

alter table "public"."controller_allocations"
  drop column "player_label";

alter table "public"."controller_allocations"
  drop column "player_number";

drop table "public"."group_assignments";

drop function "public"."assert_resource_free_for_assignment"();

drop table "public"."group_charges";

drop table "public"."group_extensions";

drop table "public"."group_payments";

drop table "public"."group_sessions";

alter table "public"."bill_discounts"
  alter column "session_id" set not null;

create or replace function private.arena_activity (
  p_arena    uuid,
  p_resource uuid,
  p_customer uuid,
  p_since    timestamp with time zone,
  p_limit    integer                  default 6
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
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can read play history';
  end if;
  if (p_resource is null) = (p_customer is null) then
    raise exception 'invalid' using hint = 'one of station or member';
  end if;

  with pl as (
    select 'single' as kind, g.session_id as bill_id, s.status, s.customer_id, g.resource_id,
           g.game_id, g.started_at, s.billed_amount_paise as billed
      from session_segments g join sessions s on s.id = g.session_id
     where g.arena_id = p_arena and (g.started_at >= p_since or g.ended_at is null)
       and (g.resource_id = p_resource or s.customer_id = p_customer)
  ), latest as (
    select distinct on (kind, bill_id) * from pl order by kind, bill_id, started_at desc
  )
  select jsonb_build_object(
    'bills', coalesce((select jsonb_agg(jsonb_build_object('bill_id', l.bill_id, 'kind', l.kind,
        'started_at', l.started_at, 'status', l.status, 'billed_paise', l.billed,
        'customer', case when c.is_guest then null else c.name end, 'station', r.name,
        'game', gm.name) order by l.started_at desc, l.bill_id)
        from (select * from latest order by started_at desc, bill_id
               limit least(greatest(coalesce(p_limit, 6), 1), 50)) l
        left join customers c on c.id = l.customer_id
        left join resources r on r.id = l.resource_id
        left join games gm on gm.id = l.game_id), '[]'::jsonb),
    'games', case when p_customer is null then '[]'::jsonb else coalesce((
        select jsonb_agg(jsonb_build_object('game_id', t.game_id, 'name', gm.name,
            'minutes', round(t.minutes)) order by t.minutes desc, gm.name)
          from (select game_id, sum(minutes) as minutes from _plays(p_arena, p_since)
                 where customer_id = p_customer and game_id is not null group by game_id) t
          join games gm on gm.id = t.game_id), '[]'::jsonb) end)
    into v_out;
  return v_out;
end;
$function$;

create or replace function private.arena_discount_usage (
  p_arena    uuid,
  p_discount uuid,
  p_limit    integer default 40,
  p_cursor   text    default null::text
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_limit int := least(greatest(coalesce(p_limit, 40), 1), 100);
  v_rows  jsonb;
  v_at    timestamptz := nullif(split_part(coalesce(p_cursor, ''), '|', 1), '')::timestamptz;
  v_id    uuid := nullif(split_part(coalesce(p_cursor, ''), '|', 2), '')::uuid;
begin
  if not private.app_is_owner(p_arena) then
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can read sales';
  end if;
  if not exists (select 1 from discounts where id = p_discount and arena_id = p_arena) then
    raise exception 'not_found' using hint = 'discount';
  end if;

  select coalesce(jsonb_agg(x.j || jsonb_build_object('cursor', x.at::text || '|' || x.id)
                            order by x.at desc, x.id desc), '[]'::jsonb) into v_rows
    from (select d.id, d.applied_at as at, jsonb_build_object(
              'bill_id', d.session_id,
              'kind', 'single',
              'at', d.applied_at, 'customer', c.name,
              'billed_paise', s.billed_amount_paise,
              'amount_paise', d.amount_paise, 'base_paise', d.base_paise,
              'status', s.status, 'by', sp.name) as j
            from bill_discounts d
            left join sessions s on s.id = d.session_id
            left join customers c on c.id = s.customer_id
            left join staff_profiles sp on sp.arena_id = d.arena_id and sp.user_id = d.applied_by
           where d.arena_id = p_arena and d.discount_id = p_discount
             and (v_at is null or (d.applied_at, d.id) < (v_at, coalesce(v_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
           order by d.applied_at desc, d.id desc
           limit v_limit + 1) x;

  return jsonb_build_object(
    'uses', (select count(*) from bill_discounts where discount_id = p_discount),
    'active_uses', (select count(*) from bill_discounts d
                      join sessions s on s.id = d.session_id
                     where d.discount_id = p_discount and s.status <> 'voided'),
    'rows', (select coalesce(jsonb_agg(r - 'cursor' order by n), '[]'::jsonb)
               from jsonb_array_elements(v_rows) with ordinality x(r, n) where n <= v_limit),
    'next', case when jsonb_array_length(v_rows) > v_limit
                 then v_rows->(v_limit - 1)->>'cursor' end);
end;
$function$;

create or replace function private.arena_members (
  p_arena    uuid,
  p_since    timestamp with time zone,
  p_since_30 timestamp with time zone,
  p_search   text                     default null::text,
  p_limit    integer                  default 50,
  p_offset   integer                  default 0
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_q      text := nullif(lower(btrim(coalesce(p_search, ''))), '');
  v_digits text := nullif(regexp_replace(coalesce(p_search, ''), '\D', '', 'g'), '');
  v_out    jsonb;
begin
  if not private.app_is_owner(p_arena) then
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can read members';
  end if;

  with m as (
    select c.* from customers c
     where c.arena_id = p_arena and not c.is_guest
       and (v_q is null or position(v_q in lower(c.name)) > 0
            or (v_digits is not null
                and position(v_digits in regexp_replace(coalesce(c.phone, ''), '\D', '', 'g')) > 0))
  ), b as (
    select s.customer_id as cid, s.started_at, s.billed_amount_paise as billed from sessions s
     where s.arena_id = p_arena and s.status <> 'voided' and (s.started_at >= p_since or s.status = 'active')
  ), pl as (
    select customer_id, sum(minutes) as minutes from _plays(p_arena, p_since) group by customer_id
  ), s as (
    select m.id, m.name, m.phone, m.birth_year, m.created_at,
           (select count(*) from b where b.cid = m.id) as visits,
           coalesce((select round(pl.minutes) from pl where pl.customer_id = m.id), 0) as minutes,
           coalesce((select sum(b.billed) from b where b.cid = m.id and b.started_at >= p_since_30), 0)
             as spent,
           greatest(m.last_visit_at, (select max(b.started_at) from b where b.cid = m.id)) as last_visit
      from m
  )
  select jsonb_build_object(
    'total', (select count(*) from s),
    'rows', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'name', name, 'phone', phone,
        'birth_year', birth_year, 'created_at', created_at, 'visits', visits, 'minutes', minutes,
        'spent_30_paise', spent, 'last_visit', last_visit) order by last_visit desc nulls last, name, id)
        from (select * from s order by last_visit desc nulls last, name, id
               limit least(greatest(coalesce(p_limit, 50), 1), 200)
               offset greatest(coalesce(p_offset, 0), 0)) p), '[]'::jsonb))
    into v_out;
  return v_out;
end;
$function$;

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
        'user_id', s.user_id, 'name', s.name, 'email', u.email, 'role', s.role,
        'perms', to_jsonb(s.perms), 'active', s.active,
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

create or replace function private.arena_station_stats (
  p_arena uuid,
  p_today timestamp with time zone,
  p_since timestamp with time zone,
  p_to    timestamp with time zone
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
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can read station figures';
  end if;
  if p_since is null or p_today is null or p_to is null or p_to <= p_since
     or p_to - p_since > interval '400 days' then
    raise exception 'invalid_range' using hint = 'up to 400 days';
  end if;

  with ch as (
    select ch.resource_id, ch.segment_start, ch.amount_paise from session_charges ch
      join sessions s on s.id = ch.session_id
     where ch.arena_id = p_arena and s.status <> 'voided'
       and ch.segment_start >= p_since and ch.segment_start < p_to
  ), pl as (
    select * from _plays(p_arena, p_since)
  )
  select coalesce(jsonb_object_agg(r.id, jsonb_build_object(
      'billed_today', coalesce((select sum(amount_paise) from ch
                                 where ch.resource_id = r.id and ch.segment_start >= p_today), 0),
      'sessions_today', (select count(distinct (pl.kind, pl.bill_id)) from pl
                          where pl.resource_id = r.id and pl.started_at >= p_today),
      'minutes_30', coalesce((select round(sum(pl.minutes)) from pl
                               where pl.resource_id = r.id and pl.started_at >= p_since), 0),
      'billed_30', coalesce((select sum(amount_paise) from ch where ch.resource_id = r.id), 0),
      'accessories', (select count(*) from controllers c
                       where c.home_resource_id = r.id and c.status <> 'retired'))), '{}'::jsonb)
    into v_out
    from resources r where r.arena_id = p_arena;
  return v_out;
end;
$function$;

create or replace function private.my_bills (
  p_arena uuid,
  p_day   date
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_from timestamptz := p_day::timestamp at time zone 'Asia/Kolkata';
begin
  if auth.uid() is null or p_arena is null
     or not (private.app_has_perm(p_arena, 'bill_edit')
             or private.app_has_perm(p_arena, 'bill_record')) then
    raise exception 'forbidden' using errcode = '42501', hint = 'needs bill_edit or bill_record';
  end if;
  if p_day is null then
    raise exception 'invalid_range' using hint = 'a day';
  end if;
  return coalesce((
    select jsonb_agg(b order by (b->>'at')::timestamptz desc, b->>'id')
      from _sales(p_arena, v_from, v_from + interval '1 day') b
     where (b->>'id')::uuid in (
             select id from sessions where arena_id = p_arena and created_by = auth.uid())),
    '[]'::jsonb);
end;
$function$;

create or replace function private.sync_fetch_entity (
  p_arena uuid,
  p_refs  jsonb
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_ref    jsonb;
  v_id     uuid;
  v_rows   jsonb;
  v_out    jsonb := '[]'::jsonb;
  v_hidden text[];
begin
  -- `not in` is NULL (not true) for a null arena, so test membership explicitly.
  if p_arena is null or not exists (select 1 from private.app_arena_ids() a where a = p_arena) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  for v_ref in select value from jsonb_array_elements(coalesce(p_refs, '[]'::jsonb)) loop
    v_id := nullif(v_ref->>'id', '')::uuid;
    -- controller_moves point at their session via session_ref
    -- ('s:<session id>'), not a uuid column.
    v_rows := case v_ref->>'type'
      when 'session' then (
        select coalesce(jsonb_agg(x), '[]'::jsonb) from (
          select jsonb_build_object('t','sessions','r',to_jsonb(s)) x from sessions s where s.arena_id = p_arena and s.id = v_id
          union all select jsonb_build_object('t','session_segments','r',to_jsonb(s)) from session_segments s where s.arena_id = p_arena and s.session_id = v_id
          union all select jsonb_build_object('t','session_extensions','r',to_jsonb(s)) from session_extensions s where s.arena_id = p_arena and s.session_id = v_id
          union all select jsonb_build_object('t','session_charges','r',to_jsonb(s)) from session_charges s where s.arena_id = p_arena and s.session_id = v_id
          union all select jsonb_build_object('t','payments','r',to_jsonb(s)) from payments s where s.arena_id = p_arena and s.session_id = v_id
          union all select jsonb_build_object('t','controller_allocations','r',to_jsonb(s)) from controller_allocations s where s.arena_id = p_arena and s.session_id = v_id
          union all select jsonb_build_object('t','controller_moves','r',to_jsonb(s)) from controller_moves s where s.arena_id = p_arena and s.session_ref = 's:' || v_id::text
        ) q)
      when 'controller' then (
        select coalesce(jsonb_agg(x), '[]'::jsonb) from (
          select jsonb_build_object('t','controllers','r',to_jsonb(s)) x from controllers s where s.arena_id = p_arena and s.id = v_id
          union all select jsonb_build_object('t','controller_moves','r',to_jsonb(s)) from controller_moves s where s.arena_id = p_arena and s.controller_id = v_id
          union all select jsonb_build_object('t','controller_allocations','r',to_jsonb(s)) from controller_allocations s where s.arena_id = p_arena and s.controller_id = v_id and s.ended_at is null
        ) q)
      when 'customer' then (
        select coalesce(jsonb_agg(jsonb_build_object('t','customers','r',to_jsonb(s))), '[]'::jsonb)
          from customers s where s.arena_id = p_arena and s.id = v_id)
      when 'booking' then (
        select coalesce(jsonb_agg(jsonb_build_object('t','bookings','r',to_jsonb(s))), '[]'::jsonb)
          from sync_v_bookings s where s.arena_id = p_arena and s.id = v_id)
      else '[]'::jsonb
    end;
    -- Customers, money and coupons only for those who may read them (as sync_pull).
    v_hidden := coalesce(v_hidden, _sync_hidden(p_arena));
    select coalesce(jsonb_agg(e), '[]'::jsonb) into v_rows
      from jsonb_array_elements(v_rows) e where e->>'t' <> all(v_hidden);
    v_out := v_out || jsonb_build_array(jsonb_build_object('ref', v_ref, 'rows', v_rows));
  end loop;
  return v_out;
end;
$function$;

create or replace function public._discount_apply (
  p_arena   uuid,
  p_disc    jsonb,
  p_bill    jsonb,
  p_at      timestamp with time zone,
  p_session uuid
)
  returns bigint
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_sub    bigint := (p_bill->>'subtotal')::bigint;
  v_d      discounts%rowtype;
  v_manual jsonb := p_disc->'manual';
  v_reason text := nullif(btrim(coalesce(p_disc->>'reason', '')), '');
  v_opts   jsonb;
  v_source text; v_name text; v_code text; v_vkind text; v_value bigint;
  v_base   bigint; v_amount bigint; v_max int; v_uses int;
begin
  if v_manual is not null then
    perform _need(p_arena, 'discount');
    v_vkind := v_manual->>'value_kind';
    v_value := (v_manual->>'value')::bigint;
    if v_value is null or not ((v_vkind = 'percent' and v_value between 1 and 100)
                               or (v_vkind = 'flat' and v_value >= 1)) then
      raise exception 'invalid_discount';
    end if;
    v_source := 'manual'; v_name := 'Manual discount'; v_base := v_sub;
  else
    if p_disc ? 'code' then
      select * into v_d from discounts
       where arena_id = p_arena and kind = 'coupon' and code = upper(btrim(p_disc->>'code')) for update;
      if not found then raise exception 'coupon_unknown'; end if;
    else
      select * into v_d from discounts
       where arena_id = p_arena and id = (p_disc->>'discount_id')::uuid for update;
      if not found then raise exception 'not_found' using hint = 'discount'; end if;
    end if;
    if not v_d.active then raise exception 'discount_inactive'; end if;
    if v_d.valid_from is not null and p_at < v_d.valid_from then
      raise exception 'discount_not_started' using hint = v_d.valid_from::text;
    end if;
    if v_d.valid_until is not null and p_at > v_d.valid_until then
      raise exception 'coupon_expired' using hint = v_d.valid_until::text;
    end if;
    if v_d.max_uses is not null then
      select count(*) into v_uses from bill_discounts b
        join sessions s on s.id = b.session_id
       where b.discount_id = v_d.id and s.status <> 'voided';
      if v_uses >= v_d.max_uses then raise exception 'coupon_used_up'; end if;
    end if;
    if v_d.min_bill_paise is not null and v_sub < v_d.min_bill_paise then
      raise exception 'discount_min_bill' using hint = v_d.min_bill_paise::text;
    end if;
    v_base := case when cardinality(v_d.activity_codes) = 0 then v_sub
                   else coalesce((select sum(value::bigint) from jsonb_each_text(p_bill->'by_activity')
                                   where key = any(v_d.activity_codes)), 0) end;
    if v_base <= 0 and cardinality(v_d.activity_codes) > 0 then
      raise exception 'discount_scope';
    end if;
    v_source := v_d.kind; v_name := v_d.name; v_code := v_d.code;
    v_vkind := v_d.value_kind; v_value := v_d.value;
  end if;

  v_amount := case when v_vkind = 'percent' then _pr_div(v_base * v_value, 100) else v_value end;
  if v_d.max_discount_paise is not null then v_amount := least(v_amount, v_d.max_discount_paise); end if;
  v_amount := greatest(0, least(v_amount, v_base));

  if v_source = 'manual' then
    select json into v_opts from settings where arena_id = p_arena and key = 'discount_options';
    if not private.app_has_perm(p_arena, 'settings') then
      v_max := coalesce((v_opts->>'manual_max_percent')::int, 0);
      if v_amount > _pr_div(v_sub * v_max, 100) then
        raise exception 'discount_over_limit' using hint = v_max::text || '%';
      end if;
    end if;
    if coalesce((v_opts->>'reason_required')::boolean, false) and v_reason is null then
      raise exception 'discount_reason_required';
    end if;
  end if;

  if (p_disc->>'amount_paise')::bigint is distinct from v_amount then
    perform _price_mismatch('discount', v_amount, (p_disc->>'amount_paise')::bigint);
  end if;

  insert into bill_discounts(id, arena_id, session_id, discount_id, source, name, code,
      value_kind, value, base_paise, amount_paise, reason, applied_by, applied_at)
    values (coalesce(nullif(p_disc->>'id', '')::uuid, gen_random_uuid()), p_arena, p_session,
      v_d.id, v_source, v_name, v_code, v_vkind, v_value, v_base, v_amount, v_reason, auth.uid(), p_at);
  return v_amount;
end;
$function$;

create or replace function public._pad_allocate (
  p_arena    uuid,
  p_allocs   jsonb,
  p_session  uuid,
  p_segment  uuid,
  p_resource uuid,
  p_activity text,
  p_game     uuid,
  p_started  timestamp with time zone
)
  returns void
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now timestamptz := statement_timestamp();
  v_a jsonb; v_cid uuid; v_status text; v_loc uuid; v_kind uuid;
  v_ids uuid[] := _pad_ids(p_allocs);
begin
  if coalesce(array_length(v_ids, 1), 0) = 0 then return; end if;
  if array_length(v_ids, 1) <> (select count(distinct x) from unnest(v_ids) x) then
    raise exception 'controller_duplicate';
  end if;
  for v_a in select value from jsonb_array_elements(p_allocs) loop
    v_cid := (v_a->>'controller_id')::uuid;
    select status, current_resource_id, kind_id into v_status, v_loc, v_kind
      from controllers where id = v_cid and arena_id = p_arena;
    if not found then raise exception 'controller_missing'; end if;
    if not _is_pad(v_kind) then raise exception 'not_a_controller'; end if;
    if v_status <> 'usable' then raise exception 'controller_unusable' using hint = v_status; end if;
    if v_loc <> p_resource then raise exception 'controller_elsewhere'; end if;
    if exists (select 1 from controller_allocations where controller_id = v_cid and ended_at is null) then
      raise exception 'controller_taken';
    end if;
    if _untracked_busy(p_arena, p_resource, array_remove(array[p_segment], null)) then
      raise exception 'controller_taken' using hint = 'untracked_player';
    end if;
  end loop;
  for v_a in select value from jsonb_array_elements(p_allocs) loop
    insert into controller_allocations(id, arena_id, controller_id, scope, session_id,
        segment_id, resource_id, activity_code, game_id, started_at, created_by, created_at)
      values (coalesce(nullif(v_a->>'id','')::uuid, gen_random_uuid()), p_arena,
        (v_a->>'controller_id')::uuid, 'single', p_session, p_segment, p_resource, p_activity,
        p_game, p_started, auth.uid(), v_now);
  end loop;
end;
$function$;

create or replace function public._plays (
  p_arena uuid,
  p_since timestamp with time zone
)
  returns table (
    kind          text,
    bill_id       uuid,
    bill_status   text,
    customer_id   uuid,
    resource_id   uuid,
    activity_code text,
    game_id       uuid,
    started_at    timestamp with time zone,
    ended_at      timestamp with time zone,
    minutes       numeric
  )
  language sql
  stable
  set search_path to 'public'
  AS $function$
  select 'single', g.session_id, s.status, s.customer_id, g.resource_id, g.activity_code, g.game_id,
         g.started_at, g.ended_at,
         greatest(0, extract(epoch from (coalesce(g.ended_at, now()) - g.started_at)) / 60)
    from session_segments g join sessions s on s.id = g.session_id
   where g.arena_id = p_arena and s.status <> 'voided'
     and (g.started_at >= p_since or g.ended_at is null);
$function$;

create or replace function public._pr_policy (
  s jsonb
)
  returns jsonb
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  select '{"billing_unit":"per_minute","block_rounding":"up","grace_minutes":0,
    "minimum_charge_minutes":0,"early_exit":"actual","rounding_scope":"session",
    "late_arrival":"actual","vr_unit_rounding":"up","money_rounding_paise":100,
    "money_rounding_dir":"nearest","payment_timing":"either","allow_extend_past_close":false,
    "cleaning_gap_minutes":0}'::jsonb
    || coalesce(s->'policy', '{}'::jsonb);
$function$;

create or replace function public._pricing_canon (
  s jsonb
)
  returns jsonb
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  select jsonb_build_object(
    'rates', coalesce((select jsonb_agg(jsonb_build_object('a', r->>'activity_code',
        'b', r->>'band', 'c', (r->>'controller_count')::int, 'u', (r->>'unit_minutes')::int,
        'p', (r->>'price_paise')::bigint)
        order by r->>'activity_code', r->>'band', coalesce((r->>'controller_count')::int, -1),
                 (r->>'unit_minutes')::int, (r->>'price_paise')::bigint)
        from jsonb_array_elements(coalesce(s->'rates', '[]'::jsonb)) r), '[]'::jsonb),
    'activities', coalesce((select jsonb_agg(jsonb_build_object('code', a->>'code',
        'model', a->>'duration_model',
        -- Absent (an older device or snapshot) = no grace.
        'grace', coalesce((a->>'overtime_grace_minutes')::int, 0))
        order by a->>'code', a->>'duration_model')
        from jsonb_array_elements(coalesce(s->'activities', '[]'::jsonb)) a), '[]'::jsonb),
    -- group_billing_mode: dropped, so a device snapshot that still carries it matches.
    'policy', _pr_policy(s) - 'group_billing_mode',
    'hours', (select jsonb_object_agg(kind, (select jsonb_object_agg(d::text,
        case when jsonb_typeof(s->'hours'->kind->(d::text)) = 'object'
             then jsonb_build_object('start', (s->'hours'->kind->(d::text)->>'start')::int,
                                     'end', (s->'hours'->kind->(d::text)->>'end')::int)
             else 'null'::jsonb end) from generate_series(1, 7) d))
        from unnest(array['open']) kind),
    'holidays', coalesce((select jsonb_agg(distinct x order by x)
        from jsonb_array_elements_text(coalesce(s->'holidays', '[]'::jsonb)) x), '[]'::jsonb),
    'closed_days', coalesce((select jsonb_agg(distinct x order by x)
        from jsonb_array_elements_text(coalesce(s->'closed_days', '[]'::jsonb)) x), '[]'::jsonb))
  -- Rules only when the snapshot has any, so a rule-free canon is unchanged.
  || coalesce((select jsonb_build_object('rules', jsonb_agg(jsonb_build_object(
        'id', r->>'id', 'name', r->>'name', 'priority', (r->>'priority')::int,
        'days', (select jsonb_agg(distinct d::int order by d::int)
                   from jsonb_array_elements_text(r->'days') d),
        'start_min', (r->>'start_min')::int, 'end_min', (r->>'end_min')::int,
        'holiday_mode', r->>'holiday_mode', 'valid_from', r->>'valid_from',
        'valid_until', r->>'valid_until',
        'activity_codes', coalesce((select jsonb_agg(distinct c order by c)
                   from jsonb_array_elements_text(r->'activity_codes') c), '[]'::jsonb),
        'adjust_kind', r->>'adjust_kind', 'adjust_value', (r->>'adjust_value')::int)
        order by (r->>'priority')::int, r->>'name' collate "C", r->>'id' collate "C"))
        from jsonb_array_elements(coalesce(s->'rules', '[]'::jsonb)) r
        having count(*) > 0), '{}'::jsonb);
$function$;

create or replace function public._pricing_snapshot (
  p_arena uuid
)
  returns jsonb
  language sql
  stable
  security definer
  set search_path to 'public'
  AS $function$
  select jsonb_build_object(
    'rate_card_name', 'Current',
    'rates', coalesce((select jsonb_agg(jsonb_build_object('activity_code', activity_code,
        'band', band, 'controller_count', controller_count, 'unit_minutes', unit_minutes,
        'price_paise', price_paise)) from sync_v_rates
        where arena_id = p_arena and band = 'standard'), '[]'::jsonb),
    'activities', coalesce((select jsonb_agg(jsonb_build_object('code', code,
        'duration_model', duration_model, 'overtime_grace_minutes', overtime_grace_minutes))
        from activities where arena_id = p_arena), '[]'::jsonb),
    'policy', coalesce((select jsonb_build_object('billing_unit', billing_unit,
        'block_rounding', block_rounding, 'grace_minutes', grace_minutes,
        'minimum_charge_minutes', minimum_charge_minutes, 'early_exit', early_exit,
        'rounding_scope', rounding_scope, 'late_arrival', late_arrival,
        'vr_unit_rounding', vr_unit_rounding, 'money_rounding_paise', money_rounding_paise,
        'money_rounding_dir', money_rounding_dir, 'payment_timing', payment_timing,
        'allow_extend_past_close', allow_extend_past_close,
        'cleaning_gap_minutes', cleaning_gap_minutes)
        from billing_policies where arena_id = p_arena and active order by created_at limit 1),
        _pr_policy('{}'::jsonb)),
    -- BusinessHours.current() when the owner never saved hours.
    'hours', coalesce((select json from settings where arena_id = p_arena and key = 'business_hours'),
      '{"open":{"1":null,"2":{"start":840,"end":1380},"3":{"start":840,"end":1380},
                "4":{"start":840,"end":1380},"5":{"start":840,"end":1380},
                "6":{"start":840,"end":1380},"7":{"start":840,"end":1380}}}'::jsonb),
    'holidays', coalesce((select jsonb_agg(day::text) from holidays where arena_id = p_arena), '[]'::jsonb),
    'closed_days', coalesce((select jsonb_agg(day::text) from holidays
        where arena_id = p_arena and closed), '[]'::jsonb))
  -- Active pricing rules, only when there are any: an arena without rules keeps
  -- exactly the snapshot (and canon) floor apps built before rules produce.
  || coalesce((select jsonb_build_object('rules', jsonb_agg(jsonb_build_object(
        'id', r.id, 'name', r.name, 'priority', r.priority, 'days', to_jsonb(r.days),
        'start_min', r.start_min, 'end_min', r.end_min, 'holiday_mode', r.holiday_mode,
        'valid_from', r.valid_from, 'valid_until', r.valid_until,
        'activity_codes', to_jsonb(r.activity_codes), 'adjust_kind', r.adjust_kind,
        'adjust_value', r.adjust_value)
        order by r.priority, r.name collate "C", r.id::text collate "C"))
        from pricing_rules r where r.arena_id = p_arena and r.active
        having count(*) > 0), '{}'::jsonb);
$function$;

create or replace function public._sales (
  p_arena uuid,
  p_from  timestamp with time zone,
  p_to    timestamp with time zone,
  p_id    uuid                     default null::uuid
)
  returns SETOF jsonb
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

create or replace function public._station_free_for_single (
  p_resource uuid
)
  returns void
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
begin
  if exists (select 1 from session_segments where resource_id = p_resource and ended_at is null) then
    raise exception 'resource_busy';
  end if;
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

create or replace function public._sync_hidden (
  p_arena uuid
)
  returns text[]
  language sql
  stable
  set search_path to 'public'
  AS $function$
  select coalesce(array_agg(t order by t), '{}') from (
    select unnest(array['customers']) t
     where p_arena not in (select private.app_arena_ids_with(array['start', 'members', 'money', 'reports']))
    union all
    select unnest(array['bill_discounts', 'payments', 'session_charges'])
     where p_arena not in (select private.app_arena_ids_with(array['bill', 'money', 'reports']))
    union all
    select unnest(array['discounts'])
     where p_arena not in (select private.app_arena_ids_with(array['discount', 'settings', 'money', 'reports']))
  ) h;
$function$;

create or replace function public._sync_sources()
  returns table (
    name text,
    rel  text
  )
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  values
    ('arenas','sync_v_arenas'), ('staff_profiles','staff_profiles'),
    ('activities','activities'), ('resources','resources'),
    ('resource_activities','sync_v_resource_activities'), ('controllers','controllers'),
    ('customers','customers'), ('rates','sync_v_rates'),
    ('billing_policies','billing_policies'), ('holidays','holidays'),
    ('game_categories','game_categories'), ('games','games'),
    ('game_controls','game_controls'), ('game_resources','game_resources'),
    ('bookings','sync_v_bookings'), ('sessions','sessions'),
    ('session_segments','session_segments'), ('session_extensions','session_extensions'),
    ('session_charges','session_charges'), ('payments','payments'),
    ('controller_allocations','controller_allocations'),
    ('controller_moves','controller_moves'), ('settings','settings'),
    ('accessory_kinds','accessory_kinds'), ('pricing_rules','pricing_rules'),
    ('discounts','discounts'), ('bill_discounts','bill_discounts')
$function$;

create or replace function public._untracked_busy (
  p_arena    uuid,
  p_resource uuid,
  p_except   uuid[] default '{}'::uuid[]
)
  returns boolean
  language sql
  stable
  security definer
  set search_path to 'public'
  AS $function$
  select exists (
      select 1 from session_segments s
        join activities a on a.arena_id = s.arena_id and a.code = s.activity_code
       where s.arena_id = p_arena and s.resource_id = p_resource and s.ended_at is null
         and a.uses_controllers and not (s.id = any(p_except))
         and not exists (select 1 from controller_allocations ca
                          where ca.segment_id = s.id and ca.ended_at is null));
$function$;

create or replace function public.assert_resource_free_for_segment()
  returns trigger
  language plpgsql
  set search_path to 'public', 'extensions'
  AS $function$
declare
  busy int;
begin
  if new.ended_at is not null then
    return new;
  end if;
  -- Serialise claims on this resource: two concurrent starts must not both see
  -- it free (ux_one_open_segment_per_resource backs this up).
  perform 1 from resources where id = new.resource_id for update;

  select count(*) into busy from (
    select 1 from session_segments
      where resource_id = new.resource_id
        and ended_at is null
        and id <> new.id
  ) t;

  if busy > 0 then
    raise exception 'resource_busy'
      using hint = 'That station already has a session on it.';
  end if;
  return new;
end;
$function$;

create or replace function public.op_activity_remove (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_id       uuid := (p->>'id')::uuid;
  v_code     text;
  v_stations int;
begin
  perform _need(p_arena, 'settings');
  if exists (select 1 from activities where id = v_id and arena_id <> p_arena) then
    raise exception 'not_found' using hint = 'activity';
  end if;
  select code into v_code from activities where id = v_id and arena_id = p_arena for update;
  if not found then return jsonb_build_object('removed', 'deleted'); end if;

  select count(*) into v_stations
    from resource_activities ra join resources r on r.id = ra.resource_id
   where ra.activity_id = v_id and r.status <> 'disabled';
  if v_stations > 0 then
    raise exception 'activity_has_stations' using hint = v_stations::text;
  end if;

  update resources set current_mode = null, updated_at = statement_timestamp()
   where arena_id = p_arena and current_mode = v_code;

  if exists (select 1 from session_segments where arena_id = p_arena and activity_code = v_code)
     or exists (select 1 from session_charges where arena_id = p_arena and activity_code = v_code)
     or exists (select 1 from controller_allocations where arena_id = p_arena and activity_code = v_code)
     or exists (select 1 from bookings where arena_id = p_arena and activity_id = v_id) then
    update activities set active = false, updated_at = statement_timestamp() where id = v_id;
    return jsonb_build_object('removed', 'retired');
  end if;

  delete from activities where id = v_id;
  return jsonb_build_object('removed', 'deleted');
end;
$function$;

create or replace function public.op_activity_upsert (
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
  v_code text := upper(btrim(coalesce(p->>'code', '')));
  v_name text := btrim(coalesce(p->>'name', ''));
  v_pads boolean := coalesce((p->>'uses_controllers')::boolean, false);
  v_old  activities%rowtype;
  v_base text;
  v_n    int := 1;
begin
  perform _need(p_arena, 'settings');
  if v_code = '' then
    select code into v_code from activities where id = v_id and arena_id = p_arena;
    if v_code is null then
      v_base := left(btrim(regexp_replace(upper(v_name), '[^A-Z0-9]+', '_', 'g'), '_'), 12);
      if v_base = '' then v_base := 'TYPE'; end if;
      v_code := v_base;
      while exists (select 1 from activities where arena_id = p_arena and code = v_code) loop
        v_n := v_n + 1;
        v_code := left(v_base, 12 - char_length(v_n::text) - 1) || '_' || v_n;
      end loop;
    end if;
  end if;
  if v_code !~ '^[A-Z0-9_]{1,12}$' then
    raise exception 'invalid_code' using hint = 'A–Z, 0–9 or _, up to 12';
  end if;
  if char_length(v_name) not between 1 and 40 then
    raise exception 'invalid_name' using hint = '1–40 characters';
  end if;
  if exists (select 1 from activities where id = v_id and arena_id <> p_arena) then
    raise exception 'not_found' using hint = 'activity';
  end if;

  select * into v_old from activities where id = v_id and arena_id = p_arena for update;
  if found then
    if v_old.code <> v_code then
      raise exception 'code_locked' using hint = v_old.code;
    end if;
    if v_old.uses_controllers <> v_pads
       and exists (select 1 from session_segments
                    where arena_id = p_arena and activity_code = v_code and ended_at is null) then
      raise exception 'activity_busy' using hint = v_code;
    end if;
  end if;

  insert into activities(id, arena_id, code, name, uses_controllers, uses_games, duration_model,
      sort_order, active, overtime_grace_minutes)
    values (v_id, p_arena, v_code, v_name, v_pads,
      coalesce((p->>'uses_games')::boolean, false),
      coalesce(p->>'duration_model', 'hourly'),
      coalesce((p->>'sort_order')::int, 0),
      coalesce((p->>'active')::boolean, true),
      coalesce((p->>'overtime_grace_minutes')::int, v_old.overtime_grace_minutes, 0))
  on conflict (id) do update set
    name = excluded.name, uses_controllers = excluded.uses_controllers,
    uses_games = excluded.uses_games, duration_model = excluded.duration_model,
    sort_order = excluded.sort_order, overtime_grace_minutes = excluded.overtime_grace_minutes,
    active = excluded.active, updated_at = statement_timestamp()
  where activities.arena_id = p_arena;
  return '{}'::jsonb;
end;
$function$;

create or replace function public.op_bill_adjust (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now    timestamptz := statement_timestamp();
  v_parent uuid := (p->>'parent_id')::uuid;
  v_new    bigint := (p->>'billed_amount_paise')::bigint;
  v_reason text := nullif(btrim(coalesce(p->>'reason', '')), '');
  v_method text := p->>'method';
  v_pay_id uuid := coalesce(nullif(p->>'payment_id', '')::uuid, gen_random_uuid());
  v_status text; v_pay text; v_old bigint; v_paid bigint; v_diff bigint;
  v_by     uuid;
  v_money  boolean := private.app_has_perm(p_arena, 'money');
begin
  if not v_money then perform _need(p_arena, 'bill_edit'); end if;
  if coalesce(p->>'scope', 'single') <> 'single' then
    raise exception 'invalid_payload' using hint = 'scope';
  end if;
  if v_reason is null then
    raise exception 'reason_required' using hint = 'say why the bill changes';
  end if;
  if length(v_reason) > 500 then raise exception 'reason_too_long' using hint = 'at most 500 characters'; end if;
  if v_new is null or v_new < 0 then
    raise exception 'invalid_total' using hint = 'the new total in whole paise, 0 or more';
  end if;

  -- Lock the bill (as op_payment does), so payments on it queue behind the change.
  select status, payment_status, billed_amount_paise, created_by into v_status, v_pay, v_old, v_by
    from sessions where id = v_parent and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'session'; end if;
  select coalesce(sum(amount_paise), 0) into v_paid from payments where session_id = v_parent;
  if not v_money and v_by is distinct from auth.uid() then
    raise exception 'forbidden' using errcode = '42501', hint = 'not your bill';
  end if;
  if v_status = 'voided' then raise exception 'voided' using hint = 'a voided bill has no total'; end if;
  if v_status <> 'completed' or v_old is null then
    raise exception 'not_ended' using hint = 'end the session first';
  end if;
  if v_pay = 'waived' then raise exception 'waived' using hint = 'a waived bill owes nothing'; end if;
  -- The difference is settled against what the caller saw, never against a payment or edit
  -- that landed since (it would turn into a refund nobody gave, or refuse real money).
  if v_old is distinct from (p->>'expected_billed_paise')::bigint
     or v_paid is distinct from (p->>'expected_paid_paise')::bigint then
    raise exception 'stale' using hint = 'the bill changed since it was loaded: reload it';
  end if;
  if v_new = v_old and v_paid = v_new then
    raise exception 'same_total' using hint = 'the bill is already that amount and paid';
  end if;

  -- What the bill says is what was collected: the difference goes in (or back) now.
  v_diff := v_new - v_paid;
  if v_diff <> 0 then
    if v_method is null or v_method not in ('cash', 'upi', 'card', 'other') then
      raise exception 'invalid_method' using hint = 'how the difference was paid or given back';
    end if;
    insert into payments(id, arena_id, session_id, amount_paise, method, kind, note, reason,
        created_by, created_at)
      values (v_pay_id, p_arena, v_parent, v_diff, v_method,
        case when v_diff < 0 then 'refund' else 'payment' end, 'Bill edited',
        v_reason, auth.uid(), v_now);
  end if;
  update sessions set billed_amount_paise = v_new, payment_status = 'paid', updated_at = v_now
    where id = v_parent;
  insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
      created_by, created_at)
    values (p_arena, 'session', v_parent, 'bill_adjust', v_reason,
      jsonb_build_object('billed_paise', v_old, 'paid_paise', v_paid),
      jsonb_build_object('billed_paise', v_new, 'paid_paise', v_new), auth.uid(), v_now);
  return jsonb_build_object('payment_status', 'paid');
end;
$function$;

create or replace function public.op_game_delete (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_id      uuid := (p->>'id')::uuid;
  v_playing int;
  v_history text;
begin
  perform _need(p_arena, 'settings');
  if v_id is null then raise exception 'invalid_payload' using hint = 'id'; end if;
  if exists (select 1 from games where id = v_id and arena_id <> p_arena) then
    raise exception 'not_found' using hint = 'game';
  end if;
  -- The lock queues behind a start that is placing a session on it right now (its foreign-key
  -- check holds a key-share lock), so the checks below see that session once it commits.
  perform 1 from games where id = v_id and arena_id = p_arena for update;
  if not found then return jsonb_build_object('deleted', true); end if;

  select count(*) from session_segments
   where arena_id = p_arena and game_id = v_id and ended_at is null
    into v_playing;
  if v_playing > 0 then
    raise exception 'game_in_play' using hint = v_playing::text;
  end if;

  v_history := case
    when exists (select 1 from session_segments where arena_id = p_arena and game_id = v_id)
      then 'sessions'
    when exists (select 1 from controller_allocations where arena_id = p_arena and game_id = v_id)
      then 'pads'
    when exists (select 1 from bookings where arena_id = p_arena and game_id = v_id)
      then 'bookings'
  end;
  if v_history is not null then
    raise exception 'game_has_history' using hint = v_history;
  end if;

  delete from games where id = v_id and arena_id = p_arena;
  return jsonb_build_object('deleted', true);
end;
$function$;

create or replace function public.op_payment (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now    timestamptz := statement_timestamp();
  v_scope  text    := coalesce(p->>'scope', 'single');
  v_parent uuid    := (p->>'parent_id')::uuid;
  v_refund boolean := coalesce((p->>'is_refund')::boolean, false);
  v_amount bigint  := (p->>'amount_paise')::bigint;
  v_status text; v_pay text; v_billed bigint; v_paid bigint;
begin
  -- Permission refusals keep their own code, ahead of any balance check.
  perform _need(p_arena, 'bill');
  if v_refund then perform _need(p_arena, 'discount'); end if;
  if v_scope <> 'single' then raise exception 'invalid_payload' using hint = 'scope'; end if;

  -- Balance (0016). Lock the parent so two pushes for the same bill queue here
  -- and the second sees the first one's payment.
  select status, payment_status, billed_amount_paise into v_status, v_pay, v_billed
    from sessions where id = v_parent and arena_id = p_arena for update;
  if found then
    select coalesce(sum(amount_paise), 0) into v_paid
      from payments where session_id = v_parent;
  end if;

  -- A payment on a voided bill is refused as such, ahead of the balance check (which
  -- would otherwise call it an overpayment on a bill that was paid before the void).
  if v_status = 'voided' and not v_refund then
    raise exception 'voided' using hint = 'a voided bill takes no payments; a refund is allowed';
  end if;

  -- v_paid is null when the parent was not found; not_found is raised further down.
  if v_paid is not null and coalesce(v_amount, 0) <> 0 then
    if v_refund then
      if v_paid - abs(v_amount) < 0 then
        raise exception 'refund_exceeds_paid'
          using hint = 'only ' || _rupees(greatest(v_paid, 0)) || ' was collected';
      end if;
    elsif v_amount > 0 and v_billed is not null and v_pay <> 'waived'
          and v_paid + v_amount > v_billed then
      raise exception 'overpayment'
        using hint = case when v_billed - v_paid <= 0 then 'this bill is already paid'
                          else 'only ' || _rupees(v_billed - v_paid) || ' is due' end;
    end if;
  end if;

  -- Amount, sign, refund reason and method.
  if v_amount is null or v_amount = 0 then raise exception 'amount_zero'; end if;
  if v_refund then
    if coalesce(btrim(p->>'reason'), '') = '' then raise exception 'refund_reason_required'; end if;
    v_amount := -abs(v_amount);
  elsif v_amount < 0 then
    raise exception 'amount_negative';
  end if;
  if (p->>'method') not in ('cash','upi','card','other') then raise exception 'invalid_method'; end if;

  -- Record the payment and recompute the parent's payment status (a waived bill
  -- keeps 'waived').
  select status, payment_status, billed_amount_paise into v_status, v_pay, v_billed
    from sessions where id = v_parent and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'session'; end if;
  if v_status = 'voided' and not v_refund then
    raise exception 'voided' using hint = 'a voided bill takes no payments; a refund is allowed';
  end if;
  insert into payments(id, arena_id, session_id, amount_paise, method, kind, note, reason,
      created_by, created_at)
    values ((p->>'payment_id')::uuid, p_arena, v_parent, v_amount, p->>'method',
      case when v_refund then 'refund' else 'payment' end, p->>'note', p->>'reason',
      auth.uid(), v_now);
  if v_pay <> 'waived' and v_status <> 'voided' then
    select coalesce(sum(amount_paise), 0) into v_paid from payments where session_id = v_parent;
    v_pay := _payment_status(v_billed, v_paid);
    update sessions set payment_status = v_pay, updated_at = v_now where id = v_parent;
  end if;
  return jsonb_build_object('payment_status', v_pay);
end;
$function$;

create or replace function public.op_payment_correct (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now       timestamptz := statement_timestamp();
  v_parent    uuid := (p->>'parent_id')::uuid;
  v_payment   uuid := (p->>'payment_id')::uuid;
  v_method    text := p->>'method';
  v_reason    text := nullif(btrim(coalesce(p->>'reason', '')), '');
  v_refund_id uuid := coalesce(nullif(p->>'refund_id', '')::uuid, gen_random_uuid());
  v_new_id    uuid := coalesce(nullif(p->>'new_payment_id', '')::uuid, gen_random_uuid());
  v_old_method text; v_old_amount bigint; v_was_refund boolean;
  v_moved bigint; v_left bigint; v_amount bigint;
begin
  perform _need(p_arena, 'money');
  if coalesce(p->>'scope', 'single') <> 'single' then
    raise exception 'invalid_payload' using hint = 'scope';
  end if;
  if v_reason is null then
    raise exception 'reason_required' using hint = 'say what was recorded wrongly';
  end if;
  if length(v_reason) > 500 then raise exception 'reason_too_long' using hint = 'at most 500 characters'; end if;
  if v_method is null or v_method not in ('cash', 'upi', 'card', 'other') then
    raise exception 'invalid_method';
  end if;

  -- Lock the bill (as op_payment does), so payments and corrections on it queue here.
  perform 1 from sessions where id = v_parent and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'session'; end if;
  select method, amount_paise, kind = 'refund' into v_old_method, v_old_amount, v_was_refund
    from payments where id = v_payment and session_id = v_parent and arena_id = p_arena;
  if not found then raise exception 'not_found' using hint = 'payment'; end if;
  if v_was_refund then
    raise exception 'not_a_payment' using hint = 'only a payment can be moved to another method';
  end if;
  if v_method = v_old_method then
    raise exception 'same_method' using hint = 'that payment is already recorded as ' || v_old_method;
  end if;

  -- What earlier corrections already moved out of this payment.
  select coalesce(sum((after->>'amount_paise')::bigint), 0) into v_moved
    from audit_log
   where arena_id = p_arena and entity_type = 'session' and entity_id = v_parent
     and action = 'payment_correct' and before->>'payment_id' = v_payment::text;
  v_left := v_old_amount - v_moved;
  if v_left <= 0 then
    raise exception 'already_corrected' using hint = 'all of this payment was already moved';
  end if;
  v_amount := coalesce((p->>'amount_paise')::bigint, v_left);
  if v_amount <= 0 or v_amount > v_left then
    raise exception 'amount_invalid' using hint = 'at most ' || _rupees(v_left) || ' can be moved';
  end if;

  insert into payments(id, arena_id, session_id, amount_paise, method, kind, note, reason,
      created_by, created_at)
    values
      (v_refund_id, p_arena, v_parent, -v_amount, v_old_method, 'refund', 'Method correction',
        v_reason, auth.uid(), v_now),
      (v_new_id, p_arena, v_parent, v_amount, v_method, 'payment', 'Method correction',
        v_reason, auth.uid(), v_now);

  insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
      created_by, created_at)
    values (p_arena, 'session', v_parent, 'payment_correct', v_reason,
      jsonb_build_object('payment_id', v_payment, 'method', v_old_method,
        'amount_paise', v_old_amount),
      jsonb_build_object('method', v_method, 'amount_paise', v_amount,
        'refund_id', v_refund_id, 'payment_id', v_new_id),
      auth.uid(), v_now);
  return jsonb_build_object('moved_paise', v_amount, 'refund_id', v_refund_id,
    'payment_id', v_new_id);
end;
$function$;

create or replace function public.op_policy_save (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare j jsonb := p->'policy'; v_id uuid;
begin
  perform _need(p_arena, 'settings');
  select id into v_id from billing_policies where arena_id = p_arena and active
    order by created_at limit 1 for update;
  if not found then
    insert into billing_policies(arena_id, name) values (p_arena, 'Default') returning id into v_id;
  end if;
  update billing_policies set
      billing_unit = j->>'billing_unit', block_rounding = j->>'block_rounding',
      grace_minutes = (j->>'grace_minutes')::int,
      minimum_charge_minutes = (j->>'minimum_charge_minutes')::int,
      early_exit = j->>'early_exit', rounding_scope = j->>'rounding_scope',
      late_arrival = j->>'late_arrival', vr_unit_rounding = j->>'vr_unit_rounding',
      money_rounding_paise = (j->>'money_rounding_paise')::int,
      money_rounding_dir = j->>'money_rounding_dir', payment_timing = j->>'payment_timing',
      allow_extend_past_close = (j->>'allow_extend_past_close')::boolean,
      cleaning_gap_minutes = (j->>'cleaning_gap_minutes')::int,
      updated_at = statement_timestamp()
    where id = v_id;
  return '{}'::jsonb;
end;
$function$;

create or replace function public.op_resource_set_mode (
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
  perform _need(p_arena, 'settings');
  perform 1 from resources where id = v_id and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'resource'; end if;
  if exists (select 1 from session_segments where resource_id = v_id and ended_at is null) then
    raise exception 'mode_switch_busy';
  end if;
  update resources set current_mode = nullif(p->>'mode',''), updated_at = statement_timestamp()
    where id = v_id;
  return '{}'::jsonb;
end;
$function$;

create or replace function public.op_resource_set_status (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_id     uuid := (p->>'id')::uuid;
  v_status text := p->>'status';
begin
  perform _need(p_arena, 'settings');
  perform _lock_resources(p_arena, array[v_id]);
  if not exists (select 1 from resources where id = v_id and arena_id = p_arena) then
    raise exception 'not_found' using hint = 'resource';
  end if;
  if v_status is distinct from 'available' then
    if exists (select 1 from session_segments
                where arena_id = p_arena and resource_id = v_id and ended_at is null) then
      raise exception 'resource_busy' using hint = 'open session';
    end if;
  end if;
  update resources set status = v_status, updated_at = statement_timestamp()
    where id = v_id and arena_id = p_arena;
  return '{}'::jsonb;
end;
$function$;

create or replace function public.op_resource_upsert (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare v_id uuid := (p->>'id')::uuid; v_code text; v_old text;
begin
  perform _need(p_arena, 'settings');
  -- An id that belongs to another arena is "not found" here, never overwritten.
  if exists (select 1 from resources where id = v_id and arena_id <> p_arena) then
    raise exception 'not_found' using hint = 'resource';
  end if;
  perform _lock_resources(p_arena, array[v_id]);
  select status into v_old from resources where id = v_id and arena_id = p_arena;
  if found and p ? 'status' and (p->>'status') is distinct from v_old
     and (p->>'status') is distinct from 'available'
     and exists (select 1 from session_segments
                  where arena_id = p_arena and resource_id = v_id and ended_at is null) then
    raise exception 'resource_busy' using hint = 'in use';
  end if;
  insert into resources(id, arena_id, name, kind, status, sort_order)
    values (v_id, p_arena, p->>'name', p->>'kind', coalesce(p->>'status', 'available'),
      coalesce((p->>'sort_order')::int, 0))
  on conflict (id) do update set name = excluded.name, kind = excluded.kind,
      status = case when p ? 'status' then excluded.status else resources.status end,
      sort_order = excluded.sort_order, updated_at = statement_timestamp()
    where resources.arena_id = p_arena;
  -- The station supports exactly the listed activities.
  delete from resource_activities ra using activities a
   where ra.resource_id = v_id and a.id = ra.activity_id
     and not (a.code = any(array(select jsonb_array_elements_text(coalesce(p->'activity_codes','[]'::jsonb)))));
  for v_code in select jsonb_array_elements_text(coalesce(p->'activity_codes', '[]'::jsonb)) loop
    insert into resource_activities(arena_id, resource_id, activity_id)
      values (p_arena, v_id, _activity_id(p_arena, v_code))
    on conflict (resource_id, activity_id) do nothing;
  end loop;
  return '{}'::jsonb;
end;
$function$;

create or replace function public.op_session_end (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now timestamptz := statement_timestamp();
  v_session uuid := (p->>'session_id')::uuid;
  v_ended timestamptz := (p->>'ended_at')::timestamptz;
  v_waive boolean := coalesce((p->>'mark_waived')::boolean, false);
  v_billed bigint := (p->>'billed_amount_paise')::bigint;
  v_status text; v_end timestamptz; v_segs uuid[]; v_paid bigint; v_pay text; v_c jsonb;
  v_bill jsonb; v_keys text[]; v_disc bigint := 0; v_total bigint; pol jsonb;
  v_moved boolean := jsonb_typeof(p->'end_moved') = 'object';
  v_from timestamptz := (p->'end_moved'->>'from')::timestamptz;
  v_end_reason text := nullif(btrim(coalesce(p->'end_moved'->>'reason', '')), '');
  v_from_bill bigint;
begin
  perform _need(p_arena, 'bill');
  perform _client_time(p_arena, v_ended, 'ended_at');
  if v_waive then
    perform _need(p_arena, 'discount');
    if nullif(btrim(coalesce(p->>'waive_reason', '')), '') is null then
      raise exception 'waive_reason_required';
    end if;
  end if;
  -- An end set earlier than when staff ended it lowers the bill: it needs a reason and is audited.
  if v_moved then
    if v_end_reason is null then
      raise exception 'end_reason_required' using hint = 'say why the end was moved earlier';
    end if;
    if length(v_end_reason) > 500 then
      raise exception 'reason_too_long' using hint = 'at most 500 characters';
    end if;
    if v_from is null or v_from <= v_ended then
      raise exception 'invalid_time' using hint = 'end_moved.from must be after ended_at';
    end if;
    perform _client_time(p_arena, v_from, 'end_moved.from');
  end if;
  select status, scheduled_end_at into v_status, v_end
    from sessions where id = v_session and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'session'; end if;
  if v_status <> 'active' then raise exception 'not_active' using hint = v_status; end if;
  select coalesce(array_agg(id), '{}') into v_segs from session_segments where session_id = v_session;
  if not _same_ids(v_segs, _jsonb_uuids(p->'expected_segment_ids'))
     or v_end is distinct from (p->>'expected_scheduled_end_at')::timestamptz then
    raise exception 'stale' using hint = 'the session was changed on another device';
  end if;
  -- What the bill would have been at the original end (segments are still open here).
  if v_moved then
    v_from_bill := (_pr_session_bill(v_session, v_from,
      coalesce((p->>'charge_overtime')::boolean, false))->>'total')::bigint;
  end if;

  update session_segments set ended_at = v_ended where session_id = v_session and ended_at is null;
  update controller_allocations set ended_at = v_ended where session_id = v_session and ended_at is null;
  for v_c in select value from jsonb_array_elements(coalesce(p->'charges', '[]'::jsonb)) loop
    insert into session_charges(id, arena_id, session_id, segment_id, segment_index, band_code,
        activity_code, resource_id, controller_count, segment_start, segment_end, played_minutes,
        billed_minutes, unit_minutes, unit_price_paise, amount_paise, created_at)
      values ((v_c->>'id')::uuid, p_arena, v_session, nullif(v_c->>'segment_id','')::uuid,
        (v_c->>'segment_index')::int, v_c->>'band_code', v_c->>'activity_code',
        nullif(v_c->>'resource_id','')::uuid, nullif(v_c->>'controller_count','')::int,
        (v_c->>'segment_start')::timestamptz, (v_c->>'segment_end')::timestamptz,
        (v_c->>'played_minutes')::int, (v_c->>'billed_minutes')::int,
        (v_c->>'unit_minutes')::int, (v_c->>'unit_price_paise')::bigint,
        (v_c->>'amount_paise')::bigint, v_now);
  end loop;
  select coalesce(sum(amount_paise), 0) into v_paid from payments where session_id = v_session;
  v_pay := case when v_waive then 'waived' else _payment_status(v_billed, v_paid) end;
  update sessions set status = 'completed', actual_ended_at = v_ended,
      billed_amount_paise = v_billed, payment_status = v_pay, updated_at = v_now,
      ended_recorded_at = v_now
    where id = v_session;
  -- A waive writes off what was not paid: audited with the amount and the staff reason
  -- (waive_reason, required: waive_reason_required).
  if v_waive then
    insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
        created_by, created_at)
      values (p_arena, 'session', v_session, 'waive',
        nullif(btrim(coalesce(p->>'waive_reason', '')), ''),
        jsonb_build_object('billed_paise', v_billed, 'paid_paise', v_paid),
        jsonb_build_object('written_off_paise', greatest(coalesce(v_billed, 0) - v_paid, 0)),
        auth.uid(), v_now);
  end if;
  if v_moved then
    insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
        created_by, created_at)
      values (p_arena, 'session', v_session, 'end_moved', v_end_reason,
        jsonb_build_object('ended_at', v_from, 'billed_paise', v_from_bill),
        jsonb_build_object('ended_at', v_ended, 'billed_paise', v_billed),
        auth.uid(), v_now);
  end if;

  -- Server-side pricing (0013): re-price the bill from the stored segments and
  -- refuse the op unless the total AND every charge row match exactly.
  if exists (select 1 from session_segments where session_id = v_session and ended_at < started_at) then
    raise exception 'invalid_time' using hint = 'the end is before the current segment started';
  end if;
  v_bill := _pr_session_bill(v_session, v_ended, coalesce((p->>'charge_overtime')::boolean, false));
  v_total := (v_bill->>'total')::bigint;
  -- A discount (preset, coupon or manual) comes off the subtotal before cash rounding.
  if jsonb_typeof(p->'discount') = 'object' then
    if v_waive then raise exception 'invalid_discount' using hint = 'a waived bill takes no discount'; end if;
    v_disc := _discount_apply(p_arena, p->'discount', v_bill, v_ended, v_session);
    select _pr_policy(pricing_snapshot) into pol from sessions where id = v_session;
    v_total := _pr_money((v_bill->>'subtotal')::bigint - v_disc, (pol->>'money_rounding_paise')::int,
      pol->>'money_rounding_dir');
  end if;
  -- Below owner level a waive is capped like a manual discount.
  if v_waive then perform _waive_check(p_arena, v_billed, v_paid); end if;
  if v_total is distinct from v_billed then
    perform _price_mismatch('bill', v_total, v_billed);
  end if;
  select coalesce(array_agg(k order by k), '{}') into v_keys from (
    select _pr_charge_key(activity_code, resource_id, controller_count, band_code, segment_start,
      segment_end, played_minutes, billed_minutes, unit_minutes, unit_price_paise, amount_paise) k
      from session_charges where session_id = v_session) t;
  if v_keys <> array(select jsonb_array_elements_text(v_bill->'keys')) then
    raise exception 'price_mismatch' using hint = 'charge rows differ from the server''s bill';
  end if;
  return jsonb_build_object('payment_status', v_pay);
end;
$function$;

create or replace function public.op_session_reconfigure (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now timestamptz := statement_timestamp();
  v_session uuid := (p->>'session_id')::uuid;
  v_at timestamptz := (p->>'at')::timestamptz;
  v_resource uuid := (p->>'resource_id')::uuid;
  v_game uuid := nullif(p->>'game_id','')::uuid;
  v_act text := p->>'activity_code';
  v_cc int := nullif(p->>'controller_count','')::int;
  v_new uuid := (p->>'new_segment_id')::uuid;
  v_borrow uuid[] := _pad_ids(p->'moves');
  v_pads uuid[] := _pad_ids(p->'allocations');
  v_status text; v_open uuid; v_open_res uuid; v_open_start timestamptz; v_idx int; v_open_cc int;
  v_skipped int;
  v_origins uuid[];
begin
  perform _need(p_arena, 'start');
  perform _client_time(p_arena, v_at, 'at');
  select status into v_status from sessions where id = v_session and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'session'; end if;
  if v_status <> 'active' then raise exception 'not_active' using hint = v_status; end if;
  select id, resource_id, started_at, idx, controller_count
    into v_open, v_open_res, v_open_start, v_idx, v_open_cc
    from session_segments where session_id = v_session and ended_at is null;
  if not found then raise exception 'no_open_segment'; end if;
  if v_open is distinct from nullif(p->>'expected_segment_id','')::uuid then
    raise exception 'stale' using hint = 'the session was changed on another device';
  end if;
  if v_at < v_open_start then raise exception 'invalid_time'; end if;

  v_origins := _pad_origins(p_arena, v_borrow);
  perform _lock_resources(p_arena, array[v_resource, v_open_res] || v_origins);
  perform _lock_pads(p_arena, v_borrow || v_pads);
  if not (_pad_origins(p_arena, v_borrow) <@ (array[v_resource, v_open_res] || v_origins)) then
    raise exception 'retry' using errcode = '40001';
  end if;

  if v_resource <> v_open_res then
    perform _station_usable(p_arena, v_resource);
    perform _station_free_for_single(v_resource);
  end if;
  perform _game_playable(v_game, v_resource);
  perform _single_supply(p_arena, v_resource, v_act, v_game,
    coalesce(array_length(v_pads, 1), 0), v_cc, v_open_res, v_open_cc);
  perform _seg_priced(p_arena, v_resource,
    (select pricing_snapshot from sessions where id = v_session), v_act, v_cc);

  update session_segments set ended_at = v_at where id = v_open;
  update controller_allocations set ended_at = v_at where segment_id = v_open and ended_at is null;
  insert into session_segments(id, arena_id, session_id, idx, resource_id, activity_code,
      game_id, controller_count, started_at, created_at)
    values (v_new, p_arena, v_session, v_idx + 1, v_resource, v_act, v_game, v_cc, v_at, v_now);
  v_skipped := _pad_borrow(p_arena, p->'moves', v_resource, 's:' || v_session::text, v_at);
  perform _pad_allocate(p_arena, p->'allocations', v_session, v_new, v_resource, v_act, v_game,
    v_at);
  update sessions set updated_at = v_now where id = v_session;
  if v_game is not null then
    update games set last_played_at = v_at, updated_at = v_now where id = v_game and arena_id = p_arena;
  end if;
  return jsonb_build_object('segment_id', v_new, 'adjusted', v_skipped > 0);
end;
$function$;

create or replace function public.op_session_record (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now      timestamptz := statement_timestamp();
  v_id       uuid := (p->>'session_id')::uuid;
  v_pay_id   uuid := (p->>'payment_id')::uuid;
  v_customer uuid := (p->>'customer_id')::uuid;
  v_res      uuid := (p->>'resource_id')::uuid;
  v_act      text := p->>'activity_code';
  v_game     uuid := nullif(p->>'game_id', '')::uuid;
  v_cc       integer := nullif(p->>'controller_count', '')::int;
  v_start    timestamptz := (p->>'started_at')::timestamptz;
  v_end      timestamptz := (p->>'ended_at')::timestamptz;
  v_method   text := p->>'method';
  v_billed   bigint := (p->>'billed_amount_paise')::bigint;
  v_reason   text := nullif(btrim(coalesce(p->>'reason', '')), '');
  v_snap jsonb; v_seg uuid := gen_random_uuid(); q jsonb; l jsonb; v_bill jsonb;
  v_total bigint; v_pay text;
begin
  perform _need(p_arena, 'bill_record');
  if v_reason is null then
    raise exception 'reason_required' using hint = 'say why the bill is added later';
  end if;
  if length(v_reason) > 500 then raise exception 'reason_too_long' using hint = 'at most 500 characters'; end if;
  if v_id is null or v_pay_id is null or v_customer is null or v_res is null or v_act is null
     or v_start is null or v_end is null or v_billed is null or v_billed < 0
     or (v_cc is not null and v_cc not between 1 and 4) then
    raise exception 'invalid_payload';
  end if;
  if v_method is null or v_method not in ('cash', 'upi', 'card', 'other') then
    raise exception 'invalid_method' using hint = 'how the bill was paid';
  end if;
  if v_end > v_now + interval '2 minutes' then
    raise exception 'time_in_future' using hint = 'ended_at';
  end if;
  if v_end <= v_start or v_end - v_start > interval '24 hours' then
    raise exception 'invalid_time' using hint = 'the end must be after the start, at most 24 h later';
  end if;
  if not exists (select 1 from customers where id = v_customer and arena_id = p_arena) then
    raise exception 'not_found' using hint = 'customer';
  end if;
  -- Lock the station so two missed bills for the same time cannot both pass the overlap check.
  perform 1 from resources where id = v_res and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'station'; end if;
  if v_game is not null and not exists (select 1 from games where id = v_game and arena_id = p_arena) then
    raise exception 'not_found' using hint = 'game';
  end if;
  if exists (select 1 from session_segments
              where resource_id = v_res and arena_id = p_arena
                and tstzrange(started_at, coalesce(ended_at, 'infinity')) && tstzrange(v_start, v_end)) then
    raise exception 'overlap' using hint = 'the station already has play recorded in that time';
  end if;

  v_snap := _pricing_snapshot(p_arena);
  perform _seg_priced(p_arena, v_res, v_snap, v_act, v_cc);

  insert into sessions(id, arena_id, customer_id, status, payment_status, started_at,
      scheduled_end_at, actual_ended_at, pricing_snapshot, policy_snapshot, billed_amount_paise,
      created_at, updated_at, created_by, ended_recorded_at)
    values (v_id, p_arena, v_customer, 'completed', 'unpaid', v_start, v_end, v_end, v_snap,
      v_snap->'policy', v_billed, v_now, v_now, auth.uid(), v_now);
  insert into session_segments(id, arena_id, session_id, idx, resource_id, activity_code, game_id,
      controller_count, started_at, ended_at, created_at)
    values (v_seg, p_arena, v_id, 0, v_res, v_act, v_game, v_cc, v_start, v_end, v_now);

  -- Charge rows straight from the server's quote (the same lines _pr_session_bill keys).
  q := _pr_quote(v_snap, v_act, v_cc, v_start, v_end, v_start);
  for l in select value from jsonb_array_elements(coalesce(q->'lines', '[]'::jsonb)) loop
    insert into session_charges(id, arena_id, session_id, segment_id, segment_index, band_code,
        activity_code, resource_id, controller_count, segment_start, segment_end, played_minutes,
        billed_minutes, unit_minutes, unit_price_paise, amount_paise, created_at)
      values (gen_random_uuid(), p_arena, v_id, v_seg, 0, l->>'band', v_act, v_res, v_cc,
        (l->>'start')::timestamptz, (l->>'end')::timestamptz,
        ((l->>'played_seconds')::bigint / 60)::int, (l->>'billed_minutes')::int,
        (l->>'unit_minutes')::int, (l->>'unit_price')::bigint, (l->>'amount')::bigint, v_now);
  end loop;
  v_bill := _pr_session_bill(v_id, v_end, true);
  v_total := (v_bill->>'total')::bigint;
  if v_total is distinct from v_billed then
    perform _price_mismatch('bill', v_total, v_billed);
  end if;

  if v_total > 0 then
    insert into payments(id, arena_id, session_id, amount_paise, method, kind, note, reason,
        created_by, created_at)
      values (v_pay_id, p_arena, v_id, v_total, v_method, 'payment', 'Added later', v_reason,
        auth.uid(), v_now);
  end if;
  v_pay := _payment_status(v_total, v_total);
  update sessions set payment_status = v_pay where id = v_id;

  update customers set last_visit_at = greatest(coalesce(last_visit_at, v_start), v_start)
    where id = v_customer;
  if v_game is not null then
    update games set last_played_at = greatest(coalesce(last_played_at, v_start), v_start)
      where id = v_game;
  end if;

  insert into audit_log(arena_id, entity_type, entity_id, action, reason, before, after,
      created_by, created_at)
    values (p_arena, 'session', v_id, 'record', v_reason, null,
      jsonb_build_object('billed_paise', v_total, 'method', v_method, 'resource_id', v_res,
        'started_at', v_start, 'ended_at', v_end),
      auth.uid(), v_now);
  return jsonb_build_object('session_id', v_id, 'billed_amount_paise', v_total,
    'payment_status', v_pay);
end;
$function$;

create or replace function public.op_session_start (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now      timestamptz := statement_timestamp();
  v_session  uuid := (p->>'id')::uuid;
  v_segment  uuid := (p->>'segment_id')::uuid;
  v_resource uuid := (p->>'resource_id')::uuid;
  v_game     uuid := nullif(p->>'game_id','')::uuid;
  v_started  timestamptz := (p->>'started_at')::timestamptz;
  v_customer uuid := (p->>'customer_id')::uuid;
  v_booking  uuid := nullif(p->>'booking_id','')::uuid;
  v_act      text := p->>'activity_code';
  v_cc       int  := nullif(p->>'controller_count','')::int;
  v_borrow   uuid[] := _pad_ids(p->'moves');
  v_pads     uuid[] := _pad_ids(p->'allocations');
  v_bstatus  text;
  v_skipped  int;
  v_origins  uuid[];
begin
  perform _need(p_arena, 'start');
  perform _client_time(p_arena, v_started, 'started_at');
  v_origins := _pad_origins(p_arena, v_borrow);
  perform _lock_resources(p_arena, array[v_resource] || v_origins);
  perform _lock_pads(p_arena, v_borrow || v_pads);
  -- A pad that moved between the read and the lock sits at a station we do not
  -- hold: retry rather than check it unlocked.
  if not (_pad_origins(p_arena, v_borrow) <@ (array[v_resource] || v_origins)) then
    raise exception 'retry' using errcode = '40001';
  end if;

  perform _station_usable(p_arena, v_resource);
  perform _game_playable(v_game, v_resource);
  perform _single_supply(p_arena, v_resource, v_act, v_game,
    coalesce(array_length(v_pads, 1), 0), v_cc);
  perform _station_free_for_single(v_resource);

  if v_booking is not null then
    select status into v_bstatus from bookings
      where id = v_booking and arena_id = p_arena for update;
    if not found then raise exception 'booking_missing'; end if;
    if v_bstatus <> 'booked' then raise exception 'booking_not_open' using hint = v_bstatus; end if;
    update bookings set status = 'checked_in', updated_at = v_now where id = v_booking;
  end if;

  insert into sessions(id, arena_id, booking_id, customer_id, status, payment_status,
      started_at, scheduled_end_at, pricing_snapshot, policy_snapshot, request_id,
      created_by, created_at, updated_at)
    values (v_session, p_arena, v_booking, v_customer, 'active', 'unpaid', v_started,
      (p->>'scheduled_end_at')::timestamptz, p->'pricing_snapshot',
      coalesce(p->'pricing_snapshot'->'policy', '{}'::jsonb), null, auth.uid(), v_now, v_now);
  insert into session_segments(id, arena_id, session_id, idx, resource_id, activity_code,
      game_id, controller_count, started_at, created_at)
    values (v_segment, p_arena, v_session, 0, v_resource, v_act, v_game, v_cc, v_started, v_now);

  v_skipped := _pad_borrow(p_arena, p->'moves', v_resource, 's:' || v_session::text, v_started);
  perform _pad_allocate(p_arena, p->'allocations', v_session, v_segment, v_resource, v_act, v_game,
    v_started);

  update customers set last_visit_at = v_started, updated_at = v_now
    where id = v_customer and arena_id = p_arena;
  if v_game is not null then
    update games set last_played_at = v_started, updated_at = v_now where id = v_game and arena_id = p_arena;
  end if;

  -- The price list the device froze into the session must be this arena's
  -- current one (0013); checked last so earlier errors keep their precedence.
  perform _assert_snapshot(p_arena, p->'pricing_snapshot');
  -- And the segment must be billable from it (no ₹0 segments).
  perform _seg_priced(p_arena, v_resource, p->'pricing_snapshot', v_act, v_cc);
  return jsonb_build_object('session_id', v_session, 'adjusted', v_skipped > 0);
end;
$function$;

alter table "public"."controller_allocations"
  add constraint "controller_allocations_scope_check" check ((scope = 'single'::text));

create trigger t_same_arena
  before insert or update on public.bill_discounts
  for each row
  execute function public._assert_same_arena('session_id', 'sessions', 'discount_id', 'discounts');

create trigger t_same_arena
  before insert or update on public.controller_allocations
  for each row
  execute function
    public._assert_same_arena('controller_id', 'controllers', 'game_id', 'games', 'resource_id',
    'resources', 'segment_id', 'session_segments', 'session_id', 'sessions');

comment on column "public"."audit_log"."entity_type" is 'Kind of row acted on, e.g. session or customer.';

comment on column "public"."controller_allocations"."scope" is 'Always single (session_id + segment_id set); kept for the device''s row shape.';

comment on column "public"."controller_allocations"."started_at" is 'When the pad was handed out (UTC; the segment start).';

comment on column "public"."controller_moves"."session_ref" is 'For a loan, the borrowing session as app text ''s:<session id>'' (not an FK); null otherwise.';

comment on column "public"."controllers"."loan_session_ref" is 'Set while on loan: the session that owes the return, as s:<sessionId> (app reference string, not a foreign key).';

comment on column "public"."customers"."last_visit_at" is 'Start time of the customer''s latest session (UTC); set by op_session_start.';

comment on column "public"."games"."last_played_at" is 'Start time (UTC) of the latest session segment on this game.';

comment on column "public"."games"."max_local_players" is 'Most players (controllers) one system may use at once on this title, 1-8. Starts and reconfigures above it are refused with players_exceeded.';

comment on function "private"."arena_sales"(uuid, timestamp with time zone, timestamp
  with time zone) is 'Client API (owner level): the arena''s closed bills (sessions, completed or voided) that closed in [from, to), newest first, for the admin dashboard''s Sales screen. At most 93 days.';

comment on function "private"."my_bills"(uuid, date) is 'Client API (bill_edit or bill_record): the caller''s own closed bills (sessions they started) that closed on the given IST day, newest first, as _sales summaries — the floor app''s My bills.';

comment on function "private"."sync_fetch_entity"(uuid, jsonb) is 'Client API (sync): for each {type, id} ref, return the server''s current rows for that whole entity (session, controller, customer or booking) so a device can replace its copy after a refused op.';

comment on function "public"."_discount_apply"(uuid, jsonb, jsonb, timestamp
  with time zone, uuid) is 'Validates a preset, coupon or manual discount against a bill, records it in bill_discounts and returns the paise taken off.';

comment on function "public"."_pad_allocate"(uuid, jsonb, uuid, uuid, uuid, text, uuid, timestamp
  with time zone) is 'Validates and inserts controller allocations for a session segment.';

comment on function "public"."_pad_borrow"(uuid, jsonb, uuid, text, timestamp
  with time zone) is 'Moves pads to a station for a session, recording loans and returns home; returns how many were already there.';

comment on function "public"."_plays"(uuid, timestamp with time zone) is 'Internal (dashboard reads): session segments of non-voided bills started since an instant or still open, with minutes played.';

comment on function "public"."_pricing_grace"() is 'Pricing: window (72 hours) during which a retired price list is still accepted at session start.';

comment on function "public"."_sales"(uuid, timestamp with time zone, timestamp
  with time zone, uuid) is 'Closed bills (completed or voided sessions) of an arena as jsonb summaries with their payments ledger, by close time range or by id. Server-only body of arena_sales / arena_sale.';

comment on function "public"."_station_free_for_single"(uuid) is 'Raises resource_busy when the station has an open session segment.';

comment on function "public"."arena_sales"(uuid, timestamp with time zone, timestamp
  with time zone) is 'Client API (owner level): the arena''s closed bills (sessions, completed or voided) that closed in [from, to), newest first, for the admin dashboard''s Sales screen. At most 93 days.';

comment on function "public"."assert_resource_free_for_segment"() is 'Trigger (session_segments): refuse an open segment on a station that already has an open segment (resource_busy), serialised by locking the station row.';

comment on function "public"."op_game_delete"(uuid, jsonb) is 'Sync op game.delete: permanently deletes a game no session, pad allocation or booking ever used (with its station statuses and control guide); refuses one in play (game_in_play) or with history (game_has_history: archive it instead).';

comment on function "public"."op_payment"(uuid, jsonb) is 'Sync op payment.record: records a payment or refund on a session, refusing overpayment of a final bill or a refund beyond what was paid.';

comment on function "public"."op_resource_set_status"(uuid, jsonb) is 'Sync op resource.set_status: puts a station in or out of service or removes it; refuses anything but available while a session is on it (resource_busy).';

comment on function "public"."sync_fetch_entity"(uuid, jsonb) is 'Client API (sync): for each {type, id} ref, return the server''s current rows for that whole entity (session, controller, customer or booking) so a device can replace its copy after a refused op.';

comment on table "public"."bill_discounts" is 'The discount applied to a session''s bill, with a snapshot of the discount, the amount taken off, who applied it and why. Append-only; one per bill.';

comment on table "public"."controller_allocations" is 'Append-only per-pad timeline: which physical controller was used by which session segment, where, and when. An open row (ended_at null) means the pad is in a player''s hands.';

comment on table "public"."customers" is 'Customers of an arena: registered members and per-visit walk-in guest records. Referenced by sessions and bookings.';

comment on table "public"."resources" is 'Bookable places on the floor (gaming stations, pool tables, rooms). Sessions, bookings and controllers point at them.';

comment on table "public"."session_segments" is 'One stretch of a single session on one station, activity, game and controller count. The open segment (ended_at null) is where the session is now; at most one open segment per station.';

revoke all
  on function "public"."_discount_apply"(uuid, jsonb, jsonb, timestamp with time zone, uuid)
  from public;

grant execute
  on function "public"."_discount_apply"(uuid, jsonb, jsonb, timestamp with time zone, uuid)
  to "postgres", "service_role";

revoke all
  on function "public"."_pad_allocate"(uuid, jsonb, uuid, uuid, uuid, text, uuid, timestamp
    with time zone)
  from public;

grant execute
  on function "public"."_pad_allocate"(uuid, jsonb, uuid, uuid, uuid, text, uuid, timestamp
    with time zone)
  to "postgres", "service_role";
