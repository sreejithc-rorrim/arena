# Generalization: from one gaming centre to recreation venues

Status: architecture agreed 2026-10-15. Phases 0–4 are the first slice; 5+ wait on owner answers.

The goal is one app that a gaming centre, a pool/snooker hall, a sports turf or a mixed venue can
sign up for and run on its own. No fork per industry, no developer setup, no loss for 404 Arena.

## 1. Executive assessment

The core is already more generic than its labels. What a venue sells is a per-arena **station type**
(`activities`) carrying `uses_controllers`, `uses_games` and `duration_model`; the floor app already
hides the game and controller steps when a type does not use them, and session segments already
allow `game_id` and `controller_count` to be null. The PS5/VR exclusivity rule is not code: it falls
out of "one open segment per resource" plus the `current_mode` lock on a resource offering several
types. So the work is mostly **setup, visibility and wording**, not the session or pricing engine.

What actually blocks a pool hall or turf today:

1. A new arena starts completely empty, with no guided setup (`create_my_arena` seeds nothing and the
   dashboard lands on Users).
2. Games and Controllers/Accessories screens show for every venue.
3. About a dozen PS5/VR literals in the floor app and dashboard.
4. Console wording throughout ("Now playing", "VR rounding", "Station").

Strengths to keep untouched: timestamp-derived timers, immutable pricing snapshots, segments,
`sync_push → op_*` as the only write path, server re-pricing, Dart/SQL pricing parity, RLS by arena.

## 2. Gaming-specific coupling found

| Where | Coupling | Action |
|---|---|---|
| `session_segments` | `controller_count between 1 and 4` | Keep: only used by controller types, null otherwise |
| `billing_policies.vr_unit_rounding` | VR-named, drives every `unit` type | Keep column; relabel "Fixed-block rounding" |
| `rates.controller_count`, `bookings.controller_requirement` | Price keyed by controller count | Keep; null for other types |
| `games.platforms` | Free text, defaults to PS5 | Phase 3: choices from the arena's game types |
| `_pricing_snapshot` default hours | 404's Tue–Sun 14:00–23:00 when `business_hours` unset | Onboarding always writes hours |
| Flutter `booking_screen.dart` | `activity.code == 'VR' ? 'PSVR2' : 'PS5'` | Phase 3: compatibility, not platform names |
| Flutter `station_controllers_sheet.dart` | dual mode only when codes are PS5 and VR | Phase 3: any multi-type station |
| Flutter `stations_screen.dart` | Controllers button only for PS5/VR codes | Phase 3: `usesControllers` |
| Flutter `station_card.dart` | "up to 4" on every rate line | Phase 3: controller types only |
| Admin `nav.ts`, settings sections | Games, Accessories always visible | Phase 2: capability gate |
| Admin `game-view.ts` | compatible stations = `kind === 'station'` | Phase 3: stations offering a game type |
| Copy (both apps) | "Now playing", "VR", console icons | Phases 2–3: noun-driven, neutral copy |

## 3. Domain model

**No table renames.** Renaming arena→venue or station→resource touches every op, view, Drift table
and sync mapping for no functional gain. The concepts map as:

| Product concept | Stored as | Notes |
|---|---|---|
| Venue | `arenas` + `settings` rows | One owner, one venue; multi-venue stays possible (membership is per arena) |
| Resource (station, table, ground…) | `resources` | `kind`, `status` (maintenance), `current_mode` |
| What is sold (PS5, Pool, Football turf) | `activities` ("station type") | Already the generic concept; owns the pricing key |
| Games catalogue | `games`, `game_resources` | Optional, only for types with `uses_games` |
| Equipment (controllers, headsets) | `controllers`, `accessory_kinds` | Optional, only for types with `uses_controllers` |
| Session, segment, booking, payment | unchanged | Shared by every venue type |

The brief's "Game → Activity" would collide with `activities`, which already means "station type".
A sport on a turf (football vs cricket) is a station type, not a game: a ground offering both types
gets the same type choice the new-session screen already shows.

## 4. Station type catalog and capabilities

**Catalog.** `public.station_type_catalog()` returns the global list of ready-made types as jsonb:
`{code, name, group, uses_controllers, uses_games, duration_model, unit_minutes, noun}`. It is data
inside a SQL function so it ships with the declarative schema to every environment without a seed
or a table. Choosing one sends the existing `activity.upsert`; the owner's copy is then theirs to
edit. The catalog carries no prices: the owner always enters them.

| Group | Types |
|---|---|
| gaming | PlayStation 5, Xbox, Gaming PC, VR (15-min blocks), Racing simulator |
| cue | Pool table, Snooker table |
| sports | Football turf, Cricket net (60-min blocks, ground), Badminton court (60-min blocks, court) |
| arcade | Arcade machine (time-based; per-play is not supported) |
| other | Lounge / private room |

**Accessory types work the same way.** `public.accessory_kind_catalog()` lists ready-made
accessory types (`{name, group, counts_as_controller}`: Controller, Fight stick, VR headset,
Steering wheel, Headphones, Cue stick, Ball set, Football, Cricket kit, Badminton racket, Bibs).
Settings → Accessory types offers them under "From catalog" (sent as the ordinary
`accessory_kind.upsert`) next to a custom type.

**Business category is not stored.** At sign-up it only pre-ticks catalog types (gaming centre →
PS5, PC, VR). A turf that later adds a PlayStation picks it from the same catalog.

