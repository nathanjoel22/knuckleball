# CLAUDE.md — Knuckleball

Standing context for every Claude session working in this repo. Read fully before touching anything.

## Design principle (binding)

**Charting never requires the network. Only syncing and sending reports do.** A team must be able to open Knuckleball anywhere — including with no internet — and chart a complete bullpen. Login is the single honest exception, and only on first use: the standard is **log in once, then chart anywhere forever**. A token refresh that fails purely for lack of network must never bounce a charter to a login screen or block charting; genuine auth failures while online still must. Reports are never generated from an unsynced session. Any change that makes charting depend on a network round trip is a regression, whatever else it improves.

## Roster & visibility model (decided by Joel, Aug 28 2026 — built as Track R, Phase 2)

Data follows the player. Sessions belong to the pitcher permanently; a team's view of a pitcher exists only through a current pitcher_teams membership row. Specifics, all decided — do not relitigate:
- Adding an existing account to a roster ALWAYS requires the player's in-app acceptance (pending invite shown at login). No auto-add, no acceptance email.
- Players can be on multiple rosters. Every pen is filed at session start: one of the pitcher's teams, or "independent" (NULL team_id, post-P2-01).
- A coach sees FULL detail only for sessions thrown for their team by currently-rostered pitchers, from each pitcher's join date. All other pens by rostered pitchers (other teams, independent) appear as summary-only workload entries: date, pitch count, team label — never the full report. Summary exposure goes through a scoped view/RPC, not RLS alone.
- Membership ending — player leaves or coach removes, both with explicit confirmation — instantly removes the team's ENTIRE view of that player, both directions, automatically. The player keeps every session regardless of who recorded it. Re-joining restores nothing retroactively.
- Saved sessions are IMMUTABLE. Pitches are freely editable during a session (in-session correction on any row of the recent-pitches log). The moment "End session & save" is pressed — from a pitcher account or a team account — the pitch data is final for everyone, including coaches. Never build a post-hoc pitch editor; one was built and deliberately reverted on Aug 28 2026. Self-reported performance data that can be quietly revised after the fact is not trustworthy, and this data informs development and recruiting conversations.
- Deletion remains available: the pitcher may delete their own sessions, the coach may delete their team's. Every deletion leaves a visible tombstone in history showing the date, the number of pitches thrown, that it was deleted, and which account deleted it (player or team). Deleted sessions are excluded from all stats, trends, and reports.
Until Track R ships: inviting an already-registered email must fail honestly ("existing account — coming soon"), never auto-add and never half-succeed silently.

