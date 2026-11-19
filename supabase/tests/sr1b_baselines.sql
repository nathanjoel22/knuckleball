-- SR1 Stage B acceptance (staging; everything rolled back -- the block ends by raising its results).
-- Fixture: pitcher login P (example.invalid) saves pens and games at chosen dates through sync_session, as the app
-- does; coach login C heads a team P joins. Checks are numbered after the packet's acceptance checks 8 and 9, plus the
-- season / year-ago / 10-pitch / reach rules in plans/sr1b-preconditions.md.
--
-- The anchor pen is Thu Nov 19 2026, 12:00 Eastern. Its earlier pens (10 pitches each unless noted):
--   a  Nov 14 23:30 ET (Nov 15 04:30 UTC)   1m, 3m, 12m        -- the day before the high-school season (Eastern)
--   b  Nov 15 00:30 ET                      1m, 3m, 12m, season
--   c  Oct  5                               3m, 12m
--   g  Oct 10, tagged command               3m, 12m
--   d  Aug  1                               12m
--   e  Mar  1                               12m
--   f  Oct  1 2025                          year ago (Aug 19 - Nov 19 2025)
--   h  Nov 16, 5 pitches                    never (under 10)
--   i  Nov 20                               never (after the anchor)
--   G  a game Nov 11                        never for a pen
-- Expected for the anchor (untagged, level high_school): 1m n 2 (no avg) · 3m n 4 (avg, no range) · 12m n 6 (avg +
-- range) · season n 1 · year ago n 1.
do $$
declare
  P uuid := 'aaaaaaaa-0000-4000-8000-0000000005b1';
  C uuid := 'aaaaaaaa-0000-4000-8000-0000000005b2';
  X uuid := 'aaaaaaaa-0000-4000-8000-0000000005b3';   -- a stranger
  anchor uuid; tagged uuid; game_anchor uuid; team uuid;
  r jsonb; b jsonb; n int; nv int; ok boolean; out text := ''; fails int := 0; pol0 int; pol1 int;
  -- (label, local time in Eastern, kind, purpose, pitches)
  fx text[][] := array[
    ['a', '2026-11-14 23:30', 'bullpen', '', '10'],
    ['b', '2026-11-15 00:30', 'bullpen', '', '10'],
    ['c', '2026-10-05 12:00', 'bullpen', '', '10'],
    ['g', '2026-10-10 12:00', 'bullpen', 'command', '10'],
    ['d', '2026-08-01 12:00', 'bullpen', '', '10'],
    ['e', '2026-03-01 12:00', 'bullpen', '', '10'],
    ['f', '2025-10-01 12:00', 'bullpen', '', '10'],
    ['h', '2026-11-16 12:00', 'bullpen', '', '5'],
    ['i', '2026-11-20 12:00', 'bullpen', '', '10'],
    ['G', '2026-11-11 12:00', 'game', '', '10'],
    ['ANCHOR', '2026-11-19 12:00', 'bullpen', '', '10'],
    ['TAGGED', '2026-11-19 13:00', 'bullpen', 'command', '10'],
    ['GAME', '2026-11-19 14:00', 'game', '', '10']];
  i int; sid uuid; ts timestamptz;
