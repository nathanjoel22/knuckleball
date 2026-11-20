# F2 Stage 2 · The roster's top row and Assign Pitchers · evidence (Nov 20, 2026)

Branch `f2-stage2` (on top of Stage H), cache `kb-shell-v368`. No database: Assign Pitchers uses Manage's server path
(`facAct` → `move_between_groups` / `add_to_group`).

Tested on staging's demo facility with the local site. Pictures aren't committed: the demo roster holds real people's
names.

## Done when

4. **Search facility on the left and Join Codes on the right; Join Codes opens the two choices: PASS.**
   - **Manager, phone (440):** `["Search facility", "Join Codes", "Assign Pitchers"]`. Search is 275 px wide at x=16;
     Join Codes is at x=299, with Assign Pitchers under it. The old join-code buttons are gone from the list.
   - **iPad 820:** search at x=88 (479 px wide); Join Codes and Assign Pitchers side by side at x=575 and x=679, on the
     same row.
   - **Laptop 1440:** the Roster heading, then the row spanning both columns (search 739 px, Join Codes at x=1119), then
     the list and the pitcher's page.
   - **The Join Codes sheet:** the manager gets `["Show my join code", "All join codes"]`; a pitching coach gets
     `["Show my join code"]`. Each opens the same code sheet as before.
   - **Search:**
     - It filters what this roster already shows: a 3-letter query shows 2 of 10 rows (2 expected, all matching).
     - Focus stays in the box while typing.
     - "zzzq" says "No pitcher on the roster matches."
     - Clearing it shows all 10.
     - Stage 1 adds facility-wide results.
5. **Assign Pitchers: PASS.**
   - The manager taps Assign Pitchers ("Tap a pitcher to assign them to a coach."), then taps a pitcher. The sheet names
     the pitcher, lists every coach with the current one marked "current" (and not pickable), and shows Confirm and
     Cancel.
   - Pick another coach and Confirm: "<pitcher> is now with <coach>." The pitcher's groups are now just the new coach's
     (a move, not an add).
   - **After signing out and back in:** still with the new coach. The demo pitcher was then moved back.
   - **A pitching coach doesn't see Assign Pitchers:** their row is `["Search facility", "Join Codes"]`.
   - A pitcher with no coach is added (`add_to_group`). A pitcher in two coaches' groups is asked "Moving from" first.
   - Manage's "Choose a coach…" stays. The chat thread follows the move as it already did (unchanged).
