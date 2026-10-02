-- S4 acceptance 1: the RLS read/write matrix. Run on STAGING before and
-- after the s4a migration; the RESULTS line must be identical for every
-- existing single-profile account. Everything is rolled back (the block
-- ends by raising its results).
do $$
declare
  T  uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights
  H  uuid := '84c1d3f1-0509-49b2-8b3f-30aae98dcbf3';   -- its head coach
  P  uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- a pitcher on it
  S  uuid := '0822329a-2f3c-4133-aec1-aa81b8d9eb06';   -- one of P's saved pens on T
  A  uuid := 'aaaaaaaa-0000-4000-8000-00000000000a';   -- assistant (fixture)
  X  uuid := 'aaaaaaaa-0000-4000-8000-00000000000b';   -- stranger coach (fixture)
  XT uuid;
  persona record; stmt text; lbl text; n bigint; out text := '';
  stmts text[] := array[
    'sel profiles|select count(*) from public.profiles',
    'sel teams|select count(*) from public.teams',
    'sel team_coaches|select count(*) from public.team_coaches',
    'sel pitcher_teams|select count(*) from public.pitcher_teams',
    'sel sessions|select count(*) from public.sessions',
    'sel pitches|select count(*) from public.pitches',
    'sel game_events|select count(*) from public.game_events',
    'sel session_notes|select count(*) from public.session_notes',
    'sel session_opened|select count(*) from public.session_opened',
    'sel roster_seen|select count(*) from public.roster_seen',
    'sel accuracy_zones|select count(*) from public.accuracy_zones',
    'sel leaderboard_exclusions|select count(*) from public.leaderboard_exclusions',
    'sel invites|select count(*) from public.invites',
    'sel departures|select count(*) from public.pitcher_team_departures',
    'upd own profile|update public.profiles set full_name = full_name where id = ''{ME}''',
    'upd P profile|update public.profiles set full_name = full_name where id = ''{P}''',
    'upd team T|update public.teams set name = name where id = ''{T}''',
    'ins session for P on T|insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, ended_at) values (gen_random_uuid(), ''{P}'', ''{T}'', ''{ME}'', now(), now())',
    'upd session S|update public.sessions set charting_perspective = charting_perspective where id = ''{S}''',
    'del session S|delete from public.sessions where id = ''{S}''',
    'ins pitch in S|insert into public.pitches (session_id, type, target_row, target_col, actual_row, actual_col, ts) values (''{S}'', ''fb'', 2, 2, 2, 2, now())',
    'del pitches of S|delete from public.pitches where session_id = ''{S}''',
    'ins membership ME->T|insert into public.pitcher_teams (pitcher_id, team_id) values (''{ME}'', ''{T}'')',
    'del membership P|delete from public.pitcher_teams where pitcher_id = ''{P}'' and team_id = ''{T}''',
    'ins coach ME->T|insert into public.team_coaches (team_id, coach_id, role) values (''{T}'', ''{ME}'', ''assistant'')',
    'ins note on S|insert into public.session_notes (session_id, author_id, body) values (''{S}'', ''{ME}'', ''matrix'')',
    'ins opened own|insert into public.session_opened (viewer_id, session_id) values (''{ME}'', ''{S}'')',
    'ins opened for H|insert into public.session_opened (viewer_id, session_id) values (''{H}'', ''{S}'')',
    'ins roster_seen own|insert into public.roster_seen (viewer_id, pitcher_id) values (''{ME}'', ''{P}'') on conflict do nothing',
    'ins zone for P|insert into public.accuracy_zones (pitcher_id, pitch_type, batter_side, cells) values (''{P}'', ''zz'', ''R'', ''{}'')',
    'fn is_team_coach T|select count(*) from (select 1 where public.is_team_coach(''{T}'')) x',
    'fn is_team_head T|select count(*) from (select 1 where public.is_team_head(''{T}'')) x',
    'fn is_team_member T|select count(*) from (select 1 where public.is_team_member(''{T}'')) x',
    'fn unopened T|select count(*) from public.get_unopened_sessions(''{T}'')',
    'fn roster_latest T|select count(*) from public.get_roster_latest(''{T}'')',
    'fn roster_verification T|select count(*) from public.get_roster_verification(''{T}'')',
    'fn my_verification|select count(*) from public.my_verification_status()',
    'fn leaderboard T|select count(*) from (select public.get_team_leaderboard(''{T}'', ''all'') r) x where r is not null and r ? ''velocity''',
    'fn report_eligible P|select count(*) from (select 1 where public.is_pitcher_report_eligible(''{P}'')) x',
    'fn set_uniform P|select count(*) from (select public.set_uniform_number(''{T}'', ''{P}'', null, (select uniform_number from public.pitcher_teams where pitcher_id = ''{P}'' and team_id = ''{T}'')) r) x where r ? ''ok''',
    'fn delete_session S|select count(*) from (select public.delete_session(''{S}'') r) x where r ? ''ok''',
    'fn create_team|select count(*) from (select public.create_team(''Matrix Team'') r) x where r is not null'
  ];
begin
  -- fixtures (as postgres)
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
    (A, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','matrix-a@example.invalid','{}', now(), now()),
    (X, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','matrix-x@example.invalid','{}', now(), now());
  insert into public.profiles (id, role, full_name, sport) values (A, 'coach', 'Matrix Asst', 'baseball'), (X, 'coach', 'Matrix Stranger', 'baseball');
  insert into public.team_coaches (team_id, coach_id, role, joined_at) values (T, A, 'assistant', now() - interval '400 days');
  XT := public._create_team_with_head(X, 'Matrix Stranger Team');

  for persona in select * from (values ('pitcher', P::text), ('head', H::text), ('assistant', A::text), ('stranger', X::text), ('anon', null)) v(name, id) loop
    out := out || chr(10) || '[' || persona.name || ']';
    foreach stmt in array stmts loop
      lbl := split_part(stmt, '|', 1);
      stmt := replace(replace(replace(replace(replace(split_part(stmt, '|', 2), '{ME}', coalesce(persona.id, '00000000-0000-0000-0000-000000000000')), '{P}', P::text), '{T}', T::text), '{S}', S::text), '{H}', H::text);
      begin
        if persona.id is null then
          execute 'set local role anon';
          perform set_config('request.jwt.claims', '{"role":"anon"}', true);
        else
          perform set_config('request.jwt.claims', json_build_object('sub', persona.id, 'role', 'authenticated')::text, true);
          execute 'set local role authenticated';
        end if;
        if left(stmt, 6) = 'select' then execute stmt into n; out := out || ' ' || lbl || '=' || n;
        else execute stmt; get diagnostics n = row_count; out := out || ' ' || lbl || '=' || n || 'r'; end if;
        execute 'reset role';
        raise exception 'undo' using errcode = 'P0002';   -- roll this one statement back
      exception
        when sqlstate 'P0002' then null;
        when others then execute 'reset role'; out := out || ' ' || lbl || '=ERR:' || sqlstate;
      end;
    end loop;
  end loop;
  raise exception 'MATRIX%', out;
end $$;
