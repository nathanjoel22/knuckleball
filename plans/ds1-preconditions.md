# DS1 demo facility: preconditions report (Nov 11, 2026)

Written against site `origin/main` `ca6fc6e`, branch `ds1-demo-seed`. The packet was not on main; it is saved as
`plans/ds1-jordan-demo-seed.md` but **not committed**, because it holds a real address and the password (see D7).
Read-only checks were run on production and staging (Auth confirmation timing, grants).

**Status: approved (Joel, Nov 11 2026): D1-D8 as recommended.** D1: the verify SQL is run by Claude on staging; on
production, run when Joel confirms at that step. D2 (the self-verify hole) is a separate packet, not built here. D6:
Joel tells Jordan. Built in `tools/seed-demo/` (README there).

## 1. How a saved session is stored

- **One call:** `sync_session(p_session, p_pitches, p_events)` (latest:
  `supabase/migrations/20261101000000_f1g_player_links.sql:312-467`). It is granted to `authenticated` only, so the
  script signs in as each pitcher (anon key + password) and saves as that pitcher, like the app does.
- **The payload** is built in the tracker's `syncOutbox` (`bullpen-tracker.html:6226-6353`):
  - **Session:** `id`, `pitcher_id`, `team_id`, `logged_by`, `started_at`, `ended_at`, `charting_perspective`, `kind`,
    `opponent`, `game_final_inning`, `game_outs_recorded`, `ra_on`, `pitch_count_adjust`, `inherited_runners`,
    `runners_left`, `relieved_session_id`, `left_owners`.
  - **Pitches** are column names straight into `pitches`: `type`, `velo`, `target_row/col`, `actual_row/col` (the
    catcher frame, 0-4), `batter_side`, `accuracy_hit_kind`, `accuracy_zone_cells`, `ts`, `kind`, `result`,
    `in_play_outcome`, `hit_type`, `fielder(s)`, `delivery`, `inning`, `outs/balls/strikes_before`, `at_bat_index`,
    `bb_type`, `runners_before/after`, `batter_to`, `runner_advances`, `outs_on_play`, `runs_scored`, `unearned_runs`,
    `sacrifice`, `spray_box`, `spray_field`.
  - **Events** go to `game_events` (`seq`, `event_type`, the before-counts and similar).
- **Intent:** not stored. A Live Game with Intent = No saves `target_row/col` null; with Intent = Yes they're set. A
  bullpen always has a target (a CHECK requires it). `ra_on` = the RA answer; a game's is `intent && RA`.
- **The date is client-set, so backdating needs no SQL.** `started_at`, `ended_at` and every pitch's `ts` are taken
  as sent. There is no age or clock check, and no trigger changes them.
  - `created_at` and `sealed_at` will show the real run time. Nothing in the app shows them.
  - The G3 team check needs the pitcher on the team now, not at `started_at`, so a session dated July on a team joined
    today is accepted.
  - The facility coaches see it through `coach_sees_pitcher` (the recording team), which has no date limit.
  - **`backdate.sql` is not needed.**
