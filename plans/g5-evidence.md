# G5 evidence (in progress)

Packet: `plans/g5-live-game-diamond.md` (GitHub, Oct 6 2026). Precondition report given Oct 6; Joel's answers:

1. iPad/laptop: (a) the square is sized so its diamond fits the screen; diamond and chart cells are the same size.
2. Phone: today's 340px footprint (cells ≈ 44.4px at 390 and 375).
3. The Live Game chart keeps the charter's chosen perspective (U12); reports are always the pitcher's view.
4. Old games: fielder → box, for now — C 1, P 17, 1B 24, 3B 18, 2B 22, SS 20, LF 7, CF 21, RF 11.
5. `bb_x`/`bb_y` stay NULL in new games; `spray_box` is the record (nothing reads `bb_x`/`bb_y`).
6. 1B/3B are drawn just inside the lines (boxes 24/18); the bases screen's tap boxes are 15 and 3.
7. Add out adds to the pitch being charted (K + caught stealing = 2); reaching 3 outs skips the bases screen and ends the half-inning.
8. The extra-inning "Start with runner on 2B?" prompt stays, as a Yes/No on the square chart.

Migration `20261007000000_g5_spray_box.sql`: generated from the live `sync_session` (identical on staging and
production); the only function change is the two new columns in the pitches insert.
