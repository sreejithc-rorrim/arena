-- app_my_staff_ids() — the caller's own staff_profiles ids
--
-- Lives in `private` (not exposed by the Data API). The "own rows" half of the
-- RLS policies on staff records (staff_personal_details, staff_terms_acceptances): a
-- member always sees their own rows, and only owner-level members see everyone's. Returns the id of every active staff_profiles row of
-- auth.uid(), one per arena; a deactivated profile sees nothing.
-- Executable by authenticated because RLS policies run as the caller.
create or replace function private.app_my_staff_ids()
  returns SETOF uuid
  language sql
  stable
  security definer
  set search_path to 'public'
  AS $function$
  select id from staff_profiles where user_id = auth.uid() and active;
$function$;

comment on function private.app_my_staff_ids() is 'Staff profile ids of the signed-in user (active only); the own-rows test of the RLS policies on staff records (personal details, terms acceptances).';

grant execute on function "private"."app_my_staff_ids"() to "authenticated", "postgres", "service_role";

revoke all on function "private"."app_my_staff_ids"() from public;

revoke all on function "private".app_my_staff_ids() from anon;
