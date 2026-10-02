do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723'; H uuid := '84c1d3f1-0509-49b2-8b3f-30aae98dcbf3';
  N uuid := 'aaaaaaaa-0000-4000-8000-0000000000d1'; Q uuid := 'aaaaaaaa-0000-4000-8000-0000000000d2';
  out text := ''; c int; hs uuid;
begin
  out := out || ' | staging head login owns ' || (select count(*) from public.profiles where account_id = H) || ' profiles (' || (select string_agg(sport, '+' order by sport) from public.profiles where account_id = H) || ')';
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
    (N, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','invited-pitcher@example.invalid','{}', now(), now()),
    (Q, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','uninvited@example.invalid','{}', now(), now());
  insert into public.profiles (id, role, full_name, sport) values (N, 'pitcher', 'Invited Pitcher', 'baseball'), (Q, 'pitcher', 'Uninvited Pitcher', 'baseball');
  insert into public.invites (team_id, email, invited_by, status) values (T, 'invited-pitcher@example.invalid', H, 'pending');
  -- old email-invite page: invited pitcher adds own membership
  perform set_config('request.jwt.claims', json_build_object('sub', N, 'role','authenticated', 'email', 'invited-pitcher@example.invalid')::text, true); execute 'set local role authenticated';
  insert into public.pitcher_teams (pitcher_id, team_id) values (N, T); get diagnostics c = row_count;
  out := out || ' | invited pitcher (pending invite) joins: ' || c || ' row';
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', Q, 'role','authenticated', 'email', 'uninvited@example.invalid')::text, true); execute 'set local role authenticated';
  begin insert into public.pitcher_teams (pitcher_id, team_id) values (Q, T); out := out || ' | uninvited pitcher joins: ALLOWED (BAD)';
  exception when others then out := out || ' | uninvited pitcher joins: refused'; end;
  execute 'reset role';
  -- the head coach's two-profile login: naming the profile works
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  out := out || ' | head creates team naming its baseball profile: ' || (public.create_team('Named profile team', H) is not null);
  select count(*) into c from public.get_unopened_sessions(T, H); out := out || ' | dots with the profile named: ' || c;
  execute 'reset role';
  raise exception 'RESULTS(rolled back):%', out;
end $$;
