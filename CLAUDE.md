# CLAUDE.md — Knuckleball

Standing context for every Claude session working in this repo. Read fully before touching anything.

## Topic files: read before you touch these

This file holds every always/never rule. The detail for each area lives in `docs/claude/`. Before working on an
area, read its file in full; a packet that touches several areas reads each one.

| Before you touch | Read |
|---|---|
| the database, RLS, migrations, Edge Functions, email, rosters and who sees what, saving and sync, session stats, account deletion | `docs/claude/backend.md` |
| training facilities, chat, QR join codes, linked sign-ins (F1) | `docs/claude/facilities.md` |
| Live Game | `docs/claude/live-game.md` |
| the app's chrome, History, navigation, the installable app, the landing and sign-in pages | `docs/claude/app-shell.md` |
| the charting grid, zone numbers, accuracy, sports, session layouts | `docs/claude/charting.md` |

A decision about one area goes in that area's file. A new always/never rule goes here. Code comments, migrations
and plans that cite a CLAUDE.md section by name ("Charting surface decisions", "Staging report links") mean the
same heading in its topic file; the landmines and RLS rules they cite by number are still below.

## Design principle (binding)

**Charting never requires the network. Only syncing and sending reports do.** A team must be able to open Knuckleball anywhere — including with no internet — and chart a complete bullpen. Login is the single honest exception, and only on first use: the standard is **log in once, then chart anywhere forever**. A token refresh that fails purely for lack of network must never bounce a charter to a login screen or block charting; genuine auth failures while online still must. Reports are never generated from an unsynced session. Any change that makes charting depend on a network round trip is a regression, whatever else it improves.

## What this is

Knuckleball (knuckleballonline.com) is a bullpen and live-game tracking app for baseball and softball pitching coaches and pitchers: two-tap pitch charting on a 5×5 zone grid (target vs. actual; `GRID_SIZE = 5` -- the U2 7×7 grid was specified but never shipped), pitch types, velocity, heat maps, one accuracy percentage (exact + relative-accuracy hits, U14), trend charts, and an emailed link to a frozen HTML session report. Charting typically happens on an **iPhone/iPad, often with no wifi** — never assume network availability in the tracker flow.

**Operator context that changes how you work:** the owner (Joel) is a solo, part-time developer, newer to the terminal, on a Mac. Prefer copy-paste one-liners, explain what commands do, and never assume a CI system, a second environment, or another human reviewer exists unless DEPLOY.md says so. Current scale: 1–3 teams. Bias every decision toward simple and operable over scalable.

## Architecture

- **Frontend:** static HTML/CSS/vanilla JS, hosted on GitHub Pages, DNS via Cloudflare. No framework, no build step, no bundler. Keep it that way — do not introduce npm, React, TypeScript, or a build pipeline without explicit approval.
- **Backend:** Supabase — Postgres with RLS, Auth (email), Edge Functions (Deno). Project ref: `fkgccjhuimkkbupbanxp`.

## RLS rules (the schema itself: `docs/claude/backend.md`)

RLS rules of engagement:

1. Never write or alter a policy without first dumping the current policies (`select * from pg_policies where schemaname='public'`).
2. Every schema/policy change is a migration file in `supabase/migrations/` — never a dashboard-only edit.
3. Policies on `teams` and `pitcher_teams` must never reference each other in a way that can recurse — this exact pair caused a production 42P17 infinite-recursion outage. The live fix is two `SECURITY DEFINER` helper functions, `public.is_team_coach(check_team_id)` and `public.is_team_member(check_team_id)`: any policy needing a cross-table team check goes through these helpers, never a direct subquery.
4. Test policy changes with three personas: coach, rostered pitcher, and (once they exist) solo pitcher.

## Deploy and environments

