-- U15: one write path for a pitcher's arsenal (profiles.pitch_types), the Pitches bubble's.
-- Who may write it (Joel, Nov 6 2026; plans/u15-preconditions.md, decision 4): the pitcher's own login (for a
-- parent-created player that's the parent's login: is_my_profile), and any coach who can see the pitcher on a current,
-- non-archived team (coach_sees_pitcher: a team's head or assistants, a facility side's manager, or the pitcher's group
-- coach). Linked guardians and teens stay read-only (F1-G). Name, throws, uniform and radar gun stay head-only (R6).
-- Kept for now (decision 2): the direct column grant on pitch_types and coach_set_pitch_types, so apps cached at v336
-- and earlier keep saving until they update; a later migration removes both. No table, column or policy change
-- (policies stay 32). Rollback: supabase/rollback/20261106000000_u15_pitch_arsenal_down.sql.
-- Test: supabase/tests/u15_pitch_arsenal.sql.

create function public.set_pitch_arsenal(p_pitcher uuid, p_types text[]) returns void
  language plpgsql security definer set search_path to '' as $$
declare v_clean text[];
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not exists (select 1 from public.profiles where id = p_pitcher and role = 'pitcher') then
    raise exception 'not allowed';
  end if;
  if not (public.is_my_profile(p_pitcher)
          or exists (select 1 from public.pitcher_teams pt
                      where pt.pitcher_id = p_pitcher and not public.is_team_archived(pt.team_id)
                        and public.coach_sees_pitcher(pt.team_id, p_pitcher))) then
    raise exception 'not allowed';
  end if;
  if p_types is null or cardinality(p_types) > 20
     or exists (select 1 from unnest(p_types) t where t is null or btrim(t) = '' or length(t) > 40) then
    raise exception 'invalid pitch list';
  end if;
  -- the order is the pitcher's colour order: keep it, drop repeats
  select coalesce(array_agg(t order by i), '{}') into v_clean
    from (select t, min(i) i from unnest(p_types) with ordinality u(t, i) group by t) x;
  update public.profiles set pitch_types = v_clean where id = p_pitcher;
end;
$$;
revoke all on function public.set_pitch_arsenal(uuid, text[]) from public, anon;
grant execute on function public.set_pitch_arsenal(uuid, text[]) to authenticated;
