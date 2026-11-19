# SR1 Stage A · Session tags · preconditions (Nov 19, 2026)

Read at `e8ecd1c` (main, with PR #122 merged; production v360). Stage A is the first stage, so no stage before it needs
to be live. **Branch:** `sr1a-session-tags`, from `origin/main`.

**The migration and rollback are written** (section 5) and were dry-run on staging inside one transaction that
was then rolled back:
- The migration applied.
- The rollback brought `sync_session` and `finalize_session_stats` back to their original checksums (`0fb73677…`,
  `eab0a2d1…`) and removed both columns.
- Staging was checked afterwards: no `purpose` column. Nothing was committed there.

## 1. What Stage A changes, where it is now

**Database** (staging and production have identical definitions of all three functions by checksum):

| What | Where now | Change |
|---|---|---|
| `sessions` | 31 columns; clients have column grants only | add `purpose text`, a check, and a SELECT grant on it |
| `session_stats` | 27 columns; column grants only | add `purpose text` and a SELECT grant |
| `sync_session(p_session, p_pitches, p_events)` | live def, last changed in `20261030000000_f1a_facilities.sql` | the INSERT into `sessions` takes `purpose` (bullpens, values on the list; anything else becomes null) |
| `sessions_h1_lock()` | live def, `20261025000000_live_game_r3b.sql` | `purpose` joins the fields a saved session can't change |
| `finalize_session_stats(uuid)` | live def, `20261029000000_sc1b_stats_v2.sql` | copies `sessions.purpose` into `session_stats.purpose` |

**Not changed:**
- **Policies:** no policy is added or changed (public stays 32, storage 12).
- **`export-account`:** it reads `sessions` with `select('*')`, so `sessions.csv` gains the column without a change.

**App** (`bullpen-tracker.html`):

| What | Line now | Change |
|---|---|---|
| `startQ` set up for a new session | 8301 | `purpose: null` |
| `setStartQ` | 8333 | unchanged; used for the new question |
| `startSessionNow` | 8402 | `s.purpose` = the answer, bullpens only, fixed from here on |
| `renderStartQuestions` | 8578 | the new question after "Turn on Relative Accuracy?" (bullpens only) |
| `endSession` outbox item | 6625 (`raOn` at 6672) | `purpose` |
| `syncOutbox` session row | 6914 (`ra_on`) | `purpose` |
| outbox → History card (pending) | 6823 | `purpose` |
| `SESSION_COLS` | 7160 | `+ purpose` |
| saved row → session | 7357 | `purpose` |
| History bullpen card header | 13540 (beside `teamChipHtml`, 7101; `.team-chip` CSS 1748) | a "Command pen" chip |
| `sw.js` `CACHE_VERSION` | 18 | `kb-shell-v360` → `v361` |

**Report function** (`supabase/functions/send-session-report/`):

| What | Line now | Change |
|---|---|---|
| `index.ts` session read | 231 (`select('id, pitcher_id, report_path, kind, deleted_at, sport, ra_on')`) | `+ purpose` |
| `index.ts` pen payload | 378 (`raOn: session.ra_on`) | `purpose: session.purpose`, from the row like `ra_on`, never from the client |
| `template.ts` `ReportPayload` | 15–30 | `purpose?: string \| null` |
| `template.ts` pen header meta | 59 | "Nov 18 · Command pen · Demo Eagles · 42 pitches …" when tagged |
| `from_rows.ts` (the operator re-render) | 123, 148 | reads `purpose` the same way, so it stays identical to the live path |

**Where the packet doesn't match the repo:**

1. **Stage A has to deploy the report function.** The packet calls Stage A "database + front end", but its "Shown in
   … the report header meta" needs `send-session-report` changed and deployed (staging, then Joel).
   - An untagged pen's header comes out byte-for-byte as today.
   - Every game's header comes out byte-for-byte as today.
   - Reports already sent are never touched.
2. **The design reference uses older stage letters.** Its "Pictures by stage" table and its "Not drawn" note use the
   blueprint's earlier lettering (e.g. it says "the session-tag question on the start screen (Stage G)", the
   printed pages Stage F, team settings Stage C). It also says softball token values are "proposed in Stage A's
   preconditions". The packet's letters win: this is Stage A for tags, and the softball token values come with Stage
   C ("propose softball values with contrast"). Nothing to build here; flagged so the later stages read it right.
3. **Stage A has no pictures.** For acceptance check 2 (side by side with the picture), I'll compare the report's
   header meta line with the line in `b01` ("· command pen ·"). The rest of `b01` is Stage C.
4. **Line numbers:** every line number the packet gives for Stage A's area matches (start screen ≈8578, `ra_on`
   in the outbox and sync, "Intent is not stored on `sessions`").

## 2. CLAUDE.md decisions this stage touches

| Recorded now (quoted) | New rule beside it |
|---|---|
| H1: "a saved session can't be un-saved, re-timed or change pitcher/team/kind/sport/start/game fields" | …nor its **purpose** (session tag). A wrong tag stays wrong, like the RA answer. |
| SC1: "Any change to how a stat is computed changes the app AND `finalize_session_stats` together (bump `stats_version` in both, recompute)." | Unchanged. `purpose` is **carried, not computed**: no bump, no recompute, existing rows stay null (= no tag, which every existing session is). I'll say so in the SC1 section. |
| U14 / U15: the start questions | One more bullpen question, "What's this pen for?". Nothing else on the start screen moves. |

There's no new rule about the network: the tag list is a constant in the page, so the question works offline.

## 3. Questions for you

