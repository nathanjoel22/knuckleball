# L1 · New landing page at `/`; sign-in moves to `signin.html`

Packet for Claude Code. Run from the repo root (`~/knuckleball-repo`). **Read `CLAUDE.md` first; where it and this packet disagree, `CLAUDE.md` wins.** Frontend-only: no migration, no Edge Function change, no dashboard change by you.

## 1. Goal

The reviewed D2 "Broadcast" landing page becomes what `knuckleballonline.com/` serves. The page that lives at `/` today (sign in + sign up) keeps working unchanged at a new address, `signin.html`. Every **Sign in** link anywhere on the site goes to `signin.html`; every **Join / Start charting free / Choose …** button goes to `signin.html#signup`. A person who is already signed in, or who arrives from an auth email, never sees the landing page: `/` forwards them to `signin.html`, which already knows what to do with a session or a token. Nothing about charting, offline, auth logic, reports or the database changes.

## 2. What Joel is handing you

`~/Downloads/knuckleball-landing.zip` (Joel will confirm the path if different). Unpack it **outside** the repo:

```bash
rm -rf /tmp/kb-landing && mkdir -p /tmp/kb-landing && unzip -q ~/Downloads/knuckleball-landing.zip -d /tmp/kb-landing
BUNDLE=/tmp/kb-landing/knuckleball-landing
(cd "$BUNDLE" && shasum -a 256 -c MANIFEST.sha256 | grep -v ': OK$'; echo "bundle verified")   # prints only failures
```

| In the bundle | What it is | What you do with it |
|---|---|---|
| `landing.html` | The finished page: real `<head>`, review notes stripped, links rewired, sign-in forwarder in place. Verified in a browser against the shipped tokens and fonts. | Copy to `index.html` (§4.2). **Do not retype it, restyle it, or change copy.** The only edits allowed are the ones in §4.3 and §4.4. |
| `media/` (13 MB) | Hero film ×4 encodes, posters, stills, 13 app/report screenshots (invented test data) | Copy into the repo at the same paths |
| `vendor/icons/arm.png` | Arm-care tile icon | Copy if missing |
| `_reference/` | Copies of `css/tokens.css`, `buttons.css`, `css/components.css`, `vendor/fonts/*` **as the page was designed against** | **Diff only. Never copy into the repo.** The repo's versions are canonical. |
| `MANIFEST.sha256`, `README.txt` | Checksums, this table | Never enters the repo |

## 3. Decisions already made (don't re-open; flag if the repo contradicts one)

1. Landing page = `index.html` (what GitHub Pages serves at `/`). Current `index.html` → `signin.html` via `git mv`; its content does not change except self-references and the small items in §4.6–4.7.
2. "Sign in" → `signin.html` everywhere (landing nav, phone menu, footer; and every other page that has one: `privacy.html`, `terms.html`, `report.html`…). Join-type CTAs → `signin.html#signup`.
3. `/` forwards signed-in people and auth links before anything draws. It's an inline script at the top of `<head>` in `landing.html` — reads `localStorage` only (any `sb-<ref>-auth-token` key, so prod and staging both work), preserves `?query` and `#hash`, and exempts the page's own section anchors (`#pricing`, `#faq` …) so a signed-in coach can still read the page. It works with no signal. **Do not add a Supabase client or any network call to the landing page.**
4. The landing page **does not register the service worker** and loads nothing from another host. The SW still precaches it (so an installed PWA whose `start_url` is still `/` can launch offline and be forwarded), plus `signin.html`. The SW must **never cache the hero media**.
5. `manifest` `start_url` moves off `/` to the page a signed-in person actually lands on (§4.6), so new installs skip the forwarder entirely. Existing iOS installs keep their old `start_url`; the forwarder covers them.
6. Brand/logo links on public pages (`report.html` footer etc.) → `/` (landing). Auth-flow redirects (sign-out, no-session guards) → `signin.html`. Frozen stored reports are never edited.
7. Copy, the "Price not set" tiers and the "Coming next: arm care" teaser ship as reviewed. Joel's follow-ups are in §8, not yours.

## 4. The work

### Gate 1 — discovery first. Run all of this, report (§7 format), then STOP and wait for Joel's go.

