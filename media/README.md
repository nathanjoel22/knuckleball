# media/ — landing-page film and images (L1)

For `plans/l1-landing-page.md`. Everything here is public marketing content, self-hosted, and **skipped by the service worker** (L1 spec 5): never precache it, never let it reach Cache Storage.

## The hero film (approved Oct 16; no-loop version Oct 19)

| File | What it is |
|---|---|
| `hero-1080p.webm` / `hero-1080p.mp4` | Desktop, 1920x1080. AV1 WebM first, H.264 MP4 fallback. |
| `hero-4x5.webm` / `hero-4x5.mp4` | Phone, 864x1080 (4:5), reframed shot by shot. Use for `max-width: 767px`. |
| `hero-poster.jpg` / `hero-poster-4x5.jpg` | The first frame: the poster until the video starts. |
| `hero-still.jpg` / `hero-still-4x5.jpg` | The softball strike: what reduced-motion visitors see instead. |

All four videos are 14.8 s, 30 fps, no audio track, `faststart`. The film **plays once and holds its last frame** (the opening frame, a placeholder until Jordan and Joel pick the final still): no `loop` attribute and no `ended` handler. The kids in it are fictional AI characters.

## landing/ — app and report screenshots

Real Knuckleball screens (the app and the session report) rendered from **invented test data**: a made-up coach ("Coach Diaz"), team ("Varsity") and pitchers ("Sam Ortega #21", "Riley Chen #7", ...). No real account was used. `-m` files are the phone-width crops for `max-width: 640px`.
