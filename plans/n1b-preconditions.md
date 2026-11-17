Written against: `b6d3847` (main; production v343, N1 Stage A live). Packet: `plans/n1-navigation-and-home.md`, Stage B.

# N1 Stage B · Sidebar and roster · preconditions (Nov 17, 2026)

**Joel, Nov 17 2026: "yes to all"** -- Q1-Q8 as recommended, the migration in section 5, and the policy sentences in
section 6 (a quiet update).

## 1. What Stage B changes, where it is now

All in `bullpen-tracker.html` unless named; line numbers as of `b6d3847`.

| What | Where now | Stage B |
|---|---|---|
| Who gets the bottom bar | `dockDevice()` 4198 (touch screens or ≤500px) | Phones only (≤500px). iPads and computers get the sidebar. |
| The left column / top block | the sidebar markup at 14957 (brand block, team line, roster toggle, roster list, outbox badge, Sign out); ≤860px it stacks on top of the page (CSS 1582) | ≥501px: the menu sidebar (below). At 501-860px an icon rail (Q2). Phones: the header in Q1. |
| Tab row (computers) | `renderTabs()` 13460, `state.tabsOff` | Retired; the sidebar replaces it. The archived banner it also drew stays. |
| History / Trends tray | `analysisTray()` (phones and iPads) | Phones keep it. In the sidebar, History opens to Sessions and Trends. |
| Roster | a list inside the sidebar; `rosterCanCollapse` 4174, `toggleRosterCollapsed` 4358, `state.rosterCollapsed`, `dockRoster`, the "roster stands alone" rule (`rosterOnly` 15092) | A page, `state.view = 'roster'`. All of those retire (decision 5). |
| Facility roster actions | `renderFacilityRoster` 4719: the "⋯" menu, Clear / Remove under "New" rows, Move / Add select (fires on change), Remove from this coach (no question) | No actions on rows. Everything moves to **Manage** on the pitcher's page, with confirmations (Q6). |
| Team roster remove | the ✕ on a row and an inline confirm (`armRemoveRosterPitcher` 4802) | Manage → "Remove from this team" opens a sheet (`b-remove-sheet.png`). Same email, same delete. |
| A coach's view of a pitcher | `renderPitcherProfileView` 14075 (Pitcher settings) | The pitcher's page: header, recent sessions, Pitcher settings, then Manage. |
| Picking a pitcher | `selectPitcher` 4362: lands on Home, or History when there's a new session | From the Roster page: the pitcher's page. From the chip: stays on the current view. |
| Team switch | `onTeamChange` 3934: lands on History | Keeps the current view (the archived rule stays: an archived team has no Chart, so Chart becomes History). |
| Pitcher chip | none (coaches switch on the roster) | On Chart and History: the pitcher's photo or initials and name; tap opens a switch sheet (the `renderSwitchSheet` pattern). A parent with several players gets the same chip, listing their players. |
| Account | `renderDataSection` 12171: Download my data and Delete my account side by side | Download stays in "Your data"; Delete my account moves to its own **Danger** group at the bottom of Account. The delete flow's screens are untouched. |
| `remove_from_group` | migration `20261030000000_f1a_facilities.sql`: removing the last group also deletes the `pitcher_teams` row | J3: it only removes the group row (section 5). |

Kept from Stage A: the phone bar, More, the Chat icon, the Sign out sheet, Account / Pitcher settings, the chooser.

**Things in the packet that don't match the repo:**

1. **"Not drawn on the charting screen (as today's rules)."** Today the sidebar *is* drawn while charting on iPads and
   computers. Only phones hide it: `app.innerHTML = (phoneSession ? '' : sidebar)`. On iPad portrait it sits above the
   grid, with the roster rolled up. Kept decision 8 says no sidebar on the charting screen, so Stage B hides it there.
   That gives the charting screen more width (iPad landscape, laptop) or more height (iPad portrait). The grid already
   sizes itself to the space (`sizeWideGrid`). Nothing else on the charting screen changes. Joel: confirm (Q3).
2. **The remove-sheet picture says "him / his".** The app's sentence today uses they / them ("emails them… Their
   sessions"), and so does every Knuckleball text. The built sheet keeps they / them.
3. **"Coaches and groups" (manager, sidebar)** names no existing screen. See Q5.
4. **The packet says "no RPC changes in this stage".** J3 (Joel, Nov 16) adds one: section 5.
5. **Two tests assert the old remove behavior:**
   - `supabase/tests/f1a_acceptance.sql` lines 178-186 (`left side true`, "P03 on side 0");
   - `supabase/tests/f1c1_chat_acceptance.sql` line 173 ("MIN leaves coach B's group (their only one): off the side").

   Both are updated with the migration.

## 2. Recorded decisions this stage changes (Joel approved them Nov 16; quoted for the record)

