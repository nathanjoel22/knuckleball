# U13 preconditions report (Oct 9, 2026)

Read-only audit for `plans/u13-segmented-buttons.md`, branch `u13-segmented-buttons` (from `main` at cf346b0). **No code has changed.** Line numbers are `bullpen-tracker.html` unless another file is named.

**How heights were measured.** Headless Chrome on 102 rendered app states: 17 screens (coach home, History, History with Delete armed, Leaderboard, coach Profile, Player Profile, roster remove armed, account menu, bullpen, bullpen sheet, bullpen discard armed, Live Game, field "what happened", field contact, pitcher home, pitcher History, pitcher Profile) × baseball and softball × 390, 375 and 1180 px. Styles that only appear in states I couldn't draw were measured on a test page using the app's own CSS; those are marked *(test page)*. Small pages were rendered at 390 px; buttons hidden until the server answers were read from their CSS and are marked *(CSS)*.

**One correction to the audit.** The pitch-type ✕ on Profile is a `<span onclick>` (line 9798), not a button, so it doesn't appear in the 208 count. It is 13 px tall. The "Add" pitch button next to it has no class and is 29 px.

---

## 1. Inventory: every style, its role, and its height

Roles: **tray** (segment group), **pri**mary, **sec**ondary, **ter**tiary, **icon**, **danger**, **nav**, **target** (charting target, not restyled).

### Charting app (`bullpen-tracker.html`): 208 buttons, 46 styles

