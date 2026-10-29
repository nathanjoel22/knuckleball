# F1-A — RLS matrix, before and after

Migration `20261030000000_f1a_facilities`.

| | Staging (`wpsscxwawgiwmifpjpec`) | Production (`fkgccjhuimkkbupbanxp`) |
|---|---|---|
| Before (Oct 29, 2026) | 30 policies, matrix captured | 30 policies, matrix captured |
| After | **32 policies, identical matrix** | Joel's step (see the apply order in STATUS.md) |

## 1. Every login × every table (`supabase/tests/f1a_rls_matrix.sql`)

**What it does:** signs in as every login on the project, one at a time, with RLS on. For each table with row security
it records how many rows that login sees and a digest of exactly which rows (only the columns a client may read). It
also records what the visibility functions return for that login:
- `pitcher_workload` over every pitcher;
- `pitcher_report_block`;
- `pitcher_session_teams`;
- `get_roster_verification` and `get_roster_closing` for each team they coach.

It is read-only and ends by raising its result.

**Staging, run straight after the migration** (before any facility test data existed):

| | Logins | Policies | Tables compared | Differences |
|---|---|---|---|---|
| Before | 32 | 30 | 19 | — |
| After | 32 | 32 | 19, plus 4 new tables | **0**: every login, every table, every function the same |

**New tables after:**
- `coach_groups` and `coach_group_members`: 0 rows for every login.
- `organizations` and `facility_invites`: denied for every login, because clients have no grant at all.

The two new `teams` columns (`org_id`, `kind`) are left out of the `teams` digest so the before/after compare like with
like. They are covered by the facility checks below.

**Production before:** 55 logins and 30 policies, with these totals (rows visible, summed over logins):

```
accuracy_zones=36 game_events=408 invites=32 pitcher_teams=115 pitches=13729 profiles=159 roster_seen=93
session_notes=30 session_opened=122 session_stats=590 sessions=628 team_coaches=29 teams=42
```

**Production after:** Joel runs the same file after applying the migration. Every one of the 55 lines must be identical,
with policies=32.

## 2. The write and visibility matrices from R4 and P2 (staging, after)

`supabase/tests/r4_rls_matrix.sql` and `p2_rls_matrix.sql` were re-run. They are rolled back. Each one checks these
operations for every persona:
- reading sessions, pitches, events and notes;
- inserting a note;
- `delete_session`;
- writing the report link;
- report eligibility.

Both gave the same yes/no pattern as recorded in `plans/p2-preconditions.md`. The only differences are the changes P2
itself made: an independent pen now saves, and the solo pitcher is eligible. Policies: 32.

## 3. The facility matrix (`supabase/tests/f1a_acceptance.sql`, staging, rolled back)

Fixture logins:

| Code | Who |
|---|---|
| M | the manager, made by `create_facility` |
| CA | coach A, 15 pitchers |
| CB | coach B, 5 pitchers |
| CX | a facility coach with no pitchers |
| HT | the head of an ordinary team (the Cairn case) |
| X | an unrelated coach |
| P01–P20 | pitchers; P01 is on the ordinary team and in coach A's group |

**Roster rows** (`pitcher_teams` on the side / pitcher `profiles` / group members / `get_roster_verification`):

| | M | CA | CB | CX | HT | X |
|---|---|---|---|---|---|---|
| | 20/20/20/20 | 15/15/15/15 | 5/5/5/5 | 0/0/0/0 | 0/1/0/0 (P01's profile, through the ordinary team) | 0/0/0/0 |

**Charting** (`sync_session`):

| Charter → pitcher | Result |
|---|---|
| M → P16 | saved |
| CA → P01 | saved |
| CA → P16 (not theirs) | not_entitled |
| CB → P16 | saved |
| CX → P02 | not_entitled |

**Reads** (session / pitches / stats) of three pens:
- the lesson pen: P01 on the facility, charted by coach A;
- P01's pen on the ordinary team;
- P16's pen, charted by coach B.

| | Lesson pen | Ordinary-team pen | Coach B's pen |
|---|---|---|---|
| P01 | 1/4/1 | 1/4/1 | 0/0/0 |
| M | 1/4/1 | 1/4/1 | 1/4/1 |
| CA | 1/4/1 | 1/4/1 | 0/0/0 |
| CB | 0/0/0 | 0/0/0 | 1/4/1 |
| CX | 0/0/0 | 0/0/0 | 0/0/0 |
| HT | 1/4/1 (R4 stands: "this data is ours") | 1/4/1 | 0/0/0 |
| X | 0/0/0 | 0/0/0 | 0/0/0 |

**Roster pitch counts** (`pitcher_workload`, pitchers with a count): M 2, CA 1, CB 1, CX 0.

**Notes:** inserting a note is refused on the lesson pen (M and CA both refused) and allowed on the ordinary team's pen
(HT).

**Leaderboard:** `get_team_leaderboard` on the facility raises `facility_team`.

**Groups:**
- Coach A **cannot** add to coach B's group (`not_allowed`) or move pitchers (`not_allowed`).
- Coach A **can** clear "New" in their own group.
- Coach A removing P03 from their only group takes P03 off the side, and the departure is logged.
- The manager can move a pitcher from A to B, add P17 to a second group, and remove P17 from one group (P17 stays on
  the side).
- When coach B is removed from the staff, their group goes; their pitchers stay on the side with no coach.

**Handoff:**
- To a coach on one side only: `not_on_both_sides`.
- To coach A (on both sides): done. Both head rows and `manager_login` moved; the old manager is an assistant on both
  sides and is no longer a facility login.

**Signup link:**
- Wrong email: `wrong_email`. Expired: `expired`.
- Created once, then `already_created` for the same login. For another login it reads `used`, and creating again gives
  `used`.

**Result:** policies 32, hard fails **0**.

## 4. With real staging accounts (Oct 29)

Coach A charted a lesson pen for Staging Pitcher, who is on Staging Knights and in coach A's group. Reads:

| | Lesson pen (session / pitches / stats) | Staging Pitcher's Knights sessions |
|---|---|---|
| Staging Knights head | 1 / 12 / 1 | 32 |
| Coach A | 1 / 12 / 1 | 32 |
| Coach B | 0 / 0 / 0 | 0 |
| Manager | 1 / 12 / 1 | 32 |

## 5. Rollback (staging, in one transaction, aborted)

The test cleared the facility test data and ran `supabase/rollback/20261030000000_f1a_facilities_down.sql`. It found:
- policies = 30;
- no `organizations` or `coach_groups` table;
- no `teams.kind` column;
- no `coach_sees_pitcher` function;
- the sessions read rule back to `is_team_coach(team_id)`.

The transaction was then aborted, so staging is unchanged (still 32 policies). With facility sessions present, the
rollback refuses to run.