```bash
git status --short; git log --oneline -3
find . -path ./.git -prune -o -path ./supabase/.temp -prune -o -type f -print | sort            # file tree

# A. what is index.html today, and where does a signed-in person end up?
grep -n -i -E 'getSession|getUser|onAuthStateChange|signInWith|signUp\(|signOut|location\.(href|replace|assign)|<form|serviceWorker' index.html | head -80

# B. every reference to the entry point or to auth redirect targets (each one gets a decision in your report)
grep -rn -E "index\.html|href=\"/\"|href='/'|location\.(href|replace|assign)\s*=\s*['\"]\.?/?['\"]|location\.origin|redirectTo|emailRedirectTo|knuckleballonline\.com" \
  --include='*.html' --include='*.js' --include='*.ts' --include='*.json' --include='*.webmanifest' --include='*.md' . | grep -v -E '^\./(\.git|supabase/\.temp)'

# C. service worker: version, precache list, how navigations and runtime caching work
grep -n -E "CACHE_VERSION|CACHE_NAME|addAll|PRECACHE|SHELL|navigate|respondWith|cache\.put|caches\.match|index\.html|['\"]\./?['\"]" sw.js

# D. manifest + head tags the landing page must inherit
ls manifest.json manifest.webmanifest site.webmanifest 2>/dev/null; cat manifest.json 2>/dev/null
grep -n -E 'rel="(manifest|icon|apple-touch-icon)"|theme-color|apple-mobile-web-app|serviceWorker\.register' index.html

# E. bundle vs repo: shared CSS/fonts must be identical or the diff must be understood; media must not collide
for f in css/tokens.css css/components.css buttons.css vendor/fonts/fonts.css vendor/fonts/*.woff2 vendor/fonts/*.ttf; do
  [ -f "$BUNDLE/_reference/$f" ] || continue; cmp -s "$f" "$BUNDLE/_reference/$f" && echo "same  $f" || echo "DIFF  $f"; done
ls -R media vendor/icons 2>/dev/null

# F. pages the landing page links to, and features its copy promises
ls privacy.html terms.html 2>&1
grep -n -i -E 'id="[^"]*(delete|deletion)[^"]*"' privacy.html
grep -n -i -E 'signup|sign-up|create account|createaccount|#signup' index.html | head -20
grep -rn -i -E 'under 13|parent|guardian|coppa' --include='*.html' --include='*.sql' . | grep -v -E '^\./(\.git|supabase/\.temp)' | head -20
grep -rn -i -E 'sign in|signin|log in|login' --include='*.html' . | grep -i 'href' | grep -v -E '^\./(index|\.git)' | head -30
```

Report, as a table: (1) what `index.html` is — auth-only page that forwards to an app page, or the app shell itself — and the page a signed-in person lands on; (2) every line from B with your proposed treatment (`signin.html` / `/` / leave); (3) sw.js in three lines: precache form (`'/'`, `'./index.html'`…), navigation strategy, whether anything is cached at runtime; (4) manifest file name, `start_url`, `scope`; (5) E results — any `DIFF` is a **stop-and-ask** before §4.2 (a token the page uses may have been renamed; `_reference/` exists so you can `diff` it); any existing `media/` or `vendor/icons/arm.png` collision; (6) F results: `terms.html` exists?, a deletion anchor in `privacy.html`?, does `index.html` have a sign-up mode you can select from a hash?, is there an under-13 / parent flow in the app?

**If `index.html` is the whole app shell (login + Home + charting in one file), stop here** — then it should be named `app.html`, not `signin.html`, and Joel decides.

### 4.1 Move the sign-in page (one `git mv`, nothing else in this step)

```bash
git mv index.html signin.html
grep -n -E "index\.html|history\.(push|replace)State" signin.html      # self-references → signin.html
```

### 4.2 Bring in the page and its assets

```bash
cp "$BUNDLE/landing.html" index.html
mkdir -p media vendor/icons && cp -R "$BUNDLE/media/." media/ && [ -f vendor/icons/arm.png ] || cp "$BUNDLE/vendor/icons/arm.png" vendor/icons/
git status --short | grep -E 'css/|buttons\.css|vendor/fonts' && echo "STOP: shared CSS/fonts changed" || echo "shared CSS untouched"
```

Nothing from `_reference/`, `MANIFEST.sha256` or `README.txt` enters the repo.

### 4.3 Finish the `<head>` of the new `index.html` (the only edits to the file)

