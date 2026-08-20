# Knuckleball
**Always a Step Ahead**

A bullpen tracking app for baseball pitchers and coaches. Log pitch type, velocity, and location — both where a pitcher was aiming and where the pitch actually landed — and review strike rate, command accuracy, and location heat maps across sessions.

Live at: **https://knuckleballonline.com**

---

## What it does

- **Coaches** sign up, create a team/program, and invite pitchers by email.
- **Pitchers** join via invite, log their own bullpen sessions, and build a session history.
- Each pitch is logged with a **two-tap flow**: tap where you're aiming (target), then tap where it actually landed (result) — so command accuracy is measurable, not just strike percentage.
- The strike zone uses standard baseball 1–9 numbering on the 9 inner boxes, with an outer ring to capture pitches that miss the zone entirely.
- Session history shows a blue → red location heat map, per-pitch-type breakdowns (count, velocity range, strike%, accuracy%), and trend charts across sessions.
- After a session, a PDF report can be emailed to up to three contacts per pitcher (coach, pitching coach, pitcher).

## Tech stack

| Piece | What it's for |
|---|---|
| **GitHub Pages** | Hosts the static site (plain HTML/CSS/JS, no build step) |
| **Supabase** | Postgres database, authentication, and row-level security |
| **Supabase Edge Functions** | Server-side logic for sending invites and emailing session reports (Deno) |
| **Resend** | Transactional email delivery (invites, confirmations, PDF reports) |
| **Cloudflare** | DNS for the custom domain |

## File structure

```
knuckleball/
├── index.html              "Who are you?" landing page (pitcher / coach)
├── login.html               Real email/password login
├── coach-signup.html        Coach self-signup — creates account + first team
├── accept-invite.html       Where an invited pitcher sets their password and joins a team
├── bullpen-tracker.html     The tracker app itself (roster, sessions, history, trends)
├── supabase-config.js       Your Supabase Project URL + anon key
├── report-config.js         Your send-session-report function URL + shared secret
└── supabase/
    ├── schema.sql            Database tables + row-level security policies
    └── functions/
        ├── invite-pitcher/          Edge Function: coach invites a pitcher by email
        └── send-session-report/     Edge Function: emails a session report PDF
```

## Data model

- `profiles` — one row per user (coach or pitcher), linked to Supabase Auth
- `teams` — one coach owns each team; a pitcher can belong to several
- `pitcher_teams` — the membership join table
- `invites` — pending/accepted email invites from coach to pitcher
- `sessions` / `pitches` — bullpen data, scoped to the team it was logged under

Every table has row-level security: a coach only ever sees data for teams they own; a pitcher only ever sees their own data plus the teams they've joined. If a pitcher belongs to two teams, each team's coach only sees sessions logged under *their* team.

## Setup

See `SETUP.md` for the full walkthrough — creating the Supabase project, running the schema, setting up Resend, deploying the two Edge Functions, and wiring the config files.

## Current status

**Working and tested:**
- Coach signup, email confirmation, login, sign-out
- Bullpen session logging (two-tap target/actual, zone numbers, heat map, accuracy)
- Session history and trend charts
- Automated PDF report emailing on a saved session
- Custom domain (knuckleballonline.com) live via GitHub Pages + Cloudflare

**Deployed but not yet tested:**
- The pitcher invite flow (`invite-pitcher` function) — built and CORS-fixed, not yet run through end-to-end

**Not yet built:**
- An in-app button for inviting pitchers (currently only callable via browser console)
- Migrating `bullpen-tracker.html`'s pitcher/session data from local browser storage into Supabase, so it syncs across devices and is properly scoped per team instead of living on one browser
