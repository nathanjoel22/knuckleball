# V1 Part B · the guided Live Game flow · evidence (Nov 18, 2026)

Branch `v1-guided-flow` (built on Part A, `v1-field-art`), cache `kb-shell-v354`. Tested on the local staging site with
the staging database, in headless Chrome. The flow was driven through the app's own functions, the same ones the taps
call, and each step read back from the screen and the session.

Pictures in `plans/v1b-evidence/`:
- `steps-<sport><size>.jpg`: the four steps in order, Intent on.
  - Sports: `bb` baseball, `sb` softball. Sizes: `ph` 440 × 912, `w` 1280 × 800.
- Each screenshot is cropped above the scoreboard (no test account's name or photo), and scanned for "@" and names:
  none.

## Done when

Items 1-5 are Part A's (PR #103).

6. **A new game opens on Select Batter Side: PASS.**
   - A new game opens with no batter drawn and the two outside columns pulsing: 10 boxes, in the accent (`rgb(255, 79,
     154)` on softball, gold on baseball).
   - There is no RHB / LHB pill.
   - With Intent on, the prompts run *Select Batter Side → Select Pitch Type → Select Pitch Intent → Select Pitch
     Outcome* (pictures).
   - With Intent off, at 440 and 1280: *Select Batter Side → Select Pitch Type → Select Pitch Outcome*, then today's
     next question.
   - In step 1, a tap on an inside box does nothing; in step 2, a tap on the chart does nothing.
7. **The pitch type stays selected: PASS.**
   - The type chosen on pitch 1 was still selected on pitch 2. After a strikeout, the next batter went from Select Batter
     Side straight to Select Pitch Intent.
   - The type changes only when tapped; voice in this app only speaks, so it can't select a type.
   - A pitching change (Discard and switch to the other pitcher) cleared it: the type was null and the new pitcher went
     to the start questions.
8. **New batters: PASS.** Each of these went to Select Batter Side with no batter drawn:
   - a strikeout (batter 1 → 2);
   - a walk (2 → 3);
   - a hit by pitch (3 → 4);
   - a ball in play (a fly out to centre, 4 → 5).

   A caught stealing that isn't the third out kept batter 4, his side and his 0-1 count.
9. **Killed tab, and never a pitch without a side: PASS.**
   - With batter 5 at step 1, the page was reloaded. Resume was offered, and it came back to Select Batter Side with
     the outside columns pulsing. The pitch type was kept (question 9).
   - A Live Game pitch can't be saved without a side:
     - in step 1 a chart tap only chooses the side;
     - `recordGameResult` refuses with no side (tried in step 1: 0 pitches);
     - a started game is saved in the draft with `batterSides`.
10. **The RHB / LHB button: PASS.** At 390, 440, 820 and 1280:
    - in a Live Game there's no pill and no "vs RHB / vs LHB" text, and the prompt is centred;
    - in a bullpen the pill is there and unchanged ("vs RHB").
11. **Saved data equal before and after: PASS.**
    - The same 11-pitch game (two pitch types, a strikeout, a walk, a foul) was charted and saved to staging on
      today's main and on this branch, with the same test pitcher.
    - The `pitches` rows are identical, compared row by row on every column except the id, the session id and the
      timestamp (`ts`): md5 `ab515a40…` both.
    - `session_stats` is identical: md5 `b324392d…` both.
    - Reports and Trends are built from these two tables.
12. **Reduced motion, version, log: PASS.**
    - With `prefers-reduced-motion: reduce`, step 1's columns have no animation and a steady 0.3 tint. Step 2's pitch
      choices have no animation and a steady accent tint (`0.12`).
    - The cache is bumped to v354, STATUS.md has the entry, and the pre-push checks run on push.

**Also checked:**
- **Q6, a wrong side:** tapping the batter, or More → Change batter side, went back to step 1. Picking the other column
  changed this at-bat's pitches (L L → R R) and no earlier at-bat.
- **Q7, a pitching change mid at-bat:** at 1-1 the hand-off carried the batter's side, and the reliever went straight to
  his next step. At 0-0 the next batter was asked.
- **Q8, a third out on the bases between pitches:** a pickoff for the third out in the middle of an at-bat. The same
  batter and side lead off inning 2, with the count reset from 0-1 to 0-0.
- **Back across an at-bat:** restores the previous batter, his side and his count.

## Deviations and notes

- **Back across an at-bat also forgets the sides chosen for the batters after it,** so the next new batter is asked
  again. Without it, a side picked before the Back was reused for a different plate appearance.
- **A started game is now offered for Resume even before its first pitch.** That's what lets a killed tab during the
  first Select Batter Side come back to it.
- **Correcting a side rescores that batter's pitches for Relative Accuracy,** the same rescoring the in-session editor
  does when a type changes, because RA cells are per batter side.
- **Fixing the side is off while a play is being entered,** in both More and the batter tap. Back out of the play first.
- **Staging data from this check:**
  - two 11-pitch test games for the U15 Softball test pitcher (main and this branch);
  - two short test games saved by mistake to the baseball test coach's pitcher, before I noticed that tab was signed in
    as that coach.
  - All are on staging only. They can be deleted from History if wanted.
