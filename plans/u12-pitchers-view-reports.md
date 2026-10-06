# U12 — Reports in the pitcher's view (Amendment 16, Oct 6, 2026)

**Joel, Oct 6, 2026.** Reports switch from the catcher's view to the **pitcher's view**: the zone as the pitcher sees it from the mound, the way TrackMan and the other charting apps show it, and the way pitchers and pitching coaches read a chart. From today, every new report renders in the pitcher's view. **All existing reports for Cairn University's pitching staff are re-rendered in the pitcher's view at their existing links** — a one-time, deliberate exception to the frozen-report rule, approved by Joel.

## Amendment 16 (supersedes the "Catcher's view" clauses of Amendments 4 and 7)

- **Storage does not change.** Every location stays stored in the catcher frame, exactly as today. The pitcher's view is a display transform: a left–right mirror at render time. Up stays up.
- **D8 numbering still holds.** 1/4/7 are always inside, rows never flip, and the label function (`zoneNumberFor`) takes the view as an input as it already does for the charting perspective. In the pitcher's view a right-handed batter stands on the **right** of the grid and the inside column is the one nearest him. Canonical zone names (Amendment 8) unchanged.
- **Every location grid in a report** — the overall plots, per-type grids, per-side blocks, game location grids, deciding-pitch grids — is drawn in the pitcher's view and labeled **"Pitcher's view"** (replacing "Catcher's view"). The silhouettes or batter labels in the per-side blocks move to match.
- **Not mirrored:** field and spray charts (G4). A field is drawn as a field, home plate at the bottom, left field on the left, as every scorebook and broadcast shows it. Labeled "Field view".
- **One function decides the view** for both renderers (`REPORT_VIEW = 'pitcher'`), so a future per-team or per-user setting is a one-line change, not a second copy of the mapping.

## Decisions made in drafting (Joel may override)

1. **In-app displays follow the reports.** History's session grids, the Profile accuracy zones and any other after-the-fact location display switch to the pitcher's view too, so a pitcher never sees one orientation in the app and another in his report. **The charting screen is unchanged:** the charter still picks Behind the catcher / Behind the pitcher (U5), because that's about where he's standing, not how results are read.
2. **The Cairn re-render rebuilds from stored data with today's renderer.** A frozen file can't be flipped in place. Re-rendering means those reports also pick up everything added since they were first generated (per-type grids, Other events, softball-safe theming, notes section). The pitch data in them is identical. Recorded as the one exception; the rule stays.
3. **Before anything is overwritten, every original Cairn report file is copied** to a private archive path in Storage (`reports-archive/2026-10-06/<same name>`), with a manifest (session id, path, original generated date, byte size, SHA-256). Rollback = copy them back.
4. **Scope of the re-render:** saved sessions whose `team_id` is Cairn's team and that already have a report file. Sessions without a report are untouched (they'll render pitcher's view whenever generated). Reports for every other team stay frozen as they are (catcher's view, correctly labeled); there are only test teams besides Cairn today.
5. **No emails go out.** Links stay the same; nobody is notified. Coaches and parents simply see the pitcher's view the next time they open a link. *Say so if you want Cairn's pitchers told.*

---

## The packet (paste for Claude Code)

