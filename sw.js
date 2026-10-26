// Offline app shell for Knuckleball (task P0-06).
//
// Job of this file: let the tracker/login pages LOAD at all with no
// network, so a coach who backgrounds the app in a dead-wifi bullpen can
// reopen it and see the P0-03 draft-restore prompt instead of the
// browser's own offline error page. It must never cache Supabase
// requests (auth, REST, storage) -- those always go to the network.
//
// Bump CACHE_VERSION on EVERY frontend deploy (kb-shell-vN -> vN+1) --
// not only when this file's logic or the PRECACHE_URLS list changes. A
// new name makes the next activation re-precache the whole shell fresh
// and purge the old generation, so a returning coach is never left on
// stale JS, or on a half-updated mix of new and old shell files (each
// file otherwise refreshes on its own next fetch, not together). The
// stale-while-revalidate fetch handler below is the offline/secondary
// path -- it is not what ships a code change. This bump is a required
// step in DEPLOY.md ("Frontend: deploy to production").
const CACHE_VERSION = 'kb-shell-v311';

const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/signin.html',   // L1: the sport / role picker (was index.html); / is now the landing page
  '/login.html',
  '/bullpen-tracker.html',
  '/coach-signup.html',
  '/accept-invite.html',
  '/join.html',
  '/join-coach.html',
  '/verify-email.html',
  '/reset-password.html',
  '/supabase-config.js',
  '/report-config.js',
  // P1-10: supabase-js and the fonts are self-hosted (nothing from jsDelivr
  // or Google any more), so they're part of the shell and work offline.
  '/pitcher-signup.html',
  '/parent-signup.html',
  '/guardian-consent.html',
  '/privacy.html',
  '/terms.html',
  '/delete-account.html',   // W1: the public account-deletion page (Google Play's link)
  '/help.html',   // P2-06: getting started and help, offline too
  '/vendor/supabase.js',
  '/vendor/fonts/fonts.css',
  '/css/tokens.css',   // D1: the design tokens every page loads (Oct 13)
  '/css/components.css',   // D2 Stage C: the shared components and sign-in look (Oct 13)
  '/buttons.css',   // U13: every page's button shapes, offline too (Oct 9)
  '/vendor/icons/arm.png',     // Home tiles: Joel's drawings, offline too (Oct 12)
  '/vendor/icons/brain.png',
  '/vendor/icons/scatter.png',
  '/vendor/icons/graph.png',
  '/vendor/icons/gear.png',
  '/vendor/icons/trends.svg',
  '/vendor/fonts/BlackOpsOne-Regular.ttf',   // the KNUCKLEBALL wordmark, offline too (Oct 8)
  // D2 Stage B (Oct 13): the two faces, precached so the first offline open already has them
  '/vendor/fonts/Archivo-var-latin.woff2',
  '/vendor/fonts/Archivo-var-latin-ext.woff2',
  '/vendor/fonts/BigShouldersDisplay-var-latin.woff2',
  '/vendor/fonts/BigShouldersDisplay-var-latin-ext.woff2',
  // P2-05 (Oct 15): the installed app -- its manifest, icons, the safe-area rules and the iOS splash images
  '/manifest.webmanifest',
  '/css/standalone.css',
  '/icons/icon-192.png', '/icons/icon-512.png', '/icons/icon-maskable-512.png', '/icons/apple-touch-icon.png', '/icons/favicon-32.png',
  '/splash/splash-1125x2436.png',
  '/splash/splash-1170x2532.png',
  '/splash/splash-1179x2556.png',
  '/splash/splash-1206x2622.png',
  '/splash/splash-1242x2208.png',
  '/splash/splash-1242x2688.png',
  '/splash/splash-1260x2736.png',
  '/splash/splash-1284x2778.png',
  '/splash/splash-1290x2796.png',
  '/splash/splash-1320x2868.png',
  '/splash/splash-1334x750.png',
  '/splash/splash-1488x2266.png',
  '/splash/splash-1536x2048.png',
  '/splash/splash-1620x2160.png',
  '/splash/splash-1640x2360.png',
  '/splash/splash-1668x2388.png',
  '/splash/splash-1668x2420.png',
  '/splash/splash-1792x828.png',
  '/splash/splash-2048x1536.png',
  '/splash/splash-2048x2732.png',
  '/splash/splash-2064x2752.png',
  '/splash/splash-2160x1620.png',
  '/splash/splash-2208x1242.png',
  '/splash/splash-2266x1488.png',
  '/splash/splash-2360x1640.png',
  '/splash/splash-2388x1668.png',
  '/splash/splash-2420x1668.png',
  '/splash/splash-2436x1125.png',
  '/splash/splash-2532x1170.png',
  '/splash/splash-2556x1179.png',
  '/splash/splash-2622x1206.png',
  '/splash/splash-2688x1242.png',
  '/splash/splash-2732x2048.png',
  '/splash/splash-2736x1260.png',
  '/splash/splash-2752x2064.png',
  '/splash/splash-2778x1284.png',
  '/splash/splash-2796x1290.png',
  '/splash/splash-2868x1320.png',
  '/splash/splash-750x1334.png',
  '/splash/splash-828x1792.png'
];

