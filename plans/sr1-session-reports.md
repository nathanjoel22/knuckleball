Written against: STATUS 2026-11-19 (R7 Stage C, one login, several roles), production v360

# SR1 · Session reports, answer-first (Nov 19, 2026)

**From Jordan + Claude, after Joel's comments on Nov 19.** Joel asked Jordan to make the bullpen and game reports
look and read like a professional organization's. The agreed design, with research, a live mockup of every reader's
version and the decisions, is the page **Knuckleball Report Blueprint**
(https://claude.ai/artifact/2dUGP82XbSxEupMr4GgWYF, draft 4; Joel has commented on it). This packet is that page as
build instructions.

**The look is in the repo:** `docs/sr1/` holds a picture of every drawn screen and both emails, and
`plans/sr1-design-reference.md` gives the values behind them (color roles as `--kr-*` tokens, the new tokens, type,
components). Open the pictures for a stage before building it. The text layouts in section 3 show structure only;
the pictures are the approved look.

Seven stages, A to G. **Each stage is its own branch, its own preconditions report, its own PR and (where it changes
an `.html` file) its own cache bump, and reaches staging before Joel ships it. A stage starts only after the one
before it is on production.** Stages A, B and D add columns or functions; C, E and F change the report function and
the app; G is CSS only.

**Only new reports change.** Every report already sent stays exactly as it is (CLAUDE.md: "reports are frozen").
Re-rendering old reports is not part of SR1.

Code facts below were read at `d0391e1` (v360). Line numbers are for finding the place, not a promise; each
preconditions report confirms them.

## 1. Goal

Make every report answer "how did it go?" on its first screen, then let the reader go as deep as they want:

- **four layers, top to bottom:** one computed sentence; the 3–4 numbers that matter, each against the pitcher's own
  history; the why, one tab per question; the full record;
- **tabs instead of one long page:** the game report's 16 sections become 6 tabs, the bullpen's 7 become 4;
- **his own history as the yardstick:** 1-, 3- or 12-month, season or year-ago averages that the reader switches,
  and his normal range;
- **workload in view:** Pitch Smart rest dates on games and a gentle 7-day warning on every report;
- **a front door per reader:** coach, player and parent see the same data with different emphasis, by level;
- **the answer in the email**, not just a button;
- **a printed report that pages**, one tab per page;
- **like-for-like pens:** each bullpen tagged with its purpose.

## 2. Decisions already made (don't re-open; flag if the repo contradicts one)

**Jordan, Nov 19, with Joel's comments the same day:**

1. **Structure.** Four layers (answer · numbers · why · record). Bullpen tabs: Summary · Command · Velocity &
   workload · Trends. Game tabs: Summary · Location · Batters · Pitch types · Trends · Every pitch. Every tab opens
   with a headline that states its takeaway with a number. Tabs are the only level of hiding; inside a tab
   everything is visible.
2. **No grades.** The report never grades or compares to a benchmark. It compares only with the pitcher's own
   history. The 60/70/70 coaching goals stay out.
3. **History windows.** 1, 3 and 12 months and **this season**, switchable by anyone reading the report. **3 months
   is the default**, and it is what the email and "What stood out" use. Little league and high school also get
   **"a year ago"** (the same weeks last year). Seasons (Joel): through high school **Nov 15 – Nov 14**; college
   **Sep 1 – Aug 31**.
4. **Pooled.** A window's average pools pitches (18 of 42 counts as 42 pitches), never an average of session
   percentages.
5. **Thin windows.** A window needs **3+ sessions** of the same kind (and tag, Stage A) to show an average. Below
   that it says "only 2 pens · needs 3" or "no games then". Every comparison shows how many sessions it rests on.
6. **Normal range.** The middle 80% of his sessions in the window (10th to 90th percentile of the session values),
   shown once the window holds **5+ sessions**; with 3–4, the average only.
7. **What stood out.** At most three items, ranked by size, always judged against the 3-month default.
   - Rates (strike %, on the spot, first-pitch strike %, in zone, velocity, each per pitch type too) stand out when
     they fall **outside his normal range**.
   - Patterns have fixed rules (starting values in the table below): a pitch's misses going one way; a fastball fade
     late in the outing; in games, hits clustered in one area, or an inning outside his strike-% range.
8. **Comparisons are like-for-like.** Bullpens with bullpens, games with games, each pitch type with its own
   history, and (Stage A) each bullpen with pens of the same tag.
9. **Workload (Joel + Jordan).** Pitch Smart rest dates on **game** reports, from a **Pitch Smart age group** the
   coach picks per team. A **7-day rolling count of every pitch, bullpens and games together**, on every report,
   with a gentle warning past about **100** under high school, **125** in high school, **150** in college. The
   warning never says a pitcher can't throw; it says that keeping this pace makes fatigue or injury more likely. No
   pro level (very rare; handled if it comes up).
10. **Readers by level.**

    | Level | Player | Parent | Coach |
    |---|---|---|---|
    | Little league | "you" wording; two numbers; what went well first; no velocity; tabs Summary · Where it went · Progress | workload and rest first, one line on how it went; tabs Summary · Progress | full report |
    | High school | "you" wording; four numbers incl. velocity; top two stood-out items; tabs Summary · Command / Location · Batters (games) · Progress | email summary only | full report |
    | College | the full report in "you" wording | none | full report |

    A facility adds nothing to the player or parent versions in SR1 (its planning card is in a later packet).
11. **Parent contact slot (Joel: yes).** Little league and high school players get a `parent` report contact.
12. **Email.** The email carries the headline, 3–4 numbers, one or two stood-out items, rest and the 7-day line (when
    they apply) and the window used, then a button to the full report. Each recipient gets the version for their
    slot.
13. **Print.** Printing the report gives one page per tab. No PDF attachment (later, only if coaches ask; it would
    need a server-side renderer).
14. **Session tags (Joel: "I like this").** A bullpen gets a purpose at the start screen; its comparisons use only pens
    with the same tag. Games have no tag.
15. **Confirm team level.** Teams that never chose a level carry the Oct 2 default, "college". Before reader versions
    go live (Stage E), every head coach confirms the level once.
16. **No gendered pronouns in report text.** Softball uses the same templates, and "his coach" (template.ts:333,
    template_game.ts:545), "he came out" and "he inherited" (template_game.ts:179–180) render for softball today.
    Coach and parent text uses the pitcher's first name or no pronoun; player text uses "you". The pictures say
    "his"; this rule wins over the pictures. *(Jordan, Nov 19; Joel confirms in Stage C's preconditions.)*

**Starting values.** Each must be one constant or one list, so a later change is small. Joel and Jordan review them
against a month of real sessions on staging before Stage E ships:

| Value | Starting value | Where it lives |
|---|---|---|
| Default window | 3 months | `REPORT_DEFAULT_WINDOW` |
| Sessions needed for an average / a range | 3 / 5 | two constants |
| Normal range | 10th–90th percentile | one constant pair |
| Misses going one way | 60%+ of a pitch's misses, with 5+ misses | pattern list |
| Fastball fade | last 10 gunned fastballs 2+ mph under the first 10 | pattern list |
| Hits clustered (games) | half or more of the hits in one third of the zone, with 4+ hits | pattern list |
| Side split | one batter side 15+ points under the other, 10+ pitches each | pattern list |
| 7-day guideline | under high school 100 · high school 125 · college 150 | one object by level |
| Session tags | Command · Velocity · Short pen between starts · No tag | one list |
| Seasons | Nov 15 (through high school) · Sep 1 (college) | one object by level |

**Kept as they are:** the report's look (Broadcast colors, Big Shoulders, the pitcher's-view grids); "The pitches that
mattered"; balls in play on the field, What led to it, Base states; "Recent bullpens vs this game" and "Bullpen to
game" (inside the game Trends tab, unchanged; their redesign is part of the IOR work, its own planning session); the
at-bat log; frozen reports; no JavaScript in a stored report; the three palettes; the 5×5 grid and zone names.

**Code facts that shape the build** (read at `d0391e1`; the full map is in Jordan's notes):

- **Tabs work without scripts.** `report.html` `inertReport()` (≈L148–165) drops scripts, forms and similar, and
  strips `on*` attributes, but keeps `<input>`, `<label>` and `<style>`. History draws each report in its own open
  shadow root (`feedReportHost`, bullpen-tracker.html ≈L16602–16620). So tabs built from hidden radio inputs and
  labels with `:checked` rules work in both places. **Don't use `:target` links**: `:target` doesn't match inside a
  shadow root, and `#` links would change the tracker's hash. If `attachShadow` fails, History falls back to plain
  markup in the page, so every `id` and radio `name` in a report must be unique to its session.
- **Inputs are client-supplied** (CLAUDE.md landmine 5: accepted, don't fix in passing). SR1 adds one server-side
  read on purpose: the history baselines (Stage B), from `session_stats`. The existing client-supplied history keeps
  feeding the Trends charts.
- **`session_stats`** (SC1, migration 20261028000000) has one row per saved session with poolable counts: pitches,
  pitch_count, strikes, hits, exact / ra hits, zone counts, velocity n / sum / min / max, `by_type` and `by_side`
  jsonb, and for games a `game` jsonb with first-pitch strike % and in-zone. No first-pitch figure for bullpens.
- **7-day count:** `pitcher_workload(ids[])` (migration 20261005020000) is a rolling 7 days over bullpens and games
  with the games' +/- adjustment. It is SECURITY INVOKER, so it counts what the caller can see.
- **Level:** `teams.level` via `set_team_level` (Level of play select, bullpen-tracker.html ≈L15766–15775); a solo
  pitcher has `profiles.level` (may be null); a facility team's level comes from its invite. No age-group field
  exists.
- **Contacts:** `profiles.contact_emails` jsonb with `coach`, `pitchingCoach`, `pitcher`, edited only by the
  player's own login or a parent acting as the player (≈L16884–16897). index.ts allows up to 3 recipients, each a
  saved contact (≈L312–324), and sends **one** Resend message to all of them (≈L482–498).
- **Start screen:** `sessions.ra_on` stores the Relative Accuracy answer. Intent is not stored on `sessions`.

## 3. The work

Phone pictures are drawn at 390px, the real width. Each stage names its pictures in `docs/sr1/`; read the matching
section of `plans/sr1-design-reference.md` with them.

### Stage A · Session tags (size M, database + front end)

Pictures: none (the tag shows in every bullpen picture's header as "command pen"). The preconditions report
sketches the start-screen question.

- **Start screen, bullpens only:** a question after "Turn on Relative Accuracy?": *"What's this pen for?"* with the
  session-tag list (decision 14's starting values) and **No tag** as the default. One tap; nothing else changes on
  the start screen. Games are not asked.
- **Stored** on the session (`sessions.purpose`, text, null = no tag; check constraint on the list) and carried
  into `session_stats` (a column, so baselines can filter without a join). The offline outbox and sync carry it
  like `ra_on`.
- **Shown** in History's session card and in the report header meta ("Nov 18 · command pen · Demo Eagles").
- Sessions saved before Stage A have no tag. A tagged pen's baseline uses only pens with the same tag; an untagged
  pen's baseline uses all pens.

### Stage B · History baselines (size M, database function, no visible change)

- **One function** returns, for a pitcher, a session kind and an optional tag, the baselines for every window
  (1, 3, 12 months, this season, a year ago):
  - sessions counted (`n`);
  - pooled values: strike %, on the spot (hits / pitches), in zone and first-pitch strike % (games), average
    velocity, pitches per session; the same per pitch type from `by_type`;
  - the 10th and 90th percentile of the per-session values, when `n` ≥ 5.
- Season start by level (decision 3); "a year ago" is the 3-month window ending on the same date last year.
  Windows end before the session being reported (it never compares with itself).
- **Whose sessions count:** the preconditions report states which rule it follows and why. Recommendation: the
  same reach as `pitcher_workload` (what the caller generating the report can see, R4), so a coach never gets a
  number built from sessions they can't open; the `n` on screen keeps it honest.
- **Tests:** a SQL acceptance test, plus a compare script in the style of `scripts/sc1-compare.js` that checks the
  function's pooled numbers against sessions summed by hand for two demo pitchers (one bullpen-heavy, one with
  games), for every window.

### Stage C · The new report: tabs and the four layers (size L, report function)

Pictures: `b01`–`b04` (bullpen), `g01`–`g06` (game), `b05` (thin window), `g07` (college).

This stage builds **the coach version** (the full report) for both kinds. Stage E adds the other readers.

- **Header:** shorter, as drawn: wordmark + sport tag, name, one meta line. The "charted from behind the catcher"
  note moves to the end of the Summary tab as a caption.
- **Tabs:** radio inputs + labels, `:checked` rules, ids and names unique to the session (section 2). Summary open
  on load. Labels scroll sideways on a phone if they don't fit.
- **Summary tab, bullpen** (`b01`): headline sentence · window switch + caption · four number tiles (on the spot,
  strike %, fastball average mph, pitches) · What stood out · 7-day card (Stage D; until then, leave it out).
- **Summary tab, game** (`g01`): headline sentence · line strip (IP · P · K · BB · H · R) · window switch · four tiles
  (strike %, first-pitch strike %, two of the first three for strikes, in zone) · by-inning table (pitches, strike %,
  fastball mph; the inning that stands out highlighted) · What stood out · rest + 7-day (Stage D).
- **Headline sentence:** built from rules, never free text, never AI. The preconditions report lists the sentence
  templates and which fact picks each (best / worst of the window, the largest stood-out item, otherwise the plain
  line). Examples: "Best command pen of the last six: 43% on the spot, led by the fastball." "First-pitch strikes
  up to 65%, but strikes faded to 56% in the 5th."
- **Window switch:** all windows rendered at save time (from Stage B), switched by radio inputs; 3 months
  checked. College has no "Year ago". Tiles show the change against the chosen window's average, the session count,
  and the range bar when `n` ≥ 5 (`b05` shows the thin state).
- **Two of the first three for strikes** (new, games): share of batters who saw strikes on two of their first three
  pitches, from the pitch order already charted.
- **Other tabs** (each opens with its takeaway headline):
  - Bullpen **Command** (`b02`): hit / miss grids per pitch type (filled = on the spot, ring = missed), the pitch
    table with "vs average", **where misses went** (up, down, arm side, glove side, from target vs actual; new), batter
    side.
  - Bullpen **Velocity & workload** (`b03`): fastball by pitch order with the last-10 band, the pitch table, delivery
    and times to home.
  - Bullpen **Trends** (`b04`): one small line per number, last 6 pens (today's trend data).
  - Game **Location** (`g02`): the grid by result; The pitches that mattered (kept).
  - Game **Batters** (`g03`): times through the order (new table), after the first pitch (new), then the kept sections
    (balls in play, What led to it, Base states, By batter side).
  - Game **Pitch types** (`g04`), **Trends** (`g05`, with the two bullpen-vs-game sections unchanged), **Every pitch**
    (`g06`, the at-bat log as today).
- **Tokens:** add the new `--kr-*` tokens for both sports (design reference); propose softball values with contrast.
- **Wording:** decision 16 throughout, including the footer: "Numbers and patterns only: compared with
  <first name>'s own sessions, never graded." (exact wording for Joel's yes in the preconditions report).
- **Size:** report the byte size of a new bullpen and game report against today's. If either more than doubles,
  stop and report (section 5).

### Stage D · Workload, rest and team settings (size M, database + front end + report)

Pictures: `b06` (warning), `g01` / `g07` (rest + 7-day, under and over the line).

- **Team settings:** a **Pitch Smart age group** row (7–8, 9–10, 11–12, 13–14, 15–16, 17–18, 19–22) next to Level of
  play, head coach only. A solo pitcher sets it on their own profile. A facility team: the preconditions report says
  where it lives, given the level comes from the invite.
- **Confirm the level (decision 15):** a head coach whose team still carries the unchosen default sees a one-time
  prompt to confirm Level of play and the age group. The preconditions report says how "unchosen" is detected
  (there may be no flag today).
- **Rest card, game reports:** Pitch Smart's rest table for the age group and the game's pitch count (with the +/-
  adjustment): "4 days · back Fri, Nov 20". No age group set → the card says so and asks the coach to set it; no
  guessing from level.
- **7-day card, every report:** pitches in the 7 days up to the session's end, bullpens and games, from the same
  logic as `pitcher_workload`, against the guideline for the level (decision 9). Over the line: the warning state
  and wording in `b06`. Little league player wording: "That's more than the 100 guideline. Talk with your coach
  about rest."
- The rest table and the guidelines are constants with their source named in a comment (Pitch Smart's guidelines
  page, checked Nov 19, 2026).

### Stage E · Reader versions (size L, report function + report page + History)

Pictures: `b08`–`b11`, `g09`–`g11`.

- **One stored file holds the versions for its level.** At save time the level is known, so the file carries the
  coach version plus that level's player and parent Summary blocks and tab sets (decision 10). Nothing is fetched
  later.
- **Which version shows:**
  - report.html takes `&v=coach|player|parent` and sets one class on the report's wrapper (report.html has a script
    under its CSP; recompute the hash after the edit);
  - History sets the same class on the shadow host from the signed-in role (a pitcher's own login → player; a
    parent → parent; coaches and facility staff → coach);
  - no `v`, or an unknown one → coach.
- **Little league player:** no velocity anywhere in that version (decision 10). Coaches and parents still see it.
- **College:** no parent version. A `v=parent` link to a college report shows the coach version.
- The preconditions report lists every element that differs by version, per level, as a table, for Joel's yes.

### Stage F · Email and the parent contact (size M, report function + app)

Pictures: `e01`, `e02`.

- **The email body** carries the version for the recipient's slot: headline, 3–4 numbers, one or two stood-out items,
  rest and the 7-day line when they apply, "Compared with <first name>'s 3-month average (5 games)" (decision 16), and
  "Open the full report", linking with that slot's `v`. Subject: "Game report: <name> · 5.0 IP, 5 K · Nov 15" /
  "Bullpen report: <name> · 18 of 42 on the spot · Nov 18".
- **One message per recipient** (up to 3) instead of one message to all, so each gets their own version. Check the
  sending limits (`_shared/rate_limit.ts`): the sender's limit counts requests, the recipient and global quotas count
  recipients; say in the preconditions report whether anything changes.
- **Parent slot:** a `parent` key in `contact_emails`, a "Parent or guardian" field in the contacts panel for little
  league and high school players, and the server check accepting it. Slot → version: coach and pitching coach →
  coach; pitcher → player; parent → parent.
- Email HTML stays table-based for mail apps; no tabs and no window switch in the email.

### Stage G · Print (size S, report CSS only)

Pictures: none; the preconditions report sketches the printed pages.

- `@media print`: every tab's panel shows, each starting a new page; the radio inputs, labels and window switch
  hide; the selected window is the one printed, named on each page; the header repeats on page 1 only.
- Check in Safari (iPhone share → Print) and Chrome (Save as PDF): one page per tab, nothing cut across a page
  break inside a card.

## 4. Out of scope

- **The coach's note.** The note box, a "notes waiting" prompt for the coach, posting the note to Chat with a report
  link, and telling the player: its own packet after SR1 (Joel agreed). The yellow focus card and the facility
  "Plan for next session" card in the pictures belong to that packet. SR1 leaves no space for them.
- **Bullpen vs game analysis** beyond keeping today's two sections: part of the IOR work, its own planning session.
- Re-rendering any report already sent.
- A PDF attachment; a pro level; season dates per team; the 60/70/70 goals.
- Charting, the session sheet, Live Game, voice, saving and sync (Stage A's one question aside).
- Leaderboards, push notifications, widgets.
- Automated click-through tests (Jordan is researching tools separately). Checks here are click paths.

## 5. Escalate if

- A stored report would need JavaScript, or a change to `inertReport()`, to work.
- Tabs or the window switch don't work in History's shadow root, or in its no-shadow fallback with two reports on
  screen.
- A new report is more than twice the size of today's for the same session.
- The baselines need data `session_stats` doesn't hold (for example, a first-pitch figure for bullpens), or
  `session_stats` rows are missing for real sessions (`session_stats_failures`).
- The caller's reach (R4) makes the baseline for the same session differ by who generates the report in a way the
  `n` doesn't explain.
- Any sent report would change.
- The level or age group can't be found for a facility or solo pitcher.
- Any wording would tell a coach, parent or pitcher that a pitcher can't throw.
- Anything here contradicts the repo as it is when the stage starts. Stop and report; don't improvise.

## 6. Acceptance checks — all must pass, each with evidence (command output, query result or click path)

**Every stage:**

1. Staging, local server, at 390 and 820px, baseball and softball. Roles: the demo facility's manager, a pitching
   coach and a pitcher (`tools/seed-demo`); staging test logins (`…@example.com`, listed in STATUS for removal) for
   a parent, a normal-team head coach, and a little league, a high school and a college team.
2. **Side by side with the picture.** For each picture the stage names, a staging screenshot of the built screen at
   390px beside the picture from `docs/sr1/`, both in the evidence file, with a list of every visible difference and
   why. Same order, surfaces, type roles and color roles. A softball screenshot of the same screen shows the
   softball tokens, with no baseball color left.
3. A report sent before the stage opens byte-for-byte as before (hash of the stored file, before and after).
4. Pre-push checks pass; `CACHE_VERSION` bumped where an `.html` file changed; STATUS.md entry in the same PR;
   CLAUDE.md updated where the stage changed a rule.

**Stage A:**

5. A bullpen started with each tag stores it (query); "No tag" stores null; a game is not asked.
6. Saved offline, the tag survives sync. History and the report header show it.

**Stage B:**

7. The SQL acceptance test passes on staging. The compare script matches hand sums for both demo pitchers in every
   window (output shown).
8. A window with 2 sessions returns `n` = 2 and no average; with 4, an average and no range; with 5+, both.
9. A tagged pen's baseline counts only same-tag pens (query); the session itself is never in its own baseline.

**Stage C:**

10. A new bullpen and game report on staging: tabs switch in report.html and in History (phone and iPad), with two
    reports open in History at once; the no-shadow fallback tested by forcing `root = host` locally.
11. Each window button changes the tiles; the counts match Stage B's function for that session (numbers side by
    side). College shows no "Year ago".
12. What stood out: a seeded session above its range, one below, one with a miss pattern and one with a fade each
    produce the expected item; no session shows more than three.
13. No "he", "his" or "him" in the rendered text of a softball and a baseball report (grep of the stored file).
14. Report sizes before and after (bytes).

**Stage D:**

15. The age group saves for a team (head coach only) and a solo pitcher; the confirm prompt shows once for a team on
    the unchosen default and never after.
16. Rest dates match Pitch Smart's table for three seeded games (one per age band) at the band edges (e.g. 50 and 51
    pitches for 13–14).
17. The 7-day count equals `pitcher_workload` for the same pitcher and day; the warning shows just over the line and
    not at or under it, for each level.

**Stage E:**

18. For a little league, a high school and a college report, each `v` shows the version in decision 10's table
    (screenshots); the little league player version has no velocity anywhere (grep of the shown text); a college
    `v=parent` shows the coach version.
19. History shows the player version to a pitcher's own login, the parent version to a parent, and the coach version
    to coaches and facility staff.

**Stage F:**

20. One send to three slots produces three messages, each with its slot's version and link (Resend log or inbox
    screenshots). The parent slot saves for a little league player and is not offered to a college player.
21. The email renders in Gmail (web and iPhone) and Apple Mail without broken layout (screenshots).

**Stage G:**

22. Printing a bullpen and a game report from Safari on iPhone and from Chrome gives one page per tab, nothing split
    inside a card (PDFs attached to the evidence).

## 7. Ship (staging first; production only by Joel)

- One branch per stage from `main`: `sr1a-session-tags`, `sr1b-baselines`, `sr1c-report-tabs`, `sr1d-workload`,
  `sr1e-reader-versions`, `sr1f-email-parent`, `sr1g-print`.
- Each stage: preconditions report (`plans/sr1<x>-preconditions.md`) and stop for Joel → build → acceptance with
  evidence (`plans/sr1<x>-evidence.md`) on staging → cache bump where needed → STATUS.md and CLAUDE.md in the same PR
  → push → PR → stop. Joel checks on his own iPhone and iPad, then merges.
- Stages A, B and D: backup first, migration on staging, tests, then production by Joel. Each migration has its
  rollback written before the forward one runs.
- Stages C, E, F: `supabase functions deploy send-session-report` to staging; production by Joel.
- Rollback: `git revert`, redeploy the previous function, and a cache bump. Reports generated while a stage was live
  stay as they were made.

---

## Paste into Claude Code (one stage at a time; replace <X> and <stage name>)

> Pull `origin/main` and work only from what GitHub has. Read `CLAUDE.md`, the top of `STATUS.md`,
> `plans/sr1-session-reports.md` and `plans/sr1-design-reference.md`, and open this stage's pictures in
> `docs/sr1/`. This is **SR1 Stage <X>: <stage name>**. Stages before <X> must already be on production; if STATUS
> says otherwise, stop and tell me. Branch `sr1<x>-…` from `main` as named in section 7. Standing rules apply:
> staging only, only Joel ships to production, no new dependency, nothing from another host, charting never needs
> the network, sent reports never change, no JavaScript in a stored report, the palettes untouched, pre-push checks
> finish before any push.
>
> **Before writing code, write `plans/sr1<x>-preconditions.md` and stop for me.** It must have: (1) every function,
> table and CSS rule Stage <X> will change, with file and line as they are now, and anything in the packet that no
> longer matches the repo; (2) each recorded CLAUDE.md decision this stage changes, quoted, with the new rule beside
> it, for my yes; (3) the questions the packet leaves to me for this stage, each with your recommendation; (4) for
> anything the packet says was not drawn, a text sketch; (5) for Stages A, B and D, the full migration, rollback and
> RLS; for Stage C, the headline-sentence templates and the footer wording; for Stage E, the table of what differs
> by version and level.
>
> **Then, on my approval, build Stage <X> exactly as section 3 says**, run every "Every stage" check and every Stage
> <X> check in section 6 on staging, write the evidence to `plans/sr1<x>-evidence.md`, bump `CACHE_VERSION` if an
> `.html` file changed, add the STATUS.md entry and the CLAUDE.md changes in the same PR, push, open the PR, and stop
> before production.

### Standing constraints (in force)

No build step. No fonts, scripts or images from other hosts. Legal and policy text only with Joel's approval.
GitHub is the source of truth; pre-push checks finish before any push. **Only Joel ships to production.**
