# F2 Stage 1 · One-session assignments · evidence (Nov 20, 2026)

- **Branch:** `f2-stage1` (on Stage 2), cache `kb-shell-v369`.
- **Migration:** `20261126000000_f2s1_session_assignments` on **staging**. A dry run showed only that file. The rollback
  (`supabase/rollback/…_down.sql`, which restores SR1 A's `sync_session` verbatim) was written first.
- **Test:** `supabase/tests/f2s1_session_assignments.sql` (rolled back): **fails=0**.
- **App check:** the demo facility on staging, at iPhone width. No pictures (the demo roster holds real people's names).

## Done when

6. **Search: PASS.**
   - SQL: coach B types "ze" and gets Zed Alpha plus the two Zed Bravos, each with "[Coach A]" to tell them apart. Q,
     a pitcher on an ordinary team, never appears.
   - 1 letter gives 0 results. "%" is matched literally (0). Own pitchers come back with `mine`.
   - Another team's head is refused (`not_allowed`, for search and for assign).
   - App: a demo pitching coach typing 2 letters gets their own matches, plus one pitcher from another coach's group
     under "In the facility". 1 letter gives no facility results.
7. **Assign to self, chart, released, then refused: PASS.**
   - SQL:
     - Saving without the assignment: `not_entitled`. Saving with it: `saved`.
     - Afterwards coach B reads session 0, pitches 0, profile 0, and `my_assignments` 0.
     - A retry after a lost response gets `already_saved`; a second session on it gets `not_entitled`.
     - The row is released with `session_id` = the session.
   - App:
     - Assign, then Yourself (pre-picked), lands on "Bullpen or Live Game?" for that pitcher. A 6-pitch command pen
       saves and syncs (outbox 0).
     - Then, through the coach's own client: sessions 0, profile 0, roster row 0, RA cells 0, `my_assignments` 0. Not on
       the roster.
     - A second run showed the recap with **only Done**: no note box and no Send / View report, plus "Saved to <first
       name>'s history. Their own coach and family see it and its report." Done goes to the roster, and the pitcher
       is gone.
8. **Assign to another coach: PASS.**
   - SQL: coach A assigns P4 (B's pitcher) to CX. CX's list is 1; CA's and CB's are 0. Assigning to the pitcher's
     own coach answers `already_coach`.
   - App: coach 2 used Manage → **Assign for a session** on their own pitcher and picked coach 1. Coach 1's roster then
     showed **Assigned for a session** first, with one row (until …, Chart, Release).
   - The manager can do the same from Manage.
9. **The device holds only the charting fields: PASS.**
   - `my_assignments` returns `id, team_id, coach_id, window_ends_at, zones` and the pitcher's `id, full_name, sport,
     pitch_types, throws, uses_radar_gun, relative_accuracy_enabled`. No contacts, uniform, level or headshot.
   - During the assignment, through the coach's own client: profile 0, roster row 0, zones 0, `coach_sees_pitcher`
     false, 0 chat compose targets. So History, Trends, the card, notes, contacts and chat get nothing.
   - The report function refuses because of the recording-team check.
10. **"Charted by a coach", seen by the pitcher, their own coach and the manager: PASS.**
    - SQL: the pitcher reads 1, the own coach 1, the manager 1; the charting coach 0, the other coach 0.
    - App: the manager's History for that pitcher shows today's two sessions with the chip "Charted by a coach". The
      wording now covers every coach-charted session, which never named the coach.
11. **24 hours and offline: PASS.**
    - SQL: past the window, the coach's list is 0. A session charted 20 h earlier (inside the window) and synced now
      is `saved` and released.
    - A session started after the window gets `not_entitled`.
    - The manager cancels; a session started after the cancel gets `not_entitled`. A coach who's neither the assigner,
      the assigned coach nor the manager can't cancel (`not_allowed`).
    - App: Discard ends it on the server (`my_assignments` 0, nothing left to retry), and the pitcher leaves the roster.
    - On staging afterwards: 2 released with their sessions, 1 cancelled, 0 open.
12. **Policy count unchanged; RLS matrix: PASS.**
    - Policies: public 32 → 32, storage 12 → 12. The new table has 0 client grants and no policy.
    - Who-sees-whom (`coach_sees_pitcher` for every coach × pitcher, plus the profiles each can read) is identical
      with an open assignment in place: `CA:11100/3 CB:00001/1 CX:00000/0 M:11111/4 X:00000/1`.
    - `supabase/tests/f1a_rls_matrix.sql` on staging: `session_assignments=-1:denied` for all 58 logins.

**Older tests re-run against the new `sync_session`** (staging): `sr1a_session_tags`, `f1a_acceptance`,
`f1g_acceptance` and `n1e_facility_notes` give fails 0. `h1_part1_acceptance` passes (130-pitch save, `already_saved`
retries, the locks). `p2_stage1` passes (a coach filing Independent is still `not_entitled`).
- `live_game_r3b` stops at its first insert ("This pitcher isn't on that team"): one of its two hard-coded staging
  pitchers has left "Staging Knights" since Oct 22. That's fixture drift, not this change.

## Policy wording (DRAFT, for Joel; not on any page yet)

"At a training facility, any of the facility's coaches can find a pitcher on the facility's roster by name and, when
assigned, chart one session for them; a temporary team or camp coach can chart the camp's pitchers on the camp's dates.
Those coaches see only what charting needs, never the pitcher's history, reports or messages."
