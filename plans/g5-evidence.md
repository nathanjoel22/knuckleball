# G5 evidence (in progress)

Packet: `plans/g5-live-game-diamond.md` (GitHub, Oct 6 2026). Precondition report given Oct 6; Joel's answers:

1. iPad/laptop: (a) the square is sized so its diamond fits the screen; diamond and chart cells are the same size. **Changed Oct 6 (Joel, option 2):** with velocity moved into the chart, the chart keeps its full size and the diamond shrinks to fit the screen with its own cells.
2. Phone: today's 340px footprint (cells ≈ 44.4px at 390 and 375).
3. The Live Game chart keeps the charter's chosen perspective (U12); reports are always the pitcher's view.
4. Old games: fielder → box, for now — C 1, P 17, 1B 24, 3B 18, 2B 22, SS 20, LF 7, CF 21, RF 11.
5. `bb_x`/`bb_y` stay NULL in new games; `spray_box` is the record (nothing reads `bb_x`/`bb_y`).
6. 1B/3B are drawn just inside the lines (boxes 24/18); the bases screen's tap boxes are 15 and 3.
7. Add out adds to the pitch being charted (K + caught stealing = 2); reaching 3 outs skips the bases screen and ends the half-inning.
8. The extra-inning "Start with runner on 2B?" prompt stays, as a Yes/No on the square chart.

Migration `20261007000000_g5_spray_box.sql`: generated from the live `sync_session` (identical on staging and
production); the only function change is the two new columns in the pitches insert.

## Migration on staging (Oct 6 2026, Joel: "apply to staging")

Applied `20261007000000_g5_spray_box.sql`; policies 34 → 34. `supabase/tests/g5_migration_acceptance.sql`
(rolled back): (1) a game through `sync_session` → saved, 3 pitches; stored ball -/-/-, single box 22
runners_after 1 outs 0, groundout DP box 19 runners_after 0 outs 2; (2) bullpen pitch with spray_box or
runners_after → refused (`pitches_g5_fields_check`); (3) box 0, box 26, bases 8 → refused; (4) policies 34.

## Client + reports (harness, Oct 6 2026; app v154)

- Flows (acceptance 3, stored pitch fields): ball 1-0; called / swinging strike 0-1; foul at 0-1 → 0-2, at 0-2 stays;
  K looking with a runner on 1st → outs_on_play 1, no bases screen, runner stays, Set; K swinging → 1 out; walk
  with 1st+2nd → bases screen pre-filled loaded (7), saved runners_after 7; single LD box 22 with a runner on 1st →
  runners_after 3; groundout DP (O·GB·19·Add out·bases) → outs_on_play 2, outs +2; error (E·GB·18) → 0 outs,
  batter on 1st; foul pop-up caught in box 4 → 1 out, spray_box 4; a third out on the play skips the bases screen
  and ends the half-inning; K + Add out (caught stealing) with 1 out → 3 outs, inning 2. runner_advances,
  runs_scored, batter_to, hit_type, fielder NULL on every G5 row.
- Box mapping (acceptance 2): each of the 25 cells tapped on the location step stores Joel's number — (0,0)=5 (0,1)=6
  (0,2)=7 (0,3)=8 (0,4)=9 (1,0)=4 (1,1)=19 (1,2)=20 (1,3)=21 (1,4)=10 (2,0)=3 (2,1)=18 (2,2)=25 (2,3)=22 (2,4)=11
  (3,0)=2 (3,1)=17 (3,2)=24 (3,3)=23 (3,4)=12 (4,0)=1 (4,1)=16 (4,2)=15 (4,3)=14 (4,4)=13.
- Acceptance 4: a K for the 3rd out ends the 9th (count 0-0, bases clear, Windup); the 10th (college) asks "start
  with a runner on 2B?" under the chart and refuses chart taps until answered; Yes → runner on 2nd, Set,
  tiebreak_runner event.
- Acceptance 6: Back from the bases screen steps bases → where → how → hoe → what → chart, nothing saved; Undo after
  a single restores the runners (3 → 1), the pitch and the at-bat.
