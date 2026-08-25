# BACKUPS.md — Knuckleball

## What the current plan provides automatically

**Nothing, automatically, today.** Checked via `supabase backups list --project-ref fkgccjhuimkkbupbanxp`:

```
{"region":"us-east-1","walg_enabled":true,"pitr_enabled":false,"backups":[],...}
```

- `pitr_enabled: false` — no point-in-time recovery.
- `backups: []` — zero physical/daily backups exist, automated or otherwise.

This is also indirectly confirmed by the account being capped at **2 active free Supabase
projects** across every org where you're an admin/owner (hit this cap while setting up this
task's restore test) — that project-count ceiling is a Free-tier restriction. Supabase's Free
tier does not include daily backups or PITR at all; those start on the Pro plan (7 days of
daily backups included) with PITR as a paid add-on on top of Pro.

**Recommendation for Joel:** if losing a season of a coach's data would be a real problem (it
would), upgrading to Pro gets you the platform's own daily backups as a baseline. That's a
plan/cost decision for you — not done as part of this task (out of scope).

Until/unless that happens, the manual routine below is the only backup that exists.

## How to take a manual backup

Two commands, run from the repo root with the Supabase CLI linked to the project (`supabase
db dump` needs Docker Desktop running):

```bash
DATE=$(date +%Y-%m-%d)
mkdir -p ~/knuckleball-backups
supabase db dump --linked -s public -f ~/knuckleball-backups/${DATE}-schema.sql
supabase db dump --linked --data-only -s public -f ~/knuckleball-backups/${DATE}-data.sql
```

- `-s public` scopes the dump to the app's own schema (skips `auth`, `storage`, etc., which
  Supabase manages itself).
- The first command dumps structure (tables, constraints, RLS policies) with no rows. The
  second dumps only data (`INSERT` statements), no structure.
- **Never commit these files to git.** They live outside the repo, in `~/knuckleball-backups/`
  — that folder contains real user data (names, emails, session/pitch data) and must not be
  pushed anywhere.

## Where dumps live

`~/knuckleball-backups/` on this machine, named `<date>-schema.sql` and `<date>-data.sql`.
This is local-disk-only — if this Mac is lost or wiped, so are these backups. Consider also
copying the dated files to a second location (an external drive, a personal encrypted cloud
folder) after each manual backup, since local-only defeats the purpose of a backup.

## How to restore (tested procedure)

Restoring means loading a schema dump + a data dump into a Postgres database — either back
into a recovered version of the same project, or into a fresh project if starting over.

1. **Create or identify the target project**, e.g.:
   ```bash
   supabase projects create <name> --org-id <org-id> --db-password <password> --region us-east-1
   ```
2. **Connect via the Supavisor session pooler, not the direct host.** New Supabase projects'
   direct connection host (`db.<ref>.supabase.co`) is IPv6-only; most home/local networks can't
   reach it and will fail with "Network is unreachable". Use the pooler instead:
   ```
   postgresql://postgres.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres
   ```
3. **Load schema, then data**, using a throwaway Postgres client container (no local `psql`
   install needed):
   ```bash
   CONN="postgresql://postgres.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres"
   docker run --rm -v ~/knuckleball-backups:/backups postgres:17 \
     psql "$CONN" -v ON_ERROR_STOP=1 -f /backups/<date>-schema.sql
   docker run --rm -v ~/knuckleball-backups:/backups postgres:17 \
     psql "$CONN" -v ON_ERROR_STOP=1 -f /backups/<date>-data.sql
   ```
4. **Verify row counts match** on every key table before trusting the restore:
   ```sql
   select 'teams' t, count(*) from public.teams
   union all select 'invites', count(*) from public.invites
   union all select 'profiles', count(*) from public.profiles
   union all select 'pitcher_teams', count(*) from public.pitcher_teams
   union all select 'sessions', count(*) from public.sessions
   union all select 'pitches', count(*) from public.pitches
   order by 1;
   ```

### Last verified: 2026-08-25

Ran this exact procedure end-to-end: dumped production, created a scratch project
(`knuckleball-restore-test`), restored schema + data into it, confirmed row counts, then
deleted the scratch project. Counts matched exactly on both sides:

| table | prod (dump snapshot) | restored scratch |
|---|---|---|
| teams | 2 | 2 |
| invites | 1 | 1 |
| profiles | 3 | 3 |
| pitcher_teams | 1 | 1 |
| sessions | 12 | 12 |
| pitches | 68 | 68 |

Restore succeeded with zero errors (`ON_ERROR_STOP=1`, schema load then data load, no failures).

## Weekly reminder

There is no CI or automation in this project to run backups for you (per CLAUDE.md, this repo
is intentionally simple/no-build-pipeline, and automating this was explicitly out of scope for
this task). Set a recurring weekly reminder for yourself — phone calendar, whatever you'll
actually see — to run the two-command manual backup above. A season's worth of a coach's data
with no restorable backup is unrecoverable; a stale weekly manual dump is much better than none.
