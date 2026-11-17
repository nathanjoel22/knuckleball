Written against: `b7e26a7` (main; production v348, N1 Stages A-F live). Packet: `plans/n1-navigation-and-home.md`, Stage G.

# N1 Stage G · Facility name and colors · preconditions (Nov 17, 2026)

**Joel, Nov 17 2026: "yes to all, build it"** -- Q1-Q5 as recommended, the migration and storage rules (section 4)
and the privacy sentence (section 5, a quiet update).

## 1. What Stage G changes

| What | Now | Stage G |
|---|---|---|
| Who can change a facility's look | nobody; `organizations` (id, name, manager_login, created_at) has no client grant and no policy | The facility's manager, through one function, in **Account → Facility look**: a logo and two colors (brand and accent). One setting for the whole facility, both sides. |
| Who sees it | — | Everyone on that facility (coaches, pitchers, parents and linked family of its pitchers) while a facility team is the current team. Through one function that returns only the facilities the caller belongs to. |
| Where it shows | the KNUCKLEBALL wordmark in the menu (≥501px) and the phone header | The logo and the facility's name, with "Powered by Knuckleball" under them (`g-sidebar-facility.png`). The two colors go on the brand, dock and accent tokens, which also color the pitcher card, Home's line score and the recap. |
| How colors apply | `html[data-sport]` swaps token values before paint (`kb:sport`) | The same way: a small block of token values (`--brand-bg`, `--brand-bg-deep`, `--brand-bg-2`, `--brand-line`, `--brand-mid`, `--brand-mid-ring`, `--dock-bg`, `--accent`, `--accent-bright`, `--accent-rgb`, `--accent-ink`, `--on-accent`) worked out from the two colors. It's kept on the device (`kb:facTheme:<uid>`) so it paints offline and before load, like the sport. |
| Never changed by a facility | — | The pitch palettes, frozen reports, the Live Game field, emails, the KNUCKLEBALL wordmark and "Powered by". An archived facility's look isn't applied. |

## 2. How the colors become tokens

- **Brand:** `--brand-bg` is the brand color itself. `--brand-bg-deep` is 25% darker and `--brand-bg-2` 10% lighter.
  `--brand-line` is white at 15%, and `--dock-bg` is the brand at 82%. `--brand-mid` (links and accent text on light
  pages) is the brand, lightened or darkened until it reaches 4.5:1 on white.
- **Accent:** `--accent` is the accent itself, and `--accent-bright` is 15% lighter. `--accent-ink` (accent-colored text
  on light pages) is darkened until it reaches 4.5:1 on white. `--on-accent` is ink or white, whichever reads better on
  the accent.
- **Refused at the picker, with a plain message:**
  - white text on the brand below 4.5:1 ("This brand color is too light for white text. Pick a darker one.");
  - neither ink nor white reaching 4.5:1 on the accent.

## 3. Questions for Joel, each with a recommendation

**Q1. Both sides.** A facility has a baseball side and a softball side, each with its own colors today (green / gold,
navy / pink).
*Recommend:* the facility's colors apply to both sides, as the packet says. The sport still shows in the menu's team box
and on chips; pitch colors never change.

**Q2. The logo.**
*Recommend:*
- PNG, JPEG or WebP; no SVG, which can carry code;
- resized on the device to fit 256 × 256 before upload, so it's small;
- 256 KB at most (the same limit as player photos);
- kept on the device after the first load (IndexedDB), so it shows offline;
- "Remove logo" goes back to the facility's initials in its brand color, as drawn ("TL").

**Q3. Contrast.** *Recommend:* refuse a pair that can't reach 4.5:1 for text (packet), checked in the app, with a live
preview. The server checks only that the colors are real hex colors. A bad pair could only ever affect the manager's own
facility, and the app never lets one through.

**Q4. The phone header.** *Recommend:* on a facility, the phone header shows the logo, the facility's name and
"Powered by Knuckleball", matching the menu. Elsewhere it stays the KNUCKLEBALL wordmark.

**Q5. A pitcher on a facility and a normal team.** *Recommend:* the look follows the current team. On the facility team
the facility's look, on the normal team Knuckleball's. Switching team switches it.

## 4. The migration, rollback and rules -- for Joel's yes before anything runs

