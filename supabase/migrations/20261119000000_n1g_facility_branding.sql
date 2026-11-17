-- Rollback: supabase/rollback/20261119000000_n1g_facility_branding_down.sql. Test: supabase/tests/n1g_facility_branding.sql.
-- N1 Stage G: a facility's own logo and colors (plans/n1g-preconditions.md). organizations stays closed to clients
-- (no grant, no policy); the manager writes through set_facility_branding, members read through
-- my_facility_brandings. Logos live in the private facility-logos bucket at <org_id>/logo.<ext>.
alter table public.organizations
  add column brand_color  text check (brand_color  ~ '^#[0-9A-Fa-f]{6}$'),
  add column accent_color text check (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
  add column logo_path    text check (logo_path is null or logo_path ~ '^[0-9a-f-]{36}/logo\.(png|jpg|webp)$'),
  add column branding_updated_at timestamptz;

-- The caller belongs to this facility: coaches a non-archived side, or a pitcher on one is theirs (own, a parent's
-- player, or linked).
create function public.is_org_member(p_org uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select exists (
    select 1 from public.teams t
     where t.org_id = p_org and t.kind = 'facility' and t.archived_at is null
       and (public.is_team_coach(t.id)
            or exists (select 1 from public.pitcher_teams pt
                        where pt.team_id = t.id and (public.is_my_profile(pt.pitcher_id) or public.is_linked_to(pt.pitcher_id))))
  );
$$;

create function public.is_org_manager_login(p_org uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select exists (select 1 from public.organizations o where o.id = p_org and o.manager_login = auth.uid());
$$;

-- One row per facility side the caller belongs to.
create function public.my_facility_brandings()
  returns table (team_id uuid, org_id uuid, name text, brand_color text, accent_color text, logo_path text, updated_at timestamptz)
  language sql stable security definer set search_path to '' as $$
  select t.id, o.id, o.name, o.brand_color, o.accent_color, o.logo_path, o.branding_updated_at
    from public.teams t join public.organizations o on o.id = t.org_id
   where t.kind = 'facility' and t.archived_at is null and public.is_org_member(o.id)
     and (public.is_team_coach(t.id)
          or exists (select 1 from public.pitcher_teams pt where pt.team_id = t.id
                      and (public.is_my_profile(pt.pitcher_id) or public.is_linked_to(pt.pitcher_id))));
$$;

-- The manager only. Null colors = Knuckleball's; logo path must be this facility's own file (or null).
create function public.set_facility_branding(p_org uuid, p_brand text, p_accent text, p_logo_path text) returns jsonb
  language plpgsql security definer set search_path to '' as $$
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  if not public.is_org_manager_login(p_org) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if (p_brand is null) <> (p_accent is null) then return jsonb_build_object('ok', false, 'error', 'both_colors'); end if;
  if p_logo_path is not null and p_logo_path not like p_org::text || '/logo.%' then
    return jsonb_build_object('ok', false, 'error', 'bad_logo_path'); end if;
  update public.organizations set brand_color = p_brand, accent_color = p_accent, logo_path = p_logo_path,
         branding_updated_at = now() where id = p_org;
  return jsonb_build_object('ok', true);
exception when check_violation then
  return jsonb_build_object('ok', false, 'error', 'bad_color');
end;
$$;

revoke execute on function public.is_org_member(uuid), public.is_org_manager_login(uuid),
  public.my_facility_brandings(), public.set_facility_branding(uuid, text, text, text) from public, anon;
grant execute on function public.is_org_member(uuid), public.is_org_manager_login(uuid),
  public.my_facility_brandings(), public.set_facility_branding(uuid, text, text, text) to authenticated;

-- Logos: private, small, images only. Members read; the manager writes, only inside the facility's own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('facility-logos', 'facility-logos', false, 262144, array['image/png', 'image/jpeg', 'image/webp'])
  on conflict (id) do nothing;   -- the rollback can't delete a storage bucket, so it may still be there
create policy "Facility logos: members read" on storage.objects for select to authenticated
  using (bucket_id = 'facility-logos' and public.is_org_member(((storage.foldername(name))[1])::uuid));
create policy "Facility logos: manager uploads" on storage.objects for insert to authenticated
  with check (bucket_id = 'facility-logos' and public.is_org_manager_login(((storage.foldername(name))[1])::uuid));
create policy "Facility logos: manager replaces" on storage.objects for update to authenticated
  using (bucket_id = 'facility-logos' and public.is_org_manager_login(((storage.foldername(name))[1])::uuid));
create policy "Facility logos: manager removes" on storage.objects for delete to authenticated
  using (bucket_id = 'facility-logos' and public.is_org_manager_login(((storage.foldername(name))[1])::uuid));
