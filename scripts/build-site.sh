#!/usr/bin/env bash
# Build the public site for Cloudflare Pages: copy ONLY the files the site serves into _site/.
#
#   scripts/build-site.sh            (run from anywhere; builds <repo>/_site)
#
# The list below is an allowlist: every file the pages load, every file sw.js precaches, the email logos the emails
# load from the site, robots.txt / sitemap.xml, the font licenses, and _headers. Nothing else is copied -- no plans/,
# supabase/, docs/, scripts/, schema files, STATUS.md / CLAUDE.md / DEPLOY.md / README, tests, staging configs, CNAME or
# the service-worker kill switch. A new file the site needs must be added here (the build fails if sw.js precaches a
# file that isn't copied). The build fails if any listed file is missing, and refuses the staging config.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/_site"
cd "$ROOT"

FILES=(
  # pages
  index.html signin.html login.html bullpen-tracker.html report.html
  coach-signup.html pitcher-signup.html parent-signup.html facility-signup.html player-link.html
  accept-invite.html join.html join-coach.html verify-email.html reset-password.html guardian-consent.html
  privacy.html terms.html help.html delete-account.html qr-print.html operator.html
  # the service worker, config and app manifest
  sw.js supabase-config.js report-config.js manifest.webmanifest
  # styles
  buttons.css css/tokens.css css/components.css css/standalone.css
  # scripts and fonts kept on our own site
  vendor/supabase.js vendor/qrcodegen.js
  vendor/fonts/fonts.css vendor/fonts/BlackOpsOne-Regular.ttf
  vendor/fonts/Archivo-var-latin.woff2 vendor/fonts/Archivo-var-latin-ext.woff2
  vendor/fonts/BigShouldersDisplay-var-latin.woff2 vendor/fonts/BigShouldersDisplay-var-latin-ext.woff2
  vendor/fonts/OFL.txt vendor/fonts/OFL-archivo.txt vendor/fonts/OFL-bigshoulders.txt
  # images the app draws
  batter-icon.png
  vendor/icons/arm.png vendor/icons/brain.png vendor/icons/gear.png vendor/icons/graph.png
  vendor/icons/scatter.png vendor/icons/trends.svg
  # installed-app icons and iOS splash screens
  icons/icon-192.png icons/icon-512.png icons/icon-maskable-512.png icons/apple-touch-icon.png icons/favicon-32.png
  splash/splash-1125x2436.png splash/splash-1170x2532.png splash/splash-1179x2556.png splash/splash-1206x2622.png
  splash/splash-1242x2208.png splash/splash-1242x2688.png splash/splash-1260x2736.png splash/splash-1284x2778.png
  splash/splash-1290x2796.png splash/splash-1320x2868.png splash/splash-1334x750.png splash/splash-1488x2266.png
  splash/splash-1536x2048.png splash/splash-1620x2160.png splash/splash-1640x2360.png splash/splash-1668x2388.png
  splash/splash-1668x2420.png splash/splash-1792x828.png splash/splash-2048x1536.png splash/splash-2048x2732.png
  splash/splash-2064x2752.png splash/splash-2160x1620.png splash/splash-2208x1242.png splash/splash-2266x1488.png
  splash/splash-2360x1640.png splash/splash-2388x1668.png splash/splash-2420x1668.png splash/splash-2436x1125.png
  splash/splash-2532x1170.png splash/splash-2556x1179.png splash/splash-2622x1206.png splash/splash-2688x1242.png
  splash/splash-2732x2048.png splash/splash-2736x1260.png splash/splash-2752x2064.png splash/splash-2778x1284.png
  splash/splash-2796x1290.png splash/splash-2868x1320.png splash/splash-750x1334.png splash/splash-828x1792.png
  # the landing page's film and screenshots
  media/hero-1080p.mp4 media/hero-1080p.webm media/hero-4x5.mp4 media/hero-4x5.webm
  media/hero-poster.jpg media/hero-poster-4x5.jpg media/hero-still.jpg media/hero-still-4x5.jpg
  media/shots/app-history.png media/shots/app-home.png media/shots/app-live.png media/shots/app-target.png
  media/shots/rep-bb.png media/shots/rep-sb.png media/shots/rep-loctypes.png media/shots/rep-loctypes-m.png
  media/shots/rep-sideL.png media/shots/rep-sideR.png media/shots/rep-trends.png
  media/shots/rep-velo.png media/shots/rep-velo-m.png
  # the logos Knuckleball's emails load from the site (supabase/functions/_shared/email.ts, supabase/templates/)
  email/lockup-baseball.png email/lockup-softball.png
  # crawlers, and Cloudflare Pages' header rules
  robots.txt sitemap.xml _headers
)

# Never ship the staging config (the working copy carries it while testing against staging).
if grep -q 'wpsscxwawgiwmifpjpec' supabase-config.js report-config.js; then
  echo "build-site: supabase-config.js / report-config.js point at STAGING -- restore the production config first." >&2
  exit 1
fi

missing=()
for f in "${FILES[@]}"; do [ -f "$f" ] || missing+=("$f"); done
if [ ${#missing[@]} -gt 0 ]; then
  echo "build-site: expected files are missing:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT"
for f in "${FILES[@]}"; do
  mkdir -p "$OUT/$(dirname "$f")"
  cp -p "$f" "$OUT/$f"
done

# Every file sw.js precaches must be in the build ('/' is index.html).
precache_missing=()
while IFS= read -r p; do
  [ "$p" = "/" ] && p="/index.html"
  [ -f "$OUT$p" ] || precache_missing+=("$p")
done < <(sed -n "/const PRECACHE_URLS/,/^];/p" sw.js | grep -o "'/[^']*'" | tr -d "'")
if [ ${#precache_missing[@]} -gt 0 ]; then
  echo "build-site: sw.js precaches files the build doesn't copy (add them to FILES):" >&2
  printf '  %s\n' "${precache_missing[@]}" >&2
  exit 1
fi

echo "build-site: copied ${#FILES[@]} files to _site/"
