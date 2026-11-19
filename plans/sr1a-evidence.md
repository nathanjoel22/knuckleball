# SR1 Stage A · Session tags · evidence (Nov 19, 2026)

**Where it was tested:**
- Branch `sr1a-session-tags`, cache `kb-shell-v361`.
- Migration `20261123000000_sr1a_session_tags` on **staging** only (`--project-ref wpsscxwawgiwmifpjpec`), recorded in
  staging's migration history.
- `send-session-report` deployed to staging.
- The local staging site, in headless Chrome, at 390 and 820.

Decisions: `plans/sr1a-preconditions.md` (Joel: yes to all).

**Pictures (`plans/sr1a-evidence/`):**
- `tags-phone-390.png`, left to right:
  1. Softball, a pitcher: the start screen with Command chosen ("Compared only with your other command pens.").
  2. Charting: the "Command pen" pill beside "RA off".
  3. History after the sync, with the card's "Command pen" chip and the report header ("Nov 19, 2026 · Command pen
     · U15 Softball Test · …").
  4. Baseball, a coach: Short pen chosen ("A light pen between starts. Compared only with Staging Pitcher's other short
     pens.").
  5. The coach's History: "Short pen" and "Velocity pen" chips; the game card has none.
- `tag-question-820.png`: the coach's start screen at 820, Velocity chosen.

Both pictures were OCR-scanned: no email address and no real name.

## Acceptance checks (packet section 6)

1. **Staging, 390 and 820, both sports: PASS.**
   - Softball: a pitcher's own login at 390.
   - Baseball: a normal-team head coach at 390 and 820.
   - The demo facility's roles weren't used. The question and the save path don't change by team kind; the facility
     path goes through the same `sync_session` check (`coach_sees_pitcher`).
2. **Side by side with the picture: PASS, as far as Stage A goes.** Stage A has no pictures of its own.
   - `b01`'s meta line reads "date · command pen · team"; the built header reads "Nov 19, 2026 · Command pen ·
     U15 Softball Test · 3 pitches · …".
   - **Differences:**
     - the capital C (the header's other words are capitalised);
     - today's pitch count, batter and "charted by" still follow it, because the shorter header is Stage C.
   - **Softball:** the softball start screen and report show the softball blue and pink only.
3. **A report sent before the stage is unchanged: PASS.** Two reports sent before Stage A on staging (a bullpen and a
   game) were hashed before the migration and after the function deploy:

   ```
   38f1a1d48a20d829f89329fa2ea80ddb52b4fe58d772a24ebc96756f058aa50f   (before = after)
   b8c11dae7c03efc6dcfca255bd2f7652043edeb00e83d7c8f7ac432970f593b6   (before = after)
   ```

   **New untagged reports don't change either.** `from_rows.ts` (the same builders as the live path) rendered the same
   sessions with main's code and this branch's code:

   ```
   a925da6f bullpen old 29485 new 29485 IDENTICAL
   a3cda8bf bullpen old 27875 new 27875 IDENTICAL
   505f0131 game    old 68924 new 68924 IDENTICAL
   60d5cc13 game    old 67418 new 67418 IDENTICAL
   39cdfbf4 bullpen old 29485 new 29497 DIFFERENT   ← a Short pen: the 12 characters " · Short pen"
   ```
4. **Checks, cache, STATUS, CLAUDE.md: PASS.**
   - The pre-push checks pass.
   - `CACHE_VERSION` is `kb-shell-v361`.
   - STATUS.md has an entry, and CLAUDE.md gains a "Session tags" section plus the H1 and SC1 lines, all in this PR.
5. **Each tag stores; No tag stores null; a game isn't asked: PASS.**
   - **The server** (`supabase/tests/sr1a_session_tags.sql`, staging, rolled back, 0 fails):

     ```
     5.1 bullpen sent command   -> saved stored command   stats command
     5.2 bullpen sent velocity  -> saved stored velocity  stats velocity
     5.3 bullpen sent short_pen -> saved stored short_pen stats short_pen
     5.4 bullpen sent (none)    -> saved stored null      stats null
     5.5 bullpen sent warmup    -> saved stored null      stats null
     5.6 game    sent command   -> saved stored null      stats null
     | grant sessions:readable stats:readable
     | re-send:already_saved still command
     | lock (as owner):session_saved_locked clear:session_saved_locked
     | game with a tag: check constraint   unknown tag: check constraint
     | recompute:short_pen | policies 32->32 | hard fails 0
     ```
   - **From the app** (the real start screen, charted, saved, synced; staging query):

     | Sport | Who | Chosen | `sessions.purpose` | `session_stats.purpose` |
     |---|---|---|---|---|
     | softball | pitcher | Command | command | command |
     | baseball | coach | Velocity | velocity | velocity |
     | baseball | coach | Short pen | short_pen | short_pen |
     | baseball | coach | No tag | null | null |

   - **Live Game:** the coach's game start screen lists "Will you be using a radar gun today? · Turn on Intent? ·
     Starting mid-game? · Opponent". With Intent on, "Turn on Relative Accuracy?" joins them. There is no tag question
     either way.
   - **Everything on staging:** 152 bullpens (3 tagged, all from these checks) and 99 games (0 tagged).
6. **Saved offline, the tag survives the sync; History and the report show it: PASS.**
   - The softball pitcher's Command pen was ended with the network off (emulated). The outbox item carried
     `purpose: "command"`, and History showed "Nov 19, 2026 · Command pen · PENDING SYNC".
   - Back online, the outbox emptied, and the row has `purpose = command` on the session and its stats row.
   - After a reload, the card still showed "Command pen" from the server's row.
   - Every new report's header:

     ```
     Nov 19, 2026 · Command pen · U15 Softball Test · 3 pitches · No batter · charted by U15 Softball Pitcher
     Nov 19, 2026 · Velocity pen · Staging Knights · 3 pitches · No batter · charted by the coaching staff
     Nov 19, 2026 · Short pen · Staging Knights · 3 pitches · No batter · charted by the coaching staff
     Nov 19, 2026 · Staging Knights · 3 pitches · No batter · charted by the coaching staff
     ```

**Also checked:**
- Policies are 32 public and 12 storage, after.
- `session_stats_failures` is 0.
- The migration and its rollback were dry-run together on staging in one rolled-back transaction before the real
  apply. The rollback returned `sync_session` and `finalize_session_stats` to their original checksums and dropped
  both columns.

## Deviations

- **The four choices sit in two rows of two** (the base styles' `tray-grid`, as used for pitch types). One row of four
  didn't fit at 390. No new CSS.
- **The report header uses "Command pen" with a capital C,** like the rest of its header.

## Staging test data (test accounts only)

- U15 Softball Pitcher: one Command pen.
- Staging Pitcher (Staging Knights): a Velocity pen, a Short pen and an untagged pen, charted by Feed Test Coach.

## Production (Joel's)

1. Backup.
2. `supabase db push --project-ref fkgccjhuimkkbupbanxp`: runs only `20261123000000_sr1a_session_tags`.
3. `supabase functions deploy send-session-report --project-ref fkgccjhuimkkbupbanxp`.
4. Then merge.

**The database must go first.** The new app selects `purpose`, and the new report function reads it. Cached v360 apps
are fine either way: they don't send the tag, so their pens save as untagged.
