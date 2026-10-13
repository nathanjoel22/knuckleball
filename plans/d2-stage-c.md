# D2 Stage C evidence (Oct 13, 2026), branch `d2-broadcast-rebrand`, v231

Spec: `plans/d2-broadcast-rebrand.md` Stage C (D1 Stage 3 with the D2 look). The mockups are in `docs/design/target/mockups/`.

## What changed
- **New `css/components.css`**, loaded after `tokens.css` and `buttons.css` by every page except `report.html` (a stored report is drawn inside that page):
  - The slanted tag (the fill is skewed and the text stays upright, so scripts can set it). Used for the sign-in role tag and the sidebar's COACH / PITCHER badge.
  - Badge, banner, and the flat card (`.panel`: 1px line, 12px radius, 20px padding, 16 on phones, no shadow).
  - The whole sign-in look (`body.signin`) and the "Which sport?" page (`body.landing`).
- **Sign-in pages, all 10, then index:**
  - The light page. Each step card opens with a full-width `--brand-bg` header whose bottom edge falls 28px (`clip-path`): wordmark, tagline, slanted tag, and a Big Shoulders 800 44px title whose last word is in the accent. One-word titles and "Join as" have no accent.
  - The form below on `--bg`, with 44px inputs (12px radius, 1.5px line, `--brand-mid` focus ring) and links in `--brand-mid`.
  - The glows and the dark card are gone. Sport still comes from `?sport=`, with no sport tray.
  - **No page has a `<style>` block any more**, and no inline color or font. The one inline link color, on pitcher-signup, was removed.
  - **Index:** the light page, a 64px Big Shoulders 900 title, and the sport cards in each sport's own brand with an accent title. The role step's icons are ink (gold on white is 1.7:1).
- **D1's temporary `html[data-theme="dark"]` scope is deleted from `tokens.css`**, since no page uses it.
- **The app:**
  - **Cards:** flat. `.panel`, History's `.session-card` and `.who-card` lose their shadows and get a 12px radius. Shadows remain only on floating things: menus, the Live Game panel, modals, the dock, the selected segment.
  - **Brand strip:** 12px radius, tagline at 0.14em, the role badge as a slanted tag.
  - **Scoreboard:** the phone bullpen and Live Game status bars are `--brand-bg-deep` (52px) with cells of a Big Shoulders number over a 10px caps label, split by `--brand-line`.
    - **Bullpen:** PITCH(ES).
    - **Live Game:** INNING ("INN" under 400px), OUT(S), COUNT.
    - The perspective sits on the right in small caps. Existing content only.
    - The wide pitch counter is a dark scoreboard tile.
  - **Strike-zone grid:** the frame is `--brand-bg` and cells have a 4px radius. The Live Game field keeps its own art.
  - **Banners** (verify, draft, outbox) are 12px radius. **Text inputs** are 44px with the focus ring.
  - **Next Pitch:** the two live buttons share `.next-pitch` (variants `.g5-nextpitch`, `.g5-act-next`). The two dead classes (`.next-pitch-btn`, `.gg-next`) are deleted.
- **`privacy.html` / `terms.html`:** the band now shows the KNUCKLEBALL wordmark in Black Ops One, with no period (Joel's Oct 13 approval to update them). No policy wording changed. CLAUDE.md's wordmark line is updated.
- **`sw.js`:** precaches `css/components.css`; `CACHE_VERSION` v231.

## Acceptance
1. **U13 unchanged:** all 114 app states (both sports × 390 / 820 / 1180) have identical tap handlers before (Stage B, `3a70b76`) and after. No button or tray rule in `buttons.css` changed.
2. **Trays:** every pick-one group was already a tray (U13), the Bullpen / Live Game chooser included (`segTray`). Zero `.btn-ghost` (grep).
3. **Sign-in pages:** they render from the shared files only. Grep shows no `<style>` in any of the 11 and no inline color or font. Every step card was checked with the steps forced visible: loading, invalid, attest, join, join as, check your email, joining; guardian ask / approved / invalid; reset request / sent / new password.
4. **Nothing new wraps or clips** in the app (Stage B vs Stage C, 114 views): no sideways page scroll, nothing newly cut off. The only flag is the pitch-log line (the baseline artifact from Stage B; same line count, checked by eye).
5. **Phone Live Game scoreboard**, free space: 320 px 4 px, 375 px 6 px, 390 px 6 px. ⏱ is fully visible; a first version overflowed at 390 and was fixed before this commit.
6. **Side by side with Jordan's mockups** (sign-in in both sports; phone charting): the header, angled edge, slanted tag, accent last word, light form, gold / pink primary, green / blue links, the dark grid frame and the scoreboard all match. **Differences:**
   - The title fits on one line where the mockup wraps it.
   - There's no period after the title.
   - The tag keeps today's wording ("BASEBALL · COACH SIGN IN").
   - The mockup's charting composition (grid beside the velocity squares) is a layout change and out of scope.
7. **Offline:** 32 precached files, all present. CACHE_VERSION v231. The airplane-mode check is Joel's.

## Not done (out of scope or not present)
- **Home section labels as slanted tags:** the Home screen has no section labels today.
- **The iPad-portrait perspective tray squeeze** (open since Stage B) is unchanged.
