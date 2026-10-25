-- _is_pad(p_kind) — is an accessory of this kind a game pad?
--
-- True for no kind (accessories from before kinds existed) or a kind with
-- counts_as_controller. Only pads are allocated to players, counted for
-- controller-count supply and borrowed by session starts. Used by
-- _inventory_tracked, _free_pads_at, _pad_allocate and _pad_borrow.
-- Server-only: not executable by anon/authenticated.
create or replace function public._is_pad (
  p_kind uuid
)
  returns boolean
  language sql
  stable
  security definer
  set search_path to 'public'
  AS $function$
  select p_kind is null
      or coalesce((select k.counts_as_controller from accessory_kinds k where k.id = p_kind), false);
$function$;

comment on function public._is_pad(uuid) is 'True when an accessory of this kind (null = no kind) is a game pad.';

grant execute on function "public"."_is_pad"(uuid) to "postgres", "service_role";

revoke all on function "public"."_is_pad"(uuid) from public;

revoke all on function "public"._is_pad(p_kind uuid) from anon;

revoke all on function "public"._is_pad(p_kind uuid) from authenticated;
