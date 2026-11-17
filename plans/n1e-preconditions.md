Written against: `7e253ba` (main; production v346, N1 Stages A-D live). Packet: `plans/n1-navigation-and-home.md`, Stage E, with
Joel's J1 (Nov 16-17: the coach's note is a line on the recap, facility coaches too).

# N1 Stage E · Zone pictures in History, the recap, and notes · preconditions (Nov 17, 2026)

**Joel, Nov 17 2026: "YES TO ALL"** -- Q1-Q4 as recommended, the migration (section 4) and the Help wording (section 5).

## 1. What Stage E changes, where it is now

All in `bullpen-tracker.html` unless named.

| What | Where now | Stage E |
|---|---|---|
| History's session bars | `.session-card-head` (date, chips, Pitches / Strikes / Accuracy / mph); the report or plot drawn under it | A small zone picture at the left of every bar (`e-history-zones.png`): a 5×5 heat map, darker = more pitches, pitcher's view, the 3×3 zone outlined. It's built from the stats row's per-type cells (`by_type[t].cells`, already loaded), or from the pitches for an unsynced session. No pitch rows needed, so it draws for every session and offline. |
| After End session & save | `endSession()` saves to the outbox, then goes to History (`state.view = 'history'`) | One screen first, **the recap** (`e-recap.png`), then History. See below. |
| Switch pitcher → Save and switch | `doSwitchPitcher(id, 'save')` calls `endSession()` | Skips the recap (packet). |
| The coach's note | no way to write one since Nov 5; facility teams never could (`is_coach_of_session` refuses them) | An optional "Note to the pitcher" line on the recap, for a coach charting a pitcher, on a normal team or a facility (J1). It shows on the pitcher's / parent's Home (Stage C), in History, and on the report page (`get_report_notes`, unchanged). |
| Notes in History on facility sessions | `renderSessionNotes` hides them on facility teams | Shown, as for any team. |

**The recap** (on the device, from the session just saved; never waits on anything):
- **Header:** the wordmark, then "FINAL · BULLPEN" (or "· LIVE GAME"), the date and time, and the pitcher's name.
- **Three numbers:** pitches; accuracy (the one U14 number); top velo, only when the session used a radar gun. A game
  shows its line (IP, K, BB, H) in place of accuracy.
- **The plot:** History's dot plot in the pitcher's view, on the dark surface (`e-zone-large.png`). Beside it, one line
  per pitch type: count · accuracy.
- **Callout**, only when true, from sessions on the device:
  - "Best <pitch> accuracy in 5 sessions": this pen's accuracy for a type beats each of that pitcher's last 5 sessions
    (same team view as History).
  - "New top velo": higher than any reading on the device.
- **"Note to the pitcher"** (coaches only): one line, optional, 280 characters max. It's kept on the device and saved to
  `session_notes` once the session has synced. Offline, it waits with the session and goes when the session goes.
- **Send report:**
  - synced: today's Send report;
  - not synced yet: "Available once this session has synced", and it takes you to the session in History. No new send
    path.
- **View report** goes to the session in History; **Done** goes to History, as today.
- **Motion:** the label slides in and the numbers count up over about half a second. Nothing moves under reduced motion.

## 2. Recorded decisions this stage changes

| CLAUDE.md now | From Stage E |
|---|---|
| History feed: "**No new coaches' notes** (Chat is the direction): the comment box is gone; existing notes show read-only…" | Coaches write one optional note per session, on the recap. History still has no comment box. |
| F1-A: "**No notes and no leaderboard on facility teams** (`is_coach_of_session` refuses…)" | Notes on facility teams: the pitcher's own group coach or the side's manager (`coach_sees_pitcher`). Still no leaderboard. |

## 3. Questions for Joel, each with a recommendation

