Written against: `6ca2a75` (main; production v344, N1 Stages A and B live). Packet: `plans/n1-navigation-and-home.md`, Stage C.

# N1 Stage C · Home dashboards · preconditions (Nov 17, 2026)

**Joel, Nov 17 2026: "yes to all, build it"** -- Q1-Q8 as recommended, and the one staging note for check 23.

**No migration and no RLS change.** Everything reads what the app can already read. Section 4 shows why that holds.

## 1. What Stage C changes, where it is now

All in `bullpen-tracker.html`.

| What | Where now | Stage C |
|---|---|---|
| Home | `renderHomeTiles()`: four squares (Chart, History, Trends, Account) under the pitcher's big header | A Home per role (below). The four squares go; History, Trends and Account stay on the bar / menu / More. |
| Pitcher's header on Home | `headerHtml` (photo, name, gear) above the squares | Not on Home. The coach's Home is about the team; a pitcher's and a parent's lead with the week (the pictures). |
| The weekly line score | new: `renderLineScore` | One component, used for one pitcher (`c-line-score.png`) and for a roster (one row per pitcher). |
| Coach / manager week data | none (the roster line has `pitcher_workload`'s 7-day sums, not per day) | **Option (a):** one read of `session_stats` (`pitcher_id, started_at, kind, pitch_count`) for the roster for the last 14 days, under its existing read rule. No migration (section 4). |
| Offline | `saveLastKnownContext()` keeps roster, teams, zones… | Adds the week rows (with the time they were read) and `state.workload`, so a coach's Home draws offline, saying "as of <time>". |
| "Needs your attention" | none (the facility's "N new" count is on the roster) | New pitchers (facility `flagged_new`), pitchers with no session in 5+ days (`IDLE_FLAG_DAYS`, from `pitcher_workload.last_at`), unread chat. Each row opens what it names. |
| The coach's note | `session_notes` already come with History's sessions (`mapSessionNotes`) | The newest note on the pitcher's sessions, as a card. Nothing on a facility team until Stage E lets its coaches write. |
| Last session / latest report | History's card and plot (`renderHistoryPlot`, `penCardStats`) | The same plot, small, with date, pitches, accuracy, pitch chips and "Open report ›" (opens the session in History, where its report draws). |

## 2. The four Homes (from the packet and the pictures)

**Pitcher, teen** (their own login; a linked `child` sign-in) -- `c-home-pitcher.png`:
1. the line score ("This week · pitches", "Nov 16 to 22");
2. **Chart today** ("Resume" when a draft is waiting);
3. the coach's note, when there is one;
4. Last session (plot, "Bullpen · Nov 10", "31 pitches · 58% accuracy", chips, Open report ›);
5. a Trends link.

**Parent** (a parent login with a player active; a linked `guardian`) -- `c-home-parent.png`:
1. the player chip;
2. "<Name> threw 68 pitches in 2 sessions this week." over the line score;
3. the note ("For Noah · from Coach Ortiz · Nov 10");
4. Latest report;
5. Earlier (the next sessions, one line each).

**View-only family:** the parent's Home without Chart.

**Coach** -- `c-home-coach.png`:
1. three numbers: **Active** "2 of 5", **Sessions**, **Pitches** this week;
2. **Start a session** (on an archived team: none);
3. the roster line score;
4. Needs your attention;
5. Recent sessions.

**Facility manager** -- the right side of `b-sidebar-ipad.png`: the coach's Home across every coach, plus "By coach" (active of total per coach group). A pitching coach's Home covers their own group only. The server already limits what they read (`coach_sees_pitcher`), and the app's roster is the same set.

**Layout:** phones stack everything. Above 860px, Needs your attention and the line score sit side by side, as in the
iPad picture.

## 3. Questions for Joel, each with a recommendation

**Q1. What counts as "active"** in "Active 2 of 5"?
*Recommend:* a pitcher with at least one session this week (Sunday to Saturday). "Of 5" = everyone on the roster (for a
pitching coach, their group).

**Q2. Which number is "pitches".** Each session has `pitches` (charted) and `pitch_count` (charted plus a game's +K / +B
adjustments).
*Recommend:* `pitch_count`, the same number the roster's "Last 7 days · N pitches" line already uses, so the two never
disagree. For a bullpen they're the same.

**Q3. Days still to come this week.** The picture is drawn on a Saturday, so every day is past or today.
*Recommend:* days after today show an empty, dimmer cell (no number). Today is outlined and shows "–" until something is
charted today, then the number.

**Q4. A big roster in the coach's line score.** The manager sees 10+ pitchers.
*Recommend:* pitchers who threw this week come first, most pitches first. Then one line, "+ 7 with no pitches this week
›", which opens the rest. That keeps the scoreboard short on a phone.

**Q5. "Needs your attention": pitchers who have never thrown.** `last_at` is empty for them.
*Recommend:* list them after the idle ones as "No sessions yet", in the same row style. A brand-new pitcher who's never
charted is exactly who a coach should notice.

**Q6. Recent sessions on the coach's Home.**
*Recommend:* the newest 5 from the same 14-day read, each "Name · Bullpen · Nov 10 · 31 pitches", opening that pitcher's
History.

**Q7. The parent's player chip with only one player.**
*Recommend:* show the chip anyway (name and photo), without the ▾ and without opening anything, as drawn. With several
players it switches, as Stage B built.

**Q8. The manager's Home title.** The picture says "THIS WEEK AT THE LAB".
*Recommend:* "This week" plus the facility's own name underneath ("Thayer Pitching Lab" on staging), so it's right for
any facility. A normal team's coach gets "This week" and the team name.

## 4. Data and rules (checked on production, read-only)

- `session_stats` has `pitcher_id`, `started_at`, `kind`, `pitch_count`, `pitches`. Its one read rule is "where the
  session's pitches are read": the pitcher, anyone linked, `coach_sees_pitcher(team, pitcher)`, or a current coach since
  the session started. The roster query therefore returns exactly what each coach may see: a pitching coach their
  group, the manager everyone. **No new function or migration.**
- Deleted sessions have no stats row (the trigger removes it), so they never count.
- Sessions waiting in the outbox count, from the device, for the pitchers they belong to.
- **Parents can read the note** (the packet's escalate check). The `session_notes` read rule allows
  `is_my_profile(pitcher)` (the parent owns the player's profile) and `is_linked_to(pitcher)` (a linked guardian, teen
  or family). So no stop.
- `pitcher_workload(ids)` returns `last_at` per pitcher; it already loads for the roster.
- The week is Sunday to Saturday in the device's time zone; `started_at` is converted to the local day.

## 5. Not drawn

- Home for a coach with no pitchers yet: the three numbers at 0 of 0, then the invite button (today's "Get the invite
  link").
- A pitcher with no sessions: the line score at 0, Chart today, then "Your first session shows up here."
- Recent sessions and "By coach": `.more-card` rows in the Stage A style.

## 6. How it will be checked

Every packet check (1-5, 19-23) on staging at 390, 820, 1180 and 1440. Roles: the DS1 manager, pitching coach and
pitcher, the parent, the view-only family and the normal-team coach.
- **19:** line-score totals side by side with History's counts for the same week.
- **20:** a pitcher at 5 days idle listed and one at 4 days not. These are computed from real `last_at` values on staging,
  or, if none sits at exactly 4 or 5 days, by checking the cutoff function on dates on the device.
- **21:** a pitching coach's Home against the manager's.
- **22:** a pen saved offline shows in the line score before it syncs.
- **23:** a note shows for the pitcher and the parent on a normal team. The U15 test team has a coach and a parent; I'd
  write one note there through the existing insert rule, on staging only.

Side by side with `c-home-pitcher.png`, `c-home-parent.png`, `c-home-coach.png` and `c-line-score.png`; the manager's Home
at 1180 against `b-sidebar-ipad.png`.
