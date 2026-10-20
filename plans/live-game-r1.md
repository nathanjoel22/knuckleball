# Live Game Release 1 — gaps fixed before shipping `live-game-back-more`

Joel, Oct 20 2026. No packet: Joel's choices on the gaps review (the "Live Game Gaps" page, 42 gaps checked against
`live-game-back-more` v259), then four layout answers. Release 2 (C2, C4, E1, E2, E3, E6, E7, F5) is a separate,
later release. Skipped: B5, B8, C3, C5, C6, C7, D1-D5, F2, F3, F4, F6. Later: F1.

## In Release 1

| ID | What | Decision |
|----|------|----------|
| A1 | Singles, doubles, triples saved | After H: **1B · 2B · 3B · HR** in the row (slots 2-5), "What kind of hit?". HR leaves the location row (Joel's note). The batter is put on that base automatically. |
| C1 | Inside-the-park HR | HR → contact → location: **OF** = inside the park (outfield box), **Fence** = over the fence (the area above the arc). Batter scores either way. |
| A2 | Fielder's choice | **FC · E · H · O** (FC column 1, E/H/O unchanged in 2-4). FC → contact → location → runners with the batter already on 1B; Next waits until a runner is called out. Saved as `in_play_outcome = 'fc'` (already allowed). |
| A3 | Two-strike foul bunt = K | Counted as a K in the app, `compute_game_summary` and the report. Changes G1b decision 11's stat treatment (Joel). |
| A4 | Runner moves kept | `runner_advances` saved on walks, HBP, hits, errors, FC (forced moves + every drag), and `batter_to` saved. |
| A5 | Reliever's IP | Moving the inning in the top bar shifts the carried-over outs, so a reliever's outs recorded are only his own. |
| A6 | Final inning | The saved final inning is the last inning a pitch or event happened in, not the one shown after a third out. |
| A7 | History card | Counts what the report counts (auto K / BB, the bunt K, runs). |
| A8 | Clock violation vs missed pitch | **Clock ball / Clock strike** (no pitch, not in the pitch count) separate from +K / +B (missed pitch, +1). |
| B1-B4 | Dropped 3rd, IBB, catcher's int., batter's int. | In **More → Rare plays ▸** (Joel). |
| B6 | Bunt attempts | **Foul bunt / Missed bunt** in Rare plays (a foul or swinging strike with `bb_type = 'bunt'`). |
| B7 | HBP on a swing | **HBP on swing** in Rare plays: a swinging strike, `pitches.hbp_swing = true` (new column, Joel). |
| C8 | Runner hit by a batted ball | On a hit's runners screen, a runner called out can be "Hit by ball" (`how = 'hit_by_ball'`). |
| E4 | Mid-game start without the hand-off | Start screen: "Starting mid-game?" → inning, outs, runners. Same carry-over as the hand-off. |
| E5 | WP and BK in the pitching line | Report's pitching line gets WP and BK columns. |

## Database (one migration, staging first)

`20261020000000_live_game_r1`: `pitches.hbp_swing` (boolean, games only, only on a swinging strike);
`sync_session` writes it; `compute_game_summary` counts the two-strike foul bunt as a K. Rollback in
`supabase/rollback/`. Policies unchanged.

## Ships with

The rest of `live-game-back-more` (v259 and the Oct 19 migration). Order: production migrations, then the site,
then `send-session-report`.
