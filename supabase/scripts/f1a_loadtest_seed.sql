-- F1-A load test, part 1 of 2: people (STAGING ONLY). Run after the facility "LoadTest Training Center" was made
-- through facility-signup.html and the test logins (f1a-coach-a/b, f1a-parent-01..12 @example.com) exist.
--   supabase db query --linked --project-ref wpsscxwawgiwmifpjpec -f supabase/scripts/f1a_loadtest_seed.sql
-- Everything goes through the app's own functions, as each person: coaches join with the coach invite link,
-- parents set up, attest, add their players and join them with the pitcher invite link ("Join as:"), and the manager
-- puts pitchers in groups. Groups: coach A 15 (incl. Staging Pitcher, who is also on Staging Knights), coach B 5
-- (incl. Testing Gas), the rest (incl. Babe Ruth) with no coach yet. Three are marked New, as a QR join would.
-- Part 2 (f1a_loadtest_sessions.sql) charts the sessions. Undo: supabase/scripts/f1a_loadtest_cleanup.sql.
do $$
declare
  KNIGHTS constant uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- staging only: refuse anywhere else
  org uuid; fb uuid; mgr uuid; mgr_bb uuid; ca uuid; cb uuid; gA uuid; gB uuid; ptok text; ctok text;
  par record; r jsonb; pl uuid; n int := 0; i int; players uuid[] := '{}';
  sp constant uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- Staging Pitcher (on Staging Knights)
  tg constant uuid := '39191e93-1952-4bc2-9065-f8152df9475d';   -- Testing Gas
  br constant uuid := 'eb70f881-0196-45ad-97db-883d1c45a038';   -- Babe Ruth
begin
  if not exists (select 1 from public.teams where id = KNIGHTS and name = 'Staging Knights') then
    raise exception 'refused: this is not the staging project';
  end if;
  select id, manager_login into org, mgr from public.organizations where name = 'LoadTest Training Center';
  if org is null then raise exception 'make the facility through facility-signup.html first'; end if;
  select id, coach_id, invite_token, coach_invite_token into fb, mgr_bb, ptok, ctok from public.teams where org_id = org and sport = 'baseball';
  select id into ca from auth.users where email = 'f1a-coach-a@example.com';
  select id into cb from auth.users where email = 'f1a-coach-b@example.com';

  -- coaches: attest (18+) and join the baseball side with its coach link, as themselves
  foreach pl in array array[ca, cb] loop
    perform set_config('request.jwt.claims', json_build_object('sub', pl, 'role', 'authenticated')::text, true);
    set local role authenticated;
    perform public.ensure_account_setup('coach', null, null);
    r := public.record_attestation('adult', '2026-10-17', null, 'signup');
    r := public.join_team_as_coach(ctok, null);
    if r ? 'error' then raise exception 'coach join: %', r; end if;
    reset role;
  end loop;

  -- parents: set up, attest, add 9 players each (100 in all), join each with the pitcher link
  for par in select u.id, u.email from auth.users u where u.email like 'f1a-parent-%@example.com' order by u.email loop
    perform set_config('request.jwt.claims', json_build_object('sub', par.id, 'role', 'authenticated')::text, true);
    set local role authenticated;
    perform public.ensure_account_setup('parent', 'LoadTest Parent ' || substr(par.email, 12, 2), null);
    r := public.record_attestation('adult', '2026-10-17', null, 'signup');
    for i in 1..9 loop
      exit when n >= 100;
      n := n + 1;
      r := public.add_player('LoadTest ' || lpad(n::text, 3, '0'), 'baseball', case when n % 4 = 0 then 'L' else 'R' end, true);
      if not coalesce((r ->> 'ok')::boolean, false) then raise exception 'add_player: %', r; end if;
      pl := coalesce((r ->> 'profile_id')::uuid, (r ->> 'id')::uuid, (select id from public.profiles where full_name = 'LoadTest ' || lpad(n::text, 3, '0')));
      r := public.join_team_via_invite(ptok, pl);
      if r ? 'error' then raise exception 'player join: %', r; end if;
      players := players || pl;
    end loop;
    reset role;
  end loop;
  -- every player throws the same four pitches (the charting mix for part 2); joined 200 days ago so every
  -- seeded session falls after the join
  update public.profiles set pitch_types = array['FB','CB','CH','SL'] where id = any(players);
  update public.pitcher_teams set joined_at = now() - interval '200 days' where team_id = fb and pitcher_id = any(players);

  -- three real staging pitchers join too (as postgres: their logins' passwords aren't ours to use)
  insert into public.pitcher_teams (pitcher_id, team_id, joined_at) values (sp, fb, now() - interval '200 days'),
    (tg, fb, now() - interval '200 days'), (br, fb, now() - interval '200 days') on conflict do nothing;

  -- groups, by the manager
  select g.id into gA from public.coach_groups g where g.team_id = fb and g.coach_id = ca;
  select g.id into gB from public.coach_groups g where g.team_id = fb and g.coach_id = cb;
  perform set_config('request.jwt.claims', json_build_object('sub', mgr, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r := public.add_to_group(gA, sp);
  for i in 1..14 loop r := public.add_to_group(gA, players[i]); end loop;
  r := public.add_to_group(gB, tg);
  for i in 15..18 loop r := public.add_to_group(gB, players[i]); end loop;
  reset role;
  update public.coach_group_members set flagged_new = true
   where (group_id = gA and pitcher_id in (players[13], players[14])) or (group_id = gB and pitcher_id = players[18]);

  raise notice 'seeded: % players; group A %, group B %, side %', n,
    (select count(*) from public.coach_group_members where group_id = gA), (select count(*) from public.coach_group_members where group_id = gB),
    (select count(*) from public.pitcher_teams where team_id = fb);
end $$;
select 'side' what, count(*) from public.pitcher_teams pt join public.teams t on t.id = pt.team_id where t.name = 'LoadTest Training Center' and t.sport = 'baseball'
union all select 'group ' || pr.full_name, count(m.*) from public.coach_groups g join public.profiles pr on pr.id = g.coach_id
  join public.teams t on t.id = g.team_id left join public.coach_group_members m on m.group_id = g.id
 where t.name = 'LoadTest Training Center' and t.sport = 'baseball' group by pr.full_name;