- Frontend: git push to the GitHub Pages branch. Rollback = `git revert` + push.
- Edge Functions: `supabase functions deploy <name>`. Rollback = check out last good version of the function directory, redeploy.
- Migrations and the full procedure: follow `DEPLOY.md`. Staging (`knuckleball-staging`, a second Supabase project, same org as production) gets every change first; production schema changes only after a fresh backup (`BACKUPS.md`).
- Auth config landmine: Supabase **Site URL / redirect URLs** were once left at `localhost:3000`, breaking every email link. Any auth-flow change: verify these settings.

## Who ships to production

Only Joel ships to production. Jordan Thayer (operations) has access to
both Supabase projects and the repo, but production changes are Joel's alone.

"Shipping to production" means any of:
- pushing or merging to `main` (GitHub Pages deploys the live site from it);
- applying a migration to the production project (fkgccjhuimkkbupbanxp);
- deploying an Edge Function to production;
- changing production Auth settings, secrets, storage policies, or RLS
  in the dashboard;
- deleting or editing production data.

Jordan, and any Claude Code session he runs, works on staging and on
branches, and opens pull requests for Joel to merge. Reading production
(queries, logs, dashboards) is fine for both.

Before any production action, a Claude Code session confirms who is
operating it (`git config user.name` / `user.email`, and ask if unclear).
If it isn't Joel, stop and say the change needs Joel. No exceptions for
"small" or docs-only changes to `main`.

Joel's git identity is `Nathan <joelhauserman@gmail.com>`.

## GitHub is the source of truth (Joel, Oct 3 2026)
- Packets and plan files come only from GitHub (github.com/nathanjoel22/knuckleball).
  Before starting any packet, pull from GitHub and work only from what GitHub has.
- Never use files from elsewhere on this Mac (Downloads, Desktop, etc.) as inputs.
- If a file Joel says he uploaded isn't on GitHub, stop and tell him. Don't work
  around it.
- Every pre-push check finishes before the push. If a check flags anything, stop
  and tell Joel before pushing.

## Secrets

