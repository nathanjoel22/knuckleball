# Schema reconciliation — P0-02

`supabase/schema/schema.sql` is a schema-only dump (`supabase db dump --linked -s public`)
taken directly from the production project `fkgccjhuimkkbupbanxp` on 2026-08-25. It contains
table definitions, constraints/FKs, and every `CREATE POLICY` statement (19 total), captured
straight from the live catalog — no separate `pg_policies` pull was needed since the dump
already includes full `USING`/`WITH CHECK` clauses. No data rows (no `INSERT`/`COPY`) are
present in this file — verified with `grep -nE "^INSERT INTO|^COPY .* FROM stdin"`, zero matches.

## Changes since the 2026-08-25 dump (not yet reflected in schema.sql)

- **P1-08** — `supabase/migrations/` created with `20260826082320_baseline.sql` (a
  baseline of this dump). `schema.sql` is still the human-readable source of truth;
  regenerate it after any applied migration.
- **P1-12** — `supabase/migrations/20260827161717_account_setup_server_side.sql` adds:
  - `public.handle_new_user()` + trigger `on_auth_user_created AFTER INSERT ON
    auth.users` — the **first user-defined trigger on `auth.users`** in this project.
    Creates a coach's `profiles` (+ `teams`) row at signup from `raw_user_meta_data`;
    `SECURITY DEFINER`, swallows its own errors and always `RETURN NEW` so it can never
    block signup.
  - `public.ensure_account_setup(p_role, p_full_name, p_team_name) returns jsonb` —
    `SECURITY DEFINER`, `EXECUTE` granted to `authenticated` only. Idempotent
    profile/team repair, called from the frontend via RPC. Uses
    `pg_advisory_xact_lock` on the caller's uid.

  Regenerate `schema.sql` from production once this migration is deployed there.

## 0. Biggest discrepancy: there are no migration files, and there never have been

`supabase/migrations/` does not exist in this repo, and `git log --oneline -- supabase/migrations`
returns nothing across the entire history. The only schema artifact ever committed before this
task was `supabase/schema.sql` — a hand-written "run once in the SQL Editor" script (commit
`a30b738`), not a migration chain.

This matters because the P0-02 task packet's own "Why" section assumes "five migrations" exist
to diff against. That assumption is incorrect for this repo. In reality: **100% of the live
schema's current state — including a fix for the recorded RLS recursion outage — exists only
as dashboard-applied changes, with zero record of when or why in version control.** The
discrepancies below are not drift from a few migrations; they are the entire gap between the
one hand-written setup script and whatever has been changed by hand in the dashboard since.

Going forward, per CLAUDE.md, every schema/policy change must be a migration file — there is
currently no migration chain to `supabase migration list` against or to build one from, so the
first real migration in this project will need to be a baseline reflecting current production
state (out of scope for this packet; recorded here for whoever picks that up).

## 1. Discrepancies vs. the committed `supabase/schema.sql`

| Area | `supabase/schema.sql` (committed, hand-written) | Live production (this dump) |
|---|---|---|
| RLS recursion fix | `teams` policy directly subqueries `pitcher_teams`, and `pitcher_teams` policies directly subquery `teams` — this is the exact cross-referencing pattern that caused the 42P17 outage. | Two `SECURITY DEFINER` helper functions, `public.is_team_coach(check_team_id)` and `public.is_team_member(check_team_id)`, now exist and are used everywhere a policy needs to check team ownership/membership across `teams` ↔ `pitcher_teams`. This is the actual fix for the recorded outage — **it is not committed anywhere in this repo.** |
| `pitcher_teams.pitcher_id` FK target | `references auth.users(id)` | `references public.profiles(id)` — required for the `pitcher_teams.select('profiles(id, full_name, pitch_types, contact_emails)')` embed used in `loadRosterForTeam` in `bullpen-tracker.html` to work at all via PostgREST. The hand-written schema would not support the app's current roster-loading code. |
| `pitches` columns | `row_idx integer`, `col_idx integer` (single location) | `target_row`, `target_col`, `actual_row`, `actual_col` (target vs. actual, matching the two-tap charting flow), plus `accuracy_mode text` with a check constraint for `ring`/`nothingUp`/`nothingLow`/`nothingAway`/`nothingInside` (matches the "relative accuracy" modes in `bullpen-tracker.html`). The hand-written schema describes an earlier, simpler pitch-location model that the app has since outgrown. |
| `profiles.contact_emails` | absent | `jsonb NOT NULL DEFAULT '{}'` — backs the coach/pitching-coach/pitcher contact emails used by `sendSessionReport` in `bullpen-tracker.html`. Not in the hand-written schema. |
| `sessions.logged_by` | absent | `uuid NOT NULL references auth.users(id)` — distinct from `pitcher_id`. Not in the hand-written schema; implies a session can be logged by someone other than the pitcher it belongs to (e.g. a coach charting for a pitcher), but there's no comment or code path found yet confirming who's expected to set this. |
| `sessions`/`pitches` write access for coaches | Coaches can only **view** (`SELECT`) sessions and pitches for their team. | Two additional `FOR ALL` (not just `SELECT`) policies exist live: `"Coaches manage sessions for their team"` and `"Coaches manage pitches for their team's sessions"`. Coaches currently have full insert/update/delete rights over sessions and pitches belonging to any pitcher on their team, not just read access. This is a materially larger permission surface than what's documented in the repo. |
| Policy count | 17 `CREATE POLICY` statements | 19 (the two coach-manage-write policies above, on top of the otherwise-equivalent 17) |

