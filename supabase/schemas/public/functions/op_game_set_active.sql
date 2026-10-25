-- op_game_set_active — sync op 'game.set_active': archive a game (active false) or restore it.
--
-- Permission: settings.
-- Payload: id, active (true or false).
-- An archived game is hidden from new sessions and bookings on every device;
-- sessions already playing it keep running, and past bills and bookings keep showing it. The
-- server does not refuse a start on an archived game: a device that was offline when it was
-- archived may already have started one, and refusing would drop a real session from its floor.
-- Setting the flag it already has writes nothing (a retry is a no-op).
-- Checks / errors: forbidden; invalid_payload (hint active); not_found (hint game).
-- Writes: games.active. Returns: {}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
create or replace function public.op_game_set_active (
  p_arena uuid,
  p       jsonb
)
  returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_target boolean := (p->>'active')::boolean;
  v_active boolean;
begin
  perform _need(p_arena, 'settings');
  if v_target is null then raise exception 'invalid_payload' using hint = 'active'; end if;
  select active into v_active from games
   where id = (p->>'id')::uuid and arena_id = p_arena for update;
  if not found then raise exception 'not_found' using hint = 'game'; end if;
  if v_active is distinct from v_target then
    update games set active = v_target, updated_at = statement_timestamp()
      where id = (p->>'id')::uuid and arena_id = p_arena;
  end if;
  return '{}'::jsonb;
end;
$function$;

comment on function public.op_game_set_active(uuid, jsonb) is
  'Sync op game.set_active: archives (false) or restores (true) a game; sessions already playing it continue and history keeps it.';

grant execute on function "public"."op_game_set_active"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_game_set_active"(uuid, jsonb) from public;

revoke all on function "public".op_game_set_active(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_game_set_active(p_arena uuid, p jsonb) from authenticated;