| CLAUDE.md now | From Stage B |
|---|---|
| "**Phones and iPads** (touch screens, or any window ≤500px; `dockDevice()`) always show the bottom bar" | Phones only (≤500px). iPads and computers: the sidebar. |
| "**Computers** keep the tab row until Stage B" | No tab row; the sidebar. |
| "A coach's open roster list (phones / iPads, `rosterCanCollapse`) still stands alone… (v336)" | Retired: the roster is a page. |
| "On phones and iPads the avatar opens More; computers keep the account dropdown until Stage B's sidebar." | Phones: the avatar opens More. iPads and computers: the sidebar's name row opens Account (Sign out inside it); the dropdown retires. |
| F1-A "Groups … Actions only through `add_to_group`, `remove_from_group` (the last group on a side takes the pitcher off it, departure logged)" | `remove_from_group` never takes the pitcher off the side; they show under "No coach yet". |

## 3. Questions for Joel, each with a recommendation

**Q1. The phone header.** With the roster gone from the top block, the phone still has today's big banner (wordmark,
tagline, COACH tag) and the team line. The Stage A pictures (`a-phone-bar.png`, `a-more-screen.png`) show a plain
header: the wordmark on the left, Chat and the avatar on the right.
*Recommend:* the plain header from the pictures. The team switcher (for anyone on more than one team) moves to the top
of the Roster page and to More's Team group. The offline pill and the waiting-to-sync badge stay just under the header.

**Q2. The icon rail on iPads held upright (501-860px).** Not drawn. Sketch:
```
 ┌────┐                          ┌──────────────────────┐
 │ KB │  wordmark mark → Home    │ KNUCKLEBALL        ✕ │  tap ☰ (or any icon's label area):
 │ ☰  │  opens the full menu     │ <team> ▾             │  the full sidebar slides over the
 │ ⌂  │  Home                    │ ⌂ Home               │  page from the left, 280px, with a
 │ ▤  │  Chart                   │ ▤ Chart              │  dimmed page behind; a tap outside,
 │ ılı│  History                 │ ılı History ▾        │  ✕, or picking an item closes it
 │ ⚇3 │  Roster (+ new count)    │ ⚇ Roster     3 new   │
 │ 💬2│  Chat (facility)         │ FACILITY …           │
 │    │                          │ …                    │
 │ JT │  avatar → Account        │ (JT) Jordan Thayer ▸ │
 └────┘  72px wide               └──────────────────────┘
```
*Recommend:* this. The rail is 72px with icon-only buttons (each ≥44px, with an aria-label) and the active item lit.
The page keeps the rest of the width. (Packet escalate clause: if the rail can't hold the menu without covering
content, I stop and report.)

**Q3. No sidebar on the charting screen at iPad and computer sizes** (mismatch 1). *Recommend:* yes, as decision 8
says. A coach switches pitcher mid-session by tapping the pitcher's name (U15's sheet), as on phones today.

**Q4. Where you land.**
*Recommend:*
- **Picking on the Roster page** opens that pitcher's page. The red "new session" dot no longer jumps to History; the
  dot stays on the row, and the pitcher's page lists the new session first.
- **Switching with the chip** keeps the view you're on.
- **Switching team** keeps the view, except Chart on an archived team, which becomes History.
- **The app's launch** still opens on Home.

**Q5. "Coaches and groups" (facility manager).** Two choices:
- (a) a small page listing the side's coaches, each with their group size, "Show code" and the manager's "Print all
  codes" (existing pieces: `my_group_codes`, `qr-print.html`, the staff list);
- (b) leave it out, since the Roster page already shows the per-coach sections.

*Recommend (a):* it's what the sidebar picture shows, built only from parts that exist. Moving a pitcher stays in Manage.