| Style (uses) | Where | Height now | Folds into | Notes |
|---|---|---|---|---|
| `btn btn-primary` (41) | Save, Send report, Yes, Update password, … | 35 (48 where overridden) | pri | 12 of them are made red inline → danger (§ inline) |
| `btn btn-ghost` (73) | Back, Cancel, Profile, Discard session (8632), … | 35–48 | sec | Discard session (8632) → danger |
| `a.btn btn-ghost` (3) | View report links 5490, 9178, 9305 | 35 | sec | links, same style |
| `type-chip` (12) | perspective 5877, delivery 7033, pen batter 4519, History filter 9105, pitch types 8381/8844, game pickers 6900–6921, 7847–7863 | 44 | tray / segment | colors set inline (§ inline) |
| `pstrip-chip` (1 template) | phone pitch strip 8668 | 60 | tray (scrollable) | per-type color inline |
| `pstrip-arrow` (2) | strip ‹ › | 60 | icon | |
| `throws-btn` (8) | throws L/R 9792, zone side 9483, lb windows/cats 9666–9667, Yes/No 9868 | 44 | tray / segment | |
| `tab-btn` (5) | page tabs 9726–9734 | **37** | nav (tray) | |
| `dock-btn` (1 template) | coach dock 3586 | 50 | nav | glide pill stays; restyled as a tray on dark |
| `roster-toggle-btn` (1) | Roster bar | **40** | nav | |
| `acct-btn` (1) | account button | **38** | icon / nav | |
| `acct-item` (2), `acct-add` (2) | account menu rows | 56 / 44 | sec (menu rows) | |
| `kind-choice-btn` (2) | Bullpen / Live Game 5932 | 72 | tray | big chooser; becomes a 2-choice tray at 44+ |
| `deliv-one` (1) | phone Set/Windup flip 8659 | **34** in status bar | sec, "selected" look when Set | spec §3; 44 hit area via padding |
| `ttp-btn` (+`ttp-compact`) | ⏱ | **33–34** (status bar, wide) | icon | disabled on Windup unchanged |
| `pb-pill` (1) | pen batter pill 8793 | 48 | sec / selected look | spec §3 |
| `kb-batter` (1) | batter silhouette | 48+ | target-like, untouched shape | its label only |
| `velo-arrow` (4) | velocity ‹ › | 50–62 | icon | |
| `velo-cell` | velocity numbers | 48–60 | target | spec §4: the number itself isn't restyled |
| `velo-slim-reset` (1) | phone velocity Reset | **40** | ter | |
| `g5-act` (5), `g5-act-next` | + Out / + Strike / + Ball / ‹ Back / Next | 44 | sec / pri (Next) | corner buttons are restyled (spec §4) |
| `ph-act` (5) | phone Undo / New batter / New inning | 44 | sec | |
| `g5-reset`, `g5-nextpitch` | velocity row in the chart | fill their box (~64) | sec / pri | |
| `undo-btn` (9) | Undo links, **Delete this session** 9217/9350 | **15** *(test page)* | ter; Delete → danger | today a 10 px underlined link |
| `end-session-btn` (4) | End session & save (+ `btn btn-primary`) | 35 | pri | |
| `sign-out-btn` (5) | Sign out | **35** | sec | |
| `sess-back`, `sess-more` | phone session header | 44 | icon (on dark) | |
| `runner-diamond-btn` | bases in status bar | 44 | target | untouched |
| `g5-cell` | field boxes | 64–70 | target | untouched (spec §4) |
| `invite-link-copy-btn` (3) | Copy invite link | **31** *(test page)* | sec | |
| `invite-regen-btn` (2) | New link | **15** *(test page)* | ter | |
| `note-del` (1) | delete coach note | **32** | icon → danger | |
| `persp-rollup` (1) | perspective roll-up | **36** *(test page)* | sec | |
| `back-to-chooser-brand` (1) | ‹ Back to chooser | 44 | sec | |
| `lb-val-btn` (1) | leaderboard value | **26** *(test page)* | ter | in a table cell → padded hit area |
| `lb-undo` (1) | leaderboard undo | **24** *(test page)* | ter | |
| `modal-close-x` (1) | close ✕ | **32** *(test page)* | icon | |
| `roster-item-remove` (1) | ✕ remove pitcher | **19** *(test page)* | icon → danger | row is 53 tall, room for 44 |
| `row-x-btn` (1) | ✕ on recent-pitch rows 8888 | **12** *(test page)* | icon | in a table row → padded hit area |
| `coach-profile-link` (1) | phone Profile | 35 | sec | |
| `hide-phone`, `show-phone`, `touch-only` | visibility helpers | — | — | not styles; kept |
| unclassed `<button>` (roster name) 10722 | roster rows | 33 inside a 53 row | nav row | `all:unset` inline; row itself is the target |
| unclassed "Add" (pitch types) | Profile | **29** | sec | |
| `<span onclick>` ✕ 9798 | remove pitch type | **13** | icon | becomes a real `<button>` |

### Inline styles on buttons: 31, all accounted for

