# Track SC — Scale (Oct 1, 2026)

**Joel's target (Oct 1, 2026): 500,000 accounts eventually.** This track is the path from today (production on free tiers, 47 profiles) to that number without a rewrite. The architecture already in place — immutable saved sessions, frozen reports, sport derived in the database, one function per check — is what makes the path incremental. What changes along the way is a short list of things that are free today and become load-bearing at predictable account counts.

## What 500,000 accounts means in load

Accounts are not users. Assume a quarter are active in a month and the active ones chart about 30 pens a year: roughly 100,000 active pitchers, **120 million pitch rows a year (~50 GB)**, **3 million frozen reports a year (~450 GB, permanent by design)**, **6 million report emails a year**, and report pages served at a few hundred GB a month. Infrastructure at that scale lands around **$1,500–3,000 a month**, dominated by email and database compute. Against the pricing model (`claude/pricing-model.md`) that is a rounding error at a 2% paid conversion.

Nothing in that list is unusual for Postgres or object storage. The risks are elsewhere: how reads are computed, per-row RLS on large scans, one request per pitch in the sync path, static-hosting bandwidth caps, and the human side (support, compliance, on-call).

## The sequence, by account count

| Accounts | Infrastructure (Joel, dashboards) | Code (packets) |
|---|---|---|
| **now → 1,000** | **SC0:** production Supabase → Pro; daily backups on; Resend paid when the first facility sends volume; static hosting → Cloudflare Pages | nothing required |
| **1,000 → 20,000** | PITR backup add-on; error monitoring (Sentry or equivalent); report bucket behind Cloudflare | **SC1** session stats at save time; **SC2** batched sync; index audit; P1-06 rate limiting |
| **20,000 → 100,000** | larger compute; read replica for History/reports; Supabase Team plan if schools require SOC 2 / SSO; support tooling and a support person | **SC3** heavy reads as SECURITY DEFINER RPCs; **SC4** partition `pitches` by season |
| **100,000 → 500,000** | reports on Cloudflare R2 (zero egress); dedicated support; load test before each season start | archive cold seasons; nothing structural |

The two code changes that get more expensive with every row — and should therefore land early — are **SC1** and **SC2**. Everything else can wait for its account count.

## The non-code parts that actually fail at scale

- **Support.** At a 1% monthly contact rate, 500,000 accounts is 5,000 tickets a month: a help center, self-serve account tools (change email exists; deletion is required for the App Store anyway), and a person. Jordan's domain.
- **Compliance.** Parent-created child profiles (S3) put COPPA in force; keep the consent record on the parent's account. Schools and districts will ask for SOC 2 and SSO — that is the Supabase Team plan, not Pro.
- **Abuse.** Signup and join-link rate limiting (P1-06, unbuilt) stops being optional. Report tokens are already 64 characters; invite tokens should be audited for entropy at the same time.
- **Operations.** PITR backups, uptime monitoring, and an on-call arrangement. At 100,000 active users a day of downtime is a different kind of event.

---

## SC0 — infrastructure checklist (Joel; no code; production changes are Joel's alone)

