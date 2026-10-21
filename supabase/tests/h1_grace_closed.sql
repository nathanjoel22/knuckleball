-- H1 grace closed (Oct 21 2026) -- staging; rolled back (the block ends by raising its results).
-- The old app's direct insert is refused for a session, and for pitches into an unsealed session; sync_session still saves.
do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights
  P uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- Staging Pitcher
  G uuid := gen_random_uuid(); S uuid := gen_random_uuid(); r jsonb; out text := '';
begin
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    insert into public.sessions (id, pitcher_id, team_id, logged_by, started_at, ended_at, kind)
      values (G, P, T, P, now() - interval '10 minutes', now() - interval '5 minutes', 'bullpen');
    out := 'old-app session insert=ALLOWED?';
  exception when others then out := 'old-app session insert=refused'; end;
  r := public.sync_session(
    jsonb_build_object('id', S, 'pitcher_id', P, 'team_id', T, 'logged_by', P, 'started_at', now() - interval '9 minutes', 'ended_at', now() - interval '8 minutes', 'kind', 'bullpen'),
    jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'Slider', 'ts', now() - interval '9 minutes', 'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 2)), '[]'::jsonb);
  out := out || format(' | sync_session=%s sealed=%s', r ->> 'status', (select sealed_at is not null from public.sessions where id = S));
  begin
    insert into public.pitches (id, session_id, type, ts, target_row, target_col, actual_row, actual_col)
      values (gen_random_uuid(), S, 'Slider', now(), 2, 2, 2, 2);
    out := out || ' | add a pitch afterwards=ALLOWED?';
  exception when others then out := out || ' | add a pitch afterwards=refused'; end;
  raise exception 'RESULT %', out;
end $$;
