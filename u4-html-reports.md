# U4 — HTML reports replace PDF, with vs-RHB / vs-LHB breakdowns

**Design decisions taken by Joel, Sept 10 2026.** This supersedes the U4 packet in `claude/task-packets.md`, which stays as history. Sequenced by D9: after U2a (shipped), before program #1 onboards.

## Decisions settled before build

| Question | Decision |
|---|---|
| Storage & links | **Frozen self-contained HTML file** in a **public** Supabase Storage bucket, unguessable filename, permanent URL. Downloads allowed, listing blocked. **AMENDED Sept 10 — see Amendment 1 at the foot of this doc:** Supabase forces `text/plain` on all HTML from `*.supabase.co`, so the file is not linked directly. It is fetched and rendered by a small `report.html` shell page on knuckleballonline.com, and the emailed link points there. The stored file itself is unchanged. |
| Why not signed URLs | A signed URL is tied to the project's JWT secret. If that ever rotates, every report link ever emailed dies at once — an unrecoverable break of the "links live forever" trust model. |
| Why not a live report page | A stored-payload page means maintaining one renderer that must render every historical payload shape forever, including 5×5 reports after U2b moves to 7×7. Files don't have that problem. |
| Deleted sessions | **The report dies with the session.** U4 records the file path on the session row so P1-15 can delete the object. |
| Location framing | **Overall plots are physical (catcher's view, labeled). Per-side blocks are batter-relative.** Inside a vs-RHB or vs-LHB block the batter side is fixed, so the 1–9 numbering is unambiguous there. |
| Split depth | Each side gets headline stats **and** its own location breakdown. This is a deliberate expansion of the Sept 9 "headline only" scope. |
| Report freshness | Frozen at generation. Trend charts show history as of that moment — a later session does not retroactively appear. That is correct: a report is a record, not a live query. |

## Why frozen files make the rest easy

Saved sessions are immutable (Amendment 2). A report is therefore a pure function of its session plus the history that existed when it was made. So the file is generated **once**, reused for every re-send, and never regenerated. Acceptance check 7 — "a report generated before a later app deploy still renders" — becomes trivially true, because the report is a static file with no dependencies.

## The packet

```
ID:              U4
Title:           HTML reports replace PDF (frozen files, public bucket, per-side splits)
Goal:            Saving a session yields "View report" and "Send report". View opens
                 the full HTML report in the browser. Send emails the report LINK to
                 the assigned contacts (cap 3). The link is an unguessable, permanent
                 URL anyone can open with no account. The report includes vs-RHB and
                 vs-LHB breakdowns computed from the batter_side U2a stores. PDF
                 generation is retired entirely.
Why:             Joel's decision (D9). One renderer to maintain instead of two;
                 reports become viewable immediately instead of only by email; the
                 report is the artifact coaches forward, so it is also the product's
                 main acquisition surface; and U2b's grid change then lands in a
                 single living renderer rather than also being built into a PDF
                 pipeline that is being deleted.
Depends on:      U2a (shipped Sept 9) for batter_side. P0-01 auth on the send path.
Preconditions:   Staging + fresh prod backup (this carries a migration).
                 Before writing code, locate and REPORT (file + line numbers):
                   1. the current PDF build in send-session-report/index.ts — every
                      section it draws, in order. That list is the content spec;
                   2. TYPE_PALETTE_HEX and its twin in bullpen-tracker.html;
                   3. the exact shape of the payload the client sends;
                   4. drawZoneGrid and any other geometry helper;
                   5. every place the client references the PDF or its attachment.
                 Then STOP and show me the section list before building.

Files touched:   NEW migration (storage bucket + policies; sessions gains
                 report_path, report_generated_at);
                 supabase/functions/send-session-report/index.ts (heavy rework);
                 bullpen-tracker.html (buttons, view flow, payload);
                 sw.js (CACHE_VERSION).

BUILD IN TWO PHASES. Stop between them and show me phase 1 output.

  ===================== PHASE 1 — the renderer =====================

  (a) MIGRATION.
      - Create a storage bucket `reports` via SQL in the migration, NOT via the
        dashboard (CLAUDE.md RLS rule 2). Public read.
      - Policies: anon may DOWNLOAD by exact object name; anon may NOT LIST.
        Verify both with the anon key before moving on. Public-read does not
        automatically grant listing, but prove it rather than assuming it.
      - sessions gains: report_path text (nullable), report_generated_at
        timestamptz (nullable). Nullable because most sessions have no report yet.
      - Write the down-migration before deploying.

  (b) OBJECT NAMING. The filename is a fresh long random token (>= 32 hex chars),
      generated server-side with a CSPRNG. It must NOT be derived from the session
      id, pitcher id, date, or anything else guessable. One report per session:
      if sessions.report_path is already set, reuse it — do not regenerate.

  (c) THE FILE MUST BE SELF-CONTAINED AND STATIC. It has to render correctly in
      five years with no network and no maintenance:
      - all CSS in one inline <style> block;
      - NO JavaScript at all;
      - NO external requests — no web fonts (use a system font stack), no CDN,
        no linked images. Any logo is an inline SVG or a data: URI;
      - all charts and zone grids are inline SVG generated server-side. Do not
        add a charting library.
      Upload with Content-Type: text/html; charset=utf-8 (wrong content type and
      browsers download the file instead of showing it) and a long immutable
      Cache-Control, since the file never changes.

  (d) SECURITY — NEW RISK, READ THIS. Until now the function's output went to one
      emailed attachment. Now it becomes a publicly reachable page. The payload is
      still client-supplied, so an authenticated user could try to get arbitrary
      markup hosted under the project's domain.
      - HTML-escape EVERY string that comes from the payload — pitcher name, team
        name, pitch type labels, notes, everything. No exceptions.
      - Coerce every number with a numeric parse and reject NaN.
      - The function builds the document from a FIXED template. It must never
        concatenate client-supplied markup, never accept raw HTML or SVG from the
        client, and never echo a payload field into an attribute unescaped.
      - Keep P0-01: unauthenticated calls to generate/send still 401.

  (e) CONTENT — port what the PDF has today, in the same order (the Preconditions
      list is the spec), plus:
      - A branded header: pitcher, date, pitch count, and the session's charting
        perspective.
      - OVERALL LOCATION PLOTS stay PHYSICAL and are labeled "Catcher's view".
        These mix both batter sides, so they must not use the 1-9 numbering and
        must not say inside/outside — those are batter-relative and would be
        wrong for half the pitches. Use physical language. The zone NAMES used
        in the per-side blocks below are banned here too, for the same reason:
        "up and in" is not a place in space until you know who is hitting.
      - PER-SIDE BLOCKS: one for vs RHB, one for vs LHB. Inside each, batter side
        is fixed, so the 1-9 numbering IS valid and should be used, along with
        inside/outside language. Zones are named with EXACTLY this vocabulary,
        no synonyms and no reworded variants (canonical list, Joel Sept 10 2026;
        also in claude/u2-handedness-clarification.md section 2b):
            1 up and in        2 middle up       3 up and out
            4 middle in        5 middle middle   6 middle out
            7 low and in       8 middle low      9 low and away
        ("low and away" for 9 is deliberate, not an inconsistency with 3 and 6 —
        it is the phrase coaches say. Do not regularise it to "low and out".)
        Show the number and the name together the first time a zone appears in a
        block, so a reader learns the mapping without a legend.
        Each block carries:
          * headline stats: pitch count, strike %, accuracy % (including the
            relative-accuracy result), pitch-type usage mix;
          * a location breakdown by zone, same information architecture as the
            overall one.
      - NULL batter_side (pitches charted before U2a): excluded from the per-side
        blocks, with ONE line saying how many were excluded. Never silently drop
        them from totals.
      - If a pen faced only ONE side: render that side's block and OMIT the other
        entirely. An empty "vs LHB: 0 pitches" column is noise. If it faced
        neither (all NULL), omit both blocks and say so once.
      - Trend charts when 2+ sessions exist, as today.
      - FOOTER: a light Knuckleball mark and a signup path. This report travels;
        the footer is the acquisition surface.
      - Structure the geometry code so grid size is a PARAMETER, not a hardcoded
        5. U2b arrives next and will pass 7.

  (f) TYPE_PALETTE. The palette is still duplicated between the tracker and this
      function. The PDF's TYPE_PALETTE_HEX is replaced by the HTML renderer's
      copy — it must still match the tracker exactly, in order. Same lockstep
      trap, new renderer.

  >>> STOP HERE. Generate a report for a real staging session and give me the
  >>> file. I want to look at it before you touch the email path or delete the
  >>> PDF code. Do not proceed to phase 2 until I say so.

  ===================== PHASE 2 — cut over =====================

  (g) BUTTONS. After save: "View report" opens the report URL; "Send report"
      emails the link. Generate the file lazily on the first of either, then
      reuse it. Both require an authenticated caller.

  (h) EMAIL. Resend now sends a LINK, not an attachment. Recipients cap stays at
      3, recipients stay HTML-escaped. Include the pitcher, date, and two or
      three headline numbers in the email body so it is useful before clicking.

  (i) REMOVE THE PDF PATH. Delete the pdf-lib import and every function that
      only served it. Remove client-side references to the attachment. Check
      whether any secret existed only for the PDF path; REPORT_FROM_EMAIL is
      still needed. Leave no dead code.

  (j) Bump CACHE_VERSION.

Out of scope:    7x7 rendering (U2b — but geometry is a parameter, per (e));
                 changing who reports go to; report expiry or revocation (links
                 live forever by decision — except via session deletion, below);
                 per-at-bat or per-batter detail (Track G); rebuilding reports
                 for old sessions.

Note for P1-15:  sessions.report_path is what lets session deletion also delete
                 the report object. P1-15 will use it. Do NOT build deletion here
                 — just make sure the path is recorded.

Acceptance:      1. Save a session -> "View report" opens the full HTML report;
                    "Send report" emails the link to the assigned contacts (cap 3).
                 2. The link opens in a logged-out incognito window and on a phone.
                 3. NON-ENUMERABLE: neighbouring/guessed object names 404, and an
                    anon-key attempt to LIST the bucket returns nothing. Show both
                    commands and their output.
                 4. Report content matches the current PDF's information, section
                    for section, against the list from Preconditions.
                 5. PER-SIDE: chart a staging pen facing BOTH sides. The vs-RHB and
                    vs-LHB blocks each appear with their own headline stats and
                    location breakdown; the numbers in each add up to that side's
                    pitch count; the two plus any NULL-side pitches equal the
                    session total.
                 6. ONE-SIDED PEN: a pen facing only righties renders the RHB block
                    and NO LHB block.
                 7. LEGACY: a session charted before U2a (all NULL batter_side)
                    renders, omits both per-side blocks, and says why in one line.
                 8. FRAMING: overall plots say "Catcher's view" and use no 1-9
                    numbers, no inside/outside language, and none of the zone
                    names. Per-side blocks do use all three. Confirm by reading
                    the rendered report, not the code.
                 8b. ZONE NAMES: every zone named in a per-side block uses the
                    canonical vocabulary exactly — "up and in", "middle up",
                    "up and out", "middle in", "middle middle", "middle out",
                    "low and in", "middle low", "low and away". grep the rendered
                    report for each string; no synonyms and no variants.
                 9. Unauthenticated calls to generate/send still 401 (P0-01).
                 10. SELF-CONTAINED: open the saved file with the network
                     disabled — it renders fully. grep the file for "http" and
                     confirm no external resource is referenced, and for "<script"
                     and confirm there is none.
                 11. ESCAPING: set a pitcher or team name to
                     <img src=x onerror=alert(1)> on staging, generate a report,
                     and confirm the rendered page shows it as literal text with
                     no element created and no script run.
                 12. A report generated before a later frontend deploy still
                     renders identically (it is a static file — verify, don't
                     assume).
                 13. sessions.report_path and report_generated_at are populated;
                     a second "Send report" reuses the SAME URL rather than
                     generating a new file. Show the SQL.
                 14. PDF path fully removed; no pdf-lib, no dead code, no orphaned
                     secrets.
                 15. P1-01 offline checks 1-3 still pass; CACHE_VERSION bumped.
Verification:    Staging first per DEPLOY.md. Checks 3, 10 and 11 are the ones
                 that protect a publicly hosted artifact — do them deliberately and
                 show the evidence. Production only after a fresh backup.
Rollback:        Functions: git checkout the previous send-session-report and
                 redeploy — the PDF path returns. Frontend: git revert plus a
                 CACHE_VERSION bump. Down-migration drops the columns; note that
                 dropping the bucket destroys every report already emailed, so
                 leave the bucket in place on a rollback and drop only the columns.
Size:            L
Escalate if:     anon listing of the bucket cannot be blocked while keeping
                 downloads public; or the object name cannot be made
                 non-enumerable; or the per-side blocks would require reading the
                 database from the function (a bigger change than this packet —
                 stop and show the design); or the PDF's current section list
                 turns out to contain something that cannot be expressed in static
                 HTML without JavaScript.
```

## Two things this quietly fixes

**CLAUDE.md landmine 5** said reports are computed client-side and can never be regenerated. After U4 the report still cannot be *recomputed*, but it no longer needs to be — the rendered artifact itself is stored permanently and can be re-sent forever. The practical limitation the landmine describes goes away even though the architecture that caused it does not.

**The sample reports' zone naming.** The three sample PDFs in this project label zones "Top-Left", "Mid-Right" and so on. Under D8 those names are ambiguous: "left" depends on both viewpoint and batter handedness. U4 replaces them — physical language on the mixed plots, 1–9 numbering inside the per-side blocks, which is exactly where those numbers are well-defined.

---

## Amendment 1 — Supabase forces text/plain; reports are served through a shell page on knuckleballonline.com (Sept 10, 2026)

**What was found.** During Phase 1, Claude Code discovered that Supabase rewrites `Content-Type: text/html` to `text/plain` on every response from `*.supabase.co` — Storage objects *and* Edge Function responses alike. This is a deliberate, long-standing platform restriction to stop arbitrary pages being hosted on their shared domain, not a bug and not a configuration mistake. Supabase's own position is that HTML responses require a paid custom domain. Verified directly: a report object returns `content-type: text/plain` alongside `content-security-policy: default-src 'none'; sandbox` and `x-content-type-options: nosniff`.

**The fix, and why it is better than the original plan.** The content-type override only matters when a browser *navigates* to the URL and has to decide how to interpret the response. It is irrelevant to a `fetch()`, which returns bytes. Knuckleballonline.com already serves HTML correctly on GitHub Pages. So the report file stays exactly where the packet put it, and a small page on the existing site fetches and renders it.

Confirmed viable by direct test: the Storage response carries `access-control-allow-origin: *`, so the cross-origin fetch is permitted. The CSP and nosniff headers on that response apply only to direct navigation and do not affect a fetch.

Two things this improves over the original design, beyond merely working:

- **The link lives on Joel's domain.** `knuckleballonline.com/report.html?r=<token>` rather than a `supabase.co` URL. This report's job is to travel between coaches and carry a signup path; the domain it arrives on is part of that.
- **A sandboxed iframe cannot execute scripts at all.** The injection risk that motivated the escaping rules in (d) becomes contained by construction rather than by vigilance. The escaping rules still stand — belt and braces — but a single mistake is no longer sufficient to cause harm.

**What stays exactly as specced:** the frozen self-contained HTML file, the public bucket, the unguessable object name, one report per session, reuse on re-send, `sessions.report_path`, and every content and framing rule. The file itself remains JavaScript-free.

**What changes:**

```
  (k) NEW STATIC PAGE: report.html, in the repo, served by GitHub Pages.
      - Reads the report token from the query string (?r=<token>).
      - VALIDATE THE TOKEN BEFORE USING IT. Accept only the exact expected
        shape (hex, expected length) with a strict regex. Never interpolate an
        unvalidated query-string value into the Storage URL — that is how a
        crafted ?r= value turns this page into a fetch-anything proxy.
      - Fetches the object as TEXT from the public bucket.
      - Renders it into <iframe sandbox srcdoc="...">. The sandbox attribute
        must NOT include allow-scripts and must NOT include allow-same-origin.
        An opaque origin with no script execution is the entire point.
      - Sizes the iframe to fill the viewport and scroll internally. Content
        height cannot be measured across an opaque origin, so do not try.
      - Error states, all handled plainly and without a raw stack trace:
        object missing (deleted session, or a bad token), network failure,
        malformed token.
      - A coach must be able to KEEP the report: offer a save/download of the
        fetched HTML. Printing directly out of a sandboxed iframe is fiddly and
        a download the coach opens locally is an acceptable answer — but the
        report must not be a thing that can only ever be looked at.

  (l) EMAIL LINK FORMAT. send-session-report now emails
      https://knuckleballonline.com/report.html?r=<token>, not the Storage URL.
      The Storage URL is an implementation detail and should not appear in any
      email, ever — if it does, recipients get a plain-text wall.

  (m) SERVICE WORKER — CHECK THIS. sw.js is scoped to the whole origin. If it
      has a catch-all navigation fallback to the app shell, opening
      /report.html could serve the TRACKER instead of the report. Verify
      explicitly that /report.html is served correctly with the service worker
      active, on a device that already has the app cached. This is landmine 9
      wearing a new hat.
```

**New acceptance checks:**

```
                 16. Opening the emailed link on desktop and on a phone renders
                     the report inline. No download step, no plain-text wall.
                 17. A crafted token — wrong shape, path traversal, an absolute
                     URL — is rejected by report.html without issuing a fetch.
                     Show the attempts and the behavior.
                 18. The iframe has no allow-scripts and no allow-same-origin.
                     Confirm by reading the rendered DOM, not the source.
                 19. With the service worker active on a device that already has
                     the app cached, /report.html still serves the report and
                     not the tracker shell (check (m)).
                 20. A token whose object does not exist shows a clean message,
                     not an error dump. This is also what a coach sees after
                     P1-15 deletes a session, so the wording should suit that:
                     the report is gone, not the app is broken.
                 21. The report can be saved or printed from the page.
```

**Rejected alternatives, recorded so they are not revisited:**

- **Supabase Pro plus the custom domain add-on** (~$25/mo plus ~$10/mo). The officially sanctioned fix and genuinely clean. Also fixes landmine 7 (free projects pausing when inactive) and improves backups, so the money is not pure cost. Rejected for now because the shell page is free and gets a better domain on the link. **Reconsider if** the shell page proves fragile, or when Pro is wanted for the pausing and backup reasons on its own merits.
- **Committing reports to the repo via the GitHub API.** Free and renders correctly, but requires a repo-write credential in Edge Function env vars and grows the codebase with every report forever. The shell page gets the same domain benefit with neither cost.
- **`Content-Disposition: attachment` to force a download.** Verified working and free, but "download it, find it, open it" on a phone is a poor first impression for the one artifact designed to travel. Acceptable only as a temporary unblock.
