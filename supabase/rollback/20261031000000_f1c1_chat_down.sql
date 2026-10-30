-- Rollback for 20261031000000_f1c1_chat. Puts back move_between_groups (F1-A) and a1_purge_profile (A1) exactly as
-- they were, stops the daily clear and removes every chat table and function. Chat messages are lost: run only on
-- Joel's decision.
select cron.unschedule('f1c1-chat-clear');
drop trigger if exists coach_group_members_f1c1_chat on public.coach_group_members;
create or replace function public.move_between_groups(p_pitcher uuid, p_from uuid, p_to uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_team uuid; v_to_team uuid;
begin
  select team_id into v_team from public.coach_groups where id = p_from;
  select team_id into v_to_team from public.coach_groups where id = p_to;
  if v_team is null or v_to_team is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if v_team <> v_to_team then return jsonb_build_object('ok', false, 'error', 'other_side'); end if;
  if not public.is_org_manager(v_team) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  delete from public.coach_group_members where group_id = p_from and pitcher_id = p_pitcher;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_in_group'); end if;
  insert into public.coach_group_members (group_id, pitcher_id, added_by, flagged_new)
    values (p_to, p_pitcher, public.f1a_my_coach_profile(v_team), false)
    on conflict (group_id, pitcher_id) do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

CREATE OR REPLACE FUNCTION public.a1_purge_profile(p_profile uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_reports text[];
  v_tombstoned int := 0;
  v_pitches int := 0;
  v_notes int := 0;
  v_recharted int := 0;
  s record;
  n int;
  v_child jsonb;
  v_child_profiles int := 0;
begin
  if not exists (select 1 from public.profiles where id = p_profile) then
    return jsonb_build_object('ok', true, 'status', 'already_gone');
  end if;
  if exists (select 1 from public.teams where coach_id = p_profile) then
    return jsonb_build_object('error', 'still_head');
  end if;
  -- a parent's managed players first: deleting the parent's profile would otherwise CASCADE them (and their
  -- sessions) without tombstones
  for s in select id from public.profiles where managed_by = p_profile and id <> p_profile loop
    v_child := public.a1_purge_profile(s.id);
    if v_child ? 'error' then return v_child; end if;
    v_child_profiles := v_child_profiles + 1 + coalesce((v_child->>'profiles')::int, 0);
    v_tombstoned := v_tombstoned + coalesce((v_child->>'tombstoned')::int, 0);
    v_pitches := v_pitches + coalesce((v_child->>'pitches')::int, 0);
    v_notes := v_notes + coalesce((v_child->>'notes')::int, 0);
    v_reports := coalesce(v_reports, '{}') || coalesce(array(select jsonb_array_elements_text(v_child->'reports')), '{}');
  end loop;
  -- the report files of every session this profile pitched (tombstoned or not)
  v_reports := coalesce(v_reports, '{}') || coalesce((select array_agg(report_path) filter (where report_path is not null)
                                                        from public.sessions where pitcher_id = p_profile), '{}');
  -- his own sessions -> tombstones (a record only)
  for s in select id, deleted_at from public.sessions where pitcher_id = p_profile loop
    if s.deleted_at is null then
      select count(*) into n from public.pitches where session_id = s.id;
      v_pitches := v_pitches + n;
      update public.sessions set deleted_at = now(), deleted_by = null, deleted_by_role = 'deleted_account',
             deleted_by_name = null, pitch_count = n
       where id = s.id;
      v_tombstoned := v_tombstoned + 1;
    else
      update public.sessions set deleted_by = null, deleted_by_role = 'deleted_account', deleted_by_name = null
       where id = s.id;
    end if;
    delete from public.game_events where session_id = s.id;
    delete from public.pitches where session_id = s.id;
    delete from public.session_notes where session_id = s.id;
    delete from public.session_opened where session_id = s.id;
  end loop;
  update public.sessions set pitcher_id = null, report_path = null, report_generated_at = null
   where pitcher_id = p_profile;
  -- sessions he charted for other pitchers stay theirs; he becomes a former coach
  update public.sessions set logged_by = null where logged_by = p_profile;
  get diagnostics v_recharted = row_count;
  -- a tombstone he wrote (deleting someone's session as head) loses his name
  update public.sessions set deleted_by = null, deleted_by_role = 'deleted_account', deleted_by_name = null
   where deleted_by = p_profile;
  -- notes he wrote are deleted
  delete from public.session_notes where author_id = p_profile;
  get diagnostics v_notes = row_count;
  delete from public.invites where invited_by = p_profile;
  update public.team_coaches set invited_by = null where invited_by = p_profile;
  -- memberships first: removing a pitcher_teams row makes G3's trigger log a departure that references this profile,
  -- which would then block the profile delete (the CLAUDE.md "deleting a team with a rostered pitcher" landmine)
  delete from public.pitcher_teams where pitcher_id = p_profile;
  delete from public.pitcher_team_departures where pitcher_id = p_profile;
  -- the profile itself; staff rows, red-dot state, accuracy zones and managed players cascade
  delete from public.profiles where id = p_profile;
  return jsonb_build_object('ok', true, 'reports', to_jsonb(coalesce(v_reports, '{}')), 'tombstoned', v_tombstoned,
                            'pitches', v_pitches, 'notes', v_notes, 'recharted', v_recharted, 'profiles', v_child_profiles);
end;
$function$;

drop function if exists public.chat_close(uuid), public.chat_resolve_report(uuid), public.chat_open_reports(), public.chat_report(uuid),
  public.chat_pin(uuid, boolean), public.chat_delete_message(uuid), public.chat_mark_read(uuid), public.chat_post(uuid, text),
  public.chat_thread(uuid, integer), public.chat_open(text, uuid, uuid, uuid), public.chat_compose_targets(), public.chat_summary(),
  public.chat_my_threads(), public.chat_my_orgs(), public.chat_access(uuid), public.chat_family_ok(uuid),
  public.f1c1_close_on_leave(), public.chat_clear_archived();
drop table public.chat_reports;
drop table public.chat_reads;
drop table public.chat_messages;
drop table public.chat_threads;