Function secrets live in Supabase (`supabase secrets list`): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `INVITE_REDIRECT_URL`, `RESEND_API_KEY`, `REPORT_FROM_EMAIL`, `VERIFY_FROM_EMAIL`, `VERIFY_REDIRECT_URL`, and since H1 `RESEND_DAILY_QUOTA` (the Resend plan's daily quota) and `ALERT_EMAIL` (Joel, for the circuit-breaker alert), since A1 `A1_CRON_SECRET` (the daily deletion run's shared secret, also in Vault as `a1_cron_secret`), and since U12 `OPERATOR_EMAILS` (`nate@knuckleballonline.com` on both projects -- Joel's dedicated operator login; the only login `rerender-reports` accepts). Historical note: a static `REPORT_API_KEY` once shipped in a public `report-config.js` — that pattern (any secret in a frontend file) is banned; if you ever find one, treat it as a live incident and flag it. The service-role key must never appear outside Edge Function env vars. The anon key is public by design; RLS is the actual security boundary.

## Known landmines

1. **RLS recursion** (see above) — the pair `teams` ↔ `pitcher_teams`.
2. **Missing foreign keys** once broke coach roster display (PostgREST embedding needs real FKs). When adding tables/columns, add the FKs.
3. **Profile-creation timing:** the profile row is created after email confirmation, with delay. Never assume a profile exists immediately after signup; handle its absence.
4. **Palette sync:** the pitch-type color palettes (one per sport) live in three places: the tracker page (`SPORTS[sport].palette`), `send-session-report/helpers.ts` (`SPORT_PALETTE_HEX`; `TYPE_PALETTE_HEX` is the baseball list) and `css/tokens.css` (`--pitch-1..8`, per sport). They must match exactly, in order -- change all three together; `.githooks/pre-push` refuses a push where they differ (D2, Oct 13 2026). Current values (D2; softball 6-8 darkened by Joel for readable chip labels): baseball `#FFB81C #22B573 #FF6B35 #E63946 #3D8BFF #B15CFF #F2E14C #00B8C4`, softball `#FF4F9A #2F9BFF #7A3FB8 #FF9F1C #00A99D #7A53FF #CD4730 #6C7684`. The report's own theme colors (`REPORT_VARS` in `helpers.ts`) follow `css/tokens.css` by hand.
5. **Client-computed reports:** the underlying pitches/history in the report payload are still client-supplied, not recomputed authoritatively from the database — accepted limitation, don't "fix" it in passing. This changed as of U4b in one way: the RENDERED report itself is now stored (`sessions.report_path`, the frozen file in the `reports` bucket) and deliberately never regenerated once set — every resend reuses the exact same file, so a later payload drift (e.g. new history) can't silently change a report someone already has the link to. The one exception so far is U12's Cairn re-render (Oct 6 2026, 23 reports, originals in `reports-archive/2026-10-06/` with a manifest); `from_rows.ts` can rebuild a report from stored rows, but nothing calls it except the operator-only `rerender-reports` -- re-render nothing else without Joel's explicit decision.
6. **Supabase default auth SMTP has tiny rate limits.** Bulk invites can silently fail mid-batch unless custom SMTP is configured (task P1-04 / SETUP.md). Production has custom SMTP (Resend, 50/hour); staging still uses the built-in sender at a fixed 2/hour, so bulk invites can't be tested on staging. Auth rate limits on both projects (Oct 5 2026): sign-ups and sign-ins 30 per 5 minutes per IP (Joel kept it; raise to ~100 if a team onboarding on one Wi-Fi hits it), token refreshes 150, token verifications 30. Change these only in the dashboard, never `supabase config push`.
7. **Free-tier Supabase projects pause when inactive** — relevant off-season. Check project status before diagnosing "the database is down".
8. **Offline is the normal case** for the tracker page: in-progress sessions autosave to localStorage, completed sessions queue and sync (tasks P0-03/P1-01). Never add code to the charting/save path that requires a network round-trip to keep charting. Data persistence and app availability are two separate problems — localStorage keeps the pitches, the service worker (P0-06) keeps the app openable offline. A field test proved that without the second, the first is unreachable.
9. **Service worker caching cuts both ways.** Once sw.js ships, a stale cached shell can strand users on old JS — exactly the failure mode that made a fixed bug look unfixed during P0-01. Always version the cache name, clean old caches on activate, and verify a deployed change actually appears after two reloads.

## Coding conventions

Vanilla JS in single-file pages; small shared JS only if a `js/` directory already exists. Match the existing style of the file you're editing. Edge Functions: Deno, esm.sh imports, the CORS-headers pattern already in the existing functions. Errors returned as JSON `{ error: string }` with proper status codes. No new dependencies without approval.

## Rules of engagement

**Never, without asking first:** run destructive SQL against production (or any UPDATE/DELETE without a WHERE you've shown); change RLS policies; change auth flows (signup, invite, reset); add dependencies, frameworks, or build steps; touch billing/legal text; delete user data; commit anything resembling a secret; deploy schema changes that haven't run on staging.

**Always:** work from a task packet when one exists, and respect its Out-of-scope and Escalate-if clauses; make schema changes as migration files; prefer the smallest change that passes acceptance; leave the codebase style-consistent.

**Release log (Joel, Oct 10 2026).** After every packet -- or request shipped without one -- reaches staging or production, add an entry at the TOP of `STATUS.md`: date, packet ID, staging or production, branch, commit, cache version, what was built, what deviated from the packet, open items. CLAUDE.md stays the rules; STATUS.md is the log. **At the start of every session, read the top of `STATUS.md`** (at least the newest few entries and "Standing open items") before starting work: it says what's on staging vs production right now and what's still open.

**Definition of done:** a task is complete only when every numbered acceptance check in its packet has been executed and the evidence (command output, query result, or click-path result) is shown. "It should work" is not done. If an acceptance check can't be run, say so explicitly — do not claim completion. If reality contradicts the packet (a file isn't where it says, the schema differs), stop and report the discrepancy instead of improvising around it.
