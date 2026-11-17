Written against: `b428265` (main; production v350, N1 complete). Follows N1 Stage G (`plans/n1g-preconditions.md`).

# N1 Stage G2 · A team's logo and colors · preconditions (Nov 17, 2026)

**Joel, Nov 17 2026:** "yes, let head coaches do it also", then **"yes to all"** (Q1-Q5, the migration, the privacy
wording). Stage G gave only a facility's manager a logo and two colors;
G2 gives a normal team's head coach the same. This report is for Joel's yes on the questions, the migration and the
privacy wording before anything runs.

## 1. What G2 changes

| What | Now (Stage G) | G2 |
|---|---|---|
| Who sets a look | a facility's manager (Account → Facility look) | also a normal team's **head coach**, in Account → **Team look** (same editor: logo, two colors, live preview, contrast refusal, Use Knuckleball colors, Remove logo) |
| Who sees it | everyone on that facility while a facility side is the current team | also everyone on that team while it's the current team: its coaches, its rostered pitchers, their parents and linked family |
| What it shows | logo or initials, the facility's name, "Powered by Knuckleball" in the menu and phone header; the colors on the brand, dock and accent tokens | the same, with the **team's** name |
| Never changed | pitch colors, reports, the Live Game field, emails, the wordmark | the same |

The app side is Stage G's code, generalised (the look is already chosen per current team).

## 2. Questions, each with a recommendation

**Q1. Who on a team.** *Recommend:* the head coach only, like rename and level. Assistants see it but can't change it.

**Q2. A pitcher on two teams, or on a team and a facility.** *Recommend:* the look follows the current team, as Stage G
decided. Independent sessions and a pitcher with no team keep Knuckleball's colors.

**Q3. Archived teams.** *Recommend:* no look, and it can't be changed (the same as rename). Restoring the team brings it
back.

**Q4. Hand-off.** *Recommend:* the look belongs to the team, so a new head inherits it and can change it.

**Q5. Deleting a team** (only possible with no sessions). *Recommend:* the colors go with the row. Supabase doesn't let
SQL delete a stored logo, so `delete_team` leaves the file, which nobody can read once the team is gone. The app's
Remove logo deletes it properly.

## 3. The migration, rollback and rules

**`supabase/migrations/20261120000000_n1g2_team_branding.sql`**
- **`teams`** gains `brand_color`, `accent_color` (hex checks), `logo_path` (`^<team uuid>/logo\.(png|jpg|webp)$`) and
  `branding_updated_at`. **No column grant**, so clients still can't read them directly; they're read only through the
  function below.
- **`is_team_reader(team)`** (security definer): the team is not archived, and the caller coaches it (`is_team_coach`),
  or a pitcher on its roster is theirs (own profile, a parent's player, or linked: `is_linked_to`).
- **`my_brandings()`** returns `(team_id, org_id, name, brand_color, accent_color, logo_path, updated_at)`:
  - every facility side, exactly as `my_facility_brandings()` does today;
  - plus every normal team the caller reads (`is_team_reader`), with the team's own values and a null `org_id`.

  `my_facility_brandings()` stays for apps still on v349 and v350.
- **`set_team_branding(team, brand, accent, logo_path)`** returns jsonb. Its checks, in order:
  - `is_team_head(team)` → else `not_allowed`;
  - `kind = 'team'` → else `use_facility_look` (a facility uses its own);
  - not archived → else `team_archived`;
  - both colors or neither → else `both_colors`;
  - the logo path is in the team's own folder → else `bad_logo_path`;
  - a bad hex → `bad_color`.
- **Grants:** the new functions are revoked from public and anon, and granted to authenticated.
- **Storage:** a private bucket `team-logos` (256 KB, png / jpeg / webp), with four policies on `storage.objects` keyed
  on the folder (the team id):
  - members read (`is_team_reader`);
  - the head inserts, updates and deletes (`is_team_head`).
- **Counts:** public policies stay **32**; storage policies go 8 → **12**. No existing rule or function changes.
- **Rollback** (`supabase/rollback/20261120000000_n1g2_team_branding_down.sql`): drops the 4 storage policies, the 3
  functions and the 4 columns. The bucket stays (Supabase refuses storage deletes in SQL, as in Stage G).
- **Test** (`supabase/tests/n1g2_team_branding.sql`, rolled back):
  1. the head sets colors and a logo: ok;
  2. an assistant, a pitcher and an outsider: `not_allowed`;
  3. another team's logo path: `bad_logo_path`; a bad hex: `bad_color`;
  4. a facility side: `use_facility_look`; an archived team: `team_archived`;
  5. `my_brandings()`: the head, an assistant, a rostered pitcher and a linked parent get the team's row; an outsider
     and another team's coach don't. Facility rows match `my_facility_brandings()` exactly;
  6. storage: the head uploads; an assistant and an outsider can't; a rostered pitcher reads; an outsider can't;
  7. 32 public policies, 12 storage policies.

## 4. Privacy wording -- Joel's approval needed (quiet update; TERMS_VERSION unchanged)

Stage G's line in `privacy.html` ("What we collect") becomes:

> **Team and facility details:** a team's or training facility's name, and an optional logo and two colors its head
> coach or manager chooses. They're shown to that team's or facility's coaches, players and families in the app.

## 5. How it will be checked

On staging at 390, 820 and 1180:
- **The U15 Softball head coach:** sets a look; it's refused below 4.5:1.
- **Who sees it:** the U15 pitcher and the parent see it; the assistant on Staging Knights (another team) doesn't.
- **Unchanged:** facility looks and Knuckleball's defaults.
- **Offline:** an offline reload keeps the look.
- **Afterwards:** staging is put back to Knuckleball's colors.

Order: staging migration → test → app → PR. For production: a backup, then your `db push`, then the merge.
