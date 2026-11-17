# N1 Stage G · evidence (Nov 17, 2026)

Branch `n1g-facility-colors`, cache `kb-shell-v349`. Staging: the migration was applied with `supabase db push`, and the
app was served locally with the staging config. Headless Chrome with device emulation. Pictures are in
`plans/n1g-evidence/`; I scanned them for email addresses and found none.

## Every-stage checks

1. **Roles** (390 unless noted; colors read from the page's computed tokens):

   | Login | Look |
   |---|---|
   | Facility manager, 1180 (`g1`), 820 (`g6`), 390 | facility: `--brand-bg #13294B`, `--accent #F26B3A`, the logo, "THAYER PITCHING LAB · Powered by Knuckleball" |
   | Facility pitcher (Andre Boateng) (`g2`) | facility look and phone header |
   | Pitching coach (Marcus Bell) | facility look |
   | Manager's softball side, 820 (`g5`) | facility look on softball too (Q1); `data-sport` softball |
   | Normal-team assistant (baseball) | Knuckleball's: `#061A12` / `#FFB81C`, the wordmark |
   | U15 coach (normal team, softball) | Knuckleball's softball: `#0B2540` / `#FF4F9A`, the wordmark |

   Pitch chips keep the sport palette everywhere (the first chip is `#FFB81C` on baseball, `#FF4F9A` on softball).
2. **Offline** (check 34): see below.
3. **Charting:** the Live Game field is drawn with fixed colors (`g5FieldSvg`), not the tokens, so it's unchanged.
   Nothing on the charting screen reads the facility tokens except the shared accent / brand (as with the sport).
4. **Side by side:** `g-sidebar-facility.png` against `g1-manager-1180.png`. Same identity block: the logo square in the
   accent, the facility name in display type, "POWERED BY KNUCKLEBALL", the navy menu, Home lit in the accent. The
   logo here is a test "TL" picture uploaded through the app. `g-sidebar-standard.png` is today's menu for teams
   without a look (Stage B).
5. `CACHE_VERSION` is `kb-shell-v349`. STATUS.md, CLAUDE.md and the privacy sentence are in this PR, and the pre-push
   checks run at push.

## Stage G checks

**32. The migration, rollback and RLS test on staging:**
- `supabase db push` applied `20261119000000_n1g_facility_branding`.
- `supabase/tests/n1g_facility_branding.sql` (rolled back): `(1) manager sets: ok | (4) bad hex: bad_color, other
  facility's logo path: bad_logo_path | (2) pitching coach: not_allowed | (3) other facility's manager: not_allowed |
  (5) reads: manager=2 coach=1 pitcher=1 linked parent=1 other manager=0 normal head=0 outsider=0 | (6) storage:
  manager upload=allowed coach upload=refused outsider upload=refused pitcher reads=1 outsider reads=0 | (7) archived
  side, pitcher rows 0 | (8) public policies 32, storage policies 8 | fails 0`.
- **Rollback, run for real on staging:**
  - The first version tried to delete the bucket and its files. Supabase refuses that from SQL ("Direct deletion from
    storage tables is not allowed"), so the whole script rolled back with nothing changed.
  - **Rewritten:** the rollback drops the 4 logo rules, the 4 functions and the 4 columns, and leaves the bucket, which
    then has no read rule. Its header says how to remove the bucket from the dashboard.
  - Re-run: `fns 0, cols 0, storage policies 4, bucket 1`. Forward again: `fns 4, cols 4, storage policies 8`. The test
    gives `fails 0` again.
  - The migration's bucket insert is now `on conflict do nothing`, so it re-applies after a rollback.

**33. As the manager, Account → Facility look:**
- **A too-light brand (`#E8EEF5`):** "This brand color is too light for white text. Pick a darker one." Save stays
  disabled.
- **Navy `#13294B` and orange `#F26B3A`:** saved; tokens applied; dark ink chosen on the accent.
- **A 600 × 600 PNG "TL" test logo**, through the real upload path: shrunk on the device to 256 × 256, stored as
  `<org>/logo.png` (2,774 bytes, `image/png`), cached on the device, and shown in the menu.
- The menu and phone header (logo, name, Powered by) and the card's colors showed for the manager, a pitching coach and
  a facility pitcher.
- Normal teams and the other sport's normal teams are unchanged.
- Reports: a History report's shadow-root styles don't use the app's `--brand-*` variables (`reportUsesAppBrandVar:
  false`); they keep their own frozen colors. Pitch chips and the Live Game field are unchanged.
- **Not run:** the view-only family and a parent on a facility. Staging has no family or parent login on the DS1
  facility. `my_facility_brandings` returns the row to a linked login (test 5), and the app applies it the same way.

**34.**
- A low-contrast brand is refused (above). The server only takes real hex colors (test 4).
- **Offline:** as the facility pitcher, one online load, then a reload with the network off. The look painted
  (`#13294B` / `#F26B3A`), with the logo and the name (`g3`).
- **Found and fixed:**
  - On the first offline run the colors were lost. The offline start path never loaded the device copy, so the first
    draw cleared what the pre-paint step had set. `applyFacilityTheme` now reads the device copy (and its cached logos)
    the first time.
  - On the 820px rail, the logo sat beside ☰ and was cut off. The rail now shows only ☰, like the wordmark; the
    identity shows when the menu opens (`g6`).

**Afterwards:** the DS1 staging facility was put back to Knuckleball's look through the app (Remove logo, Use Knuckleball
colors). Staging: colors null, logo path null, 0 files in `facility-logos`.
