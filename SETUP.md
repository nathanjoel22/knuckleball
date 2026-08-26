# SETUP.md — Knuckleball

## Auth email SMTP (Resend)

Supabase's built-in auth mailer has very low rate limits — a coach inviting a full staff
could silently hit the cap mid-roster. Auth emails (invites, password resets) are sent
through custom SMTP via Resend instead, using the same verified sending domain
(`knuckleballonline.com`) that `send-session-report` already uses for report emails.

### Where this is configured

Supabase Dashboard → Authentication → SMTP Settings, project `fkgccjhuimkkbupbanxp`. This
is dashboard-only configuration — it does not live in this repo, and should **not** be
pushed via `supabase config push`: that command pushes the whole local `config.toml` to the
project, and it isn't clear it only touches the keys you specify rather than resetting
unspecified Auth settings — including the Site URL/redirect-URL landmine noted in
`CLAUDE.md`. Configure this by hand in the dashboard, not via CLI.

### Settings

| Field | Value |
|---|---|
| Enable Custom SMTP | On |
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` (literal string, not a variable) |
| Password | The Resend API key — same value as the `RESEND_API_KEY` Supabase secret. Never store the actual value in this repo. |
| Sender email | An address on the verified `knuckleballonline.com` domain |
| Sender name | Knuckleball |

### Rate limits

Authentication → Rate Limits: the email-sending rate limit was raised well above the
Supabase default, giving headroom for a 15+ invite onboarding day.

### Verifying it's actually routing through Resend

Check the headers of any received auth email (invite or password reset):

- `DKIM-Signature: ... s=resend; d=knuckleballonline.com`
- `Authentication-Results: ... dkim=pass header.i=@knuckleballonline.com header.s=resend`

Resend delivers through AWS SES under the hood, so a second DKIM signature and `Received`
lines mentioning `amazonses.com` are expected alongside the Resend one — not a sign of
misconfiguration.

### Verified

2026-08-26: sent 10 invites back-to-back via `invite-pitcher` in ~24 seconds; all 10
delivered. Confirmed via received message headers (above) that auth emails are signed and
routed through Resend's Knuckleball sending domain, not Supabase's default mailer.

### Rollback

Toggle "Enable Custom SMTP" back off in the same dashboard screen to return to Supabase's
default auth mailer.
