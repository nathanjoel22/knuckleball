# DEPLOY.md — Knuckleball

Two Supabase projects exist:

| | Project ref | Purpose |
|---|---|---|
| **Production** | `fkgccjhuimkkbupbanxp` | Real coaches, real data. Never test against this. |
| **Staging** | `wpsscxwawgiwmifpjpec` (`knuckleball-staging`) | Test data only. Try everything here first. |

Both are in the "Knuckleball Inc." Supabase org. The CLI stays **linked to production**
(`supabase link`'s default target) — staging is always addressed explicitly with
`--project-ref wpsscxwawgiwmifpjpec` so there's no ambiguity about which project a command
is about to touch.

## Secrets (distinct per project, never in this repo)

Each project has its own copies of the same secret names, set independently via
`supabase secrets set ... --project-ref <ref>`:

- `INVITE_REDIRECT_URL`, `RESEND_API_KEY`, `REPORT_FROM_EMAIL`, `VERIFY_FROM_EMAIL`,
  `VERIFY_REDIRECT_URL`, `RESEND_DAILY_QUOTA` and `ALERT_EMAIL` (since H1), and `OPERATOR_EMAILS`
  (since U12; the only logins `rerender-reports` accepts) — set manually per project. CLAUDE.md
  has the authoritative list and what each one is for.
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` — reserved names, injected
  automatically by the platform into every Edge Function. You cannot and don't need to set
  these yourself (`supabase secrets set SUPABASE_...` is rejected by the CLI).

Staging currently reuses production's Resend API key and sender address (same verified
`knuckleballonline.com` domain) — there's no separate staging email identity. If that's ever
undesirable, set up a second Resend sender and update staging's `RESEND_API_KEY`/
`REPORT_FROM_EMAIL` independently; nothing else needs to change.

Check what's set on either project (values are never shown, only names/hashes):
```bash
supabase secrets list --project-ref fkgccjhuimkkbupbanxp
supabase secrets list --project-ref wpsscxwawgiwmifpjpec
```

## Schema changes — exact order

**Never edit schema or RLS directly on production, and never run `supabase config push`
for Auth settings** (see SETUP.md — it can reset unspecified dashboard settings like Site
URL/redirect URLs).

### Migration history on production (baseline registered — done)

Production was originally built by hand, so the baseline
(`supabase/migrations/20260826082320_baseline.sql`) had to be marked as already applied there
before the first `supabase db push` (`supabase migration repair --status applied 20260826082320`).
That has been done: on 2026-10-06, `supabase migration list` against production showed every
migration in this folder (55, from `20260826082320` to `20261006000000`) applied on both sides,
with Local and Remote identical. So the history is complete, and the next `db push` to
production runs only genuinely new files.

To check the history at any time (read-only; enter the database password at the prompt):

```bash
supabase migration list --project-ref fkgccjhuimkkbupbanxp
```

Every row should show the same version under Local and Remote. A version with no Remote entry
has not reached production yet; a Remote entry with no Local file means a change reached
production outside this repo — stop and investigate before the next `db push`.

1. **Write a migration file.**
   ```bash
   supabase migration new <short_description>
   ```
   This creates a timestamped file in `supabase/migrations/`. (Many files here use hand-set
   round timestamps instead, e.g. `20261005020000_r4_cross_team.sql`; that works as long as each
   new version sorts after the last one applied.) Write plain SQL in it —
   `CREATE TABLE`, `ALTER TABLE`, `CREATE POLICY`, etc. Per the RLS rule in CLAUDE.md, if the
   policy needs a cross-table check, use a `SECURITY DEFINER` helper function (see
   `is_team_coach`/`is_team_member` in the baseline migration) — never a direct subquery
   across `teams` ↔ `pitcher_teams`, which caused the original 42P17 outage.

2. **Preview against staging first:**
   ```bash
   supabase db push --project-ref wpsscxwawgiwmifpjpec --password <staging-db-password> --dry-run
   ```
   Confirms exactly which migration(s) would run and where, before touching anything.

3. **Apply to staging for real:**
   ```bash
   supabase db push --project-ref wpsscxwawgiwmifpjpec --password <staging-db-password>
   ```

4. **Verify on staging.** Run the smoke checklist below against staging. Manually check the
   specific thing your migration was for (e.g. `select * from pg_policies where
   schemaname='public'` if it touched RLS).

5. **Only once staging looks right, apply to production:**
   ```bash
   supabase db push --project-ref fkgccjhuimkkbupbanxp --password <prod-db-password> --dry-run
   supabase db push --project-ref fkgccjhuimkkbupbanxp --password <prod-db-password>
   ```
   Per BACKUPS.md, take a fresh backup dump before this step if the change touches
   anything beyond a brand-new additive table.

6. **Re-verify on production** with the same manual check from step 4, against real data.

### Rollback (schema)

There is no automatic down-migration. Since Oct 2, each risky migration has a hand-written down
script in `supabase/rollback/` (`<version>_<name>_down.sql`, 10 so far), written from production's
definitions before the change. `db push` never runs these (they are outside
`supabase/migrations/`): run one deliberately, staging first, only when that change has to be
undone. Otherwise, write and apply a new migration file that reverses the change (e.g.
`DROP POLICY` / re-`CREATE POLICY` with the old definition), following the same staging-first
order above. Never hand-edit a production policy from the dashboard to
"just fix it quickly" — that's exactly how this project ended up with no migration history
in the first place (see `supabase/schema/SCHEMA_NOTES.md`).

## Edge Function deploys

```bash
supabase functions deploy <name> --project-ref wpsscxwawgiwmifpjpec   # staging first
# verify, then:
supabase functions deploy <name> --project-ref fkgccjhuimkkbupbanxp   # production
```

All seven functions deploy the same way: `invite-pitcher`, `request-email-change`,
`rerender-reports`, `send-guardian-consent`, `send-removal-notice`, `send-session-report` and
`send-verification-email` (`_shared/` holds common code and is not deployed on its own).
`supabase/config.toml` carries no per-function `verify_jwt` overrides, so every function
defaults to platform JWT verification on both projects; keep it that way (see P0-01's history with
`send-session-report` and `verify_jwt = false`).

### Rollback (functions)

`git checkout` the last-good commit of the function's `index.ts`, then redeploy that version
with the same command.

## Frontend: deploy to production

The frontend has no build step. "Deploying" is a `git push` of `main` to GitHub Pages;
the live site updates within a minute or two.

Before every frontend deploy:

1. **Confirm the config files point at production**, not staging. If you've been serving
   against staging locally (section below), the swap may still be in place:
   ```bash
   grep -l wpsscxwawgiwmifpjpec supabase-config.js report-config.js
   ```
   This must print **nothing**. If it prints a filename, restore the prod config (the `mv`
   step at the end of the staging section) before committing.

2. **Bump `CACHE_VERSION` in `sw.js`** (`kb-shell-vN` → `kb-shell-vN+1`) — on *every*
   frontend deploy, whether or not this change touched `sw.js` or `PRECACHE_URLS`. A fresh
   version name forces the next service-worker activation to re-precache the whole shell
   and purge the old cache generation, so an already-installed device can't sit on stale
   JS — or on a half-updated mix of new and old shell files — after the push. Skipped, this
   is the step that silently leaves returning coaches on old code. (The stale-while-revalidate
   fetch handler is a backstop, not the delivery mechanism.)

3. `git push origin main`.
   A tracked pre-push hook (`.githooks/pre-push`) enforces step 2: if the push changes any
   shell file (`*.html`, `sw.js`, `sw-killswitch.js`, `supabase-config.js`,
   `report-config.js`) on `main` without a higher `kb-shell-vN` than the remote, the push
   is rejected. It needs a **one-time** enable per clone: `git config core.hooksPath .githooks`.
   Genuine exception: `git push --no-verify`.

4. **Verify the change is actually live.** Load the affected page and reload twice: the
   service worker serves the old shell on the first load, installs the new `CACHE_VERSION`
   and re-precaches in the background, then serves the new shell on the second. The new
   `sw.js` can take a few minutes to reach a device (GitHub Pages sets its own
   cache-control on that file) — if the change still isn't visible after two reloads, wait
   ~10 min and retry before assuming the deploy failed.

### Rollback (frontend)

`git revert <bad-commit>` and push. The plain revert carries `CACHE_VERSION` *back down*
to its previous value, which reuses an old generation name — bump it *forward* again in
the revert commit (step 2 above) so the version history stays monotonic. Any value that
differs from the broken generation makes `activate()` re-precache and clean up.

## Frontend: running against staging locally

The frontend is static HTML with no build step, so "deploying" it to staging just means
serving it locally with the staging config swapped in — nothing gets pushed anywhere.

1. From the repo root, temporarily swap the config files:
   ```bash
   cp supabase-config.js supabase-config.prod.js.bak
   cp report-config.js report-config.prod.js.bak
   cp supabase-config.staging.js supabase-config.js
   cp report-config.staging.js report-config.js
   ```
2. Serve the repo root locally:
   ```bash
   python3 -m http.server 8080
   ```
3. Open `http://localhost:8080/login.html` (or any page) in a browser. It now talks to the
   `knuckleball-staging` project instead of production.
4. **When done, restore the real config** so you don't accidentally commit the swap:
   ```bash
   mv supabase-config.prod.js.bak supabase-config.js
   mv report-config.prod.js.bak report-config.js
   ```

`INVITE_REDIRECT_URL` on staging points to `http://localhost:8080/accept-invite.html` for
exactly this reason — invite links sent from staging only make sense while serving locally
on that port.

Staging's Supabase **Site URL** (Auth settings) must stay set to `http://localhost:8080` for
the same reason — auth email links (confirmation, password reset) are built from it, and
staging is only ever served locally on port 8080. Don't "fix" it to a real URL.

The frontend is never actually deployed "to staging" as a hosted site — production remains
the only place `git push` publishes to (GitHub Pages). Building separate staging hosting
was deliberately out of scope here.

## Smoke checklist (manual — no CI/CD yet)

Run this against staging after any non-trivial change, before touching production:

1. **Signup** — create a coach account (real signup flow, or via the Admin API with
   `email_confirm: true` to skip the confirmation email during a quick check). Confirm a
   `profiles` row (role `coach`) and a `teams` row are created.
2. **Invite** — as that coach, invite a pitcher to the team. Confirm the invite email
   arrives and an `invites` row exists with `status = 'pending'`.
3. **Accept** — accept the invite as the pitcher (via the real link, or by setting a
   password via the Admin API and signing in directly). Confirm a `profiles` row (role
   `pitcher`), a `pitcher_teams` row, and the invite's `status` flips to `accepted`.
4. **Session** — as the pitcher, log a session with a few pitches. Confirm the coach can
   see it (same query `loadSessionsForCurrentSelection` uses in `bullpen-tracker.html`).
5. **Report** — send the session report. Confirm the email arrives with a
   `report.html?r=<token>` link (reports are HTML pages now; there is no PDF attachment).
   On staging, **the emailed link itself will not work** — `send-session-report` always
   builds links on `https://knuckleballonline.com`, whose `report.html` reads from
   *production* storage, and a staging report only exists in *staging* storage. That's
   expected, not a bug. To check the report, copy the `r=<token>` value from the email
   and open `http://localhost:8080/report.html?r=<token>` while serving locally with the
   staging config (above). Confirm it renders and looks correct.

This was run in full against staging on 2026-08-26 (see git history / task record for
P1-08) — all five steps passed with test data.

## What's still manual, on purpose

CI/CD and automated tests are explicitly out of scope for this task. This checklist is the
whole safety net for now — run it by hand, every time, until that changes.
