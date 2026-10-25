-- _untracked_busy(p_arena, p_resource, p_except) — is someone playing at the station with untracked pads?
--
-- True when an open session segment at p_resource (id not in p_except) has a
-- controller-using activity but no open controller_allocations row: its pads may be in hand, so
-- none can be lent or allocated there. Used by _pad_borrow and _pad_allocate.
-- Server-only: not executable by anon/authenticated.
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

comment on function public._untracked_busy(uuid, uuid, uuid[]) is 'True when open play at the station uses controllers without any allocated pads.';

grant execute
  on function "public"."_untracked_busy"(uuid, uuid, uuid[])
  to "postgres", "service_role";

revoke all on function "public"."_untracked_busy"(uuid, uuid, uuid[]) from public;

revoke all on function "public"._untracked_busy(p_arena uuid, p_resource uuid, p_except uuid[]) from anon;

revoke all on function "public"._untracked_busy(p_arena uuid, p_resource uuid, p_except uuid[]) from authenticated;
