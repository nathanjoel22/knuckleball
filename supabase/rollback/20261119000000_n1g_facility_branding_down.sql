-- Rollback of 20261119000000_n1g_facility_branding: removes the four logo rules, the four functions and the four
-- organizations columns (the colors and logo paths go with them). Facilities fall back to Knuckleball's look.
-- The facility-logos bucket and any uploaded logos stay: Supabase refuses to delete storage rows from SQL
-- ("Direct deletion from storage tables is not allowed"). With its read rule gone, nobody can read it. To remove it
-- too: Supabase dashboard -> Storage -> facility-logos -> empty, then delete the bucket.
drop policy if exists "Facility logos: members read" on storage.objects;
drop policy if exists "Facility logos: manager uploads" on storage.objects;
drop policy if exists "Facility logos: manager replaces" on storage.objects;
drop policy if exists "Facility logos: manager removes" on storage.objects;
drop function if exists public.set_facility_branding(uuid, text, text, text);
drop function if exists public.my_facility_brandings();
drop function if exists public.is_org_manager_login(uuid);
drop function if exists public.is_org_member(uuid);
alter table public.organizations
  drop column if exists brand_color, drop column if exists accent_color,
  drop column if exists logo_path, drop column if exists branding_updated_at;
