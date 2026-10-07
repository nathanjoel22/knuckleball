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