## Charting surface decisions (Joel, Aug 29 2026 — Track U)
- The grid is drawn from the CATCHER'S perspective. Stored pitch coordinates are always physical; the left-handed-batter view mirrors DISPLAY NUMBERING ONLY, never stored data.
- Grid v2 (U2) is 7×7 with the strike zone at rows/cols 2-4. Boxes are numbered 1-49 per a Joel-approved diagram committed to the repo — that diagram is the canonical numbering spec, and the mapping lives in ONE shared module used by both charting and report rendering (never duplicated).
- Legacy 5×5 sessions are never migrated or touched; they render through the legacy path permanently.
- Batter side (RHB/LHB) is stored on every pitch charted after U2; it is a simulated-batter toggle, distinct from profiles.throws (the pitcher's hand).
- Reports are HTML pages at unguessable URLs, content frozen at save time; PDF generation is retired with U4. Anyone with the link can view — that is the chosen trust model.

**Zone numbering protocol (D8, Sept 9 2026).** Boxes 1/4/7 are ALWAYS the inside
column, 2/5/8 middle, 3/6/9 outside — in every charting perspective and for either
batter side. Rows never flip. A zone number is a display label computed at render
time from the stored catcher-frame coordinate plus batter side (`zoneNumberFor`),
never stored and never a second copy of the mapping. Labels therefore mirror on
screen with perspective (and, after U2, batter side) so the low column is always on
the batter's side; the "Inside" accuracy highlight must always sit under the 1/4/7
labels. Reports and history always render the catcher's view, labeled as such.
Stored coordinates stay catcher-frame, always — this protocol changes nothing about
storage.

## Sports: baseball and softball (Track S — S1 + S2, Joel, Oct 1 2026)

- Every profile, team and session has a `sport` ('baseball' | 'softball'), derived by SECURITY DEFINER triggers (`20261001000000_s1_sport.sql`). Cross-sport team joins are refused; a team's or session's sport never changes; a profile's sport can't change once it has a team or sessions. Sign-in checks the account's sport and role; every login/sign-up link carries `?sport=`. The landing page always opens on "Which sport?".
- Client: `SPORTS` config in the tracker (catalog, palette, velo range, `hasDelivery`, `hasTimeToPlate`, `hasLeaderboard`, `hasLiveGame`) + `applySport()`; theme via `html[data-sport]` CSS variables set before paint. Softball: blue/pink theme, no leaderboard, no Set/Windup, no time to home.
- **Softball Live Game (S2):** same as baseball except no delivery (`pitches.delivery` null) and no ⏱. Own fastpitch field (`GG_FIELD_SVG_SOFTBALL`: all-dirt infield, pitcher's circle low in column 3 / row 4, bases spaced so none sits on a grid line). Softball's + More has **Illegal pitch** instead of Balk: runners up one base AND a ball added (ball 4 = walk), saved as the existing `balk` + `auto_ball` game_events rows (flagged `illegalPitch`/`illegalPitchBall` in the draft so the log shows one line and one Undo removes both) — no new event type.
- Reports: `SPORT_PALETTE_HEX` + `useSportPalette()` in `send-session-report/helpers.ts`; the softball theme swap (`themedCss`) is applied to the WHOLE report (CSS and drawn charts) for both pen and game reports. Baseball reports must stay byte-identical. Softball game at-bats show side only, no delivery.

## Session layouts (Joel, Oct 1 2026 — G1b-r5 / G1b-r6)

- **Phones (≤500px, `isPhoneWidth`, `phoneSessionMode`)**: one session header (‹ team · photo · name · #num · offline dot · 9-dot sheet with perspective / opponent / End session & save / Discard), Set-Windup as one flip button, swipeable grid-square pitch chips in their own colors, grid capped at 340px.
- **iPad portrait (501–860px)**: the stacked layout, deliberately unchanged (Joel chose "option B").
- **iPad landscape / laptop (>860px, `isWideSession`)**: two columns for pen and Live Game — left: perspective, pitch types (never more than two per row), delivery (pen: + batter, pitch counter beside the perspective chips); right: the grid, sized by `sizeWideGrid()` to fit the viewport (cap 560, min 44px cells, batter silhouette 80% of grid height with room on both sides so the grid never moves). Live Game: ⏱ bottom-left, Undo / New batter / New inning centered under the grid. Hints show on the grid's caption line. Rotating across 860px re-renders.
- Discard session sits beside End session & save on every non-phone width (same confirm and `discardActiveSession` as the phone sheet).
- Pitch labels display in capitals everywhere; stored names are unchanged.
- Live Game state: Set/Windup defaults from the bases, velocity "Reset", in-grid ADV Runners (SB / On Last Play) are live. The G1b-r4 tap redesign was deleted; Joel will bring a new Live Game packet.

## What this is

Knuckleball (knuckleballonline.com) is a bullpen and live-game tracking app for baseball and softball pitching coaches and pitchers: two-tap pitch charting on a 5×5 zone grid (target vs. actual), pitch types, velocity, heat maps, accuracy percentages (including a "relative accuracy" mode), trend charts, and an emailed link to a frozen HTML session report. Charting typically happens on an **iPhone/iPad, often with no wifi** — never assume network availability in the tracker flow.

**Operator context that changes how you work:** the owner (Joel) is a solo, part-time developer, newer to the terminal, on a Mac. Prefer copy-paste one-liners, explain what commands do, and never assume a CI system, a second environment, or another human reviewer exists unless DEPLOY.md says so. Current scale: 1–3 teams. Bias every decision toward simple and operable over scalable.

## Architecture

- **Frontend:** static HTML/CSS/vanilla JS, hosted on GitHub Pages, DNS via Cloudflare. No framework, no build step, no bundler. Keep it that way — do not introduce npm, React, TypeScript, or a build pipeline without explicit approval.
- **Backend:** Supabase — Postgres with RLS, Auth (email), Edge Functions (Deno). Project ref: `fkgccjhuimkkbupbanxp`.
- **Email:** Resend (report emails link to a frozen HTML report — see U4/U4b below; auth email SMTP per SETUP.md).
- **Edge Functions:** `supabase/functions/invite-pitcher/index.ts` (coach invites a pitcher — verifies the caller's JWT, checks team ownership under RLS, uses the admin client only for `inviteUserByEmail`) and `supabase/functions/send-session-report/index.ts` (U4/U4b, PDF retired — builds a self-contained HTML report from a client-supplied pitch payload, uploads it to the public `reports` storage bucket at an unguessable token filename, and emails a `report.html?r=<token>` link instead of an attachment; the admin/service-role client is used only for that one storage upload, never for reading `sessions` — that read/write goes through the caller's own RLS-scoped client. Gated on `is_pitcher_report_eligible` — verified email AND currently on a team, the latter a deliberate temporary restriction until solo pitcher accounts exist).

## Schema and RLS

Source of truth: `supabase/schema/schema.sql` (live production dump, 2026-08-25) + `supabase/schema/SCHEMA_NOTES.md`. As of P1-08, `supabase/migrations/` exists with a baseline migration generated from that dump, and the old stale hand-written `supabase/schema.sql` (which predated the RLS-recursion fix and the current pitches model) has been deleted.

The real tables (from the dump): `profiles` (incl. `contact_emails jsonb`), `teams` (`coach_id` → auth.users), `pitcher_teams` (`pitcher_id` → **profiles**, not auth.users — required for the PostgREST embeds the roster code uses; keep it that way), `invites`, `sessions` (`pitcher_id` → auth.users NOT NULL; `team_id` → teams, currently NOT NULL until the D3 migration in P2-01 makes it nullable; `logged_by` → auth.users — the person who charted, which may be a coach or teammate rather than the pitcher), `pitches` (`session_id` → sessions; `target_row/col` + `actual_row/col`; `accuracy_mode` with a check constraint matching the relative-accuracy modes).

There are 35 RLS policies (production; S3 session_notes: coaches add, author deletes, author/pitcher/current coaches read via `is_coach_of_session`; the report page reads notes through `get_report_notes(token)`). Since H1 nobody holds FOR ALL on sessions, pitches or game_events: see "Saved sessions and sync (H1)" below. Decision D3 is settled: sessions belong to the pitcher, team affiliation becomes optional (the `team_id` NOT NULL drop is P2-01).

**Profiles vs logins (S4 Stage A, Oct 2 2026).** A login (auth user) owns one or more profiles (`profiles.account_id`); its primary profile has `id = account_id` and holds email verification. Profiles no longer reference `auth.users`; `sessions.pitcher_id/logged_by/deleted_by`, `teams.coach_id` and `invites.invited_by` reference `profiles`. Every policy and function checks ownership with `is_my_profile(p)` (team helpers: "the caller owns a profile in that row"); functions acting as the caller take an optional profile id and otherwise use the login's only profile (`my_single_profile()`), refusing with `profile_required` when the login has several -- never `auth.uid()` as a profile id. "Add a sport" = `add_sport_profile(sport)`. Report eligibility reads verification through the profile's login. The app runs one ACTIVE profile at a time (`kb:activeProfile:<uid>`, per-profile offline snapshots `lastKnownContext:<uid>:<profile>`), switches in place without a reload, and sign-in never refuses for sport or role. Down migration: `supabase/rollback/20261002020000_s4a_profiles_down.sql`. RLS proof: `supabase/tests/s4_rls_matrix.sql` (identical before/after on staging).

**Parent accounts and players (S4 Stage B, Oct 2 2026).** A parent login has a primary profile with role `parent` (no sport; never charts, never joins a team) created by `ensure_account_setup('parent', name)` from `parent-signup.html`. Any login attested 'adult' can `add_player(name, sport, throws, consent)`: a managed pitcher profile (`account_id` = that login, `managed_by` = its primary profile, `guardian_consented_at` + `consent_via = 'parent_created'`, reports to the login's email via `contact_emails.pitcher`); no email, login or age is ever stored for a player. Players join teams through `join.html`'s "Join as:" picker (shown only to logins that are parents or manage players). Coaches see "Parent account" (`get_roster_verification.managed`). Parents, like coaches, can only attest 'adult'. Under 13 is possible ONLY as a parent-added player -- self-signup still has no under-13 answer. One-time notices in the tracker (the age box, "Who's charting?") share one overlay path in `render()`: dead-center over the app on the shaded navy backdrop, one at a time. Rollback: `supabase/rollback/20261002060000_s4b_players_down.sql`; acceptance: `supabase/tests/s4b_acceptance.sql`.

**Departed pitchers (G3, Joel, Oct 2 2026).** A session belongs to the team it was charted under (`sessions.team_id`, never changed after insert). Coaches read sessions — and their pitches, game_events and notes — by that team (`is_team_coach(team_id)`, `is_coach_of_session_team`), so they keep a pitcher's sessions from while he was on the team after he leaves; writing notes still needs him on the team now (`is_coach_of_session`). A new session can only be filed under a team the pitcher is on now, or one he left after the session started (trigger `sessions_g3_team_check`, reading `pitcher_team_departures`, which a trigger fills whenever a `pitcher_teams` row is deleted). The pitcher always sees all his own sessions. Departed pitchers' old sessions are reachable by SQL only (no app screen yet, Joel's call).

**Live Game events and levels (G3).** `game_events` also stores `seq` and the count/inning before each event. Event types now include `illegal_pitch` (softball: ADV = with runner_advances, no ADV = without; always followed by its `auto_ball`) and `tiebreak_runner` (extra innings, "Start with runner on 2B?"). Game reports and `compute_game_summary` count IBB / auto-ball-four / auto-strike-three as BB/K and list them under "Other events"; pitch stats never include them. `teams.level` (baseball little_league / high_school / college; softball little_league / high_school_up, CHECK-tied to sport, head coach sets it) decides the first extra inning: 7 / 8 / 10 and 7 / 8.

**Migration history.** Every schema change up to P1-08 was applied to production by hand; `supabase/migrations/20260826082320_baseline.sql` is the snapshot of that state and the first real migration this repo has. Production has no `supabase_migrations` history table yet, so a one-time `supabase migration repair --status applied` is required before the first `db push` (see DEPLOY.md). Keep regenerating the dump in `supabase/schema/schema.sql` after any approved schema change — it stays the human-readable source of truth.

**Report gate invariant (P1-10, Oct 2 2026).** A report can be generated or sent only when: the pitcher's LOGIN is email-verified AND the pitcher is on a team AND the calling coach is verified (Amendment 11) AND the pitcher's login is attested 'adult' OR has guardian approval (13-17) AND, for a parent-added player, the player's own consent stamp is set (S4 B). Existing logins that haven't answered the one-time age box get NO reports until they answer (Joel, option a). The age bracket, terms version and guardian state live on the login's PRIMARY profile; `guardian_email` and `guardian_consent_token` are never client-readable; guardian emails go only to the stored address, once per 10 minutes (`claim_guardian_send`). The one-time box is decided only on the online load -- it never appears offline. Policy pages (`privacy.html`, `terms.html`, Version 2026-10-03, adding parent accounts and under-13s) were approved by Joel on Oct 2 2026; any text change needs his re-approval in the commit message. Fonts and supabase-js are self-hosted under `vendor/` -- pages load nothing from third-party hosts; keep it that way (the privacy policy says so).

**Change Email (Joel signed off as an auth-flow change, Oct 2 2026).** The address lives ONLY in `auth.users` (no `profiles.email`). The client never calls `supabase.auth.updateUser({ email })`. `request-email-change` (Edge Function, caller's JWT) calls `begin_email_change()` (records the request in hidden profile columns, cancels any outstanding verify link, 1 per 10 minutes), has Supabase GENERATE (not send) the email-change link with the admin client -- its only admin use -- and sends ONE Knuckleball email via Resend to the new address. Landing (`bullpen-tracker.html?email_change=1`) runs `confirm_email_change()`: the login's `auth.users` email must equal the requested address with nothing pending; it sets `email_verified_at` and moves `contact_emails.pitcher` on every profile the login owns. The account stays verified on its old address while a change is pending. `verify_email` links are bound to the address they were sent to (`email_verify_sent_to`). Only `verify_email` and `confirm_email_change` set `email_verified_at`; neither reads `email_confirmed_at` (Amendment 9). Requires, in BOTH projects' Auth settings: "Secure email change" OFF, and the tracker's `?email_change=1` URL in the redirect allow-list. Rollback: `supabase/rollback/20261002070000_email_change_down.sql`.

**Staging report links.** `send-session-report` reads an optional `REPORT_SITE_ORIGIN` secret for the emailed link: staging has `http://localhost:8080` (opens the local staging site, which reads staging storage); production has NONE, so it links to https://knuckleballonline.com. Never set it on production.

**Saved sessions and sync (H1, Joel, Oct 3 2026; absorbs SC2).**
- **Nothing reaches the server until "End session & save"** (Joel accepts this). In-session edits and Undo are device-only; every session row is saved (`ended_at` set) when it's written.
- **One atomic call per saved session:** the outbox sends `sync_session(p_session, p_pitches, p_events)`, which checks entitlement itself (the pitcher's own profile, or a coach of the session's team, charting as one of their own profiles), inserts session + pitches + events (the sport and team triggers still fire) and sets `sessions.sealed_at` -- all or nothing. An id that's already saved and sealed returns `already_saved` and writes nothing, never a merge; the app clears the item and tells the user. Any other refusal keeps the item queued with its reason and retries; nothing is ever discarded. Never write sessions/pitches/game_events directly from the app.
- **The lock (every caller, server functions included):** `sessions_h1_lock` -- a saved session can't be un-saved, re-timed or change pitcher/team/kind/sport/start/game fields; the tombstone fields are writable only by the server's own functions (`delete_session`); `report_path`/`report_generated_at` stay writable. `h1_child_lock` -- a saved session's pitches/events can't change (an identical re-send is skipped; the `after_pitch_id` FK may still clear itself), and nothing can be added once sealed.
- **Deleting is only `delete_session()`** (the pitcher for own sessions, the team's HEAD coach; assistants refused), which writes the tombstone. No client DELETE rule on any of the three tables.
- **Grace path (opened on production Oct 5 2026 with v145; close no earlier than Oct 19 2026):** devices on v144 and earlier still sync through the old direct path -- INSERT (and an identical upsert re-send) into saved-but-unsealed sessions only, via the six "H1 grace" policies. Close it with a follow-up migration (drop the grace policies -> 29 policies, seal every remaining session) once production shows no old-path writes for a week, at least 14 days after the H1 deploy; show Joel any unsaved/unsealed leftovers first.

**Sending limits (H1 Part 2).** Every function that sends email or writes a report file calls `takeRateLimit()` (`supabase/functions/_shared/rate_limit.ts`) before sending: per-user, per-recipient and a daily circuit breaker at 90% of `RESEND_DAILY_QUOTA` (Resend free plan: 100/day, 3,000/month), with one alert email to `ALERT_EMAIL` per day when it trips. Limits live in `public.rate_limit_config` (tune there, no deploy); events in `public.rate_limit_events` (pruned after 7 days). Neither table nor `rate_limit_take()` is reachable by clients -- the functions call it with the service role, passing the caller's verified id; that RPC is the service role's only use in those functions besides the existing report upload and `generateLink`. Over a limit -> HTTP 429 `{ error: <human message>, code: 'rate_limited' }`, shown in the UI as-is. Generating or viewing a report without emailing never counts against email limits. Not limited, on purpose: the anon token lookups (long random tokens). Supabase Auth's own limits are set by Joel in the dashboard, never `supabase config push`. CAPTCHA (Turnstile) is the recorded next step if signups are abused.

**Report recipients (H1 Part 3b).** `send-session-report` emails only addresses saved in the player's report contacts (`profiles.contact_emails`, edited only by the owning login -- the pitcher, or the parent for a parent-created player). Anything else -> 400, nothing sent. Coaches send to those contacts and can't add others.

**Column grants (security fix, Oct 2 2026).** `profiles` and `teams` have NO table-level SELECT for clients -- only an explicit column grant. Secret columns (`teams.invite_token`, `teams.coach_invite_token`, `profiles.email_verify_token`, and P1-10's guardian token/email) are never granted; they're reached only through their SECURITY DEFINER functions. A new column on either table is unreadable by clients until a migration grants it (and, for profiles, it's added to the tracker's `PROFILE_COLS`). Never `select('*')` on these tables.

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

Function secrets live in Supabase (`supabase secrets list`): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `INVITE_REDIRECT_URL`, `RESEND_API_KEY`, `REPORT_FROM_EMAIL`, `VERIFY_FROM_EMAIL`, `VERIFY_REDIRECT_URL`, and since H1 `RESEND_DAILY_QUOTA` (the Resend plan's daily quota) and `ALERT_EMAIL` (Joel, for the circuit-breaker alert). Historical note: a static `REPORT_API_KEY` once shipped in a public `report-config.js` — that pattern (any secret in a frontend file) is banned; if you ever find one, treat it as a live incident and flag it. The service-role key must never appear outside Edge Function env vars. The anon key is public by design; RLS is the actual security boundary.

## Known landmines

1. **RLS recursion** (see above) — the pair `teams` ↔ `pitcher_teams`.
2. **Missing foreign keys** once broke coach roster display (PostgREST embedding needs real FKs). When adding tables/columns, add the FKs.
3. **Profile-creation timing:** the profile row is created after email confirmation, with delay. Never assume a profile exists immediately after signup; handle its absence.
4. **Palette sync:** the pitch-type color palettes (one per sport) are duplicated in the tracker page (`SPORTS[sport].palette`) and in `send-session-report/helpers.ts` (`SPORT_PALETTE_HEX`; `TYPE_PALETTE_HEX` is the baseball list) and must match exactly, in order. Change both or neither.
5. **Client-computed reports:** the underlying pitches/history in the report payload are still client-supplied, not recomputed authoritatively from the database — accepted limitation, don't "fix" it in passing. This changed as of U4b in one way: the RENDERED report itself is now stored (`sessions.report_path`, the frozen file in the `reports` bucket) and deliberately never regenerated once set — every resend reuses the exact same file, so a later payload drift (e.g. new history) can't silently change a report someone already has the link to.
6. **Supabase default auth SMTP has tiny rate limits.** Bulk invites can silently fail mid-batch unless custom SMTP is configured (task P1-04 / SETUP.md).
7. **Free-tier Supabase projects pause when inactive** — relevant off-season. Check project status before diagnosing "the database is down".
8. **Offline is the normal case** for the tracker page: in-progress sessions autosave to localStorage, completed sessions queue and sync (tasks P0-03/P1-01). Never add code to the charting/save path that requires a network round-trip to keep charting. Data persistence and app availability are two separate problems — localStorage keeps the pitches, the service worker (P0-06) keeps the app openable offline. A field test proved that without the second, the first is unreachable.
9. **Service worker caching cuts both ways.** Once sw.js ships, a stale cached shell can strand users on old JS — exactly the failure mode that made a fixed bug look unfixed during P0-01. Always version the cache name, clean old caches on activate, and verify a deployed change actually appears after two reloads.

## Coding conventions

Vanilla JS in single-file pages; small shared JS only if a `js/` directory already exists. Match the existing style of the file you're editing. Edge Functions: Deno, esm.sh imports, the CORS-headers pattern already in both functions. Errors returned as JSON `{ error: string }` with proper status codes. No new dependencies without approval.

## Rules of engagement

**Never, without asking first:** run destructive SQL against production (or any UPDATE/DELETE without a WHERE you've shown); change RLS policies; change auth flows (signup, invite, reset); add dependencies, frameworks, or build steps; touch billing/legal text; delete user data; commit anything resembling a secret; deploy schema changes that haven't run on staging.

**Always:** work from a task packet when one exists, and respect its Out-of-scope and Escalate-if clauses; make schema changes as migration files; prefer the smallest change that passes acceptance; leave the codebase style-consistent.

**Definition of done:** a task is complete only when every numbered acceptance check in its packet has been executed and the evidence (command output, query result, or click-path result) is shown. "It should work" is not done. If an acceptance check can't be run, say so explicitly — do not claim completion. If reality contradicts the packet (a file isn't where it says, the schema differs), stop and report the discrepancy instead of improvising around it.
