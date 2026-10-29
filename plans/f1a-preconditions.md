# F1-A — preconditions report (no code yet)

Oct 29, 2026. Packet: `plans/f1-training-facilities.md` (v2, on GitHub in commit `1103ed7`; that upload added only
this file). Read from the live databases (production `fkgccjhuimkkbupbanxp` and staging `wpsscxwawgiwmifpjpec`: the same
101 functions and 30 policies on each) and from `main` at `a7c5314` (v320).

## The nine questions

### 1. Does `sessions` have a charted-by column?

**Yes. `sessions.logged_by`** is "the person who charted" (CLAUDE.md). `sync_session` already refuses
unless `is_my_profile(logged_by)`, so the value is always the caller's own profile. The H1 lock freezes it, and A1
clears it to NULL on a purge ("Logged by former coach").

**Proposal:** add no `charted_by`; F1 reads `logged_by`.

### 2. Head checks: does the manager as plain head need any of them to change?

**No.** "Head" is `teams.coach_id`, tested by `is_team_head(team)`. It is login-level: any profile the caller's login
owns counts. `team_coaches.role` (CHECK `'head' | 'assistant'`) is kept in step by `_create_team_with_head` and
`hand_off_team_head`.

Every head-only action goes through `is_team_head`:
- delete a session (`delete_session`, the H1 head rule);
- rename, archive, restore and delete a team (`rename_team`, `archive_team`, `restore_team`, `delete_team`);
- the R6 handoff (`hand_off_team_head`);
- invite links (`rotate_team_invite`, `rotate_coach_invite`, `get_team_invite_links`);
- `set_team_level`, `set_uniform_number`, `remove_coach`, `get_removal_notice_info`;
- the `leaderboard_exclusions` and `pitcher_teams` DELETE policies.

