# CLAUDE.md — Knuckleball

Standing context for every Claude session working in this repo. Read fully before touching anything.

## What this is

Knuckleball (knuckleballonline.com) is a bullpen session tracking app for pitching coaches and pitchers: two-tap pitch charting on a 5×5 zone grid (target vs. actual), pitch types, velocity, heat maps, accuracy percentages (including a "relative accuracy" mode), trend charts, and an emailed PDF session report. Charting typically happens on an **iPhone/iPad, often with no wifi** — never assume network availability in the tracker flow.

**Operator context that changes how you work:** the owner (Joel) is a solo, part-time developer, newer to the terminal, on a Mac. Prefer copy-paste one-liners, explain what commands do, and never assume a CI system, a second environment, or another human reviewer exists unless DEPLOY.md says so. Current scale: 1–3 teams. Bias every decision toward simple and operable over scalable.

## Architecture

- **Frontend:** static HTML/CSS/vanilla JS, hosted on GitHub Pages, DNS via Cloudflare. No framework, no build step, no bundler. Keep it that way — do not introduce npm, React, TypeScript, or a build pipeline without explicit approval.
- **Backend:** Supabase — Postgres with RLS, Auth (email), Edge Functions (Deno). Project ref: `fkgccjhuimkkbupbanxp`.
- **Email:** Resend (report emails with PDF attachments; auth email SMTP per SETUP.md).
- **Edge Functions:** `supabase/functions/invite-pitcher/index.ts` (coach invites a pitcher — verifies the caller's JWT, checks team ownership under RLS, uses the admin client only for `inviteUserByEmail`) and `supabase/functions/send-session-report/index.ts` (builds the PDF with pdf-lib from a client-supplied payload and sends via Resend; it does not read the database).

## Schema and RLS

Source of truth: `supabase/schema/schema.sql` (live production dump, 2026-08-25) + `supabase/schema/SCHEMA_NOTES.md`. As of P1-08, `supabase/migrations/` exists with a baseline migration generated from that dump, and the old stale hand-written `supabase/schema.sql` (which predated the RLS-recursion fix and the current pitches model) has been deleted.

The real tables (from the dump): `profiles` (incl. `contact_emails jsonb`), `teams` (`coach_id` → auth.users), `pitcher_teams` (`pitcher_id` → **profiles**, not auth.users — required for the PostgREST embeds the roster code uses; keep it that way), `invites`, `sessions` (`pitcher_id` → auth.users NOT NULL; `team_id` → teams, currently NOT NULL until the D3 migration in P2-01 makes it nullable; `logged_by` → auth.users — the person who charted, which may be a coach or teammate rather than the pitcher), `pitches` (`session_id` → sessions; `target_row/col` + `actual_row/col`; `accuracy_mode` with a check constraint matching the relative-accuracy modes).

There are 19 RLS policies. Coaches hold **FOR ALL** (not just SELECT) on their team's sessions and pitches — they can chart and edit on behalf of pitchers; pitchers manage their own rows via `pitcher_id` only, with no team dependency. Decision D3 is settled: sessions belong to the pitcher, team affiliation becomes optional (the `team_id` NOT NULL drop is P2-01).

**There is no migration chain.** `supabase/migrations/` has never existed; all live schema state was applied by hand. The first migration created in this repo must be a baseline of current production (part of P1-08). Until that exists, the dump is the only truth — regenerate it after any approved schema change.

RLS rules of engagement:

1. Never write or alter a policy without first dumping the current policies (`select * from pg_policies where schemaname='public'`).
2. Every schema/policy change is a migration file in `supabase/migrations/` — never a dashboard-only edit.
3. Policies on `teams` and `pitcher_teams` must never reference each other in a way that can recurse — this exact pair caused a production 42P17 infinite-recursion outage. The live fix is two `SECURITY DEFINER` helper functions, `public.is_team_coach(check_team_id)` and `public.is_team_member(check_team_id)`: any policy needing a cross-table team check goes through these helpers, never a direct subquery.
4. Test policy changes with three personas: coach, rostered pitcher, and (once they exist) solo pitcher.

## Deploy and environments

- Frontend: git push to the GitHub Pages branch. Rollback = `git revert` + push.
- Edge Functions: `supabase functions deploy <name>`. Rollback = check out last good version of the function directory, redeploy.
- Migrations and the full procedure: follow `DEPLOY.md` (task P1-08). If it exists, staging (a second Supabase project) gets every change first; production schema changes only after a fresh backup (`BACKUPS.md`).
- Auth config landmine: Supabase **Site URL / redirect URLs** were once left at `localhost:3000`, breaking every email link. Any auth-flow change: verify these settings.

## Secrets

Function secrets live in Supabase (`supabase secrets list`): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `INVITE_REDIRECT_URL`, `RESEND_API_KEY`, `REPORT_FROM_EMAIL`. Historical note: a static `REPORT_API_KEY` once shipped in a public `report-config.js` — that pattern (any secret in a frontend file) is banned; if you ever find one, treat it as a live incident and flag it. The service-role key must never appear outside Edge Function env vars. The anon key is public by design; RLS is the actual security boundary.

## Known landmines

1. **RLS recursion** (see above) — the pair `teams` ↔ `pitcher_teams`.
2. **Missing foreign keys** once broke coach roster display (PostgREST embedding needs real FKs). When adding tables/columns, add the FKs.
3. **Profile-creation timing:** the profile row is created after email confirmation, with delay. Never assume a profile exists immediately after signup; handle its absence.
4. **`TYPE_PALETTE` sync:** the pitch-type color palette is duplicated in the tracker page and in `send-session-report/index.ts` (`TYPE_PALETTE_HEX`) and must match exactly, in order. Change both or neither.
5. **Client-computed reports:** the report payload (pitches, stats, history) is computed client-side and never stored server-side; a report cannot be regenerated later. Accepted limitation — don't "fix" it in passing.
6. **Supabase default auth SMTP has tiny rate limits.** Bulk invites can silently fail mid-batch unless custom SMTP is configured (task P1-04 / SETUP.md).
7. **Free-tier Supabase projects pause when inactive** — relevant off-season. Check project status before diagnosing "the database is down".
8. **Offline is the normal case** for the tracker page: in-progress sessions autosave to localStorage, completed sessions queue and sync (tasks P0-03/P1-01). Never add code to the charting/save path that requires a network round-trip to keep charting.

## Coding conventions

Vanilla JS in single-file pages; small shared JS only if a `js/` directory already exists. Match the existing style of the file you're editing. Edge Functions: Deno, esm.sh imports, the CORS-headers pattern already in both functions. Errors returned as JSON `{ error: string }` with proper status codes. No new dependencies without approval.

## Rules of engagement

**Never, without asking first:** run destructive SQL against production (or any UPDATE/DELETE without a WHERE you've shown); change RLS policies; change auth flows (signup, invite, reset); add dependencies, frameworks, or build steps; touch billing/legal text; delete user data; commit anything resembling a secret; deploy schema changes that haven't run on staging (once staging exists).

**Always:** work from a task packet when one exists, and respect its Out-of-scope and Escalate-if clauses; make schema changes as migration files; prefer the smallest change that passes acceptance; leave the codebase style-consistent.

**Definition of done:** a task is complete only when every numbered acceptance check in its packet has been executed and the evidence (command output, query result, or click-path result) is shown. "It should work" is not done. If an acceptance check can't be run, say so explicitly — do not claim completion. If reality contradicts the packet (a file isn't where it says, the schema differs), stop and report the discrepancy instead of improvising around it.
