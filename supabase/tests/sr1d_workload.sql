-- SR1 Stage D acceptance, database part (staging; everything rolled back -- the block ends by raising its results).
-- Fixture logins (example.invalid): coach C (baseball head; also a softball profile and team), pitcher P (on C's
-- baseball team), stranger X. Checks are numbered after the packet's acceptance checks 15 and 17; the rest dates and
-- the warning edges (16, 17) live in the report function and are checked by scripts/sr1d-check.ts.
do $$
declare
  C uuid := 'aaaaaaaa-0000-4000-8000-0000000005d1';
  P uuid := 'aaaaaaaa-0000-4000-8000-0000000005d2';
  X uuid := 'aaaaaaaa-0000-4000-8000-0000000005d3';
  CS uuid; team uuid; steam uuid; anchor uuid := gen_random_uuid();
  r jsonb; w jsonb; n int; pw int; err text; v text; out text := ''; fails int := 0; pol0 int; pol1 int;
  -- (label, start offset, kind, pitches, adjust)
  i int;
begin
  select count(*) into pol0 from pg_policies where schemaname = 'public';
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select x.u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', x.e || '@example.invalid',
         jsonb_build_object('full_name', x.nm, 'intended_role', x.ro, 'intended_sport', 'baseball'), now(), now()
    from (values (C, 'sr1d-c', 'Casey Head', 'coach'), (P, 'sr1d-p', 'Pat Workload', 'pitcher'), (X, 'sr1d-x', 'Xan Stranger', 'coach')) x(u, e, nm, ro);
  insert into public.profiles (id, role, full_name, sport) select P, 'pitcher', 'Pat Workload', 'baseball'
   where not exists (select 1 from public.profiles where id = P);   -- landmine 3
  update public.profiles set age_attestation = 'adult', attested_at = now(), attested_via = 'signup', terms_version = '2026-10-17' where id in (C, P, X);

  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true); set local role authenticated;
  team := public.create_team('SR1D Baseball', C);
  CS := public.add_sport_profile('softball');
  steam := public.create_team('SR1D Softball', CS);
  reset role;
  insert into public.pitcher_teams (pitcher_id, team_id) values (P, team);

  -- ---------- 15. the age group saves for a team (head only, baseball only) and for a pitcher's own profile ----------
  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true); set local role authenticated;
  perform public.set_team_age_group(team, '15-16');
  select pitch_smart_age into v from public.teams where id = team;
  out := out || ' 15a head sets 15-16:' || coalesce(v, 'null'); if v is distinct from '15-16' then fails := fails + 1; end if;
  begin perform public.set_team_age_group(steam, '15-16'); err := 'saved'; exception when others then err := sqlerrm; end;
  out := out || ' | softball team:' || err; if err <> 'baseball_only' then fails := fails + 1; end if;
  begin perform public.set_team_age_group(team, '12-13'); err := 'saved'; exception when others then err := left(sqlerrm, 40); end;
  out := out || ' | not a group:' || err; if err = 'saved' then fails := fails + 1; end if;
  select level_confirmed_at is null into strict err from public.teams where id = team;
  out := out || ' | confirmed before:' || (case when err = 'true' then 'no' else 'yes' end);
  perform public.set_team_level(team, 'high_school');
  select (level_confirmed_at is not null)::text into err from public.teams where id = team;
  out := out || ' level set -> confirmed:' || err; if err <> 'true' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role', 'authenticated')::text, true); set local role authenticated;
  begin perform public.set_team_age_group(team, '7-8'); err := 'saved'; exception when others then err := sqlerrm; end;
  out := out || ' | stranger:' || err; if err = 'saved' then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  update public.profiles set pitch_smart_age = '17-18' where id = P;
  select pitch_smart_age into v from public.profiles where id = P;
  out := out || ' | pitcher own:' || coalesce(v, 'null'); if v is distinct from '17-18' then fails := fails + 1; end if;
  begin perform public.set_team_age_group(team, '7-8'); err := 'saved'; exception when others then err := sqlerrm; end;
  out := out || ' | pitcher on team:' || err; if err = 'saved' then fails := fails + 1; end if;

  -- ---------- 17. the 7-day count = pitcher_workload for the same pitcher and day ----------
  -- a pen 6 days ago (30), a pen 8 days ago (40, outside), the anchor game 2 hours ago (50 pitches, +3 adjustment)
  for i in 1 .. 3 loop
    r := public.sync_session(
      jsonb_build_object('id', case when i = 3 then anchor else gen_random_uuid() end, 'pitcher_id', P, 'team_id', team, 'logged_by', P,
        'kind', case when i = 3 then 'game' else 'bullpen' end,
        'started_at', now() - (array[interval '6 days', interval '8 days', interval '2 hours'])[i],
        'ended_at', now() - (array[interval '6 days', interval '8 days', interval '2 hours'])[i] + interval '40 minutes',
        'pitch_count_adjust', case when i = 3 then 3 else 0 end),
      (select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'Four Seam Fastball', 'velo', 80, 'ts', now() - interval '9 days' + k * interval '1 second',
          'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2, 'kind', case when i = 3 then 'game' else 'bullpen' end,
          'result', case when i = 3 then 'ball' end, 'inning', case when i = 3 then 1 end, 'at_bat_index', case when i = 3 then k / 4 end,
          'balls_before', case when i = 3 then 0 end, 'strikes_before', case when i = 3 then 0 end, 'outs_before', case when i = 3 then 0 end))
         from generate_series(1, (array[30, 40, 50])[i]) k),
      '[]'::jsonb);
    if (r ->> 'ok') is distinct from 'true' then fails := fails + 1; out := out || ' save' || i || ':' || r::text; end if;
  end loop;
  w := public.session_workload(anchor);
  select d7_bullpen + d7_game into pw from public.pitcher_workload(array[P]);
  out := out || ' | 17 session_workload ' || (w ->> 'seven_day') || ' = pitcher_workload ' || pw || ' (30 + 53; the 40 eight days back left out)'
         || ' level ' || coalesce(w ->> 'level', 'null') || ' age ' || coalesce(w ->> 'age_group', 'null');
  if (w ->> 'seven_day')::int <> pw or pw <> 83 or w ->> 'age_group' <> '15-16' or w ->> 'level' <> 'high_school' then fails := fails + 1; end if;
  -- a pen saved after the anchor changes nothing for the anchor
  r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', P, 'team_id', team, 'logged_by', P, 'kind', 'bullpen',
         'started_at', now() - interval '30 minutes', 'ended_at', now() - interval '10 minutes'),
       (select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'Four Seam Fastball', 'ts', now(), 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2, 'kind', 'bullpen')) from generate_series(1, 12)),
       '[]'::jsonb);
  w := public.session_workload(anchor);
  out := out || ' | after a later pen: ' || (w ->> 'seven_day'); if (w ->> 'seven_day')::int <> 83 then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role', 'authenticated')::text, true); set local role authenticated;
  w := public.session_workload(anchor);
  out := out || ' | stranger: ' || coalesce(w ->> 'error', 'read it') || ' age ' || coalesce(public.sr1_session_age(anchor), 'hidden');
  if w ->> 'error' is distinct from 'not_found' or public.sr1_session_age(anchor) is not null then fails := fails + 1; end if;
  reset role;

  select count(*) into pol1 from pg_policies where schemaname = 'public';
  out := out || ' | policies ' || pol0 || '->' || pol1; if pol1 <> 32 then fails := fails + 1; end if;
  out := out || ' | hard fails ' || fails;
  raise exception 'SR1D(rolled back):%', out;
end $$;
