# supabase/ — arena_ops backend

Postgres (Supabase, PG 17) backend for the staff app's multi-device sync. Many arenas
(gaming centres) share one database; every row carries `arena_id`, and a signed-in
staff member only ever sees the arenas they are an active member of.

## Layout

| Path | What |
|---|---|
| `schemas/` | **Source of truth.** One file per object, the layout `supabase db schema declarative generate` writes. Each file holds the object plus its indexes, triggers, RLS policy, grants and `comment on` docs. |
| `schemas/public/tables/` | 35 tables |
| `schemas/public/views/` | 4 `sync_v_*` views used by the change feed (server-only) |
| `schemas/public/functions/` | Client API wrappers (`security invoker`), sync ops, pricing, helpers, triggers (map below) |
| `schemas/public/default_privileges.sql` | New objects grant nothing to `anon` / `authenticated` |
| `schemas/private/` | Schema `private` (`schema.sql`, `default_privileges.sql`, `functions/`): the client API's SECURITY DEFINER bodies and the RLS helpers. Not exposed by the Data API — never add it to `config.toml` `[api] schemas`. |
| `schemas/realtime/policies.sql` | `realtime.messages` policies for the private arena channels |
| `schemas/_cluster/extensions/` | `pgcrypto`, `uuid-ossp`, `btree_gist` |
| `schemas/_cluster/publications.sql` | The 29 tables in the `supabase_realtime` publication |
| `migrations/` | **Generated** by `supabase db schema declarative sync` — never edit. `20261015054055_declarative_sync` is the squashed baseline (the old `0001`–`0016` history is gone; see `docs/DEPLOY_SUPABASE.md` §4a). |
| `tests/` | pgTAP (`supabase test db --local`) |
| `seed.sql` | Local demo data loaded by `supabase db reset`: arena "404 Arena (demo)", logins `owner@arena.test` / `staff@arena.test` (password `password123`), catalog, customers, a week of bills, running sessions, bookings (written through `sync_push`). Real arenas still start empty. |
| `concurrency_tests/` | `race_A.sql` / `race_B.sql`: two halves of a two-device race on one station; `run.sh` (station race), `run_pads.sh` (pad races), `fixture.sh` (their own arena, removed on exit). Use `docker exec psql` on the local container. |
| `audit/security_audit.sql` | Read-only report of the API surface (grants, SECURITY DEFINER, RLS). Its allowlist of client functions predates the invitation/sales/pricing RPCs (it still names `add_staff_by_email`), so it reports the newer client API as `FAIL`; test 13 is the current assertion. |
| `templates/confirmation.html` | Sign-up confirmation link. An owner signing up (user metadata `signup`, redirect to `/register`) gets the confirmation wording; an invited NEW address (redirect to `/accept-invite`) gets the invitation wording |
| `templates/magic_link.html` | Sign-in link, used only for invitations to an address that already has a confirmed login |
| `config.toml` | Local stack (ports 5443x). Sign-up on with e-mail code confirmation; pg-delta is on. `additional_redirect_urls` include `http://127.0.0.1:4200/**` and `http://localhost:4200/**` (`ng serve`, for `/accept-invite`); `email_sent` limit 30/h; local mail goes to Mailpit at `http://127.0.0.1:54434`. |

## Changing the schema

1. Edit the end state in `schemas/` (the `create table`, the function body, the policy, the comment) — never `alter`.
2. `supabase db schema declarative sync --name <what_changed> --no-apply` → read the generated migration.
3. `supabase migration up --local`.
4. Run the same sync again: it must say **No schema changes found**.
5. `supabase test db --local` and `supabase db advisors --local --type all`.

