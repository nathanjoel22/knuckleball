-- N1 Stage G2: a normal team's own logo and colors, set by its head coach (plans/n1g2-preconditions.md; Joel, Nov 17
-- 2026, "yes to all"). Stage G's facility look is unchanged. teams gets four columns with NO client grant: the head
-- writes through set_team_branding, members read through my_brandings (facility sides + normal teams in one list).
-- Logos live in the private team-logos bucket at <team_id>/logo.<ext>.
alter table public.teams
  add column brand_color  text check (brand_color  ~ '^#[0-9A-Fa-f]{6}$'),
  add column accent_color text check (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
  add column logo_path    text check (logo_path is null or logo_path ~ '^[0-9a-f-]{36}/logo\.(png|jpg|webp)$'),
  add column branding_updated_at timestamptz;

-- The caller belongs to this (non-archived) team: coaches it, or a pitcher on its roster is theirs (own, a parent's
-- player, or linked).
create function public.is_team_reader(p_team uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select exists (
    select 1 from public.teams t
     where t.id = p_team and t.archived_at is null
       and (public.is_team_coach(t.id)
            or exists (select 1 from public.pitcher_teams pt
                        where pt.team_id = t.id and (public.is_my_profile(pt.pitcher_id) or public.is_linked_to(pt.pitcher_id))))
  );
$$;

-- Every look the caller can see: facility sides exactly as my_facility_brandings() (kept for v349/v350 apps), then
-- normal teams with their own values (org_id null).
create function public.my_brandings()
  returns table (team_id uuid, org_id uuid, name text, brand_color text, accent_color text, logo_path text, updated_at timestamptz)
  language sql stable security definer set search_path to '' as $$
  select f.team_id, f.org_id, f.name, f.brand_color, f.accent_color, f.logo_path, f.updated_at
    from public.my_facility_brandings() f
  union all
  select t.id, null::uuid, t.name, t.brand_color, t.accent_color, t.logo_path, t.branding_updated_at
    from public.teams t
   where t.kind = 'team' and public.is_team_reader(t.id);
$$;

-- The head coach only. Null colors = Knuckleball's; the logo path must be this team's own file (or null).
create function public.set_team_branding(p_team uuid, p_brand text, p_accent text, p_logo_path text) returns jsonb
  language plpgsql security definer set search_path to '' as $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  if not public.is_team_head(p_team) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if exists (select 1 from public.teams where id = p_team and kind <> 'team') then
    return jsonb_build_object('ok', false, 'error', 'use_facility_look'); end if;
  if public.is_team_archived(p_team) then return jsonb_build_object('ok', false, 'error', 'team_archived'); end if;
  if (p_brand is null) <> (p_accent is null) then return jsonb_build_object('ok', false, 'error', 'both_colors'); end if;
  if p_logo_path is not null and p_logo_path not like p_team::text || '/logo.%' then
    return jsonb_build_object('ok', false, 'error', 'bad_logo_path'); end if;
  update public.teams set brand_color = p_brand, accent_color = p_accent, logo_path = p_logo_path,
         branding_updated_at = now() where id = p_team;
  return jsonb_build_object('ok', true);
exception when check_violation then
  return jsonb_build_object('ok', false, 'error', 'bad_color');
end;
$$;

revoke execute on function public.is_team_reader(uuid), public.my_brandings(),
  public.set_team_branding(uuid, text, text, text) from public, anon;
grant execute on function public.is_team_reader(uuid), public.my_brandings(),
  public.set_team_branding(uuid, text, text, text) to authenticated;

-- Logos: private, small, images only. Members read; the head writes, only inside the team's own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('team-logos', 'team-logos', false, 262144, array['image/png', 'image/jpeg', 'image/webp'])
  on conflict (id) do nothing;   -- the rollback can't delete a storage bucket, so it may still be there
create policy "Team logos: members read" on storage.objects for select to authenticated
  using (bucket_id = 'team-logos' and public.is_team_reader(((storage.foldername(name))[1])::uuid));
create policy "Team logos: head uploads" on storage.objects for insert to authenticated
  with check (bucket_id = 'team-logos' and public.is_team_head(((storage.foldername(name))[1])::uuid));
create policy "Team logos: head replaces" on storage.objects for update to authenticated
  using (bucket_id = 'team-logos' and public.is_team_head(((storage.foldername(name))[1])::uuid));
create policy "Team logos: head removes" on storage.objects for delete to authenticated
  using (bucket_id = 'team-logos' and public.is_team_head(((storage.foldername(name))[1])::uuid));