- **Pitfalls the generator must respect:**
  - Velocity of exactly 65 before Sep 21 counts as "no reading" (U6, `isDefaultVeloReading`), so never write 65.
  - A game must end at the end of an inning with no runner of his own left on. Otherwise `final_at` stays null ("Line
    open"), and its report is refused for 6 hours.
- **Live Game is not "the G1b grid" any more.** Since Oct 19-21 a play carries contact, location, fielders, runner
  moves and runs (CLAUDE.md, "Live Game charting now"). The generator will write plays the way the app does:
  - a strikeout, a walk, a hit with its base and the runners forced or held, an out in play with fielders, an occasional
    error or HBP;
  - every count, out, runner and run consistent, so `compute_game_summary` gives a true box line.
  - It won't produce rare plays (balks, interference, relief hand-offs).

## 2. How `session_stats` comes to exist

- **Only by the database:** the `sessions_sc1_stats` trigger runs `finalize_session_stats` when `sync_session` seals
  the session. No client writes it, and the script can't write it either (no grant), so the rows are made exactly as
  for a charted session.
- **Checking it:** `scripts/sc1-compare.js` / `sc1b-compare.js` already lift the app's own stats functions out of the
  tracker and compare them with the stored row in Node. `verify.mjs` will do the same with rows it reads as the signed-in
  pitcher (RLS), and will also check `session_stats_failures` is empty for the seeded ids.
  - Nothing is ported, so there is no second copy of the math.

## 3. Facility creation

- **The page's calls, in order** (`facility-signup.html:153-205`):
  1. `facility_invite_info(token)`;
  2. `auth.signUp(email, password, data {full_name, intended_role:'coach', intended_sport:'baseball'})`;
  3. `ensure_account_setup()`;
  4. `record_attestation('adult', '2026-10-17', null, 'signup')`;
  5. `create_facility(token)`.
- **The invite must** be unused and not expired (14 days). Its email must match the login (case ignored), and the login
  must not already coach or pitch anywhere.
- **What it makes:**
  - the organization;
  - **always two** `kind='facility'` teams, baseball and softball (F1 decision B), so the demo facility will have an
    empty softball side;
  - Jordan as head of both;
  - his own coach group on each side.
- Joel makes the invite on `operator.html` for Jordan's address, once per environment, and pastes the token in.

## 4. Coaches, pitchers and "verified"

- **Coaches** (`join-coach.html`):
  1. the manager's `get_team_invite_links(baseball team)` gives the coach token (the script reads it as Jordan);
  2. `signUp` with `intended_role:'coach'`, `ensure_account_setup`, `record_attestation('adult')`;
  3. `join_team_as_coach(token)`.
  A trigger then makes the coach's group.
- **Pitchers** (`join.html?c=`, "I'm 18 or older and pitch for myself"):
  1. the coach's `my_group_codes()` gives the group code;
  2. `signUp` with `intended_role:'pitcher'`, `ensure_account_setup`, `record_attestation('adult')`;
  3. `join_group_via_token(code)`, which adds the facility membership and the group row.
  After that: `profiles.update({throws})` and `set_pitch_arsenal` (full names such as Four Seam Fastball, Curveball).
- **No birthday is ever stored.** The app keeps only the age bracket ('adult'), so the birthdays in the packet would
  have nowhere to go. I'll leave them out of the config.
- **Auth confirmation is off on both projects.** Every production sign-up since Sept 22 was confirmed instantly, and
  staging's last 30 days too. `signUp` returns a session and Supabase sends nothing.
- **"Verified" (`profiles.email_verified_at`) only comes from clicking an emailed link.** The join pages send it
  automatically (`join.html:407-418`, `join-coach.html:313-324`) through Resend.
  - A report needs the pitcher verified, and the coach too when they aren't the owner.
  - **This is the packet's "stop and report" case.** See D1.

## 5. Deletion

The A1 flow can't do the teardown:
- **It always sends email**, when the deletion is requested and again when it completes.
- **It waits 7 days** for the daily job.
- **Jordan is refused `still_head`.** Handing off needs another login that coaches both sides.
- **The data can't all be removed from the app.** Once a facility team has a session (a tombstone counts), no app call
  can delete that team or the organization. `delete_team` refuses, and there is no organization delete.

The precedent is `supabase/scripts/f1a_loadtest_cleanup.sql`, which removed the F1-A load-test facility in one SQL
block (dry run by default). See D3.

## 6. Email and push surfaces

| Surface | Fires on | The seed |
|---|---|---|
| Supabase Auth confirmation | sign-up, if "Confirm email" were on | off on both projects (checked) |
| send-verification-email (Resend) | the join pages, automatically after sign-up; the Resend button | the script never calls it (D1) |
| send-guardian-consent | a 13-17 answer | all adults |
| invite-pitcher (Auth invite) | not used by any page | not called |
| send-session-report | Send report (Email); Create report / View send no email | the script makes no reports (D4) |
| send-removal-notice | a coach removing a pitcher | never |
| request-email-change | Change Email | never |
| delete-account | request and completion emails | not used (D3) |
| rate-limit alert | the daily circuit breaker | unaffected: no sends |
| chat | none (no trigger, no email) | n/a |
| push | none exists in the app | n/a |

The script calls no Edge Function at all. Acceptance 10 becomes a before/after count of `rate_limit_events`
(read-only).

## Where the packet and the repo differ

1. **Notes:** facility teams refuse coach notes (`is_coach_of_session`, F1-A: Chat replaces them). The bullpens get none.
2. **Chat can't be backdated:** `chat_post` takes only the text; the time is `now()`. The posts would be dated the run
   day (D5).
3. **Reports for backdated sessions aren't made by themselves.** History auto-creates only for sessions started from
   Nov 5. Older ones show **Create report** (D4).
4. **Trends show strike % and peak velocity per pitch type, not command.** "Improvers visibly improve" has to show
   there. The command drift will push strike % up 10-15 points over the window, plus about 1 mph for improvers (a slip
   for the two who slip).
5. **Perspective:** today's app default is behind the pitcher for a bullpen and behind the catcher for a game (U15).
   The seed uses those. Storage is catcher-frame either way.
6. **Acceptance 6:** "from the manager, the coach and the pitcher" is the same report link; a report is made once per
   session and every viewer sees that one.
7. **Acceptance 11** becomes the teardown SQL (D3).

## Decisions for Joel

- **D1. Verification without the email.** Recommended: **a small `ds1_verify.sql`** that Joel runs. It sets
  `profiles.email_verified_at` on the 13 primary profiles, found by those addresses, and refuses anything else.
  `auth.users` is not touched. This is an exception to "only `verify_email` sets it", scoped to this packet.
  - The alternative: let the 13 verification emails go to Jordan's inbox and click each one. That breaks "no email".
- **D2. A security hole found while reading (separate from DS1).** `generate_email_verify_token()` is callable by any
  signed-in login and **returns the token**. `verify_email` is callable by anyone. So any login can mark its own email
  verified without receiving anything, which defeats the report gate's verification check. The grants are live on
  production (checked).
  - The seed will **not** use it.
  - Recommended: a short packet that revokes it from `authenticated` and has send-verification-email call it with the
    service role.
- **D3. Teardown.** Recommended: `--teardown` **writes** `out/teardown-<env>.sql` for Joel to run, modelled on the
  F1-A cleanup. It is a dry run by default and refuses the wrong project. It removes the seeded sessions (pitches,
  events, stats with them), any report files made from them, chat, groups, roster, staff, both teams, the organization,
  the invite, the 13 profiles and the 13 logins. `--reset` = run that, then seed.
- **D4. Reports.** Recommended: the script makes none. In the app, History's **Create report** makes one with no email
  (the normal path), and verify asks Joel to open one per pitcher on staging. Alternatively the script could call
  Create report's function itself for every session. That writes 100-150 report files and copies the tracker's payload
  builders.
- **D5. Chat:** post the four facility messages and the Coach 1 ↔ Pitcher 2 thread **dated the run day**, or skip chat.
  Recommended: post them; the thread shows it's live.
- **D6. Jordan's own login.** His real Gmail becomes a facility manager login on production with a password that's in
  the packet. Recommended: Jordan changes his own password after the first sign-in (the 12 alias accounts keep the
  shared one). It also means that address can't later coach an ordinary team.
- **D7. The packet file.** Committing it verbatim would put a real address and the password in the public repo, which
  the packet itself forbids. Recommended: commit a copy with the people's names and addresses replaced by roles, and the
  password by "the shared password in config.local.json"; keep the verbatim copy local (git-ignored).
- **D8. Birthdays:** dropped (no column exists; the age bracket is 'adult').