Every new object file must revoke `anon` and `authenticated` explicitly (see any existing
file's last lines). pg-delta builds a shadow database where default privileges apply, so a
missing revoke shows up as a generated `grant … to anon` — reject that migration.

## Security model

| Role | Can do |
|---|---|
| `anon` | Nothing. No table, view, sequence or function privilege. |
| `authenticated` | `select` on tables, filtered by RLS to its own arenas (`arena_id in (select private.app_arena_ids())`), narrower for sensitive tables (below). Execute only the client API below. No direct writes. |
| `service_role` / `postgres` | Everything (dashboard, SQL editor, `bootstrap_owner`). Never shipped in an app, and no deployed code uses it. |

- **Direct reads (RLS — dashboard queries and Realtime Postgres Changes).** Every arena table:
  active members (`private.app_arena_ids()`). `payments`, `session_charges`: members holding `bill`, `money` or `reports` (or role owner). `customers`:
  `start`, `members`, `money` or `reports` (or owner). `audit_log`: owner level only.
  `staff_personal_details`, `staff_terms_acceptances`: a member's own rows
  (`private.app_my_staff_ids()`), everyone's at owner level. These are **not** in the sync feed:
  the floor app reads them online.
  `staff_invites`: no client access at all. These go through
  `private.app_arena_ids_with(perms)`. The **device sync feed** (`sync_pull`,
  `sync_fetch_entity`, SECURITY DEFINER) narrows the same way (`_sync_hidden`): customers need
  `start` / `members` / owner level, payments, charges and bill discounts `bill` / owner level,
  coupons `discount` / `settings` / owner level. The pull returns that `scope`; a device whose
  scope changes re-reads the feed from the start.
- **Realtime.** One private channel per arena, topic `arena:<arena uuid>`. The
  `realtime.messages` policies `arena_members_receive` (select) and `arena_members_send` (insert),
  both `to authenticated`, admit only active members of that arena
  (`private.can_use_arena_topic(topic)`). Realtime caches the decision per connection until the
  JWT refreshes, so a revocation takes effect within `jwt_expiry` (3600 s). Postgres Changes are
  subscribed for INSERT and UPDATE only (DELETE events are neither RLS-checked nor filtered);
  deletions travel as the `sync` broadcast, sent only after the server committed ops. No business
  data travels in Realtime: every event only triggers an authorized pull or refetch.

- **One write path.** Devices push operations to `sync_push`; `_sync_apply` maps each op kind
  to an `op_*` function. Every `op_*` is `security definer` with a pinned `search_path`, checks
  the same permission the app checks (`_need(arena, perm)`), locks stations then pads in a fixed
  order, refuses stale writes, and is applied exactly once per `op_id` (`sync_ops` ledger).
- **The server prices money itself.** Bills and extensions are re-priced from the session's
  frozen price list (`_pr_*`) and refused on any one-paisa mismatch.
- **Permissions.** `staff_profiles.perms` ⊆ `start, bill, discount, members, stations, money,
  reports, settings, bill_edit, bill_record`. `role = 'owner'` implies all. Holding `money` or `reports` makes a member
  *owner level* (`app_is_owner`, same rule as the app). Only owner-level members grant or remove
  `money`/`reports` or edit an owner-level member; nobody changes their own perms.
- **Two routes to ownership; everyone else joins by invitation.** A new arena owner registers on the admin
  dashboard (`apps/admin`), confirms the e-mail with the e-mailed link, and calls
  `create_my_arena()` (confirmed logins only, one owned arena per login). The operator can also
  attach an owner with `bootstrap_owner()` (SQL editor, no limit). Both go through
  `_create_arena_with_owner`, which creates the arena **empty**: no station types, accessory
  types, prices, stations, games or accessories. The owner adds them on the dashboard through
  `sync_push` (`activity.upsert`, `accessory_kind.upsert`, `rate.upsert`, `resource.upsert`,
  `controller.upsert`, `game.upsert`, `game.set_compat`). `_seed_arena_catalog` is a test fixture only (pgTAP). A
  sign-up belongs to no arena until then. Staff and co-owners join **only by accepting an
  invitation**: dashboard Users → Invite (name, e-mail, role, permissions) → `invite_member` as
  the caller (staff invites need `settings`; granting
  `money`/`reports` needs owner level; inviting an owner needs an owner). `staff_invites` stores
  only the SHA-256 of a random one-time token; an invite expires in 7 days, and there is one open
  invite per (arena, address) — a newer one replaces the old link. The dashboard then has
  Supabase Auth e-mail the link (`signInWithOtp`, redirect `/accept-invite?invite=…&token=…`: a
  sign-in link for a confirmed login, the sign-up confirmation for a new one); if the e-mail
  fails it withdraws the invite. The link opens the
  dashboard's `/accept-invite`, which signs the invitee in on a separate in-memory client (never
  the browser's stored dashboard session, so an owner signed in in the same browser stays signed
  in as themselves), makes any login that did not arrive by a magic link (new, or unconfirmed until now — its
  password may have been chosen by someone else) choose its own password, then calls
  `accept_invite(p_invite, p_token)`: the token must match and be unused, unwithdrawn and
  unexpired; the caller's **confirmed** auth e-mail must equal the invited address
  (`invite_wrong_account`); the inviter must still hold the authority; an existing owner is never
  demoted. It creates or reactivates the `staff_profiles` row for that arena only. Owners list
  pending invites with `arena_invites()` and withdraw them with `revoke_invite()`.
  `add_member_by_email` / `add_staff_by_email` (which linked an existing login without consent)
  are removed. `arena_staff()` lists owners and staff with e-mails; changes go through
  `sync_push` (`staff.update`; a field the op leaves out keeps its value). The floor app
  (`apps/mobile`) only signs in, with the person's own e-mail and password.
