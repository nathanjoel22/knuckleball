# N1 Stage E · evidence (Nov 17, 2026)

Branch `n1e-zone-recap`, cache `kb-shell-v347`. Staging: the migration was applied with `supabase db push`, and the app
was served locally with the staging config. Headless Chrome with device emulation at 390, 820, 1180 and 1440. Pictures
are in `plans/n1e-evidence/`; I scanned them for email addresses and found none.

## The migration (J1)

```
supabase db push --project-ref wpsscxwawgiwmifpjpec   -> Applying migration 20261118000000_n1e_facility_notes.sql
```
- **F1-C2's parked migration.** Staging holds it; its file was put in place only for the push, then removed (not
  committed).
- **Before:** production's and staging's function bodies matched (md5 `5066e463…`). The rollback restores production's
  exact text.
- **After on staging:** SECURITY DEFINER, STABLE, EXECUTE for authenticated / postgres / service_role (unchanged), 32
  policies.
- **`supabase/tests/n1e_facility_notes.sql` on staging** (rolled back):
  - **before the migration:** group coach refused, other coach refused, manager refused, normal head allowed, pitcher
    refused, which is today's rule (`fails 2` against the new expectations);
  - **after:** `(1) group coach, own facility pitcher: allowed | (2) other coach, same side: refused | (3) the manager:
    allowed | (4) normal team head: allowed | (5) the pitcher: refused | (6) policies 32 | fails 0`.

## Every-stage checks

1. **Sizes:**
   - History with zone pictures at 390 (`e1`), 820 (`e9`), 1180 (`e6`) and 1440 (`e8`).
   - The recap at 390 (`e2`, `e4`, `e5`) and 1180 (`e7`), full screen, with no bar or menu showing.
   - Roles: the facility manager (coach), the U15 head coach (normal team), and the DS1 pitcher and U15 pitcher (note
     on Home).
2. **Offline:** see check 27. The recap drew with no signal; the zone pictures come from the loaded stats rows, so
   they need no pitch rows.
3. **Charting:** several bullpens and two games were saved through the app this stage. All synced; no bar or menu
   showed while charting.
4. **Side by side:**

   | Picture | Built | Differences, and why |
   |---|---|---|
   | `e-history-zones.png` | `e1-history-thumbs-390.png` | The zone picture sits at the left of today's bar. The bar keeps its numbers and the report under it (Q1: open, as decided Nov 5), where the drawing shows a compact closed list. |
   | `e-recap.png` | `e2-recap-390.png`, `e7-recap-1180.png` | Same order: header with time, FINAL tag, name, the numbers, plot, per-type lines, callout, Send / View / Done. The plot is History's own (cream zone cells, the plate under it), on the dark surface, rather than the drawing's grid. The "Note to the pitcher" line (J1) sits above Send report for coaches. Top velo shows only with radar readings, as the packet says. |
   | `e-zone-large.png` | the recap's plot | Same dots in the pitcher's view. History's cell style. |

5. `CACHE_VERSION` is `kb-shell-v347`. STATUS.md, CLAUDE.md and Help's step 6 are in this PR, and the pre-push checks
   run at push.

## Stage E checks

**26.** Every History bar has a picture (15 of 15 for Noah Lindqvist). Each picture's cells were compared in code with
History's plot for the same session, which is the report's first plot (Amendment 16, pitcher's view):
- Noah Lindqvist (**LHP**): 6 sessions, pens and games, all SAME;
- Andre Boateng (**RHP**): 6 sessions, all SAME.

**27.**
- **Bullpen recap, online (manager, Andre):**
  - 6 pitches · 67% accuracy, with 4SFB 3 · 67% and CU 3 · 67%.
  - A second pen showed "3 PITCHES | 67% ACCURACY", and its History card showed 3 pitches · 67% accuracy.
- **Game recap:**
  - 2 pitches, 0.0 IP, 0 K, 0 BB, 0 H. Its History card said "0.0 IP 2 PITCHES 0 K 0 BB 0 H".
  - Found and fixed: the count-up could stop partway when the browser pauses animation (headless here; a phone app in
    the background). A 700 ms fallback now always lands on the real number.
- **Offline (manager):**
  - The recap drew, with "Available once this session has synced." (`e4`).
  - A note was typed, then Send report → History at that session, which said "Available once this session has synced."
  - The note waited on the device. Back online: the session synced, the note saved (queue 0), and it shows in History.
- **Done** → History. **View report** → the session in History.
- **Send report on a synced session** calls today's `sendSessionReport`. It wasn't pressed for real (no email).
- **Notes:**
  - **Facility:** the manager's recap note for Andre Boateng saved after sync and shows in History. On Andre's Home:
    "JORDAN THAYER · NOV 17 “N1 Stage E facility note: nice work on the curve.”" (`e3`).
  - **Normal team:** the U15 coach's recap note shows on the U15 pitcher's Home ("U15 SOFTBALL COACH · NOV 17 …").
- **Save and switch:** 3 pitches for Noah, then Save and switch to Andre. No recap, Andre's start questions, outbox 0.
- **Callout:** "Best 4SFB accuracy in 6 sessions" appeared for a Noah pen that beat his previous 5 (`e7`). "New top
  velo" fires only with radar readings above every earlier one; none were charted this stage.

**28.** With `prefers-reduced-motion: reduce`, the recap gets `still`, the tag's animation is `none`, and the numbers are
drawn at their final values.

## Staging test data from this stage

- Bullpens for Andre Boateng (several) and Noah Lindqvist (one), plus a 2-pitch game for Andre.
- Two notes on Andre's pens: "N1 Stage E facility note…" and "Offline note: stay tall."
- A pen and a note ("Normal-team recap note…") for the U15 pitcher.
