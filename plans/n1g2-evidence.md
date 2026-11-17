# N1 Stage G2 · evidence (Nov 17, 2026)

**What G2 is:** a normal team's head coach sets the team's logo and colors.

**Where it was tested:**
- Branch `n1g2-team-colors`, cache `kb-shell-v351`.
- Staging: the migration was applied with `supabase db push`; the app was served locally with the staging config.
- Headless Chrome with device emulation.
- Pictures are in `plans/n1g2-evidence/`, scanned for email addresses: none.

## Database

**The migration:** `supabase db push` applied `20261120000000_n1g2_team_branding`. F1-C2's parked migration file was put
in place only for the push, then removed.

**The test:** `supabase/tests/n1g2_team_branding.sql` (rolled back) gave `fails 0`:
- (1) the head sets: ok;
- (3) refused writes: a bad hex gives `bad_color`, another team's logo path `bad_logo_path`, one color only
  `both_colors`;
- (2) `not_allowed` for the assistant, a pitcher, another team's head and an outsider;
- (4) a facility side gives `use_facility_look`; an archived team gives `team_archived`;
- (5) reads of the team's row: head 1, assistant 1, pitcher 1, linked parent 1, other head 0, outsider 0, facility
  manager 0. Facility rows differ from `my_facility_brandings()`: 0;
- (6) storage: head upload allowed, assistant upload refused, outsider upload refused; pitcher reads 1, outsider reads 0;
- an archived team returns 0 rows;
- (7) public policies 32, storage policies 12.

**Rollback, run for real on staging:**
- After the rollback: functions 0, columns 0, storage policies 8, bucket 1 (the bucket stays, as in Stage G).
- Re-applied with `db push`: functions 3, columns 4, storage policies 12.
- The test gives `fails 0` again.

## App (Account → Team look)

**As the U15 Softball Test head coach** (normal team, softball; `g2a-head-390`):
- Account shows **Team look**.
- A too-light brand (`#F4E1E6`) is refused: "This brand color is too light for white text. Pick a darker one." Save
  stays disabled.
- Maroon `#5B1A33` and gold `#F2C14E` saved: "Saved. Everyone on the team sees it next time they open the app."
- A 500 × 500 test logo was uploaded through the app to `<team>/logo.png` in `team-logos` and shown in the header.
- The header reads "U15 SOFTBALL TEST · Powered by Knuckleball".

**Who sees it** (390):

| Login | Look |
|---|---|
| U15 pitcher (rostered) | the team's: `#5B1A33` / `#F2C14E`, name "U15 Softball Test", no editor |
| Staging Knights assistant (another team) | Knuckleball's: `#061A12` / `#FFB81C` |
| DS1 facility pitcher | Knuckleball's (the facility has no look) |
| Parent login (U15 Kid) | Knuckleball's. That player isn't on the U15 team, so this isn't a linked-parent check of the team look; test (5) covers a linked parent on the server |

**Offline:** as the U15 pitcher at 1180, one online load, then a reload with the network off. The look painted
(`#5B1A33`), with the logo in the menu and the name (`g2b`).

**Afterwards:** the U15 team was put back to Knuckleball's look through the app (Remove logo, Use Knuckleball colors).
On staging, no team has a look and `team-logos` holds 0 files.
