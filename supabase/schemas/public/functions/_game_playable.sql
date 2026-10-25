-- _game_playable(p_game, p_resource) — refuse a game that is not playable on a station.
--
-- No-op when p_game is null. Raises 'not_playable' (hint: the game_resources status, or
-- 'not_installed' when there is no row) unless the status is 'playable'.
-- Used by op_session_start and op_session_reconfigure.
-- Server-only: not executable by anon/authenticated.
create or replace function public._game_playable (
  p_game     uuid,
  p_resource uuid
)
  returns void
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare v_status text;
begin
  if p_game is null then return; end if;
  select status into v_status from game_resources where game_id = p_game and resource_id = p_resource;
  if not found or v_status <> 'playable' then
    raise exception 'not_playable' using hint = coalesce(v_status, 'not_installed');
  end if;
end;
$function$;

comment on function public._game_playable(uuid, uuid) is 'Raises not_playable unless the game is installed and playable on the station (no-op without a game).';

grant execute on function "public"."_game_playable"(uuid, uuid) to "postgres", "service_role";

revoke all on function "public"."_game_playable"(uuid, uuid) from public;

revoke all on function "public"._game_playable(p_game uuid, p_resource uuid) from anon;

revoke all on function "public"._game_playable(p_game uuid, p_resource uuid) from authenticated;
