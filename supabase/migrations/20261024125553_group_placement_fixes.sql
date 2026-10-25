set local check_function_bodies = off;

create or replace function public._group_assignable (
  p_arena          uuid,
  p_group          uuid,
  p_resource       uuid,
  p_activity       text,
  p_game           uuid,
  p_cc             integer,
  p_player         integer,
  p_exclude_player integer,
  p_borrowed       integer
)
  returns void
  language plpgsql
  stable
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_used int; v_usable int; v_max int; v_others int; v_players int;
begin
  perform _station_usable(p_arena, p_resource);
  perform _mode_ok(p_arena, p_resource, p_activity);
  perform _game_playable(p_game, p_resource);
  if exists (select 1 from session_segments where resource_id = p_resource and ended_at is null) then
    raise exception 'resource_busy';
  end if;
  if exists (select 1 from group_assignments
              where resource_id = p_resource and ended_at is null and group_id <> p_group) then
    raise exception 'resource_busy' using hint = 'another group';
  end if;
  select count(*), coalesce(sum(coalesce(controller_count, 0)), 0)
    into v_others, v_used
    from group_assignments
   where resource_id = p_resource and ended_at is null and group_id = p_group
     and not (p_exclude_player is not null and player_number = p_exclude_player);
  if v_used + p_cc > 4 then raise exception 'controllers_exceeded'; end if;
  if p_game is not null then
    v_max := _game_max_players(p_game);
    if v_used + p_cc > v_max then raise exception 'players_exceeded' using hint = v_max::text; end if;
  end if;
  v_usable := _usable_pads_at(p_arena, p_resource) + coalesce(p_borrowed, 0);
  if v_used + p_cc > v_usable and _inventory_tracked(p_arena) then
    raise exception 'controllers_unavailable' using hint = v_usable::text || ' usable';
  end if;
  if v_others = 0 then return; end if;
  -- Sharing a station with this group's other players: controller activities only, same activity and game.
  if not _uses_controllers(p_arena, p_activity) then raise exception 'resource_busy'; end if;
  if exists (select 1 from group_assignments
              where resource_id = p_resource and ended_at is null and group_id = p_group
                and not (p_exclude_player is not null and player_number = p_exclude_player)
                and (activity_code is distinct from p_activity or game_id is distinct from p_game)) then
    raise exception 'game_conflict';
  end if;
  if p_game is not null then
    -- Distinct players on the station after placing p_player (+1 unless already there).
    select count(distinct player_number) + (case when exists (
             select 1 from group_assignments where resource_id = p_resource and ended_at is null
               and group_id = p_group and player_number = p_player
               and not (p_exclude_player is not null and player_number = p_exclude_player))
           then 0 else 1 end)
      into v_players from group_assignments
     where resource_id = p_resource and ended_at is null and group_id = p_group
       and not (p_exclude_player is not null and player_number = p_exclude_player);
    if v_players > v_max then raise exception 'players_exceeded' using hint = v_max::text; end if;
  end if;
end;
$function$;

create or replace function public._group_place (
  p_arena          uuid,
  p_group          uuid,
  a                jsonb,
  p_at             timestamp with time zone,
  p_idx            integer,
  p_exclude_player integer
)
  returns integer
  language plpgsql
  security definer
  set search_path to 'public'
  AS $function$
declare
  v_now timestamptz := statement_timestamp();
  v_res uuid := (a->>'resource_id')::uuid;
  v_game uuid := nullif(a->>'game_id','')::uuid;
  v_act text := a->>'activity_code';
  v_player int := (a->>'player_number')::int;
  v_pads uuid[] := _pad_ids(a->'allocations');
  v_npads int := coalesce(array_length(_pad_ids(a->'allocations'), 1), 0);
  v_cc int := case when v_npads > 0 then v_npads else nullif(a->>'controller_count','')::int end;
  v_aid uuid := (a->>'id')::uuid;
  v_skipped int;
  v_snap jsonb; v_mode text; v_pool int; v_here int;
begin
  perform _group_assignable(p_arena, p_group, v_res, v_act, v_game, coalesce(v_cc, 0),
    v_player, p_exclude_player, coalesce(jsonb_array_length(coalesce(a->'moves','[]'::jsonb)), 0));
  -- An unpriced station would bill ₹0 (_pr_sweep / _pr_group_bill skip it).
  select pricing_snapshot, billing_mode, purchased_controller_count into v_snap, v_mode, v_pool
    from group_sessions where id = p_group;
  if v_mode = 'shared_controller_pool' then
    -- Pads bill once from the pool; a player without pads is swept with no count.
    if coalesce(v_cc, 0) = 0 then
      perform _seg_priced(p_arena, v_res, v_snap, v_act, null);
    elsif coalesce(v_pool, 0) > 0 then
      perform _seg_priced(p_arena, v_res, v_snap, v_act, v_pool);
    end if;
  else
    select coalesce(sum(controller_count), 0) + coalesce(v_cc, 0) into v_here
      from group_assignments
     where group_id = p_group and resource_id = v_res and ended_at is null
       and not (p_exclude_player is not null and player_number = p_exclude_player);
    perform _seg_priced(p_arena, v_res, v_snap, v_act, nullif(v_here, 0));
  end if;
  insert into group_assignments(id, arena_id, group_id, player_number, player_label, idx,
      resource_id, activity_code, game_id, controller_count, started_at, created_at)
    values (v_aid, p_arena, p_group, v_player, a->>'player_label', p_idx, v_res, v_act, v_game,
      v_cc, p_at, v_now);
  if v_game is not null then
    update games set last_played_at = p_at, updated_at = v_now where id = v_game and arena_id = p_arena;
  end if;
  v_skipped := _pad_borrow(p_arena, a->'moves', v_res, 'g:' || p_group::text, p_at);
  perform _pad_allocate(p_arena, a->'allocations', 'group', null, p_group, null, v_aid,
    v_player, a->>'player_label', v_res, v_act, v_game, p_at);
  return v_skipped;
end;
$function$;
