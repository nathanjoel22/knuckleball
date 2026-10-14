# D3 preconditions report (Oct 14, 2026)

Spec: `plans/d3-design-cleanup.md` (GitHub main `5be0c78`; production is `67357ff`, v233). Read against main; **no code changed.** Branch `d3-design-cleanup`.

## Joel's answers (Oct 14, 2026)

1. **Option 2** (eleven steps with `--s-6`): yes.
2. **7px:** the clock was removed from Live Games instead (v234, `live-game-no-clock`). That frees the scoreboard, so **7 → 8 per the spec's table**.
3. **Tray padding:** stays 3px (geometry).
4. **Not-in-table spacing:** as proposed (60 → 64, 80 → 64, 44 → 48; the 1px pill paddings stay).
5. **Shadows:** as proposed.
   - Named tokens for the plates and the target-dot halo.
   - The danger ring is gone with the Live Game clock. It stays only for the bullpen clock's "bad" state, as `--ring-danger`.
   - The dock and dock-pill shadows fold.
6. **`--ring-target-strong`** (3px) for the field's selected boxes: yes.
7. **The phone sheet's top corners at `--radius-dock` (18):** yes.

## Summary: what Joel was asked

1. **Option 2, the eleven-step scale with `--s-6`?** Jordan chose it; it needs your confirmation. I recommend it: the phone screens keep their 6px gaps.
2. **7px → 6, not the table's 8.** Under Option 2, 7 sits exactly between 6 and 8; the tie-down rule gives 6, while the spec's table (written for both options) says 8.
   - The live scoreboard's gap and cell padding are 7px, measured on Oct 13 so the Live Game bar fits Windup and the clock at 375/390 with 6px to spare.
   - At 8 they'd add about 8px and overflow again. At 6 they get 2–3px more room.
   - **Proposed:** 7 → 6 everywhere (14 uses).
3. **Keep the U13 tray's 3px padding** (`buttons.css` `.tray`). It's geometry: the 44px tray holds 38px segments plus 3 + 3, and D1's own target says "3px padding". Moving it to 2 changes every tray.
   - **Proposed:** exempt, with `/* geometry: 44 = 38 + 3 + 3 (U13) */`.
   - Same for the 9-dot icon's 3px dot gap (`.dots9`) and the dock icon/label gap (3px).
4. **Not in the spec's table:**
   - Home empty state 60px → 64;
   - `report.html`'s loading state 80px → 64;
   - index's `.wrap` gap 44px → 48;
   - three 1px vertical pill paddings (`.team-chip`, `.acct-badge`, `.roster-verify-badge` margin): the table's 1 → 2 would make those pills 2px taller, so I'd keep them as 1px geometry.
   - **Proposed:** 60 → 64, 80 → 64, 44 → 48; the 1px pill paddings exempt.
5. **Shadows not in the spec** (all from recent work), each kept as a named token rather than folded:
   - `--ring-plate`: the v232 dark plates behind the chart's button rows and the sign-in Log in, `0 0 0 3px var(--brand-bg)`.
   - `--ring-danger`: the time-to-plate "bad" state, a 2px danger ring.
   - `--ring-halo`: the target dot's 4px accent glow.
   - The coach dock's `0 6px 24px` folds to `--shadow-pop` (a small change).
   - The dock pill's resting `0 2px 8px` folds to `--shadow-segment` (`0 1px 3px`). That's a slightly flatter pill, a U13 state, so it's your call. **Proposed:** fold both.
6. **`--ring-target-strong` exists:** the Live Game field's selected / drop-target boxes use a measured 3px ring (white or gold), not 2px. Proposed as the spec allows.
7. **Optional, from the spec:** the phone sheet's top corners at `--radius-dock` (18) instead of 12. Not proposed unless you want it.

## 1. Dead CSS (deleted, not remapped)

No markup or script uses these, and no script builds their names (searched for name fragments too):
- **From the spec's table:** `.brand-mark` (app), `.game-panel-undo`, `.position-swipe-chip`, `.position-swipe-badge`, `.invite-btn`, `.gg-book`, `.gg-book-play`, `.gg-book-back`, `.gg-book-fix`, `.gg-noread`, `.gg-seq`.
- **Found while counting:** `.gg-cell`, `.gg-clear`, `.gg-btn`, `.gg-velo-readout`, `.gg-fix`, `.gg-on` (all from the pre-G5 Live Game grid).

Because `.gg-book` is dead, the grid family that must share one radius is `.zone-grid`, `.g5-face` and `.g5-field`.

## 2. Corners: every literal `border-radius` (89)

