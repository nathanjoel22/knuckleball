# P2-01 + P2-02 preconditions report (Oct 22, 2026)

Packet: `plans/p2-solo-pitchers.md` (GitHub, `b224e56`; that upload added only this file). Branch `p2-solo-pitchers`
from `main` (`b224e56`, v295). Nothing built. `S` = `supabase/schema/schema.sql` (regenerated from production today,
after R3 Stage B); `T` = `bullpen-tracker.html`.

**Headline.** The database already treats a no-team session almost exactly as the packet wants: the only paths that
read one are the pitcher's own and R4's current-coach path, and only the pitcher can delete it or write its report.
What blocks independent sessions is three explicit refusals (`team_id NOT NULL`, the G3 trigger, `sync_session`'s
`v_team is null` check), the report-eligibility team clause, and a full-page "No team yet" wall in the app. **One
real hazard found:** `sync_session`'s relief-link check fails open when a team is NULL (item 1c).

---

## 1. Everything that assumes `sessions.team_id` is set

**a. The column** (S:3568) `team_id uuid NOT NULL`, FK `sessions_team_id_fkey` -> teams `ON DELETE RESTRICT` (S:4085). No
CHECK mentions it; no index on it. Triggers: `sessions_g3_team_check` (S:3926, `BEFORE INSERT OR UPDATE OF team_id`),
`sessions_h1_lock` (S:3930), `sessions_s1_sport` (S:3934; sport comes from the pitcher, not the team).

**b. Policies** (29 in S, none with a `TO` clause). NULL rule: every team helper is an `exists(... team_id =
check_team_id ...)`, so a NULL team gives **false**, never NULL (`is_team_coach`, `is_team_head`, `is_team_member`,
`is_coach_of_session`, `is_coach_of_session_team`; `is_team_archived(NULL)` = false).

| Table | Cmd | Policy (S line) | Predicate | NULL team |
|---|---|---|---|---|
| sessions | SELECT | S:4210 | `is_my_profile(pitcher_id) OR is_team_coach(team_id) OR is_current_coach_of_pitcher(pitcher_id, started_at)` | pitcher + current coaches (R4) |
| sessions | UPDATE | S:4214 (report link) | `is_my_profile(pitcher_id) OR is_team_coach(team_id)` (USING and CHECK) | pitcher only |
| pitches | SELECT | S:4204 | exists session with the same three-way predicate | pitcher + current coaches |
| game_events | SELECT | S:4162 | same | pitcher + current coaches |
| session_notes | INSERT | S:4122 | `is_my_profile(author_id) AND is_coach_of_session(session_id)` | **nobody** (pitchers never add notes) |
| session_notes | SELECT | S:4176 | author, the pitcher, `is_coach_of_session_team`, or the R4 path | author, pitcher, current coaches |
| session_notes | DELETE | S:4114 | `is_my_profile(author_id)` | unchanged |

No INSERT/DELETE policy on sessions; pitches and game_events have SELECT only (writes only through `sync_session`).
No other table's policy touches `sessions.team_id`.

**c. Functions**
- `sessions_g3_team_check` (S:2646-2668): NULL on INSERT falls through to `raise 'This pitcher isn''t on that team'`
  (S:2666). **Fix:** `if new.team_id is null then return new;` at the top of the INSERT path -- the non-NULL rule
  (on the team now, or left after the session started; archived refused) is untouched. The UPDATE branch already
  refuses any team change (S:2652), so a saved session can't move between NULL and a team (the H1 lock refuses it too,
  `IS DISTINCT FROM`, S:2694-2700).
- `sync_session` (S:2830-2978): `v_team is null` -> `invalid_session` (S:2866). New-row entitlement (S:2887):
  `is_my_profile(v_pitcher) or is_team_coach(v_team)` -- with NULL only the pitcher himself can save it (a coach can't
  file a pen as Independent; packet rule 2). **Hazard (S:2903-2907):** the relief-link check
  `elsif not (v_owner.kind = 'game' and v_owner.team_id = v_team and ...) then refused else linked` -- if either team is
  NULL the comparison is NULL, `not (NULL)` is NULL, the `elsif` isn't taken, and it falls to **`linked`**. Unreachable
  today only because S:2866 rejects NULL first. **Fix in Stage 1:** `v_owner.team_id is not distinct from v_team` plus an
  explicit `v_team is not null` (relief linking stays team games only), so it fails closed.
- `r3_apply_relief` (S:2017): `o.team_id = r.team_id` -> NULL -> skipped. Fails closed; no change.
- `delete_session` (S:840-852): pitcher, else `is_team_head(v_team)` -> NULL team: pitcher only. No change.
- `is_current_coach_of_pitcher` (S:1553-1565): reads `pitcher_teams`, never `sessions.team_id` -- the R4 path is
  unaffected (current, non-archived teams, joined on or before the session).
