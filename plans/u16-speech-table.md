# U16 speech table: every cell × batter side

Generated Nov 8, 2026 by running the tracker's own `zoneAreaName` (`bullpen-tracker.html`) over all 25 cells and both
batter sides. The same run compared every string with the names the packet's rules give (`plans/u16-voice-call.md`):
**0 mismatches of 50**.

- **Row / col** are the STORED catcher-frame cell: row 0 is the top row, col 0 is the catcher's left. That is a
  right-handed batter's side, so a righty's "in".
- **#** is the packet's number for that side. It's batter-relative, so 1 is always up and in.
- **What's said** is the pitch's stored full name, then this name ("Slider low and in"). The charting perspective never
  changes it.
- A "no batter" bullpen uses the vs RHB column.
- Two pairs of cells share words by the packet's rule, because a corner and the side cell below or above it touch the same
  zone cell:
  - 10 and 15 are both "up and in plus" (14 / 16 "up and away plus");
  - 21 and 19 are both "low and in plus" (25 / 20 "low and away plus").

| Row | Col | # vs RHB | Said vs RHB | # vs LHB | Said vs LHB |
|---|---|---|---|---|---|
| 0 | 0 | 10 | up and in plus | 14 | up and away plus |
| 0 | 1 | 11 | up and in extra | 13 | up and away extra |
| 0 | 2 | 12 | middle up extra | 12 | middle up extra |
| 0 | 3 | 13 | up and away extra | 11 | up and in extra |
| 0 | 4 | 14 | up and away plus | 10 | up and in plus |
| 1 | 0 | 15 | up and in plus | 16 | up and away plus |
| 1 | 1 | 1 | up and in | 3 | up and away |
| 1 | 2 | 2 | middle up | 2 | middle up |
| 1 | 3 | 3 | up and away | 1 | up and in |
| 1 | 4 | 16 | up and away plus | 15 | up and in plus |
| 2 | 0 | 17 | middle in plus | 18 | middle away plus |
| 2 | 1 | 4 | middle in | 6 | middle away |
| 2 | 2 | 5 | middle middle | 5 | middle middle |
| 2 | 3 | 6 | middle away | 4 | middle in |
| 2 | 4 | 18 | middle away plus | 17 | middle in plus |
| 3 | 0 | 19 | low and in plus | 20 | low and away plus |
| 3 | 1 | 7 | low and in | 9 | low and away |
| 3 | 2 | 8 | middle low | 8 | middle low |
| 3 | 3 | 9 | low and away | 7 | low and in |
| 3 | 4 | 20 | low and away plus | 19 | low and in plus |
| 4 | 0 | 21 | low and in plus | 25 | low and away plus |
| 4 | 1 | 22 | low and in extra | 24 | low and away extra |
| 4 | 2 | 23 | middle low extra | 23 | middle low extra |
| 4 | 3 | 24 | low and away extra | 22 | low and in extra |
| 4 | 4 | 25 | low and away plus | 21 | low and in plus |
