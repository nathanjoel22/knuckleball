# D2 Stage B evidence (Oct 13, 2026), branch `d2-broadcast-rebrand`, v230

Spec: `plans/d2-broadcast-rebrand.md` Stage B (D1 Stage 2 with the new faces).

## What changed
- **Fonts:** `vendor/fonts/` gains four variable woff2 files, Archivo and Big Shoulders Display, latin + latin-ext (241 KB). They were downloaded once from the Google Fonts stylesheet URL in the spec, with the licenses `OFL-archivo.txt` and `OFL-bigshoulders.txt` from google/fonts.
- **`fonts.css`:** rewritten with their `@font-face` rules (Archivo declares `font-stretch: 62% 125%`). Black Ops One is unchanged.
- **Removed:** Teko, IBM Plex Sans, IBM Plex Mono (24 files, 412 KB) and their licenses, after a grep showed nothing outside `docs/` names them.
- **`sw.js`:** precaches the four new files; `CACHE_VERSION` v230.
- **Face mapping, every page:**
  - Teko 600 headings (`.display`, the pitcher's name, the "Which sport?" cards, the parent section label, the legal titles) → Big Shoulders 800, uppercase.
  - Teko numbers → Big Shoulders 700 with tabular figures. That's the roster, uniform and stat numbers, the pitch counter, session meta and leaderboard ranks.
  - Teko 700 flash and scorebook letters → Big Shoulders 800.
  - Plex Mono → Archivo 700 with tabular figures. That's `.mono`, the invite link, velocity, zone numbers and counts, scorebook codes, leaderboard values and the email readout.
  - Plex Sans and the system stack → Archivo (`--font-sans`), including report.html's shell (`kb-` classes only), which now loads `fonts.css`.
- **Sizes:** the nine steps on every page. The other pages' 11–42 px values went to the nearest step for their role:
  - labels → 10;
  - meta → 12;
  - body → 14 / 16;
  - headings → 20 / 24 / 32 / 44;
  - index's title 64 / 44 / 32 by screen.
- **Uppercase 10 px labels** (41 rules): Archivo 700, 0.1em, width 90%.
- **Small titles** (profile section heads, leaderboard title): Archivo 800, width 85%.
- **Live Game field captions:** keep 0.02em spacing at 85% width, since they sit in fixed boxes.
- **320 px Live Game status bar** (decision 5): a little tighter below 360 px. It now has 6 px spare (it was 7 px over before Stage B).

## Acceptance
1. **Font census** (every page, `buttons.css`, `tokens.css`, `fonts.css`): Big Shoulders Display, Archivo and Black Ops One only, plus `inherit`. Frozen reports keep their own Georgia, and Stage D restyles new ones.
2. **Size census:** exactly 10 / 12 / 14 / 16 / 20 / 24 / 32 / 44 / 64 px. The Live Game field's scaled captions (`calc(var(--g5c) * …)`) are excepted, as in D1.
3. **Offline:** all 31 precached files exist, the four fonts included. The airplane-mode load on a device is Joel's check.
4. **Nothing new wraps or clips.** Checked before (Stage A, `769b677`) against after:

   | Set | Views |
   |---|---|
   | App states, both sports, 390 / 820 / 1180 | 114 |
   | Pages, both sports, 390 / 820 | 56 |

   - **Clipped or scrolling:** no new sideways page scroll, nothing newly cut off.
   - **"LINE DRIVE" on the field:** went to two lines and was fixed (see above).
   - **Items the check flagged that turned out not to wrap:** the throws tag beside a roster name, the pitch chips' ✕, and the pitch-log line (two lines before and after at 390). The new font sits text on a slightly different baseline, which the check counts as an extra line.
   - **Paragraphs that re-flow** because body text grew (legal 15 → 16, sign-up subtitles 13 → 14). Running text, not UI.
5. **Precondition 4's list at 320 / 375:**

   | Item | 320 px | 375 px |
   |---|---|---|
   | Page tabs, free space | 9 px | 64 px |
   | Live Game status bar, free space | 6 px | 6 px |
   | Pitch tray, types visible | 2.2 (unchanged; decision 4) | 2.9 |
   | Roster names, free space | 88 px | 143 px |
   | Velocity strip, chart captions, coach dock | one line | one line |

6. **Joel's phone check:** pending.

## Notes
- **Decision 7 (spec vs style guide):** the spec's mapping table turns Teko headings into Big Shoulders. The style guide's "title" role (Archivo 800 caps) applies only where the spec names small titles. The mapping table was followed.
- **Already cut off before Stage B, not new:** on iPad portrait (820), the bullpen's "Behind the catcher / Behind the pitcher" tray is too narrow. It was cut off before ("Behind the catche"); Archivo fits it better, but the two labels touch.
- **The legal pages' wordmark** ("KNUCKLEBALL." in the band) is now Big Shoulders caps per the mapping table. Black Ops One there comes with Stage C.
- **`docs/type-sheet-reference.html`** still names Teko and Plex. It's a historical reference and now falls back to system fonts.