- **Spec table:** 45 rules.
- **Dead:** 13 rules deleted.
- **Already on-scale values that just read the token:** 31 (no visible change).
- **Two corrections to a naive match:** `.velo-slim .velo-cell` is a segment (the table) and `.offline-pill::before` is a dot (circle).
- **New token:** `--radius-mark` (2px), for `.plr-dot` and the report's legend and dots.

file:line | selector | today | becomes
- bullpen-tracker.html:62 | .sess-head | 10px | control
- bullpen-tracker.html:70 | .sess-offline | 50% | not in the table -> circle (already 50%)
- bullpen-tracker.html:73 | .dots9 i | 50% | not in the table -> circle (already 50%)
- bullpen-tracker.html:131 | .velo-slim | 10px | control
- bullpen-tracker.html:137 | .velo-slim .velo-cell | 10px | segment
- bullpen-tracker.html:141 | .sess-sheet | 16px 16px 0 0 | control top
- bullpen-tracker.html:204 | .brand-mark | 2px | DELETE (dead)
- bullpen-tracker.html:220 | .offline-pill | 20px | pill
- bullpen-tracker.html:222 | .offline-pill::before | 50% | circle
- bullpen-tracker.html:234 | .team-select | 6px | control
- bullpen-tracker.html:272 | .roster-item | 6px | segment
- bullpen-tracker.html:290 | .roster-dot | 50% | not in the table -> circle (already 50%)
- bullpen-tracker.html:294 | .roster-dot-count | 9px | not in the table -> segment (already 9)
- bullpen-tracker.html:298 | .tab-dot, .session-dot | 50% | not in the table -> circle (already 50%)
- bullpen-tracker.html:307 | .invite-btn | 6px | DELETE (dead)
- bullpen-tracker.html:314 | .invite-link-panel | 8px | control
- bullpen-tracker.html:319 | .invite-link-text | 5px | segment
- bullpen-tracker.html:333 | .verify-badge | 20px | pill
- bullpen-tracker.html:355 | .change-email-form | 8px | control
- bullpen-tracker.html:370 | .invite-form | 8px | control
- bullpen-tracker.html:414 | .headshot | 50% | not in the table -> circle (already 50%)
- bullpen-tracker.html:434 | .pitch-chip | 20px | pill
- bullpen-tracker.html:526 | .info-q | 50% | not in the table -> circle (already 50%)
- bullpen-tracker.html:529 | .info-tip | 10px | control
- bullpen-tracker.html:530 | .info-note | 10px | control
- bullpen-tracker.html:582 | .roster-name-btn:focus-visible | 8px | control
- bullpen-tracker.html:610 | .pitch-count-badge | 22px | circle
- bullpen-tracker.html:628 | .add-type-inline button | 5px | control
- bullpen-tracker.html:637 | .velo-strip | 8px | control
- bullpen-tracker.html:657 | .game-velo | 10px | control
- bullpen-tracker.html:731 | .kb-batter__label | 999px | not in the table -> pill (already 999px)
- bullpen-tracker.html:760 | .kb-batter__label | 999px | not in the table -> pill (already 999px)
- bullpen-tracker.html:765 | .zone-grid | 6px | cell
- bullpen-tracker.html:778 | .zone-caption | 10px | pill
- bullpen-tracker.html:824 | .scorebook-btn | 8px | control
- bullpen-tracker.html:884 | .game-panel-header | 8px | control
- bullpen-tracker.html:894 | .game-panel-undo | 14px | DELETE (dead)
- bullpen-tracker.html:898 | .game-panel-body | 12px | not in the table -> control (already 12)
- bullpen-tracker.html:921 | .position-swipe-chip | 8px | DELETE (dead)
- bullpen-tracker.html:933 | .position-swipe-badge | 10px | DELETE (dead)
- bullpen-tracker.html:951 | .scorebook-cell | 4px | not in the table -> cell (already 4)
- bullpen-tracker.html:990 | .coach-dock | 18px | not in the table -> dock (already 18)
- bullpen-tracker.html:995 | .dock-btn | 12px | not in the table -> control (already 12)
- bullpen-tracker.html:1002 | .dock-btn:focus-visible | 12px | not in the table -> control (already 12)
- bullpen-tracker.html:1004 | .dock-pill | 12px | not in the table -> control (already 12)
- bullpen-tracker.html:1020 | .hp-dot | 50% | not in the table -> circle (already 50%)
- bullpen-tracker.html:1071 | .target-dot-core | 50% | not in the table -> circle (already 50%)
- bullpen-tracker.html:1077 | .rel-glow-overlay | 2px | cell
- bullpen-tracker.html:1090 | .pitch-log-row | 5px | segment
- bullpen-tracker.html:1093 | .plr-dot | 2px | mark
- bullpen-tracker.html:1098 | .edit-mini | 5px | segment
- bullpen-tracker.html:1117 | .coach-logged-tag | 20px | pill
- bullpen-tracker.html:1141 | .deleted-tag | 20px | pill
- bullpen-tracker.html:1152 | .contacts-panel | 10px | control
- bullpen-tracker.html:1159 | .team-chip | 20px | pill
- bullpen-tracker.html:1180 | .attest-stop | 8px | control
- bullpen-tracker.html:1188 | .acct-avatar | 50% | not in the table -> circle (already 50%)
- bullpen-tracker.html:1190 | .acct-chip | 999px | not in the table -> pill (already 999px)
- bullpen-tracker.html:1194 | .acct-menu | 12px | not in the table -> control (already 12)
- bullpen-tracker.html:1200 | .acct-badge | 999px | not in the table -> pill (already 999px)
- bullpen-tracker.html:1206 | .notes-block | 10px | control
- bullpen-tracker.html:1207 | .note-item | 8px | segment
- bullpen-tracker.html:1245 | .lb-row | 6px | segment
- bullpen-tracker.html:1257 | .lb-exclude-panel | 6px | control
- bullpen-tracker.html:1403 | .g5-face | 6px | cell
- bullpen-tracker.html:1414 | .g5-field | 6px | cell
- bullpen-tracker.html:1418 | .g5-cell | 4px | not in the table -> cell (already 4)
- bullpen-tracker.html:1432 | .g5-shade | 3px | cell
- bullpen-tracker.html:1484 | .g5-runner | 50% | not in the table -> circle (already 50%)
- bullpen-tracker.html:1497 | .g5-drag-token | 50% | not in the table -> circle (already 50%)
- bullpen-tracker.html:1511 | .g5-velo-row .velo-strip-wrap | 8px | control
- bullpen-tracker.html:1543 | .gg-btn | 9px | DELETE (dead)
- bullpen-tracker.html:1565 | .gg-seq | 10px | DELETE (dead)
- bullpen-tracker.html:1569 | .gg-book | 6px | DELETE (dead)
- bullpen-tracker.html:1578 | .gg-book-play | 8px | DELETE (dead)
- bullpen-tracker.html:1583 | .gg-book-back, .gg-book-fix | 8px | DELETE (dead)
- bullpen-tracker.html:1589 | .gg-velo-readout | 9px | DELETE (dead)
- bullpen-tracker.html:1593 | .gg-noread | 8px | DELETE (dead)
- bullpen-tracker.html:1596 | .gg-velo | 9px | not in the table -> segment (already 9)
- bullpen-tracker.html:1606 | .gg-velo .velo-strip-box::after | 8px | segment
- bullpen-tracker.html:1621 | .gg-fix | 9px | DELETE (dead)
- privacy.html:30 | .note | 10px | control
- terms.html:30 | .note | 10px | control
- buttons.css:15 | .btn | 12px | not in the table -> control (already 12)
- buttons.css:41 | .tray | 12px | not in the table -> control (already 12)
- buttons.css:51 | .seg | 9px | not in the table -> segment (already 9)
- buttons.css:66 | .tray-ind | 9px | not in the table -> segment (already 9)
- buttons.css:79 | .seg .type-dot | 50% | not in the table -> circle (already 50%)
- css/components.css:184 | body.landing .option-icon | 50% | not in the table -> circle (already 50%)

