-- R4 access matrix: what each persona can read and do for one pitcher's sessions on several teams.
-- Run on staging BEFORE and AFTER the R4 migration; rolled back. Every write attempt is undone.
--   P   pitcher (baseball) on TA (recording) and TB (other current team), TC (archived), left TD
--   P2  the same login's softball profile, on TS
--   HA/AA  head/assistant of TA    HB/AB  head/assistant of TB    HC  head of TC (archived)
--   HD  head of TD (pitcher left)  HS  head of TS (softball)      X  unrelated coach    anon
-- Sessions: SA (charted for TA), SB (for TB), SD (for TD while P was on it). Notes on each by its team's head.
do $$
declare
  P uuid := 'aaaaaaaa-0000-4000-8000-000000000b01'; P2 uuid := 'aaaaaaaa-0000-4000-8000-000000000b02';
  HA uuid := 'aaaaaaaa-0000-4000-8000-000000000b11'; AA uuid := 'aaaaaaaa-0000-4000-8000-000000000b12';
  HB uuid := 'aaaaaaaa-0000-4000-8000-000000000b13'; AB uuid := 'aaaaaaaa-0000-4000-8000-000000000b14';
  HC uuid := 'aaaaaaaa-0000-4000-8000-000000000b15'; HD uuid := 'aaaaaaaa-0000-4000-8000-000000000b16';
  HS uuid := 'aaaaaaaa-0000-4000-8000-000000000b17'; X  uuid := 'aaaaaaaa-0000-4000-8000-000000000b18';
  TA uuid; TB uuid; TC uuid; TD uuid; TS uuid; TX uuid;
  SA uuid := 'aaaaaaaa-0000-4000-8000-000000000c01'; SB uuid := 'aaaaaaaa-0000-4000-8000-000000000c02';
  SD uuid := 'aaaaaaaa-0000-4000-8000-000000000c03';
  pj jsonb; ej jsonb; r jsonb; out text := ''; who record; v text; s uuid; c1 int; c2 int; c3 int; c4 int;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000','authenticated','authenticated', 'r4-' || n || '@example.invalid', '{}', now(), now()
    from (values (P,'p'),(HA,'ha'),(AA,'aa'),(HB,'hb'),(AB,'ab'),(HC,'hc'),(HD,'hd'),(HS,'hs'),(X,'x')) x(u, n);
  insert into public.profiles (id, role, full_name, sport, email_verified_at, age_attestation, attested_at, attested_via, terms_version)
  select u, rl, nm, sp, now(), 'adult', now(), 'signup', '2026-10-03b'
    from (values (P,'pitcher','Pat R4','baseball'),(HA,'coach','HA','baseball'),(AA,'coach','AA','baseball'),(HB,'coach','HB','baseball'),(AB,'coach','AB','baseball'),
                 (HC,'coach','HC','baseball'),(HD,'coach','HD','baseball'),(HS,'coach','HS','softball'),(X,'coach','X','baseball')) x(u, rl, nm, sp);
  insert into public.profiles (id, account_id, role, full_name, sport) values (P2, P, 'pitcher', 'Pat R4 (softball)', 'softball');
  TA := public._create_team_with_head(HA, 'R4 Team A'); TB := public._create_team_with_head(HB, 'R4 Team B');
  TC := public._create_team_with_head(HC, 'R4 Team C'); TD := public._create_team_with_head(HD, 'R4 Team D');
  TS := public._create_team_with_head(HS, 'R4 Softball'); TX := public._create_team_with_head(X, 'R4 Unrelated');
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (TA, AA, 'assistant', HA), (TB, AB, 'assistant', HB);
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (P, TA, now() - interval '30 days'), (P, TB, now() - interval '30 days'),
    (P, TC, now() - interval '30 days'), (P, TD, now() - interval '30 days'), (P2, TS, now() - interval '30 days');

  -- three saved pens, one per recording team (D's while he was still on it)
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  foreach s in array array[SA, SB, SD] loop
    select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)) into pj from generate_series(1, 4);
    r := public.sync_session(jsonb_build_object('id', s, 'pitcher_id', P, 'team_id', case s when SA then TA when SB then TB else TD end,
           'logged_by', P, 'started_at', now() - interval '2 days', 'ended_at', now() - interval '2 days' + interval '30 minutes'), pj, '[]');
  end loop;
  execute 'reset role';
  insert into public.session_notes (session_id, author_id, author_name, body)
    values (SA, HA, 'HA', 'note on A'), (SB, HB, 'HB', 'note on B'), (SD, HD, 'HD', 'note on D');
  update public.teams set archived_at = now(), archived_by = HC where id = TC;   -- TC archived
  delete from public.pitcher_teams where pitcher_id = P and team_id = TD;      -- P left TD

  -- READ matrix: sessions / pitches / notes visible per persona for SA, SB, SD
  out := 'READ (sessions/pitches/notes for SA SB SD):';
  for who in select * from (values ('P',P),('HA',HA),('AA',AA),('HB',HB),('AB',AB),('HC',HC),('HD',HD),('HS',HS),('X',X)) t(n, id) loop
    perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role','authenticated')::text, true); execute 'set local role authenticated';
    v := '';
    foreach s in array array[SA, SB, SD] loop
      select count(*) into c1 from public.sessions where id = s;
      select count(*) into c2 from public.pitches where session_id = s;
      select count(*) into c3 from public.session_notes where session_id = s;
      v := v || ' ' || c1 || '/' || c2 || '/' || c3;
    end loop;
    execute 'reset role';
    out := out || ' | ' || who.n || ':' || v;
  end loop;
  execute 'set local role anon';
  select count(*) into c1 from public.sessions where id in (SA, SB, SD);
  select count(*) into c2 from public.pitches where session_id in (SA, SB, SD);
  execute 'reset role';
  out := out || ' | anon: ' || c1 || '/' || c2;

  -- WRITE matrix on SA and SB: add a note, delete_session (each undone)
  out := out || ' || NOTE INSERT (SA SB):';
  for who in select * from (values ('HA',HA),('AA',AA),('HB',HB),('AB',AB),('HC',HC),('X',X)) t(n, id) loop
    v := '';
    foreach s in array array[SA, SB] loop
      begin
        perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role','authenticated')::text, true); execute 'set local role authenticated';
        insert into public.session_notes (session_id, author_id, author_name, body) values (s, who.id, who.n, 'probe');
        raise exception 'R4UNDO:ok';
      exception when others then
        v := v || ' ' || case when sqlerrm = 'R4UNDO:ok' then 'yes' else 'no' end;
      end;
      execute 'reset role';
    end loop;
    out := out || ' | ' || who.n || ':' || v;
  end loop;
  out := out || ' || DELETE_SESSION (SA SB):';
  for who in select * from (values ('P',P),('HA',HA),('AA',AA),('HB',HB),('AB',AB)) t(n, id) loop
    v := '';
    foreach s in array array[SA, SB] loop
      begin
        perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role','authenticated')::text, true); execute 'set local role authenticated';
        r := public.delete_session(s);
        raise exception 'R4UNDO:%', coalesce(r->>'ok', 'no');
      exception when others then
        v := v || ' ' || case when sqlerrm = 'R4UNDO:true' then 'yes' else 'no' end;
      end;
      execute 'reset role';
    end loop;
    out := out || ' | ' || who.n || ':' || v;
  end loop;
  -- report UPDATE path (report_path write through the caller's client)
  out := out || ' || REPORT_PATH WRITE (SA SB):';
  for who in select * from (values ('P',P),('HA',HA),('HB',HB),('HC',HC)) t(n, id) loop
    v := '';
    foreach s in array array[SA, SB] loop
      begin
        perform set_config('request.jwt.claims', json_build_object('sub', who.id, 'role','authenticated')::text, true); execute 'set local role authenticated';
        update public.sessions set report_path = repeat('ab', 32) || '.html' where id = s;
        get diagnostics c4 = row_count;
        raise exception 'R4UNDO:%', c4;
      exception when others then
        v := v || ' ' || case when sqlerrm = 'R4UNDO:1' then 'yes' else 'no' end;
      end;
      execute 'reset role';
    end loop;
    out := out || ' | ' || who.n || ':' || v;
  end loop;
  out := out || ' || policies: ' || (select count(*) from pg_policies where schemaname = 'public');
  raise exception 'MATRIX(rolled back):%', out;
end $$;
