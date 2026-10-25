# Changelog

All notable changes to arena_ops (floor app, admin web and Supabase backend)
are recorded here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

One version covers the whole release: `apps/admin/package.json`,
`apps/mobile/pubspec.yaml` and the migrations in `supabase/migrations/` ship
together.

## [Unreleased]

### Added
- Admin Overview: a "Day" period shows any past day (yesterday by default, picked with a date
  field; `?period=day&day=YYYY-MM-DD`) with takings by hour, compared with the day before.

### Removed
- Group sessions, everywhere, to be rebuilt from scratch: the floor app's group screens and
  sheets (new group, assign, switch, extend, end, payment, "Open groups"), group billing and the
  "group billing mode" rule, group bills in Sales, Overview, reports, CSV (the bills report loses
  its Type column) and My bills, and the `group.*` sync ops (now refused as `unknown_op`).
  **Destructive:** migration `20261024131855_remove_group_sessions` drops `group_sessions`,
  `group_assignments`, `group_extensions`, `group_charges` and `group_payments` with their data,
  plus `billing_policies.group_billing_mode`, `bill_discounts.group_id` (`session_id` becomes
  required) and the group columns of `controller_allocations`. The floor app's database (v19)
  drops its group tables after the usual backup; an unsynced group bill on a device is lost.
- Floor app owner screens: Today, Money, Reports (and its Excel export) and Settings (pricing,
  hours, holidays, stations, staff and PINs, game library and game editing). Owners land on the
  Floor like staff and do that work on the admin web; the bottom bar is Floor · Bookings · Bills ·
  More, and Bills now shows for owners too. Game pickers and the system's games list are
  read-only and point to the dashboard. Dependencies `excel` and `share_plus` removed.
- The staff-time module, to be rebuilt when there is a real need (code kept at the git tag
  `staff-module-archive`): attendance (clock-in / clock-out, corrections, review, missed-time
  requests), GPS / geofence clock-in, shifts and staff holidays, leave, HR profile, pay setup and
  payroll. Floor app: the attendance chip, Attendance and Leave screens, and the location
  permission (`geolocator`, `flutter_map`, `latlong2`). Dashboard: Attendance and Payroll, the
  Team tabs Attendance / Leave / Salary / Schedule, Settings › Staff's schedule, clock-in,
  attendance, leave and payroll tabs, "Works here as staff", and the Leaflet map. Server: its
  15 tables, ops, `attendance_days` / `leave_balances`, the `attendance` / `work_hours` /
  `leave_rules` settings and the permissions `attendance_review`, `leave_approve`, `payroll`,
  `payroll_finalise` and `time_request` (migration `20261024090442_remove_staff_module`, which
  drops those tables and their data). Staff accounts, invitations, permissions, Team, staff terms
  and personal details stay.

