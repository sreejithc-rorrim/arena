-- Pre-release data inventory — READ ONLY (selects only; changes nothing)
--
-- Prepared 2026-10-22 for the production project (oilylxydibubupuqghbw) ahead of
-- prod_prerelease_reset.sql. Run each query (Q0–Q7) on its own in the production
-- SQL Editor (select the query text → Run): the editor shows only the last result
-- of a script. Save every result (CSV export) before the reset; Q0 and Q7 are run
-- again afterwards and compared.
--
-- Never run this with `supabase … --linked`: this repository is linked to the old
-- hosted DEVELOPMENT project, not production.
--
-- The output contains personal data (e-mails, names, phone counts): keep the
-- exports out of the repository and chat.


-- Q0. Row count of every public table (empty tables included).
select c.relname as table_name,
       (xpath('/row/n/text()',
              query_to_xml(format('select count(*) as n from public.%I', c.relname), false, true, '')
       ))[1]::text::bigint as rows
from pg_class c
where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
order by c.relname;


-- Q1. Rows per table and arena (every public table with an arena_id column).
select col.table_name,
       x.arena_id::uuid as arena_id,
       a.name           as arena_name,
       x.n              as rows
from information_schema.columns col
join pg_tables pt on pt.schemaname = 'public' and pt.tablename = col.table_name
cross join lateral xmltable(
  '/table/row' passing query_to_xml(
    format('select arena_id::text as arena_id, count(*) as n from public.%I group by 1', col.table_name),
    true, false, '')
  columns arena_id text path 'arena_id', n bigint path 'n') x
left join public.arenas a on a.id = x.arena_id::uuid
where col.table_schema = 'public' and col.column_name = 'arena_id'
order by a.name nulls first, col.table_name;


-- Q2. Arenas: owners, people, activity window and money (identify test arenas).
select a.id, a.name, a.area, a.created_at,
       (select string_agg(sp.name || ' <' || coalesce(u.email, '?') || '>'
                          || case when sp.active then '' else ' (inactive)' end, ', ' order by sp.created_at)
          from public.staff_profiles sp left join auth.users u on u.id = sp.user_id
         where sp.arena_id = a.id and sp.role = 'owner')                         as owners,
       (select count(*) from public.staff_profiles sp
         where sp.arena_id = a.id and sp.role = 'staff')                         as staff_profiles,
       (select count(*) from public.resources r where r.arena_id = a.id)         as stations,
       (select count(*) from public.games g where g.arena_id = a.id)             as games,
       (select count(*) from public.customers c where c.arena_id = a.id)         as customers,
       (select count(*) from public.sessions s where s.arena_id = a.id)          as sessions,
       (select count(*) from public.payments p where p.arena_id = a.id)          as payment_rows,
       (select round(coalesce(sum(p.amount_paise), 0) / 100.0, 2)
          from public.payments p where p.arena_id = a.id)                        as session_payments_rupees_raw,
       (select count(*) from public.attendance_punches p where p.arena_id = a.id) as punches,
       (select count(*) from public.salary_runs s where s.arena_id = a.id)       as salary_runs,
       (select min(o.created_at) from public.sync_ops o where o.arena_id = a.id) as first_op_at,
       (select max(o.created_at) from public.sync_ops o where o.arena_id = a.id) as last_op_at,
       (select max(p.created_at) from public.payments p where p.arena_id = a.id) as last_payment_at
from public.arenas a
order by a.created_at;


-- Q3. Auth users: memberships and activity (identify test logins).
select u.id, u.email, u.created_at, u.last_sign_in_at,
       u.email_confirmed_at is not null                                   as confirmed,
       u.raw_app_meta_data ->> 'provider'                                 as provider,
       (select string_agg(a.name || ': ' || sp.role
                          || case when sp.active then '' else ' (inactive)' end, ', ' order by a.name)
          from public.staff_profiles sp join public.arenas a on a.id = sp.arena_id
         where sp.user_id = u.id)                                         as memberships,
       (select count(*) from public.staff_invites i
         where i.email = lower(u.email) and i.accepted_at is null
           and i.revoked_at is null and i.expires_at > now())             as open_invites_to_this_email,
       (select count(*) from public.sync_ops o where o.user_id = u.id)    as ops_pushed,
       (select max(o.created_at) from public.sync_ops o where o.user_id = u.id) as last_op_at
from auth.users u
order by u.created_at;