**Q6. Manage, exactly** (the packet's table, with J3):

| Action | Who | Built |
|---|---|---|
| Clear "New" | manager, the pitcher's own coach | a button, no question |
| Move to coach / Add to coach | manager | pick the coach, then **Confirm** |
| Remove from <coach>'s group / my group | manager, own coach | a sheet: "Removes <name> from <coach>'s group." If it's their only group: "<name> stays at the facility under No coach yet." No email. Buttons: Keep / Remove from group. |
| Remove from facility | manager | a sheet: "Removes <name> from this facility and emails them to let them know. Their sessions and stats aren't deleted, only this facility's view of them." Keep on roster / Remove from facility. |
| Remove from this team | head coach, normal team | the same sheet with "this team's roster" (today's sentence) |

*Recommend:* as above. Nothing about who can do what changes; the server's rules decide as today.

**Q7. Recent sessions on the pitcher's page.**
*Recommend:* the newest 5 from the data History already holds (date, Bullpen / Live Game, pitches, accuracy), each
opening History at that session, and "All sessions ›". It works offline for opened pitchers, as History does.

## 4. Not drawn

- The icon rail: Q2.
- The roster page and the pitcher's page: a list (today's rows, minus the buttons) and a page of existing sections in
  the Stage A style.
- Manage: rows in a `.more-card` like More's, a red row for removals.

## 5. The migration (J3) -- for Joel's yes before it runs anywhere

**`supabase/migrations/20261117000000_n1b_remove_from_group.sql`**
```sql
-- N1 Stage B (J3, Joel, Nov 16 2026): removing a pitcher from their last coach group on a facility side no longer takes
-- them off the side. The pitcher_teams row stays, so they're still on the facility, listed under "No coach yet" for
-- the manager. Only "Remove from facility" (the manager, with the removal email) ends the membership.
-- left_side is still returned (always false) so apps on v343 and earlier keep working.
create or replace function public.remove_from_group(p_group uuid, p_pitcher uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_team uuid;
begin
  select team_id into v_team from public.coach_groups where id = p_group;
  if v_team is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not public.f1a_may_edit_group(p_group) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  delete from public.coach_group_members where group_id = p_group and pitcher_id = p_pitcher;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_in_group'); end if;
  return jsonb_build_object('ok', true, 'left_side', false);
end;
$$;
```
- `create or replace` keeps the existing grants (authenticated only; F1-A's revoke from anon / public still applies).
  The build checks this with `\df+`-style output from `pg_proc` / `information_schema.routine_privileges`.
- **No RLS change, no new table or column.** The policy count stays 32.
- **What follows from it** (by today's rules, unchanged):
  - The pitcher stays on the facility. The manager sees them (under "No coach yet"); the old coach no longer does
    (`coach_sees_pitcher`).
  - Their private chat thread with that coach closes as today (access is computed from groups); the family keeps
    reading it.
  - They keep the facility's Everyone thread.
  - A QR join code later puts them back into a group (`join_group_via_token` already handles "already on the side").
  - No departure row is written, because they didn't depart.

**Rollback: `supabase/rollback/20261117000000_n1b_remove_from_group_down.sql`** restores F1-A's body exactly (the
`v_left` version that deletes the `pitcher_teams` row when no group is left). Pitchers left group-less in the meantime
stay on the side; the manager removes them from the facility if wanted.

**Tests:**
- `f1a_acceptance.sql`: CA removing P03's own last group → `ok, left side false`; "P03 on side 1, departure logged 0".
- `f1c1_chat_acceptance.sql`: MIN removed from their only group → still on the side; the thread stays closed and the
  family keeps reading, as before.
- A new `supabase/tests/n1b_remove_from_group.sql`: the last-group removal keeps the `pitcher_teams` row; the manager
  sees the pitcher, the old coach doesn't; "Remove from facility" still deletes the row and logs the departure. All
  rolled back.

**Order:** staging migration → tests on staging → app build and evidence on staging → PR. For production, Joel takes a
backup (BACKUPS.md), then runs `supabase db push`. That's applied before or with the merge: the app's new sheet text
assumes it, and v343 still works either way.

## 6. Policy sentences -- Joel's approval needed (recorded in the commit message)

After Stage B, Delete my account is at the bottom of **Account**, in its own group. Account opens from More on a phone
and from your name in the sidebar on an iPad or computer. Help already says More → Account → Your data (Stage A).

| Where | Now | Proposed |
|---|---|---|
| `privacy.html` 172 | "in the app: Profile → Your data → Download my data." | "in the app: Account → Your data → Download my data." |
| `privacy.html` 173 | "in the app: Profile → Your data → Delete my account." | "in the app: Account → Delete my account (at the bottom)." |
| `privacy.html` 215 | "In the app, from Profile → Your data: download a copy…, or delete an account…" | "In the app, from Account: download a copy…, or delete an account…" |
| `terms.html` 102 | "in the app (Profile → Your data)." | "in the app (Account)." |
| `delete-account.html` 69 | "open **Profile → Your data → Delete my account**" | "open **Account → Delete my account** (on a phone, Account is under More)" |
| In-app terms notice (tracker 2545) | "in Profile → Your data." | "in Account." |
| `help.html` #data | "More → Account → Your data has Download my data and Delete my account" | "More → Account: Your data has Download my data; Delete my account is at the bottom." |

These are quiet updates: no change to what we do, so `TERMS_VERSION` stays 2026-10-17 and the Version line doesn't
change (as with the Nov 13 host line).

## 7. How it will be checked

Every packet check (1-5, 13-18) on staging at 390, 820, 1180 and 1440px, baseball and softball. Roles: the DS1
manager, pitching coach and pitcher, the parent, the view-only family login and the normal-team coach from Stage A.
Evidence goes in `plans/n1b-evidence.md`, with the side-by-side for `b-sidebar-ipad.png` (1180) and
`b-remove-sheet.png` (390).

Check 17 uses DS1 demo pitchers on staging. "Remove from facility" sends the removal email, and every DS1 pitcher's
address is a `+pitcherN` alias of Jordan's real Gmail. DS1's rule is no email, so see Q8. Afterwards I put the demo
back: re-add them to the group, or re-join them by code.

**Q8. The one removal email in check 17.**
*Recommend:* use the staging test pitcher `feed-pitcher-1793899731@example.com` instead. I add them to the demo facility
by its join code (no email), then remove them. The removal email goes to an example.com address that nobody reads, and
nothing reaches Jordan's inbox. The alternative is one email to a DS1 `+pitcher` alias (Jordan's Gmail).