self.addEventListener('install', (event) => {
  // Cache each URL independently rather than cache.addAll(), which fails
  // the whole install if even one asset 404s or blips -- that would
  // silently leave the entire offline shell inactive.
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_VERSION);
    await Promise.all(PRECACHE_URLS.map(async (url) => {
      try {
        const res = await fetch(url, { cache: 'reload' });
        if (res && (res.ok || res.type === 'opaque')) await cache.put(url, res);
      } catch (e) {
        // One flaky asset shouldn't block the rest of the shell from caching.
      }
    }));
    self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((names) => Promise.all(
        names.filter((n) => n !== CACHE_VERSION).map((n) => caches.delete(n))
      ))
      .then(() => self.clients.claim())
  );
});

function isShellRequest(url) {
  return url.origin === self.location.origin;   // P1-10: everything the app loads is same-origin now
}

self.addEventListener('fetch', (event) => {
  const req = event.request;

  // Only ever intercept GET -- never touch POST/PUT/etc (nothing in this
  // app should hit those same-origin anyway, but this is a hard rule).
  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  // Never cache or intercept Supabase (auth, REST, storage, edge
  // functions) -- always hit the network so auth state and data are
  // never served stale or from cache.
  if (url.hostname.endsWith('.supabase.co')) return;

  // Leave everything else (anything unexpected from another origin) alone --
  // this worker only knows about its own enumerated shell assets.
  if (!isShellRequest(url)) return;

  // L1: the landing page's film and screenshots are never cached (13 MB) -- straight to the network.
  if (url.pathname.startsWith('/media/hero-') || url.pathname.startsWith('/media/shots/')) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_VERSION);
    // ignoreSearch: every PRECACHE_URLS entry is stored under its bare path
    // with no query string, but several of these shell pages are always
    // VISITED with one (verify-email.html?t=..., join.html?t=..., an
    // invite/verification link is never bare) -- each of those tokens gets
    // read from location.search by the page's OWN client-side JS after
    // load, so the actual HTML/JS shell served is identical either way.
    // Without this, cache.match's default exact-URL comparison never hits
    // for any of those links, silently defeating their precaching and
    // falling through to network-only -- on a flaky connection (or none),
    // that's the "Offline and not yet cached." fallback below, on exactly
    // the links (email verification, team invites) where reliability
    // matters most. Found via a real report: a verification email link
    // hit this offline page even though verify-email.html was precached.
    const cached = await cache.match(req, { ignoreSearch: true });

    const networkFetch = fetch(req).then((res) => {
      if (res && (res.ok || res.type === 'opaque')) {
        cache.put(req, res.clone());
      }
      return res;
    }).catch(() => null);

    if (cached) {
      // Cache-first for instant offline-safe response, but always
      // refresh the cache in the background when online so the shell
      // can't get permanently stuck on stale content.
      event.waitUntil(networkFetch);
      return cached;
    }

    const fresh = await networkFetch;
    return fresh || new Response('Offline and not yet cached.', {
      status: 503,
      statusText: 'Offline',
      headers: { 'Content-Type': 'text/plain' }
    });
  })());
});
