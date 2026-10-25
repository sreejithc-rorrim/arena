-- _waive_check(arena, billed, paid) — may the caller write off what this bill still owes?
--
-- A waive writes off billed − paid. Owner level (role owner, or money / reports) waives any
-- amount; anyone else (with discount) at most settings.discount_options.manual_max_percent of
-- the bill, the same cap as a manual discount (default 0: walk-outs then need an owner).
-- Exact integer comparison (written_off × 100 > billed × cap), mirrored by the floor app.
-- Raises waive_over_limit (hint: the cap in percent). Used by op_session_end.
-- Server-only: not executable by anon/authenticated.
create or replace function public._waive_check (
  p_arena  uuid,
  p_billed bigint,
  p_paid   bigint
)
  returns void
  language plpgsql
  stable
  set search_path to 'public'
  AS $function$
declare v_max int;
begin
  if private.app_is_owner(p_arena) then return; end if;
  select coalesce((json->>'manual_max_percent')::int, 0) into v_max
    from settings where arena_id = p_arena and key = 'discount_options';
  v_max := coalesce(v_max, 0);
  if greatest(coalesce(p_billed, 0) - coalesce(p_paid, 0), 0) * 100 > coalesce(p_billed, 0) * v_max then
    raise exception 'waive_over_limit' using hint = v_max::text || '%';
  end if;
end;
$function$;

comment on function public._waive_check(uuid, bigint, bigint) is 'Internal: raise waive_over_limit unless the caller is owner level or the write-off is within discount_options.manual_max_percent of the bill.';

grant execute on function "public"."_waive_check"(uuid, bigint, bigint) to "postgres", "service_role";

revoke all on function "public"."_waive_check"(uuid, bigint, bigint) from public;

revoke all on function "public"."_waive_check"(uuid, bigint, bigint) from anon;

revoke all on function "public"."_waive_check"(uuid, bigint, bigint) from authenticated;