**`supabase/migrations/20261119000000_n1g_facility_branding.sql`**
```sql
-- N1 Stage G: a facility's own logo and colors (plans/n1g-preconditions.md). organizations stays closed to clients
-- (no grant, no policy); the manager writes through set_facility_branding, members read through
-- my_facility_brandings. Logos live in the private facility-logos bucket at <org_id>/logo.<ext>.
alter table public.organizations
  add column brand_color  text check (brand_color  ~ '^#[0-9A-Fa-f]{6}$'),
  add column accent_color text check (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
  add column logo_path    text check (logo_path is null or logo_path ~ '^[0-9a-f-]{36}/logo\.(png|jpg|webp)$'),
  add column branding_updated_at timestamptz;

-- The caller belongs to this facility: coaches a non-archived side, or a pitcher on one is theirs (own, a parent's
-- player, or linked).
create function public.is_org_member(p_org uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select exists (
    select 1 from public.teams t
     where t.org_id = p_org and t.kind = 'facility' and t.archived_at is null
       and (public.is_team_coach(t.id)
            or exists (select 1 from public.pitcher_teams pt
                        where pt.team_id = t.id and (public.is_my_profile(pt.pitcher_id) or public.is_linked_to(pt.pitcher_id))))
  );
$$;

create function public.is_org_manager_login(p_org uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select exists (select 1 from public.organizations o where o.id = p_org and o.manager_login = auth.uid());
$$;

-- One row per facility side the caller belongs to.
create function public.my_facility_brandings()
  returns table (team_id uuid, org_id uuid, name text, brand_color text, accent_color text, logo_path text, updated_at timestamptz)
  language sql stable security definer set search_path to '' as $$
  select t.id, o.id, o.name, o.brand_color, o.accent_color, o.logo_path, o.branding_updated_at
    from public.teams t join public.organizations o on o.id = t.org_id
   where t.kind = 'facility' and t.archived_at is null and public.is_org_member(o.id)
     and (public.is_team_coach(t.id)
          or exists (select 1 from public.pitcher_teams pt where pt.team_id = t.id
                      and (public.is_my_profile(pt.pitcher_id) or public.is_linked_to(pt.pitcher_id))));
$$;

-- The manager only. Null colors = Knuckleball's; logo path must be this facility's own file (or null).
create function public.set_facility_branding(p_org uuid, p_brand text, p_accent text, p_logo_path text) returns jsonb
  language plpgsql security definer set search_path to '' as $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  if not public.is_org_manager_login(p_org) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if (p_brand is null) <> (p_accent is null) then return jsonb_build_object('ok', false, 'error', 'both_colors'); end if;
  if p_logo_path is not null and p_logo_path not like p_org::text || '/logo.%' then
    return jsonb_build_object('ok', false, 'error', 'bad_logo_path'); end if;
  update public.organizations set brand_color = p_brand, accent_color = p_accent, logo_path = p_logo_path,
         branding_updated_at = now() where id = p_org;
  return jsonb_build_object('ok', true);
exception when check_violation then
  return jsonb_build_object('ok', false, 'error', 'bad_color');
end;
$$;

revoke execute on function public.is_org_member(uuid), public.is_org_manager_login(uuid),
  public.my_facility_brandings(), public.set_facility_branding(uuid, text, text, text) from public, anon;
grant execute on function public.is_org_member(uuid), public.is_org_manager_login(uuid),
  public.my_facility_brandings(), public.set_facility_branding(uuid, text, text, text) to authenticated;

-- Logos: private, small, images only. Members read; the manager writes, only inside the facility's own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('facility-logos', 'facility-logos', false, 262144, array['image/png', 'image/jpeg', 'image/webp']);
create policy "Facility logos: members read" on storage.objects for select to authenticated
  using (bucket_id = 'facility-logos' and public.is_org_member(((storage.foldername(name))[1])::uuid));
create policy "Facility logos: manager uploads" on storage.objects for insert to authenticated
  with check (bucket_id = 'facility-logos' and public.is_org_manager_login(((storage.foldername(name))[1])::uuid));
create policy "Facility logos: manager replaces" on storage.objects for update to authenticated
  using (bucket_id = 'facility-logos' and public.is_org_manager_login(((storage.foldername(name))[1])::uuid));
create policy "Facility logos: manager removes" on storage.objects for delete to authenticated
  using (bucket_id = 'facility-logos' and public.is_org_manager_login(((storage.foldername(name))[1])::uuid));
```
- **Policy counts:** `public` stays at 32. Storage adds 4, beside the headshots' 4. No existing rule changes.
- **`organizations`** gains 4 columns and stays unreadable to clients (no grant).
- **Rollback** (`supabase/rollback/20261119000000_n1g_facility_branding_down.sql`): drops the 4 storage policies, the 4
  functions and the 4 columns. **Changed during the build:** Supabase refuses to delete storage rows from SQL, so the
  `facility-logos` bucket and any logos stay (unreadable, with no read policy). They're removed from the dashboard if
  wanted. The migration's bucket insert is `on conflict do nothing`, so re-applying after a rollback works.
- **Test** (`supabase/tests/n1g_facility_branding.sql`, rolled back):
  1. the manager sets colors and a logo path: ok;
  2. a pitching coach on the facility: `not_allowed`;
  3. an outsider: `not_allowed`;
  4. a bad hex or another facility's logo path: refused;
  5. `my_facility_brandings()`: the coach, a pitcher on the facility and a linked parent get the row; an outsider and a
     normal-team coach get none;
  6. storage: the manager can insert `org/logo.png`; a pitching coach and an outsider can't; a member can select it and
     an outsider can't;
  7. an archived side returns no row;
  8. 32 public policies.
- **Order:** staging migration → test → app on staging → PR. For production: a backup, then Joel's `db push`, before the
  merge (v348 doesn't call the new functions, so either order is safe).

## 5. Privacy sentence -- Joel's approval needed (quiet update; TERMS_VERSION unchanged)

In `privacy.html` "What we collect", after the player details:

> **Facility details:** a training facility's name, and an optional logo and two colors its manager chooses. They're
> shown to that facility's coaches, players and families in the app.

## 6. How it will be checked

Every packet check (1-5, 32-34) on staging at 390, 820, 1180 and 1440.
- **32:** the migration and rollback run on staging (the rollback on a scratch run, then forward again). The RLS test
  shows a pitching coach and a pitcher can read and not write the branding, and another facility's manager can do
  neither. Staging has only the one DS1 facility, so the second facility lives inside the test (rolled back).
- **33:** with a test logo and two colors on the DS1 facility (staging):
  - the menu, phone header and card show them for the manager, a pitching coach, a pitcher and the view-only family;
  - a normal team and the facility's other sport side behave as decided in Q1;
  - pitch chips, reports and the Live Game field are unchanged.
- **34:** a low-contrast pair is refused, and the theme paints on an offline reload.

Side by side with `g-sidebar-standard.png` and `g-sidebar-facility.png`. Afterwards the DS1 staging facility's look is
put back to Knuckleball's.
