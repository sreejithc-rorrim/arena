-- op_game_delete — sync op 'game.delete': permanently delete a game nobody ever used.
--
-- Permission: settings.
-- Payload: id.
-- Only a game that no session segment, pad allocation or booking ever referred to
-- is deleted, with its station statuses (game_resources) and control guide (game_controls);
-- devices get the tombstones. A game with any such history is refused: archive it instead
-- (game.set_active false), so past bills and bookings keep their game. The checks run after
-- the game row is locked, so a session that starts on it at the same moment either commits first
-- (and the delete is refused) or waits and is refused itself (the game is gone). Idempotent: an
-- id that is already gone returns {deleted: true}; game.upsert never brings a deleted id back.
-- Checks / errors: forbidden; invalid_payload (hint id); not_found (hint game: the id belongs to
--   another arena); game_in_play (hint: how many stations play it now); game_has_history (hint:
--   sessions, pads or bookings — the first kind of record that refers to it).
-- Writes: games (delete; game_resources and game_controls cascade). Returns: {deleted: true}.
-- Server-only: not executable by anon/authenticated; reached through sync_push.
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

comment on function public.op_game_delete(uuid, jsonb) is
  'Sync op game.delete: permanently deletes a game no session, pad allocation or booking ever used (with its station statuses and control guide); refuses one in play (game_in_play) or with history (game_has_history: archive it instead).';

grant execute on function "public"."op_game_delete"(uuid, jsonb) to "postgres", "service_role";

revoke all on function "public"."op_game_delete"(uuid, jsonb) from public;

revoke all on function "public".op_game_delete(p_arena uuid, p jsonb) from anon;

revoke all on function "public".op_game_delete(p_arena uuid, p jsonb) from authenticated;
