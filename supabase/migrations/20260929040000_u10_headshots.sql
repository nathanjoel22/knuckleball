-- U10 (8): player headshots.
--
-- Decisions (Joel, Sept 29 2026):
--  * The PLAYER uploads, replaces or removes his own photo (from his
--    Profile). Coaches can't upload for a player.
--  * The phone crops to a square, resizes to 256x256 JPEG and re-encodes it
--    (which drops EXIF, incl. GPS) before upload; the original never leaves
--    the device.
--  * PRIVATE bucket, one file per player at `{user_id}.jpg`. Readable by the
--    player and by the coaches (head or assistant) of any team he's on --
--    through the existing is_team_coach helper. Not by teammates, not on the
--    leaderboard, not on reports, not in the roster list.
--
-- 42P17 landmine: no policy below references teams or pitcher_teams. The
-- one cross-table check (is the caller a coach of this photo's player) is
-- public.can_view_headshot(), a SECURITY DEFINER helper built on
-- is_team_coach -- same pattern as every other cross-table check.
--
-- Rollback (manual, in this order):
--   drop policy if exists "Headshots: player and his coaches can read"  on storage.objects;
--   drop policy if exists "Headshots: player uploads his own"           on storage.objects;
--   drop policy if exists "Headshots: player replaces his own"          on storage.objects;
--   drop policy if exists "Headshots: player removes his own"           on storage.objects;
--   delete from storage.objects where bucket_id = 'headshots';
--   delete from storage.buckets where id = 'headshots';
--   drop function if exists public.can_view_headshot(text);
--   revoke update (headshot_updated_at) on public.profiles from authenticated;
--   alter table public.profiles drop column if exists headshot_updated_at;

-- 1. Cache-busting timestamp: set when the player uploads, cleared when he
--    removes. Self-service only, through the existing "Users update own
--    profile" policy (id = auth.uid()) -- this adds the column to the
--    column-level UPDATE grant, nothing else.
alter table public.profiles add column headshot_updated_at timestamptz;
comment on column public.profiles.headshot_updated_at is
  'U10 (8): when the player last uploaded his headshot (storage bucket headshots, object {id}.jpg); NULL = no photo. Written only by the player himself.';
grant update (headshot_updated_at) on public.profiles to authenticated;

-- 2. The bucket: private, JPEG only, 256 KB cap (a 256x256 JPEG is ~15-40 KB).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('headshots', 'headshots', false, 262144, array['image/jpeg'])
on conflict (id) do nothing;

-- 3. Is the caller a coach (head or assistant) of the player whose photo
--    this object is? Takes the object NAME, never casts it -- a malformed
--    name simply matches nobody instead of raising.
create or replace function public.can_view_headshot(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id::text || '.jpg' = p_object_name
       and public.is_team_coach(pt.team_id)
  );
$$;
revoke all on function public.can_view_headshot(text) from public, anon;
grant execute on function public.can_view_headshot(text) to authenticated;

-- 4. Storage policies, headshots bucket only. "Own file" = exactly
--    {auth.uid()}.jpg, so a player can never write anyone else's photo.
create policy "Headshots: player and his coaches can read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'headshots'
    and (name = auth.uid()::text || '.jpg' or public.can_view_headshot(name))
  );

create policy "Headshots: player uploads his own"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'headshots' and name = auth.uid()::text || '.jpg');

create policy "Headshots: player replaces his own"
  on storage.objects for update to authenticated
  using      (bucket_id = 'headshots' and name = auth.uid()::text || '.jpg')
  with check (bucket_id = 'headshots' and name = auth.uid()::text || '.jpg');

create policy "Headshots: player removes his own"
  on storage.objects for delete to authenticated
  using (bucket_id = 'headshots' and name = auth.uid()::text || '.jpg');