- Resume: a draft saved on the location step reopens on it and finishes (fly out, box 8).
- Sizes (real page CSS, headless Chrome): 390 and 375 — chart cells 64px, diamond cells 44px (340px footprint,
  Joel's choice); iPad landscape 1180 — chart 85px = diamond 85px (diamond box 624 = 441 × √2).
  Screenshots of every screen at 390, 375 and iPad, both sports: scratchpad contact sheets (to be shown to Joel).
- Reports: spray charts (all / by result / by batted-ball type / by pitch type), what led to it (per box, per
  batted-ball type, pitch type × result, deciding pitch), base states (and by pitch type); counts hand-checked on
  a fixture game. Old games are placed by fielder (C 1, P 17, 1B 24, 3B 18, 2B 22, SS 20, LF 7, CF 21, RF 11).
  The 1B/2B/3B/HR column shows only when a hit has a hit type. App ↔ from_rows payload parity unchanged (5 staging
  sessions identical).

## Joel's changes after the first look (Oct 6)

- Velocity after the roll back sits in the chart: the bar on the second-to-last row, Reset + Next pitch on the last
  row, on every layout; nothing below the chart.
- iPad/laptop (option 2): the chart keeps its full size and the diamond fits the screen. At 1180×820: chart 550px
  (106px cells; was 444 under option a); diamond box 628px, 85px cells, bottom at 775 of 820 (no scrolling). The
  roll scales between the two sizes.
- Joel's iPhone 14 (Oct 7): after the roll back the chart collapsed to a tiny square under the velocity bar. Cause:
  the one-draw roll-back wrapper shrink-wrapped, and the phone chart is width:100% of its parent; my earlier
  renders skipped that draw. Fixed (the wrapper takes the full width); re-rendered with the animation draw at
  390 and 375 — full-size chart, bar on row 4, Reset + Next pitch on row 5. v155.
- Joel, Oct 7: on iPad / laptop the account button moved into the pitcher header's row, so the name, photo and pitch
  types sit level with the Knuckleball logo and the chart / diamond gain that row's height (phones unchanged;
  Profile and Leaderboard keep the separate row). Full-page render at 1180×820: header level with the logo block,
  diamond larger and fully on screen. v156.
- Joel, Oct 7 (phones): the first flip rolls into a 3×3 — the infield (17, 18, 24, 25) and the five boxes above it
  (19–23) — whose cells are the chart's own size; the prompts keep the 5×5 pattern shifted into it (Looking 20,
  Foul 22; Ball 19, Swing 25, In Play 23; E 19, H 25, O 23; Pop 20, Fly 22, Bunt 19, LD 25, GB 23). The location
  and bases questions zoom out to the 5×5; Next rolls back to the chart. Measured: chart 64px, 3×3 64px at 390 and
  375; 5×5 location 44px. iPad / laptop unchanged (5×5 throughout). Flow, box map, tiebreak, resume tests re-run:
  unchanged. v157.

## Revert to a card flip and an upright field (Joel, Oct 7)

