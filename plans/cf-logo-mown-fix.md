# CF logo fix · the mown center-field logo is the plate, not the keypad

Packet for Claude Code. Run from the repo root (`~/knuckleball-repo`). **Read `CLAUDE.md` first; where it and this packet disagree, `CLAUDE.md` wins.** Docs-only: two reference files and one rendered PNG. No app file, no CSS, no landing page, no database.

Source: Jordan's note to Joel, Oct 21 2026. Do this before any work on the outfield grass of the Live Game diamond (G5), since that is where the mown logo will be drawn from these references.

## 1. The decision being enforced

Knuckleball has two marks. **The keypad, "The spot"** (the slanted 3×3 zone with one lit pocket; `kb-mark` on the landing page) is the main logo: app icon, favicon, splash, nav. **The home plate with the K, "Strikeout"**, is the secondary logo for limited uses — the first is the logo mown into the center-field grass. The landing page is already right and is not touched here.

## 2. The bug

`docs/cf-logo-mown.md` and `docs/cf-logo-mown-demo.html` describe the mown logo as the home plate, but their SVG draws the keypad: the symbols are `kb-spot` and `kb-spot-lit`. Nothing in the app uses them yet, so only those two files (and the demo's rendered PNG) change.

## 3. Discovery — report, then proceed (no gate unless something below stops you)

```bash
git status --short; git log --oneline -3                      # clean tree; note the start commit
git pull --ff-only
ls -la docs/cf-logo-mown*                                     # the .md, the demo .html, the rendered .png (name it)
grep -rn -E 'kb-spot' --include='*.html' --include='*.md' --include='*.js' --include='*.css' --include='*.svg' . | grep -v '^\./\.git'
grep -n -E '<symbol id="kb-spot|<use [^>]*#kb-spot|CX|CY|LSIZE|mask|hairline|0\.05|\.05|0\.1\b|\.22|pointer-events' docs/cf-logo-mown.md docs/cf-logo-mown-demo.html
grep -n -i -E 'render|screenshot|playwright|chrom|puppeteer|\.png' docs/cf-logo-mown.md | head        # how the PNG was made
file docs/cf-logo-mown*.png                                   # its pixel size — the re-render must match
```

**Stop and ask if:** `kb-spot` appears anywhere other than those two docs files (the app or the landing page would be using it, and this packet says they don't); or either file has no `kb-spot` symbols at all (then the fix was already applied — say so and stop); or there is no record of how the PNG was rendered and its size can't be read.

## 4. The change (both files, identically)

### 4.1 Replace the two symbols

Delete the `<symbol id="kb-spot" …>…</symbol>` and `<symbol id="kb-spot-lit" …>…</symbol>` blocks and put these in their place, **byte for byte** (same 100×100 box, so the placement constants `CX`, `CY`, `LSIZE` do not change):

```html
<!-- the secondary mark, Strikeout: home plate (true 17-inch proportions) cut as a band, the K inside -->
<symbol id="kb-plate" viewBox="0 0 100 100">
  <path fill-rule="evenodd" d="M2 2H98V50L50 98L2 50Z M9 9H91V47.1L50 88.1L9 47.1Z"/>
  <path transform="translate(26 16) scale(0.03466)" d="M0 0H442V1327H0Z M510 1139V494L820 0H1280Z M823 1327L673 1018L935 625L1301 1327Z"/>
</symbol>
<!-- the spot, "cut shorter" -->
<symbol id="kb-plate-lit" viewBox="0 0 100 100">
  <circle cx="67.9" cy="38.2" r="5.6"/>
</symbol>
```

The second path is the actual **K from the Black Ops One wordmark font**, traced, so it matches KNUCKLEBALL. **Do not edit, re-trace, round or reformat it.**

### 4.2 Rename every reference

`#kb-spot` → `#kb-plate` and `#kb-spot-lit` → `#kb-plate-lit`: the mask `<use>`, the outline `<use>`, the lit `<use>`, and any mention by name in the `.md` prose. Nothing else moves: the cross-cut stripes, the 5% shade, the 10% hairline, the 22% white spot, `pointer-events:none`, `CX`/`CY`/`LSIZE`.

### 4.3 Re-render the demo PNG

The same way it was made before (per discovery), at the same pixel size, to the same path. Then look at it — open the PNG, don't just trust the file size. Expected: on the cross-cut grass it reads as a **home plate with the K mown into it and the small spot in the crook of the K** (upper right, where the two arms meet). If the demo also shows the solid version, that one reads as the **Strikeout logo** from the concepts page: a plate outline as a band, the K inside, the spot in the same crook.

### 4.4 Prose check

Read `docs/cf-logo-mown.md` once through. Its text already says home plate; make sure no sentence still describes a keypad, a lit pocket or a 3×3 zone. Fix only what contradicts the plate; don't rewrite.

## 5. Acceptance checks — all with evidence

1. `grep -rn 'kb-spot' . --include='*.html' --include='*.md' --include='*.js' --include='*.css' --include='*.svg' | grep -v '^\./\.git'` → nothing.
2. In each of the two files, the `kb-plate` and `kb-plate-lit` symbols are byte-identical to §4.1: save §4.1's block to a temp file and `diff` it against the block extracted from each file (`sed -n '/<symbol id="kb-plate"/,/<\/symbol>/p'` twice, once per id).
3. Each file has the plate referenced from the mask `<use>`, the outline `<use>` and the lit `<use>`: `grep -c '#kb-plate"' <file>` → 2 and `grep -c '#kb-plate-lit"' <file>` → 1 (adjust only if discovery showed a different number of `<use>`s before; the count must equal the old `#kb-spot` count).
4. `git diff` touches no line containing `CX`, `CY`, `LSIZE`, `pointer-events`, the stripe pattern, or the `.05` / `.1` / `.22` opacities.
5. The PNG is re-rendered at the same pixel size as before (`file` before and after) and you looked at it: mown plate + K + spot; solid = Strikeout, if shown.
6. `git diff --stat` lists exactly: `docs/cf-logo-mown.md`, `docs/cf-logo-mown-demo.html`, the PNG. Nothing else — no `index.html`, no `css/`, no app file.

## 6. Commit

One commit: `docs: center-field mown logo is the plate (kb-plate), not the keypad — per Jordan Oct 21`. Push only on Joel's word (CLAUDE.md: only Joel ships).

## 7. Report

The three files touched, the old and new `<use>` counts, the PNG size, the six checks with evidence, and the PNG itself so Joel can look.