1. **Supabase production → Pro.** Dashboard → project → Billing. Production project only; staging stays free (it may pause; unpause before a staging session). Nothing in the repo, migrations or Auth settings changes; Confirm email stays OFF.
2. **Daily backups** are included with Pro — confirm they're appearing under Database → Backups after 24 hours. The "fresh backup before prod schema changes" rule stays (belt and braces).
3. **Resend → paid** the week the first facility starts sending reports (the free tier's 100-a-day cap fails silently to the coach). Same API key, same SMTP settings; nothing changes in the function.
4. **Cloudflare Pages** for the static site when monthly users approach 10,000 (GitHub Pages' 100 GB/month soft limit). Same repo, no build step. Cut over by adding the custom domain in Cloudflare Pages first, confirming it serves, then switching DNS; keep GitHub Pages live until then. The service worker, report CSP hash and Supabase config are unaffected — it's the same files from a different host.
5. **Error monitoring** (Sentry's free tier is enough to start) once SC1 ships, so the first scale bug is seen before a coach reports it.

---

## SC1 — session stats at save time

**Why.** History, the leaderboard, Profile's pitch mix and accuracy, and the trend sections all compute from raw pitch rows on every view. Saved sessions are immutable (Amendment 2), so every session's numbers can be computed **once, at save**, and read forever. This is the single biggest scale change and the earliest one, because the backfill grows with every session saved.

**Design.**
- Table `session_stats`: `session_id` (PK, FK ON DELETE CASCADE), `pitcher_id`, `sport`, `kind`, `pitch_count`, `strikes`, `strike_pct`, `accuracy_pct`, `relative_accuracy_pct`, `velocity_avg`, `velocity_max`, `velocity_n` (Amendment 10 rule applied inside), `by_type jsonb` (per pitch type: count, strike %, accuracy %, velocity), `by_side jsonb` (vs RHB / vs LHB: count, strike %, accuracy %, mix), `zone_counts jsonb` (25 cells, catcher frame), `computed_at`, `stats_version int`.
- One function, `finalize_session_stats(p_session uuid)`, SECURITY DEFINER with `search_path = ''`, called by the same path that marks a session saved (trigger on `sessions` when `saved_at` goes non-null, or inside the save RPC — preconditions decide). Game sessions get `kind='game'` rows with the game-specific fields (`compute_game_summary` already exists — reuse it, don't fork it). Deleting a session (P1-15) cascades the row; the tombstone is unaffected.
- **The SQL function is the single definition of every stat.** The client's History computation is replaced by reads of `session_stats`; the report renderer keeps rendering from the payload in SC1 (reports are frozen; unchanged), but must not drift — acceptance 4 proves the two agree.
- Backfill migration computes a row for every saved session on staging, then production (fresh backup first). `stats_version` lets a later definition change recompute selectively.
- RLS on `session_stats`: readable exactly where the session is readable (reuse the sessions policies' helper functions; no direct reference to teams + pitcher_teams — 42P17). No client INSERT/UPDATE/DELETE; only the function writes.
- Reads: History list and per-session stats, Profile pitch mix / accuracy zones, `get_team_leaderboard` (week / month / all-time, bullpens only per Amendment 12, softball still returns empty per S1) all switch to `session_stats`. In-session live stats keep computing client-side (the session isn't saved yet).

```
ID:              SC1
Title:           Session stats computed once at save
Goal:            A session_stats row is written when a session is saved and is the
                 only thing History, Profile and the leaderboard read. Raw pitch
                 rows are read only while charting, by the report renderer, and
                 by the function that writes the stats.
Depends on:      P1-15 (delete), U7, U8, U11, G2, S1 — all shipped.
Preconditions:   REPORT, with file and line numbers, before any code or SQL:
                   1. Where a session is marked saved today (client call, RPC, or
                      column update) and whether a trigger or RPC is the right
                      hook. Whether the offline queue can save a session before
                      all its pitches have synced (if so, finalize must run after
                      the last pitch lands — say how).
                   2. Every place that computes stats from pitches today: History,
                      Profile (U7), leaderboard (U8), trends, the velocity
                      Amendment 10 rule, in-session live stats. List the exact
                      formulas so the SQL matches them.
                   3. compute_game_summary's shape, so game rows reuse it.
                   4. The sessions RLS helpers to reuse for session_stats.
                   5. Row counts on staging and production for the backfill.
                 Build nothing until Joel has read the report.
Migration:       sc1_session_stats — table, function, trigger/RPC hook, RLS, and
                 the backfill. Staging first; production after a fresh backup, by
                 Joel only. Policy count reported before/after.
Files touched:   bullpen-tracker.html (History, Profile, leaderboard reads);
                 migration; schema.sql; sw.js (CACHE_VERSION).
Out of scope:    The report renderer (keeps rendering from the payload); any
                 change to stat definitions; partitioning; the sync path (SC2).
Acceptance:      1. Save a pen on staging → a session_stats row exists within the
                    same transaction / before the UI shows "saved"; delete it →
                    the row is gone and the tombstone remains.
                 2. Backfill: every saved session on staging has a row; count of
                    sessions = count of rows (minus deleted).
                 3. History, Profile and leaderboard read session_stats: prove
                    with the network/SQL log that no pitch rows are fetched on
                    those screens.
                 4. For every existing session on staging, the client's pre-SC1
                    computation and the stored row agree on every number (a
                    one-off comparison script; 0 differences, or each difference
                    explained and accepted by Joel). Amendment 10's 65-rule is
                    applied identically.
                 5. Games: kind='game' rows carry the compute_game_summary
                    fields; the leaderboard still ignores games; softball
                    leaderboard still empty.
                 6. RLS: a pitcher sees only his rows; a coach sees his team's;
                    a direct INSERT/UPDATE/DELETE on session_stats as any user
                    fails.
                 7. Offline: airplane mode, chart, save, reconnect → the row is
                    written after the last pitch syncs, not before.
                 8. CACHE_VERSION bumped; P1-01 offline checks 1–3 pass.
Verification:    Staging, with Joel checking History and the leaderboard against
                 what he saw before SC1 for two real pitchers.
Rollback:        Code: git revert (the client can go back to computing from
                 pitches). Schema: drop the trigger and table — no existing table
                 is altered.
Size:            L.
Escalate if:     any stat definition can't be reproduced exactly in SQL; the save
                 hook can't guarantee all pitches have landed; the RLS helpers
                 would need a new policy on sessions or pitches.
```

## SC2 — batched sync

**Why.** The P1-01 outbox sends one request per pitch. At 100,000 active devices that is the request volume that drives compute cost and rate-limit risk. One RPC that takes a session's pending rows as a batch cuts it roughly forty-fold and changes nothing in the data model. It also closes half of P1-16: new rows are inserted, never upserted.

**Design.**
- RPC `sync_rows(p_session uuid, p_pitches jsonb, p_events jsonb)`, SECURITY INVOKER so every existing RLS policy applies unchanged. Inserts `pitches` and `game_events` rows `ON CONFLICT (id) DO NOTHING` using the client-generated ids the outbox already carries (precondition confirms). Returns the ids accepted, so the outbox clears exactly those.
- Insert-only. A row that already exists is never modified by the sync path (Amendment 2). In-session corrections (P1-05 as shipped) keep their existing path.
- The outbox batches per session, up to 50 rows per call, keeps its retry/backoff rules, and **falls back to the single-row path** if the RPC is unavailable — a client with a stale service-worker cache must keep working through the rollout.
- Sport, kind and ownership checks are untouched: they're triggers and policies, and the RPC runs as the user.

```
ID:              SC2
Title:           Batched offline sync
Goal:            The outbox syncs a session's pending pitches and game events in
                 batches through one RLS-respecting RPC, insert-only, with the
                 single-row path kept as the fallback.
Depends on:      P1-01 (shipped), S1 triggers (shipped). Independent of SC1.
Preconditions:   REPORT before code: the outbox's queue shape (are ids generated
                 on the client? what is retried, in what order?); the exact
                 PostgREST calls it makes today (insert vs upsert); how
                 game_events rows with after_pitch_id are ordered relative to
                 their pitch; whether any path relies on UPDATE through the
                 outbox (if so, name it — it is the P1-16 gap).
Migration:       sc2_sync_rows — the function only (SECURITY INVOKER,
                 search_path ''). No policy change; counts before = after.
Files touched:   bullpen-tracker.html (outbox); migration; schema.sql; sw.js.
Out of scope:    Any policy change; removing UPDATE from pitches policies (that
                 is P1-16, now easier); SC1.
Acceptance:      1. Airplane mode, chart 45 pitches + 2 events, reconnect → one
                    or two RPC calls (network log), all rows present, ids match.
                 2. Replay the same batch → 0 new rows (idempotent).
                 3. A batch containing a row for a session the user doesn't own
                    is refused by RLS, and the rest of the batch is rolled back
                    (one transaction) — prove with SQL on staging.
                 4. Old client (previous CACHE_VERSION loaded, then the function
                    deployed) keeps syncing via the single-row path.
                 5. RPC unavailable (rename it on staging temporarily) → the
                    outbox falls back and nothing is lost.
                 6. Sport-mismatch and kind CHECK triggers still fire inside the
                    batch (one bad row fails the batch with the same message).
                 7. P1-01 offline checks 1–3 pass; CACHE_VERSION bumped.
Verification:    Staging, Joel charting a pen offline on his phone and reconnecting.
Rollback:        git revert; drop the function.
Size:            M.
Escalate if:     the outbox has no client-generated ids (then SC2 needs a
                 preliminary change and its own packet); any path depends on
                 UPDATE through the outbox.
```

## SC3 / SC4 — scoped only

- **SC3 — heavy reads as RPCs.** Any read that scans more than one session's pitches (trend charts over N sessions, per-type location grids in reports, the Profile accuracy zones if they outlive SC1) moves into a SECURITY DEFINER function that checks entitlement once (`is_pitcher_report_eligible`-style) and then queries, instead of per-row policy evaluation. Written when the slow-query log on Pro shows them; not before.
- **SC4 — partition `pitches` by season.** Declarative partitioning on `created_at` by season (Aug–Jul), with the current season's partition hot. Needs SC1 first (so History never scans pitches) and a maintenance window. Written at ~20 million rows.

---

### Standing constraints (in force)

Service-role key never outside Edge Function env vars. Every schema/RLS change via migration, staging first, fresh backup before production. Never `supabase config push` for Auth settings. Confirm email stays OFF on both projects. `auth.users.email_confirmed_at` is never read. Saved sessions are immutable; no UPDATE path through sync. No policy references `teams` and `pitcher_teams` directly (42P17 — use helpers). Games never feed the leaderboard or accuracy stats. Softball never has a leaderboard. **Only Joel ships to production.**
