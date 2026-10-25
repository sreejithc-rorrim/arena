-- _price_mismatch(p_what, p_server, p_device) — raise the price_mismatch error.
--
-- Always raises 'price_mismatch' with hint '<what>: server <n> paise, device <n|none> paise'.
-- Called with 'bill' by op_session_end and 'extension' by op_session_extend when the device's money differs from the server's by any amount (0 tolerance).
-- Server-only: not executable by anon/authenticated.
create or replace function public._price_mismatch (
  p_what   text,
  p_server bigint,
  p_device bigint
)
  returns void
  language plpgsql
  immutable
  set search_path to 'public', 'extensions'
  AS $function$
begin
  raise exception 'price_mismatch'
    using hint = format('%s: server %s paise, device %s paise', p_what, p_server,
                        coalesce(p_device::text, 'none'));
end;
$function$;

comment on function public._price_mismatch(text, bigint, bigint) is 'Raises price_mismatch with a hint comparing the server and device amounts in paise.';

grant execute
  on function "public"."_price_mismatch"(text, bigint, bigint)
  to "postgres", "service_role";

revoke all on function "public"."_price_mismatch"(text, bigint, bigint) from public;

revoke all on function "public"._price_mismatch(p_what text, p_server bigint, p_device bigint) from anon;

revoke all on function "public"._price_mismatch(p_what text, p_server bigint, p_device bigint) from authenticated;