- `pitcher_workload` (S:1952-1974): no team filter, SECURITY INVOKER -> independent sessions count, as the packet wants.
- `get_team_leaderboard` (S:1183-1334): `where s.team_id = p_team_id` (S:1252) -> independent sessions never on a board.
- `compute_game_summary` (S:597-739): never reads `team_id` or `teams.level`.
- Others reading `sessions.team_id`: `pitcher_session_teams` (S:1927, inner join drops NULL -- the app adds the
  "Independent" chip itself); `get_roster_latest` (S:1123) / `get_unopened_sessions` (S:1352), both SECURITY INVOKER and
  joined to the coach's own roster, include a pitcher's independent pens for a current coach (the roster "new" dot) --
  consistent with rule 3; `delete_team` (S:895) and `a1_headed_teams` (S:71) count by team (unaffected).

**d. send-session-report** (`index.ts`): session read via the caller's RLS (:228-232, no team selected); ownership
(:251-262) = `is_my_profile` or `is_coach_of_session_team` -> an independent session's report is the pitcher's only
(403 `not_recording_team` for anyone else); team name and the trend lists come from the client body (:382, :390-392,
:421). `from_rows.ts` (operator re-render only) uses `.eq('team_id', s.team_id)` (:130-133), which won't match NULL --
independent sessions can't be re-rendered (acceptable: nothing calls it but `rerender-reports`, which is per team).
`export-account` exports a coach's team sessions by team (:88); a pitcher's own export is by pitcher -- unaffected.

**e. The app (T)** -- nothing handles a team-less pitcher:
- **The wall:** `render()` returns a full-page "No team yet ... Ask your coach for their team's invite link."
  (T:12903-12916) whenever `state.teams` is empty. `currentPitcherId` is only set in `onTeamChange` (T:3629), which
  never runs with zero teams (T:2601-2605); no pitcher branch like the coach's `setupNeeded = 'team'` (T:2745-2755).
- History: `if(!pitcherId || !teamId) return []` (T:5887-5888); the query itself has no team filter (R4).
- Draft key `'draft:' + pitcherId + ':' + currentTeamId` (T:4665; coach adopt T:3643); outbox `teamId:
  state.currentTeamId` (T:5321) -> `team_id: item.teamId` (T:5569); velocity history keyed `pitcher:team` (T:4956).
- Team picker: none (wall) / one (static name, T:12925) / many (`<select>`, archived in an optgroup, T:12919-12924).
- Chips: `teamChipHtml` returns '' when `!s.teamId` (T:5841); the pitcher's History team filter lets NULL-team rows
  through any filter (T:11290-11292).
- Report team: `reportTeamId(s) = s.teamId || currentTeamId` (T:12580), `sameReportTeam` (T:12581) -- would put a
  team name on an independent report and mix its trends with the current team's; payload `teamName` (T:12629, T:12766).
- Uniform number: "Join a team to set a uniform number." (T:12352); `setupIncomplete` requires a team, so a team-less
  pitcher always gets the "Finish setting up your profile" banner (T:12552-12560).
- Report templates drop " · Team" when the name is null/empty (`template.ts:59`, `template_game.ts:107`); the bullpen
  workload caption says "on this team" (`template.ts:267`); `connect.ts` captions say "(same team)" (:6, :114).

## 2. Report eligibility

