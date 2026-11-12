# DS1 — Jordan's demo facility (seeded accounts and sessions), Nov 11, 2026

> **Copy for the public repo (Nov 11, 2026, decision D7 in `plans/ds1-preconditions.md`).** Joel's packet, word for word,
> except that the people's names and addresses, the facility name and the shared password are replaced by
> placeholders. They live only in the git-ignored `tools/seed-demo/config.local.json`; the verbatim packet stays on
> Joel's Mac as `plans/ds1-jordan-demo-seed.verbatim.md` (git-ignored).

**Joel, Nov 11: "I need to expedite the process."** Jordan now has App Store Connect access and the TestFlight build is on its way; he needs something real to open. This packet creates a complete facility for him on production — one facility manager, two pitching coaches, ten pitchers, and 10–15 sessions per pitcher spread from July 1, 2026 to the run date — all with the password (the shared demo password). Everything lands in Jordan's own Gmail inbox because the addresses are plus-aliases of one account.

## What Joel is overriding, and what he is not

Overridden for this packet only, because it is a demo facility that Joel will tear down or rotate later:

1. **Known shared password on test accounts.** Thirteen accounts get (the shared demo password). They are set through the normal sign-up call (`supabase.auth.signUp` with the anon key), never the Admin API.
2. **Sessions written by a script, not by charting.** Once written they are immutable like any other saved session; the script never updates or deletes a session except in `--teardown`.
3. **Backdated sessions.** Dates run back to July 1, 2026 so Trends and the season views have something to show.
4. **Demo data on production.** It is Jordan's facility, named after him, and it is the facility the pilot can be shown.