| Kind | Count | Lines | Fix |
|---|---|---|---|
| Red danger fill | 12 | 5389, 8626, 8649, 9213, 9346, 9640, 9921, 10004, 10030, 10051, 10068, 10735 | `.btn-danger` class |
| Chip colors (amber selection or the pitch type's color) | 13 | 4519, 5877, 6900, 6910, 6921, 7033, 7847, 7853, 7863, 8381, 8668, 8844, 9105 | tray classes; pitch colors → **decision B** |
| Spacing (margin-top) | 4 | 3313, 9090, 10800, 10802 | layout classes |
| `all:unset` roster name | 1 | 10722 | a class |
| Field box position | 1 | 8311 (`g5-cell`) | charting target → **decision C** |

### Other pages

| Page | Control | Height | Folds into |
|---|---|---|---|
| login, join (3), join-coach (2), coach-, pitcher-, parent-signup, accept-invite, reset-password (2) | `btn-primary` submit | 42 | pri |
| index (landing) | `option-card` sport and role choices (4 links) | 178 | **decision D** |
| index | `back-link` ‹ Baseball / Softball | **27** | ter |
| guardian-consent | `approve-btn` | ~48 *(CSS)* | pri |
| report.html | `kb-btn` Download / Print | ~33 *(CSS)* | sec on dark |
| verify-email, privacy, terms | no buttons (text links only) | — | — |
| frozen pen and game reports (`send-session-report` templates) | **no buttons at all** | — | nothing changes |

---

## 2. Where button styles live, and how themes set colors

- **No shared stylesheet exists.** Every page has its own `<style>` block. The only shared CSS file is `vendor/fonts/fonts.css`. The 8 sign-in/sign-up pages each carry an identical copy of `.btn-primary` (same text in all 8).
- **The charting app** keeps every style in its one `<style>` (starts line 15), with 55 custom properties on `:root` (line 54) and a `html[data-sport="softball"]` block (line 241) that redefines them. Other pages copy a 9–15 variable subset, plus their own softball block.
- **Theme colors are already custom properties**, so `--btn-*` tokens can point at them:

| Token | Baseball (today) | Softball (today) |
|---|---|---|
| `--btn-ink` | `--field-dark` #0F241B | `--field-dark` #234B6E |
| `--btn-soft` | `--surface` #E8F3EC | `--surface` #EAF4FB |
| `--btn-primary` / `--btn-on-primary` | `--primary-bg` #E8A83D / #0F241B | #E27BA2 / #FFFFFF |
| `--btn-accent` | `--amber` #E8A83D | `--amber` #F2A7C3 (pink) — see **decision E** |
| `--btn-danger` | see **decision F** | same |

---

## 3. Choice groups and helpers

**No shared helper exists.** Every group is rebuilt in its render function: a ternary adds `selected` / `on` / `active` and an inline color, and each option calls its own handler, which sets state and re-renders. Only the dock toggles a class in JS (3596, 3638). Today there are **0** `aria-pressed`, **0** radio or tab roles, and **1** `:focus-visible` rule.

| Group | Builder (line) | Choices | Shows on |
|---|---|---|---|
| Charting perspective | 5870–5877 | 2 | iPad/laptop (phones: a drop-down) |
| Delivery Windup / Set | `renderDeliveryToggle` 7027 | 2 | **iPad portrait, landscape, laptop** — see **decision A** |
| Pen batter None / RHB / LHB | `renderBatterModeToggle` 4512 | 3 | **iPad/laptop** — see **decision A** |
| History filter All / Bullpen / Live Game | `renderHistoryFilter` 9100 | 3 | all |
| Pitch types (wide) | 8381, 8844 | 2–8 | iPad/laptop |
| Pitch strip (phone) | 8668 | scrolls | phones |
| Game pickers | 6900–6921, 7847–7863 | 2–3 | Live Game |
| Throws L / R | 9792 | 2 | Profile |
| Zone side vs RHB / vs LHB | 9483 | 2 | accuracy-zone editor |
| Leaderboard window, category | 9666, 9667 | 3+ | Leaders |
| Yes / No (setting) | 9868 | 2 | Profile |
| Uses radar gun Yes / No | 10227 (swaps primary/ghost) | 2 | setup |
| Extra-inning "runner on 2B?" Yes / No | 8350 (primary + ghost) | 2 | Live Game |
| Page tabs | 9726–9734 | 3–4 | all |
| Mode chooser Bullpen / Live Game | 5932 | 2 | New Session |
| Account menu | 3251 | profiles | menu |
| Dock | 3586 | 4 | coach phones |

**Plan:** one render helper, `tray(options, current, handlerName)`, that returns the markup, plus one shared keydown listener for arrow keys, `aria-pressed` and the sliding indicator. Each option still calls its existing handler, so behavior doesn't change.

---

## 4. Report pages and the CSP

- `report.html`'s CSP (line 12) covers **scripts only**: `script-src 'self' 'sha256-1d1x…'`. It has **no `style-src`**.
- Its toolbar buttons (`kb-btn`, lines 47–52, 86–87) are styled in the page's own `<style>`. **There is no external stylesheet**, which differs from spec §5.
- Changing that `<style>` doesn't touch the hashed script, so **the CSP hash stays unchanged**. The inline script (line 108) won't be edited.
- Frozen report files contain no buttons, so past and future reports are untouched.

---

## 5. Every control under 44 px, and how each gets there

| Control | Now | How it gets to 44 |
|---|---|---|
| `btn` (primary/ghost/end session/coach profile) | 35 | taller box (min-height 44) |
| page tabs | 37 | taller box (nav tray) |
| account button | 38 | 44×44 icon button |
| Sign out | 35 | taller box |
| Roster bar | 40 | taller box |
| Set/Windup and ⏱ in the phone status bar | 34 / 33 | **hit area** via `::before`; the bar is already 44 tall, the visible pill stays |
| ⏱ on iPad/laptop | 33 | taller box |
| velocity Reset (phone) | 40 | taller box (tertiary) |
| Delete this session / Undo links (`undo-btn`) | 15 | Delete → danger button; Undo → tertiary 44 |
| invite Copy / New link | 31 / 15 | taller box |
| note delete, modal ✕ | 32 | 44×44 icon |
| perspective roll-up | 36 | taller box |
| leaderboard value / undo | 26 / 24 | **hit area** (table cells) |
| roster ✕ remove | 19 | 44×44 icon (row is 53) |
| recent-pitch ✕ | 12 | **hit area** (table rows) |
| pitch-type ✕ (span) and "Add" | 13 / 29 | real buttons, 44 |
| landing ‹ Baseball / Softball | 27 | taller box |
| sign-in/sign-up submit | 42 | taller box |
| report.html Download / Print | ~33 | taller box (toolbar grows ~11 px) |

---

## Decisions for Joel (the packet's Escalate-if items)

- **A. Windup/Set and the pen batter on iPad/laptop.** Spec §3 calls them single buttons, but that's only true on phones. On iPad and laptop they are 2- and 3-choice groups (`renderDeliveryToggle`, `renderBatterModeToggle`). **Recommend:** trays on iPad/laptop (today's behavior), single buttons on phones.
- **B. Pitch-type colors with zero inline styles.** Each chip's color comes from the pitch palette. **Recommend:** generate one small stylesheet at sport load from `SPORTS[sport].palette` (classes per palette slot), so there are no `style=""` attributes and no second copy of the palette (landmine 4). Alternative: allow one CSS variable per chip (`style="--type:#…"`).
- **C. `g5-cell` position.** Its one inline style places the box on the field, and spec §4 leaves charting targets untouched. **Recommend:** leave it and count it as a charting target, not a button style.
- **D. Landing page sport/role choices.** These are 178 px picture cards (links), not buttons. **Recommend:** keep the cards and restyle only the ‹ back button.
- **E. Seeing the selected segment outdoors.** A white segment on the soft tray is 1.14:1, so selection shows only through the shadow and the underline. The underline is gold 2.1:1 / pink 1.9:1 on white, under the 3:1 guideline for controls. **Options:** (1) build as spec; (2) point `--btn-accent` at each sport's existing dark ink (green 16:1, navy 9:1) — a token choice, not a color change; (3) keep gold/pink, 4 px thick.
- **F. Danger text color.** The inline red today is `--red-bg` #A83A31. On the soft fill it reads 5.6:1; `--red` #C0453B reads 4.44:1, just under the 4.5:1 text minimum. **Recommend:** `--btn-danger` = `--red-bg`.
- **G. One shared stylesheet or a copy per page.** No shared CSS exists. **Recommend:** a new `buttons.css` at the root, linked from every page and precached by `sw.js`, so there's one copy instead of 15. The alternative keeps today's pattern: the same block pasted into each page.
- **Not in scope, flagged.** Softball's primary button today is white on pink at **2.77:1** (under 4.5:1); colors stay per the spec, so it's unchanged. `docs/button-directions-reference.html` loads Google Fonts and is published on the live site (GitHub Pages serves the whole repo); the privacy policy says pages load nothing from third-party hosts.
