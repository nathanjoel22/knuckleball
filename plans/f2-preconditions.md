# F2 · Facility assignments, reassigning, birthdays, camps, housekeeping · preconditions (Nov 20, 2026)

Read at `39c7257` (main: SR1 complete, v366). Packet: `plans/f2-facility-assignments-birthdays-camps.md` (saved
verbatim; there was no copy on main). **Joel, Nov 20: "keep going and don't stop to ask"**, so every decision below
has a default, marked **→ default taken**. The builds use those defaults on staging. Any "no" from Joel changes the
build, not production, because nothing here goes to production without him.

Policy counts now: **public 32 / storage 12** on production and staging.

---

## 1. Stage H

### a) Why the opening film stopped
- **The iPhone app still opens the site's `index.html`.**
  - The app shell (`knuckleball-app`, `ios/App/App/capacitor.config.json`) starts at `start.html`, which goes to
    `https://knuckleballonline.com/`.
  - The app repo has had only store-text commits since Nov 17. **The cause and the fix are in this repo.**
- **The cause:** Nov 18's random parts (`f002f1d`, PR #111, `index.html:387-420`).
  - Parts 2 and 3 start mid-film. They set `currentTime` on `loadedmetadata`, and call `play()` only on `seeked`.
  - iOS WebKit loads no video data before `play()`, so `loadedmetadata` never comes. The 4.5 s fallback then runs:
    dark, then the logo, then sign-in.
  - So once the device had seen the whole film, about 2 launches in 3 showed no film at all, and the third only 3.5 s.
  - It was checked only in desktop Chrome, which does load the data ahead.
- **Signed in, no film:** that is by design (`index.html:18` goes straight to the app).
- **Android has no film today:** its shell starts at `bullpen-tracker.html`
  (`android/app/src/main/assets/capacitor.config.json:6`), and the film is gated to iOS (`index.html:23`).
- **The fix (built):** every signed-out launch plays the first 5 s from 0 s, with `play()` at once, so no seek. With no
  signal there's no film. `kb:introSeen` is cleared.
- **Android → default taken: unchanged (no film).** Giving it the film means changing its shell's start page and
  releasing a new Play build. Say if you want it.

### b) "Create Your Child's Profile"
- Built everywhere it appeared:
  - More (`bullpen-tracker.html:14177`), Account (`:14442`), the account button (`:4263`), the box heading (`:4308`);
  - the under-13 stops: tracker `:2740`, `join.html:140/183/284`, `join-coach.html:213`, `accept-invite.html:106/156`;
  - the Get started label and hint (`:14697`), and Help (`help.html:114`, twice).
- Nothing in the functions or the store text used it.
- **Not changed:**
  - "Add player" button texts (`bullpen-tracker.html:4319`, `join.html:560`), which are a different control;
  - `terms.html:82` ("If you add a player"), which is legal text and yours.

### c) Pitcher Name / Parent Name
- Built on `login.html#new`, `join.html` (a new pitcher on a team link) and `accept-invite.html` (an invited pitcher).
  - The pages Coach, facility and the parent's "Join as" use are unchanged.
- **Where Parent Name lives → default taken: the sign-up's auth metadata (`parent_name`). No column.**
  - Nothing has a home for a parent's *name*:
    - `contact_emails` holds addresses. The server treats every value as an allowed recipient
      (`send-session-report/index.ts:320`), and `saveContactEmails` rebuilds the object and drops unknown keys
      (`bullpen-tracker.html:5843`).
    - The guardian fields are secret, for 13–17 only, and on the login's primary profile.
  - The metadata keeps it with no migration. If you want it shown somewhere, Stage 3's migration can copy it into a
    real place.
- **Required for 13–17, optional at 18+ → default taken (packet).**
  - Under 13, the form becomes a Parent account (as before). The Parent Name typed carries over as that account's name.

## 2. Stage 2

### The roster's top row today
- **`renderJoinCodeBar()`** (`bullpen-tracker.html:5278-5287`):
  - **Show my join code**: any coach with a group on the side;
  - **All join codes**: the manager only.
- It sits first inside `renderFacilityRoster` (`:5345-5367`). It's the same on every size; only the page around it
  changes:
  - phones: the list, then the pitcher's page;
  - 501–860: one column with the icon rail;
  - over 860: `.roster-split`, with the list at 260–340 px and the pitcher's page beside it.
- There's no search today.

### The existing move path
- **`facAct`** (`:5378`) calls:
  - `move_between_groups(p_pitcher, p_from, p_to)`: manager only, `f1c1_chat.sql:430`;
  - `add_to_group(p_group, p_pitcher)`: manager or that group's coach, `f1a_facilities.sql:803`.
- **Manage's "Choose a coach…"** (`:14316-14325`, manager only): Move when the pitcher is in exactly one group, otherwise
  Add.
