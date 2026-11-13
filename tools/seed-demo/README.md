# DS1 demo facility seed

Builds Jordan's demo training facility (packet `plans/ds1-jordan-demo-seed.md`, decisions in `plans/ds1-preconditions.md`):
one facility manager, two pitching coaches, ten adult pitchers, and 10-15 bullpens and Live Games per pitcher between
the config's `startDate` and `endDate`. Everything goes through the app's own calls, signed in as each account with the
public anon key: the same sign-up, join and save calls the pages make, so RLS, triggers and the stats trigger all run
normally. **No Edge Function is called, so no email is sent.** Nothing here is part of the site; Cloudflare's build copies
only its own file list.

**Only Joel runs this against production.** Staging first, a fresh production backup before production.

| File | What it is |
|---|---|
| `config.local.json` | **git-ignored.** The real names, addresses, the shared password, the seed, the two invite tokens |
| `config.example.json` | the same shape with placeholders (committed) |
| `generate.mjs` | the pitcher profiles and sessions (no network) |
| `seed.mjs` | `--dry-run`, the real run, `--teardown`, `--reset` |
| `verify.mjs` | signs in as each account and checks the packet's acceptance list |
| `out/` | **git-ignored.** `preview.json`, `verify-<env>.sql`, `teardown-<env>.sql`, the stats sample |

## Steps, in order

All commands from `~/knuckleball-repo/tools/seed-demo`.

1. **Facility invites (Joel).** On `operator.html`, signed in as your operator login, make one invite per project:
   - Facility name and the manager's email exactly as in `config.local.json`; Baseball level **College**.
   - **Staging:** run the local staging site (`python3 -m http.server 8000 --bind ::` in the site repo, with the staging config
     swap) and open `http://localhost:8000/operator.html`.
   - **Production:** `https://knuckleballonline.com/operator.html`.
   - Each gives a link ending in `facility-signup.html?t=...`. Paste the part after `t=` into `config.local.json` →
     `invites.staging` / `invites.prod`. **Don't open the link**: the script signs up the manager itself.
2. **Config:** `config.local.json` already has the people, the password and the seed. Keep `seed` and `endDate` the
   same for both projects: they decide every date and number, so staging and production get the same facility.
3. `npm install` (once).
4. **Dry run:** `node seed.mjs --env staging --dry-run`. It prints the summary table (sessions per pitcher, the trend,
   strike % first third → last third, the games' totals) and writes `out/preview.json`. Nothing is sent.
5. **Staging run:** `node seed.mjs --env staging`. It takes a few minutes. Safe to run again: accounts are signed into,
   memberships kept, sessions have fixed ids and come back `already_saved`.
6. **Verified email (decision D1):** the run writes `out/verify-staging.sql`, which marks the 13 sign-ins' email
   verified. That's needed for reports and normally comes only from an emailed link. Run it:
   `supabase db query --linked --project-ref wpsscxwawgiwmifpjpec -f "$PWD/out/verify-staging.sql"`
7. **Check:** `node verify.mjs --env staging`. Every line should say PASS.
   - For the email check, run the count it prints before step 5 and again now; the two should be equal.
8. **Look at staging in the browser:**
   - Sign in as the manager, one coach and one pitcher on the local staging site.
   - History and Trends: open **Create report** on one session per pitcher (the backdated sessions don't make their
     reports on their own; Create report sends no email).
   - Chat shows the facility posts and the Coach 1 thread.
9. **Fresh production backup** (BACKUPS.md).
10. **Production:** steps 4-7 with `--env prod`; the verify SQL is `"$PWD/out/verify-prod.sql"` (the full path: the CLI reads `-f` from the repo root) with
    `--project-ref fkgccjhuimkkbupbanxp`.
11. **TestFlight:** open the app as Jordan (and one coach, one pitcher) with the shared password.

## What it makes

- **Accounts:** the manager signs up like `facility-signup.html` and makes the facility with the invite
  (`create_facility`).
  - Coaches join like `join-coach.html`, with the manager's coach link. A trigger makes each coach's group.
  - Pitchers join like `join.html?c=` ("I'm 18 or older"), with their coach's group code. Then their hand
    (`throws`) and pitches (`set_pitch_arsenal`) are set.
  - Every account answers the 18+ question (`record_attestation`). No birthday is stored; the app has no column for
    one.
- **Sessions:** one `sync_session` per session, exactly as the outbox sends it.
  - Most are charted by the pitcher's coach (`logged_by` = the coach), some by the pitcher.
  - **Bullpens** have 20-40 pitches: a fastball warm-up, then the mix, all with a target. They open behind the
    pitcher (U15). Batters are mixed, some pens have no batter, and Relative Accuracy is off.
  - **Live Games** last 1-4 innings and 25-75 pitches, opening behind the catcher. Every plate appearance is played
    pitch by pitch: balls, called and swinging strikes, fouls, HBP, and balls in play with contact, location,
    fielders, runner moves and runs. About half the games have Intent (a target on every pitch). Every game ends on
    the inning's third out, so none is left "line open".
  - Velocity is mostly present (a few sessions without a gun). Never exactly 65 (U6).
- **The stats rows** (`session_stats`) are made by the database's trigger when each session saves, as for a charted
  one.
- **Each pitcher's story:** four improve, four hold, two slip.
  - The improvers' strike % (what Trends shows) rises and their fastball gains about 1.5 mph; the slips fall.
  - The seed `ds1-122` was picked because all ten read that way in pens and overall.
- **Chat:** four facility posts by the manager, and a short Coach 1 ↔ Pitcher 2 thread.
  - Dated the day of the run: chat can't be backdated (decision D5).
- **Left out by the app's rules:** coaches' notes (facility teams have none: Chat replaced them) and the leaderboard
  (none on facility teams).

## Removing the facility (teardown)

The app's own account deletion can't do this. It emails each account, waits 7 days, and refuses the manager while
they head the facility. It also can't delete a team that has sessions. So teardown is a SQL file Joel runs (decision D3),
modelled on `supabase/scripts/f1a_loadtest_cleanup.sql`:

1. `node seed.mjs --env staging --teardown` writes `out/teardown-staging.sql`.
2. Run it as is: `supabase db query --linked --project-ref wpsscxwawgiwmifpjpec -f "$PWD/out/teardown-staging.sql"`. It's a
   **dry run**: it does everything, reports the counts and rolls back.
3. To really remove it, change `dry_run constant boolean := true` to `false` in that file and run it again.

What it removes:
- the facility's sessions (pitches, events, stats with them), chat, roster, staff and groups;
- both teams, the organization and its invite;
- the 13 profiles and the 13 sign-ins.

It refuses the wrong project, and refuses if anyone who isn't a demo sign-in has joined the facility. Report files made
from these sessions are deleted where SQL is allowed to, or listed for deleting in Storage → reports.

`--reset` writes the teardown, waits while you run it, then seeds again.

**When the demo period ends** (Joel decides): tear the facility down, or at least change the shared password on every
account. Jordan should change his own manager password after his first sign-in either way (decision D6).
