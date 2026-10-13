# D2 preconditions report (Oct 13, 2026)

Spec: `plans/d2-broadcast-rebrand.md` (GitHub main). Read against branch `d1-design-standardization` (D1 Stage 1, v227), which isn't merged yet. **No code changed.** Every number below comes from a grep or from Chrome (true 320 / 375 px viewports, both sports, 38 app screens each).

## Summary: what Joel needs to decide

1. **Sign-in pages between Stage A and Stage C.** The target file has no dark scope, but the 11 sign-in pages stay dark until Stage C. *Proposed:* in Stage A they take the new brand colors on the dark look (page `--brand-bg`, card `--brand-bg-2`, gold accent), then turn light in Stage C.
2. **Two token names I got wrong in D1 Stage 1.** D1's text says the focus ring is `--focus` and motion is `--duration-*` / `--ease-*`. I shipped `--focus-ring` and `--motion-fast` / `--motion-spring`. *Proposed:* rename them to D1's names in Stage A. Nothing uses them yet.
3. **Gold text on light backgrounds.** It fails today and gets worse with the new gold. Two places: the roster's throws tag and History's "logged by coach" tag (1.6–2.1:1 now, 1.7:1 at `#FFB81C`). *Proposed:* both use `--accent-ink` (5.9:1) in Stage A.
4. **The pitch tray's "3½ types".** Today it shows **2.9 types at 375 px and 2.2 at 320**, not 3½. U13's trays are wider than the old chips. Stage B keeps today's count unless you want 3½. Getting there would mean narrower segments, which is a layout change.
5. **Already tight at 320 px today:** the Live Game status bar overflows by 7 px, cutting off the ⏱ button. Archivo is wider, so Stage B will make this worse unless it's fixed. *Proposed:* fix it in Stage B (status-bar padding or gap) and treat it as allowed, not "a new clip".
6. **Report softball approach.** I recommend the spec's preferred option, a variable block inside each report (§5).
7. **readableTextOn() has no callers.** U13 (Oct 9) removed the filled pitch chips, so nothing calls it. *Proposed:* delete it in Stage A; the spec's slot 1 / slot 7 check then applies to the dots and underlines (§6).
8. **A permanent palette check.** The D1 check was a one-off script, not something in the repo. *Proposed:* add it to `.githooks/pre-push` so a mismatched palette can't be pushed.

## 1. Token names: D1 Stage 1 vs the target file

D1's names win (spec). Each mismatch, with how it maps:

**In the target, not in tokens.css → added in Stage A:**
- **Brand:** `--brand-bg-deep`, `--brand-bg-2`, `--brand-line`, `--brand-mid`, `--brand-soft` (new jobs: the scoreboard cells, raised dark areas, hairlines on dark, links and focus on light, avatars).
- **Light-scope `--card-2`** (today only the dark scope has it).
- **On-colors:** `--on-accent` (`--btn-on-primary` points to it), `--on-danger`.
- **Flash:** `--flash-fg`. The tracker already sets a local `--flash-fg:#F1ECDD` on `.zone-cell-flash`. It's the same job, so the local definition goes and the token takes over.
- **Rings and shadows:** `--ring-select`, `--ring-target`, `--shadow-segment`, `--shadow-pop`.
- **Geometry:** `--radius-segment`, `--cut`, `--dock-pill`.
- **Scales:** `--s-*` (spacing), `--t-*` (type), `--lh-*`, `--tr-*`. These are defined in Stage A but used from Stage B/C.
- **Focus and motion:** `--focus`, `--duration-*`, `--ease-*` (replace my `--focus-ring` / `--motion-*`, decision 2).

**In tokens.css, not in the target:**
- **Kept** (in use, no target equivalent):
  - `--btn-h` (U13);
  - `--game-chip-border` and `--game-panel-bg` (the Live Game panel). New values: `--surface-border` and `--card-2`.