- **Chat today:** a move takes the open private thread to the new coach, who reads its history. The old coach loses it
  (the manager still reads). If an open thread with the new coach already exists, the old one is archived (90 days).
  Unchanged.

### Built
- **Phones:** one row, Search facility (left, fills the width) and **Join Codes** (right). The manager gets **Assign
  Pitchers** under Join Codes.
- **501–860:** the same row; Assign Pitchers sits beside Join Codes when it fits.
- **Over 860:** the row spans both columns above the list and the pitcher's page.
- **Join Codes** opens a sheet with Show my join code and (manager) All join codes. Each continues as today.
- **Search** filters the roster already on the device (by name, every section). Stage 1 adds facility results.
- **Assign Pitchers → defaults taken:**
  - It uses the same `facAct` path: move from the one current coach, or add when there is none.
  - **A pitcher in two coaches' groups:** the sheet asks which coach they move away from (Manage can't do this today).
  - **Manage's "Choose a coach…" stays** as the single-pitcher path.

## 3. Stage 1

### Where membership decides visibility or chat
- **The root is `coach_sees_pitcher`** (`f1a_facilities.sql:103`). On top of it:
  - `can_view_headshot`, `get_roster_*`, `is_coach_of_pitcher`, `is_coach_of_session_team`,
    `is_current_coach_of_pitcher`, `pitcher_session_teams`, `is_coach_of_session` (notes);
  - `set_pitch_arsenal`, `sr1_session_level` / `_age`, and `sync_session`'s charting check;
  - the SELECT rules on sessions, pitches, game_events, session_stats, pitcher_teams and profiles, the notes rules,
    accuracy_zones, and the headshots storage rule.
- **Chat reads the groups directly:** `chat_access`, `chat_compose_targets`, `chat_open/post/thread/my_threads`.
  `chat_family_ok` uses ownership and links only.
- **None of them will read the new table**, so an assignment counts nowhere. Proof: the F1-A matrix before and after,
  with a live assignment in the fixture.

### Shape → default taken
- **`session_assignments`:** id, team_id, pitcher_id, coach_id, assigned_by, created_at, `window_ends_at` (+24 h),
  session_id, released_at, cancelled_at, cancelled_by.
  - No client grant and no policy (**still 32**).
  - At most one open row per pitcher per coach.
- **`facility_pitcher_search(team, q)`:**
  - for a coach on the side's staff or the manager;
  - 2+ letters, up to 20 results;
  - returns id and name, plus the coach's name only when two results share a name.
- **`assign_session(team, pitcher, coach)`** and **`cancel_assignment(id)`**. Cancelling is for the assigner, the
  manager or the assigned coach.
- **`my_assignments()`: the device's only read of an assigned pitcher.** It returns the name, pitch types, throws,
  radar gun on/off, the RA default and the RA cells.
  - **Never:** contact_emails, uniform, level, headshot, History, notes, card, birthday.
  - It's kept in the offline snapshot, so charting works offline.
- **The save** (`sync_session`): the draft carries `assignment_id`. A new OR beside `can_chart_for OR
  coach_sees_pitcher` (`sr1a:87`) accepts the session when the assignment is:
  - the caller's, for that pitcher and team;
  - not cancelled and not used;
  - and the session's `started_at` is inside the window.

  The same transaction sets `released_at` and `session_id`. A save from the offline queue days later passes, because
  the window is checked against `started_at`.
- **A lost-response retry:** today the existing-row branch checks entitlement before `already_saved` (`sr1a:77`). So a
  released coach would be stuck with `not_entitled`. Fix: the session's own charter (`logged_by` is his) gets
  `already_saved`.
- **Expiry:** computed (`now() > window_ends_at` and no session). No cron. A discard on the device cancels it.

### Defaults taken
- **History:** coach-charted sessions read **"Charted by a coach"** (and "Charted by a former coach"). Today it's
  "Logged by coach" with no name (`:13446`, `:13583`), so the one wording now covers every coach-charted session and
  needs no new read.
- **After an assigned save:** the recap offers no View / Send report and no note box. The session leaves his History
  once synced. The report is for the pitcher's own coach, the family and the manager, as usual
  (`send-session-report` refuses him: `not_recording_team`).
- **Who can search and assign:** any coach on the side's staff, and the manager (packet).

## 4. Stage 4 → defaults taken
- **Tables:**
  - `camp_rosters`: id, org_id, team_id (the facility side, so one sport), name (2–60), coach_id, first_day, last_day
    (`date`), created_by, created_at, updated_at, ended_at;
  - `camp_roster_pitchers`: camp_id, pitcher_id.
  - No grant and no policy (**still 32**).
  - Functions for the manager: `create_camp`, `update_camp`, `end_camp`, `facility_camps()`. For the coach:
    `my_camps()`, the same narrow fields as Stage 1.