At the comment `<!-- L1 §4.3: … -->` insert, copied verbatim from `signin.html` (or from the app page if `signin.html` has none): the `<link rel="icon" …>`, `<link rel="apple-touch-icon" …>` and `<link rel="manifest" …>` tags. **Not** the service-worker registration, **not** any Supabase `<script>`, not `apple-mobile-web-app-*` metas. Keep the page's own `theme-color` (`#030D09` = `--brand-bg-deep`). Then remove the placeholder comment.

### 4.4 Link targets that depend on what F found (edit `index.html` only where stated)

- `href="terms.html"` (footer, 1×): if `terms.html` doesn't exist, point it at wherever the terms live (`privacy.html#<id>` if there's a terms section) or remove the `<a>`; report which.
- `href="privacy.html"` on the footer's **Delete account** link (it's the third `privacy.html` link, text "Delete account"): if `privacy.html` has a deletion section with an id, append `#<id>`; if the app has a dedicated deletion page, use that. Otherwise leave it.
- `signin.html#signup` (6×): see §4.7.

### 4.5 Point the app at `signin.html`

For each line in discovery B, apply decision 3.6: sign-out and no-session redirects → `signin.html`; brand/home links on public pages → `/`. Then in **`sw.js`**:
1. Precache list: keep the entry that serves `/` (`'/'`, `'./'` or `'./index.html'` in whatever form it uses) **and add `'./signin.html'`** in the same form.
2. If the fetch handler caches anything at runtime (`cache.put` outside `install`), exclude paths under `media/hero-` and `media/shots/` from it (plain pass-through, no `respondWith`). If it only ever serves the precache list and sends everything else to the network, change nothing and say so.
3. Bump `CACHE_VERSION` (`kb-shell-vN` → `vN+1`).

Do not touch the draft/outbox/sync code, the auth guard logic itself (only its URL strings), or the report payload.

### 4.6 Manifest

`start_url` → the page a signed-in person lands on after `signin.html` forwards them (from discovery A). If `signin.html` itself is where a signed-in person stays, `start_url` → `signin.html`. Leave `scope` (should be `/` or `./`) and `id` alone. Add `<meta name="robots" content="noindex">` to the `<head>` of `signin.html`.

### 4.7 `#signup`

- If `signin.html` has a sign-up mode (tab, toggle, second form) selectable from JS: add the smallest possible hook — on load, `if (location.hash === '#signup')` select it. Nothing else.
- If sign-up is a separate page (e.g. `signup.html`): `sed` the six `href="signin.html#signup"` in `index.html` to that page.
- If both forms are always visible: leave the links (the hash is harmless).
Report which case applied.

### 4.8 Docs (last commit)

- `CLAUDE.md`, in the page map / file list: `index.html` = marketing landing page (no SW registration, no Supabase, forwards signed-in users to `signin.html`); `signin.html` = sign in / sign up, formerly `index.html`.
- `DEPLOY.md` smoke checklist: add "`/` shows the landing page; `/signin.html` shows sign in; signed-in device opening `/` lands in the app".
- Save this packet as `plans/l1-landing-page.md`.

### Commits (push nothing until §5 passes)

1. `L1: landing-page media and icon` — `media/`, `vendor/icons/arm.png` only (deployable on its own, changes nothing).
2. `L1: landing page at /, sign-in moves to signin.html` — everything in 4.1–4.7, one atomic commit so `/` is never missing.
3. `L1: docs` — 4.8.

## 5. Acceptance checks — all must pass, each with evidence (command output or screenshot path)

