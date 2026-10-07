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

## Migration on staging (Oct 6 2026, Joel: "apply to staging")

Applied `20261007000000_g5_spray_box.sql`; policies 34 → 34. `supabase/tests/g5_migration_acceptance.sql`
(rolled back): (1) a game through `sync_session` → saved, 3 pitches; stored ball -/-/-, single box 22
runners_after 1 outs 0, groundout DP box 19 runners_after 0 outs 2; (2) bullpen pitch with spray_box or
runners_after → refused (`pitches_g5_fields_check`); (3) box 0, box 26, bases 8 → refused; (4) policies 34.
