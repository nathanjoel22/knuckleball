// Branded emails (Joel, Oct 22 2026): one layout for Knuckleball's own emails, in the sport's colours -- the brand
// dark header with the lockup ("The spot" + KNUCKLEBALL, an image: email apps can't load our fonts), a title, the
// message, one button in the sport's accent, and the link written out for apps that block buttons. Tables and inline
// styles only (Gmail / Outlook / Apple Mail). Colours = css/tokens.css (--brand-bg, --accent, --on-accent, --ink,
// --ink-dim, --ink-faint, --bg, --brand-mid) -- keep in step by hand, like REPORT_VARS.
// The lockup images live on the live site (email/lockup-<sport>.png, drawn by scripts/email-art.js).

export type EmailSport = 'baseball' | 'softball'

const PALETTE: Record<EmailSport, { brand: string; accent: string; onAccent: string; ink: string; inkDim: string; inkFaint: string; bg: string; link: string }> = {
  baseball: { brand: '#061A12', accent: '#FFB81C', onAccent: '#07140F', ink: '#07140F', inkDim: '#26342D', inkFaint: '#56645C', bg: '#F3F5F2', link: '#16593D' },
  softball: { brand: '#0B2540', accent: '#FF4F9A', onAccent: '#0B2540', ink: '#0B2540', inkDim: '#2C4560', inkFaint: '#5A6E84', bg: '#F4F7FB', link: '#1F5C99' },
}
const SITE = 'https://knuckleballonline.com'
const FONT = "'Helvetica Neue', Helvetica, Arial, sans-serif"

export function escapeEmailHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
}

// paragraphs and footnote are HTML the caller has already escaped; the button's href and label are escaped here.
export function brandedEmail(o: {
  sport?: string | null
  title: string
  paragraphs: string[]
  button?: { href: string; label: string }
  footnote?: string
}): string {
  const sport: EmailSport = o.sport === 'softball' ? 'softball' : 'baseball'
  const c = PALETTE[sport]
  const p = (html: string) => `<p style="margin:0 0 16px;font-family:${FONT};font-size:16px;line-height:1.5;color:${c.inkDim};">${html}</p>`
  const button = o.button ? `
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:8px 0 20px;"><tr>
            <td bgcolor="${c.accent}" style="background:${c.accent};border-radius:10px;">
              <a href="${escapeEmailHtml(o.button.href)}" style="display:inline-block;padding:14px 24px;font-family:${FONT};font-size:16px;font-weight:700;color:${c.onAccent};text-decoration:none;border-radius:10px;">${escapeEmailHtml(o.button.label)}</a>
            </td></tr></table>
          ${p(`If the button doesn't work, copy this link into your browser:<br><a href="${escapeEmailHtml(o.button.href)}" style="color:${c.link};word-break:break-all;">${escapeEmailHtml(o.button.href)}</a>`)}` : ''
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light only"><title>${escapeEmailHtml(o.title)}</title></head>
<body style="margin:0;padding:0;background:${c.bg};">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="${c.bg}" style="background:${c.bg};">
    <tr><td align="center" style="padding:24px 12px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;background:#FFFFFF;border-radius:14px;overflow:hidden;">
        <tr><td bgcolor="${c.brand}" style="background:${c.brand};padding:20px 24px;">
          <img src="${SITE}/email/lockup-${sport}.png" width="300" height="50" alt="KNUCKLEBALL" style="display:block;border:0;width:300px;max-width:100%;height:auto;color:#FFFFFF;font-family:${FONT};font-size:24px;font-weight:800;letter-spacing:2px;">
        </td></tr>
        <tr><td bgcolor="${c.accent}" style="background:${c.accent};height:6px;line-height:6px;font-size:0;">&nbsp;</td></tr>
        <tr><td style="padding:28px 24px 8px;">
          <h1 style="margin:0 0 16px;font-family:${FONT};font-size:26px;line-height:1.15;font-weight:800;letter-spacing:0.01em;text-transform:uppercase;color:${c.ink};">${escapeEmailHtml(o.title)}</h1>
          ${o.paragraphs.map(p).join('')}
          ${button}
          ${o.footnote ? `<p style="margin:0 0 20px;font-family:${FONT};font-size:13px;line-height:1.5;color:${c.inkFaint};">${o.footnote}</p>` : ''}
        </td></tr>
      </table>
      <p style="margin:16px 0 0;font-family:${FONT};font-size:12px;color:${c.inkFaint};">Knuckleball LLC &middot; <a href="${SITE}/privacy.html" style="color:${c.inkFaint};">Privacy</a> &middot; <a href="${SITE}/terms.html" style="color:${c.inkFaint};">Terms</a></p>
    </td></tr>
  </table>
</body></html>`
}