```
ID:              U12
Title:           Reports and after-the-fact displays in the pitcher's view;
                 one-time re-render of Cairn's existing reports (Amendment 16)
Spec:            plans/u12-pitchers-view-reports.md (on GitHub; pull first, work
                 only from GitHub). Build to it.
Depends on:      U4/U4b, U5/U5b (perspective + zoneNumberFor), U2a (batter side),
                 U11, G2, G3, S1/S2, S3 (notes on report page). All shipped.
Staging only.    Only Joel ships to production. The re-render touches production
                 Storage: fresh backup, archive copy of every file first, Joel runs
                 it.

PRECONDITIONS — REPORT, with file and line numbers, before any code:
  1. Every place a location grid is drawn after the fact: both report
     renderers (bullpen, game), History, Profile accuracy zones, anything else.
     Which already take a view/perspective input and which hard-code catcher's
     view.
  2. zoneNumberFor and the inside/outside column logic: confirm a mirrored view
     with batter side still yields 1/4/7 inside for both sides (four-case table
     from U2a/D8), in both copies (tracker and send-session-report).
  3. Can send-session-report build a report entirely from stored rows (session,
     pitches, game events, profile, team, notes) without a client payload? If
     not, what's missing — this is required for the re-render.
  4. Storage: how report files are written, whether a private archive path can
     be written only by the function, and how a re-render would overwrite the
     same object name (cache headers; Cloudflare/GitHub caching of report.html
     vs the file itself).
  5. Counts on production: Cairn sessions with a report file; total report
     files by team.
  Build nothing until Joel has read the report.

BUILD:
  - One REPORT_VIEW constant (= 'pitcher') read by both renderers and the
    in-app displays; mirror x at render; labels via zoneNumberFor with the view
    input; batter placement in per-side blocks follows the view; caption
    "Pitcher's view". Field/spray views unaffected and labeled "Field view".
  - History and Profile location displays switch to the pitcher's view (spec
    decision 1). Charting screen unchanged.
  - A server-side "render from stored rows" path in send-session-report if
    precondition 3 says one is needed, used by the re-render and available for
    future regeneration — not exposed to clients.
  - Re-render job (run by Joel, staging first): for each Cairn session with a
    report: copy the existing file to reports-archive/2026-10-06/, record the
    manifest row, render from stored rows in the pitcher's view, overwrite the
    same object name. Dry-run mode prints the list and counts without writing.
  - CLAUDE.md and the status board: Amendment 16 text; the frozen-report rule
    stays, with this one dated exception.

OUT OF SCOPE: changing stored coordinates; changing the charting perspective
  control; re-rendering any non-Cairn report; per-team or per-user view
  settings; emailing anyone.

ACCEPTANCE:
  1. Four-case table (RHB/LHB × pitcher's view) rendered on staging: inside is
     the column nearest the batter and is labeled 1/4/7; up is up; a pitch
     stored at catcher-frame column 0 appears in pitcher's-view column 4.
  2. A staging bullpen report and game report render every location grid in
     the pitcher's view with the new caption; spray/field charts unchanged.
  3. History and Profile show the pitcher's view and agree with the report for
     the same session (screenshots side by side).
  4. Render-from-rows: for three staging sessions, the report built from stored
     rows matches one built from the client payload except for the view.
  5. Re-render dry run on production lists every Cairn session with a report
     and the count matches precondition 5; Joel approves the list.
  6. Re-render on staging first, then production after backup: every archived
     copy present with a manifest row (hash matches the original); every
     overwritten file opens at its old link in the pitcher's view; notes
     still show; no email sent; non-Cairn files byte-identical before/after.
  7. Rollback rehearsed on staging: copying the archive back restores the
     originals byte-for-byte.
  8. Strict escaping and report.html CSP unchanged (recompute the hash only if
     the inline script changes). CACHE_VERSION bumped; P1-01 checks 1–3 pass.
VERIFICATION: Joel opens three Cairn report links on his phone after the
  production run and confirms the orientation with a pitcher.
ROLLBACK: git revert; copy reports-archive/2026-10-06/* back over the
  re-rendered files using the manifest.
SIZE: M.
ESCALATE IF: the renderer can't rebuild a report from stored rows without data
  that only the original client payload had; a mirrored view breaks 1/4/7
  inside for either batter side; overwriting a report object can't be done
  without changing its URL; any non-Cairn file would be touched.
```

### Standing constraints (in force)

Locations are stored in the catcher frame; zone numbers are never stored. One label function. Reports are frozen — Amendment 16's Cairn re-render is the single dated exception. Strict escaping. Fresh backup before production; only Joel ships to production. GitHub is the source of truth.
