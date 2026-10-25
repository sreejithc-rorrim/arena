# Hosted Supabase — deployment checklist (new DEVELOPMENT project)

Prepared 2026-10-11 (updated 2026-10-12 for 0016; 2026-10-14 for the generated
migrations after it: invitations, Realtime, the `private` schema, narrower
money/customer reads) from an audit of the migrations, RLS, grants, the
auth design and the mobile configuration. **Nothing added after 0015 has been
run against a hosted project, and the hosted state has not been re-verified
since 2026-10-12.** Every step that creates or changes anything hosted is
yours to do (or to approve explicitly). Read [SYNC.md](SYNC.md) for how sync
works.

This is a *development* hosted project: use it to prove two real phones on
different networks before a production project is created the same way.

---

## 0. Keys and secrets — what may go where

| Item | Kind | Where it may live | Never |
|---|---|---|---|
| Project URL (`https://<ref>.supabase.co`) | public | app build config (`dart_define.<env>.json`), docs | — |
| **Publishable key** (`sb_publishable_…`) or legacy **anon** key | public (it is shipped inside the app; RLS + `sync_push` checks are what protect data) | app build config; admin dashboard `apps/admin/src/environments/environment.production.ts` (filled at deploy time) | — |
| **Secret key** (`sb_secret_…`) / legacy **service_role** key | **SECRET — bypasses RLS** | password manager only. Nothing deployed needs it (no Edge Functions) | the app, the dashboard, the repo, `dart_define` files, CI logs, chat, screenshots |
| **Database password** | **SECRET** | password manager; typed at the `supabase link` / `db push` prompt | the repo, shell history, chat |
| JWT secret / signing keys | **SECRET** | stays in the dashboard | anywhere else |
| Supabase **personal access token** (CLI `supabase login`) | **SECRET** (acts as you, all projects) | the CLI's keychain entry | the repo, chat |
| SMTP credentials (if custom SMTP) | **SECRET** | dashboard only | anywhere else |

The app reads exactly two values in cloud mode: `AO_SUPABASE_URL` and
`AO_SUPABASE_ANON_KEY` (the publishable or anon key — the name is historical).
`dart_define*.json` files are git-ignored; only `dart_define.example.json`
(placeholders) is committed. A release build refuses local mode, a missing URL
or key, any non-https or development host, and any secret (`sb_secret_…`) or
`service_role` key ([RELEASE.md](RELEASE.md)). The dashboard's production build
likewise refuses a non-https or local URL and a secret/`service_role` key, and
shows "Setup needed" instead of the app while `environment.production.ts` is
empty.

## 1. What the audit found

