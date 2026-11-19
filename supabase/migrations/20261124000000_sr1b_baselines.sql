-- SR1 Stage B (Joel, Nov 19 2026; plans/sr1-session-reports.md Stage B, decisions in plans/sr1b-preconditions.md):
-- history baselines. For one saved session, the pitcher's own earlier sessions of the same kind (and, for a tagged
-- bullpen, the same tag), pooled per window, from session_stats. Nothing is stored and nothing changes on screen yet:
-- Stage C's report calls this at save time.
--
--  (1) sr1_session_level(session): the level the session's comparisons use -- its team's level, or for an independent
--      session the pitcher's profile level; when unset, the sport's last level (college / high_school_up), as the
--      app's extraInningStart already does. SECURITY DEFINER (a guardian or a teen's own sign-in can't read the
--      teams row), returning null unless the caller may chart for, coach, or follow that pitcher.
--  (2) session_baselines(session): SECURITY INVOKER, so it counts only what the caller can read (R4, F1-A, F1-G), the
--      same reach as pitcher_workload. Windows end before the session starts and never include it:
--        1m / 3m / 12m before it; this season (Nov 15 through high school, Sep 1 college, in Eastern time); a year ago
--        (the 3 months ending a year before it; not for college).
--      Each window: n sessions; pooled values (decision 4) once n >= 3; the 10th / 90th percentile of the per-session
--      values once n >= 5 (decision 6); the same per pitch type (a type's n = sessions that threw it).
--        bullpen: strike % (strikes / pitches), on the spot (hits / pitches), velocity (gunned pitches), pitches.
--        game:    strike % (strikes / the summary's strike-% denominator), first-pitch strike % (first-pitch strikes,
--                 rebuilt exactly from the stored rounded % because a game has under 100 first pitches), in zone
--                 (in_zone / pitches), velocity, pitches (with the +/- adjustment).
-- No table, column or policy changes: public stays 32, storage 12.
-- Rollback: supabase/rollback/20261124000000_sr1b_baselines_down.sql. Test: supabase/tests/sr1b_baselines.sql.

-- (1)
create or replace function public.sr1_session_level(p_session uuid)
returns text
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  s record;
  v_level text;
begin
  select x.pitcher_id, x.team_id, x.sport, x.started_at into s from public.sessions x where x.id = p_session;
  if not found or s.pitcher_id is null then return null; end if;
  if not (public.can_chart_for(s.pitcher_id) or public.coach_sees_pitcher(s.team_id, s.pitcher_id)
          or public.is_linked_to(s.pitcher_id) or public.is_current_coach_of_pitcher(s.pitcher_id, s.started_at)) then
    return null;
  end if;
  if s.team_id is not null then
    select t.level into v_level from public.teams t where t.id = s.team_id;
  else
    select p.level into v_level from public.profiles p where p.id = s.pitcher_id;
  end if;
  return coalesce(v_level, case when s.sport = 'softball' then 'high_school_up' else 'college' end);
end;
$function$;
revoke all on function public.sr1_session_level(uuid) from public, anon;
grant execute on function public.sr1_session_level(uuid) to authenticated;

-- (2)
create or replace function public.session_baselines(p_session uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path to ''
as $function$
declare
  -- Starting values (packet section 2): one place each
  c_min_avg   constant int := 3;      -- sessions needed for an average
  c_min_range constant int := 5;      -- sessions needed for the normal range
  c_lo        constant numeric := 0.1;
  c_hi        constant numeric := 0.9;
  c_tz        constant text := 'America/New_York';
  s record;
  v_level text;
  v_college boolean;
  v_local date;
  v_season date;
  v_wins jsonb := '{}'::jsonb;
  w record;
  v_out jsonb;
begin
  select x.id, x.pitcher_id, x.kind, x.purpose, x.started_at, x.sport into s
    from public.sessions x where x.id = p_session and x.deleted_at is null;
  if not found or s.pitcher_id is null then
    return jsonb_build_object('error', 'not_found');
  end if;
  v_level := public.sr1_session_level(p_session);
  v_college := v_level = 'college';
  v_local := (s.started_at at time zone c_tz)::date;
  -- this season: the latest season start on or before the session's (Eastern) date
  v_season := case when v_college
                   then make_date(extract(year from v_local)::int - case when v_local < make_date(extract(year from v_local)::int, 9, 1) then 1 else 0 end, 9, 1)
                   else make_date(extract(year from v_local)::int - case when v_local < make_date(extract(year from v_local)::int, 11, 15) then 1 else 0 end, 11, 15) end;

  for w in
    select * from (values
      ('1m',       s.started_at - interval '1 month',  s.started_at),
      ('3m',       s.started_at - interval '3 months', s.started_at),
      ('12m',      s.started_at - interval '12 months', s.started_at),
      ('season',   (v_season::timestamp at time zone c_tz), s.started_at),
      ('year_ago', s.started_at - interval '1 year' - interval '3 months', s.started_at - interval '1 year')
    ) v(k, f, t)
    where not (v.k = 'year_ago' and v_college)
  loop
    with st as (   -- the window's sessions the caller can read (RLS), never this one
      select x.* from public.session_stats x
       where x.pitcher_id = s.pitcher_id and x.kind = s.kind and x.session_id <> s.id
         and x.started_at >= w.f and x.started_at < w.t
         and (s.kind <> 'bullpen' or s.purpose is null or x.purpose = s.purpose)
    ),
    per as (       -- one row per session: the pooled parts and the session's own values
      select st.session_id,
             st.pitches,
             st.pitch_count,
             case when st.kind = 'game' then (st.game ->> 'strikes')::numeric else st.strikes end as k_num,
             case when st.kind = 'game' then (st.game ->> 'strike_pct_denominator')::numeric else st.pitches end as k_den,
             st.hits, st.velo_n, st.velo_sum,
             (st.game ->> 'first_pitch_pitches')::numeric as fp_den,
             round((st.game ->> 'first_pitch_strike_pct')::numeric * (st.game ->> 'first_pitch_pitches')::numeric / 100) as fp_num,
             (st.game ->> 'in_zone')::numeric as z_num,
             (st.game ->> 'pitches')::numeric as z_den
        from st
    ),
    agg as (
      select count(*) as n,
             sum(k_num) as k_num, sum(k_den) as k_den, sum(hits) as hits, sum(pitches) as pitches,
             sum(velo_n) as velo_n, sum(velo_sum) as velo_sum, sum(pitch_count) as pitch_count,
             sum(fp_num) as fp_num, sum(fp_den) as fp_den, sum(z_num) as z_num, sum(z_den) as z_den,
             percentile_cont(array[c_lo, c_hi]) within group (order by 100.0 * k_num / nullif(k_den, 0)) filter (where k_den > 0) as r_k,
             percentile_cont(array[c_lo, c_hi]) within group (order by 100.0 * hits / nullif(pitches, 0)) filter (where pitches > 0) as r_spot,
             percentile_cont(array[c_lo, c_hi]) within group (order by velo_sum::numeric / velo_n) filter (where velo_n > 0) as r_velo,
             percentile_cont(array[c_lo, c_hi]) within group (order by pitch_count) as r_pc,
             percentile_cont(array[c_lo, c_hi]) within group (order by 100.0 * fp_num / fp_den) filter (where fp_den > 0) as r_fp,
             percentile_cont(array[c_lo, c_hi]) within group (order by 100.0 * z_num / z_den) filter (where z_den > 0) as r_z
        from per
    ),
    ty as (        -- per pitch type, from by_type
      select t.key as type, st.session_id,
             (t.value ->> 'n')::numeric as pitches,
             (t.value ->> 'strikes')::numeric as k_num,
             case when st.kind = 'game' then (t.value ->> 'pct_n')::numeric else (t.value ->> 'n')::numeric end as k_den,
             (t.value ->> 'hits')::numeric as hits,
             (t.value ->> 'velo_n')::numeric as velo_n, (t.value ->> 'velo_sum')::numeric as velo_sum
        from st, jsonb_each(st.by_type) t
       where t.key <> ''
    ),
    tagg as (
      select type, count(*) as n,
             sum(k_num) as k_num, sum(k_den) as k_den, sum(hits) as hits, sum(pitches) as pitches,
             sum(velo_n) as velo_n, sum(velo_sum) as velo_sum,
             percentile_cont(array[c_lo, c_hi]) within group (order by 100.0 * k_num / nullif(k_den, 0)) filter (where k_den > 0) as r_k,
             percentile_cont(array[c_lo, c_hi]) within group (order by 100.0 * hits / nullif(pitches, 0)) filter (where pitches > 0) as r_spot,
             percentile_cont(array[c_lo, c_hi]) within group (order by velo_sum / velo_n) filter (where velo_n > 0) as r_velo
        from ty group by type
    )
    select jsonb_build_object(
             'from', w.f, 'to', w.t, 'n', a.n,
             'avg', case when a.n >= c_min_avg then jsonb_strip_nulls(jsonb_build_object(
                      'strike_pct', round(100.0 * a.k_num / nullif(a.k_den, 0), 1),
                      'spot_pct', case when s.kind = 'bullpen' then round(100.0 * a.hits / nullif(a.pitches, 0), 1) end,
                      'velo', round(a.velo_sum::numeric / nullif(a.velo_n, 0), 1),
                      'velo_n', a.velo_n,
                      'pitches', round(a.pitch_count::numeric / a.n, 1),
                      'fp_strike_pct', round(100.0 * a.fp_num / nullif(a.fp_den, 0), 1),
                      'in_zone_pct', round(100.0 * a.z_num / nullif(a.z_den, 0), 1))) end,
             'range', case when a.n >= c_min_range then jsonb_strip_nulls(jsonb_build_object(
                      'strike_pct', to_jsonb(array[round(a.r_k[1]::numeric, 1), round(a.r_k[2]::numeric, 1)]),
                      'spot_pct', case when s.kind = 'bullpen' then to_jsonb(array[round(a.r_spot[1]::numeric, 1), round(a.r_spot[2]::numeric, 1)]) end,
                      'velo', case when a.r_velo is not null then to_jsonb(array[round(a.r_velo[1]::numeric, 1), round(a.r_velo[2]::numeric, 1)]) end,
                      'pitches', to_jsonb(array[round(a.r_pc[1]::numeric, 1), round(a.r_pc[2]::numeric, 1)]),
                      'fp_strike_pct', case when a.r_fp is not null then to_jsonb(array[round(a.r_fp[1]::numeric, 1), round(a.r_fp[2]::numeric, 1)]) end,
                      'in_zone_pct', case when a.r_z is not null then to_jsonb(array[round(a.r_z[1]::numeric, 1), round(a.r_z[2]::numeric, 1)]) end)) end,
             'types', coalesce((select jsonb_object_agg(tg.type, jsonb_build_object(
                      'n', tg.n,
                      'avg', case when tg.n >= c_min_avg then jsonb_strip_nulls(jsonb_build_object(
                               'strike_pct', round(100.0 * tg.k_num / nullif(tg.k_den, 0), 1),
                               'spot_pct', case when s.kind = 'bullpen' then round(100.0 * tg.hits / nullif(tg.pitches, 0), 1) end,
                               'velo', round(tg.velo_sum / nullif(tg.velo_n, 0), 1),
                               'velo_n', tg.velo_n,
                               'pitches', round(tg.pitches / tg.n, 1))) end,
                      'range', case when tg.n >= c_min_range then jsonb_strip_nulls(jsonb_build_object(
                               'strike_pct', to_jsonb(array[round(tg.r_k[1]::numeric, 1), round(tg.r_k[2]::numeric, 1)]),
                               'spot_pct', case when s.kind = 'bullpen' then to_jsonb(array[round(tg.r_spot[1]::numeric, 1), round(tg.r_spot[2]::numeric, 1)]) end,
                               'velo', case when tg.r_velo is not null then to_jsonb(array[round(tg.r_velo[1]::numeric, 1), round(tg.r_velo[2]::numeric, 1)]) end)) end))
                      from tagg tg), '{}'::jsonb))
      into v_out
      from agg a;
    v_wins := v_wins || jsonb_build_object(w.k, v_out);
  end loop;

  return jsonb_build_object(
    'session', s.id, 'kind', s.kind, 'purpose', s.purpose, 'level', v_level, 'season_start', v_season,
    'min_avg', c_min_avg, 'min_range', c_min_range, 'windows', v_wins);
end;
$function$;
revoke all on function public.session_baselines(uuid) from public, anon;
grant execute on function public.session_baselines(uuid) to authenticated;
