#!/usr/bin/env node
// Branded emails (Joel, Oct 22 2026): the header lockup for Knuckleball's own emails -- "The spot" and the KNUCKLEBALL
// wordmark (Black Ops One), one image per sport on its own brand dark, drawn by the Chrome already on this Mac (same
// approach as scripts/splash.js: no package, no outside service). Email apps can't load our fonts, so the wordmark goes
// out as an image (with "KNUCKLEBALL" as its alt text). Run by hand after a brand change:   node scripts/email-art.js
// Writes email/lockup-baseball.png and email/lockup-softball.png (1200x200, shown at 300x50). Output is committed.
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const ROOT = path.join(__dirname, '..');
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const FONT = 'data:font/ttf;base64,' + fs.readFileSync(path.join(ROOT, 'vendor/fonts/BlackOpsOne-Regular.ttf')).toString('base64');
const TMP = fs.mkdtempSync(path.join(require('os').tmpdir(), 'kb-email-'));
// css/tokens.css: --brand-bg and --accent per sport (keep in step by hand, like REPORT_VARS)
const SPORTS = { baseball: { bg: '#061A12', lit: '#FFB81C' }, softball: { bg: '#0B2540', lit: '#FF4F9A' } };
// index.html's kb-mark: the slanted 3x3 zone, the low-away pocket lit
const mark = lit => `<svg viewBox="0 0 100 100" width="64" height="64"><g transform="translate(50 50) skewX(-14) translate(-38 -38)">` +
  [[0, 0], [27, 0], [54, 0], [0, 27], [27, 27], [54, 27], [0, 54], [27, 54], [54, 54]]
    .map(([x, y], i) => `<rect x="${x}" y="${y}" width="22" height="22" rx="2" fill="${i === 8 ? lit : '#FFFFFF'}"/>`).join('') + `</g></svg>`;

fs.mkdirSync(path.join(ROOT, 'email'), { recursive: true });
for (const [sport, c] of Object.entries(SPORTS)) {
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>
    @font-face{ font-family:'Black Ops One'; src:url('${FONT}') format('truetype'); font-display:block; }
    html,body{ margin:0; width:600px; height:100px; background:${c.bg}; overflow:hidden; }
    body{ display:flex; align-items:center; gap:16px; padding:0 4px; box-sizing:border-box; }
    .wm{ font-family:'Black Ops One'; color:#FFFFFF; font-size:48px; letter-spacing:0.02em; line-height:1; }
  </style></head><body>${mark(c.lit)}<span class="wm">KNUCKLEBALL</span></body></html>`;
  const f = path.join(TMP, sport + '.html'), out = path.join(ROOT, 'email', `lockup-${sport}.png`);
  fs.writeFileSync(f, html);
  try { fs.unlinkSync(out) } catch (e) {}
  execFileSync(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=2',
    '--allow-file-access-from-files', '--window-size=600,100', '--virtual-time-budget=2000', `--screenshot=${out}`, 'file://' + f],
    { stdio: 'ignore', timeout: 60000 });
  console.log('wrote', path.relative(ROOT, out));
}
