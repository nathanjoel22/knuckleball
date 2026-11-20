# F2 Stage 4 · Temporary Team/Camp Roster · evidence (Nov 20, 2026)

- **Branch:** `f2-stage4` (on Stage 1), cache `kb-shell-v370`.
- **Migration:** `20261127000000_f2s4_camps` on **staging**. A dry run showed only that file. The rollback (restores
  Stage 1's `sync_session` and drops the camp columns, tables and functions) was written first.
- **Test:** `supabase/tests/f2s4_camps.sql` (rolled back): **fails=0**. Stage 1's, SR1 A's and F1-A's tests still give
  fails=0 against the new `sync_session`.
- **App check:** the demo facility on staging, at iPhone width. No pictures (real names).

## Done when

13. **A camp: a name, a coach, four pitchers from three coaches, three days. It shows under the coach's roster and at
    the bottom of the manager's list, expandable: PASS.**
    - **SQL:**
      - A coach can't create one (`not_allowed`); a pitcher not on the side is refused (`not_on_side`).
      - The manager makes "Winter Camp" (P1, P2 from A, P3 from B, P4 from C; Nov 20–22). The manager's list shows 1
        camp, 4 pitchers and its coach.
      - The camp coach's list shows 1 camp of 4. Each pitcher has only `full_name, id, pitch_types,
        relative_accuracy_enabled, sport, throws, uses_radar_gun, zones`.
      - Other coaches get 0. The camp coach can't call the manager's list.
    - **App:**
      - More → **Create Temporary Team/Camp Roster** opens the sheet: Team/Camp Name, Assign a coach (3 offered), Assign
        pitchers (with Search facility), Set date (From / To).
      - Saved "F2 Test Camp", Nov 20–22, 4 pitchers. The demo side has pitchers in only 2 coaches' groups, so they came
        from two.
      - Manager: the camp is the **last** section, after "No coach yet". It expands to its 4 pitchers and Edit camp.
      - Camp coach: "F2 Test Camp · Nov 20–Nov 22" under their roster, 4 rows, all chartable today.
14. **On a camp day the coach charts a camp pitcher; the session carries the camp's name; nothing else is readable:
    PASS.**
    - **SQL:**
      - Two camp sessions `saved`.
      - Refused (`not_entitled`): a pitcher not in the camp; a session after the last day; a session without naming
        the camp.
      - The camp coach then reads 0 camp sessions, 0 camp pitchers' profiles and 0 roster rows (`coach_sees_pitcher`
        false); a retry gets `already_saved`.
      - P3's own coach and P3 both read the session as "Winter Camp".
      - Changing a saved session's camp is refused (`session_saved_locked`), even as the table owner.
    - **App:** the camp coach chartered a camp pitcher from another coach's group (the draft carried the camp). The
      recap showed only Done. It synced (outbox 0). Then the coach reads 0 of that pitcher's sessions; the camp stays
      listed for its other days. The manager's History shows the session with the **"F2 Test Camp"** chip.
15. **The day after the last day it's gone from both lists; the sessions and their label stay; permanent coaches never
    changed: PASS.**
    - SQL: a camp whose last day was yesterday is in neither list. Coach-group membership is byte-identical before and
      after everything (`permanent coaches unchanged: true`). The camp sessions keep their names (3 of 3).
    - Dates are Eastern days: `f2_today_et()` on the server, `todayET()` on the device. Charting is allowed when
      `started_at` in Eastern falls on a camp day, so a later sync is fine.
16. **Editing (name, coach, pitchers, dates) and ending early: PASS; neither touches a saved session.**
    - **SQL:**
      - The edit to "Spring Camp" (coach C, 3 pitchers, Nov 19–25) is saved; the saved session still reads "Winter
        Camp".
      - The old coach's list drops to 0 and the new coach's is 1. The new coach charts the added pitcher, labelled
        "Spring Camp".
      - End early: the manager's list is 0, editing afterwards gives `camp_ended`, and charting after the end gives
        `not_entitled`.
    - **App:** renamed to "F2 Renamed Camp" with the session still labelled "F2 Test Camp". End early… then "Yes, end it
      now" takes it off the manager's roster, with "Camp ended. Its sessions keep its name."

**Nothing widened:**
- Policies 44 → 44 (public + storage). There are 0 client grants on `camp_rosters` / `camp_roster_pitchers`, and the
  manager's own client is refused reading them directly.
- `sessions` gains `camp_id` (FK, never deleted: camps only end) and `camp_name`, both readable by whoever reads the
  session.

**Staging data:** "F2 Test Camp" (renamed, then ended) stays on the demo facility with one camp session, as test
history.