`is_head_of_pitcher` (the `coach_set_*` edits of a pitcher's name, pitch types, throws and so on) is also built on
`is_team_head`. A manager who heads both facility teams, with a coach profile on each, passes all of these unchanged.

**Notes for `handoff_facility`:**
- `hand_off_team_head` requires the new head to already be an **assistant on that team**, and turns the old head into
  an assistant. So `handoff_facility(new_manager)` needs the new manager to be a coach on both sides (see Q3 below).
- The old manager stays on as an assistant on both sides unless removed.

### 3. R4's cross-team read, by name

These all decide "a coach can see this pitcher" with `is_team_coach(team)` (any coach of the team: head or
assistant). On a facility team each one must also require `is_group_coach` for an assistant.

**Policies (8 of the 30):**
- `sessions` SELECT: "Sessions: read by the pitcher, the recording…": `is_team_coach(team_id) OR
  is_current_coach_of_pitcher(pitcher_id, started_at)`.
- The same shape, through the session, on `pitches` SELECT, `game_events` SELECT and `session_stats` SELECT.
- `session_notes` SELECT: `is_coach_of_session_team` and `is_current_coach_of_pitcher`.
- `sessions` UPDATE (the report link): `is_team_coach(team_id)`.
- `pitcher_teams` SELECT "Coaches view memberships for their teams": `is_team_coach`. **This is the roster.** Without
  narrowing, a facility assistant sees the whole side.
- `profiles` SELECT "Coaches view their pitchers' profiles", via `pitcher_teams` + `is_team_coach`.
- `accuracy_zones` ALL: `is_coach_of_pitcher`.

**Helper functions:**
- `is_current_coach_of_pitcher` (R4 itself: `is_team_coach(pt.team_id)` over the pitcher's current teams);
- `is_coach_of_pitcher`;
- `is_coach_of_session` (notes insert);
- `is_coach_of_session_team`.

**Functions that use them:**
- `sync_session`: **charting**. `is_team_coach(team)` lets any coach of the team chart any pitcher on it.
- `pitcher_session_teams`, `get_roster_verification`, `get_roster_closing`, `can_view_headshot`,
  `pitcher_report_block`, `get_team_leaderboard`.
- `pitcher_workload` is SECURITY INVOKER, so it narrows by itself once the policies do.
- The `send-session-report` Edge Function checks the recording team through the caller's own RLS reads.

**Proposal: one new helper, `coach_sees_pitcher(team, pitcher)`.** It means `is_team_coach(team) AND (team is not a
facility OR is_team_head(team) OR is_group_coach(pitcher, team))`.
- It replaces `is_team_coach(...)` in the places above where a pitcher is involved: the eight policies'
  coach clauses, `is_current_coach_of_pitcher`, `is_coach_of_pitcher`, the two `is_coach_of_session*` helpers and
  `sync_session`'s charting check.
- `is_team_coach` itself is unchanged, so staff lists and team rows still work.
- For `kind='team'` the new helper is exactly `is_team_coach`. Behaviour stays the same, but **the policy text
  changes**. The packet asks for "byte-for-byte unchanged". I read that as unchanged *behaviour*, proven by the RLS
  matrix (every role × every table) before and after. Rewriting only the facility half isn't possible, because a
  policy can't branch on the team's kind without reading `teams`, and that is exactly the 42P17 trap. The helper
  reads `teams` inside SECURITY DEFINER, as `is_team_archived` already does.
- No policy will reference `teams` or `pitcher_teams` directly. The `pitcher_teams` SELECT policy calls the helper
  instead.

### 4. How the switcher decides which profiles a login has

The app reads `profiles where account_id = <login>` (the "Users view own profile" rule) and picks one:
`pickActiveProfile`, `kb:activeProfile:<uid>`, and the "Who's charting?" picker when there are several.
- **A login has exactly one role.** `ensure_account_setup` makes the primary profile (`id = account_id`), and
  `add_sport_profile` copies the primary's role into the other sport.
- `create_facility` can therefore make the manager's primary coach profile (baseball) plus a second coach profile
  (softball) on the same login, as `add_sport_profile` does. The switcher already flips between them.
- **The manager's profiles are `role = 'coach'`.** "Facility manager" isn't a profile role: it means "this login
  owns an organization". That keeps every coach path (`create_team` checks, `sync_session`, head rules) working.

### 5. How `get_team_leaderboard` and the Leaders tab are gated

- **Tab:** `hasLeaderboard()` = has a team and the team isn't archived and `SPORTS[sport].hasLeaderboard`. That is
  `false` for both sports since Oct 10, so Leaders is hidden everywhere today. F1-A adds "and not a facility team",
  so it stays hidden when the flag comes back.
- **Server:** `get_team_leaderboard(team, window)` (SECURITY DEFINER) requires `is_team_coach` or `is_team_member`.
  F1-A adds a refusal for `kind='facility'`.

### 6. How `pitcher_workload` is scoped, and its cost for 100 pitchers

- It is SECURITY INVOKER: the caller's read rules decide which sessions count. Since SC1-B it sums the
  `session_stats` row.
- **Timed today as each real coach, with the read rules on:**
  - production: 19 pitchers / 106 sessions in **11–12 ms**;
  - staging: 7 pitchers / 57 sessions in **12 ms**.
- That's about **0.1 ms per visible session**, so 100 pitchers × 20 sessions ≈ **0.2–0.3 s** on the server, plus the
  narrowed helper's extra check per row. The load test measures the real number.

### 7. Where `profiles.managed_by` is read

- **11 functions:**
  - `add_player`, `add_sport_profile`, `get_roster_verification` ("Parent account");
  - `is_pitcher_report_eligible`, `pitcher_report_block`;
  - `join_team_via_invite`, `join_team_as_coach` ("Join as:");
  - the A1 set: `a1_due_deletions`, `a1_purge_profile`, `account_deletion_status`, `request_account_deletion`.
- **Pages:** `bullpen-tracker.html` (8 places) and `join.html` (3).
- **Policies:** none.

Every one treats it as "the login that created and manages this player". A later `player_guardians` table can keep
`managed_by` as the creator, with no change to these.

### 8. Policy count

**30 on production and 30 on staging** (unchanged since SC1).

### 9. A plan for seeding staging (100 pitchers × ~20 sessions) without touching production

- **Every seeding command names `--project-ref wpsscxwawgiwmifpjpec`.** The linked project is production, so a bare
  `--linked` would hit it. The seed script also refuses to run unless a staging-only marker row exists (the "Staging
  Knights" team).
- **Logins** (as built: `f1a-…@example.com`, an address range that never receives mail, and 12 seed parents, not 1,
  because a login holds at most 10 profiles): four test logins:
  - the manager;
  - coach A (15 pitchers);
  - coach B (5 pitchers);
  - one seed parent.

  They're made with the staging Auth admin API. The key comes from `supabase projects api-keys --project-ref
  wpsscxwawgiwmifpjpec`, is held in memory only and never written to a file.
- **Pitchers:** 100 **parent-created players** (no login each) under the seed parent, named "LoadTest 001…100", all
  baseball:
  - 15 in coach A's group, 5 in coach B's group, the other 80 in no group (the manager sees all 100);
  - 3 real staging test pitchers for the acceptance checks, one of them also on Staging Knights.
- **Sessions:** ~20 per pitcher, mixed pens and games of ~60 pitches. They're written **through `sync_session` as
  the manager**, so sealing, the triggers and `session_stats` all run as they do in real use. That's about 2,000
  sessions and ~120,000 pitches; staging's free tier has room.
- **Cleanup:** `supabase/scripts/f1a_loadtest_cleanup.sql` removes everything tagged LoadTest (sessions through the
  same server path, then players, groups and logins), so staging can go back to how it was.

## Where the packet and today's system differ (decisions needed)

**A. "Role boundaries stay exactly as today": today there are none at sign-in.**
- Since S4 (A8, Oct 2) `login.html` **never refuses** a login for sport or role. The card only tells the app which
  profile to open.
- A login can't hold two roles (Q4), so a pitcher login can't *open* a coach profile anyway. But a pitcher who signs
  in on the Coach card is let in to their pitcher profile.
- The facility card's "refuse logins with no organization" and the other cards' "refuse a facility login" are
  **new**. They can only be enforced in the browser after sign-in: sign straight out, with a plain message. Supabase
  password sign-in can't be refused per card on the server, and what anyone can read stays decided by the server's
  read rules.
- **Proposal:** enforce it in the browser for the facility card in both directions only. Leave the pitcher and coach
  cards as they are today, as the packet says.

**B. A one-sport facility.** `facility_invites` has a level per side. Should a facility that only does baseball get
only the baseball team (softball level left empty)? **Proposal: yes.** The switcher then shows one side.

**C. Handoff to someone coaching only one side.** `hand_off_team_head` needs the new head to be an assistant on each
team. **Proposal:** `handoff_facility` requires the new manager to be a coach on every side the facility has, and
refuses otherwise. The old manager stays on as an assistant (with a coach group) until the new manager removes them.

**D. Charting is narrowed too.** `sync_session` lets any coach of a team chart any pitcher on it. On a facility team
an assistant should chart only their group's pitchers (the packet's table). Proposal: the same helper as Q3.

**E. The inquiry function has no signed-in caller.**
- Every current Edge Function checks the caller's login, and H1's limits are per user.
- `facility-inquiry` must accept anonymous posts, so it needs a new **per-IP** limit (by hashed IP, kept 7 days like
  the other events), plus the daily circuit breaker.
- It's a public form that emails nate@knuckleballonline.com, so spam is possible. It is capped by those limits, and
  there's no CAPTCHA, because no third-party loads are allowed.

**F. Load-test timing on real devices.**
- I can time roster, History and Trends in the test Chrome at phone and iPad sizes, with the phone CPU and Wi-Fi
  simulated, and record the numbers.
- The packet asks for an iPad and a phone over Wi-Fi. That needs you to open the staging site on both while I read
  the timings, or to accept the simulated numbers.

**G. Test logins.** Creating staging logins with the Auth admin API (Q9) is a write to staging Auth. It's staging
only, but it's a new kind of step, so I'm asking first.

## Joel's answers (Oct 29, 2026)

- **A. Agreed.** The facility card turns away logins that don't own a facility; the Pitcher and Coach cards turn away
  facility logins. Enforced in the browser right after sign-in (sign out, plain message).
- **B. No.** Every facility has both sides: `create_facility` always makes a baseball and a softball team.
- **C. OK.** `handoff_facility` needs the new manager on both sides; the old manager stays as a pitching coach.
- **D. OK to narrow.** A facility assistant charts only their group's pitchers.
- **E. No form, no link.** The facility card shows the contact email as plain text to copy. **No
  `facility-inquiry` Edge Function and no `facility-inquiry.html`** (packet check 2 is dropped).
- **F. Simulated** timings (test Chrome with phone / iPad CPU and network throttling) are good.
- **G. Yes:** staging test logins via the staging Auth admin API, key in memory only.

## As built (staging, Oct 29 2026)

See STATUS.md (F1-A entry), `plans/f1a-rls-matrix.md` and `plans/f1a-load-test.md`.
