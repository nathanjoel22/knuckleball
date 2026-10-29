-- F1-A load test, part 2 of 2: sessions (STAGING ONLY). Run repeatedly until it reports 0 left: each run charts 20
-- sessions (16 pens, 4 Live Games, ~60 pitches each, over the last 140 days) for up to 12 LoadTest players who have
-- none yet, through sync_session as the facility manager -- so sealing, the triggers and session_stats all run.
--   supabase db query --linked --project-ref wpsscxwawgiwmifpjpec -f supabase/scripts/f1a_loadtest_sessions.sql
do $$
declare
  KNIGHTS constant uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';
  org uuid; fb uuid; mgr uuid; mgr_bb uuid; p record; k int; j int; r jsonb; pj jsonb; arr jsonb[];
  st timestamptz; kind text; types text[] := array['FB','CB','CH','SL']; t text; tr int; tc int; ar int; ac int;
  b int; s int; outs int; inn int; ab int; res text; v numeric; aimed boolean; done int := 0; left_n int;
begin
  if not exists (select 1 from public.teams where id = KNIGHTS and name = 'Staging Knights') then
    raise exception 'refused: this is not the staging project';
  end if;
  select id, manager_login into org, mgr from public.organizations where name = 'LoadTest Training Center';
  select id, coach_id into fb, mgr_bb from public.teams where org_id = org and sport = 'baseball';
  perform set_config('request.jwt.claims', json_build_object('sub', mgr, 'role', 'authenticated')::text, true);
  for p in select pr.id from public.profiles pr join public.pitcher_teams pt on pt.pitcher_id = pr.id and pt.team_id = fb
            where pr.full_name like 'LoadTest %' and not exists (select 1 from public.sessions x where x.pitcher_id = pr.id)
            order by pr.full_name limit 12 loop
    for k in 1..20 loop
      kind := case when k % 5 = 0 then 'game' else 'bullpen' end;
      st := date_trunc('minute', now() - (140 - k * 7) * interval '1 day' - (random() * 6) * interval '1 hour');
      arr := '{}'; b := 0; s := 0; outs := 0; inn := 1; ab := 0;
      for j in 1..(55 + floor(random() * 11))::int loop
        t := types[1 + floor(random() * random() * 4)::int];   -- fastballs most often
        v := case t when 'FB' then 79 + random() * 7 when 'CB' then 64 + random() * 7 when 'CH' then 70 + random() * 6 else 72 + random() * 6 end;
        tr := 1 + floor(random() * 3)::int; tc := 1 + floor(random() * 3)::int;
        ar := greatest(0, least(4, tr + round(random() * 2 - 1)::int)); ac := greatest(0, least(4, tc + round(random() * 2 - 1)::int));
        if kind = 'bullpen' then
          arr := arr || jsonb_build_object('id', gen_random_uuid(), 'kind', 'bullpen', 'type', t, 'velo', case when random() < .8 then round(v) end,
            'ts', st + j * interval '25 seconds', 'target_row', tr, 'target_col', tc, 'actual_row', ar, 'actual_col', ac,
            'batter_side', case when random() < .5 then 'R' else 'L' end, 'delivery', case when random() < .6 then 'windup' else 'set' end);
        else
          aimed := random() < .7;   -- a called spot on most pitches (both target cells or neither)
          res := case when random() < .36 then 'ball' when random() < .25 then 'strike_looking' when random() < .2 then 'strike_swinging'
                      when random() < .5 then 'foul' else 'in_play' end;
          arr := arr || jsonb_build_object('id', gen_random_uuid(), 'kind', 'game', 'type', t, 'velo', round(v),
            'ts', st + j * interval '20 seconds', 'target_row', case when aimed then tr end, 'target_col', case when aimed then tc end,
            'actual_row', ar, 'actual_col', ac, 'batter_side', case when random() < .6 then 'R' else 'L' end,
            'delivery', case when random() < .5 then 'windup' else 'set' end, 'result', res,
            'in_play_outcome', case when res = 'in_play' then case when random() < .7 then 'out' else 'hit' end end,
            'hit_type', null, 'inning', inn, 'outs_before', outs, 'balls_before', b, 'strikes_before', s, 'at_bat_index', ab,
            'outs_on_play', case when res = 'in_play' then 0 end, 'runs_scored', 0);
          -- the count, outs and innings move on as a game's would (hits stay singles; runners aren't tracked here)
          if res = 'ball' then b := b + 1; if b = 4 then b := 0; s := 0; ab := ab + 1; end if;
          elsif res in ('strike_looking', 'strike_swinging') then
            if s = 2 then b := 0; s := 0; ab := ab + 1; outs := outs + 1; else s := s + 1; end if;
          elsif res = 'foul' then if s < 2 then s := s + 1; end if;
          else
            if (arr[array_length(arr, 1)] ->> 'in_play_outcome') = 'out' then
              arr[array_length(arr, 1)] := arr[array_length(arr, 1)] || jsonb_build_object('outs_on_play', 1, 'bb_type', 'ground', 'spray_box', 22, 'spray_field', 'IF');
              outs := outs + 1;
            else
              arr[array_length(arr, 1)] := arr[array_length(arr, 1)] || jsonb_build_object('hit_type', '1B', 'bb_type', 'line', 'spray_box', 20, 'spray_field', 'OF');
            end if;
            b := 0; s := 0; ab := ab + 1;
          end if;
          if outs = 3 then outs := 0; inn := inn + 1; end if;
        end if;
      end loop;
      pj := to_jsonb(arr);
      set local role authenticated;
      r := public.sync_session(jsonb_build_object('id', gen_random_uuid(), 'pitcher_id', p.id, 'team_id', fb, 'logged_by', mgr_bb,
             'kind', kind, 'started_at', st, 'ended_at', st + interval '40 minutes', 'charting_perspective', 'behind_catcher',
             'opponent', case when kind = 'game' then 'LoadTest Opponent' end,
             'game_final_inning', case when kind = 'game' then inn end, 'game_outs_recorded', case when kind = 'game' then (inn - 1) * 3 + outs end),
             pj, '[]');
      reset role;
      if not coalesce((r ->> 'ok')::boolean, false) then raise exception 'sync_session: %', r; end if;
    end loop;
    done := done + 1;
  end loop;
  select count(*) into left_n from public.profiles pr join public.pitcher_teams pt on pt.pitcher_id = pr.id and pt.team_id = fb
   where pr.full_name like 'LoadTest %' and not exists (select 1 from public.sessions x where x.pitcher_id = pr.id);
  raise notice 'charted % players; % left', done, left_n;
  perform set_config('kb.f1a_left', left_n::text, false);
end $$;
select count(*) filter (where pr.full_name like 'LoadTest %' and not exists (select 1 from public.sessions x where x.pitcher_id = pr.id)) as players_left,
       (select count(*) from public.sessions s join public.teams t on t.id = s.team_id where t.name = 'LoadTest Training Center') as sessions,
       (select count(*) from public.session_stats_failures) as stats_failures
  from public.profiles pr;
