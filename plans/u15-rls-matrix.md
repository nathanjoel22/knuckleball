# U15 — RLS matrix, before and after (staging)

Migration `20261106000000_u15_pitch_arsenal`: one new SECURITY DEFINER function, `set_pitch_arsenal(uuid, text[])`. No
table, column, grant or policy change.

| | Staging (`wpsscxwawgiwmifpjpec`) | Production (`fkgccjhuimkkbupbanxp`) |
|---|---|---|
| Policies before (Nov 6, 2026) | 32 | 32 |
| After | **32, identical matrix** | Joel's step (apply order in STATUS.md) |

## 1. Every login × every table (`supabase/tests/f1a_rls_matrix.sql`, read-only)

Run on staging straight before and straight after the migration. The `MATRIX` result (every login's row counts and row
digests for every table with row security, plus the visibility functions) was **identical**: 32 logins, 32 policies.

```
TOTALS account_deletion_log=0 accuracy_zones=25 chat_messages=0 chat_reads=0 chat_reports=0 chat_threads=0
coach_group_members=0 coach_groups=0 facility_invites=0 game_events=85 invites=4 leaderboard_exclusions=0
organizations=0 pitcher_team_departures=0 pitcher_teams=34 pitches=1674 player_link_invites=0 player_links=0
profiles=62 rate_limit_config=0 rate_limit_events=0 roster_seen=22 session_notes=4 session_opened=33
session_stats=277 session_stats_failures=0 sessions=284 team_coaches=16 teams=25
```

The per-login lines are kept off this public repo (they list login ids).

## 2. Who may write an arsenal (`supabase/tests/u15_pitch_arsenal.sql`, rolled back)

Fixture logins on `example.invalid`. Result `fails=0`:

| Caller → pitcher | Expected | Got |
|---|---|---|
| pitcher, own | ok | ok |
| head coach of the pitcher's team | ok | ok |
| assistant coach of that team | ok | ok |
| head of another team | refused | not allowed |
| a pitcher, on someone else | refused | not allowed |
| parent, their own player | ok | ok |
| a coach, on a player on no team of theirs | refused | not allowed |
| facility manager, a pitcher on the side | ok | ok |
| the pitcher's group coach | ok | ok |
| another group's coach, same facility side | refused | not allowed |
| head of an archived team | refused | not allowed |
| pitcher on an archived team, own | ok | ok |
| parent, on the parent's own profile row | refused | not allowed |
| coach, on the coach's own profile | refused | not allowed |
| not signed in | refused | permission denied |

Also: duplicates dropped with the order kept; null, a blank name and 21 pitches refused (`invalid pitch list`); an
empty list saves. Policies still 32.

## 3. In the app (staging)

- An assistant coach (Staging Knights) added and removed pitches for a rostered pitcher.
- A softball head coach set a pitcher's list, and that pitcher's own login then showed it.
- A parent edited their player's list.
- The parent's crafted call on another pitcher was refused: `not allowed`.