- **Dates:** there's no facility time zone anywhere (`organizations` has none), and every date rule uses
  `America/New_York`. Days are Eastern: chartable when the session's `started_at` in Eastern falls between first_day and
  last_day.
  - Listed for the coach from creation until the day after last_day.
  - The manager's list follows the same rule. Ended camps go from both.
- **Session tags can't carry the camp:** `sessions.purpose` is a bullpen-only enum that drives baselines
  (`sr1a:19`, `sr1b:106`).
  - Instead, `sessions.camp_id` plus a **`sessions.camp_name` snapshot**, written by `sync_session` and H1-locked. A
    later rename never changes past sessions, and an ended camp's name stays.
  - History shows it as a chip; the report header doesn't (to keep the report unchanged).
- **The camp grant:** chart only, any number of sessions on its dates. No History, reports or messages (packet). No
  release per session.
- **Where they show:**
  - Coach: a section under their Roster, "<name> · Nov 21–23".
  - Manager: collapsible sections after "No coach yet", like the coach groups (`section()`, `:5355`).
- **Account deletion:** `a1_purge_profile` sets a deleted coach's camps ended and drops a deleted pitcher's rows.

## 5. Stage 3

### Approval needed
**This reverses a recorded decision.** P1-10 / S4 say "No date of birth, ever": the
`p1_10_attestation.sql:33` comment, `plans/s4-profiles-and-consent.md:44`, and `privacy.html:81` ("We never ask for or
store a date of birth"). Your packet asks for it, so I'm treating the packet as that decision. Stage 3 is built on
staging only, and its policy text is DRAFT.

### Storage → default taken
- **`profile_birthdays`** (profile_id pk → profiles on delete cascade, birth_date, set_by, set_at).
  - No grant and no policy (**still 32**).
  - Column grants can't stop coaches: the profiles SELECT rule lets them read rostered pitchers' rows, so any granted
    `birth_date` column is a coach-readable column.
- **Read** through `my_birthdays()`: own profiles, players the caller created, and linked guardian / child.
- **Write** through `set_birthday()`.
- **A1:** the export reads it explicitly, and a delete cascades with the profile.

### Contradiction cases (counts; no names)

| | Production | Staging |
|---|---|---|
| attested adult (pitchers / coaches / parents) | 61 (34 / 20 / 7) | 39 (21 / 13 / 5) |
| attested 13–17 (with guardian approval) | 2 (2) | 8 (5) |
| not answered yet | 21 | 11 |
| parent-created players (by a coach's login) | 8 (1) | 6 (2) |
| adult logins that pitch *and* hold coach / parent / facility roles | 2 | 2 |
| child sign-ins | 0 | 0 |

**What the rules require if a date disagrees → defaults taken (yours to approve before production):**
- **Said 13–17, date says under 13** (up to 2 on production):
  - A self-signed-up under-13 is impossible (P1-10), and the sessions can't move to a parent-made profile, because the
    H1 lock forbids changing `pitcher_id`.
  - **Default:** the birthday is saved, reports stop as for an unanswered login, and the app says "A parent or guardian
    needs to set up this account. Contact us."
  - Nothing is deleted, charting continues, and sessions are untouched. The move to a parent account is an operator
    job, later.
- **Said adult, date says 13–17:**
  - **Default:** treated as a new 13–17 sign-up: a guardian's email is asked, and reports stop until approved.
  - The 2 logins with adult roles keep those roles but are listed for you on the operator log. R7 can't remove a role
    today, and doing so needs your call.
- **Not answered yet:** the birthday replaces their one-time age box.
- **Coach-added players** (1 on production): the coach is their "parent" on the login.
  - **Default:** the coach may *enter* a birthday (or "I don't know") from a quiet roster prompt, but can never read it
    back (write-only). The packet says coaches never see one.

### The job → defaults taken
- **The rule:** `pg_cron` `'53 9 1 9 *'` (Sep 1, about 5 am Eastern), following the `chat_clear_archived` pattern
  (`f1c1_chat.sql:414-424`).
  - New level = the **higher** of today's and the table's (packet table, ages on Sep 1).
  - So it never moves down, and a hand-set higher level is kept with no "set by hand" column.
- **Logging:** each change goes to `level_switch_log` (operator only). No email or notice.

### What a pitcher's own level drives
- **Only `profiles.level` changes.** A rostered pitcher's team games use `teams.level`, untouched.
- **Extra innings:** independent games started afterwards.
- **`sr1_session_level`:** the fallback for independent sessions. It decides:
  - the season window (college Sep 1);
  - "a year ago";
  - the 7-day guideline (100 / 125 / 150);
  - the reader versions.

  It's read when a report is *made*. **A not-yet-reported independent session made after Sep 1 uses the new level →
  default: accept** (it's rare: 1 production pitcher has independent sessions).
- **`collegeOnlyPlayer`:** a switch to College hides the Parent or guardian contact field. The saved address stays.
- **Not driven by the level:** Pitch Smart age group (a separate column; not derived from the birthday → default: no),
  level confirmation (teams only), and the leaderboard.

### Policy wording (DRAFT, for the Stage 3 PR)
- *Privacy, replacing line 81:* "Birthday: a pitcher's date of birth, entered by the pitcher or the parent who set the
  player up. We use it only to apply our age rules (who needs a parent or guardian's approval) and to move a player to
  the next level of play on September 1."
- *Privacy, who sees it:* "Only the player and their parents or guardians on Knuckleball see a birthday. Coaches,
  facility managers, teammates and report links see the level of play, never the date. It never appears in reports,
  emails or chat, is in your own data download, and is deleted with the account."
- *Terms, line 85:* "...accurate information, including your birthday or your player's."
- *Guardian consent page, line 57:* "...and their birthday, which only they and their parents or guardians can see."
- **`TERMS_VERSION`:** a material change. **Default: bump**, so every login sees "I agree" once. Yours.
- Also App Store privacy label and Play Data safety: Date of birth, linked to the user, app functionality. Yours.

### Policy wording for Stages 1 and 4 (DRAFT, in the Stage 1 PR)
"At a training facility, any of the facility's coaches can find a pitcher on the facility's roster by name and, when
assigned, chart one session for them; a temporary team or camp coach can chart the camp's pitchers on the camp's dates.
Those coaches see only what charting needs, never the pitcher's history, reports or messages."

---

## 6. The drafting decisions, as yes / no

Each one is built with the default **(D)**.

1. Film: the first 5 s on every signed-out launch, iOS only; Android stays without a film. **(D: yes)**
2. Parent Name is required for 13–17 and optional at 18+, and kept in the sign-up metadata, with no column. **(D: yes)**
3. A pitcher in two groups: Assign asks which coach they move from. Manage's "Choose a coach…" stays. **(D: yes)**
4. Search and assign for any coach on the side's staff, plus the manager. **(D: yes)**
5. An unused assignment ends after 24 h (computed, no cron). A session started inside the window is accepted whenever
   it syncs. **(D: yes)**
6. Every coach-charted session reads "Charted by a coach" (it replaces "Logged by coach"). **(D: yes)**
7. Nobody is offered View / Send report on the assigned coach's device. **(D: yes)**
8. A camp is listed from creation, chartable on its dates only, with days in Eastern time. **(D: yes)**
9. The camp coach can chart only, for any number of sessions on the camp's dates. **(D: yes)**
10. The camp name is snapshotted onto each session, so a rename doesn't change past sessions. It's shown in History,
    not on the report. **(D: yes)**
11. After its last date, a camp leaves the coach's roster and the manager's list; the record and the session labels
    stay. **(D: yes)**
12. Birthdays live in a separate table with no grant, read only by the player and their parents. **(D: yes)**
13. A coach may enter (never read) a coach-added player's birthday. **(D: yes)**
14. A contradiction is handled like a new sign-up of that age, with nothing deleted:
    - under 13 → reports stop until an operator moves the account;
    - 13–17 → guardian approval;
    - adult roles are flagged, not removed.

    **(D: yes; your approval before production)** **Built instead, and Joel, Nov 20 2026: contradictions matter only under
    18.** A date that makes the person 18+ today is always saved; an under-18 contradiction is not saved, goes on the
    operator list, and the person is asked to contact us. Nothing else changes.
15. The level rule, only ever up, with a hand-set higher level kept. **Joel, Nov 20 2026: 12 or under LL; 13–17 HS
    (HS & up); 18+ on Sep 1 College (softball HS & up).**
16. A report made after a switch for an older independent session uses the new level. **(D: accept)**
17. `TERMS_VERSION` is bumped with the birthday wording. **Joel, Nov 20 2026: yes (2026-11-20), and the wording is
    approved. P1-10's "no date of birth" is reversed.** Android's film: ignored for now (Joel).

## 7. What the existing rules make impossible as written
- **"Nothing deleted, sessions untouched" for an existing under-13 login:** it can't become a parent-made player without
  changing `pitcher_id` (H1 lock). The closest is decision 14's hold, then an operator move.
- **"Coaches never see a birthday" for coach-added players:** the coach owns that profile's login. The closest is
  write-only (decision 13).
- **The level switch can't reach team games:** they use the team's level. It changes independent sessions and the
  fallbacks only.
- **A camp label on session tags:** a tag is a bullpen-only enum that drives baselines. Hence a camp name column.