## 3. Spacing: padding / margin / gap literals

literal px values by file: {'bullpen-tracker.html': 458, 'privacy.html': 17, 'report.html': 6, 'terms.html': 17, 'buttons.css': 6, 'css/components.css': 69}
exempt: {('bullpen-tracker.html', 'calc/env'): 7, ('bullpen-tracker.html', 'geometry'): 60, ('report.html', 'calc/env'): 1, ('css/components.css', 'calc/env'): 1}

bullpen-tracker.html: 135 off-scale -> 10→8 ×48, 14→12 ×27, 7→6 ×14, 5→4 ×10, 18→16 ×9, 9→8 ×7, 3→2 ×5, 1→0 ×4, 40→32 ×3, 22→20 ×3, 60→64 ×1, 11→12 ×1, 26→24 ×1, 28→24 ×1, -7→-6 ×1

privacy.html: 4 off-scale -> 18→16 ×2, 30→32 ×1, 14→12 ×1

report.html: 1 off-scale -> 80→64 ×1

terms.html: 4 off-scale -> 18→16 ×2, 30→32 ×1, 14→12 ×1

buttons.css: 2 off-scale -> 3→2 ×1, 10→8 ×1

css/components.css: 34 off-scale -> 14→12 ×10, 10→8 ×10, 28→24 ×2, 18→16 ×2, 22→20 ×2, 9→8 ×1, 11→12 ×1, 44→48 ×1, 36→32 ×1, 26→24 ×1, -10→-8 ×1, 13→12 ×1, 5→4 ×1

