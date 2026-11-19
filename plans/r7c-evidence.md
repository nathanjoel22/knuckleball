# R7 Stage C · one login, several roles · evidence (Nov 19, 2026)

**Where it was tested:**
- Branch `r7c-roles`, cache `kb-shell-v360`.
- Migration `20261122000000_r7c_roles` on **staging** only (`--project-ref wpsscxwawgiwmifpjpec`, written out on every
  command), recorded in staging's migration history.
- `facility-invites` redeployed to staging (its email check's new "child" answer).
- The local staging site, in headless Chrome: phone 390, iPad 820, laptop 1280.

**Pictures (`plans/r7c-evidence/`):**
- `roles-phone.png`, at 390, left to right:
  - More with the roles;
  - Account → Your roles after "Open this first";
  - "Pitch for U15 Softball Test too?" (a coach on a team link);
  - "Coach U15 Softball Test too?" (on a staff link);
  - a 13-17 pitcher refused on a staff link.
- `role-menu-1280.png`: the side menu's Role select under the team.

## Done when (Stage C)

10. **Joel's case: PASS.**
    - **The server** (`supabase/tests/r7c_roles.sql` 10): a facility manager's staff-link join makes them an assistant
      on team X, and they stay head of both facility sides. `my_roles`: "coach: R7C Team X", "facility: R7C Facility".
    - **In the browser:**
      - The Stage B self-serve manager opened U15 Softball Test's staff link while signed in and joined it straight
        away, as an assistant. Their softball coach profile already existed, so no question was needed.
      - A fresh sign-in opened the facility (R7B Self Serve Lab, `isFacilityManager` true).
      - More listed "Facility — R7B Self Serve Lab ✓" and "Coach — U15 Softball Test". Choosing the second opened U15
        Softball Test as an assistant.
      - With the network off, a cold start reopened U15 Softball Test, the last role used.
11. **Each gains the role and loses nothing: PASS.**
    - **The server** (`r7c_roles.sql` 11):

      | Case | Before (not asked) | Asked | Gains | Keeps |
      |---|---|---|---|---|
      | A coach on a team link | `coach_cannot_join`, as before | joins | pitcher profile `pitcher/baseball/team_link` | head of team B |
      | An adult pitcher on a staff link | `pitcher_cannot_join` | joins | coach profile `coach/baseball/staff_link`, assistant | primary still pitcher |
      | A coach on a guardian link | — | — | `parent: Kit Kid` | primary still coach |

      A team's head coach can also start a facility, and stays head of their team.
    - **In the browser** (the real pages):
      - Feed Test Coach (baseball) on the U15 team link saw "Pitch for U15 Softball Test too?". After "Join as a
        pitcher", the app opened their new softball pitcher profile. Roles: Coach — Staging Knights, Pitcher — U15
        Softball Test.
      - The U15 pitcher on the staff link saw "Coach U15 Softball Test too?", joined, and the app opened them as an
        assistant. Roles: Coach — U15 Softball Test, Pitcher — U15 Softball Test.
      - Feed Test Coach accepted the test parent's guardian link on `player-link.html` ("Continue to follow Little
        Leaguer with this account"). Roles: Coach — Staging Knights, Pitcher — U15 Softball Test, Parent — Little
        Leaguer.
12. **A child sign-in and an under-18 pitcher are refused every adult role: PASS.**
    - **The server** (`r7c_roles.sql` 12):

      | | Staff link | Team link | Guardian or family link | Facility |
      |---|---|---|---|---|
      | A child sign-in | `coaches_must_be_adults` | `coach_cannot_join` | — | `adult_required` |
      | A 13-17 pitcher | `coaches_must_be_adults` | — | `adult_required` | `adult_required` |

      The operator's email check now calls such an address `child`.
    - **In the browser:** the 13-17 pitcher made in Stage A, opening a staff link, sees "Coaches must be 18 or older,
      so this account can't join a coaching staff."
13. **Each role on a two-role login reads exactly what a single-role login would: PASS** (`supabase/tests/r7_roles_matrix.sql`).
    - **Method:** each pair is built by the real link functions, with real saved pens. Then one role is moved to a twin
      login (same rows, only the owner changes), and the reads are compared row for row on sessions, pitches,
      game_events, session_stats, session_notes, pitcher_teams, team_coaches, teams and profiles. "Both" = the union
      every time:

      | Pair | Rows (both = role 1 + role 2) |
      |---|---|
      | Coach + pitcher | teams 2=1+1, pitches 5=3+2, profiles 3=2+1, sessions 2=1+1, pitcher_teams 2=1+1, session_stats 2=1+1 |
      | Facility + assistant | teams 3=2+1, pitches 6=3+3, profiles 5=3+3, sessions 2=1+1, team_coaches 4=2+2 |
      | Coach + guardian | pitches 8=5+3, profiles 4=3+2, sessions 3=2+1, session_stats 3=2+1 |

      0 fails; policies 32 → 32.
    - **No login reads anything new:** the F1-A read matrix (every staging login, every table, every readable column)
      is identical with and without Stage C, once R7's three new `profiles` columns are left out of its fingerprint.
14. **The opening role in Account changes where the next sign-in opens, on a second device too: PASS.**
    - **The server** (`r7c_roles.sql` 14): `set_opening_role` stores `opens_profile` / `opens_team` on the primary.
      Someone else's player is refused with `not_your_role`.
    - **In the browser:**
      - Account → Your roles showed "Facility — R7B Self Serve Lab · OPENS FIRST". "Open this first" on "Coach — U15
        Softball Test" saved it: "Saved. Signing in opens Coach — U15 Softball Test."
      - Then, on an iPad emulation with all storage cleared (a second device), a fresh sign-in opened U15 Softball
        Test as the coach.
15. **Delete removes every role; export contains every role's data: PASS.**
    - **The server** (`r7c_roles.sql` 15):
      - A pitcher + coach login, purged the way `delete-account` purges (every profile on the login): 0 profiles left,
        0 staff rows left behind.
      - A coach + guardian login, deleted: 0 links left.
      - A facility manager asking to delete is refused with `still_head` until they hand off (Account → "Hand off the
        facility", new). The hand-off section was checked on screen; the hand-off itself is the existing
        `handoff_facility`, tested in `f1a_acceptance`.
    - **The export** of Feed Test Coach's three-role login (`export-account`, staging) has every role:
      - `profile.json` holds both profiles (`coach/baseball`, `pitcher/softball/team_link`);
      - `player_access.csv` holds the guardian link to Little Leaguer;
      - `sessions.csv` has 55 rows.
16. **Suite, cache and STATUS: PASS** (the store review notes were rewritten with Stage A).
    - **Tests on staging after the migration:**
      - 0 fails: `r7c_roles`, `r7_roles_matrix`, `r7b_facility_self`, `f1a_acceptance`, `f1b`, `f1g`, `f1c1`,
        `n1b`, `n1e`, `n1g`, `n1g2`, `u15`.
      - Ran without a fail counter: `s4b`, `p1_10`, `teams_hotfix`, `p1_09`.
      - Identical with and without Stage C: `s4_rls_matrix`, `f1a_rls_matrix`.
    - **Two old tests already fail the same way without Stage C** (`permission denied for function is_linked_to`):
      `r4_rls_matrix` and `p2_rls_matrix`. They were written before F1-G and are left as they were.
    - **Cache** `kb-shell-v360`.
    - **The rollback was run for real on staging:** all six functions came back to their original checksums and the
      three columns were gone. Then the migration was re-applied.

## Changes to existing tests

- **`f1g_acceptance.sql`:** its "an adult pitcher / coach accepting a guardian link is refused" cases are removed.
  Stage C allows that on purpose (Done-when 11); `r7c_roles.sql` tests it.
- **`f1a_rls_matrix.sql`:** leaves R7's three new `profiles` columns out of its fingerprint, as it already does for
  F1-A's own new `teams` columns.

## What changed

- **Database:**
  - the `profiles` columns `created_via` / `opens_profile` / `opens_team`;
  - `r7_add_role_profile`;
  - the three joins gain `p_add_role`;
  - `accept_player_link`, `f1_make_facility` and `facility_email_status` take any adult login;
  - `my_roles()`, `set_opening_role()`.
- **Link pages:**
  - `join.html`: "Pitch for <team> too?";
  - `join-coach.html`: "Coach <team> too?", and the 18+ refusal reworded;
  - `player-link.html`: any adult account, and the child refusal.

  Both join pages also offer that card when a login with several profiles has none of the right kind there; that
  used to show "link no longer valid".
- **App:**
  - the roles module (`my_roles`, `switchRole`, `renderRoleSwitch`, `renderYourRoles`, `setOpeningRole`);
  - what a fresh sign-in opens;
  - the facility hand-off;
  - "+ Start a facility".

## Notes

- **The team menu and the Role menu sit together.** A coach on two teams has one role (Coach) and still picks the team
  in the team menu. A login with two different roles gets the Role menu as well. For Joel's case both menus list the
  facility and the team.
- **Chat stays per login:** a manager in their coach role still has the Facility → Chat entry.
- **Staging test data changed by these checks** (test accounts only):
  - Feed Test Coach is now also a pitcher on U15 Softball Test and a guardian of Little Leaguer;
  - the U15 pitcher is also an assistant on U15;
  - the R7B manager is an assistant on U15, and opens on it.
