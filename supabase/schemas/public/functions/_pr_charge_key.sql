-- _pr_charge_key(p_act, p_res, p_cc, p_band, p_start, p_end, ...) — canonical key of one charge row.
--
-- Joins activity, station (or '-'), controller count (or '-'), band, start and end as epoch
-- microseconds, played and billed minutes, unit minutes, unit price and amount with '|'.
-- op_session_end compares sorted arrays of these keys (device charge rows vs the
-- server bill's keys from _pr_keys) as multisets; row ids and order are ignored.
-- Server-only: not executable by anon/authenticated.
create or replace function public._pr_charge_key (
  p_act    text,
  p_res    uuid,
  p_cc     integer,
  p_band   text,
  p_start  timestamp with time zone,
  p_end    timestamp with time zone,
  p_played bigint,
  p_billed bigint,
  p_um     integer,
  p_price  bigint,
  p_amount bigint
)
  returns text
  language sql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
  select concat_ws('|', p_act, coalesce(p_res::text, '-'), coalesce(p_cc::text, '-'), p_band,
    (extract(epoch from p_start) * 1000000)::bigint, (extract(epoch from p_end) * 1000000)::bigint,
    p_played, p_billed, p_um, p_price, p_amount);
$function$;

comment on function public._pr_charge_key(text, uuid, integer, text, timestamp with time zone, timestamp with time zone, bigint, bigint, integer, bigint, bigint) is 'Pricing: text key of a charge row''s money-relevant fields, used to compare device and server charge rows as multisets.';

grant execute
  on function "public"."_pr_charge_key"(text, uuid, integer, text, timestamp
    with time zone, timestamp with time zone, bigint, bigint, integer, bigint, bigint)
  to "postgres", "service_role";

revoke all
  on function "public"."_pr_charge_key"(text, uuid, integer, text, timestamp
    with time zone, timestamp with time zone, bigint, bigint, integer, bigint, bigint)
  from public;

revoke all on function "public"._pr_charge_key(p_act text, p_res uuid, p_cc integer, p_band text, p_start timestamp with time zone, p_end timestamp with time zone, p_played bigint, p_billed bigint, p_um integer, p_price bigint, p_amount bigint) from anon;

revoke all on function "public"._pr_charge_key(p_act text, p_res uuid, p_cc integer, p_band text, p_start timestamp with time zone, p_end timestamp with time zone, p_played bigint, p_billed bigint, p_um integer, p_price bigint, p_amount bigint) from authenticated;