### Fixed
- Admin sign-in, create account, create arena, accept invite and reset password pages show the
  ARQ logo instead of the old "404" badge (#24).
- Admin Pricing › rule "When": the From and To time fields are the same size; the "00:00 is
  midnight" hint no longer wraps or stretches the From field (#25).
- Floor app booking check-in runs the same price check as New Session: a controller count with
  no price is refused ("No price for PS5 with 3 controllers.") instead of starting a session the
  server rejects (`no_rate`). The no-price tip now points to the dashboard's Pricing (#30).
- Floor app End sheet: bill lines show their exact amounts (₹37.50, as in Sales) and cash rounding
  gets its own "Rounding" line, so the lines add up to the total. Amounts charged are unchanged
  (#22).
- Floor app booking check-in: a station whose session is still running, overtime included, is
  never offered. An any-system booking goes to a free station, and the other free ones are chips
  staff can pick instead. A booking for a station still in use says so ("HEX is still in use.")
  instead of failing only at "Check in & start" (#20).

## [0.0.1-alpha.1] - 2026-10-24

### Fixed
- Floor app End: setting "Ended at" earlier than now (which lowers the bill) now needs a reason.
  The server requires it (`end_reason_required`) and audits the move with the end and bill before
  and after; the dashboard bill shows it in History with an "End moved" tag (`session.end`
  `end_moved`, migration `20261023202840_bill_edit_stale_end_moved`).
- Bill edits (My bills and dashboard Edit bill) no longer settle against a payment or edit that
  landed after the bill was loaded: `bill.adjust` sends the total and collected the user saw and is
  refused as `stale` if either changed, instead of recording a refund nobody gave or refusing a
  real payment.
- Dashboard Edit bill: changing the amount, method or reason after a failed Save makes a new edit
  instead of replaying the first one. The Start/End fields, which never changed the session's
  times, are removed; the times show as text.

### Changed
- Rebrand to ARQ: app name (Android, iOS, web titles, admin page titles and sign-in), app icons
  on Android (adaptive), iOS and web, and the in-app logo, all generated from `assets/logo.png`
  with `flutter_launcher_icons` (`apps/mobile/flutter_launcher_icons.yaml`). The admin sidebar
  shows the ARQ logo instead of "404".
- Admin Sales bill detail: tags next to the status (Added later, Edited, Discount, Refunded), four
  tiles (time played, players, collected, due / paid by), a compact details grid, Amount and
  Payments side by side on wide screens, payments and history as a timeline with the reason
  quoted, and a note when a bill was added later (who, when, why). The Sales list shows the first
  tag next to each bill's state.
- Floor app: a station card that is over time (single or group) now keeps pulsing red until the
  session is ended or extended, instead of turning red once (steady red with reduced motion on).
- Floor app Extend (single and group): pick any number of minutes (− / + in 5-min steps, a
  slider up to 4 h, or tap to type) instead of fixed +15/+30/+60. The confirmation shows the
  bill so far, the extension's price and the new total, for staff to tell the customer. The
  station card's "+30" button is now "Extend".
- Overtime, single sessions and groups: past the booked end the clock keeps running but the
  price stops at the booked time. At End, staff see how long it ran over and what that adds, and
  choose "Charge overtime" (off by default: the booked time is billed). Extending still charges
  up to the new end. End ops carry `charge_overtime`; server `_pr_session_bill`,
  `_pr_group_bill` / `_pr_sweep` (migrations `20261023154403_no_overtime_charge`,
  `20261023154904_overtime_choice`).

### Added
- Admin dashboard is an installable PWA (web manifest + Angular service worker). The service
  worker caches only the app shell (pages always load fresh when online), never Supabase data;
  the CSP `connect-src` now also lists the font, map-tile and Turnstile origins it re-fetches.
- Missed bills: staff with "Add missed bills" (Bills tab › Add missed bill) and owners (dashboard
  Sales › Missed bill) can add a single session that was never started in the app: customer (or
  walk-in), station, type, game, controllers, date and times, how it was paid, and a required
  reason. The server prices it on the current price list (shown first), adds it ended and paid in
  full, refuses times that overlap play already recorded on that station, and audits it. Server:
  op `session.record`, client RPC `session_quote` (migrations `20261023185829_missed_entries`,
  `20261023191248_staff_entry_perms`).
- Two new staff permissions in admin Users: "Add missed bills" (`bill_record`, owner-granted) and
  "Request missed time" (`time_request`). Neither is on for new invites. The Bills tab shows for
  "Edit own bills" or "Add missed bills"; each button needs its own permission.
- Missed punches: staff with "Request missed time" can ask to add a missed clock-in/out or fix a
  clock-out from Attendance › Add missed time, and see the decision there. Reviewers approve or
  reject on the dashboard (Attendance › Missed time requests); approval applies it as an
  attendance correction, so it counts only then. Owners can still add a missing entry directly. Server: table
  `attendance_requests`, ops `attendance.request` / `attendance.request_decide`.
- Floor app: a Bills tab in the bottom bar (staff with "Edit own bills" or "Add missed bills",
  online only; owner-level users find My bills under More) lists the closed bills the signed-in
  staff member started, today first, with a date picker and day arrows. Tapping a bill changes
  its total with a required comment and, when collected money changes, how it was paid or given
  back. New permission "Edit own bills" (`bill_edit`), granted only by an owner in admin Users.
  Server: `op_bill_adjust` accepts `bill_edit` for bills the caller started (`forbidden`, 'not
  your bill' otherwise); new client RPC `my_bills` (migration `20261023183101_bill_edit_perm`).
- Floor app End session: "Ended at" can be changed (e.g. the timer ran on) and the price
  recalculates; the "Bill amount" can be lowered (sent as a manual discount; the manual-discount
  limit applies below owner level).
- Floor app: Sync button in the Floor screen header.
- Admin Sales: "Edit" on a closed bill (Money permission) shows Start, End and the Price and
  lets you set the amount. Collected is set to match (the difference recorded as paid or given
  back), and History shows the change with any corrected times. Sync op `bill.adjust`
  (migrations `20261023151719_bill_edit` onwards).
- Local demo seed (`supabase/seed.sql`, loaded by `supabase db reset`): arena "404 Arena
  (demo)" with owner and staff logins, catalog, customers, a week of bills, running sessions
  and bookings. Logins and how to load it without a reset are in the README.

### Removed
- Billing rules removed from admin Settings and the floor app's Settings, and the Overtime
  grace field from admin Pricing. Bills use the simple defaults: per-minute, no grace period,
  no minimum charge, rounded to the nearest ₹1. The pricing code is unchanged.
- Sentry removed from the floor app for now (crash reports, breadcrumbs, Session Replay):
  `sentry_flutter` and `sentry_dart_plugin` dropped, `AO_SENTRY_*` defines are ignored. Timer
  anomalies and unexpected errors go to the debug log only. iOS builds no longer fetch
  `sentry-cocoa` from GitHub.

## [0.0.1-alpha.0] - 2026-10-21

First alpha release. For internal testing on the staging project; not for real
takings yet.

### Added

**Floor app (Flutter, staff only)**
- Sign-in with per-person logins; one local database per arena and person.
- Sessions started from a station: game, players, controllers, pricing snapshot
  captured at start. Switch system, change game and change controllers close
  the open segment and open a new one.
- Timers derived from stored timestamps; live price stops at the booked end;
  overtime grace per station type.
- Custom durations in hours and minutes; extensions.
- Billing and payments, including split and group bills, discounts
  (preset, coupon or manual) and cash rounding.
- Groups, bookings tab, members (customers) and controller (pad) tracking with
  loan, return and move history.
- Offline-first: every change is saved on the device and synced through an
  outbox; conflicts and refusals show under Sync → Needs attention.
- Staff module: own clock-in/out (server-timed) and leave applications.
- Permission-aware screens (start, bill, discount, members, stations, …).
- Flavors `dev`, `staging` and `prod`, each bound to one environment.

**Admin web (Angular)**
- Owner self-registration with e-mail confirmation and arena creation;
  self-service venue setup wizard.
- Stations, station types (priced per minute, hour or day, fractional units),
  games library with per-station availability, controllers and accessory types.
- Pricing: rates, time rules (happy hours as ordinary rules), holidays, hours,
  billing rules, overtime grace, discounts and coupons.
- Users: invite by e-mail, accept-invite flow, roles and permissions,
  deactivate.
- Sales and reports, live via private Realtime channels.
- Staff: shifts and roster, attendance corrections, leave approvals, pay setup
  and payroll with finalised, locked periods.
- Password reset; Turnstile support for sign-up and sign-in.

**Backend (Supabase)**
- Declarative schema (`supabase/schemas/`) with generated migrations.
- All writes through `sync_push` with per-op permission checks; the server
  re-prices every bill and extension and refuses any difference.
- Row Level Security on every table, scoped to arena membership and
  permission; `anon` reaches nothing.
- Private Realtime channel per arena; paged `sync_pull` with permission-aware
  filtering.
- Append-only money, audit and evidence records.
- Staff module: attendance days, shifts, leave balances and salary runs.

### Security
- No SECURITY DEFINER function in an exposed schema is client-executable;
  client API is a fixed allow-list.
- Release builds refuse local mode, non-https or development hosts, and any
  secret or `service_role` key.
- Only the publishable key ships in either app.

### Known issues
- Not yet tested on two real phones across different networks.
- Session times are device-asserted within bounds; the server cannot prove an
  end time is true.
- No automated Dart-vs-SQL pricing parity check or cross-app e2e suite: the
  old `tool/` scripts were removed and an e2e suite is planned.
- Admin web admits only owner-level logins, so a `leave_approve`-only member
  cannot approve leave anywhere yet.
- Admin initial bundle exceeds its 500 kB budget.
- Not built yet: push notifications, who's-in board, shared clock-in tablet.

[Unreleased]: https://github.com/rorrimlabs/arc-arena/compare/v0.0.1-alpha.1...HEAD
[0.0.1-alpha.1]: https://github.com/rorrimlabs/arc-arena/compare/v0.0.1-alpha.0...v0.0.1-alpha.1
[0.0.1-alpha.0]: https://github.com/rorrimlabs/arc-arena/releases/tag/v0.0.1-alpha.0
