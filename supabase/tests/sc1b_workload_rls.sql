-- SC1-B (staging; read-only, ends by raising its result): as each coach, with RLS on, pitcher_workload (stats v2:
-- summed from session_stats) against the old formula counted from pitches. Expect "0 differ" for every coach.
do $$
declare c record; ids uuid[]; bad int := 0; v_n int := 0; out text := '';
begin
  for c in select distinct pr.account_id uid from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id loop
    perform set_config('request.jwt.claims', json_build_object('sub', c.uid, 'role', 'authenticated')::text, true);
    set local role authenticated;
    select array_agg(distinct pt.pitcher_id) into ids from public.pitcher_teams pt
      where public.is_team_coach(pt.team_id);
    if ids is not null then
      select count(*) into v_n from public.pitcher_workload(ids);
      select count(*) into bad from public.pitcher_workload(ids) w
        join lateral (
          with ss as (select s.id, s.pitcher_id, s.kind, s.started_at,
                        greatest(0, (select count(*) from public.pitches p where p.session_id = s.id) + s.pitch_count_adjust)::int as n
                      from public.sessions s where s.pitcher_id = w.pitcher_id and s.deleted_at is null and s.ended_at is not null)
          select coalesce(sum(n) filter (where kind='bullpen' and started_at > now() - interval '7 days'),0)::int d7b,
                 coalesce(sum(n) filter (where kind='game' and started_at > now() - interval '7 days'),0)::int d7g,
                 coalesce(sum(n) filter (where kind='bullpen' and started_at > now() - interval '30 days'),0)::int d30b,
                 coalesce(sum(n) filter (where kind='game' and started_at > now() - interval '30 days'),0)::int d30g,
                 (select n from ss order by started_at desc limit 1) lastn from ss) o on true
        where (w.d7_bullpen, w.d7_game, w.d30_bullpen, w.d30_game) is distinct from (o.d7b, o.d7g, o.d30b, o.d30g)
           or w.last_pitches is distinct from o.lastn;
      out := out || format(' coach %s: %s pitchers, %s differ;', left(c.uid::text, 8), v_n, bad);
    end if;
    reset role;
  end loop;
  raise exception 'RESULT%', out;
end $$;
