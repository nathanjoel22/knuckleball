-- H1 Part 1 + 3a acceptance (database side). Rolled back. Run on staging as
--   cat supabase/migrations/20261003000000_h1_saved_lock.sql supabase/tests/h1_part1_acceptance.sql > /tmp/x.sql
--   supabase db query --linked --project-ref <staging> -f /tmp/x.sql
-- (or alone once the migration is applied).
do $$
declare
  T  uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights (baseball)
  H  uuid := '84c1d3f1-0509-49b2-8b3f-30aae98dcbf3';   -- its head coach
  P  uuid := 'aaaaaaaa-0000-4000-8000-0000000000d1';   -- rostered pitcher
  A  uuid := 'aaaaaaaa-0000-4000-8000-0000000000d2';   -- assistant coach
  X  uuid := 'aaaaaaaa-0000-4000-8000-0000000000d3';   -- unrelated pitcher
  S1 uuid := gen_random_uuid(); S2 uuid := gen_random_uuid(); S3 uuid := gen_random_uuid(); S4 uuid := gen_random_uuid();
  pj jsonb; ej jsonb; pj5 jsonb; r jsonb; c int; out text := ''; e1 uuid; p1 uuid; v text;
  sess jsonb;
begin
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
    (P, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','h1-p@example.invalid','{}', now(), now()),
    (A, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','h1-a@example.invalid','{}', now(), now()),
    (X, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','h1-x@example.invalid','{}', now(), now());
  insert into public.profiles (id, role, full_name, sport) values
    (P,'pitcher','Pat H1','baseball'), (A,'coach','Asst H1','baseball'), (X,'pitcher','Xavier H1','baseball');
  insert into public.pitcher_teams (pitcher_id, team_id) values (P, T);
  insert into public.team_coaches (team_id, coach_id, role, invited_by) values (T, A, 'assistant', H);

  -- a 130-pitch game with 10 events
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 80 + (i % 8), 'ts', now() + make_interval(secs => i),
         'target_row', null, 'target_col', null, 'actual_row', 1 + (i % 5), 'actual_col', 1 + (i % 4), 'kind', 'game',
         'result', 'ball', 'inning', 1 + (i / 20), 'at_bat_index', i / 4, 'balls_before', 0, 'strikes_before', 0, 'outs_before', 0))
    into pj from generate_series(1, 130) i;
  select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'event_type', 'stolen_base', 'after_pitch_id', pj -> (i * 10) ->> 'id',
         'at_bat_index', i, 'runners_before', 1, 'outs_on_play', 0, 'runs_scored', 0, 'seq', i))
    into ej from generate_series(1, 10) i;
  sess := jsonb_build_object('id', S1, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '2 hours',
          'ended_at', now(), 'kind', 'game', 'opponent', 'Rivals', 'game_final_inning', 7, 'game_outs_recorded', 21);

  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.sync_session(sess, pj, ej);
  out := 'A. 130-pitch game in one call: ' || r::text;
  r := public.sync_session(sess, pj, ej);
  out := out || ' | B. retry: ' || r::text;
  r := public.sync_session(sess, pj || jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'cb', 'velo', 70)), ej);
  out := out || ' | B2. retry with an extra pitch: ' || r::text;
  execute 'reset role';
  out := out || ' | db: pitches=' || (select count(*) from public.pitches where session_id = S1) || ' events=' || (select count(*) from public.game_events where session_id = S1)
         || ' sealed=' || (select sealed_at is not null from public.sessions where id = S1) || ' sport=' || (select sport from public.sessions where id = S1);

  -- 1. direct writes on a saved session's pitch and event, as the owning pitcher
  p1 := (pj -> 0 ->> 'id')::uuid; e1 := (ej -> 0 ->> 'id')::uuid;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  begin update public.pitches set velo = 99 where id = p1; get diagnostics c = row_count; out := out || ' | 1. update saved pitch: ' || c || ' rows';
  exception when others then out := out || ' | 1. update saved pitch: ' || sqlerrm; end;
  begin delete from public.pitches where id = p1; get diagnostics c = row_count; out := out || ', delete saved pitch: ' || c || ' rows';
  exception when others then out := out || ', delete saved pitch: ' || sqlerrm; end;
  begin update public.game_events set runs_scored = 3 where id = e1; get diagnostics c = row_count; out := out || ', update saved event: ' || c || ' rows';
  exception when others then out := out || ', update saved event: ' || sqlerrm; end;
  begin delete from public.game_events where id = e1; get diagnostics c = row_count; out := out || ', delete saved event: ' || c || ' rows';
  exception when others then out := out || ', delete saved event: ' || sqlerrm; end;
  begin insert into public.pitches (id, session_id, type) values (gen_random_uuid(), S1, 'fb'); out := out || ', add pitch to sealed session: ALLOWED (BAD)';
  exception when others then out := out || ', add pitch to sealed session: ' || replace(sqlerrm, '"', ''); end;
  execute 'reset role';
  -- the lock binds every caller, the server's own role included
  begin update public.pitches set velo = 99 where id = p1; out := out || ' | lock as table owner: ALLOWED (BAD)';
  exception when others then out := out || ' | lock as table owner (update pitch): ' || sqlerrm; end;
  begin update public.game_events set runs_scored = 3 where id = e1; out := out || ', (update event): ALLOWED (BAD)';
  exception when others then out := out || ', (update event): ' || sqlerrm; end;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  -- 13. nothing unsaved can be written
  begin insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at) values (S4, P, T, P, now()); out := out || ' | 13. unsaved session insert: ALLOWED (BAD)';
  exception when others then out := out || ' | 13. unsaved session insert: ' || replace(sqlerrm, '"', ''); end;
  r := public.sync_session(jsonb_build_object('id', S4, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now()), '[]', '[]');
  out := out || ', sync_session without ended_at: ' || (r->>'error');

  -- 3. the session row
  begin update public.sessions set ended_at = null where id = S1; out := out || ' | 3. un-save: ALLOWED (BAD)'; exception when others then out := out || ' | 3. un-save: ' || sqlerrm; end;
  begin update public.sessions set pitcher_id = X where id = S1; out := out || ', change pitcher: ALLOWED (BAD)'; exception when others then out := out || ', change pitcher: ' || sqlerrm; end;
  begin update public.sessions set kind = 'bullpen', opponent = null, game_final_inning = null, game_outs_recorded = null where id = S1; out := out || ', change kind: ALLOWED (BAD)'; exception when others then out := out || ', change kind: ' || sqlerrm; end;
  begin update public.sessions set sport = 'softball' where id = S1; out := out || ', change sport: ALLOWED (BAD)'; exception when others then out := out || ', change sport: ' || sqlerrm; end;
  begin update public.sessions set team_id = '0a31f943-009f-4825-8de9-3d2b356c1a5d' where id = S1; out := out || ', change team: ALLOWED (BAD)'; exception when others then out := out || ', change team: ' || sqlerrm; end;
  begin update public.sessions set started_at = started_at - interval '1 day' where id = S1; out := out || ', change start: ALLOWED (BAD)'; exception when others then out := out || ', change start: ' || sqlerrm; end;
  begin update public.sessions set deleted_at = now(), deleted_by = P, deleted_by_role = 'pitcher', pitch_count = 0 where id = S1; out := out || ', fake tombstone: ALLOWED (BAD)'; exception when others then out := out || ', fake tombstone: ' || sqlerrm; end;
  begin update public.sessions set sealed_at = null where id = S1; out := out || ', unseal: ALLOWED (BAD)'; exception when others then out := out || ', unseal: ' || sqlerrm; end;
  update public.sessions set report_path = repeat('ab', 32) || '.html', report_generated_at = now() where id = S1; get diagnostics c = row_count;
  out := out || ', report_path write: ' || c || ' row';
  execute 'reset role';

  -- grace path: a v144 client's queued pen (session upsert, then pitch upsert, then a retry)
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  begin
    insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, ended_at, charting_perspective, kind, opponent, game_final_inning, game_outs_recorded)
    values (S2, P, T, P, now() - interval '1 hour', now(), 'behind_catcher', 'bullpen', null, null, null)
    on conflict (id) do update set pitcher_id = excluded.pitcher_id, team_id = excluded.team_id, logged_by = excluded.logged_by, started_at = excluded.started_at,
      ended_at = excluded.ended_at, charting_perspective = excluded.charting_perspective, kind = excluded.kind, opponent = excluded.opponent,
      game_final_inning = excluded.game_final_inning, game_outs_recorded = excluded.game_outs_recorded;
    select jsonb_agg(jsonb_build_object('id', gen_random_uuid(), 'type', 'fb', 'velo', 82, 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2, 'kind', 'bullpen')) into pj5 from generate_series(1, 5);
    insert into public.pitches (id, session_id, type, velo, target_row, target_col, actual_row, actual_col, kind)
      select (j->>'id')::uuid, S2, j->>'type', (j->>'velo')::int, 2, 2, 2, 2, 'bullpen' from jsonb_array_elements(pj5) j where (j->>'velo') is not null
          and (j->>'id') in (select y->>'id' from jsonb_array_elements(pj5) with ordinality t(y, n) where n <= 3)
      on conflict (id) do update set type = excluded.type, velo = excluded.velo, actual_row = excluded.actual_row, actual_col = excluded.actual_col, kind = excluded.kind;
    out := out || ' | GRACE v144 first sync (3 of 5 pitches, then the connection drops): ' || (select count(*) from public.pitches where session_id = S2) || ' pitches';
  exception when others then out := out || ' | GRACE v144 first sync FAILED: ' || sqlerrm; end;
  begin
    insert into public.pitches (id, session_id, type, velo, target_row, target_col, actual_row, actual_col, kind)
      select (j->>'id')::uuid, S2, j->>'type', (j->>'velo')::int, 2, 2, 2, 2, 'bullpen' from jsonb_array_elements(pj5) j
      on conflict (id) do update set type = excluded.type, velo = excluded.velo, actual_row = excluded.actual_row, actual_col = excluded.actual_col, kind = excluded.kind;
    out := out || ', v144 retry (all 5, upsert): ' || (select count(*) from public.pitches where session_id = S2) || ' pitches';
  exception when others then out := out || ', v144 retry FAILED: ' || sqlerrm; end;
  execute 'reset role';
  -- the same half-done old sync finished by the NEW app instead
  delete from public.pitches where session_id = S2 and id not in (select (y->>'id')::uuid from jsonb_array_elements(pj5) with ordinality t(y, n) where n <= 3);
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.sync_session(jsonb_build_object('id', S2, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '1 hour', 'ended_at', now()), pj5, '[]');
  out := out || ' | half-done old sync finished by sync_session: ' || r::text || ' -> ' || (select count(*) from public.pitches where session_id = S2) || ' pitches, sealed=' || (select sealed_at is not null from public.sessions where id = S2);
  execute 'reset role';

  -- entitlement
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.sync_session(jsonb_build_object('id', S3, 'pitcher_id', P, 'team_id', T, 'logged_by', X, 'started_at', now(), 'ended_at', now()), '[]', '[]');
  out := out || ' | entitlement: other pitcher syncs for P: ' || (r->>'error');
  r := public.sync_session(sess, '[]', '[]'); out := out || ', other pitcher re-sends P''s saved id: ' || (r->>'error');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.sync_session(jsonb_build_object('id', S3, 'pitcher_id', P, 'team_id', T, 'logged_by', H, 'started_at', now(), 'ended_at', now()), '[]', '[]');
  out := out || ', P claims the head coach charted it: ' || (r->>'error');
  begin r := public.sync_session(jsonb_build_object('id', S3, 'pitcher_id', P, 'team_id', '0a31f943-009f-4825-8de9-3d2b356c1a5d', 'logged_by', P, 'started_at', now(), 'ended_at', now()), '[]', '[]');
    out := out || ', P files under a team he''s not on: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  exception when others then out := out || ', P files under a team he''s not on: ' || sqlerrm; end;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.sync_session(jsonb_build_object('id', S3, 'pitcher_id', P, 'team_id', T, 'logged_by', H, 'started_at', now(), 'ended_at', now()), pj5 #- '{0}', '[]');
  out := out || ', head coach charts P''s pen: ' || (r->>'status');
  execute 'reset role';
  execute 'set local role anon';
  begin r := public.sync_session(sess, '[]', '[]'); out := out || ', anon: ALLOWED (BAD)'; exception when others then out := out || ', anon: refused'; end;
  execute 'reset role';

  -- 12 / 2. deletion
  foreach v in array array['P', 'H', 'A'] loop
    perform set_config('request.jwt.claims', json_build_object('sub', case v when 'P' then P when 'H' then H else A end, 'role','authenticated')::text, true);
    execute 'set local role authenticated';
    begin delete from public.sessions where id = S3; get diagnostics c = row_count; out := out || case when v = 'P' then ' | 12. direct DELETE as pitcher: ' else ', as ' || case v when 'H' then 'head coach' else 'assistant' end || ': ' end || c || ' rows';
    exception when others then out := out || ', direct DELETE (' || v || '): ' || sqlerrm; end;
    execute 'reset role';
  end loop;
  perform set_config('request.jwt.claims', json_build_object('sub', A, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.delete_session(S3); out := out || ' | delete_session as assistant: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.delete_session(S3); out := out || ', as head coach: ' || coalesce(r->>'ok', r->>'error');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.delete_session(S1); out := out || ', as pitcher (130-pitch game): ' || coalesce(r->>'ok', r->>'error') || ' events=' || (r->>'event_count');
  execute 'reset role';
  out := out || ' | 2. tombstones: ' || (select string_agg(deleted_by_role || ' pitch_count=' || pitch_count || ' pitches_left=' || (select count(*) from public.pitches p where p.session_id = s.id)
         || ' events_left=' || (select count(*) from public.game_events g where g.session_id = s.id), '; ') from public.sessions s where s.id in (S1, S3));

  -- the after_pitch_id foreign key still clears itself under the lock (as a cascade would)
  r := public.sync_session(jsonb_build_object('id', S4, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now(), 'ended_at', now(), 'kind', 'game'),
       jsonb_build_array(jsonb_build_object('id', p1, 'type', 'fb')), jsonb_build_array(jsonb_build_object('id', e1, 'event_type', 'wild_pitch', 'after_pitch_id', p1)));
  begin delete from public.pitches where id = p1; out := out || ' | FK set-null under the lock: ok, after_pitch_id now ' || coalesce((select after_pitch_id::text from public.game_events where id = e1), 'null');
  exception when others then out := out || ' | FK set-null under the lock: BLOCKED ' || sqlerrm; end;

  -- 13 (3b). report contacts: only the owning login edits them
  update public.profiles set contact_emails = '{"pitcher":"h1-p@example.invalid","coach":"real-coach@example.invalid"}' where id = P;
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  begin update public.profiles set contact_emails = '{"coach":"someone-else@example.invalid"}' where id = P; get diagnostics c = row_count;
    out := out || ' | 13. head coach edits the pitcher''s contacts: ' || c || ' rows';
  exception when others then out := out || ' | 13. head coach edits the pitcher''s contacts: ' || sqlerrm; end;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role','authenticated')::text, true); execute 'set local role authenticated';
  update public.profiles set contact_emails = '{"pitcher":"h1-p@example.invalid","coach":"new-coach@example.invalid"}' where id = P; get diagnostics c = row_count;
  out := out || ', the pitcher edits his own: ' || c || ' row';
  execute 'reset role';
  out := out || ' (stored coach contact: ' || (select contact_emails->>'coach' from public.profiles where id = P) || ')';
  out := out || ' | policies now: ' || (select count(*) from pg_policies where schemaname = 'public');
  raise exception 'RESULTS(rolled back):%', out;
end $$;