1. **The labels.** The packet's list is Command · Velocity · Short pen between starts · No tag. "Short pen between
   starts" is too long for one of four buttons on a 390px phone.
   - **Recommendation:** buttons **Command · Velocity · Short pen · No tag**, with the note under them explaining the
     one chosen (sketch below).
   - **Stored as** `command` / `velocity` / `short_pen`; null = No tag.
2. **The default.** The packet says **No tag** every time.
   - The other choice: remember the pitcher's last answer on the device, as Relative Accuracy does.
   - **Recommendation: the packet's No tag.** A tag only means something when it was picked for this pen, and
     a remembered one would quietly put a velocity pen among the command pens.
3. **When it's fixed.** **Recommendation:** at "Start bullpen ›", like the Relative Accuracy answer. While charting
   it shows read-only beside the RA pill ("Command pen"), and the database locks it at the save.
4. **Where it shows** (the packet says History's card and the report header). **Recommendation:**
   - those two, plus the pending card for a pen still waiting to sync;
   - not Home, Trends or the pitcher's page in Stage A.
5. **The report function deploy** (section 1, item 1): your yes that Stage A deploys `send-session-report`, staging
   first, then you on production, after the database.

## 4. Sketch: the start screen (bullpen, phone, 390px)

```
Bullpen

Which team is this for?          (pitchers on a team only, as today)
[ Demo Eagles ][ Independent ]

Will you be using a radar gun today?
[ Yes ][ No ]

Turn on Relative Accuracy?
[ Yes ][ No ]
A pitch counts as accurate only when it lands on the target.

What's this pen for?
[ Command ][ Velocity ][ Short pen ][ No tag ]     ← No tag selected to start
Compared only with your other command pens.        ← the note follows the choice:
                                                     Velocity:  "Compared only with your other velocity pens."
                                                     Short pen: "A light pen between starts. Compared only with
                                                                 your other short pens."
                                                     No tag:    "Compared with all your pens."
                                                     (a coach sees "<name>'s" in place of "your")

                         [ Start bullpen › ]
```

- **Built with:** the same `segTray` control as the other questions, in one row of four. If it doesn't fit at 390,
  it wraps to two rows of two. No new CSS beyond what the tray already has.
- **Live Game:** the question never appears.
- **While charting:** `[RA off] [Command pen]` sits beside the RA pill.
- **History card:** `Nov 18 · Command pen` in the existing team-chip style (Independent / team name).
- **Report header** (pens with a tag only): `Wed, Nov 18, 2026 · Command pen · Demo Eagles · 42 pitches · …`.

## 5. Migration, rollback, RLS

**Files (written, dry-run on staging, rolled back):**
- `supabase/migrations/20261123000000_sr1a_session_tags.sql`
- `supabase/rollback/20261123000000_sr1a_session_tags_down.sql`

The three functions are copied whole from staging (identical on production). Only the lines marked
`SR1 Stage A` change.

**New schema:**

```sql
alter table public.sessions add column purpose text;
alter table public.sessions add constraint sessions_purpose_check
  check (purpose is null or (purpose in ('command', 'velocity', 'short_pen') and kind = 'bullpen'));
grant select (purpose) on public.sessions to authenticated;

alter table public.session_stats add column purpose text;
grant select (purpose) on public.session_stats to authenticated;
```

**`sync_session`:** the session INSERT gains `purpose`:

```sql
case when coalesce(nullif(p_session ->> 'kind', ''), 'bullpen') = 'bullpen'
      and p_session ->> 'purpose' in ('command', 'velocity', 'short_pen')
     then p_session ->> 'purpose' end
```

A value this server doesn't know saves as no tag rather than failing. So a pen never sticks in the outbox over its
tag (H1: refusals keep an item queued forever).

**`sessions_h1_lock`:** `new.purpose` / `old.purpose` join the "who and what a saved session belongs to" tuple.

**`finalize_session_stats`:** `purpose` is added to the insert's column list, `s.purpose` to its values, and
`purpose = excluded.purpose` to the on-conflict update.

**Rollback:**
1. The three functions return to their old definitions.
2. The `session_stats` column, then the check and the `sessions` column, are dropped.

Tags saved meanwhile go with the columns; the sessions themselves are untouched. An app still sending `purpose`
keeps syncing, because `sync_session` ignores keys it doesn't read.

**RLS:** no policy changes.
- Who can read a tag: whoever can read the session or stats row, under the existing rules.
- Who can write it: only `sync_session`, at the save. Clients have no write rule on `sessions` (H1).
- A test, `supabase/tests/sr1a_session_tags.sql`, will check:
  - each tag, and no tag, stores as sent;
  - a game's tag and an unknown value store null;
  - the lock refuses a changed tag, even from the server's own functions;
  - `session_stats.purpose` follows;
  - policies stay 32.

## 6. The checks I'll run after your yes

The packet's 1–6:
- **Where and who:** staging at 390 and 820, both sports, with the demo facility's roles plus a pitcher and a
  normal-team coach.
- **Each tag:** stored (a query for each); a game is never asked.
- **Offline:** a tagged pen saved with the network off and synced on reconnect keeps its tag.
- **Where it shows:** History and the report header.
- **Sent reports:** one sent before Stage A, hashed before and after.
- **The rest:** the pre-push checks, `kb-shell-v361`, a STATUS entry, the CLAUDE.md lines, all in the PR.

## Joel's answers (Nov 19, 2026)

"yes to all": questions 1–5 as recommended. Labels Command · Velocity · Short pen · No tag; No tag every time; fixed at
Start bullpen; shown in History (pending cards too) and the report header only; Stage A deploys `send-session-report`.