No other table/column differences were found; `profiles`, `teams`, `invites` are otherwise
consistent between the hand-written script and live.

## 2. D3 ownership checklist

**(1) Does the sessions/pitches table key to a pitcher user id?**
Yes. `sessions.pitcher_id` (`uuid`, `NOT NULL`) references `auth.users(id) ON DELETE CASCADE`.
`pitches` has no direct pitcher column; it keys to `sessions.id` via `pitches.session_id`
(`uuid`, `NOT NULL`, `ON DELETE CASCADE`), so a pitch's owner is only reachable by joining
through its session. Separately, `sessions.logged_by` (`uuid`, `NOT NULL` →
`auth.users(id)`) also exists and is distinct from `pitcher_id` — see the discrepancy table above.

**(2) Is any team column on it nullable/absent?**
No — and this is the important finding. `sessions.team_id` is `uuid NOT NULL` with a foreign
key to `teams(id) ON DELETE CASCADE`. It is required, not optional. `pitches` has no team column
of its own; it inherits team scoping transitively through `sessions.team_id`. **A session
cannot exist in production today without a team.** See escalation below.

**(3) Which policies assume team membership for read/write?**
- `teams` / `"Pitchers view teams they belong to"` — `is_team_member(id)`, requires a
  `pitcher_teams` row.
- `pitcher_teams` / `"Coaches view memberships for their teams"`, `"Coaches remove pitchers
  from their team"` — both `is_team_coach(team_id)`.
- `profiles` / `"Coaches view their pitchers' profiles"` — requires a `pitcher_teams` row
  plus `is_team_coach` on that row's `team_id`.
- `sessions` / `"Coaches manage sessions for their team"` (ALL) and `"Coaches view sessions
  logged under their team"` (SELECT) — both require `sessions.team_id` to match a team the
  coach owns. Since `team_id` is `NOT NULL`, every session row is necessarily covered by
  team-based coach access — there is no team-less session a coach could be locked out of, but
  also none a pitcher could have privately without a team.
- `pitches` / `"Coaches manage pitches for their team's sessions"` (ALL) and `"Coaches view
  pitches for their team's sessions"` (SELECT) — same, via `sessions.team_id`.
- Pitcher-side access (`"Pitchers manage own sessions"`, `"Pitchers manage pitches in own
  sessions"`) does **not** depend on team membership, only `pitcher_id`/session ownership — but
  since `team_id` is required at insert time regardless, a pitcher can't currently create a
  team-less session even though the RLS policy governing their own access doesn't require one.

**(4) Are all expected FKs present (invites, pitcher_teams, sessions)?**
Yes, all present:
- `invites`: `team_id → teams(id) ON DELETE CASCADE`, `invited_by → auth.users(id)`.
- `pitcher_teams`: `team_id → teams(id) ON DELETE CASCADE`, `pitcher_id → profiles(id) ON
  DELETE CASCADE` (see discrepancy above — this targets `profiles`, not `auth.users`).
- `sessions`: `pitcher_id → auth.users(id) ON DELETE CASCADE`, `team_id → teams(id) ON DELETE
  CASCADE`, `logged_by → auth.users(id)` (no explicit `ON DELETE`, defaults to `NO ACTION`).
- `pitches`: `session_id → sessions(id) ON DELETE CASCADE`.
- (`profiles.id → auth.users(id) ON DELETE CASCADE` and `teams.coach_id → auth.users(id) ON
  DELETE CASCADE` also present, though not explicitly asked for above.)

## 3. Escalation

**D3 answer (2) triggers this packet's own escalate condition:** "the D3 answers show sessions
cannot exist without a team (that changes Phase 1–2 sequencing — Joel must see it before
P1-01)." `sessions.team_id` is `NOT NULL` in production today — the intended ownership model
(decision D3: "sessions belong to the pitcher, team affiliation is optional") is not what's
currently enforced by the schema. A solo pitcher with no team cannot have a session row as the
database is currently constrained. Flagged to Joel; no fix attempted here per this packet's
scope.
