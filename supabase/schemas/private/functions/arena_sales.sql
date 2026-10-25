-- arena_sales(arena, from, to) — the owner dashboard's Sales list
--
-- Lives in `private`, which the Data API does not expose: SECURITY DEFINER
-- code never sits in an API schema. Clients reach it only through the
-- SECURITY INVOKER wrapper public.arena_sales.
--
-- The arena's closed bills (single sessions, completed or voided)
-- that closed in [p_from, p_to), newest first, as a jsonb array of _sales
-- summaries. The range may span at most 93 days, else 'invalid_range'.
-- SECURITY DEFINER. Caller must be owner level in p_arena (app_is_owner), else
-- 'forbidden'.
-- Client API: callable by signed-in users (authenticated).
create or replace function private.arena_sales (
  p_arena uuid,
  p_from  timestamptz,
  p_to    timestamptz
)
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
begin
  if not private.app_is_owner(p_arena) then
    raise exception 'forbidden' using errcode = '42501', hint = 'only an owner can list sales';
  end if;
  if p_from is null or p_to is null or p_to <= p_from or p_to - p_from > interval '93 days' then
    raise exception 'invalid_range' using hint = 'from < to, at most 93 days';
  end if;
  return coalesce((
    select jsonb_agg(b order by (b->>'at')::timestamptz desc, b->>'id')
      from _sales(p_arena, p_from, p_to) b), '[]'::jsonb);
end;
$function$;

comment on function private.arena_sales(uuid, timestamptz, timestamptz) is 'Client API (owner level): the arena''s closed bills (sessions, completed or voided) that closed in [from, to), newest first, for the admin dashboard''s Sales screen. At most 93 days.';

grant execute on function "private"."arena_sales"(uuid, timestamptz, timestamptz) to "authenticated", "postgres", "service_role";

revoke all on function "private"."arena_sales"(uuid, timestamptz, timestamptz) from public;

revoke all on function "private".arena_sales(p_arena uuid, p_from timestamptz, p_to timestamptz) from anon;