- **Mapped to a target name:**
  - `--on-dark-line` → `--brand-line` (one use, report.html's top bar);
  - `--scrim-notice` → `--scrim`.
- **Retired with the stage that replaces them:**
  - `--text-*`, 27 names → the nine `--t-*` (Stage B);
  - `--font-report`, `--font-system` (Stage B / D);
  - `--radius-*` and `--shadow-*` inventories → the target's five radii and three shadows (Stage C).

**Softball:** tokens.css sets its own softball `--btn-primary*` (`#E27BA2`, white text) and `--chooser*`. In the target, both follow `--accent` / `--brand-bg` in every sport, so those softball overrides are removed. `--accent-game` becomes `var(--accent)`, one gold.

**The dark scope** (`html[data-theme="dark"]`) isn't in the target. It stays through Stage C (decision 1) and is deleted at Stage C's end, as the spec says.

**The target's base rules** (`body`, `.display`, `.num`, `.tnum`, `.label`, `.wordmark`, `:focus-visible`) go in `css/components.css`, not `tokens.css`. `tokens.css` stays variables-only, because `report.html` loads it and draws every frozen report inside its own page (§5). I checked all 24 versions of the report code: no report ever used those class names as CSS classes, and each report's own `body` rule comes later and wins. So even loaded there, they wouldn't change an old report. Keeping them out of `tokens.css` makes that a rule rather than a check.

## 2. Hard-coded colors left after D1 Stage 1

130 lines in total; the full list is in the appendix. By file:

| File | Field art (stays) | Other |
|---|---|---|
| `bullpen-tracker.html` | 53 | 86 |
| `buttons.css` | — | 20 (white / black alphas for the glass segment and shadows) |
| `index.html` | — | 29 (the "Which sport?" cards in fixed sport colors, and the ball icons) |
| `privacy.html`, `terms.html` | — | 17 each (their own blocks; changed only with Joel's approval) |
| `report.html` | — | 1 (the footer's `#527065`) |

**The spec's named old hexes, still in rules:**
- **`bullpen-tracker.html`:**
  - `.acct-chip-baseball` / `-softball` (1200–1201), the account switcher's fixed sport chips: `#0F241B`, `#234B6E`;
  - the leaderboard medal fill (10002): `#E8A83D`;
  - `.g5-baselbl` (1447): `#111`;
  - the flash's local `--flash-fg` (1051): `#F1ECDD`.
- **`index.html`:** the sport cards (124–133) and the softball ball icon (204): `#C9A227`.
- **`privacy.html` / `terms.html`:** their own variable blocks.

**Old-gold and old-green tints written as rgba** (they follow the old accent, so they become tokens in Stage A):
- `rgba(201,162,39,…)`, Live Game field picks: 1433, 1437, 1441, 1475;
- `rgba(193,122,69,…)`, warning tints: 335, 351, 366, 1112, 1126 → `--warning-tint`;
- `rgba(16,40,28,…)` / `rgba(27,53,80,…)`, field shading per sport: 1433–1445, 1476;
- `rgba(232,243,236,…)` / `rgba(234,244,251,…)`, the Live Game panel header: 886–890, 145–146;
- the dock's `rgba(15,36,27,.72)` / `rgba(35,75,110,.74)` (997, 999) → `--dock-bg`;
- the notice backdrop (1182–1183) → `--scrim` and `--shadow-modal`.

**Left alone** (out of scope, or data rather than theme):
- the field art (`--gg-*`, mower stripes, `G5_BALL_SVG`);
- the History plot's home plate (5881–5897, our own drawing);
- the softball ball yellow `#F3E04B` and the base-on yellow `#F4C430`;
- the relative-accuracy tag `#7C9CBF` (9280–9281). This is old pitch slot 5's blue used as a text color, and it becomes `--brand-mid`.

## 3. Fonts: where each face is used today, and what it becomes

| File | Teko | Plex Sans | Plex Mono | Georgia | System stack | Black Ops One |
|---|---|---|---|---|---|---|
| `bullpen-tracker.html` | 12 | 2 | 19 (+60 `class="mono"`) | — | — | 3 |
| 10 sign-in pages | 2 each (parent-signup 3) | 1 each | accept-invite 2 | — | — | 2 each |
| `index.html` | 3 | 1 | — | — | — | 2 |
| `privacy.html`, `terms.html` | 2 each | 1 each | — | — | 2 each | — |
| `report.html` | — | — | — | — | 6 | — |
| `send-session-report/template.ts` | — | — | — | 2 | — | — |
| `send-session-report/svg.ts` | — | — | — | 4 | — | — |

**The tracker, per the mapping table:**
- **Teko 600 → Big Shoulders 800, uppercase:**
  - `.display` (every section heading);
  - `.pitcher-header h2` (the pitcher's name, 44 px).
- **Teko 400/500 → Big Shoulders 700, tabular figures:**
  - `.roster-item-num`, `.uniform-locked-num`, `.pitch-counter-num`, `.stat-num`, `.meta-num`, `.lb-rank`.
- **Teko 700 → Big Shoulders 800:** the strike / ball flash letter (829, 1061).
- **Plex Mono → Archivo 700 + `.tnum`:**
  - `.mono` (pitch log, velocities, zone numbers);
  - the invite link (322), `.velo` input (642), `.scorebook-cell-code`, zone numbers (1067), the velocity strip (1073), `.lb-num`, `.lb-val`.

  Note: some of these are weight 500/600 today, and the table makes them all 700, which is a little bolder and wider. That's covered by the width check in §4.
- **Plex Sans → Archivo, same weights:** everything else.

**Reports:** Georgia appears in `template.ts` (body and headings) and `svg.ts` (chart labels). `template_game.ts`, `connect.ts` and `diamond.ts` reuse those. In Stage D they get the new font stacks, with system fallbacks.

## 4. Text that's tight today (Chrome, true viewport widths)

Free space = the row's width minus what its contents need. The worst screen of 38 per width, both sports:

| Item | 320 px | 375 px |
|---|---|---|
| Page tabs (4) | 18 px free (6%) | 73 px free (22%) |
| Phone Live Game status bar | **−7 px: overflows; the ⏱ button is cut off** | 6 px free (2%) |
| Phone bullpen status bar | 115 px free | ≥ 115 px |
| Pitch tray | 2.2 types visible | 2.9 types visible |
| Velocity strip | one line, 6 px to spare in its tightest square ("100") | 16 px |
| Chart caption / field caption / phone hint | one line (pills sized to their text) | one line |
| Roster names ("Jackson Esbenshade", the longest) | 95 px free | 150 px free |
| Coach dock | fits (equal-width buttons; labels slightly wider than their share at 320) | 43 px free |
| Already cut off on purpose (ellipsis) | the session header's team name ("SC Baseball" 88 → 73 px) | — |

**What this means for Stage B:**
- **The phone Live Game status bar** has no room at 375 and is already over at 320. It needs a fix in Stage B (decision 5).
- **The page tabs at 320** have 6% to spare. Archivo plus uppercase could use that up, so Stage B re-measures them, and U9's shorter "Player" label stays.
- **Everything else** has room.

## 5. Session reports: the softball swap, and how old reports stay frozen

**Today:** `themedCss()` (`helpers.ts`) makes a softball report by find-and-replacing ten baseball hexes in the finished HTML (`SOFTBALL_THEME_SWAP`), across CSS and drawn charts alike. Baseball reports skip it and are byte-identical.

**Is a rebuilt swap collision-free?** Checked with the new values:
- No target is also a source.
- No softball pitch color equals a baseball theme color.
- Baseball pitch 1 (`#FFB81C`) equals the gold accent. That's harmless, since softball reports draw only softball pitch colors.

So a rebuilt swap would work. It would need new entries for the two chart-only greys (`#5B6B61`, `#7C8C82`) too.

**Recommendation: the variable block (the spec's preferred option).**
- Stage D touches every color line in the report code anyway: 32 in `template.ts`, 7 in `template_game.ts`, 24 in `svg.ts`, 34 in `diamond.ts`. Writing them as `var(--…)`, with one baseball block and one softball block in the report's own CSS, costs about the same.
- It ends the hand-kept hex table.
- There's one wrinkle: SVG `fill="…"` / `stroke="…"` attributes can't read variables (14 in `svg.ts`, 19 in `diamond.ts`, the field art excluded). Those become `style="fill:var(--…)"`.
- `from_rows.ts` uses the same builders, so it follows automatically.

**Frozen reports, the rule that keeps them safe:** `report.html` draws a stored report inside its own page, not in a frame (Sept 30, for iOS printing). Anything `report.html` loads therefore sits in the same page as every old report. I checked all 24 versions of the report code: every variable a report uses is defined inside that report, so nothing `report.html` loads (including D1 Stage 1's `tokens.css`) changes an old report.

Stage D keeps it that way: **a new report defines every variable it uses inside its own file and never reads `tokens.css`.** Otherwise a later token change would restyle reports already sent, and the downloaded file would look different from the page.

## 6. The palette check and readableTextOn()

- **The palette check:** in D1 Stage 1 it was a one-off script. It confirmed `--pitch-1..8` = `SPORTS[sport].palette` = `SPORT_PALETTE_HEX` in order, both sports, and isn't in the repo. *Proposed:* a small check in `.githooks/pre-push`, which already runs on every push (decision 8).
- **`readableTextOn()` (`bullpen-tracker.html:1993`)** has no callers since U13 (`163cb70`, Oct 9), which replaced the filled pitch chips with white segments, a color underline and a dot. Pitch colors now appear only as marks (dots, underlines, chart dots, report legend swatches), never behind text. *Proposed:* delete it (decision 7).
- **Pitch colors as marks on white** (3:1 is the guideline for marks):

| Palette | Slots below 3:1 on white |
|---|---|
| Baseball today | 1, 2, 5, 6, 7, 8 (slot 7 1.8:1, slot 1 2.1:1) |
| Baseball D2 | 1, 2, 3, 7, 8 (**slot 7 `#F2E14C` 1.3:1, slot 1 `#FFB81C` 1.7:1**) |
| Softball today | 1, 2, 4, 5, 6 |
| Softball D2 | 2, 4, 5 |

  This isn't new (today's baseball palette has six slots under 3:1), but the D2 yellow and gold are fainter on white than today's. Chart dots carry a white outline, which doesn't help on white. *Option for Joel* (not proposed as part of D2 unless you want it): a thin `--ink` 25% ring on pitch dots, so pale colors read on white.

**Text pairs from the target file:** all pass AA. Checked:

| Pair | Ratio |
|---|---|
| ink on page | 17.2 |
| faint text on white / on soft fill | 6.2 / 5.3 |
| faint on brand | 5.9 |
| accent text on white | 5.9 |
| ink on gold | 10.9 |
| danger on soft fill | 4.8 |
| white on danger | 5.7 |
| warning on white | 5.4 |
| success on white | 5.0 |
| links / focus on white | 8.3 |
| softball: ink on page | 14.5 |
| softball: faint on white / on soft fill | 5.3 / 4.6 |
| softball: faint on brand | 5.5 |
| softball: pink text | 6.7 |
| softball: navy on pink | 5.1 |
| softball: links | 6.9 |
| white on strike / ball flash | 4.4 / 4.2 (pass as large text, 24 px bold) |
| white on pink | 3.1 (fails as normal text, so it's never used: the target puts navy on pink) |

## Appendix: hard-coded color lines (non-field), file:line

- `bullpen-tracker.html`:
  - 145–146, 297, 335, 351, 366, 531–532, 539–540, 886–890, 997–1015 (dock);
  - 1051, 1112, 1126, 1148, 1176, 1182–1183, 1200–1201, 1414–1415, 1425, 1430–1448, 1475–1476, 1496–1510 (Live Game field UI);
  - 5860–5897 (History plot);
  - 8451, 8457, 9280–9281, 10002.
- `index.html`: 119–133, 196–205.
- `report.html`: 271.
- `buttons.css`: 20 white / black alpha values.
- `privacy.html` / `terms.html`: their variable blocks.
