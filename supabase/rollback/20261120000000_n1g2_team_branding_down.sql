-- Down for 20261120000000_n1g2_team_branding (N1 Stage G2). Drops the 4 logo rules, the 3 functions and the 4 teams
-- columns. The team-logos bucket and any logos in it STAY: Supabase refuses storage deletes from SQL. With no read rule
-- left nobody can read them; remove the bucket from the dashboard (Storage -> team-logos -> Delete) if wanted.
--   supabase db query --linked --project-ref <ref> -f "$PWD/supabase/rollback/20261120000000_n1g2_team_branding_down.sql"
begin;
drop policy if exists "Team logos: members read" on storage.objects;
drop policy if exists "Team logos: head uploads" on storage.objects;
drop policy if exists "Team logos: head replaces" on storage.objects;
drop policy if exists "Team logos: head removes" on storage.objects;
drop function if exists public.my_brandings();
drop function if exists public.set_team_branding(uuid, text, text, text);
drop function if exists public.is_team_reader(uuid);
alter table public.teams drop column if exists brand_color, drop column if exists accent_color,
  drop column if exists logo_path, drop column if exists branding_updated_at;
delete from supabase_migrations.schema_migrations where version = '20261120000000';
commit;