-- Q4. Rows that point at each auth user. A 'no action' row blocks deleting that user
--     until the row itself is removed; 'cascade' rows go with the user; 'set null'
--     rows stay with the reference cleared.
select u.email, fk.table_name, fk.column_name, fk.on_delete, x.n as rows
from (
  select c.conrelid::regclass::text as table_name,
         att.attname                as column_name,
         case c.confdeltype when 'a' then 'no action' when 'r' then 'restrict'
                            when 'c' then 'cascade'   when 'n' then 'set null'
                            else 'set default' end as on_delete
  from pg_constraint c
  join pg_attribute att on att.attrelid = c.conrelid and att.attnum = c.conkey[1]
  where c.contype = 'f' and c.confrelid = 'auth.users'::regclass
    and c.connamespace = 'public'::regnamespace
) fk
cross join lateral xmltable(
  '/table/row' passing query_to_xml(
    format('select %I::text as uid, count(*) as n from %s where %I is not null group by 1',
           fk.column_name, fk.table_name, fk.column_name),
    true, false, '')
  columns uid text path 'uid', n bigint path 'n') x
join auth.users u on u.id = x.uid::uuid
order by u.email, fk.on_delete, fk.table_name;


-- Q5. Invitations (pending, expired, revoked and accepted).
select a.name as arena, i.email, i.name, i.role, i.created_at, i.expires_at,
       case when i.accepted_at is not null then 'accepted'
            when i.revoked_at  is not null then 'revoked'
            when i.expires_at <= now()     then 'expired'
            else 'pending' end as state,
       inv.email as invited_by
from public.staff_invites i
join public.arenas a on a.id = i.arena_id
left join auth.users inv on inv.id = i.invited_by
order by a.name, i.created_at;


-- Q6. Kept-configuration state that test activity may have left behind (review by hand).
select a.name as arena, 'pad away from home or on loan' as item,
       c.label || ' at ' || cur.name || ' (home ' || home.name || ')'
         || coalesce(', loan → ' || c.loan_return_to, '') as detail
from public.controllers c
join public.arenas a on a.id = c.arena_id
join public.resources cur  on cur.id  = c.current_resource_id
join public.resources home on home.id = c.home_resource_id
where c.current_resource_id <> c.home_resource_id
   or c.loan_return_to is not null or c.loan_session_ref is not null
union all
select a.name, 'pad not usable', c.label || ': ' || c.status
from public.controllers c join public.arenas a on a.id = c.arena_id
where c.status <> 'usable'
union all
select a.name, 'station not available', r.name || ': ' || r.status
from public.resources r join public.arenas a on a.id = r.arena_id
where r.status <> 'available'
union all
select a.name, 'salary run (' || s.status || ')',
       s.period_start || ' – ' || s.period_end
         || case when s.finalised_at is not null then ' (finalised: locks this period)' else '' end
from public.salary_runs s join public.arenas a on a.id = s.arena_id
union all
select a.name, 'setting', st.key || ' (updated ' || st.updated_at || ')'
from public.settings st join public.arenas a on a.id = st.arena_id
order by 1, 2, 3;


-- Q7. Structure baseline (compare before and after the reset; nothing here may change).
select 'append-only guard triggers enabled' as item,
       count(*) filter (where t.tgenabled = 'O') || ' of ' || count(*) as value
from pg_trigger t
where not t.tgisinternal and t.tgname like 't\_%\_append\_only'
union all
select 'tombstone triggers enabled',
       count(*) filter (where t.tgenabled = 'O') || ' of ' || count(*)
from pg_trigger t
where not t.tgisinternal and t.tgname like 't\_%\_tomb'
union all
select 'disabled user triggers in public', count(*)::text
from pg_trigger t join pg_class c on c.oid = t.tgrelid
where not t.tgisinternal and t.tgenabled = 'D' and c.relnamespace = 'public'::regnamespace
union all
select 'public tables / with RLS',
       count(*) || ' / ' || count(*) filter (where c.relrowsecurity)
from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
union all
select 'public + private functions', count(*)::text
from pg_proc p where p.pronamespace in ('public'::regnamespace, 'private'::regnamespace)
union all
select 'RLS policies (public + realtime)', count(*)::text
from pg_policies where schemaname in ('public', 'realtime')
union all
select 'supabase_realtime publication tables', count(*)::text
from pg_publication_tables where pubname = 'supabase_realtime'
union all
select 'applied migrations (count, latest)',
       case when to_regclass('supabase_migrations.schema_migrations') is null
            then 'no migration history table'
            else (xpath('/row/v/text()', query_to_xml(
                    'select count(*) || '', '' || max(version) as v from supabase_migrations.schema_migrations',
                    false, true, '')))[1]::text end
union all
select 'extensions', string_agg(extname || ' ' || extversion, ', ' order by extname)
from pg_extension
union all
select 'auth users', count(*)::text from auth.users;