Still in force, no exceptions: the service-role key stays inside Edge Function env vars (the script uses the public anon key and signs in as each account, so RLS, triggers and the same RPCs the pages use all run normally); **only Joel runs the script against production**, staging first, with a fresh prod backup taken before the prod run; **no schema or RLS change** — if the data model refuses something, the fallback is a SQL file Joel runs in the Supabase SQL editor, not a policy edit; no email leaves the system because of this seed (no session reports, no invites; Resend's daily count must not move); no email address or password is committed — the site repo is public until the Cloudflare move finishes, so names, addresses and the password live in a git-ignored local file; nothing is pushed to main and no PR is merged by Claude Code.

## The people

| Role | Sign-in | Display name | Notes |
|---|---|---|---|
| Facility manager | (Jordan's own address) | (Jordan's name) | Owns the facility organization and both `kind='facility'` teams; `organizations.manager_login` |
| Coach 1 | (alias +coach1) | (Coach 1's name) | Own coach group with its own join token; pitchers 1–5 |
| Coach 2 | (alias +coach2) | (Coach 2's name) | Own coach group; pitchers 6–10 |
| Pitcher 1 | (alias +pitcher1) | (Pitcher 1's name) | RHP, 20, FB/SL/CH |
| Pitcher 2 | (alias +pitcher2) | (Pitcher 2's name) | LHP, 19, FB/CB/CH |
| Pitcher 3 | (alias +pitcher3) | (Pitcher 3's name) | RHP, 21, FB/CT/SL |
| Pitcher 4 | (alias +pitcher4) | (Pitcher 4's name) | RHP, 18, FB/CH |
| Pitcher 5 | (alias +pitcher5) | (Pitcher 5's name) | RHP, 22, FB/SL/CB/CH |
| Pitcher 6 | (alias +pitcher6) | (Pitcher 6's name) | LHP, 20, FB/SL/CH |
| Pitcher 7 | (alias +pitcher7) | (Pitcher 7's name) | RHP, 19, FB/SPL/SL |
| Pitcher 8 | (alias +pitcher8) | (Pitcher 8's name) | RHP, 21, FB/CB |
| Pitcher 9 | (alias +pitcher9) | (Pitcher 9's name) | LHP, 18, FB/CH/CB |
| Pitcher 10 | (alias +pitcher10) | (Pitcher 10's name) | RHP, 20, FB/CT/SL/CH |

Facility name **(the facility name)**, sport baseball, no "(demo)" suffix — Jordan may show it to real people. All pitchers are adults (18–22, random birthdays that make them so), so every one of them comes in through the adult-pitcher link, with age attestation and S4 consent answered the way a real adult would; no parent flow and no 13–17 record anywhere in this seed. Password (the shared demo password) on all thirteen.

## The sessions

Each pitcher gets a random count between 10 and 15; half bullpens, half games (odd counts give the extra one to bullpens). Dates are random between **July 1, 2026 and the run date**, never two sessions for one pitcher on the same day, bullpens on any weekday, games mostly Thursday–Sunday, with a light bias toward more games in September–October. All of it sits inside one college season (Jul 1–Jun 30), which is what Trends should show.

The randomness is **seeded** (one fixed seed in the config) so staging and production receive the same facility and Joel can compare the two.

Each pitcher carries a hidden profile the generator draws from, so the ten do not look alike and Trends have a story:

- handedness and arsenal as in the table; fastball sits in a band per pitcher (averages between 79 and 91 mph, ±2 per pitch; breaking balls and changeups offset the usual amount below the fastball), written into the velocity field the U6 strip reads;
- a base command level (the share of pitches landing in the intended cell: 25–45%; in the intended cell or an adjacent one: 60–80%; the rest scattered, some into the outer ring 10–25) with a per-pitch-type modifier so one pitch is clearly better than another for each pitcher;
- a trajectory over the window — four pitchers improve, four hold, two slip — applied as a slow drift to the command level, not a jump;
- realistic targets: fastballs up (1–3) and down (7–9) more than middle, breaking balls low and to the glove side, changeups low and away, with the canonical numbering (1 up and in … 3 up and away … 6 middle away … 7 low and in … 9 low and away, pitcher's view, 10–25 the outer ring in reading order) and every target a real area name the app uses.

**Bullpens:** 20–40 pitches, Intent on for every pitch (type + target), outcome location drawn from the profile, the usual pen flow (a warm-up fastball block, then mixed), the catcher-side perspective settings the app defaults to today, and whatever per-session fields the charting screen saves (notes on about a third of them, two or three plain sentences a coach would write).

**Games:** 1–4 innings, 25–75 pitches, batters with counts built pitch by pitch, outcomes among ball, called strike, swinging strike, foul, in play (with the ball-in-play result and field location the G1b grid saves), hit-by-pitch rarely; 3-0 counts happen but are not special here. "Turn on Intent?" = Yes on about 60% of games (type + target on every pitch), No on the rest (type only, no target). Box line per game (IP, H, R, ER, K, BB, pitches, strikes) consistent with the pitches. The pitcher is the only pitcher of record in the session; no reliever switches.

**Stats:** whatever the app writes alongside a saved session (the SC1 `session_stats` rows, and anything SC1-B added) must exist for every seeded session and must equal what recomputing from the pitches gives. Use the same code path the app uses if it can be called from Node; if the stats are produced by a database trigger, confirm the trigger ran; if the app computes them client-side, port that function and add a test that compares its output with the app's for one real saved session on staging.

**Chat (small, optional if cheap):** three or four manager posts in the facility thread over the window (welcome, a schedule note, a reminder to wear cleats on the turf) and one short private thread between Coach 1 and Pitcher 2 — all dated inside the window, nothing that triggers push or email.

## Report first, then build

Pull `origin/main` and read `CLAUDE.md`, `plans/f1-training-facilities.md`, `plans/sc1-*.md`, `plans/u15-charting-phone-batch.md` and the facility signup, coach join, pitcher link and account-deletion code. Report, in this order, before writing the script:

1. **How a saved session is stored** — table(s), the JSON shape the charting screen writes for a bullpen and for a Live Game (fields, pitch records, ball-in-play, velocity, intent flag), which columns carry the session date, and whether the owner can set that date through RLS on insert. If the date column is server-set (`default now()` with no owner-writable date), say so: the fallback is a generated `backdate.sql` for Joel, never a policy change.
2. **How `session_stats` (SC1/SC1-B) comes to exist** — trigger, RPC or client code — and how the script will produce it identically.
3. **The facility creation path** — the RPC `facility-signup.html` calls (`create_facility(token)`) and what the invite token requires. Joel will create the invite himself on `operator.html` for each environment and paste the token into the local config; the script does not call the operator function.
4. **The coach join path and the adult-pitcher link path** — the RPCs behind the join links, what profile fields, attestation and consent rows they expect, and what makes an account "verified" for report access. Report access requires pitcher verified and caller verified; the seed must satisfy that through the normal flow, never by touching `auth.users`. If that flow needs a click in an email, stop and report — we decide together.
5. **The deletion path** — what the A1 delete-account flow removes and in what order, so `--teardown` can use it as each user and then remove the organization, teams, groups and invites it created.
6. **Email surfaces** — every place a sign-up, join, session save or chat post could send mail or push, and how the seed avoids each.

Stop after the report; build on approval.

## Build (after approval)

In the site repo, `tools/seed-demo/` with its own `package.json` (Node 20, `@supabase/supabase-js`, a seeded RNG), no effect on the site itself:

- `seed.mjs` — `--env staging|prod` (URLs and anon keys read from the site's existing config, which is public), `--dry-run` (writes `out/preview.json` and prints the summary table: accounts, sessions per pitcher by type, date range, pitch totals, no network writes), the real run, `--teardown`, and `--reset` (teardown then seed). Idempotent: an account that already exists is signed into, not recreated; a pitcher who already has seeded sessions gets none added; the summary at the end prints what was created versus found.
- `config.example.json` committed; `config.local.json` git-ignored with the real addresses, names, password, birthdays, the two invite tokens and the RNG seed. Add `tools/seed-demo/config.local.json` and `tools/seed-demo/out/` to `.gitignore` in the same PR.
- `generate.mjs` — the pitcher profiles and session generator, separate from the writer so a dry run exercises all of it.
- `verify.mjs` — signs in as each account and checks the acceptance list below, printing pass/fail.
- `README.md` — Joel's exact steps, in order: create the two facility invites on operator.html (staging, then prod), fill `config.local.json`, `npm install`, dry run, staging run, verify, look at staging in the browser, **fresh production backup**, prod run, verify, then open the TestFlight app as Jordan. Include the teardown steps and a note that the password should be rotated or the facility torn down once the demo period ends.

Open a PR; do not merge. Nothing in the PR contains an address, name, birthday or password from this packet beyond the example file's placeholders.

## Acceptance (verify.mjs plus Joel on the phone)

1. All thirteen accounts sign in on the web and in the TestFlight build with (the shared demo password).
2. The manager sees both coaches, all ten pitchers, every session's history, both coach groups and the facility chat; the manager cannot post in a coach's private thread.
3. Coach 1 sees pitchers 1–5 only; Coach 2 sees 6–10 only; neither sees the other's pitchers in History, Trends, Charts or Chat.
4. Each pitcher sees only their own sessions and their own coach.
5. 100–150 sessions in total; per pitcher 10–15; bullpens and games split as specified; all dates between Jul 1, 2026 and the run date; no two on one day per pitcher.
6. A report opens for every pitcher from the manager, from the pitcher's coach and from the pitcher; the report's numbers match the session.
7. Trends show the full window for every pitcher and the four improvers visibly improve.
8. `session_stats` for a sample of 20 sessions equals a fresh recomputation from the pitches.
9. No leaderboard and no notes appear on facility teams (F1 rule), and nothing from this facility appears to any non-facility account.
10. Resend's sent count and the push/notification tables are unchanged by the run; Jordan's inbox received nothing from the seed.
11. `--teardown` on staging removes all thirteen accounts, the organization, both teams, both groups, the memberships and every seeded session, and `--dry-run` afterwards reports a clean slate.

## Paste into Claude Code (site repo)

> Save this packet verbatim as `plans/ds1-jordan-demo-seed.md` on a branch `ds1-demo-seed` before anything else; if a copy already exists on main, use that one and tell me if the two differ. Pull `origin/main` first. Read `CLAUDE.md`, `plans/f1-training-facilities.md`, the SC1 packets, `plans/u15-charting-phone-batch.md`, and the facility-signup, coach-join, pitcher-link, charting save, report and delete-account code. Goal: a seeded demo facility for Jordan — one facility manager, two coaches, ten adult pitchers, 10–15 sessions per pitcher (half bullpens, half games) dated July 1, 2026 to the run date, password (the shared demo password) everywhere — created through the app's own sign-up, join and save paths with the anon key, with no schema or RLS change and no email sent. The packet's "What Joel is overriding" section lists the exceptions Joel has granted for this packet and the rules that remain in force; both are binding. The names, addresses, birthdays and password in the packet go only in a git-ignored `tools/seed-demo/config.local.json`, never in a committed file. **Report first** on the six questions under "Report first, then build" and stop; build `tools/seed-demo/` on approval; Joel alone runs it, staging before prod; open a PR and do not merge.

## Decisions Joel has already made (recorded)

- Facility name (the facility name); coach and pitcher names as in the table (editable in `config.local.json` before the run).
- All ten pitchers adults; no parent or under-18 records in the demo.
- Same seed for staging and prod so the two match.
- The password gets rotated or the facility torn down when the demo period ends; Joel decides when.