Joel replaced the 45° roll (and the phone 3×3 / zoom) with a card flip: the field is the back of the pitch chart —
the same square and the same 25 boxes in every layout. Demo approved first (artifact BQgxSMrV5KszUoXMV1Mt17).
Field geometry (Joel): home plate mid box 15; foul lines diagonally through 17 and 3, and 23 and 11; the fence arc
from box 4's top-left corner, peaking mid box 7, to box 10's top-right corner; 1B mid 23, 2B mid 25, 3B mid 17;
the dirt from box 17's top-left corner, peaking mid 25, to box 23's top-right corner. Added (not specified): a
grass diamond inside the bases, the mound mid 24 (softball: all dirt, pitcher's circle).
Interim until Joel reassigns the prompts: prompts keep their box numbers; the bases screen taps 17 / 25 / 23 (the
drawn bases); "Next pitch" (radar off) moves to 24; + Add out, Next and ‹ Back sit in a row under the field.
Old-game fielder → box re-placed for the upright field, to confirm: C 15, P 24, 1B 23, 2B 22, SS 18, 3B 17, LF 19,
CF 20, RF 21. Reports draw the same upright field. Flow / box map / tiebreak / resume tests re-run with the new
base boxes: all pass. v158. send-session-report + rerender-reports redeployed to staging.
- Joel, Oct 7: 2B moved to the bottom of box 25, clear of the outfield grass (the grass diamond shrinks under it);
  What happened? → Foul 4, Looking 19, Swing 20, Ball 21, In Play 10. Same 2B in the reports' field. v159.
- Joel, Oct 7: Foul asks Foul Tip (box 19) or Foul Out (box 21) — boxes my choice, to confirm. Foul Tip records a
  plain foul (strike below two, count stays at two; true foul tips remain unmodeled per the spec — to confirm).
  Foul Out shades foul ground only: boxes 1, 2, 16, 14, 13, 12 whole; 3 and 17 left of the line; 23 and 11 right
  of it; 15 everything outside the triangle from home to its top corners. A tap records an out on a ball in play
  in that box (no batted-ball type), then the bases question pre-filled as before (skipped on the third out).
  Harness: Foul Tip at 0-1 → 0-2, at 0-2 stays; tappable boxes exactly 1,2,3,11,12,13,14,15,16,17,23; foul out
  in 13 with a runner on 1st → out, box 13, runners_after 1; foul out for the third out → inning 2, no bases;
  a fair box ignored; Back: bases → foulout → foul → what → chart, nothing saved. v160.
- Joel confirmed (Oct 7): Foul Tip = any foul ball (as built). Foul Out = any caught foul, including a strike three
  caught by the catcher; stored as an out on a ball in play in its foul box, so it does not count as a K (told Joel).
  After a Foul Out: the runners question, then velocity (radar on), then the chart (as built).
- Joel, Oct 7: H/O/E → E 4, H 20, O 10; "What type of contact?" → Bunt 4, Pop 6, LD 20, Fly 8, GB 10. Looking, Swing
  and Ball go straight to velocity (ball four still asks the runners first, per the spec). Harness: every button
  in its box; flow and foul tests re-run. v161.
- Joel, Oct 7: What happened? → Foul 4, Looking 6, Swing 20, Ball 8, In Play 10. v162.
- Joel, Oct 7: a ball in play's location shades fair ground only — the exact opposite of Foul Out (boxes 4–10, 18–22,
  24, 25 whole; the fair side of the line in 3, 17, 23, 11; in 15 only the triangle from home up). All-foul boxes
  (1, 2, 12–14, 16) are not tappable there. Harness: the two shadings together cover all 25 boxes, with 3, 11, 15,
  17, 23 split into opposite halves; box 13 ignored on the location step; box 15 accepted. Flow + foul tests re-run
  (the old all-25-box location test retired: foul boxes are reached through Foul Out now). v163.
- Joel, Oct 7: nothing above the fence arc shades on the location step; the top row (5–9) shades only the strip below
  the arc (clip polygons computed from the arc: circle centre (250,700), r 650, in the field's 100-a-box units).
  Area over the fence shades on neither screen. v164.
- Joel, Oct 7: on a fly-ball hit, box 13 shows "HR?" while the field flashes; it switches the flashing to the area
  above the fence (top row above the arc), where a tap records the home run: in play, hit, hit_type HR, fly, the
  box; the bases go empty with no runners question (my choices, to confirm: HR? only on H + Fly; no runners
  question after a homer). Report at-bat log reads "HR · Fly · box 7". Harness: HR? only on H+Fly; over-the-fence
  boxes 5–9 only; HR stored as above, runners_after 0, delivery back to Windup, next screen velocity; Back returns
  to the location step with nothing saved. v165; send-session-report redeployed to staging.
- Joel confirmed (Oct 7): HR? on a fly ball OR a line drive (hits only); no runners question after a home run. Harness: HR? shown on H+LD, still not on an out. v166.
- Joel, Oct 7: What happened? → Foul 4, Looking 2, Swing 1, Ball 8, In Play 10. v167.
- Joel, Oct 7: buttons moved to the bottom corners — What happened? Swing 1, Looking 2, Foul 14, In Play 13, Ball 12;
  Foul Tip 13, Foul Out 12; E 14, H 13, O 12; Bunt 1, Pop 2, LD 14, Fly 13, GB 12. Harness: every button in its box;
  flow (14/14), foul and HR tests re-run. v168.