`is_pitcher_report_eligible` (S:1618-1629, SECURITY DEFINER):
```
coalesce((select acct.email_verified_at is not null
                 and (acct.age_attestation = 'adult' or acct.guardian_consented_at is not null)
                 and (pr.managed_by is null or pr.guardian_consented_at is not null)
            from public.profiles pr join public.profiles acct on acct.id = pr.account_id
           where pr.id = p_pitcher_id), false)
and exists (select 1 from public.pitcher_teams where pitcher_id = p_pitcher_id)
```
Stage 1 drops only the last line: verified AND (adult OR guardian-approved) AND (a parent-added player's consent stamp)
-- the S4 B consent clause stays (it's a consent rule, not a team rule). `pitcher_report_block` (S:1903-1916) has no
team case; `send-session-report` defaults to "No report can be sent until this player is on a team." (:211, :217) --
that fallback text changes with Stage 2. **Callers:** only `send-session-report/index.ts:201` (and :210 for the block);
nothing in SQL or policies; the app gates client-side with `currentPitcherOnTeam` (T:2354-2356, "a deliberate,
temporary restriction until solo/team-less pitcher accounts are supported") in History (T:11335, T:11465) and
`sendSessionReport` (T:12811). The caller-verified rule (Amendment 11) is untouched.

## 3. Signup today

`pitcher-signup.html` needs **no invite**: `auth.signUp` (intended role pitcher, sport from `kb:sport`, :225-228), then
`ensure_account_setup('pitcher', name)` (:249), the attestation (`record_attestation`, :168/:250; 13-17 also
`send-guardian-consent`), the verification email, then `bullpen-tracker.html` (:258). It never calls
`join_team_via_invite`. With email confirmation on, its confirm card says "...log in to finish setting up your team."
(:112). **What a pitcher with no team sees now** (headless, a seeded team-less pitcher): the "NO TEAM YET -- You haven't
joined a team yet. Ask your coach for their team's invite link." wall, sign out and the account menu only. The U9 setup
modal is set but never drawn (the wall returns first, T:13110). The invite path (`join.html`) is unchanged by this
packet.

## 4. Team picker and Leaders

Picker: see 1e. **Leaders is already hidden for everyone:** `hasLeaderboard()` (T:11709) needs `sportCfg().hasLeaderboard`,
which is `false` for both sports (T:1821, T:1828; "Joel, Oct 10: leaderboard hidden for now"). Rule 6's "Leaders tab
hidden" is already true; rules 6 and 8 need no change beyond keeping it so.

## 5. Extra-inning tiebreak

`state.activeSession.extraStart = extraInningStart((state.teams.find(t => t.id === state.currentTeamId) || {}).level)`
(T:6383). `extraInningStart` (T:6784-6787) already falls back to the sport's last level with no team -- **baseball
college (10th), softball high school & up (8th)** -- so an independent game works today with that default. Rule 7's
per-game level question is a new start-screen question (U14 pattern).

## 6. Production counts (read-only, Oct 22)

- Pitcher profiles by teams they're on: **0 teams: 13** (4 sessions between them -- teams they left), **1 team: 27**
  (105 sessions), **2+: none**. None on an archived team (13 teams, 0 archived). 1 parent-added player.
- Sessions 124, none with a NULL team. **Policies 29.**
- Those 13 team-less pitchers hit the wall today; after Stage 2 they become solo pitchers (their old team sessions stay
  readable by the teams that charted them, G3).

## 7. RLS matrix BEFORE (staging, `supabase/tests/p2_rls_matrix.sql`, rolled back)

Personas from `r4_rls_matrix.sql`: P (pitcher on TA, TB, archived TC, left TD), Q (pitcher on no team), HA/AA and HB/AB
(head/assistant of TA, TB), HC (archived TC), HD (TD, P left), HS (softball), X (unrelated), anon. Pens: SA (TA), SB
(TB), SD (TD while P was on it), **SI (P, no team)**, **SQ (Q, no team)** -- the NULL rows made inside the transaction
(`team_id` NOT NULL dropped and the G3 trigger paused, then rolled back). Counts are sessions/pitches/events/notes.

```
SYNC_SESSION team NULL (P): invalid_session
READ s/p/e/n (SA SB SD SI SQ):
  P : 1/4/1/1 1/4/1/1 1/4/1/1 1/1/1/0 0/0/0/0     Q : 0 0 0 0 1/1/1/0
  HA: 1/4/1/1 1/4/1/1 1/4/1/1 1/1/1/0 0/0/0/0     AA: same as HA
  HB: 1/4/1/1 1/4/1/1 1/4/1/1 1/1/1/0 0/0/0/0     AB: same as HB
  HC: nothing   HD: SD only 1/4/1/1   HS: nothing   X: nothing   anon: 0/0
NOTE INSERT (SA SB SI SQ): HA/AA yes on SA only; HB/AB yes on SB only; P, HC, X none; nobody on SI or SQ
DELETE_SESSION (SA SB SI): P yes yes yes; HA SA only; HB SB only; assistants none
REPORT_PATH WRITE (SA SB SI SQ): P SA SB SI; Q SQ; HA SA; HB SB; HC, X none
ELIGIBLE P/Q: true/false        policies: 29
```
Read: an independent pen is already visible only to its pitcher and his current non-archived coaches (R4), and
writable only by the pitcher. A solo pitcher's pen is visible to no coach. Stage 1's AFTER run must differ only in:
`sync_session` saves SI, and Q becomes eligible.

---

## Escalation checks (packet "ESCALATE IF")

- **A coach reading a NULL-team session by a non-R4 path:** none (matrix above; every team helper is false for NULL).
- **Eligibility letting an unverified or unconsented pitcher get a report:** no -- only the membership clause goes;
  verified + adult-or-guardian + parent-player consent stay, and the caller-verified rule is separate.
- **Draft / outbox carrying the filing:** yes -- the filing becomes the session's own `teamId` (NULL = Independent),
  chosen before pitch 1 and locked; the draft key uses the session's filing, so a mid-session switch can't orphan it.
- **G3 allowing NULL without weakening non-NULL:** yes (one early return for NULL; the rest unchanged).
- **New:** the `sync_session` relief-link fail-open (1c) -- fixed in the same migration.

## Decisions for Joel

1. Independent pens readable by his current coaches (R4) -- the packet's default, and how the database already behaves.
2. Filing tray default = last used, locked after pitch 1.
3. Independent games: ask the level at start (rule 7), or just use the sport default the app already applies
   (baseball college 10th, softball 8th).
4. A coach can't file a session as Independent (only the pitcher himself can save one) -- rule 2 as written.
5. Notes: nobody can add notes to an independent pen (pitchers can't add notes anywhere today) -- as rule 3 implies.
6. One migration for Stage 1 (`20261026000000_p2_01_team_optional`): NOT NULL dropped, G3 NULL early return,
   `sync_session` (NULL team for the pitcher's own pens; the relief-link fix), `is_pitcher_report_eligible` without the
   team clause. Policies unchanged (29).