| Area | Result |
|---|---|
| Migration order | The files in `supabase/migrations/`, oldest first: one generated baseline (`20261015054055_declarative_sync`, the whole schema from scratch) and the generated migrations after it, applied in filename order by `supabase db push`. The old hand-written `0001`–`0016` and the 2026-10-11…14 migrations were squashed into that baseline; **never squash history again once a remote has applied it**. |
| Fresh-project compatibility | The baseline creates every schema object on an empty project (verified by `supabase db reset --local` on the same Postgres 17 image). Extensions: `pgcrypto` (already present on hosted — `if not exists` is a no-op), `btree_gist` in `extensions`. The migrations add the `realtime.messages` policies and tables to the `supabase_realtime` publication; none inserts users or needs superuser beyond what `postgres` has on hosted. **It cannot be pushed onto a project that already has the old history** (§4a). |
| `seed.sql` | Intentionally empty (arenas start with no catalog). `db push` does not run it unless `--include-seed` is passed — don't. The real arena is created by the owner's sign-up or once by `bootstrap_owner` (step 7). |
| Client write path | No table or view is writable by `anon`/`authenticated`; every change goes through `sync_push` (permission + rule checks per op). |
| RLS | Enabled on every public table; every policy is scoped to arena membership. Payment and charge rows also need `bill`, `money` or `reports`; customers `start`, `members`, `money` or `reports`; `audit_log` owner level; `staff_invites` has no client access. Views are not client-readable (views bypass RLS). The device feed (`sync_pull`) applies the same rules (`_sync_hidden`): customers, money rows and coupons reach only devices whose login may read them; coupons (`discounts`) need `discount`, `settings`, `money` or `reports`. |
| Client API | Signed-in users can execute exactly: `sync_push`, `sync_pull`, `sync_fetch_entity`, `my_arenas`, `create_my_arena` (sign-up: confirmed logins, one arena each), `invite_member` / `accept_invite` / `revoke_invite` / `arena_invites` (invitations), `arena_staff` (owner's staff list with e-mails), `arena_sales` / `arena_sale` (owner's Sales screen), `arena_pricing` (owner's Pricing screen), `app_is_owner` (asserted by pgTAP test 13). `anon` can call nothing. `bootstrap_owner` is database-only; `create_arena`, `add_staff_by_email` and `add_member_by_email` are dropped. Found and fixed in 0014: trigger functions still had Postgres' default EXECUTE grant (unreachable, but removed). |
| SECURITY DEFINER | All pin `search_path`. None in an exposed schema is executable by `anon` or `authenticated` (lints 0028/0029): the client API's definer bodies live in schema `private` (not exposed by the Data API) and `public` holds `security invoker` wrappers. Server-only definer functions (`op_*`, `_pr_*`, `bootstrap_owner`, …) stay in `public` without client EXECUTE. |
| Realtime | One private channel per arena (`arena:<arena uuid>`); `realtime.messages` policies admit only active members of that arena. Postgres Changes on 29 published tables (INSERT/UPDATE, RLS-filtered); a `sync` broadcast after committed ops. No business data in Realtime — events only trigger authorized pulls/refetches (SYNC.md "Read path"). |
| Role limits | Same as hosted defaults: `authenticated` 8 s statement timeout, 8 s lock timeout. The two-device suite runs under them through PostgREST. Pulls are paged at 2,000 rows; pushes at 50 ops. |
| Auth design | Per-person logins. A new arena owner registers on the admin dashboard and confirms the e-mail with the e-mailed link, then `create_my_arena` creates their one arena; the operator can also use `bootstrap_owner` (SQL editor). Everyone else (staff and co-owners) joins **only by accepting an invitation**: the owner invites from the dashboard's Users page, which runs `invite_member` as the caller and has Supabase Auth e-mail the link (`signInWithOtp`: a sign-in link for a confirmed login, the sign-up confirmation for a new one), and the invited, confirmed login accepts on the dashboard's `/accept-invite` page (a login that did not arrive by a sign-in link chooses its own password first) (SYNC.md "Auth and roles"). No owner-set passwords, no linking of an existing login without consent. No service-role key anywhere in the app or repo. |
| Mobile — Android | **Fixed:** the release manifest had no `INTERNET` permission (only debug/profile did), so a release build could not reach Supabase at all. Debug builds now allow cleartext only for the local dev stack. Release builds are cloud-only and need the release key (RELEASE.md). |
| Mobile — iOS | No ATS exceptions; https works as is. Session (refresh token) stored in the Keychain via `flutter_secure_storage`, one entry per backend (`arena_ops.supabase.session@<host:port>`). |
| Settings that are NOT migrations | Everything under `[auth]` in `supabase/config.toml` applies to the LOCAL stack only. On hosted you set them in the dashboard (step 3), together with Realtime's "Allow public access" (step 3.7) and the two e-mail templates (step 3.1). |

Run `supabase/audit/security_audit.sql` after the push (step 5): it re-checks
grants, RLS, views and `search_path` on the hosted database. Its allowlist of
client functions predates the current client API (it still names
`add_staff_by_email`), so see step 5 for which `FAIL` rows to expect.

## 2. Create the project (dashboard)

1. Sign in at **supabase.com/dashboard** → your organization → **New project**.
2. **Name**: `arena-ops-dev` (keep "dev" in the name; production gets its own project later).
3. **Database password**: click *Generate a password*, then store it in your password manager **before** continuing. You will type it at the CLI prompt in step 4; it is never written to the repo.
4. **Region**: *South Asia (Mumbai)* — closest to the venue.
5. **Security options** (if shown): keep *Data API* enabled and exposing the `public` schema (the app uses PostgREST RPCs) — never `private`. Any "automatic RLS" option can stay on — the migrations enable RLS themselves.
6. Create the project and wait until it reports healthy.
7. **Project Settings → General**: note the **Reference ID** (`<ref>`).
8. **Project Settings → API Keys**: copy the **Project URL** and the **publishable key** (or the legacy **anon** key). Do **not** copy the secret / service_role key — nothing needs it.

## 3. Authentication settings (dashboard)

1. **Authentication → Sign In / Providers → Email**: enabled.
   * Keep the **Email provider itself ENABLED** — it is how everyone signs in with e-mail + password.
   * **Authentication → Sign In / Providers → User Signups → Allow new users to sign up**: **ON** — new arena owners register on the admin dashboard. A sign-up belongs to no arena until it confirms its e-mail and creates one (`create_my_arena`, one per login).
   * **Allow new users to sign up** must stay ON for invitations too: inviting a new address creates its login.
   * **Confirm email**: **ON**. Two templates (**Authentication → Emails → Templates**), copied from the repo:
     * **Confirm signup**: subject `ARQ: confirm your e-mail`, body = `supabase/templates/confirmation.html`. It shows an owner signing up the confirmation link (it opens the dashboard's `/register`), and an invited new address the invitation link (it tells them apart by the `signup: "owner"` user metadata the sign-up sets).
     * **Magic Link**: subject `You're invited to ARQ`, body = `supabase/templates/magic_link.html` (invitations to an address that already has a confirmed login).
     * **Project Settings → Authentication → SMTP**: set up your own SMTP sender. The built-in one delivers only to the project's team members, at a low rate, so real sign-ups would never get their link and invitations would never arrive.
   * **Attack protection → CAPTCHA (Turnstile)**: create a Turnstile widget in Cloudflare for the dashboard's domain; put its **site key** (public) in `apps/admin/src/environments/environment.production.ts` (`turnstileSiteKey`) and its **secret key** here (Provider: Turnstile). The dashboard then sends a token with sign-up, sign-in, password reset and invitations. **Do not turn CAPTCHA on until the floor app sends a token too**: Supabase then refuses every password sign-in without one, including staff signing in on the floor app. Keep the default sign-up rate limits.
   * **Secure password change**: ON. A person whose last sign-in is older than 24 h may be asked to sign out and back in before More → Change password succeeds.
2. **Authentication → Sign In / Providers → Anonymous sign-ins**: **OFF**.
3. **Authentication → Policies / Passwords** (wording varies): minimum length **10**, require letters and digits; enable **leaked-password protection** if your plan offers it.
4. **Authentication → URL Configuration**: **Site URL** = the admin dashboard's https URL; **Redirect URLs** must include `https://<dashboard>/register`, `https://<dashboard>/accept-invite` **and** `https://<dashboard>/reset-password` (or simply `https://<dashboard>/**`). The sign-up confirmation links to the dashboard's `/register` page, the invitation and sign-in e-mails to `/accept-invite`, and the password-reset e-mail (Sign in → *Forgot your password?*) links to `/reset-password`. The dashboard asks for the redirect to its own address (`<the origin it is served from>/reset-password`); a redirect URL missing from this list makes Supabase send the person to the Site URL instead, where the link does nothing. The floor app needs no redirect URLs (no OAuth, no deep links); staff who forgot their password can reset it from the dashboard's sign-in page too.
   * **Authentication → Emails → Templates → Reset password**: the default template (a link, `{{ .ConfirmationURL }}`) works as is; change only the wording if you like. It needs the SMTP sender from step 1 like every other e-mail.
   * The reset link signs the person in, so **Secure password change** (step 1) does not get in the way: they set the new password right after a fresh sign-in.
   * Locally, `supabase/config.toml` already allows `http://127.0.0.1:4200/**` and `http://localhost:4200/**`; the reset e-mail shows up in Mailpit (`http://127.0.0.1:54434`, `[inbucket]` in `config.toml`).
5. Leave JWT expiry (3600 s) and refresh-token rotation at their defaults (they match the local stack the app was tested with). A Realtime revocation takes effect within the JWT expiry.
6. *(Optional, smaller surface)* **Integrations / Database → Extensions**: the app does not use GraphQL; you may disable `pg_graphql`.
7. **Realtime → Settings**: turn **off** "Allow public access" (private channels only). Both apps use private channels; this is a dashboard-only setting.

## 4. Apply the migrations (your terminal, from the repo root)

```bash
supabase login
```
Opens a browser to create a personal access token; the CLI keeps it in your keychain.

```bash
supabase link --project-ref <ref>
```
Prompts for the database password from step 2.3. This writes `supabase/.temp/project-ref` (git-ignored).

```bash
supabase db push --dry-run
```
For a new project: must list exactly the files in `supabase/migrations/`, oldest
first, and nothing else. On a project that already has the old history it fails
or lists a baseline that would collide with existing objects: stop, see §4a.

```bash
supabase db push
```
Applies them. Do NOT add `--include-seed`.

```bash
supabase migration list --linked
```
Local and Remote columns must both show the same list.

Rules while linked:
* **Never** run `supabase db reset --linked` or `supabase test db --linked` (the pgTAP files insert users and fixtures).
* The race scripts (`supabase/concurrency_tests/`) target the local Docker container only and refuses anything else; keep using them locally.
* Future schema changes: edit `supabase/schemas/` and generate the migration (CLAUDE.md, "Supabase — declarative schemas only"; never write one by hand), run `supabase db reset --local` and `supabase test db` locally, then `supabase db push --dry-run` / `db push`.

## 4a. The existing hosted dev project (old history)

The hosted dev project `ouxvtvlzhxddmqirmnxo` was pushed with the old history
(36 versions, `0001` … `20261014105230`) before the migrations were squashed. The
new baseline cannot be pushed onto it, and **the obvious "fixes" destroy data or
drift the schema: never run `supabase db reset --linked`, and never `migration
repair` by hand.**

Decided 2026-10-19: **production is a fresh project** on the current history
(§§1–4 as written). The old dev project is not upgraded in place:

1. **Before touching it**, take a copy: Database → Backups (or
   `pg_dump --schema-only` and `--data-only` of the linked project) and keep it
   with the release records.
2. **Clean up what the repo no longer has** (SEC-002): `supabase functions list
   --project-ref ouxvtvlzhxddmqirmnxo` → `supabase functions delete staff-admin`
   (it holds the service-role key and was deployed `--no-verify-jwt`).
3. Either leave it as an old staging copy (no new builds point at it) or delete
   it and create a new staging project from §1. The dashboard's
   `environment.production.ts` and `dart_define.prod.json` must point at the new
   production project, never at this one.

### Backups (every hosted project holding real takings)

* Use a plan with daily backups, and turn on **Point-in-Time Recovery** for
  production (Database → Backups). Write down the retention.
* Before every `supabase db push`: a `pg_dump --schema-only` and a
  `--data-only` of the linked project.
* Once before go-live, restore one backup into a scratch project and check that
  sessions and payments are there (a restore drill).
* Money, audit and evidence rows are append-only in the database itself
  (`_append_only` triggers on payments, charges, bill discounts, `audit_log`
  and pad moves): deleting a session or an arena
  that has them is refused. To really remove test data (a whole test arena, or a
  kept arena's pre-release activity, plus test logins) use
  `supabase/audit/prod_prerelease_reset.sql`, after an inventory
  (`supabase/audit/prod_prerelease_inventory.sql`) and a backup proven to
  restore; the runbook is in its header. It is a dry run until explicitly
  confirmed, lifts only those triggers inside its own transaction and keeps
  foreign keys enforced. Never delete under `set session_replication_role =
  replica`: that also switches off every foreign-key cascade and check, so the
  arena row goes and all of its rows stay behind as orphans.
* Migrations are forward-only. A generated migration that drops a column
  (e.g. `20261016123826_game_play_modes` drops `games.player_mode`) must never
  reach a database holding real rows of it without a copy step first.

## 5. Verify the hosted database

1. **SQL Editor** → paste `supabase/audit/security_audit.sql` → **Run**. The script's allowlist predates the current client API, so on the current schema it reports `unexpected function callable by authenticated` for `create_my_arena`, `invite_member`, `accept_invite`, `revoke_invite`, `arena_invites`, `arena_staff`, `arena_sales`, `arena_sale` and `arena_pricing` — those are intended (section 1; pgTAP test 13 asserts the exact list). Any other `FAIL` row is real. The `REVIEW` rows must list exactly the 14 client functions in section 1 and the extensions.
2. **Advisors → Security Advisor**: review; there should be no RLS-disabled or exposed-view findings. On 2026-10-12 it also listed **Leaked password protection disabled** — turn it on under Authentication → Policies / Passwords if the plan offers it (step 3.3).
3. **Database → Tables**: `arenas` holds only arenas created by sign-up or `bootstrap_owner` (`seed.sql` is empty and is never pushed).
4. **SQL Editor**: `select tablename from pg_publication_tables where pubname = 'supabase_realtime' order by 1;` lists the 29 tables in `supabase/schemas/_cluster/publications.sql`.

## 6. Point a build at it (your machine)

Each hosted project has its own flavor and define file (git-ignored by
`dart_define*.json`): the staging project `arena-ops-staging` uses
`--flavor staging` with `dart_define.staging.json`, the company's production
project `--flavor prod` with `dart_define.prod.json`. Copy
`dart_define.example.json` and fill it in:

```json
{
  "AO_BACKEND": "supabase",
  "AO_SUPABASE_URL": "https://<ref>.supabase.co",
  "AO_SUPABASE_ANON_KEY": "<publishable or anon key from step 2.8>",
  "AO_SENTRY_DSN": "<that environment's Sentry DSN, or empty>",
  "AO_ENVIRONMENT": "staging"
}
```

(`"production"` for prod.) Then add the project's host (`<ref>.supabase.co`) to
that environment's set in `AppConfig.hostedSupabaseHosts`
(`apps/mobile/lib/core/config/app_config.dart`) as a reviewed code change —
until it is there the flavor refuses to start. Never list a host for both
environments.

```bash
flutter run --flavor staging --dart-define-from-file=dart_define.staging.json
```

The prod flavor never runs as a debug build (profile or release only). Release
builds also need `android/key.properties` — Gradle refuses the release
otherwise, it never signs with the debug key ([RELEASE.md](RELEASE.md)).

The older `dart_define.hosted-dev.json` (the old hosted dev project, §4a) no
longer starts: the dev flavor reaches only the local stack. It is retired once
staging is verified.

**Admin dashboard:** fill `apps/admin/src/environments/environment.production.ts`
(intentionally empty in the repo) with the project URL and the publishable key
at deploy time. Production requires an https, non-local URL and a publishable
(`sb_publishable_…`) or legacy anon key; a secret or `service_role` key is
refused, and a build with no or bad configuration shows "Setup needed" instead
of the app. Serve it at the https URL you set as Site URL (step 3.4).

## 7. Bootstrap and the two-phone test

**Initial owner — either route:**

* **On the admin dashboard (self-serve, `/register`):** *Create an account* → e-mail + password → open the confirmation link from the e-mail (same browser) → *Create your arena* (one arena per confirmed login). Needs steps 3.1's sign-up, confirmation, template and SMTP settings. Then continue at step 3 below.
* **By the operator (dashboard + database access):**

1. **Authentication → Users → Add user → Create new user**: your e-mail, a strong password (password manager), tick **Auto Confirm User**.
2. **SQL Editor** → run (your values):
   ```sql
   select bootstrap_owner('you@example.com', '404 Arena', 'Your Name');
   ```
   It creates an empty arena (the owner adds types, prices, stations, games and controllers on the dashboard) and makes that login its owner. It refuses an unknown or unconfirmed login. Running it again creates a *second* arena — run it once.
3. **Admin dashboard**: sign in → the arena starts **empty**: add station types, prices, stations, controllers, games and each game's per-station availability (game detail → *Stations*: Playable / Not installed / Not playable). A game playable on no station shows "No station", and the server refuses a session start for a game not marked playable on that station (`not_playable`). Then the **owner phone**: *Sign in* with that e-mail and password → the arena opens.

**Each staff member or co-owner (owner, any time) — by invitation only:**

4. **Check the e-mail setup once**: step 3.1 (SMTP, both templates, sign-ups on) and step 3.4 (the dashboard's `/accept-invite` in Redirect URLs). Nothing to deploy: the dashboard asks Supabase Auth to send the invitation itself. If an older version deployed the `staff-admin` Edge Function, delete it (`supabase functions delete staff-admin`).
5. **Admin dashboard** → Users → **Invite user**: name, e-mail, role (staff, or owner for a co-owner — only an owner may invite an owner) and permissions. No password: the person receives the link by e-mail (valid 7 days; a newer invite to the same address replaces it). Pending invitations are listed on the Users page with **Withdraw**.
6. The person opens the link → the dashboard's `/accept-invite` page → a new login chooses its own password (an existing one may keep its own) → accepted. Their confirmed e-mail must be the invited address. On their phone: *Sign in* with that e-mail and password.
7. To remove a staff member's access: admin dashboard → Users → **Deactivate** (their device returns to sign-in; their Realtime access ends within the JWT expiry). **Don't delete the login** of anyone who has used the app: deactivating is enough and keeps their history attributed. Only a login that never did anything (e.g. a mistyped invitation) can be deleted under Authentication → Users.
8. Run the multi-device checks on **different networks** (one on mobile data):
   * start a session on one phone, see it on the other within about a second (Realtime), at worst on the next 10 s poll;
   * put one phone in airplane mode, take a payment and start a session there; reconnect; confirm it syncs (or, if the other phone took the same station meanwhile, that it is refused and shown under Sync → Needs attention, money included);
   * both phones try to use the same controller; exactly one succeeds;
   * end and bill a session; confirm the bill is accepted (no `price_mismatch`);
   * owner changes a price; staff phone shows it; a session started on the old price list still ends cleanly;
   * owner turns the staff member off; the staff phone returns to sign-in and keeps any unsent work on the device.
9. Record the results; only then plan the production project (same steps, separate project, separate keys).

## 8. Known limits that still apply after deployment

* **Session times are device-asserted.** The server re-prices every bill
  (migration 0013), but only for the times the device sent; it cannot prove an
  end time is true. Amount validation is therefore **not** protection against
  forged or wrong timestamps. Audit evidence: server receipt time and sender of
  every op (`sync_ops.created_at`, `user_id`). See SYNC.md.
* A Dart pricing change needs a matching migration and a green
  Dart-vs-SQL parity check (SYNC.md "Changing pricing").
* No backups/PITR policy has been chosen for the hosted project (plan-dependent).
* Realtime only nudges: a missed event is caught by the floor app's 10 s poll
  and by the catch-up pull on reconnect (the dashboard refetches on reconnect).
* `sync_pull` hides customers, money rows and coupons from logins that may not
  read them, but rows already on a device stay there when a member's
  permissions are narrowed. Bookings (party name, phone) and bill totals still
  reach every active member: an open product decision.
