-- _game_max_players(p_game) — the game's max local players (default 1).
--
-- games.max_local_players, or 1 when the game is missing or the value is null.
-- Used by _single_supply for 'players_exceeded'.
-- Server-only: not executable by anon/authenticated.
create or replace function public._game_max_players (
  p_game uuid
)
  returns integer
  language sql
  stable
  security definer
  set search_path to 'public'
  AS $function$
  select coalesce((select max_local_players from games where id = p_game), 1);
$function$;

comment on function public._game_max_players(uuid) is 'Returns a game''s max local players, defaulting to 1.';

grant execute on function "public"."_game_max_players"(uuid) to "postgres", "service_role";

revoke all on function "public"."_game_max_players"(uuid) from public;

revoke all on function "public"._game_max_players(p_game uuid) from anon;

revoke all on function "public"._game_max_players(p_game uuid) from authenticated;