Serve the repo root locally the way `DEPLOY.md` says (staging config; `python3 -m http.server 8080` if that's the procedure). Never create test accounts against production.

1. **Renders with the real design.** `http://localhost:8080/` — DevTools console has no errors and no failed requests; Network shows **no host other than localhost**; computed `font-family` of `h1` starts with `"Big Shoulders Display"`, of `.site-nav .wm` with `"Black Ops One"`; `getComputedStyle(document.querySelector('.band.cut'),'::before').height` is `28px`.
2. **No placeholder link survives, every reference resolves.** `grep -c -E 'href="#(join|signin|privacy|terms|delete)"' index.html` → 0. Extract every `href`, `src`, `srcset` and `poster` in `index.html` (not `#…`, not `https://`), request each from the local server, all 200.
3. **Sign in → `signin.html`** from the desktop nav, from the phone menu at ≤440 px (nav Sign in hides, the menu's shows), and from the footer. All six Join-type CTAs → `signin.html#signup`. `grep -c 'href="signin.html"' index.html` → 3; `grep -c 'signin.html#signup' index.html` → 6 (unless §4.7 case 2).
4. **Sign in / sign up unchanged.** `signin.html` with no session shows what `/` showed before; sign up a fresh staging account end-to-end and land in the app; `#signup` opens the sign-up mode if §4.7 case 1.
5. **Signed-in forwarding.** With a staging session, load `/` → ends in the app with no visible landing page; Back does not return to `/` (`replace`, not `assign`). `/#pricing` with a session stays on the landing page.
6. **Auth links keep their tokens.** `/#access_token=x&refresh_token=y&type=recovery` → `signin.html#access_token=x&refresh_token=y&type=recovery`; `/?code=abc` → `signin.html?code=abc`.
7. **Offline, after the new SW is active** (Application → Service Workers → Offline): signed in, open `/` → app; open the charting page → chart three pitches → end session → saved locally; signed out, `/` still renders (film may not play — fine). Then back online: the session syncs.
8. **SW hygiene.** Cache Storage shows the new `CACHE_VERSION` only (old one gone after activation); after playing the film and scrolling the whole page, no `media/hero-*` or `media/shots/*` entry in any cache; `signin.html` is in the precache.
9. **Film.** Desktop: autoplays muted, Pause → Play, Replay at the end. Phone width: `hero-4x5` source and `hero-poster-4x5.jpg` poster. Rendering → emulate `prefers-reduced-motion: reduce` → still image, no autoplay.
10. **Nothing shared changed.** `git diff --stat <start-commit> -- css buttons.css vendor/fonts` is empty (`<start-commit>` = the hash from discovery's `git log`); `git status` shows no `_reference`, `MANIFEST.sha256`, `README.txt`.
11. **Landing page is inert.** `grep -c -E 'serviceWorker\.register|supabase-js|supabase\.co|createClient|supabase-config' index.html` → 0.
12. **Reports untouched.** Open a stored staging report in `report.html` — renders exactly as before.

## 6. Push, then verify live

```bash
git push
curl -sI https://knuckleballonline.com/ | head -1; curl -sI https://knuckleballonline.com/signin.html | head -1
curl -sI https://knuckleballonline.com/media/hero-poster.jpg | head -1
curl -s https://knuckleballonline.com/ | grep -c 'signin.html'      # ≥ 9
```

Then hand Joel these three on-device checks (iPhone/iPad, production): installed home-screen app opens → app, not the landing page (if the landing page flashes once, it's the old SW — force-reload per the P1-11 rule, then it should not recur); Safari → `knuckleballonline.com` signed out → landing page, film plays, Sign in works; a password-reset email → ends on the reset form.

**Recommended for Joel (dashboard, both projects), not blocking:** Authentication → URL Configuration → Site URL `https://knuckleballonline.com/signin.html`, and add it to Redirect URLs (staging: `http://localhost:8080/signin.html`). The forwarder already covers these links; this just removes the hop. If discovery B found `redirectTo` in `supabase/functions/invite-pitcher` pointing at `/` or `index.html`, list it as a follow-up (function deploy per `DEPLOY.md`) — not part of L1.

## 7. Report format (Gate 1 and final)

- Table of files touched with one line each; the new `CACHE_VERSION`; the `start_url` value; which §4.4 and §4.7 cases applied.
- Self-audit: confirm no change to the draft/outbox/sync path, the auth guard logic (URL strings only), the report payload, `css/`, `buttons.css`, `vendor/fonts/`.
- The 12 checks, each with its evidence.
- Anything you had to decide that this packet didn't cover, stated as a decision Joel can reverse.

## 8. Joel's follow-ups (not for Claude Code; listed so they aren't lost)

- **Pricing shows "$—" and "Price not set" publicly** (D1 lock is ~Feb 2027). To hide the paid tiers until then: delete the three `<div class="tier">` blocks (keep `.tier.free`) and the `.price-foot` line. Or leave as the honest placeholder it is.
- **Arm care "Coming next" teaser** is visible. To hide: delete `<section … id="arm">`.
- **"Talk to us"** on the Facility tier scrolls to the FAQ. Swap in a `mailto:` when there's an address.
- **Under-13 / parent copy** (Coaches, Players, FAQ) promises a parent-managed flow; discovery F says whether the app has it today. If not, those three lines need rewording before the page is widely shared.
- Coaches/Players section words are the designer's draft; the hero is yours.
- `signin.html` still wears its current look; a later packet can bring it in line with the landing page (it already shares the tokens).