**Capabilities are derived from the venue's active types**, with one rule mirrored in Dart
(`domain/venue/venue_capabilities.dart`) and TypeScript (`core/venue/`):

| Capability | On when | Shows |
|---|---|---|
| `games` | any active type uses games | Games nav, game step, compatibility, top games |
| `equipment` | any active type uses controllers | Controller board, accessories, controller step |

Bookings, sessions, pricing, payments, customers, staff and reports are core for every venue.
Deriving instead of storing flags means the UI can never disagree with the catalog (no "games off"
while a type still uses games). Turning a capability off hides screens only; no data is deleted, and
the server keeps enforcing permissions and ops regardless of visibility.

**Venue noun.** One stored value, the settings key `venue_profile = {resource_noun}` where the noun is
one of station, table, ground, court, machine, room. Onboarding sets it from the chosen types (their
shared noun, else station); Settings → Arena edits it. Labels such as "Add your first table" and the
Stations nav item read it.

## 5. Database migration strategy

All changes are additive and declarative (`supabase/schemas/`, pg-delta migrations):

- New `station_type_catalog()` (security invoker, client API, no table access).
- New `_venue_profile()` validator; `op_settings_save` accepts the `venue_profile` key.
- No column, table or Drift change. The settings feed already syncs any key; devices accept keys on
  `sharedSettingKeys`.

Existing arenas keep working with no data change: a venue with no `venue_profile` reads as "station",
and 404 Arena's PS5/VR types keep every console screen visible. The hosted project is behind local
migrations and is only updated manually (`docs/DEPLOY_SUPABASE.md`).

## 6. Floor app (Flutter) plan

- Providers for the derived capabilities and the venue profile, watching the sync revision.
- Hide the Controller board and Games tiles, the station-card games button and the controllers
  button when the capability is off; the new-session flow already skips game and controller steps.
- Noun in floor zone headings, the new-session station step and the stations empty state.
- Remove the PS5/VR literals listed in section 2 (staff screens only; owner screens in the app are
  scheduled to be hidden and are not extended).

## 7. Dashboard (Angular) plan

- A venue store (types' flags plus `venue_profile`) feeding nav filtering, a route `canMatch` guard,
  and in-page sections (accessories, top games).
- Neutral copy and noun-driven labels.
- Settings → Station types gains "Add from catalog".

## 8. Self-service onboarding

Register → create arena (name, your name) → `/setup`, four short steps, each saved as it is completed
so leaving half-way resumes at the first unfinished step:

1. **What do you run?** Category cards pre-tick catalog types; adjust the ticks.
2. **When are you open?** Weekly hours (suggested 10:00–22:00 every day).
3. **How much do you charge?** One price per type (per controller count for controller types), per
   hour or per block.
4. **Add your tables / grounds / stations.** A count per type; names are filled in ("Table 1").

The overview then shows optional next steps: invite staff, billing rules, holidays. Everything stays
editable in Settings and Pricing.

## 9. Testing and regression strategy

- Existing suites unchanged and green: `tool/verify_all.sh`, `--with-it`, `--with-psql` (pricing
  parity; this slice does not change pricing semantics).
- pgTAP `27_venue_types_test.sql`: catalog validity and grants; `venue_profile` validation and
  permission; a pool hall built from scratch runs a session and payment with no game or controllers;
  a turf on 60-minute blocks refuses an overlapping booking and bills started hours.
- Flutter: capability rule, profile parsing and sync, gated tiles (phone and desktop), pool flow
  without game/controller steps, booking games filtered by compatibility.
- Admin: venue store, nav gating, setup steps and resume, sign-up lands on setup, add-from-catalog,
  and an integration test from registration to a paid pool session.
- Real-device offline behaviour is not covered by these checks.

## 10. Phases

| Phase | Objective | Status |
|---|---|---|
| 0 | This document | first slice |
| 1 | Catalog function, `venue_profile` setting, pgTAP (pool and turf end to end) | first slice |
| 2 | Derived capabilities and venue noun in both apps; gated nav and screens | first slice |
| 3 | Remove PS5/VR literals and console copy on staff and dashboard screens | first slice |
| 4 | Self-service `/setup` wizard and "Add from catalog" | first slice |
| 5 | Server booking integrity: booking vs live session, maintenance, cleaning gap | needs owner answer |
| 6 | Turf booking UX: slot grid, optional deposit | needs payments-on-booking design |
| 7 | Hide owner screens in the floor app | planned separately |

## Not supported by the current engine

Stated plainly so nobody assumes otherwise:

- **Per-play, credit or token pricing** (arcades). Only time-based pricing exists.
- **Packages, bundles and membership plans.** Membership plans are still an open owner question.
- **Booking deposits or prepayment.** Payments attach to sessions, not bookings.
- **Per-resource rates.** Price is per type; a premium table needs its own type.
- **Slot-grid booking.** Bookings use a date, start time and duration.
- **Server-side booking checks against live sessions, maintenance and the cleaning gap.** The floor
  app checks these; the server only refuses booking-vs-booking overlaps.
- **Billing unit and block rounding are venue-wide.** A mixed venue shares them. Types on the
  fixed-block model (VR, turf) get per-type block lengths, but the rounding direction is shared.
- **Session without a running timer.** A turf booking is checked in and runs a normal timed session.
- **GST and invoices.** Still an open owner question (#22).
