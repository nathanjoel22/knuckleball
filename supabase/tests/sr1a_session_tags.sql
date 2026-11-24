-- SR1 Stage A acceptance (staging; everything rolled back -- the block ends by raising its results).
-- Fixture: one pitcher login P (example.invalid) saves pens and a game through sync_session, as the app's outbox does.
-- Checks are numbered after the packet's acceptance check 5 (each tag stores; Feel Good, once "No tag", = null; a game has none) and the
-- lock and stats copy from plans/sr1a-preconditions.md section 5.
do $$
declare
  P uuid := 'aaaaaaaa-0000-4000-8000-0000000005a1';
  ids uuid[] := array[gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid()];
  sent text[] := array['command', 'velocity', 'short_pen', null, 'warmup', 'command'];   -- 5: unknown; 6: a game
  want text[] := array['command', 'velocity', 'short_pen', null, null, null];
  kinds text[] := array['bullpen', 'bullpen', 'bullpen', 'bullpen', 'bullpen', 'game'];
  i int; r jsonb; got text; st text; err text; out text := ''; fails int := 0; pol0 int; pol1 int;
begin
  select count(*) into pol0 from pg_policies where schemaname = 'public';
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (P, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sr1a-p@example.invalid',
            jsonb_build_object('full_name', 'Pat Pens', 'intended_role', 'pitcher', 'intended_sport', 'baseball'), now(), now());
  insert into public.profiles (id, role, full_name, sport) select P, 'pitcher', 'Pat Pens', 'baseball'
   where not exists (select 1 from public.profiles where id = P);   -- landmine 3

  -- ---------- 5. each tag stores as sent; Feel Good (null), an unknown value and a game store null ----------
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true); set local role authenticated;
  for i in 1 .. 6 loop
    r := public.sync_session(
      jsonb_build_object('id', ids[i], 'pitcher_id', P, 'team_id', null, 'logged_by', P, 'kind', kinds[i],
                         'started_at', now() - interval '1 hour' - i * interval '1 minute', 'ended_at', now() - i * interval '1 minute',
                         'ra_on', false) || case when sent[i] is null then '{}'::jsonb else jsonb_build_object('purpose', sent[i]) end,
      jsonb_build_array(jsonb_build_object('id', gen_random_uuid(), 'type', 'Fastball', 'velo', 80, 'ts', now(),
                         'target_row', 2, 'target_col', 2, 'actual_row', 2, 'actual_col', 3, 'kind', kinds[i],
                         'result', case when kinds[i] = 'game' then 'ball' end,
                         'inning', case when kinds[i] = 'game' then 1 end, 'at_bat_index', case when kinds[i] = 'game' then 0 end,
                         'balls_before', case when kinds[i] = 'game' then 0 end, 'strikes_before', case when kinds[i] = 'game' then 0 end,
                         'outs_before', case when kinds[i] = 'game' then 0 end)),
      '[]'::jsonb);
    select purpose into got from public.sessions where id = ids[i];
    select purpose into st from public.session_stats where session_id = ids[i];
    out := out || ' 5.' || i || ' ' || kinds[i] || ' sent ' || coalesce(sent[i], '(none)') || ' -> ' || coalesce(r ->> 'status', r ->> 'error')
           || ' stored ' || coalesce(got, 'null') || ' stats ' || coalesce(st, 'null');
    if (r ->> 'ok') is distinct from 'true' or got is distinct from want[i] or st is distinct from want[i] then fails := fails + 1; end if;
  end loop;
  -- the column is readable by the pitcher (column grant)
  begin perform purpose from public.sessions where id = ids[1]; err := 'readable'; exception when others then err := sqlerrm; end;
  out := out || ' | grant sessions:' || err; if err <> 'readable' then fails := fails + 1; end if;
  begin perform purpose from public.session_stats where session_id = ids[1]; err := 'readable'; exception when others then err := sqlerrm; end;
  out := out || ' stats:' || err; if err <> 'readable' then fails := fails + 1; end if;
  -- a re-send of a saved pen with another tag changes nothing (already_saved)
  r := public.sync_session(jsonb_build_object('id', ids[1], 'pitcher_id', P, 'team_id', null, 'logged_by', P, 'kind', 'bullpen',
         'started_at', now() - interval '2 hours', 'ended_at', now(), 'purpose', 'velocity'), '[]'::jsonb, '[]'::jsonb);
  select purpose into got from public.sessions where id = ids[1];
  out := out || ' | re-send:' || coalesce(r ->> 'status', r ->> 'error') || ' still ' || got;
  if got <> 'command' then fails := fails + 1; end if;
  reset role;

  -- ---------- the lock: no one changes a saved session's tag, the server's own functions included ----------
  begin update public.sessions set purpose = 'velocity' where id = ids[1]; err := 'changed'; exception when others then err := sqlerrm; end;
  out := out || ' | lock (as owner):' || err; if err <> 'session_saved_locked' then fails := fails + 1; end if;
  begin update public.sessions set purpose = null where id = ids[2]; err := 'changed'; exception when others then err := sqlerrm; end;
  out := out || ' clear:' || err; if err <> 'session_saved_locked' then fails := fails + 1; end if;
  -- the check: never on a game, never off the list
  begin
    insert into public.sessions (id, pitcher_id, logged_by, started_at, kind, purpose) values (gen_random_uuid(), P, P, now(), 'game', 'command');
    err := 'inserted';
  exception when others then err := sqlerrm; end;
  out := out || ' | game with a tag:' || left(err, 60); if err = 'inserted' then fails := fails + 1; end if;
  begin
    insert into public.sessions (id, pitcher_id, logged_by, started_at, kind, purpose) values (gen_random_uuid(), P, P, now(), 'bullpen', 'warmup');
    err := 'inserted';
  exception when others then err := sqlerrm; end;
  out := out || ' unknown tag:' || left(err, 60); if err = 'inserted' then fails := fails + 1; end if;
  -- a recompute keeps the copy
  perform public.finalize_session_stats(ids[3]);
  select purpose into st from public.session_stats where session_id = ids[3];
  out := out || ' | recompute:' || coalesce(st, 'null'); if st is distinct from 'short_pen' then fails := fails + 1; end if;

  select count(*) into pol1 from pg_policies where schemaname = 'public';
  out := out || ' | policies ' || pol0 || '->' || pol1;
  if pol1 <> 32 then fails := fails + 1; end if;
  out := out || ' | hard fails ' || fails;
  raise exception 'SR1A(rolled back):%', out;
end $$;