**Q1. History's bars: open or closed by default.** Today every session's report is open under its bar (Nov 5). The
picture draws a compact list of closed bars with the zone picture.
*Recommend:* keep them open, as decided Nov 5. The zone picture makes a closed bar useful, but opening every report is
still the History you chose. If you'd rather have the compact list, say "closed": it's one line.

**Q2. Who gets the recap.** *Recommend:* everyone who charts (coaches, pitchers, parents, teens), after every saved
bullpen and game, except Save and switch. The note line is for coaches only.

**Q3. Where the note is shown.** *Recommend:* only where notes already show: the pitcher's / parent's Home card, History
(read-only, under the session), and the report page's "Coaches notes". No email.

**Q4. A note on an unsynced session, if the app is closed before it syncs.** *Recommend:* the note is stored on the
device with the session's outbox item, so it survives a closed app. When the session syncs, the note is saved right
after it. If saving the note fails (say, the coach left the team in between), the session still syncs, and the note
stays queued with the reason shown, like any outbox item.

## 4. The migration (J1) -- for Joel's yes before it runs anywhere

`is_coach_of_session` is used by exactly one rule, `session_notes` "Coaches add notes to their pitchers' sessions"
(INSERT). Nothing else calls it (checked on production). Changing the function changes who may add a note; **no policy
is created, dropped or edited** (still 32).

**`supabase/migrations/20261118000000_n1e_facility_notes.sql`**
```sql
-- N1 Stage E (J1, Joel, Nov 16-17 2026): coaches leave a note on the recap, facility coaches too. On a facility team
-- a note needs the pitcher in the coach's own group, or the side's manager (coach_sees_pitcher). Normal teams are
-- unchanged. Used only by the session_notes INSERT rule.
create or replace function public.is_coach_of_session(p_session_id uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select exists (
    select 1
      from public.sessions s
      join public.team_coaches tc on tc.team_id = s.team_id
      join public.profiles cp on cp.id = tc.coach_id and cp.account_id = auth.uid()
      join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
     where s.id = p_session_id
       and s.started_at >= pt.joined_at
       and (not public.is_facility_team(s.team_id) or public.coach_sees_pitcher(s.team_id, s.pitcher_id))
  );
$$;
```
- **Rollback** (`supabase/rollback/20261118000000_n1e_facility_notes_down.sql`): restores today's body exactly (`and not
  public.is_facility_team(s.team_id)`). Notes written in the meantime stay; they can't be added any more.
- **Test** (`supabase/tests/n1e_facility_notes.sql`, rolled back):
  1. a group coach adds a note on their pitcher's facility session: allowed;
  2. another coach on the same side, not the pitcher's group: refused;
  3. the manager: allowed;
  4. a normal team's coach as before: allowed;
  5. a pitcher writing a note: refused;
  6. 32 policies.
- **Order:** staging migration → test → app on staging → PR. For production: a backup, then Joel's `db push`, before or
  with the merge (v346 shows no note box, so either order is safe).

## 5. Help wording -- Joel's approval needed

Stage A removed Help's coach step 6 ("Add a note") and proposed the Stage E text for your words. Proposed (the Stage A
draft said "at the top of their report"; notes actually sit near the end of the report page, so this says "on"):

> **6. Leave a note.** When you end a session, write a line under **Note to the pitcher**. It shows on their report and
> on their Home.

## 6. How it will be checked

Every packet check (1-5, 26-28) on staging at 390, 820, 1180 and 1440, plus the migration test.
- **26:** every History bar has a picture, and a session's picture matches its report's first plot (same cells, pitcher's
  view), for a RHP and a LHP.
- **27:** the recap offline, for a bullpen and a game. Its numbers equal the History card's. Done, View report and Send
  report go where section 1 says, synced and unsynced. Plus: a coach's note offline, then synced, appears on the
  pitcher's Home, on a normal team and on the facility.
- **28:** reduced motion: nothing moves.

No email: Send report is only checked for where it leads (unsynced), or with your OK on a real send.
