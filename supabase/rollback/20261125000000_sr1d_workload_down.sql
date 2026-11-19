-- Rollback for 20261125000000_sr1d_workload.sql (SR1 Stage D). The functions go; set_team_level returns to its
-- definition from before (copied from staging Nov 19 2026, identical on production by checksum); the columns go, and
-- with them every age group and confirmation saved meanwhile. (After the report reads session_workload, roll the
-- report function back first.)
drop function if exists public.session_workload(uuid);
drop function if exists public.sr1_session_age(uuid);
drop function if exists public.set_team_age_group(uuid, text);
CREATE OR REPLACE FUNCTION public.set_team_level(p_team_id uuid, p_level text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if public.is_team_archived(p_team_id) then
    raise exception 'team_archived' using detail = 'This team is archived. Restore it first.';
  end if;
  update public.teams set level = p_level where id = p_team_id;
end;
$function$;
alter table public.profiles drop column if exists pitch_smart_age;
alter table public.teams drop column if exists level_confirmed_at;
alter table public.teams drop column if exists pitch_smart_age;
