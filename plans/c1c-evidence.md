# C1 Stage C — evidence (Nov 25, 2026; staging)

Branch `c1-stage-c`, cache `kb-shell-v376`. Staging database: migration `20261201000000_c1c_compile` (dry run, then push).

During the push, compiling the Stage B test pieces found a type error (two all-empty columns in the union). It was
fixed in the migration file, re-applied to staging, and the 8 test live sessions compiled with no errors. No function
changes. The app checks used two headless Chrome tabs on different addresses (the staging demo coach and the demo
pitcher's own login).

Also in this PR (Joel, mid-build): the parts question is two **Yes / No** rows like the other start questions, not two
toggle buttons.

## Done when

15. **Each charter's save screen; one combined session; the pieces unchanged: PASS.**
    - **App:** two devices charted 5 pitches (pitcher B on Intent, coach A on Outcome).
      - B saved first. B's screen: "Saved · your part · Bullpen · 5 Pitches called · 5 Matched · 0 Left empty · You
        charted: Intent — the calls. The report comes when every device has saved…". No Send or View.
      - A saved second, and A's screen said the same for Outcome.
      - History on both devices then showed one session, "Charted on two devices", 5 pitches, 100% strikes, 40%
        accuracy, with the pieces hidden. Its report was made (`a281…3d5f.html`).
    - **Database** (`supabase/tests/c1c_compile.sql`, fails=0):
      - nothing is combined after the first piece; after the last it is;
      - pitches: `1:IO(exact) 2:IO(miss) 3:I 4:O -:O`, which covers a matched call and location, a call with no
        location, a skipped call, and an unmatched location kept;
      - the unmatched call is left out;
      - the type comes from the call; the purpose comes from the pen; `logged_by` is the Outcome charter;
      - the pieces keep their 8 pitches and have no stats rows; the combined stats are pitches 5, scored 2, hits 1;
      - `compiled_from` can't be changed (`session_saved_locked`).
16. **Three hours: PASS (database).** Setup: P kept holding Intent after H saved, and the live session was aged four
    hours. `c1_compile_stale()` closed it and compiled `1:IO:Slider`: H's location from H's piece, and P's call filled
    from what reached the server. No part was left open.
17. **A part nobody took: PASS.** A game charted with Outcome & Response alone compiled with `charted_intent false /
    charted_outcome true`. Its report takes Stage A's partial-session path ("Only where each pitch landed was charted").
18. **One person with both parts: identical: PASS.**
    - Every staging stats row that isn't a piece or combined session hashes the same before and after the migration:
      `0aca07c1…` for 267 rows.
    - The c1c test checks every other stats row is unchanged (true).
    - `scripts/c1a-report-check.ts`: 0 fails of 185 (67 full reports byte-identical to before C1).
    - Baselines and workload read only `session_stats`, and pieces have no row there.
19. **Test suite and shell version: PASS for everything C1 touches, with older stale tests listed.**
    - **Pass:**
      - C1 tests: `c1a`, `c1b`, `c1c`;
      - earlier releases: `f1a_acceptance`, `f1a_rls_matrix`, `f1b`, `f1c1`, `f1g`;
      - F2: `f2s1`, `f2s3`, `f2s4`;
      - live games and sessions: `g5_migration`, `h1_grace_closed`, `h1_part2`, `live_game_r2`, `live_game_r3a`,
        `pitch_count_runs`, `runners_left`;
      - N1, P and R4: `n1b`, `n1e`, `n1g`, `n1g2`, `p1_09`, `p1_10`, `p2_stage1`, `r4_acceptance` (both);
      - R7: `r7_roles_matrix`, `r7b`, `r7c`;
      - stats and baselines: `sc1_session_stats`, `sc1b_workload_rls` (0 differ), `sr1a`, `sr1b`, `sr1d`;
      - the rest: `rls_holes_test`, `s4_rls_matrix`, `s4b`, `teams_hotfix`, `u14`, `u15`, `a1_roster_closing`,
        `email_change_acceptance`.
    - **Fail for reasons older than C1:**
      - `live_game_r1` reads `hbp_swing`, dropped on Oct 22;
      - `h1_part1_acceptance` exercises the v144 old-app path, closed on Oct 21;
      - `p2_rls_matrix` and `r4_rls_matrix` get `permission denied for function is_linked_to` (F1-G's revokes);
      - `s4_multiprofile` hits `already_have_sport` (staging data);
      - `live_game_r3b` hits fixture drift.
    - **Print nothing, as before:** `a1_account_deletion`, `email_change_setup`, `sc1_compare_rows` and
      `terms_agreement` are setup or read-only scripts.
    - Shell: v374 (A), v375 (B), v376 (C). STATUS updated per stage.

## Notes for Joel
- **Approved by Joel (Nov 25 2026). Before compiling:** a piece shows in History with "Shared · waiting for the other device" and no report. This
  replaces "hidden everywhere" for the time before the combined session exists. Otherwise there would be nothing in
  History until the last device saved.
- **Account deletion:** the live tables keep the departed charter's login id (no name) until the pitcher's profile
  goes. Nothing reads it but the server's own functions.