begin
  select count(*) into pol0 from pg_policies where schemaname = 'public';
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select x.u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', x.e || '@example.invalid',
         jsonb_build_object('full_name', x.nm, 'intended_role', x.ro, 'intended_sport', 'baseball'), now(), now()
    from (values (P, 'sr1b-p', 'Pat Baseline', 'pitcher'), (C, 'sr1b-c', 'Casey Coach', 'coach'), (X, 'sr1b-x', 'Xan Stranger', 'coach')) x(u, e, nm, ro);
  insert into public.profiles (id, role, full_name, sport) select P, 'pitcher', 'Pat Baseline', 'baseball'
   where not exists (select 1 from public.profiles where id = P);   -- landmine 3
  update public.profiles set level = 'high_school' where id = P;

  -- ---------- the sessions, saved as the app saves them (independent pens; P charts himself) ----------
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  for i in 1 .. array_length(fx, 1) loop
    sid := gen_random_uuid(); ts := (fx[i][2])::timestamp at time zone 'America/New_York';
    r := public.sync_session(
      jsonb_build_object('id', sid, 'pitcher_id', P, 'team_id', null, 'logged_by', P, 'kind', fx[i][3],
                         'started_at', ts, 'ended_at', ts + interval '30 minutes', 'ra_on', false)
        || case when fx[i][4] = '' then '{}'::jsonb else jsonb_build_object('purpose', fx[i][4]) end,
      (select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'Fastball', 'velo', 80, 'ts', ts + k * interval '1 minute',
                         'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', case when k % 2 = 0 then 2 else 0 end, 'kind', fx[i][3],
                         'result', case when fx[i][3] = 'game' then (case when k % 2 = 0 then 'strike_looking' else 'ball' end) end,
                         'inning', case when fx[i][3] = 'game' then 1 end, 'at_bat_index', case when fx[i][3] = 'game' then k / 4 end,
                         'balls_before', case when fx[i][3] = 'game' then 0 end, 'strikes_before', case when fx[i][3] = 'game' then 0 end,
                         'outs_before', case when fx[i][3] = 'game' then 0 end))
         from generate_series(0, fx[i][5]::int - 1) k),
      '[]'::jsonb);
    if (r ->> 'ok') is distinct from 'true' then fails := fails + 1; out := out || ' save ' || fx[i][1] || ':' || r::text; end if;
    if fx[i][1] = 'ANCHOR' then anchor := sid; elsif fx[i][1] = 'TAGGED' then tagged := sid; elsif fx[i][1] = 'GAME' then game_anchor := sid; end if;
  end loop;

  -- ---------- 8. the window rules (high school: season from Nov 15 Eastern, a year ago shown) ----------
  b := public.session_baselines(anchor);
  out := out || ' | 8 level ' || (b ->> 'level') || ' season ' || (b ->> 'season_start');
  if b ->> 'season_start' <> '2026-11-15' then fails := fails + 1; end if;
  out := out || ' | 1m n' || (b #>> '{windows,1m,n}') || ' avg ' || coalesce(b #>> '{windows,1m,avg}', 'null');
  if (b #>> '{windows,1m,n}')::int <> 2 or (b #> '{windows,1m,avg}') <> 'null'::jsonb then fails := fails + 1; end if;
  out := out || ' | 3m n' || (b #>> '{windows,3m,n}') || ' avg ' || coalesce(b #>> '{windows,3m,avg,strike_pct}', 'null') || ' range ' || coalesce(b #>> '{windows,3m,range}', 'null');
  if (b #>> '{windows,3m,n}')::int <> 4 or (b #> '{windows,3m,avg}') = 'null'::jsonb or (b #> '{windows,3m,range}') <> 'null'::jsonb then fails := fails + 1; end if;
  out := out || ' | 12m n' || (b #>> '{windows,12m,n}') || ' range ' || coalesce(b #>> '{windows,12m,range,strike_pct}', 'null');
  if (b #>> '{windows,12m,n}')::int <> 6 or (b #> '{windows,12m,range}') = 'null'::jsonb then fails := fails + 1; end if;
  out := out || ' | season n' || (b #>> '{windows,season,n}') || ' (Nov 14 23:30 ET left out)';
  if (b #>> '{windows,season,n}')::int <> 1 then fails := fails + 1; end if;
  out := out || ' | year ago n' || coalesce(b #>> '{windows,year_ago,n}', 'absent');
  if (b #>> '{windows,year_ago,n}')::int is distinct from 1 then fails := fails + 1; end if;
  -- the pooled numbers for 12m: six pens, 10 pitches, 5 in the zone, 5 on the spot, all 80 mph
  out := out || ' | 12m avg ' || (b #>> '{windows,12m,avg}');
  if (b #>> '{windows,12m,avg,strike_pct}')::numeric <> 50 or (b #>> '{windows,12m,avg,spot_pct}')::numeric <> 50
     or (b #>> '{windows,12m,avg,velo}')::numeric <> 80 or (b #>> '{windows,12m,avg,pitches}')::numeric <> 10 then fails := fails + 1; end if;
  out := out || ' | type Fastball 12m n' || (b #>> '{windows,12m,types,Fastball,n}');
  if (b #>> '{windows,12m,types,Fastball,n}')::int <> 6 then fails := fails + 1; end if;

  -- ---------- 9. a tagged pen counts only same-tag pens; the session itself never counts ----------
  b := public.session_baselines(tagged);
  out := out || ' | 9 tagged 12m n' || (b #>> '{windows,12m,n}') || ' 1m n' || (b #>> '{windows,1m,n}');
  if (b #>> '{windows,12m,n}')::int <> 1 or (b #>> '{windows,1m,n}')::int <> 0 then fails := fails + 1; end if;
  b := public.session_baselines(game_anchor);
  out := out || ' | game 1m n' || (b #>> '{windows,1m,n}') || ' fp ' || coalesce(b #>> '{windows,1m,avg}', 'null');
  if (b #>> '{windows,1m,n}')::int <> 1 then fails := fails + 1; end if;

  -- ---------- levels: college (season Sep 1, no year ago); no level = college for baseball ----------
  reset role;
  update public.profiles set level = 'college' where id = P;
  set local role authenticated;
  b := public.session_baselines(anchor);
  out := out || ' | college season ' || (b ->> 'season_start') || ' n' || (b #>> '{windows,season,n}') || ' year ago ' || coalesce(b #>> '{windows,year_ago,n}', 'absent');
  if b ->> 'season_start' <> '2026-09-01' or (b #>> '{windows,season,n}')::int <> 4 or b #> '{windows}' ? 'year_ago' then fails := fails + 1; end if;
  reset role;
  update public.profiles set level = null where id = P;
  set local role authenticated;
  b := public.session_baselines(anchor);
  out := out || ' | no level -> ' || (b ->> 'level');
  if b ->> 'level' <> 'college' then fails := fails + 1; end if;
  reset role;

  -- ---------- reach: the stranger gets nothing; the coach's n = what the coach can read ----------
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role', 'authenticated')::text, true); set local role authenticated;
  b := public.session_baselines(anchor);
  out := out || ' | stranger: ' || coalesce(b ->> 'error', 'n' || (b #>> '{windows,12m,n}'));
  if b ->> 'error' is distinct from 'not_found' then fails := fails + 1; end if;
  ok := public.sr1_session_level(anchor) is null;
  out := out || ' level hidden:' || ok; if not ok then fails := fails + 1; end if;
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true); set local role authenticated;
  team := (public.create_team('SR1B Test Team', null))::text::uuid;
  reset role;
  if team is null then select id into team from public.teams where name = 'SR1B Test Team'; end if;
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (P, team, '2026-11-01'::timestamptz);
  perform set_config('request.jwt.claims', json_build_object('sub', C, 'role', 'authenticated')::text, true); set local role authenticated;
  b := public.session_baselines(anchor);
  if b ? 'error' then
    out := out || ' | coach: ' || (b ->> 'error') || ' (the anchor itself is out of reach)';
  else
    select count(*) into nv from public.session_stats x where x.pitcher_id = P and x.kind = 'bullpen' and x.session_id <> anchor
       and x.pitches >= 10 and x.started_at < (select started_at from public.sessions where id = anchor)
       and x.started_at >= (select started_at from public.sessions where id = anchor) - interval '12 months';
    out := out || ' | coach 12m n' || (b #>> '{windows,12m,n}') || ' = coach-readable ' || nv || ' (pitcher sees 6)';
    if (b #>> '{windows,12m,n}')::int <> nv then fails := fails + 1; end if;
  end if;
  reset role;

  select count(*) into pol1 from pg_policies where schemaname = 'public';
  out := out || ' | policies ' || pol0 || '->' || pol1;
  if pol1 <> 32 then fails := fails + 1; end if;
  out := out || ' | hard fails ' || fails;
  raise exception 'SR1B(rolled back):%', out;
end $$;
