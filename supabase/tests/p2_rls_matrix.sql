-- P2-01 access matrix: who can read and do what with a pitcher's sessions on several teams AND with no team
-- ("independent"). Run on staging BEFORE and AFTER the p2_01 migration; everything is rolled back (the block ends by
-- raising its results). Built from r4_rls_matrix.sql (same personas) plus:
--   SI  an independent pen of P (team_id NULL)      Q / SQ  a pitcher on no team at all, and his independent pen
-- BEFORE the migration team_id is NOT NULL, so the test drops it inside this (rolled-back) transaction and inserts the
-- NULL-team rows as the owner -- to see how today's policies treat such a row. AFTER, the same lines run unchanged.
--   P   pitcher (baseball) on TA (recording) and TB (other current team), TC (archived), left TD
--   HA/AA  head/assistant of TA    HB/AB  head/assistant of TB    HC  head of TC (archived)
--   HD  head of TD (pitcher left)  HS  head of a softball team    X  unrelated coach    anon
do $$
declare
  P uuid := 'aaaaaaaa-0000-4000-8000-000000000d01'; Q uuid := 'aaaaaaaa-0000-4000-8000-000000000d02';
  HA uuid := 'aaaaaaaa-0000-4000-8000-000000000d11'; AA uuid := 'aaaaaaaa-0000-4000-8000-000000000d12';
  HB uuid := 'aaaaaaaa-0000-4000-8000-000000000d13'; AB uuid := 'aaaaaaaa-0000-4000-8000-000000000d14';
  HC uuid := 'aaaaaaaa-0000-4000-8000-000000000d15'; HD uuid := 'aaaaaaaa-0000-4000-8000-000000000d16';
  HS uuid := 'aaaaaaaa-0000-4000-8000-000000000d17'; X  uuid := 'aaaaaaaa-0000-4000-8000-000000000d18';
  TA uuid; TB uuid; TC uuid; TD uuid; TS uuid; TX uuid;
  SA uuid := 'aaaaaaaa-0000-4000-8000-000000000e01'; SB uuid := 'aaaaaaaa-0000-4000-8000-000000000e02';
  SD uuid := 'aaaaaaaa-0000-4000-8000-000000000e03'; SI uuid := 'aaaaaaaa-0000-4000-8000-000000000e04';
  SQ uuid := 'aaaaaaaa-0000-4000-8000-000000000e05';
  pj jsonb; r jsonb; out text := ''; who record; v text; s uuid; c1 int; c2 int; c3 int; c4 int; c5 int;
  lb_before jsonb; lb_after jsonb;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000','authenticated','authenticated', 'p2m-' || n || '@example.invalid', '{}', now(), now()
    from (values (P,'p'),(Q,'q'),(HA,'ha'),(AA,'aa'),(HB,'hb'),(AB,'ab'),(HC,'hc'),(HD,'hd'),(HS,'hs'),(X,'x')) x(u, n);
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version)
  select u, rl, nm, sp, now(), 'adult', now(), 'signup', '2026-10-17'
    from (values (P,'pitcher','Pat P2','baseball'),(Q,'pitcher','Quinn Solo','baseball'),(HA,'coach','HA','baseball'),(AA,'coach','AA','baseball'),
                 (HB,'coach','HB','baseball'),(AB,'coach','AB','baseball'),(HC,'coach','HC','baseball'),(HD,'coach','HD','baseball'),
                 (HS,'coach','HS','softball'),(X,'coach','X','baseball')) x(u, rl, nm, sp);
  TA := public._create_team_with_head(HA, 'P2 Team A'); TB := public._create_team_with_head(HB, 'P2 Team B');
  TC := public._create_team_with_head(HC, 'P2 Team C'); TD := public._create_team_with_head(HD, 'P2 Team D');
  TS := public._create_team_with_head(HS, 'P2 Softball'); TX := public._create_team_with_head(X, 'P2 Unrelated');
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (TA, AA, 'assistant', HA), (TB, AB, 'assistant', HB);
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (P, TA, now() - interval '30 days'), (P, TB, now() - interval '30 days'),
    (P, TC, now() - interval '30 days'), (P, TD, now() - interval '30 days');

  -- the team-filed pens, through sync_session as the pitcher
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  foreach s in array array[SA, SB, SD] loop
    select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 4);
    r := public.sync_session(jsonb_build_object('id', s, 'pitcher_id', P, 'team_id', case s when SA then TA when SB then TB else TD end,
           'logged_by', P, 'started_at', now() - interval '2 days', 'ended_at', now() - interval '2 days' + interval '30 minutes'), pj, '[]');
  end loop;
  -- an independent pen through sync_session (refused before the migration, saved after)
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 4);
  r := public.sync_session(jsonb_build_object('id', SI, 'pitcher_id', P, 'team_id', null, 'logged_by', P,
         'started_at', now() - interval '1 day', 'ended_at', now() - interval '1 day' + interval '30 minutes'), pj, '[]');
  out := 'SYNC_SESSION team NULL (P): ' || coalesce(r ->> 'status', r ->> 'error');
  execute 'reset role';
  -- before the migration: make the NULL-team rows exist anyway (rolled back), to see how today's policies read them
  if (select is_nullable from information_schema.columns where table_schema = 'public' and table_name = 'sessions' and column_name = 'team_id') = 'NO' then
    alter table public.sessions alter column team_id drop not null;
  end if;
  alter table public.sessions disable trigger sessions_g3_team_check;
  insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, ended_at, kind)
    select SI, P, null, P, now() - interval '1 day', now() - interval '1 day' + interval '30 minutes', 'bullpen' where not exists (select 1 from public.sessions where id = SI);
  insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, ended_at, kind)
    values (SQ, Q, null, Q, now() - interval '1 day', now() - interval '1 day' + interval '30 minutes', 'bullpen');
  alter table public.sessions enable trigger sessions_g3_team_check;
  insert into public.pitches (session_id, type, target_row, target_col, actual_row, actual_col, ts)
    select vv.sid, 'fb', 2, 2, 2, 2, now() from (values (SI), (SQ)) vv(sid) where not exists (select 1 from public.pitches pp where pp.session_id = vv.sid);
  alter table public.game_events disable trigger game_events_h1_lock;   -- setup only: one event on each pen (rolled back)
  insert into public.game_events (session_id, event_type, seq) select vv.sid, 'balk', 1 from (values (SA), (SB), (SD), (SI), (SQ)) vv(sid);
  alter table public.game_events enable trigger game_events_h1_lock;
  insert into public.session_notes (session_id, author_id, author_name, body)
    values (SA, HA, 'HA', 'note on A'), (SB, HB, 'HB', 'note on B'), (SD, HD, 'HD', 'note on D');
  update public.teams set archived_at = now(), archived_by = HC where id = TC;   -- TC archived
  delete from public.pitcher_teams where pitcher_id = P and team_id = TD;      -- P left TD

  -- READ: sessions/pitches/events/notes visible per persona for SA SB SD SI SQ
  out := out || ' || READ s/p/e/n (SA SB SD SI SQ):';
  for who in select * from (values ('P',P),('Q',Q),('HA',HA),('AA',AA),('HB',HB),('AB',AB),('HC',HC),('HD',HD),('HS',HS),('X',X)) t(n, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role','authenticated')::text, true); execute 'set local role authenticated';
    v := '';
    foreach s in array array[SA, SB, SD, SI, SQ] loop
      select count(*) into c1 from public.sessions where id = s;
      select count(*) into c2 from public.pitches where session_id = s;
      select count(*) into c5 from public.game_events where session_id = s;
      select count(*) into c3 from public.session_notes where session_id = s;
      v := v || ' ' || c1 || '/' || c2 || '/' || c5 || '/' || c3;
    end loop;
    execute 'reset role';
    out := out || ' | ' || who.n || ':' || v;
  end loop;
  execute 'set local role anon';
  select count(*) into c1 from public.sessions where id in (SA, SB, SD, SI, SQ);
  select count(*) into c2 from public.pitches where session_id in (SA, SB, SD, SI, SQ);
  execute 'reset role';
  out := out || ' | anon: ' || c1 || '/' || c2;

  -- WRITE: add a note (SA SB SI SQ), each undone
  out := out || ' || NOTE INSERT (SA SB SI SQ):';
  for who in select * from (values ('P',P),('HA',HA),('AA',AA),('HB',HB),('AB',AB),('HC',HC),('X',X)) t(n, id) loop
    v := '';
    foreach s in array array[SA, SB, SI, SQ] loop
      begin
        perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role','authenticated')::text, true); execute 'set local role authenticated';
        insert into public.session_notes (session_id, author_id, author_name, body) values (s, who.id, who.n, 'probe');
        raise exception 'P2UNDO:ok';
      exception when others then
        v := v || ' ' || case when sqlerrm = 'P2UNDO:ok' then 'yes' else 'no' end;
      end;
      execute 'reset role';
    end loop;
    out := out || ' | ' || who.n || ':' || v;
  end loop;
  out := out || ' || DELETE_SESSION (SA SB SI):';
  for who in select * from (values ('P',P),('HA',HA),('AA',AA),('HB',HB),('AB',AB)) t(n, id) loop
    v := '';
    foreach s in array array[SA, SB, SI] loop
      begin
        perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role','authenticated')::text, true); execute 'set local role authenticated';
        r := public.delete_session(s);
        raise exception 'P2UNDO:%', coalesce(r->>'ok', 'no');
      exception when others then
        v := v || ' ' || case when sqlerrm = 'P2UNDO:true' then 'yes' else 'no' end;
      end;
      execute 'reset role';
    end loop;
    out := out || ' | ' || who.n || ':' || v;
  end loop;
  out := out || ' || REPORT_PATH WRITE (SA SB SI SQ):';
  for who in select * from (values ('P',P),('Q',Q),('HA',HA),('HB',HB),('HC',HC),('X',X)) t(n, id) loop
    v := '';
    foreach s in array array[SA, SB, SI, SQ] loop
      begin
        perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role','authenticated')::text, true); execute 'set local role authenticated';
        update public.sessions set report_path = repeat('ab', 32) || '.html' where id = s;
        get diagnostics c4 = row_count;
        raise exception 'P2UNDO:%', c4;
      exception when others then
        v := v || ' ' || case when sqlerrm = 'P2UNDO:1' then 'yes' else 'no' end;
      end;
      execute 'reset role';
    end loop;
    out := out || ' | ' || who.n || ':' || v;
  end loop;
  -- report eligibility (P on teams, Q on none)
  out := out || ' || ELIGIBLE P/Q: ' || public.is_pitcher_report_eligible(P) || '/' || public.is_pitcher_report_eligible(Q)
             || ' block Q: ' || coalesce(public.pitcher_report_block(Q), 'none');
  out := out || ' || policies: ' || (select count(*) from pg_policies where schemaname = 'public');
  raise exception 'MATRIX(rolled back):%', out;
end $$;