- **Sales are read through owner-level RPCs.** The dashboard's Sales screen lists closed bills
  (completed or voided sessions, by close time, at most 93 days) with
  `arena_sales()` (each bill with its payments ledger, returning-customer flag, player-minutes,
  who/when of a void and the server's receipt time) and opens one with `arena_sale()` (charge
  lines, extensions, audit history, void record); both share the server-only `_sales()`.
- **Financial corrections append, never edit.** A void is a `session.void` op and
  needs a reason (`void_reason_required`); it keeps the bill and its payments (voiding never
  refunds). Money taken before a void can be refunded (`payment.record` with `is_refund`, reason
  required, never more than collected); a voided bill takes no new payment (`voided`). A payment
  keyed under the wrong method is moved by `payment.correct` (Money permission, reason
  required): a refund row on the old method and a payment row on the new one, in one
  transaction, never more than the payment (`already_corrected`, `amount_invalid`); those rows
  are flagged `correction` in the ledger and are not counted as refunds. A waive at the end of a
  session writes an audit entry with the amount written off and the staff reason. Every
  void, waive and correction is in `audit_log` with who, when, why and the before/after amounts.
- **History is append-only.** There are no delete policies; payments, moves, extensions and
  audit rows are only ever added.
- **Catalog rows that history names are archived, not deleted.** A game is archived with
  `game.set_active` (hidden from new sessions and bookings on every device; sessions already
  playing it continue; bills keep showing it). `game.delete` removes only a game no session
  segment, pad allocation or booking ever named, with its station statuses and
  control guide, after locking the row (a start racing it either commits first and the delete is
  refused, or fails on the foreign key); `session_segments` and
  `controller_allocations` reference `games` with no cascade, so even a direct delete of a used
  game fails. A deleted id is never re-created by a queued `game.upsert` (`not_found`), and an
  edit that saw a different active flag than the stored one is refused (`stale`) instead of
  undoing an archive or restore made elsewhere. The server does not refuse a start on an archived
  game: a device that was offline when it was archived may already have started one, and a
  refused start would drop a real session from that device's floor. Station types follow the same
  rule (`activity.remove`).

## Tables