- **Exempt as geometry:** 60 in the tracker (`.zone-grid` and its cells, `.g5-*`, `.gg-*` overlays, `.home-plate*`, `.kb-batter*`, the velocity strip and cells, `.zone-wrap`, the coach dock's offsets), plus every value inside `calc()` / `env()` (9).
- **Proposed additional exemptions** (decisions 2–4): the U13 tray's 3px, the 9-dot icon, the dock's icon/label gap, and the three 1px pill paddings.
- **Off-scale under Option 2:** the counts above (6px is already on scale). The full list follows. Values marked 7 → 6 follow decision 2; 1 → 0 would become 2 per the table, or stay exempt per decision 4.

file:line | selector | property | value → step
- bullpen-tracker.html:72 | .dots9 | gap | 3 → 2
- bullpen-tracker.html:78 | .ph-status | gap | 10 → 8
- bullpen-tracker.html:81 | .sb-cell | padding | 10 → 8
- bullpen-tracker.html:87 | .ph-status | gap | 7 → 6
- bullpen-tracker.html:87 | .ph-status | padding | 10 → 8
- bullpen-tracker.html:87 | .sb-cell | padding-right | 7 → 6
- bullpen-tracker.html:92 | .ph-status | gap | 7 → 6
- bullpen-tracker.html:92 | .ph-status | padding | 10 → 8
- bullpen-tracker.html:92 | .sb-cell | padding-right | 7 → 6
- bullpen-tracker.html:93 | .ph-status | gap | 5 → 4
- bullpen-tracker.html:93 | .sb-cell | padding-right | 5 → 4
- bullpen-tracker.html:101 | .deliv-one | padding | 10 → 8
- bullpen-tracker.html:187 | .sidebar | gap | 18 → 16
- bullpen-tracker.html:198 | .brand-block | padding | 18 → 16
- bullpen-tracker.html:205 | .brand-mark | margin-bottom | 3 → 2
- bullpen-tracker.html:220 | .offline-pill | padding | 3 → 2
- bullpen-tracker.html:220 | .offline-pill | padding | 9 → 8
- bullpen-tracker.html:226 | .boot-screen | gap | 14 → 12
- bullpen-tracker.html:226 | .boot-screen | padding | 40 → 32
- bullpen-tracker.html:232 | .team-select-wrap | gap | 5 → 4
- bullpen-tracker.html:235 | .team-select | padding | 9 → 8
- bullpen-tracker.html:235 | .team-select | padding | 10 → 8
- bullpen-tracker.html:241 | .team-line | gap | 10 → 8
- bullpen-tracker.html:252 | .roster-toggle-btn | padding | 14 → 12
- bullpen-tracker.html:259 | .persp-rollup | padding | 14 → 12
- bullpen-tracker.html:280 | .throws-tag | margin-left | 7 → 6
- bullpen-tracker.html:287 | .roster-item | padding-left | 22 → 20
- bullpen-tracker.html:294 | .roster-dot-count | padding | 5 → 4
- bullpen-tracker.html:302 | .session-dot | margin-right | 7 → 6
- bullpen-tracker.html:307 | .invite-btn | padding | 10 → 8
- bullpen-tracker.html:314 | .invite-link-panel | padding | 14 → 12
- bullpen-tracker.html:319 | .invite-link-text | padding | 7 → 6
- bullpen-tracker.html:319 | .invite-link-text | padding | 9 → 8
- bullpen-tracker.html:340 | .roster-verify-badge | margin-top | 1 → 0
- bullpen-tracker.html:347 | .verify-banner | gap | 10 → 8
- bullpen-tracker.html:355 | .change-email-form | gap | 10 → 8
- bullpen-tracker.html:364 | .outbox-badge | padding | 10 → 8
- bullpen-tracker.html:370 | .invite-form | gap | 10 → 8
- bullpen-tracker.html:375 | .text-input | padding | 9 → 8
- bullpen-tracker.html:387 | .main | padding | 40 → 32
- bullpen-tracker.html:390 | .empty-state | gap | 10 → 8
- bullpen-tracker.html:390 | .empty-state | padding | 60 → 64
- bullpen-tracker.html:396 | .pitcher-header-actions | gap | 10 → 8
- bullpen-tracker.html:404 | .pitcher-ident | gap | 14 → 12
- bullpen-tracker.html:408 | .headshot-setup-row | gap | 14 → 12
- bullpen-tracker.html:412 | .pitcher-num | margin-left | 10 → 8
- bullpen-tracker.html:425 | .pitcher-header | gap | 10 → 8
- bullpen-tracker.html:426 | .pitcher-header .pitcher-ident | gap | 10 → 8
- bullpen-tracker.html:434 | .pitch-chip | padding | 9 → 8
- bullpen-tracker.html:479 | .home-tiles | gap | 10 → 8
- bullpen-tracker.html:490 | .home-tile | gap | 10 → 8
- bullpen-tracker.html:492 | .home-tile | padding | 10 → 8
- bullpen-tracker.html:529 | .info-tip | padding | 10 → 8
- bullpen-tracker.html:530 | .info-note | padding | 10 → 8
- bullpen-tracker.html:547 | .start-q-actions | gap | 10 → 8
- bullpen-tracker.html:577 | .controls-panel | gap | 18 → 16
- bullpen-tracker.html:578 | .chip-row | gap | 10 → 8
- bullpen-tracker.html:580 | .mt-10 | margin-top | 10 → 8
- bullpen-tracker.html:591 | .deliv-tray-row | gap | 10 → 8
- bullpen-tracker.html:610 | .pitch-count-badge | padding | 10 → 8
- bullpen-tracker.html:620 | .pitch-counter | gap | 10 → 8
- bullpen-tracker.html:628 | .add-type-inline button | padding | 10 → 8
- bullpen-tracker.html:657 | .game-velo | padding | 10 → 8
- bullpen-tracker.html:777 | .zone-caption | padding | 14 → 12
- bullpen-tracker.html:791 | .walkthrough-summary | margin | 10 → 8
- bullpen-tracker.html:792 | .walkthrough-summary | gap | 10 → 8
- bullpen-tracker.html:806 | .adjust-runners-panel | padding | 14 → 12
- bullpen-tracker.html:822 | .scorebook-btn | padding | 5 → 4
- bullpen-tracker.html:868 | .walkthrough-layout | gap | 14 → 12
- bullpen-tracker.html:885 | .game-panel-header | gap | 10 → 8
- bullpen-tracker.html:887 | .game-panel-header .stat-readout | gap | 14 → 12
- bullpen-tracker.html:894 | .game-panel-undo | padding | 10 → 8
- bullpen-tracker.html:921 | .position-swipe-chip | padding | 14 → 12
- bullpen-tracker.html:935 | .position-swipe-badge | padding | 1 → 0
- bullpen-tracker.html:935 | .position-swipe-badge | padding | 5 → 4
- bullpen-tracker.html:994 | .dock-btn | gap | 3 → 2
- bullpen-tracker.html:1019 | .hp-key | gap | 5 → 4
- bullpen-tracker.html:1083 | .stat-readout | gap | 18 → 16
- bullpen-tracker.html:1087 | .pitch-log | gap | 5 → 4
- bullpen-tracker.html:1090 | .pitch-log-row | padding | 7 → 6
- bullpen-tracker.html:1090 | .pitch-log-row | padding | 10 → 8
- bullpen-tracker.html:1093 | .plr-dot | margin-right | 7 → 6
- bullpen-tracker.html:1094 | .pitch-row-actions | gap | 9 → 8
- bullpen-tracker.html:1098 | .edit-mini | padding | 5 → 4
- bullpen-tracker.html:1098 | .edit-mini | padding | 7 → 6
- bullpen-tracker.html:1104 | .draft-banner | gap | 14 → 12
- bullpen-tracker.html:1111 | .session-card-head | gap | 14 → 12
- bullpen-tracker.html:1117 | .coach-logged-tag | padding | 7 → 6
- bullpen-tracker.html:1131 | .breakdown-table | margin-top | 14 → 12
- bullpen-tracker.html:1141 | .deleted-tag | padding | 7 → 6
- bullpen-tracker.html:1148 | .empty-hist | padding | 40 → 32
- bullpen-tracker.html:1151 | .contacts-panel | gap | 14 → 12
- bullpen-tracker.html:1152 | .contacts-panel | padding | 18 → 16
- bullpen-tracker.html:1159 | .team-chip | padding | 1 → 0
- bullpen-tracker.html:1159 | .team-chip | padding | 7 → 6
- bullpen-tracker.html:1161 | .workload-banner | margin | 10 → 8
- bullpen-tracker.html:1176 | .attest-opt | gap | 10 → 8
- bullpen-tracker.html:1178 | .attest-check | gap | 10 → 8
- bullpen-tracker.html:1180 | .attest-stop | padding | 10 → 8
- bullpen-tracker.html:1181 | .policy-foot | padding | 14 → 12
- bullpen-tracker.html:1187 | .acct-btn | padding | 10 → 8
- bullpen-tracker.html:1190 | .acct-chip | padding | 7 → 6
- bullpen-tracker.html:1196 | .acct-item | gap | 10 → 8
- bullpen-tracker.html:1197 | .acct-who | gap | 3 → 2
- bullpen-tracker.html:1200 | .acct-badge | padding | 1 → 0
- bullpen-tracker.html:1204 | .who-card | padding | 22 → 20
- bullpen-tracker.html:1206 | .notes-block | gap | 10 → 8
- bullpen-tracker.html:1206 | .notes-block | margin | 14 → 12
- bullpen-tracker.html:1206 | .notes-block | padding | 14 → 12
- bullpen-tracker.html:1207 | .note-item | padding | 9 → 8
- bullpen-tracker.html:1207 | .note-item | padding | 11 → 12
- bullpen-tracker.html:1213 | .note-add-row | gap | 10 → 8
- bullpen-tracker.html:1217 | .report-panel | padding-top | 14 → 12
- bullpen-tracker.html:1228 | .profile-page | gap | 22 → 20
- bullpen-tracker.html:1236 | .lb-page | gap | 18 → 16
- bullpen-tracker.html:1237 | .lb-controls | gap | 10 → 8
- bullpen-tracker.html:1257 | .lb-exclude-panel | padding | 10 → 8
- bullpen-tracker.html:1277 | .session-grid-layout | gap | 26 → 24
- bullpen-tracker.html:1278 | .controls-panel | gap | 14 → 12
- bullpen-tracker.html:1279 | .panel | padding | 18 → 16
- bullpen-tracker.html:1281 | .brand-block | padding | 18 → 16
- bullpen-tracker.html:1310 | .sidebar | gap | 10 → 8
- bullpen-tracker.html:1311 | .brand-block | gap | 10 → 8
- bullpen-tracker.html:1311 | .brand-block | padding | 14 → 12
- bullpen-tracker.html:1321 | .main | padding | 14 → 12
- bullpen-tracker.html:1321 | .main | gap | 14 → 12
- bullpen-tracker.html:1324 | .controls-panel | gap | 10 → 8
- bullpen-tracker.html:1325 | .panel | padding | 14 → 12
- bullpen-tracker.html:1326 | .session-grid-layout | gap | 18 → 16
- bullpen-tracker.html:1337 | .wide-left | gap | 14 → 12
- bullpen-tracker.html:1338 | .wide-right | gap | 14 → 12
- bullpen-tracker.html:1359 | .persp-count .wide-count | gap | 5 → 4
- bullpen-tracker.html:1366 | .phone-footer | gap | 14 → 12
- bullpen-tracker.html:1366 | .phone-footer | padding | 28 → 24
- bullpen-tracker.html:1455 | .ph-addcount | margin-top | -7 → -6
- privacy.html:21 | .band | padding | 18 → 16
- privacy.html:25 | h2 | margin | 30 → 32
- privacy.html:26 | h3 | margin | 18 → 16
- privacy.html:30 | .note | padding | 14 → 12
- report.html:37 | #kb-state | padding | 80 → 64
- terms.html:21 | .band | padding | 18 → 16
- terms.html:25 | h2 | margin | 30 → 32
- terms.html:26 | h3 | margin | 18 → 16
- terms.html:30 | .note | padding | 14 → 12
- buttons.css:40 | .tray | padding | 3 → 2
- buttons.css:49 | .seg | padding | 10 → 8
- css/components.css:28 | .badge | padding | 9 → 8
- css/components.css:55 | body.signin | gap | 14 → 12
- css/components.css:67 | body.signin .card | padding | 28 → 24
- css/components.css:105 | body.signin .text-input | padding | 10 → 8
- css/components.css:105 | body.signin .text-input | padding | 14 → 12
- css/components.css:115 | body.signin .info-msg | padding | 14 → 12
- css/components.css:125 | body.signin .age-row | gap | 18 → 16
- css/components.css:126 | body.signin .age-opt | gap | 10 → 8
- css/components.css:129 | body.signin .age-stop | padding | 10 → 8
- css/components.css:131 | body.signin .terms-check | gap | 10 → 8
- css/components.css:137 | body.signin .joinas-btn | padding | 14 → 12
- css/components.css:143 | body.signin .email-readout | padding | 11 → 12
- css/components.css:143 | body.signin .email-readout | padding | 14 → 12
- css/components.css:147 | body.signin .approve-btn | padding | 10 → 8
- css/components.css:168 | body.landing .wrap | gap | 44 → 48
- css/components.css:176 | body.landing .options | gap | 22 → 20
- css/components.css:178 | body.landing .option-card | padding | 36 → 32
- css/components.css:178 | body.landing .option-card | padding | 26 → 24
- css/components.css:180 | body.landing .option-card | gap | 14 → 12
- css/components.css:201 | body.landing .stage | padding | 10 → 8
- css/components.css:202 | body.landing .frame | gap | 28 → 24
- css/components.css:205 | body.landing .back-link | padding | 10 → 8
- css/components.css:205 | body.landing .back-link | margin-left | -10 → -8
- css/components.css:210 | body.landing | padding | 22 → 20
- css/components.css:210 | body.landing | padding | 14 → 12
- css/components.css:211 | body.landing .wrap | gap | 14 → 12
- css/components.css:213 | body.landing .frame | gap | 14 → 12
- css/components.css:215 | body.landing .option-card | padding | 18 → 16
- css/components.css:220 | body.landing .wrap | gap | 10 → 8
- css/components.css:222 | body.landing .frame, body.landing .options | gap | 10 → 8
- css/components.css:223 | body.landing .option-card | padding | 13 → 12
- css/components.css:223 | body.landing .option-card | gap | 5 → 4
- css/components.css:231 | body.landing .option-card | padding | 10 → 8
- css/components.css:231 | body.landing .option-card | padding | 14 → 12

## 4. Phone layout today (true 375 / 390 px viewports, both sports)

| Screen | Grid top | Velocity strip bottom |
|---|---|---|
| Bullpen, baseball, 375 and 390 | 184px | 690px |
| Bullpen, softball, 375 and 390 | 184px | 710px (the extra "Zone: armpits to top of knees" line) |
| Live Game at the velocity step, both sports, 375 and 390 | 184px | 455px (the in-chart velocity row) |

Stage B must keep these within 4px.

## 5. Shadows: every `box-shadow` (39)

file:line | selector | today | becomes
- bullpen-tracker.html:74 | .ph-layout .controls-panel.ph-controls | none | none (stays)
- bullpen-tracker.html:377 | .text-input:focus | 0 0 0 3px var(--brand-mid-ring) | --ring-focus
- bullpen-tracker.html:517 | .home-soon:active | none !important | none (stays)
- bullpen-tracker.html:529 | .info-tip | 0 4px 12px rgba(0,0,0,.25) | --shadow-pop
- bullpen-tracker.html:574 | .modal-panel | 0 8px 32px rgba(var(--ink-rgb),0.35) | --shadow-modal
- bullpen-tracker.html:649 | .velo-cell.typical | inset 0 0 0 2px var(--accent) | --ring-target
- bullpen-tracker.html:650 | .velo-cell.selected | none | none (stays)
- bullpen-tracker.html:848 | .ttp-btn.ttp-running | inset 0 0 0 2px var(--accent) | --ring-target
- bullpen-tracker.html:850 | .ttp-btn.ttp-bad | inset 0 0 0 2px var(--danger) | not in the spec: --ring-danger (2px danger ring)
- bullpen-tracker.html:898 | .game-panel-body | 0 10px 26px rgba(var(--ink-rgb),0.28) | --shadow-pop
- bullpen-tracker.html:992 | .coach-dock | 0 6px 24px rgba(0,0,0,0.22) | --shadow-pop (the dock; was its own value)
- bullpen-tracker.html:1006 | .dock-pill | 0 2px 8px rgba(0,0,0,.18), inset 0 -3px 0 var(--btn-accent) | --shadow-segment, --ring-select
- bullpen-tracker.html:1008 | .dock-pill.lifted | 0 10px 22px rgba(0,0,0,.30), inset 0 -3px 0 var(--btn-accent) | --shadow-lift, --ring-select
- bullpen-tracker.html:1072 | .target-dot-core | 0 0 0 4px rgba(var(--accent-rgb),0.28) | not in the spec: a 3-4px outer ring -- see note
- bullpen-tracker.html:1174 | .attest-backdrop .attest-card | var(--shadow-modal) | already a token
- bullpen-tracker.html:1194 | .acct-menu | 0 10px 26px rgba(var(--ink-rgb),0.22) | --shadow-pop
- bullpen-tracker.html:1246 | .lb-row.me | inset 0 0 0 1px var(--accent) | --ring-target? (1px: the leaderboard "me" row) -- see note
- bullpen-tracker.html:1264 | .zone-cell.zone-painted | inset 0 0 0 2px var(--accent) | --ring-target
- bullpen-tracker.html:1421 | .g5-choice | inset 0 0 0 2px var(--accent-game) | --ring-target
- bullpen-tracker.html:1463 | 50% | inset 0 0 0 3px rgba(var(--accent-rgb),0.55) | --ring-target-strong (3px selected state) -- see note
- bullpen-tracker.html:1484 | .g5-runner | 0 1px 3px rgba(0,0,0,.35), inset 0 0 0 4px var(--btn-accent) | --shadow-segment
- bullpen-tracker.html:1490 | .g5-cell.g5-over, .g5-cell.g5-target | inset 0 0 0 3px #fff | --ring-target-strong (3px selected state) -- see note
- bullpen-tracker.html:1491 | .g5-cell.g5-sel | inset 0 0 0 3px var(--accent-game) | --ring-target-strong (3px selected state) -- see note
- bullpen-tracker.html:1492 | .g5-cell.g5-held | inset 0 0 0 3px #fff | --ring-target-strong (3px selected state) -- see note
- bullpen-tracker.html:1498 | .g5-drag-token | 0 6px 16px rgba(0,0,0,.35), inset 0 0 0 4px var(--btn-accent) | --shadow-lift, + 4px btn-accent ring (see note)
- bullpen-tracker.html:1504 | .g5-velo-row, .g5-next-row | 0 0 0 3px var(--brand-bg) | not in the spec: a 3-4px outer ring -- see note
- bullpen-tracker.html:1530 | .gg-cell.gg-clear | 0 0 0 3px var(--surface-border) | DELETE (dead rule)
- bullpen-tracker.html:1544 | .gg-btn | 0 2px 6px rgba(var(--ink-rgb),0.15) | DELETE (dead rule)
- bullpen-tracker.html:1548 | .gg-btn:disabled | none | none (stays)
- buttons.css:30 | .btn.is-selected | 0 1px 3px rgba(0,0,0,.18), inset 0 -3px 0 var(--btn-accent) | --shadow-segment
- buttons.css:33 | .btn:active:not(:disabled) | inset 0 0 0 999px rgba(0,0,0,.04) | --press
- buttons.css:34 | .btn.is-selected:active:not(:disabled) | 0 1px 3px rgba(0,0,0,.18), inset 0 -3px 0 var(--btn-accent), inset 0 0 0 999px rgba(0,0,0, | --shadow-segment
- buttons.css:60 | .seg[aria-pressed="true"] | 0 1px 3px rgba(0,0,0,.18), inset 0 -3px 0 var(--seg-accent, var(--btn-accent)) | --shadow-segment
- buttons.css:67 | .tray-ind | 0 1px 3px rgba(0,0,0,.18), inset 0 -3px 0 var(--seg-accent, var(--btn-accent)) | --shadow-segment
- buttons.css:70 | .tray.has-ind .seg[aria-pressed="true"] | none | none (stays)
- buttons.css:74 | tray-ind, .tray-locked .seg[aria-pressed="true"] | 0 1px 2px rgba(0,0,0,.10) | --shadow-segment
- buttons.css:84 | .btn:disabled, .seg:disabled | none | none (stays)
- css/components.css:110 | body.signin .text-input:focus | 0 0 0 3px var(--brand-mid-ring) | --ring-focus
- css/components.css:234 | body.signin .card > .btn-primary | 0 0 0 3px var(--brand-bg) | not in the spec: a 3-4px outer ring -- see note

**Proposed new tokens**, beyond the spec's `--shadow-lift`, `--ring-focus` and `--press`:
- `--ring-target-strong`: inset 3px, for the Live Game field's selected / drop-target boxes;
- `--ring-plate`, `--ring-danger`, `--ring-halo` (decision 5).

The drag token's 4px inner ring and the runner's 4px ring are U13's selected underline color at 4px, so they become `--ring-select-4` or stay composite with `--shadow-lift`. That's part of the drag video check.

## 6. Report font sizes (new reports only)

| file:line | rule | today | becomes |
|---|---|---|---|
| template.ts:329 | `body` | 15 | 16 |
| template.ts:343 | `.header-meta` | 13 | 12 |
| template.ts:355 | `.type-grid h3` | 13 | 12 |
| template.ts:359 | `.legend-item` | 13 | 12 |
| template.ts:364 | `.data-table` | 13 | 12 |
| template.ts:370 | `.side-stats` | 13 | 12 |
| template.ts:372 | `.side-lists ul` | 13 | 12 |
| template_game.ts:515 | `.ab-row` | 13 | 12 |
| template.ts:357 | `.type-grid-stats` | 11.5 | 12 |
| template.ts:375 | `.report-footer` | 11.5 | 12 |
| template.ts:339 | `.brand-mark.small` | 11 | 10 |
| diamond.ts:197 | `.kb-mix` | 11 | 10 |

- Every other size is already on the nine steps.
- The charts' `font-size="8"` labels (svg.ts) and the field's count numbers (`34`, diamond.ts) are SVG units that scale with the drawing, not pixels. D1 left them alone; proposed the same.