| Area | Tables |
|---|---|
| Arena & people | `arenas`, `staff_profiles`, `staff_invites` (no client access), `customers` |
| Floor setup | `resources` (stations), `activities` (station types), `resource_activities`, `games`, `game_categories`, `game_resources`, `game_controls`, `controllers` (station accessories: pads, VR headsets, wheels…), `accessory_kinds` (owner-defined; `counts_as_controller` marks pads) |
| Pricing & rules | `rate_cards`, `rates`, `rate_bands`, `billing_policies`, `holidays`, `settings`, `pricing_rules` (day/time adjustments judged at a session's start), `pricing_catalog_history` |
| Discounts | `discounts` (presets and coupons), `bill_discounts` (the discount applied to a bill, a copy of what was used; one per bill) |
| Single sessions | `sessions` → `session_segments`, `session_extensions`, `session_charges`, `payments` |
| Pads in use | `controller_allocations`, `controller_moves` |
| Bookings & audit | `bookings`, `audit_log` |
| Staff records (online only, not in `sync_pull`) | `staff_personal_details` (own row + owner level), `staff_terms` (append-only versions) and `staff_terms_acceptances`. The staff-time module (attendance, shifts, leave, pay, payroll) was removed on 2026-10-24; it is kept at the git tag `staff-module-archive` |
| Sync (server-only) | `sync_ops`, `sync_tombstones`; views `sync_v_arenas`, `sync_v_bookings`, `sync_v_rates`, `sync_v_resource_activities` |

Money is `bigint` paise; instants are `timestamptz` (UTC); business days are Asia/Kolkata.
`sync_xid` on every synced row is the id of the transaction that last wrote it (the change-feed
cursor), stamped by the `sync_stamp` trigger; deletes leave a row in `sync_tombstones`.

## Functions

| Group | Functions |
|---|---|
| **Client API** (`authenticated`) | `sync_push`, `sync_pull`, `sync_fetch_entity`, `my_arenas`, `create_my_arena`, `invite_member`, `accept_invite`, `revoke_invite`, `arena_invites`, `arena_staff`, `arena_sales`, `arena_sale`, `arena_pricing`, `arena_overview`, `arena_station_stats`, `arena_game_stats`, `arena_game_fans`, `arena_members`, `arena_activity`, `arena_discount_usage`, `app_is_owner`, `my_bills` (floor app's My bills: the caller's own closed bills of one IST day as `_sales` summaries; `bill_edit` or `bill_record`), `session_quote` (the price of a missed single session on the current price list; `bill_record`), `station_type_catalog` / `accessory_kind_catalog` (the global ready-made station and accessory types an owner picks from; data in the function body, reads no table) — the dashboard's reads are aggregated on the server (`_plays`, `_bill_minutes`) so screens download figures, not history; each a `security invoker` wrapper in `public` over its SECURITY DEFINER body in `private` |
| RLS helpers (`private`, not client API) | `private.app_arena_ids`, `private.app_has_perm`, `private.app_is_owner`, `private.app_arena_ids_with(perms)`, `private.app_my_staff_ids()`, `private.can_use_arena_topic(topic)` — executable by `authenticated` because policies run as the caller; `private` is not an exposed schema |
| Operator only | `bootstrap_owner` |
| Sync ops (`op_*`, via `sync_push`) | sessions: `op_session_start/_reconfigure/_extend/_end/_void`; money: `op_payment`, `op_payment_correct`, `op_bill_adjust` (Edit bill: new total, collected made to match; `money`, or `bill_edit` on a bill the caller started), `op_session_record` (`session.record`: a missed single session added ended, priced and paid; `bill_record`); accessories: `op_controller_move/_upsert/_set_status` (only pads — `_is_pad` — are allocated or borrowed by a start), `op_accessory_kind_upsert/_remove`; time rules: `op_rule_upsert/_delete/_reorder`; discounts: `op_discount_upsert/_set_active/_delete` (applied at `session.end` by `_discount_apply`); customers & bookings: `op_customer_*`, `op_booking_*`; settings: `op_game_*` (`game.delete` removes only a game nothing ever used — in play → `game_in_play`, with history → `game_has_history`, archive it with `game.set_active` instead), `op_resource_*`, `op_rate_*`, `op_policy_save`, `op_settings_save` (keys `business_hours`, `floor_options`, `discount_options`, `venue_profile`, `offline_rules` — validated by `_floor_options` / `_discount_options` / `_venue_profile` / `_offline_rules`), `op_holiday_*`, `op_staff_update`, `op_arena_update` (arena name, area, phone); staff: `op_staff_details_save`, `op_terms_publish/_accept` |
| Sync plumbing | `_sync_apply` (op kind → `op_*`), `_sync_sources` |
| Server pricing | `_pr_*` (port of the app's PricingService / SegmentBilling; `_pr_rule` / `_pr_rule_price` apply a time rule to each unit price), `_pricing_snapshot` (carries `rules` only when there are active ones), `_pricing_canon`, `_pricing_grace`, `_assert_snapshot`, `_price_mismatch`, `_discount_apply` |
| Floor rules | `_need`, `_lock_resources`, `_lock_pads`, `_station_*`, `_pad_*`, `_single_supply`, `_game_*`, `_booking_free`, `_free_pads_at`, `_untracked_busy`, … |
| Triggers | `sync_stamp`, `sync_record_delete`, `set_updated_at`, `_assert_same_arena`, `assert_resource_free_for_segment`, `assert_controller_free_for_allocation` |

Each function file starts with a header explaining what it does, who calls it, what it
checks and which errors it raises; the same summary is stored as `comment on function`
(visible in Studio).

## Tests

| File | Covers |
|---|---|
| `00_schema_parity_test.sql` | Postgres is a superset of the app's Drift schema |
| `01_rls_authorization_test.sql` | Owner vs staff authorization, retired functions are gone |
| `07_sync_ops_test.sql` | `sync_push` → `op_*` → `sync_pull` end to end |
| `08_server_pricing_test.sql` | Server re-prices bills and refuses mismatches |
| `09_account_provisioning_test.sql` | `bootstrap_owner`, `create_my_arena` (confirmation, names, one-arena limit), `arena_staff`; no function links an existing login silently |
| `10_integrity_authz_test.sql` | Payments fit the bill, owner protection, pad-move permission |
| `11_ported_floor_test.sql` | Sessions and payments through `sync_push` |
| `12_ported_pads_test.sql` | Controller allocation, borrowing and moves through `sync_push` |
| `13_security_hardening_test.sql` | Client surface, RLS shape, owner-level perms, integrity checks |
| `14_admin_sales_test.sql` | `arena_sales` / `arena_sale`: who may read, half-open close-time ranges, voided bills |
| `15_catalog_from_scratch_test.sql` | An empty arena built only through `sync_push` (`activity.upsert` rules, rate, station, pad, game, compat) runs a session |
| `16_admin_catalog_details_test.sql` | A game's age rating and media (`game.upsert`), the arena's name/area/phone (`arena.update`); edits from builds that do not send the new fields keep them |
| `17_staff_invites_test.sql` | `invite_member` → `accept_invite`: works once, only for the confirmed invited login, only for its arena, only while the inviter keeps the authority; `revoke_invite`, `arena_invites` |
| `18_realtime_and_sensitive_reads_test.sql` | Direct reads of money, customer and audit rows; who may use an arena's private Realtime channel; which tables Realtime announces |
| `19_game_lifecycle_test.sql` | Game names (trimmed, unique ignoring case); archive/restore while in play; `game.delete` only for a never-used game (in play, past sessions or bookings refused; FK backstop), tombstones, idempotent retries, no resurrection by a queued edit, edits over a newer archive refused (`base_active`), station notes kept, cross-arena and permission refusals |
| `20_floor_and_config_ops_test.sql` | `booking.update` (stale, conflict, closed), `booking.set_status` (cancel, no-show), `controller.set_status`, `resource.set_mode`, `holiday.upsert` / `holiday.delete` |
| `22_sales_corrections_test.sql` | A void needs a reason; refunds after a void (never more than collected, no new payments); waives audited with the amount written off; `payment.correct` (permission, reason, same method, part moves, no over-correction, replay); `arena_sales` returning customer, player-minutes, ledger with correction rows, void who/when; every bill's methods = ledger = collected |
| `23_accessories_test.sql` | Accessory kinds (owner-defined, unique names, retire vs delete), `controllers.kind_id` kept by edits that omit it, only pads allocated / borrowed / counted, every accessory moved with history, a type code derived from its name |
| `24_pricing_rules_test.sql` | Rules by day, window, holidays, dates and type; priority and `rule.reorder`; a whole session priced by its start; % and ₹/h both ways, never below ₹0; snapshot and canon unchanged without rules; `session.end` billed with the rule |
| `25_discounts_test.sql` | Presets, coupons and manual discounts on `session.end`: expiry, use limit (voids free a use), scope, minimum bill, staff cap and reason, permission, recomputed amount; `bill_discounts`, `_sales`, `arena_discount_usage` paging |
| `26_admin_reads_test.sql` | `arena_overview`, `arena_station_stats`, `arena_game_stats`, `arena_game_fans`, `arena_members`, `arena_activity`: owner only, figures without voided bills |
| `27_venue_types_test.sql` | `station_type_catalog` validity and grants; `venue_profile` validation and permission; a mixed venue built from the catalog runs a pool session and a turf booking to payment with no game or controllers; booking overlap refused across sports; started-hour turf billing |
| `21_policy_save_test.sql` | `policy.save`: settings permission (owner-level managers without it refused), a `Default` row created or the oldest active row overwritten, every field stored (read from inside `policy`; a retired `group_billing_mode` key is ignored), new rules in the pricing snapshot and the old price list retired, refusals of missing or bad fields write nothing, replays, other arenas |

Every file creates and isolates its own arena and rolls back.
