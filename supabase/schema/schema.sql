


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."_create_team_with_head"("p_coach_id" "uuid", "p_name" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_team_id uuid;
begin
  insert into public.teams (coach_id, name, coach_invite_token, coach_invite_token_rotated_at)
  values (
    p_coach_id, p_name,
    replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),
    now()
  )
  returning id into v_team_id;

  insert into public.team_coaches (team_id, coach_id, role) values (v_team_id, p_coach_id, 'head');

  return v_team_id;
end;
$$;


ALTER FUNCTION "public"."_create_team_with_head"("p_coach_id" "uuid", "p_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."accuracy_zones_stamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;


ALTER FUNCTION "public"."accuracy_zones_stamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_sport_profile"("p_sport" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_primary public.profiles%rowtype;
  v_new uuid := gen_random_uuid();
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_sport not in ('baseball', 'softball') then
    raise exception 'invalid sport';
  end if;
  select * into v_primary from public.profiles where id = auth.uid();
  if not found or v_primary.role not in ('coach', 'pitcher') then
    raise exception 'no_profile_to_copy';
  end if;
  if exists (select 1 from public.profiles where account_id = auth.uid() and managed_by is null
              and role = v_primary.role and sport = p_sport) then
    raise exception 'already_have_sport';
  end if;
  insert into public.profiles (id, account_id, role, full_name, sport, throws, uses_radar_gun)
  values (v_new, auth.uid(), v_primary.role, v_primary.full_name, p_sport, v_primary.throws, v_primary.uses_radar_gun);
  return v_new;
end;
$$;


ALTER FUNCTION "public"."add_sport_profile"("p_sport" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_view_headshot"("p_object_name" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id::text || '.jpg' = p_object_name
       and public.is_team_coach(pt.team_id)
  );
$$;


ALTER FUNCTION "public"."can_view_headshot"("p_object_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."coach_set_full_name"("p_pitcher_id" "uuid", "p_name" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_head_of_pitcher(p_pitcher_id) then
    raise exception 'not allowed';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'name cannot be blank';
  end if;
  update public.profiles set full_name = btrim(p_name) where id = p_pitcher_id;
end;
$$;


ALTER FUNCTION "public"."coach_set_full_name"("p_pitcher_id" "uuid", "p_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."coach_set_pitch_types"("p_pitcher_id" "uuid", "p_types" "text"[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_head_of_pitcher(p_pitcher_id) then
    raise exception 'not allowed';
  end if;
  if p_types is null or cardinality(p_types) > 20 then
    raise exception 'invalid pitch list';
  end if;
  update public.profiles set pitch_types = p_types where id = p_pitcher_id;
end;
$$;


ALTER FUNCTION "public"."coach_set_pitch_types"("p_pitcher_id" "uuid", "p_types" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."coach_set_relative_accuracy"("p_pitcher_id" "uuid", "p_enabled" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_head_of_pitcher(p_pitcher_id) then
    raise exception 'not allowed';
  end if;
  if p_enabled is null then
    raise exception 'invalid value';
  end if;
  update public.profiles set relative_accuracy_enabled = p_enabled where id = p_pitcher_id;
end;
$$;


ALTER FUNCTION "public"."coach_set_relative_accuracy"("p_pitcher_id" "uuid", "p_enabled" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."coach_set_throws"("p_pitcher_id" "uuid", "p_throws" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_head_of_pitcher(p_pitcher_id) then
    raise exception 'not allowed';
  end if;
  update public.profiles set throws = p_throws where id = p_pitcher_id;
end;
$$;


ALTER FUNCTION "public"."coach_set_throws"("p_pitcher_id" "uuid", "p_throws" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."coach_set_uses_radar_gun"("p_pitcher_id" "uuid", "p_enabled" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_head_of_pitcher(p_pitcher_id) then
    raise exception 'not allowed';
  end if;
  update public.profiles set uses_radar_gun = coalesce(p_enabled, false) where id = p_pitcher_id;
end;
$$;


ALTER FUNCTION "public"."coach_set_uses_radar_gun"("p_pitcher_id" "uuid", "p_enabled" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."compute_game_summary"("p_session_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO ''
    AS $$
declare
  v_kind text;
  v_final_inning smallint;
  v_outs_recorded smallint;
  v_result jsonb;
begin
  select kind, game_final_inning, game_outs_recorded
    into v_kind, v_final_inning, v_outs_recorded
    from public.sessions
   where id = p_session_id;

  if not found then
    return jsonb_build_object('error', 'session not found or not accessible');
  end if;
  if v_kind <> 'game' then
    return jsonb_build_object('error', 'not a game session');
  end if;

  with p as (
    select * from public.pitches where session_id = p_session_id
  ),
  f as (
    select
      *,
      (result in ('strike_looking','strike_swinging','foul','foul_tip','in_play','sac_bunt','sac_fly','dropped_third')) as is_strike_result,
      (result not in ('interference','other')) as counts_toward_pct,
      public.is_strike_cell(actual_row, actual_col) as in_zone,
      (result in ('strike_looking','strike_swinging','foul_tip') and strikes_before >= 2) as is_regular_k_out,
      (result = 'dropped_third' or (result in ('strike_looking','strike_swinging','foul_tip') and strikes_before >= 2)) as is_k,
      (result = 'ball' and balls_before >= 3) as is_bb,
      (result = 'in_play' and in_play_outcome = 'hit') as is_hit,
      (result = 'in_play' and in_play_outcome in ('hit') and hit_type in ('2B','3B','HR')) as is_xbh,
      (result = 'in_play' and in_play_outcome = 'out') as is_inplay_out,
      (result = 'in_play' and in_play_outcome = 'error') as is_error,
      (result = 'hbp') as is_hbp,
      (result in ('sac_bunt','sac_fly')) as is_sac_out,
      (result = 'dropped_third' and in_play_outcome = 'out') as is_dropped_third_out,
      (balls_before = 0 and strikes_before = 0) as is_first_pitch
    from p
  ),
  -- G3: no-pitch events that end an at-bat. Not pitches -- they never touch
  -- pitch count, strike %, zone or first-pitch numbers.
  ev as (
    select at_bat_index,
      (event_type = 'intentional_walk' or (event_type = 'auto_ball' and balls_before >= 3)) as is_bb,
      (event_type = 'auto_strike' and strikes_before >= 2) as is_k
      from public.game_events
     where session_id = p_session_id and event_type in ('intentional_walk','auto_ball','auto_strike')
  ),
  evagg as (
    select count(*) filter (where is_bb) as ev_bb, count(*) filter (where is_k) as ev_k
      from ev
  ),
  bf as (
    select count(distinct ab) as batters_faced from (
      select at_bat_index as ab from f where at_bat_index is not null
      union
      select at_bat_index from ev where (is_bb or is_k) and at_bat_index is not null
    ) x
  ),
  agg as (
    select
      count(*) as pitches,
      count(*) filter (where is_strike_result) as strikes,
      count(*) filter (where counts_toward_pct) as pct_denom,
      count(*) filter (where is_strike_result and counts_toward_pct) as pct_num,
      count(*) filter (where in_zone) as in_zone,
      count(*) filter (where is_first_pitch) as fp_pitches,
      count(*) filter (where is_first_pitch and is_strike_result) as fp_strikes,
      count(*) filter (where is_k) as k,
      count(*) filter (where is_bb) as bb,
      count(*) filter (where is_hit) as h,
      count(*) filter (where is_xbh) as xbh,
      count(*) filter (where is_inplay_out) as outs_in_play,
      count(*) filter (where is_error) as errors,
      count(*) filter (where is_hbp) as hbp,
      count(*) filter (where is_regular_k_out) as regular_k_outs,
      count(*) filter (where is_sac_out) as sac_outs,
      count(*) filter (where is_dropped_third_out) as dropped_third_outs,
      max(inning) as max_inning
    from f
  )
  select jsonb_build_object(
    'pitches', pitches,
    'strikes', strikes,
    'strike_pct', case when pct_denom > 0 then round(100.0 * pct_num / pct_denom) else 0 end,
    'strike_pct_denominator', pct_denom,
    'in_zone', in_zone,
    'in_zone_pct', case when pitches > 0 then round(100.0 * in_zone / pitches) else 0 end,
    'first_pitch_pitches', fp_pitches,
    'first_pitch_strike_pct', case when fp_pitches > 0 then round(100.0 * fp_strikes / fp_pitches) else null end,
    'k', k + ev_k, 'bb', bb + ev_bb, 'h', h, 'xbh', xbh,
    'outs_in_play', outs_in_play, 'errors', errors, 'hbp', hbp,
    'batters_faced', bf.batters_faced,
    'outs_recorded', coalesce(v_outs_recorded, regular_k_outs + ev_k + outs_in_play + sac_outs + dropped_third_outs),
    'outs_source', case when v_outs_recorded is not null then 'counter' else 'derived' end,
    'final_inning', coalesce(v_final_inning, greatest(max_inning, 1)),
    'final_inning_source', case when v_final_inning is not null then 'counter' else 'derived' end
  ) into v_result
  from agg, evagg, bf;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."compute_game_summary"("p_session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_team"("p_name" "text", "p_profile" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_coach uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_profile is not null then
    if not public.is_my_profile(p_profile) then raise exception 'not_your_profile'; end if;
    v_coach := p_profile;
  else
    v_coach := public.my_single_profile();
    if v_coach is null then raise exception 'profile_required'; end if;
  end if;
  if (select pr.role from public.profiles pr where pr.id = v_coach) is distinct from 'coach' then
    raise exception 'only_coaches_create_teams';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'team name cannot be blank';
  end if;
  return public._create_team_with_head(v_coach, btrim(p_name));
end;
$$;


ALTER FUNCTION "public"."create_team"("p_name" "text", "p_profile" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_session"("p_session_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_pitcher     uuid;
  v_team        uuid;
  v_role        text;
  v_by          uuid;
  v_count       integer;
  v_event_count integer;
  v_name        text;
  v_report      text;
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not authenticated');
  end if;

  select pitcher_id, team_id, report_path into v_pitcher, v_team, v_report
  from public.sessions
  where id = p_session_id and deleted_at is null;
  if not found then
    return jsonb_build_object('error', 'session not found or already deleted');
  end if;

  if public.is_my_profile(v_pitcher) then
    v_role := 'pitcher';
    v_by := v_pitcher;
  elsif public.is_team_head(v_team) then
    v_role := 'coach';
    v_by := (select t.coach_id from public.teams t where t.id = v_team);
  else
    return jsonb_build_object('error', 'not entitled to delete this session');
  end if;

  select full_name into v_name from public.profiles where id = v_by;

  select count(*) into v_count from public.pitches where session_id = p_session_id;
  select count(*) into v_event_count from public.game_events where session_id = p_session_id;

  update public.sessions
     set deleted_at      = now(),
         deleted_by      = v_by,
         deleted_by_role = v_role,
         deleted_by_name = v_name,
         pitch_count     = v_count
   where id = p_session_id;

  delete from public.game_events where session_id = p_session_id;
  delete from public.pitches where session_id = p_session_id;

  return jsonb_build_object('ok', true, 'report_path', v_report, 'event_count', v_event_count);
end;
$$;


ALTER FUNCTION "public"."delete_session"("p_session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_account_setup"("p_role" "text" DEFAULT NULL::"text", "p_full_name" "text" DEFAULT NULL::"text", "p_team_name" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid             uuid := auth.uid();
  v_meta            jsonb;
  v_profile_role    text;
  v_resolved_role   text;
  v_resolved_name   text;
  v_resolved_team   text;
  v_has_profile     boolean;
  v_has_team        boolean;
  v_profile_created boolean := false;
  v_team_created    boolean := false;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'not authenticated');
  end if;

  perform pg_advisory_xact_lock(hashtext('ensure_account_setup:' || v_uid::text));

  select raw_user_meta_data into v_meta from auth.users where id = v_uid;

  select role into v_profile_role from public.profiles where id = v_uid;
  v_has_profile := found;

  if not v_has_profile then
    v_resolved_role := coalesce(nullif(p_role, ''), nullif(v_meta ->> 'intended_role', ''));
    v_resolved_name := coalesce(nullif(p_full_name, ''), nullif(v_meta ->> 'full_name', ''));

    if v_resolved_role in ('coach', 'pitcher') and v_resolved_name is not null then
      insert into public.profiles (id, role, full_name)
      values (v_uid, v_resolved_role, v_resolved_name)
      on conflict (id) do nothing;

      select role into v_profile_role from public.profiles where id = v_uid;
      v_has_profile := found;
      v_profile_created := v_has_profile;
    end if;
  end if;

  if not v_has_profile then
    return jsonb_build_object(
      'profile',    'missing',
      'role',       null,
      'needs_role', true
    );
  end if;

  -- ---- Team (coach only) ----
  -- needs_team here still means "no team you HEAD" -- unchanged on purpose.
  -- This branch is what the explicit "create a team" recovery form
  -- (renderAccountSetupScreen / submitAccountSetup) drives: someone
  -- filling that in wants to become a NEW team's head regardless of
  -- whatever else they're already an assistant on, so "you already have
  -- team access" must never short-circuit it. The routing question this
  -- migration actually fixes -- whether an assistant-only coach even
  -- REACHES this recovery screen on a normal load -- is answered by
  -- loadTeams() (client) reading team_coaches instead of teams.coach_id,
  -- not by changing this function's own notion of needs_team.
  if v_profile_role = 'coach' then
    select exists (select 1 from public.teams where coach_id = v_uid) into v_has_team;

    if not v_has_team then
      v_resolved_team := coalesce(nullif(p_team_name, ''), nullif(v_meta ->> 'team_name', ''));
      if v_resolved_team is not null then
        perform public._create_team_with_head(v_uid, v_resolved_team);
        v_has_team     := true;
        v_team_created := true;
      end if;
    end if;

    return jsonb_build_object(
      'profile',    case when v_profile_created then 'created' else 'exists' end,
      'role',       'coach',
      'team',       case when v_team_created then 'created'
                         when v_has_team     then 'exists'
                         else 'missing' end,
      'needs_team', not v_has_team
    );
  end if;

  return jsonb_build_object(
    'profile', case when v_profile_created then 'created' else 'exists' end,
    'role',    'pitcher',
    'team',    'not_applicable'
  );
end;
$$;


ALTER FUNCTION "public"."ensure_account_setup"("p_role" "text", "p_full_name" "text", "p_team_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_email_verify_token"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_token text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');

  update public.profiles
  set email_verify_token = v_token,
      email_verify_token_sent_at = now()
  where id = auth.uid();

  if not found then
    raise exception 'profile not found for current user';
  end if;

  return v_token;
end;
$$;


ALTER FUNCTION "public"."generate_email_verify_token"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_removal_notice_info"("p_pitcher_id" "uuid", "p_team_id" "uuid") RETURNS TABLE("email" "text", "team_name" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;

  if not exists (
    select 1 from public.pitcher_teams
    where pitcher_id = p_pitcher_id and team_id = p_team_id
  ) then
    raise exception 'pitcher is not a member of this team';
  end if;

  return query
    select u.email::text, t.name
    from public.profiles pr
    join auth.users u on u.id = pr.account_id
    cross join public.teams t
    where pr.id = p_pitcher_id and t.id = p_team_id;
end;
$$;


ALTER FUNCTION "public"."get_removal_notice_info"("p_pitcher_id" "uuid", "p_team_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_report_notes"("p_token" "text") RETURNS TABLE("author_name" "text", "body" "text", "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
  select n.author_name, n.body, n.created_at
    from public.sessions s
    join public.session_notes n on n.session_id = s.id
   where p_token ~ '^[0-9a-f]{64}\.html$'
     and s.report_path = p_token
     and s.deleted_at is null
   order by n.created_at;
$_$;


ALTER FUNCTION "public"."get_report_notes"("p_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_roster_latest"("p_team_id" "uuid") RETURNS TABLE("pitcher_id" "uuid", "latest_ended_at" timestamp with time zone)
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select s.pitcher_id, max(s.ended_at)
    from public.sessions s
    join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
   where s.team_id = p_team_id
     and s.deleted_at is null
     and s.ended_at is not null
     and s.started_at >= pt.joined_at
   group by s.pitcher_id;
$$;


ALTER FUNCTION "public"."get_roster_latest"("p_team_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_roster_verification"("p_team_id" "uuid") RETURNS TABLE("pitcher_id" "uuid", "email" "text", "email_confirmed" boolean)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select pt.pitcher_id, u.email, acct.email_verified_at is not null
  from public.pitcher_teams pt
  join public.profiles pr on pr.id = pt.pitcher_id
  join auth.users u on u.id = pr.account_id
  join public.profiles acct on acct.id = pr.account_id
  where pt.team_id = p_team_id
    and public.is_team_coach(p_team_id);
$$;


ALTER FUNCTION "public"."get_roster_verification"("p_team_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_team_invite_links"("p_team_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;

  return (
    select jsonb_build_object(
      'invite_token', invite_token,
      'invite_token_rotated_at', invite_token_rotated_at,
      'coach_invite_token', coach_invite_token,
      'coach_invite_token_rotated_at', coach_invite_token_rotated_at
    )
    from public.teams where id = p_team_id
  );
end;
$$;


ALTER FUNCTION "public"."get_team_invite_links"("p_team_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_team_leaderboard"("p_team_id" "uuid", "p_window" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  c_tz       constant text := 'America/New_York';
  v_is_coach boolean;
  v_min      integer;
  v_start    timestamptz;
  v_end      timestamptz;
  v_result   jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  v_is_coach := public.is_team_coach(p_team_id);
  if not (v_is_coach or public.is_team_member(p_team_id)) then
    raise exception 'not allowed';
  end if;

  if p_window = 'week' then
    v_min   := 10;
    v_start := date_trunc('week', now() at time zone c_tz) at time zone c_tz;
    v_end   := (date_trunc('week', now() at time zone c_tz) + interval '7 days') at time zone c_tz;
  elsif p_window = 'month' then
    v_min   := 25;
    v_start := date_trunc('month', now() at time zone c_tz) at time zone c_tz;
    v_end   := (date_trunc('month', now() at time zone c_tz) + interval '1 month') at time zone c_tz;
  elsif p_window = 'all' then
    v_min := 50;
  else
    raise exception 'invalid window';
  end if;

  if (select t.sport from public.teams t where t.id = p_team_id) = 'softball' then
    return jsonb_build_object(
      'window', p_window, 'minimum', v_min, 'is_coach', v_is_coach, 'generated_at', now(),
      'velocity', '[]'::jsonb, 'accuracy', '[]'::jsonb, 'strike', '[]'::jsonb,
      'disabled', 'softball');
  end if;

  with members as (
    select pt.pitcher_id, pr.full_name, pt.uniform_number
      from public.pitcher_teams pt
      join public.profiles pr on pr.id = pt.pitcher_id
     where pt.team_id = p_team_id
  ),
  pit as (
    select s.pitcher_id, p.id as pitch_id, p.ts, p.velo,
           (p.actual_row between 1 and 3 and p.actual_col between 1 and 3) as is_strike,
           (p.target_row = p.actual_row and p.target_col = p.actual_col)   as is_exact,
           (p.velo is not null
              and not public.is_default_velo_reading(p.velo, p.ts)
              and not exists (select 1 from public.leaderboard_exclusions e
                               where e.pitch_id = p.id and e.team_id = p_team_id)) as velo_ok
      from public.pitches p
      join public.sessions s on s.id = p.session_id
     where s.team_id = p_team_id
       and s.deleted_at is null
       and s.kind = 'bullpen'
       and s.pitcher_id in (select pitcher_id from members)
       and (v_start is null or (p.ts >= v_start and p.ts < v_end))
  ),
  agg as (
    select m.pitcher_id, m.full_name, m.uniform_number,
           count(*)::int as n,
           round(100.0 * count(*) filter (where pit.is_exact)  / count(*))::int as acc,
           round(100.0 * count(*) filter (where pit.is_strike) / count(*))::int as strike
      from members m
      join pit on pit.pitcher_id = m.pitcher_id
     group by m.pitcher_id, m.full_name, m.uniform_number
  ),
  peak as (
    select distinct on (pitcher_id) pitcher_id, pitch_id, ts, velo
      from pit
     where velo_ok
     order by pitcher_id, velo desc, ts asc
  ),
  vel as (
    select a.full_name, a.uniform_number, a.n, a.pitcher_id, k.velo, k.pitch_id, k.ts,
           rank() over (order by k.velo desc) as rk
      from agg a
      join peak k on k.pitcher_id = a.pitcher_id
  ),
  acc as (
    select a.full_name, a.uniform_number, a.n, a.pitcher_id, a.acc as val,
           (a.n >= v_min) as qualified,
           case when a.n >= v_min then rank() over (partition by (a.n >= v_min) order by a.acc desc) end as rk
      from agg a
  ),
  stk as (
    select a.full_name, a.uniform_number, a.n, a.pitcher_id, a.strike as val,
           (a.n >= v_min) as qualified,
           case when a.n >= v_min then rank() over (partition by (a.n >= v_min) order by a.strike desc) end as rk
      from agg a
  )
  select jsonb_strip_nulls(jsonb_build_object(
    'window',       p_window,
    'minimum',      v_min,
    'is_coach',     v_is_coach,
    'window_start', v_start,
    'generated_at', now(),
    'velocity', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', v.rk, 'name', v.full_name, 'number', v.uniform_number,
               'value', v.velo, 'pitch_count', v.n, 'is_me', public.is_my_profile(v.pitcher_id),
               'peak_pitch_id', case when v_is_coach then v.pitch_id end,
               'peak_pitch_ts', case when v_is_coach then v.ts end
             ) order by v.rk, v.full_name)
        from vel v), '[]'::jsonb),
    'accuracy', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', x.rk, 'name', x.full_name, 'number', x.uniform_number,
               'value', x.val, 'pitch_count', x.n, 'qualified', x.qualified,
               'is_me', public.is_my_profile(x.pitcher_id)
             ) order by x.qualified desc, x.rk, x.n desc, x.full_name)
        from acc x), '[]'::jsonb),
    'strike', coalesce((
      select jsonb_agg(jsonb_build_object(
               'rank', x.rk, 'name', x.full_name, 'number', x.uniform_number,
               'value', x.val, 'pitch_count', x.n, 'qualified', x.qualified,
               'is_me', public.is_my_profile(x.pitcher_id)
             ) order by x.qualified desc, x.rk, x.n desc, x.full_name)
        from stk x), '[]'::jsonb),
    'excluded', case when v_is_coach then coalesce((
      select jsonb_agg(jsonb_build_object(
               'pitch_id', e.pitch_id, 'name', pr.full_name, 'value', pi.velo,
               'pitch_ts', pi.ts, 'excluded_at', e.excluded_at
             ) order by e.excluded_at desc)
        from public.leaderboard_exclusions e
        join public.pitches  pi on pi.id = e.pitch_id
        join public.sessions se on se.id = pi.session_id
        join public.profiles pr on pr.id = se.pitcher_id
       where e.team_id = p_team_id), '[]'::jsonb) end
  ))
  into v_result;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."get_team_leaderboard"("p_team_id" "uuid", "p_window" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unopened_sessions"("p_team_id" "uuid", "p_viewer" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("session_id" "uuid", "pitcher_id" "uuid")
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  with v as (
    select case when p_viewer is not null then (case when public.is_my_profile(p_viewer) then p_viewer end)
                else public.my_single_profile() end as viewer
  )
  select s.id, s.pitcher_id
    from v, public.sessions s
    join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
   where v.viewer is not null
     and s.team_id = p_team_id
     and s.deleted_at is null
     and s.ended_at is not null
     and s.started_at >= pt.joined_at
     and s.ended_at > public.session_dots_since()
     and s.ended_at > coalesce(
           (select tc.joined_at from public.team_coaches tc
             where tc.team_id = p_team_id and tc.coach_id = v.viewer),
           '-infinity'::timestamptz)
     and not exists (
       select 1 from public.session_opened o
        where o.viewer_id = v.viewer and o.session_id = s.id
     );
$$;


ALTER FUNCTION "public"."get_unopened_sessions"("p_team_id" "uuid", "p_viewer" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."hand_off_team_head"("p_team_id" "uuid", "p_new_head_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_old uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if not exists (
    select 1 from public.team_coaches
     where team_id = p_team_id and coach_id = p_new_head_id and role = 'assistant'
  ) then
    raise exception 'target must be an existing assistant on this team';
  end if;

  v_old := (select t.coach_id from public.teams t where t.id = p_team_id);
  update public.team_coaches set role = 'assistant' where team_id = p_team_id and coach_id = v_old;
  update public.team_coaches set role = 'head'      where team_id = p_team_id and coach_id = p_new_head_id;
  update public.teams set coach_id = p_new_head_id where id = p_team_id;
end;
$$;


ALTER FUNCTION "public"."hand_off_team_head"("p_team_id" "uuid", "p_new_head_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_role      text := nullif(new.raw_user_meta_data ->> 'intended_role', '');
  v_full_name text := nullif(new.raw_user_meta_data ->> 'full_name', '');
  v_team_name text := nullif(new.raw_user_meta_data ->> 'team_name', '');
begin
  if v_role = 'coach' and v_full_name is not null then
    insert into public.profiles (id, role, full_name)
    values (new.id, 'coach', v_full_name)
    on conflict (id) do nothing;

    -- R6: a coach-invite-link signup deliberately omits team_name (it's
    -- joining an existing team as assistant via join_team_as_coach, not
    -- creating one) -- this branch is unchanged, still skips team creation
    -- whenever team_name is absent, which is exactly what that path needs.
    if v_team_name is not null
       and not exists (select 1 from public.teams where coach_id = new.id) then
      perform public._create_team_with_head(new.id, v_team_name);
    end if;
  end if;

  return new;
exception when others then
  raise warning 'handle_new_user failed for auth user %: %', new.id, sqlerrm;
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."invalidate_my_email_verification"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  update public.profiles
  set email_verified_at = null
  where id = auth.uid();
end;
$$;


ALTER FUNCTION "public"."invalidate_my_email_verification"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_coach_of_pitcher"("p_pitcher_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id = p_pitcher_id and public.is_team_coach(pt.team_id)
  );
$$;


ALTER FUNCTION "public"."is_coach_of_pitcher"("p_pitcher_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_coach_of_session"("p_session_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1
      from public.sessions s
      join public.team_coaches tc on tc.team_id = s.team_id
      join public.profiles cp on cp.id = tc.coach_id and cp.account_id = auth.uid()
      join public.pitcher_teams pt on pt.team_id = s.team_id and pt.pitcher_id = s.pitcher_id
     where s.id = p_session_id
       and s.started_at >= pt.joined_at
  );
$$;


ALTER FUNCTION "public"."is_coach_of_session"("p_session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_coach_of_session_team"("p_session_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.sessions s
      join public.team_coaches tc on tc.team_id = s.team_id
      join public.profiles cp on cp.id = tc.coach_id and cp.account_id = auth.uid()
     where s.id = p_session_id
  );
$$;


ALTER FUNCTION "public"."is_coach_of_session_team"("p_session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_default_velo_reading"("p_velo" integer, "p_ts" timestamp with time zone) RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select p_velo = 65 and p_ts < to_timestamp(1789965601)   -- keep in lockstep with U6_CUTOFF_TS
$$;


ALTER FUNCTION "public"."is_default_velo_reading"("p_velo" integer, "p_ts" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_head_of_pitcher"("p_pitcher_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.pitcher_teams pt
     where pt.pitcher_id = p_pitcher_id and public.is_team_head(pt.team_id)
  );
$$;


ALTER FUNCTION "public"."is_head_of_pitcher"("p_pitcher_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_my_headshot"("p_object_name" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (select 1 from public.profiles pr where pr.id::text || '.jpg' = p_object_name and pr.account_id = auth.uid());
$$;


ALTER FUNCTION "public"."is_my_headshot"("p_object_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_my_profile"("p" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (select 1 from public.profiles pr where pr.id = p and pr.account_id = auth.uid());
$$;


ALTER FUNCTION "public"."is_my_profile"("p" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_pitcher_report_eligible"("p_pitcher_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select
    coalesce((select acct.email_verified_at is not null
                from public.profiles pr join public.profiles acct on acct.id = pr.account_id
               where pr.id = p_pitcher_id), false)
    and exists (select 1 from public.pitcher_teams where pitcher_id = p_pitcher_id);
$$;


ALTER FUNCTION "public"."is_pitcher_report_eligible"("p_pitcher_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_strike_cell"("p_row" integer, "p_col" integer) RETURNS boolean
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select p_row between 1 and 3 and p_col between 1 and 3;
$$;


ALTER FUNCTION "public"."is_strike_cell"("p_row" integer, "p_col" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_team_coach"("check_team_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id
     where tc.team_id = check_team_id and pr.account_id = auth.uid()
  );
$$;


ALTER FUNCTION "public"."is_team_coach"("check_team_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_team_head"("check_team_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.teams t join public.profiles pr on pr.id = t.coach_id
     where t.id = check_team_id and pr.account_id = auth.uid()
  );
$$;


ALTER FUNCTION "public"."is_team_head"("check_team_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_team_member"("check_team_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.pitcher_teams pt join public.profiles pr on pr.id = pt.pitcher_id
     where pt.team_id = check_team_id and pr.account_id = auth.uid()
  );
$$;


ALTER FUNCTION "public"."is_team_member"("check_team_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."join_team_as_coach"("p_token" "text", "p_profile" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_prof uuid;
  v_role text;
  v_team_id uuid;
  v_team_name text;
  v_team_sport text;
  v_head_id uuid;
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not_authenticated');
  end if;

  select id, name, coach_id, sport into v_team_id, v_team_name, v_head_id, v_team_sport
    from public.teams where coach_invite_token = p_token;

  if p_profile is not null then
    if not public.is_my_profile(p_profile) then
      return jsonb_build_object('error', 'not_your_profile');
    end if;
    v_prof := p_profile;
  else
    v_prof := (select pr.id from public.profiles pr
                where pr.account_id = auth.uid() and pr.managed_by is null
                  and pr.role = 'coach' and pr.sport = v_team_sport);
    v_prof := coalesce(v_prof, public.my_single_profile());
    if v_prof is null then
      return jsonb_build_object('error', 'profile_required');
    end if;
  end if;

  select role into v_role from public.profiles where id = v_prof;
  if v_role = 'pitcher' then
    return jsonb_build_object('error', 'pitcher_cannot_join');
  end if;

  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;

  insert into public.team_coaches (team_id, coach_id, role, invited_by)
  values (v_team_id, v_prof, 'assistant', v_head_id)
  on conflict (team_id, coach_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name, 'profile_id', v_prof);
end;
$$;


ALTER FUNCTION "public"."join_team_as_coach"("p_token" "text", "p_profile" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."join_team_via_invite"("p_token" "text", "p_profile" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_prof uuid;
  v_team_id uuid;
  v_team_name text;
  v_team_sport text;
  v_role text;
begin
  if auth.uid() is null then
    return jsonb_build_object('error', 'not_authenticated');
  end if;

  select id, name, sport into v_team_id, v_team_name, v_team_sport from public.teams where invite_token = p_token;

  if p_profile is not null then
    if not public.is_my_profile(p_profile) then
      return jsonb_build_object('error', 'not_your_profile');
    end if;
    v_prof := p_profile;
  else
    v_prof := (select pr.id from public.profiles pr
                where pr.account_id = auth.uid() and pr.managed_by is null
                  and pr.role = 'pitcher' and pr.sport = v_team_sport);
    v_prof := coalesce(v_prof, public.my_single_profile());
    if v_prof is null then
      return jsonb_build_object('error', 'profile_required');
    end if;
  end if;

  select role into v_role from public.profiles where id = v_prof;
  if v_role in ('coach', 'parent') then
    return jsonb_build_object('error', 'coach_cannot_join');
  end if;

  if v_team_id is null then
    return jsonb_build_object('error', 'invalid_token');
  end if;

  insert into public.pitcher_teams (pitcher_id, team_id)
  values (v_prof, v_team_id)
  on conflict (pitcher_id, team_id) do nothing;

  return jsonb_build_object('ok', true, 'team_id', v_team_id, 'team_name', v_team_name, 'profile_id', v_prof);
end;
$$;


ALTER FUNCTION "public"."join_team_via_invite"("p_token" "text", "p_profile" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."leaderboard_exclusions_stamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.excluded_by := auth.uid();
  new.excluded_at := now();
  return new;
end;
$$;


ALTER FUNCTION "public"."leaderboard_exclusions_stamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_single_profile"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select case when count(*) = 1 then (array_agg(pr.id))[1] end
    from public.profiles pr where pr.account_id = auth.uid();
$$;


ALTER FUNCTION "public"."my_single_profile"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_verification_status"() RETURNS TABLE("email" "text", "email_confirmed" boolean)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select u.email, pr.email_verified_at is not null
  from auth.users u
  join public.profiles pr on pr.id = u.id
  where u.id = auth.uid();
$$;


ALTER FUNCTION "public"."my_verification_status"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pitcher_teams_g3_departure"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  insert into public.pitcher_team_departures (pitcher_id, team_id, joined_at)
  values (old.pitcher_id, old.team_id, old.joined_at);
  return old;
end;
$$;


ALTER FUNCTION "public"."pitcher_teams_g3_departure"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."profiles_s4_cap"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if (select count(*) from public.profiles p where p.account_id = coalesce(new.account_id, new.id)) >= 10 then
    raise exception 'profile_limit' using detail = 'A login can hold at most 10 profiles.';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."profiles_s4_cap"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_coach"("p_team_id" "uuid", "p_coach_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if p_coach_id = (select coach_id from public.teams where id = p_team_id) then
    raise exception 'cannot remove the head coach -- hand off the head role first';
  end if;
  delete from public.team_coaches
   where team_id = p_team_id and coach_id = p_coach_id and role = 'assistant';
end;
$$;


ALTER FUNCTION "public"."remove_coach"("p_team_id" "uuid", "p_coach_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rename_team"("p_team_id" "uuid", "p_name" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;
  if p_name is null or btrim(p_name) = '' then
    raise exception 'team name cannot be blank';
  end if;
  update public.teams set name = btrim(p_name) where id = p_team_id;
end;
$$;


ALTER FUNCTION "public"."rename_team"("p_team_id" "uuid", "p_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_coach_invite"("p_token" "text") RETURNS TABLE("team_id" "uuid", "team_name" "text", "team_sport" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select id, name, sport from public.teams where coach_invite_token = p_token;
$$;


ALTER FUNCTION "public"."resolve_coach_invite"("p_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_team_invite"("p_token" "text") RETURNS TABLE("team_id" "uuid", "team_name" "text", "team_sport" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select id, name, sport from public.teams where invite_token = p_token;
$$;


ALTER FUNCTION "public"."resolve_team_invite"("p_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rotate_coach_invite"("p_team_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_new_token text;
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;

  v_new_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  update public.teams
  set coach_invite_token = v_new_token, coach_invite_token_rotated_at = now()
  where id = p_team_id;

  return v_new_token;
end;
$$;


ALTER FUNCTION "public"."rotate_coach_invite"("p_team_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rotate_team_invite"("p_team_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_new_token text;
begin
  if not public.is_team_head(p_team_id) then
    raise exception 'not authorized';
  end if;

  v_new_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  update public.teams
  set invite_token = v_new_token, invite_token_rotated_at = now()
  where id = p_team_id;

  return v_new_token;
end;
$$;


ALTER FUNCTION "public"."rotate_team_invite"("p_team_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."s1_membership_sport"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_member      uuid;
  v_member_sport text;
  v_team_sport  text;
begin
  if tg_table_name = 'pitcher_teams' then
    v_member := new.pitcher_id;
  else
    v_member := new.coach_id;
  end if;
  select t.sport into v_team_sport from public.teams t where t.id = new.team_id;
  select p.sport into v_member_sport from public.profiles p where p.id = v_member;
  if v_team_sport is distinct from v_member_sport then
    raise exception 'sport_mismatch'
      using detail = format('This is a %s team; this account is %s.', coalesce(v_team_sport, 'unknown'), coalesce(v_member_sport, 'unknown'));
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."s1_membership_sport"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."s1_profiles_sport"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_intended text;
begin
  if tg_op = 'INSERT' then
    new.account_id := coalesce(new.account_id, new.id);
    if new.role = 'parent' then
      return new;   -- S4: parents never chart; sport stays null (CHECK)
    end if;
    if new.sport is null then
      select nullif(u.raw_user_meta_data ->> 'intended_sport', '') into v_intended
        from auth.users u where u.id = new.id;
      new.sport := case when v_intended in ('baseball', 'softball') then v_intended else 'baseball' end;
    end if;
    return new;
  end if;
  if new.sport is distinct from old.sport and (
       exists (select 1 from public.sessions s where s.pitcher_id = old.id)
    or exists (select 1 from public.pitcher_teams pt where pt.pitcher_id = old.id)
    or exists (select 1 from public.team_coaches tc where tc.coach_id = old.id)) then
    raise exception 'sport_locked'
      using detail = 'This profile already has sessions or a team, so its sport can''t change.';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."s1_profiles_sport"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."s1_sessions_sport"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_pitcher_sport text;
begin
  if tg_op = 'UPDATE' then
    if new.sport is distinct from old.sport then
      raise exception 'sport_locked' using detail = 'A session''s sport can''t change.';
    end if;
    return new;
  end if;
  select p.sport into v_pitcher_sport from public.profiles p where p.id = new.pitcher_id;
  v_pitcher_sport := coalesce(v_pitcher_sport, 'baseball');
  if new.sport is null then
    new.sport := v_pitcher_sport;
  elsif new.sport <> v_pitcher_sport then
    raise exception 'sport_mismatch'
      using detail = format('This pitcher is %s; a %s session can''t be saved for them.', v_pitcher_sport, new.sport);
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."s1_sessions_sport"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."s1_teams_sport"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_coach_sport text;
begin
  if tg_op = 'INSERT' then
    select p.sport into v_coach_sport from public.profiles p where p.id = new.coach_id;
    v_coach_sport := coalesce(v_coach_sport, 'baseball');
    if new.sport is null then
      new.sport := v_coach_sport;
    elsif new.sport <> v_coach_sport then
      raise exception 'sport_mismatch'
        using detail = format('A %s coach can''t create a %s team.', v_coach_sport, new.sport);
    end if;
    return new;
  end if;
  if new.sport is distinct from old.sport then
    raise exception 'sport_locked' using detail = 'A team''s sport can''t change.';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."s1_teams_sport"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."session_dots_since"() RETURNS timestamp with time zone
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$ select '2026-10-01 01:58:51.610017+00'::timestamptz $$;


ALTER FUNCTION "public"."session_dots_since"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."session_notes_before_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_ended   timestamptz;
  v_deleted timestamptz;
begin
  select s.ended_at, s.deleted_at into v_ended, v_deleted
    from public.sessions s where s.id = new.session_id;
  if not found or v_ended is null then
    raise exception 'Notes can only be added to a saved session' using errcode = 'check_violation';
  end if;
  if v_deleted is not null then
    raise exception 'Notes can''t be added to a deleted session' using errcode = 'check_violation';
  end if;
  new.author_name := coalesce((select p.full_name from public.profiles p where p.id = new.author_id), '');
  new.created_at := now();
  return new;
end;
$$;


ALTER FUNCTION "public"."session_notes_before_insert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."session_notes_redot"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  delete from public.session_opened o
   using public.sessions s
   where s.id = new.session_id
     and o.session_id = new.session_id
     and o.viewer_id = s.pitcher_id;
  return null;
end;
$$;


ALTER FUNCTION "public"."session_notes_redot"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sessions_g3_team_check"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if tg_op = 'UPDATE' then
    if new.team_id is distinct from old.team_id then
      raise exception 'A session''s team can''t be changed' using errcode = 'check_violation';
    end if;
    return new;
  end if;
  if exists (select 1 from public.pitcher_teams pt where pt.pitcher_id = new.pitcher_id and pt.team_id = new.team_id)
     or exists (select 1 from public.pitcher_team_departures d
                 where d.pitcher_id = new.pitcher_id and d.team_id = new.team_id and new.started_at < d.left_at) then
    return new;
  end if;
  raise exception 'This pitcher isn''t on that team' using errcode = 'check_violation';
end;
$$;


ALTER FUNCTION "public"."sessions_g3_team_check"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_my_uniform_number"("p_team_id" "uuid", "p_number" smallint, "p_profile" "uuid" DEFAULT NULL::"uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_prof uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_profile is not null then
    if not public.is_my_profile(p_profile) then raise exception 'not_your_profile'; end if;
    v_prof := p_profile;
  else
    select case when count(*) = 1 then (array_agg(pt.pitcher_id))[1] end into v_prof
      from public.pitcher_teams pt join public.profiles pr on pr.id = pt.pitcher_id
     where pt.team_id = p_team_id and pr.account_id = auth.uid();
  end if;

  update public.pitcher_teams
     set uniform_number = p_number
   where pitcher_id = v_prof
     and team_id = p_team_id;

  if not found then
    raise exception 'not a member of that team';
  end if;
end;
$$;


ALTER FUNCTION "public"."set_my_uniform_number"("p_team_id" "uuid", "p_number" smallint, "p_profile" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_uniform_number"("p_team_id" "uuid", "p_pitcher_id" "uuid", "p_number" smallint, "p_expected" smallint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_current smallint;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if p_number is not null and (p_number < 0 or p_number > 99) then
    raise exception 'uniform number must be between 0 and 99';
  end if;

  if not (public.is_my_profile(p_pitcher_id) or public.is_team_head(p_team_id)) then
    raise exception 'not allowed';
  end if;

  select uniform_number into v_current from public.pitcher_teams
   where team_id = p_team_id and pitcher_id = p_pitcher_id;
  if not found then
    raise exception 'pitcher is not a member of this team';
  end if;
  if v_current is distinct from p_expected then
    return jsonb_build_object('error', 'conflict', 'current', v_current);
  end if;

  if p_number is not null and exists (
    select 1 from public.pitcher_teams
     where team_id = p_team_id and pitcher_id <> p_pitcher_id and uniform_number = p_number
  ) then
    return jsonb_build_object('error', 'taken');
  end if;

  update public.pitcher_teams set uniform_number = p_number
   where team_id = p_team_id and pitcher_id = p_pitcher_id;

  return jsonb_build_object('ok', true);
end;
$$;


ALTER FUNCTION "public"."set_uniform_number"("p_team_id" "uuid", "p_pitcher_id" "uuid", "p_number" smallint, "p_expected" smallint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."teams_level_default"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if new.level is null then
    new.level := case when new.sport = 'softball' then 'high_school_up' else 'college' end;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."teams_level_default"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."teams_set_invite_token"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if new.invite_token is null then
    new.invite_token := replace(gen_random_uuid()::text, '-', '')
                     || replace(gen_random_uuid()::text, '-', '');
    new.invite_token_rotated_at := now();
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."teams_set_invite_token"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verify_email"("p_token" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_id uuid;
begin
  select id into v_id from public.profiles where email_verify_token = p_token;
  if v_id is null then
    return jsonb_build_object('ok', false, 'error', 'invalid_or_used_token');
  end if;

  update public.profiles
  set email_verified_at = now(), email_verify_token = null, email_verify_token_sent_at = null
  where id = v_id;

  return jsonb_build_object('ok', true);
end;
$$;


ALTER FUNCTION "public"."verify_email"("p_token" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."accuracy_zones" (
    "pitcher_id" "uuid" NOT NULL,
    "pitch_type" "text" NOT NULL,
    "batter_side" "text" NOT NULL,
    "cells" "text"[] NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_by" "uuid",
    CONSTRAINT "accuracy_zones_batter_side_check" CHECK (("batter_side" = ANY (ARRAY['R'::"text", 'L'::"text"]))),
    CONSTRAINT "accuracy_zones_cells_check" CHECK (("cardinality"("cells") <= 49))
);


ALTER TABLE "public"."accuracy_zones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."game_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "at_bat_index" smallint,
    "after_pitch_id" "uuid",
    "event_type" "text" NOT NULL,
    "runners_before" smallint,
    "runner_advances" "jsonb",
    "outs_on_play" smallint,
    "runs_scored" smallint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "seq" integer,
    "inning_before" smallint,
    "balls_before" smallint,
    "strikes_before" smallint,
    "outs_before" smallint,
    CONSTRAINT "game_events_event_type_check" CHECK (("event_type" = ANY (ARRAY['stolen_base'::"text", 'caught_stealing'::"text", 'pickoff'::"text", 'wild_pitch'::"text", 'passed_ball'::"text", 'balk'::"text", 'other'::"text", 'intentional_walk'::"text", 'auto_ball'::"text", 'auto_strike'::"text", 'illegal_pitch'::"text", 'tiebreak_runner'::"text"]))),
    CONSTRAINT "game_events_outs_on_play_check" CHECK ((("outs_on_play" >= 0) AND ("outs_on_play" <= 3))),
    CONSTRAINT "game_events_runner_advances_check" CHECK ((("runner_advances" IS NULL) OR ("jsonb_typeof"("runner_advances") = 'array'::"text"))),
    CONSTRAINT "game_events_runners_before_check" CHECK ((("runners_before" >= 0) AND ("runners_before" <= 7))),
    CONSTRAINT "game_events_runs_scored_check" CHECK ((("runs_scored" >= 0) AND ("runs_scored" <= 4)))
);


ALTER TABLE "public"."game_events" OWNER TO "postgres";


COMMENT ON TABLE "public"."game_events" IS 'Runner corrections with no pitch of their own (G1b decision 2): the only way to record a caught-stealing/pickoff out, a stolen base, a wild pitch, a passed ball, or a balk. A correction tool, not a scorebook -- see the packet''s own framing.';



COMMENT ON COLUMN "public"."game_events"."after_pitch_id" IS 'The pitch this event happened after, if any (nullable -- some events, like a mid-count pickoff, have no anchor pitch to point at). Client-generated pitch UUIDs mean this FK is always satisfiable as long as pitches sync before events in the same outbox item (syncOutbox()''s own ordering, not enforced by this FK alone).';



COMMENT ON COLUMN "public"."game_events"."seq" IS 'G3: the event''s place in the game''s one ordered log (shared with pitches.seq in the app). Null on rows saved before G3.';



COMMENT ON COLUMN "public"."game_events"."balls_before" IS 'G3: the count when the event happened -- an auto ball with 3 balls before it is a walk.';



CREATE TABLE IF NOT EXISTS "public"."invites" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "team_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "invited_by" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "invites_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'accepted'::"text"])))
);


ALTER TABLE "public"."invites" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."leaderboard_exclusions" (
    "pitch_id" "uuid" NOT NULL,
    "team_id" "uuid" NOT NULL,
    "excluded_by" "uuid",
    "excluded_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."leaderboard_exclusions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pitcher_team_departures" (
    "pitcher_id" "uuid" NOT NULL,
    "team_id" "uuid" NOT NULL,
    "joined_at" timestamp with time zone,
    "left_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."pitcher_team_departures" OWNER TO "postgres";


COMMENT ON TABLE "public"."pitcher_team_departures" IS 'G3: one row each time a pitcher leaves or is removed from a team (pitcher_teams rows are deleted). Read only by SECURITY DEFINER functions; no client access.';



CREATE TABLE IF NOT EXISTS "public"."pitcher_teams" (
    "pitcher_id" "uuid" NOT NULL,
    "team_id" "uuid" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "uniform_number" smallint,
    CONSTRAINT "pitcher_teams_uniform_number_range" CHECK ((("uniform_number" >= 0) AND ("uniform_number" <= 99)))
);


ALTER TABLE "public"."pitcher_teams" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pitches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "velo" integer,
    "ts" timestamp with time zone DEFAULT "now"() NOT NULL,
    "target_row" integer,
    "target_col" integer,
    "actual_row" integer DEFAULT 0 NOT NULL,
    "actual_col" integer DEFAULT 0 NOT NULL,
    "accuracy_mode" "text",
    "batter_side" "text",
    "in_accuracy_zone" boolean,
    "accuracy_zone_cells" "text"[],
    "kind" "text" DEFAULT 'bullpen'::"text" NOT NULL,
    "result" "text",
    "in_play_outcome" "text",
    "hit_type" "text",
    "fielder" "text",
    "delivery" "text",
    "inning" smallint,
    "outs_before" smallint,
    "balls_before" smallint,
    "strikes_before" smallint,
    "at_bat_index" smallint,
    "bb_type" "text",
    "bb_x" numeric(5,4),
    "bb_y" numeric(5,4),
    "fielders" "text",
    "runners_before" smallint,
    "batter_to" smallint,
    "runner_advances" "jsonb",
    "outs_on_play" smallint,
    "runs_scored" smallint,
    "sacrifice" "text",
    "bb_from_position" boolean,
    "time_to_plate" numeric(4,2),
    CONSTRAINT "pitches_accuracy_mode_check" CHECK ((("accuracy_mode" IS NULL) OR ("accuracy_mode" = ANY (ARRAY['ring'::"text", 'nothingUp'::"text", 'nothingLow'::"text", 'nothingAway'::"text", 'nothingInside'::"text"])))),
    CONSTRAINT "pitches_batter_side_check" CHECK ((("batter_side" IS NULL) OR ("batter_side" = ANY (ARRAY['R'::"text", 'L'::"text"])))),
    CONSTRAINT "pitches_batter_to_check" CHECK ((("batter_to" IS NULL) OR (("batter_to" >= 0) AND ("batter_to" <= 4)))),
    CONSTRAINT "pitches_bb_type_check" CHECK ((("bb_type" IS NULL) OR ("bb_type" = ANY (ARRAY['ground'::"text", 'line'::"text", 'fly'::"text", 'pop'::"text", 'bunt'::"text"])))),
    CONSTRAINT "pitches_delivery_check" CHECK (("delivery" = ANY (ARRAY['set'::"text", 'windup'::"text"]))),
    CONSTRAINT "pitches_fielder_check" CHECK (("fielder" = ANY (ARRAY['P'::"text", 'C'::"text", '1B'::"text", '2B'::"text", '3B'::"text", 'SS'::"text", 'LF'::"text", 'CF'::"text", 'RF'::"text"]))),
    CONSTRAINT "pitches_g1b_fields_check" CHECK (((("kind" = 'bullpen'::"text") AND ("bb_type" IS NULL) AND ("bb_x" IS NULL) AND ("bb_y" IS NULL) AND ("fielders" IS NULL) AND ("runners_before" IS NULL) AND ("batter_to" IS NULL) AND ("runner_advances" IS NULL) AND ("outs_on_play" IS NULL) AND ("runs_scored" IS NULL) AND ("sacrifice" IS NULL) AND ("bb_from_position" IS NULL)) OR ("kind" = 'game'::"text"))),
    CONSTRAINT "pitches_hit_type_check" CHECK (("hit_type" = ANY (ARRAY['1B'::"text", '2B'::"text", '3B'::"text", 'HR'::"text"]))),
    CONSTRAINT "pitches_in_play_outcome_check" CHECK (("in_play_outcome" = ANY (ARRAY['hit'::"text", 'out'::"text", 'error'::"text", 'fc'::"text", 'reached'::"text"]))),
    CONSTRAINT "pitches_kind_check" CHECK (("kind" = ANY (ARRAY['bullpen'::"text", 'game'::"text"]))),
    CONSTRAINT "pitches_outs_on_play_check" CHECK ((("outs_on_play" IS NULL) OR (("outs_on_play" >= 0) AND ("outs_on_play" <= 3)))),
    CONSTRAINT "pitches_result_check" CHECK (("result" = ANY (ARRAY['ball'::"text", 'strike_looking'::"text", 'strike_swinging'::"text", 'foul'::"text", 'in_play'::"text", 'hbp'::"text", 'sac_bunt'::"text", 'sac_fly'::"text", 'dropped_third'::"text", 'interference'::"text", 'other'::"text", 'batter_interference'::"text", 'foul_tip'::"text"]))),
    CONSTRAINT "pitches_runner_advances_is_array" CHECK ((("runner_advances" IS NULL) OR ("jsonb_typeof"("runner_advances") = 'array'::"text"))),
    CONSTRAINT "pitches_runners_before_check" CHECK ((("runners_before" IS NULL) OR (("runners_before" >= 0) AND ("runners_before" <= 7)))),
    CONSTRAINT "pitches_runs_scored_check" CHECK ((("runs_scored" IS NULL) OR (("runs_scored" >= 0) AND ("runs_scored" <= 4)))),
    CONSTRAINT "pitches_sacrifice_check" CHECK ((("sacrifice" IS NULL) OR ("sacrifice" = ANY (ARRAY['SF'::"text", 'SAC'::"text"])))),
    CONSTRAINT "pitches_target_matches_kind" CHECK (((("kind" = 'bullpen'::"text") AND ("target_row" IS NOT NULL) AND ("target_col" IS NOT NULL)) OR (("kind" = 'game'::"text") AND ("target_row" IS NULL) AND ("target_col" IS NULL)))),
    CONSTRAINT "pitches_time_to_plate_check" CHECK ((("time_to_plate" IS NULL) OR (("time_to_plate" >= 0.80) AND ("time_to_plate" <= 3.00))))
);


ALTER TABLE "public"."pitches" OWNER TO "postgres";


COMMENT ON COLUMN "public"."pitches"."kind" IS 'G1: copied from the parent session''s kind at insert time (a session''s
   kind never changes, and pitches are immutable after save, so this never
   drifts from it). Denormalized specifically so pitches_target_matches_kind
   can be a real CHECK constraint instead of a trigger -- a CHECK can only
   see its own row.';



COMMENT ON COLUMN "public"."pitches"."bb_type" IS 'Batted-ball type for an in-play result: ground/line/fly/pop/bunt. NULL for every non-in-play pitch and every bullpen pitch.';



COMMENT ON COLUMN "public"."pitches"."bb_x" IS 'Normalized batted-ball location, x axis. Home plate origin: bb_x=0.5 is the center line, 0/1 are the field diagram''s left/right edges (docs/field-diagram.svg). May be outside [0,1] if ever tapped past the diagram''s own bounds -- not clamped, not invented.';



COMMENT ON COLUMN "public"."pitches"."bb_y" IS 'Normalized batted-ball location, y axis. 0 = home plate, 1 = the center-field fence (docs/field-diagram.svg''s own coordinate convention, documented in that file). Can exceed 1 -- a home run lands past the fence, and this is a real recorded location, not an error.';



COMMENT ON COLUMN "public"."pitches"."fielders" IS 'Optional fielder SEQUENCE for a play with more than one touch, e.g. "6-4-3" -- distinct from the existing, unchanged `fielder` column (the single first fielder, required for an out/error, G1). NULL when only one fielder is relevant or none was recorded.';



COMMENT ON COLUMN "public"."pitches"."runners_before" IS 'Bitmask of occupied bases immediately before this pitch: 1st=1, 2nd=2, 3rd=4 (0-7). Written on EVERY game pitch from this migration forward, not only in-play ones -- makes every pitch row self-contained the same way outs_before/balls_before/strikes_before already are, and is what Undo restores from.';



COMMENT ON COLUMN "public"."pitches"."batter_to" IS 'Where the BATTER ended on this play: 0 = out, 1/2/3 = that base, 4 = scored. NULL for anything that isn''t an in-play result.';



COMMENT ON COLUMN "public"."pitches"."runner_advances" IS 'Array of {"from": <1|2|3>, "to": <0|1|2|3|4>} for every RUNNER (not the batter -- see batter_to) who moved on this play. 0 = out, 4 = scored. NULL when there were no runners on base to move.';



COMMENT ON COLUMN "public"."pitches"."outs_on_play" IS 'Total outs recorded on this single play (0-3) -- comes from where the runners (and batter) ended, per decision 8, never from a separate counter. A double play is 2 here, something the old single-result-implies-one-out model could never represent.';



COMMENT ON COLUMN "public"."pitches"."runs_scored" IS 'Runs that scored on this single play (0-4) -- a runner or the batter tapped to Home. Earned/unearned is out of scope; this is just runs allowed.';



COMMENT ON COLUMN "public"."pitches"."sacrifice" IS 'SF or SAC, DERIVED after the fact from the play (fly + batter out + a run scored = SF; bunt + batter out + a runner advanced = SAC) -- never tapped directly. NULL for everything else, including a play that happens to look like one but doesn''t meet the definition. The pre-G1b path of tapping "Sac bunt"/"Sac fly" as a RESULT directly is retired (see pitches_result_check, unchanged, which still allows those two result values only because existing rows already carry them).';



COMMENT ON COLUMN "public"."pitches"."bb_from_position" IS 'True when bb_x/bb_y are the tapped fielding position''s own anchor coordinate (G1b-r decision 5), not a precise tap. Every in-play/E/FC row in this build has this true -- precise tap-to-locate is a deferred refinement. NULL for every non-in-play pitch and every bullpen pitch.';



COMMENT ON COLUMN "public"."pitches"."time_to_plate" IS 'U11 (7): time to home from the stretch, in seconds (first move to the catcher''s glove), stopwatch-timed by the charter on this pitch. NULL = not timed. 0.80-3.00 only.';



CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "full_name" "text" NOT NULL,
    "pitch_types" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "contact_emails" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "email_verify_token" "text",
    "email_verify_token_sent_at" timestamp with time zone,
    "email_verified_at" timestamp with time zone,
    "throws" "text",
    "relative_accuracy_enabled" boolean DEFAULT false NOT NULL,
    "uses_radar_gun" boolean DEFAULT true NOT NULL,
    "setup_dismissed_at" timestamp with time zone,
    "headshot_updated_at" timestamp with time zone,
    "sport" "text",
    "account_id" "uuid" NOT NULL,
    "managed_by" "uuid",
    "is_primary" boolean GENERATED ALWAYS AS (("id" = "account_id")) STORED,
    CONSTRAINT "profiles_full_name_not_blank" CHECK (("btrim"("full_name") <> ''::"text")),
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['coach'::"text", 'pitcher'::"text", 'parent'::"text"]))),
    CONSTRAINT "profiles_sport_check" CHECK (((("role" = 'parent'::"text") AND ("sport" IS NULL)) OR (("role" <> 'parent'::"text") AND ("sport" = ANY (ARRAY['baseball'::"text", 'softball'::"text"]))))),
    CONSTRAINT "profiles_throws_check" CHECK (("throws" = ANY (ARRAY['L'::"text", 'R'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."email_verify_token" IS 'CSPRNG token (64 hex chars: two gen_random_uuid() calls, dashes stripped,
   concatenated -- pgcrypto/gen_random_bytes is not enabled on this project,
   same approach as teams.invite_token). Set by generate_email_verify_token(),
   cleared the moment verify_email() succeeds -- null the rest of the time.
   Regenerating overwrites it, invalidating any link already sent.';



COMMENT ON COLUMN "public"."profiles"."email_verify_token_sent_at" IS 'When email_verify_token was last (re)generated. Set alongside the token, always.';



COMMENT ON COLUMN "public"."profiles"."email_verified_at" IS 'When this profile''s account email was verified through OUR OWN flow.
   Never read auth.users.email_confirmed_at as a substitute for this --
   that column means something different (whether Supabase itself gated
   sign-in on confirmation) and is meaningless once "Confirm email" is off,
   since Supabase stamps it for everyone at signup in that configuration.';



COMMENT ON COLUMN "public"."profiles"."uses_radar_gun" IS 'The PITCHER''s own preference (U9): whether the velocity strip appears at
   all on the charting page, for whoever charts them. Default true since U10
   (Sept 29 2026): Yes unless the player -- or a head coach editing his
   profile -- has chosen No. Changing it never affects an already-open
   session -- the client snapshots this value onto the session/draft object
   at creation and resume (see sessionUsesRadarGun() in bullpen-tracker.html),
   never re-reading it live mid-pen even from the same device.';



COMMENT ON COLUMN "public"."profiles"."setup_dismissed_at" IS 'When this pitcher completed or explicitly skipped ("Set this up later")
   the post-signup setup page -- NULL means show it once, automatically, on
   next load. Backfilled to now() for every profile that existed before U9
   shipped, so no existing user is suddenly redirected to a page they never
   asked for; they still see the ongoing incomplete-profile reminder banner
   if applicable, which is derived live and does not depend on this column.';



COMMENT ON COLUMN "public"."profiles"."headshot_updated_at" IS 'U10 (8): when the player last uploaded his headshot (storage bucket headshots, object {id}.jpg); NULL = no photo. Written only by the player himself.';



COMMENT ON COLUMN "public"."profiles"."sport" IS 'S1: baseball | softball. One sport per profile, ever (S3 adds a second profile, never a second sport). Set at signup from intended_sport; locked once the profile has a session or a team.';



COMMENT ON COLUMN "public"."profiles"."account_id" IS 'S1 (for S3): the login that owns this profile. = id for every profile until S3 adds child / second-sport profiles.';



COMMENT ON COLUMN "public"."profiles"."managed_by" IS 'S4: set on a player profile created by a parent (Stage B); null for a login''s own profiles.';



COMMENT ON COLUMN "public"."profiles"."is_primary" IS 'S4: true for the login''s own first profile (id = account_id), which holds email verification and, in Stage B, attestation.';



CREATE TABLE IF NOT EXISTS "public"."roster_seen" (
    "viewer_id" "uuid" NOT NULL,
    "pitcher_id" "uuid" NOT NULL,
    "seen_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."roster_seen" OWNER TO "postgres";


COMMENT ON TABLE "public"."roster_seen" IS 'U10 (3) revised: when each viewer (coach or the pitcher himself) last had this pitcher''s History on screen. The red dot shows when the pitcher''s latest session ended after seen_at, or there is no row. Own rows only (RLS).';



CREATE TABLE IF NOT EXISTS "public"."session_notes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "author_id" "uuid" NOT NULL,
    "author_name" "text" DEFAULT ''::"text" NOT NULL,
    "body" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "session_notes_body_check" CHECK ((("char_length"("body") >= 1) AND ("char_length"("body") <= 2000)))
);


ALTER TABLE "public"."session_notes" OWNER TO "postgres";


COMMENT ON TABLE "public"."session_notes" IS 'S3: a coach''s plain-text note on a saved session. Never edited; the author may delete it. Read by the pitcher and his current coaches (RLS), and shown live on the session''s report page via get_report_notes.';



CREATE TABLE IF NOT EXISTS "public"."session_opened" (
    "viewer_id" "uuid" NOT NULL,
    "session_id" "uuid" NOT NULL,
    "opened_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."session_opened" OWNER TO "postgres";


COMMENT ON TABLE "public"."session_opened" IS 'U10 (3): which sessions each viewer (coach or the pitcher himself) has tapped open in History. A session saved after launch with no row here for the viewer shows a red dot. Own rows only (RLS).';



CREATE TABLE IF NOT EXISTS "public"."sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pitcher_id" "uuid" NOT NULL,
    "team_id" "uuid" NOT NULL,
    "started_at" timestamp with time zone NOT NULL,
    "ended_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "logged_by" "uuid" NOT NULL,
    "deleted_at" timestamp with time zone,
    "deleted_by" "uuid",
    "deleted_by_role" "text",
    "pitch_count" integer,
    "charting_perspective" "text" DEFAULT 'behind_catcher'::"text" NOT NULL,
    "report_path" "text",
    "report_generated_at" timestamp with time zone,
    "kind" "text" DEFAULT 'bullpen'::"text" NOT NULL,
    "deleted_by_name" "text",
    "opponent" "text",
    "game_final_inning" smallint,
    "game_outs_recorded" smallint,
    "sport" "text" NOT NULL,
    CONSTRAINT "sessions_charting_perspective_check" CHECK (("charting_perspective" = ANY (ARRAY['behind_catcher'::"text", 'behind_pitcher'::"text"]))),
    CONSTRAINT "sessions_deletion_check" CHECK ((("deleted_at" IS NULL) OR (("deleted_by" IS NOT NULL) AND ("deleted_by_role" = ANY (ARRAY['pitcher'::"text", 'coach'::"text"])) AND ("pitch_count" IS NOT NULL) AND ("pitch_count" >= 0)))),
    CONSTRAINT "sessions_game_fields_check" CHECK (((("kind" = 'bullpen'::"text") AND ("opponent" IS NULL) AND ("game_final_inning" IS NULL) AND ("game_outs_recorded" IS NULL)) OR ("kind" = 'game'::"text"))),
    CONSTRAINT "sessions_kind_check" CHECK (("kind" = ANY (ARRAY['bullpen'::"text", 'game'::"text"]))),
    CONSTRAINT "sessions_opponent_length" CHECK ((("opponent" IS NULL) OR ("char_length"("opponent") <= 60))),
    CONSTRAINT "sessions_sport_check" CHECK (("sport" = ANY (ARRAY['baseball'::"text", 'softball'::"text"])))
);


ALTER TABLE "public"."sessions" OWNER TO "postgres";


COMMENT ON COLUMN "public"."sessions"."pitch_count" IS 'Pitch-count snapshot taken at soft-delete time; NULL for live sessions (count them from public.pitches).';



COMMENT ON COLUMN "public"."sessions"."report_path" IS 'Object name (not a full URL) of this session''s frozen HTML report in the reports bucket. NULL until first generated. Never regenerated once set -- reused for every re-send. Lets a future session-deletion feature delete the report object (not implemented here).';



COMMENT ON COLUMN "public"."sessions"."report_generated_at" IS 'When report_path was first set. NULL until then.';



COMMENT ON COLUMN "public"."sessions"."kind" IS 'G1: which mode this whole session was charted in. Fixed at creation
   (the chooser runs before the first pitch, before charting_perspective
   is even asked), never changed after. Every existing row is a bullpen.
   Games are kept separate everywhere that computes accuracy/command/zone
   results and never feed the team leaderboard -- see the G1 precondition
   report for the exact list of call sites.';



COMMENT ON COLUMN "public"."sessions"."deleted_by_name" IS 'Snapshot of profiles.full_name for deleted_by, taken at soft-delete time by delete_session(). NULL for live sessions and for any session deleted before this column existed.';



COMMENT ON COLUMN "public"."sessions"."opponent" IS 'Optional, free text, editable up to save. NULL renders as "Game · <date>"; set renders as "vs <opponent> · <date>". NULL for every bullpen.';



COMMENT ON COLUMN "public"."sessions"."game_final_inning" IS 'The tracker''s own inning counter at save time (G2). NULL for a bullpen, and NULL for a game saved before this column existed -- the renderer falls back to max(pitches.inning) for those and labels it "outs from pitches", never invents.';



COMMENT ON COLUMN "public"."sessions"."game_outs_recorded" IS 'The tracker''s own outs counter at save time (G2) -- this is the reason it exists: a caught-stealing out (gameBumpOuts()) advances this with no pitch row behind it at all, so it cannot be recovered from pitches after the fact. NULL for a bullpen and for a pre-G2 game (same pitch-derived fallback as game_final_inning).';



COMMENT ON COLUMN "public"."sessions"."sport" IS 'S1: the pitcher''s sport, set by trigger; never from the client.';



CREATE TABLE IF NOT EXISTS "public"."team_coaches" (
    "team_id" "uuid" NOT NULL,
    "coach_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "invited_by" "uuid",
    CONSTRAINT "team_coaches_role_check" CHECK (("role" = ANY (ARRAY['head'::"text", 'assistant'::"text"])))
);


ALTER TABLE "public"."team_coaches" OWNER TO "postgres";


COMMENT ON TABLE "public"."team_coaches" IS 'R6: a coach''s relationship to a team is a membership with a role, not a
   property of the account -- one coach account can be head of one team and
   assistant on another. Exactly one head row per team (partial unique index
   below). Writes only ever happen through the SECURITY DEFINER functions in
   this migration (create_team, join_team_as_coach, hand_off_team_head,
   remove_coach) -- there is deliberately no INSERT/UPDATE/DELETE policy, so
   a direct client write is refused by RLS regardless of role.';



CREATE TABLE IF NOT EXISTS "public"."teams" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "coach_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "invite_token" "text" NOT NULL,
    "invite_token_rotated_at" timestamp with time zone,
    "coach_invite_token" "text" NOT NULL,
    "coach_invite_token_rotated_at" timestamp with time zone,
    "sport" "text" NOT NULL,
    "level" "text" NOT NULL,
    CONSTRAINT "teams_level_check" CHECK (((("sport" = 'baseball'::"text") AND ("level" = ANY (ARRAY['little_league'::"text", 'high_school'::"text", 'college'::"text"]))) OR (("sport" = 'softball'::"text") AND ("level" = ANY (ARRAY['little_league'::"text", 'high_school_up'::"text"]))))),
    CONSTRAINT "teams_sport_check" CHECK (("sport" = ANY (ARRAY['baseball'::"text", 'softball'::"text"])))
);


ALTER TABLE "public"."teams" OWNER TO "postgres";


COMMENT ON COLUMN "public"."teams"."invite_token" IS 'CSPRNG token (64 hex chars: two gen_random_uuid() calls, dashes stripped,
   concatenated -- pgcrypto/gen_random_bytes is not enabled on this project,
   confirmed while writing this migration, so this avoids that dependency
   entirely; gen_random_uuid() is core Postgres, no extension needed) for the
   shareable join link. Regenerating (rotate_team_invite) overwrites it,
   instantly invalidating the old link. Never derived from team id/name/timestamp.';



COMMENT ON COLUMN "public"."teams"."invite_token_rotated_at" IS 'When invite_token was last (re)generated. Set alongside invite_token, always.';



COMMENT ON COLUMN "public"."teams"."coach_invite_token" IS 'R6: same shape/trust model as invite_token (R0) -- CSPRNG, the token IS
   the credential, rotating invalidates the old link instantly. A separate
   token (not the pitcher one) because resolving it must reject a pitcher
   and land the visitor on the coach signup/accept path instead.';



COMMENT ON COLUMN "public"."teams"."sport" IS 'S1: the creating coach''s sport; never changes. Members must match (sport_mismatch).';



COMMENT ON COLUMN "public"."teams"."level" IS 'G3: level of play, set by the head coach. Decides the first extra inning (baseball LL 7 / HS 8 / college 10; softball LL 7 / HS & up 8).';



ALTER TABLE ONLY "public"."accuracy_zones"
    ADD CONSTRAINT "accuracy_zones_pkey" PRIMARY KEY ("pitcher_id", "pitch_type", "batter_side");



ALTER TABLE ONLY "public"."game_events"
    ADD CONSTRAINT "game_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invites"
    ADD CONSTRAINT "invites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."leaderboard_exclusions"
    ADD CONSTRAINT "leaderboard_exclusions_pkey" PRIMARY KEY ("pitch_id", "team_id");



ALTER TABLE ONLY "public"."pitcher_teams"
    ADD CONSTRAINT "pitcher_teams_pkey" PRIMARY KEY ("pitcher_id", "team_id");



ALTER TABLE ONLY "public"."pitches"
    ADD CONSTRAINT "pitches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_email_verify_token_key" UNIQUE ("email_verify_token");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."roster_seen"
    ADD CONSTRAINT "roster_seen_pkey" PRIMARY KEY ("viewer_id", "pitcher_id");



ALTER TABLE ONLY "public"."session_notes"
    ADD CONSTRAINT "session_notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."session_opened"
    ADD CONSTRAINT "session_opened_pkey" PRIMARY KEY ("viewer_id", "session_id");



ALTER TABLE ONLY "public"."sessions"
    ADD CONSTRAINT "sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_coaches"
    ADD CONSTRAINT "team_coaches_pkey" PRIMARY KEY ("team_id", "coach_id");



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_coach_invite_token_key" UNIQUE ("coach_invite_token");



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_invite_token_key" UNIQUE ("invite_token");



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_pkey" PRIMARY KEY ("id");



CREATE INDEX "pitcher_team_departures_idx" ON "public"."pitcher_team_departures" USING "btree" ("pitcher_id", "team_id");



CREATE INDEX "profiles_account_id_idx" ON "public"."profiles" USING "btree" ("account_id");



CREATE UNIQUE INDEX "profiles_one_per_sport_role" ON "public"."profiles" USING "btree" ("account_id", "sport", "role") WHERE ("managed_by" IS NULL);



CREATE INDEX "session_notes_session_id_idx" ON "public"."session_notes" USING "btree" ("session_id");



CREATE UNIQUE INDEX "team_coaches_one_head_per_team" ON "public"."team_coaches" USING "btree" ("team_id") WHERE ("role" = 'head'::"text");



CREATE OR REPLACE TRIGGER "accuracy_zones_stamp" BEFORE INSERT OR UPDATE ON "public"."accuracy_zones" FOR EACH ROW EXECUTE FUNCTION "public"."accuracy_zones_stamp"();



CREATE OR REPLACE TRIGGER "leaderboard_exclusions_stamp" BEFORE INSERT ON "public"."leaderboard_exclusions" FOR EACH ROW EXECUTE FUNCTION "public"."leaderboard_exclusions_stamp"();



CREATE OR REPLACE TRIGGER "pitcher_teams_g3_departure" AFTER DELETE ON "public"."pitcher_teams" FOR EACH ROW EXECUTE FUNCTION "public"."pitcher_teams_g3_departure"();



CREATE OR REPLACE TRIGGER "pitcher_teams_s1_sport" BEFORE INSERT OR UPDATE ON "public"."pitcher_teams" FOR EACH ROW EXECUTE FUNCTION "public"."s1_membership_sport"();



CREATE OR REPLACE TRIGGER "profiles_s1_sport" BEFORE INSERT OR UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."s1_profiles_sport"();



CREATE OR REPLACE TRIGGER "profiles_s4_cap" BEFORE INSERT ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."profiles_s4_cap"();



CREATE OR REPLACE TRIGGER "session_notes_before_insert" BEFORE INSERT ON "public"."session_notes" FOR EACH ROW EXECUTE FUNCTION "public"."session_notes_before_insert"();



CREATE OR REPLACE TRIGGER "session_notes_redot" AFTER INSERT ON "public"."session_notes" FOR EACH ROW EXECUTE FUNCTION "public"."session_notes_redot"();



CREATE OR REPLACE TRIGGER "sessions_g3_team_check" BEFORE INSERT OR UPDATE OF "team_id" ON "public"."sessions" FOR EACH ROW EXECUTE FUNCTION "public"."sessions_g3_team_check"();



CREATE OR REPLACE TRIGGER "sessions_s1_sport" BEFORE INSERT OR UPDATE ON "public"."sessions" FOR EACH ROW EXECUTE FUNCTION "public"."s1_sessions_sport"();



CREATE OR REPLACE TRIGGER "team_coaches_s1_sport" BEFORE INSERT OR UPDATE ON "public"."team_coaches" FOR EACH ROW EXECUTE FUNCTION "public"."s1_membership_sport"();



CREATE OR REPLACE TRIGGER "teams_s1_sport" BEFORE INSERT OR UPDATE ON "public"."teams" FOR EACH ROW EXECUTE FUNCTION "public"."s1_teams_sport"();



CREATE OR REPLACE TRIGGER "teams_set_invite_token" BEFORE INSERT ON "public"."teams" FOR EACH ROW EXECUTE FUNCTION "public"."teams_set_invite_token"();



CREATE OR REPLACE TRIGGER "teams_z_level" BEFORE INSERT ON "public"."teams" FOR EACH ROW EXECUTE FUNCTION "public"."teams_level_default"();



ALTER TABLE ONLY "public"."accuracy_zones"
    ADD CONSTRAINT "accuracy_zones_pitcher_id_fkey" FOREIGN KEY ("pitcher_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."accuracy_zones"
    ADD CONSTRAINT "accuracy_zones_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."game_events"
    ADD CONSTRAINT "game_events_after_pitch_id_fkey" FOREIGN KEY ("after_pitch_id") REFERENCES "public"."pitches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."game_events"
    ADD CONSTRAINT "game_events_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."invites"
    ADD CONSTRAINT "invites_invited_by_fkey" FOREIGN KEY ("invited_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."invites"
    ADD CONSTRAINT "invites_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."leaderboard_exclusions"
    ADD CONSTRAINT "leaderboard_exclusions_excluded_by_fkey" FOREIGN KEY ("excluded_by") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."leaderboard_exclusions"
    ADD CONSTRAINT "leaderboard_exclusions_pitch_id_fkey" FOREIGN KEY ("pitch_id") REFERENCES "public"."pitches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."leaderboard_exclusions"
    ADD CONSTRAINT "leaderboard_exclusions_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pitcher_team_departures"
    ADD CONSTRAINT "pitcher_team_departures_pitcher_id_fkey" FOREIGN KEY ("pitcher_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pitcher_team_departures"
    ADD CONSTRAINT "pitcher_team_departures_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pitcher_teams"
    ADD CONSTRAINT "pitcher_teams_pitcher_id_fkey" FOREIGN KEY ("pitcher_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pitcher_teams"
    ADD CONSTRAINT "pitcher_teams_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pitches"
    ADD CONSTRAINT "pitches_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_managed_by_fkey" FOREIGN KEY ("managed_by") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."roster_seen"
    ADD CONSTRAINT "roster_seen_pitcher_id_fkey" FOREIGN KEY ("pitcher_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."roster_seen"
    ADD CONSTRAINT "roster_seen_viewer_id_fkey" FOREIGN KEY ("viewer_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."session_notes"
    ADD CONSTRAINT "session_notes_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."session_notes"
    ADD CONSTRAINT "session_notes_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."session_opened"
    ADD CONSTRAINT "session_opened_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."session_opened"
    ADD CONSTRAINT "session_opened_viewer_id_fkey" FOREIGN KEY ("viewer_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sessions"
    ADD CONSTRAINT "sessions_deleted_by_fkey" FOREIGN KEY ("deleted_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."sessions"
    ADD CONSTRAINT "sessions_logged_by_fkey" FOREIGN KEY ("logged_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."sessions"
    ADD CONSTRAINT "sessions_pitcher_id_fkey" FOREIGN KEY ("pitcher_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sessions"
    ADD CONSTRAINT "sessions_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_coaches"
    ADD CONSTRAINT "team_coaches_coach_id_fkey" FOREIGN KEY ("coach_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_coaches"
    ADD CONSTRAINT "team_coaches_invited_by_fkey" FOREIGN KEY ("invited_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."team_coaches"
    ADD CONSTRAINT "team_coaches_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_coach_id_fkey" FOREIGN KEY ("coach_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



CREATE POLICY "Authors delete their own notes" ON "public"."session_notes" FOR DELETE USING ("public"."is_my_profile"("author_id"));



CREATE POLICY "Coach manages leaderboard exclusions for own team" ON "public"."leaderboard_exclusions" USING ("public"."is_team_head"("team_id")) WITH CHECK ("public"."is_team_head"("team_id"));



CREATE POLICY "Coaches add notes to their pitchers' sessions" ON "public"."session_notes" FOR INSERT WITH CHECK (("public"."is_my_profile"("author_id") AND "public"."is_coach_of_session"("session_id")));



CREATE POLICY "Coaches manage events for their team's sessions" ON "public"."game_events" USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "game_events"."session_id") AND "public"."is_team_coach"("s"."team_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "game_events"."session_id") AND "public"."is_team_coach"("s"."team_id")))));



CREATE POLICY "Coaches manage own team invites" ON "public"."invites" USING ((EXISTS ( SELECT 1
   FROM "public"."teams" "t"
  WHERE (("t"."id" = "invites"."team_id") AND "public"."is_my_profile"("t"."coach_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."teams" "t"
  WHERE (("t"."id" = "invites"."team_id") AND "public"."is_my_profile"("t"."coach_id")))));



CREATE POLICY "Coaches manage own teams" ON "public"."teams" USING ("public"."is_team_head"("id")) WITH CHECK ("public"."is_team_head"("id"));



CREATE POLICY "Coaches manage pitches for their team's sessions" ON "public"."pitches" USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND "public"."is_team_coach"("s"."team_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND "public"."is_team_coach"("s"."team_id")))));



CREATE POLICY "Coaches manage sessions for their team" ON "public"."sessions" USING ("public"."is_team_coach"("team_id")) WITH CHECK ("public"."is_team_coach"("team_id"));



CREATE POLICY "Coaches remove pitchers from their team" ON "public"."pitcher_teams" FOR DELETE USING ("public"."is_team_head"("team_id"));



CREATE POLICY "Coaches view events for their team's sessions" ON "public"."game_events" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "game_events"."session_id") AND "public"."is_team_coach"("s"."team_id")))));



CREATE POLICY "Coaches view memberships for their teams" ON "public"."pitcher_teams" FOR SELECT USING ("public"."is_team_coach"("team_id"));



CREATE POLICY "Coaches view pitches for their team's sessions" ON "public"."pitches" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND "public"."is_team_coach"("s"."team_id")))));



CREATE POLICY "Coaches view sessions logged under their team" ON "public"."sessions" FOR SELECT USING ("public"."is_team_coach"("team_id"));



CREATE POLICY "Coaches view teams they belong to as staff" ON "public"."teams" FOR SELECT USING ("public"."is_team_coach"("id"));



CREATE POLICY "Coaches view their fellow coaches' profiles" ON "public"."profiles" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."team_coaches" "tc"
  WHERE (("tc"."coach_id" = "profiles"."id") AND "public"."is_team_coach"("tc"."team_id")))));



CREATE POLICY "Coaches view their pitchers' profiles" ON "public"."profiles" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."pitcher_teams" "pt"
  WHERE (("pt"."pitcher_id" = "profiles"."id") AND "public"."is_team_coach"("pt"."team_id")))));



CREATE POLICY "Coaches view their teams' coaching staff" ON "public"."team_coaches" FOR SELECT USING ("public"."is_team_coach"("team_id"));



CREATE POLICY "Invited person marks their invite accepted" ON "public"."invites" FOR UPDATE USING (("email" = ("auth"."jwt"() ->> 'email'::"text"))) WITH CHECK (("email" = ("auth"."jwt"() ->> 'email'::"text")));



CREATE POLICY "Invited person views invite addressed to their email" ON "public"."invites" FOR SELECT USING (("email" = ("auth"."jwt"() ->> 'email'::"text")));



CREATE POLICY "Notes readable by author, pitcher and his team's coaches" ON "public"."session_notes" FOR SELECT USING (("public"."is_my_profile"("author_id") OR (EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "session_notes"."session_id") AND "public"."is_my_profile"("s"."pitcher_id")))) OR "public"."is_coach_of_session_team"("session_id")));



CREATE POLICY "Pitcher or their coach manages zones" ON "public"."accuracy_zones" USING (("public"."is_my_profile"("pitcher_id") OR "public"."is_coach_of_pitcher"("pitcher_id"))) WITH CHECK (("public"."is_my_profile"("pitcher_id") OR "public"."is_coach_of_pitcher"("pitcher_id")));



CREATE POLICY "Pitchers accept invite by inserting own membership" ON "public"."pitcher_teams" FOR INSERT WITH CHECK (("public"."is_my_profile"("pitcher_id") AND (EXISTS ( SELECT 1
   FROM "public"."profiles" "pr"
  WHERE (("pr"."id" = "pitcher_teams"."pitcher_id") AND ("pr"."role" = 'pitcher'::"text")))) AND (EXISTS ( SELECT 1
   FROM "public"."invites" "i"
  WHERE (("i"."team_id" = "pitcher_teams"."team_id") AND ("i"."status" = 'pending'::"text") AND ("lower"("i"."email") = "lower"(("auth"."jwt"() ->> 'email'::"text"))))))));



CREATE POLICY "Pitchers manage events in own sessions" ON "public"."game_events" USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "game_events"."session_id") AND "public"."is_my_profile"("s"."pitcher_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "game_events"."session_id") AND "public"."is_my_profile"("s"."pitcher_id")))));



CREATE POLICY "Pitchers manage own sessions" ON "public"."sessions" USING ("public"."is_my_profile"("pitcher_id")) WITH CHECK ("public"."is_my_profile"("pitcher_id"));



CREATE POLICY "Pitchers manage pitches in own sessions" ON "public"."pitches" USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND "public"."is_my_profile"("s"."pitcher_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND "public"."is_my_profile"("s"."pitcher_id")))));



CREATE POLICY "Pitchers view own memberships" ON "public"."pitcher_teams" FOR SELECT USING ("public"."is_my_profile"("pitcher_id"));



CREATE POLICY "Pitchers view teams they belong to" ON "public"."teams" FOR SELECT USING ("public"."is_team_member"("id"));



CREATE POLICY "Users insert own profile" ON "public"."profiles" FOR INSERT WITH CHECK (("id" = "auth"."uid"()));



CREATE POLICY "Users update own profile" ON "public"."profiles" FOR UPDATE USING (("account_id" = "auth"."uid"()));



CREATE POLICY "Users view own profile" ON "public"."profiles" FOR SELECT USING (("account_id" = "auth"."uid"()));



CREATE POLICY "Viewers insert own roster-seen rows" ON "public"."roster_seen" FOR INSERT WITH CHECK ("public"."is_my_profile"("viewer_id"));



CREATE POLICY "Viewers insert own session-opened rows" ON "public"."session_opened" FOR INSERT WITH CHECK ("public"."is_my_profile"("viewer_id"));



CREATE POLICY "Viewers read own roster-seen rows" ON "public"."roster_seen" FOR SELECT USING ("public"."is_my_profile"("viewer_id"));



CREATE POLICY "Viewers read own session-opened rows" ON "public"."session_opened" FOR SELECT USING ("public"."is_my_profile"("viewer_id"));



CREATE POLICY "Viewers update own roster-seen rows" ON "public"."roster_seen" FOR UPDATE USING ("public"."is_my_profile"("viewer_id")) WITH CHECK ("public"."is_my_profile"("viewer_id"));



ALTER TABLE "public"."accuracy_zones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."game_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."invites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."leaderboard_exclusions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pitcher_team_departures" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pitcher_teams" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pitches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."roster_seen" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."session_notes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."session_opened" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."team_coaches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."teams" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



REVOKE ALL ON FUNCTION "public"."_create_team_with_head"("p_coach_id" "uuid", "p_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."_create_team_with_head"("p_coach_id" "uuid", "p_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."accuracy_zones_stamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."accuracy_zones_stamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."accuracy_zones_stamp"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."add_sport_profile"("p_sport" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."add_sport_profile"("p_sport" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_sport_profile"("p_sport" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_view_headshot"("p_object_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_view_headshot"("p_object_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_view_headshot"("p_object_name" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."coach_set_full_name"("p_pitcher_id" "uuid", "p_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."coach_set_full_name"("p_pitcher_id" "uuid", "p_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."coach_set_full_name"("p_pitcher_id" "uuid", "p_name" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."coach_set_pitch_types"("p_pitcher_id" "uuid", "p_types" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."coach_set_pitch_types"("p_pitcher_id" "uuid", "p_types" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."coach_set_pitch_types"("p_pitcher_id" "uuid", "p_types" "text"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."coach_set_relative_accuracy"("p_pitcher_id" "uuid", "p_enabled" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."coach_set_relative_accuracy"("p_pitcher_id" "uuid", "p_enabled" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."coach_set_relative_accuracy"("p_pitcher_id" "uuid", "p_enabled" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."coach_set_throws"("p_pitcher_id" "uuid", "p_throws" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."coach_set_throws"("p_pitcher_id" "uuid", "p_throws" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."coach_set_throws"("p_pitcher_id" "uuid", "p_throws" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."coach_set_uses_radar_gun"("p_pitcher_id" "uuid", "p_enabled" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."coach_set_uses_radar_gun"("p_pitcher_id" "uuid", "p_enabled" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."coach_set_uses_radar_gun"("p_pitcher_id" "uuid", "p_enabled" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."compute_game_summary"("p_session_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."compute_game_summary"("p_session_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."compute_game_summary"("p_session_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_team"("p_name" "text", "p_profile" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_team"("p_name" "text", "p_profile" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_team"("p_name" "text", "p_profile" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_session"("p_session_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_session"("p_session_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_session"("p_session_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."ensure_account_setup"("p_role" "text", "p_full_name" "text", "p_team_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ensure_account_setup"("p_role" "text", "p_full_name" "text", "p_team_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ensure_account_setup"("p_role" "text", "p_full_name" "text", "p_team_name" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."generate_email_verify_token"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."generate_email_verify_token"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_email_verify_token"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_removal_notice_info"("p_pitcher_id" "uuid", "p_team_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_removal_notice_info"("p_pitcher_id" "uuid", "p_team_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_removal_notice_info"("p_pitcher_id" "uuid", "p_team_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_report_notes"("p_token" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_report_notes"("p_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_report_notes"("p_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_report_notes"("p_token" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_roster_latest"("p_team_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_roster_latest"("p_team_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_roster_latest"("p_team_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_roster_verification"("p_team_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_roster_verification"("p_team_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_roster_verification"("p_team_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_team_invite_links"("p_team_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_team_invite_links"("p_team_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_team_invite_links"("p_team_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_team_leaderboard"("p_team_id" "uuid", "p_window" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_team_leaderboard"("p_team_id" "uuid", "p_window" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_team_leaderboard"("p_team_id" "uuid", "p_window" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_unopened_sessions"("p_team_id" "uuid", "p_viewer" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_unopened_sessions"("p_team_id" "uuid", "p_viewer" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unopened_sessions"("p_team_id" "uuid", "p_viewer" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."hand_off_team_head"("p_team_id" "uuid", "p_new_head_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."hand_off_team_head"("p_team_id" "uuid", "p_new_head_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."hand_off_team_head"("p_team_id" "uuid", "p_new_head_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."invalidate_my_email_verification"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."invalidate_my_email_verification"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."invalidate_my_email_verification"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_coach_of_pitcher"("p_pitcher_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_coach_of_pitcher"("p_pitcher_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_coach_of_pitcher"("p_pitcher_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_coach_of_session"("p_session_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_coach_of_session"("p_session_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_coach_of_session"("p_session_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_coach_of_session_team"("p_session_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_coach_of_session_team"("p_session_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_coach_of_session_team"("p_session_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_default_velo_reading"("p_velo" integer, "p_ts" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."is_default_velo_reading"("p_velo" integer, "p_ts" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_default_velo_reading"("p_velo" integer, "p_ts" timestamp with time zone) TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_head_of_pitcher"("p_pitcher_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_head_of_pitcher"("p_pitcher_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_head_of_pitcher"("p_pitcher_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_my_headshot"("p_object_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_my_headshot"("p_object_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."is_my_headshot"("p_object_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_my_headshot"("p_object_name" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_my_profile"("p" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_my_profile"("p" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_my_profile"("p" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_my_profile"("p" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_pitcher_report_eligible"("p_pitcher_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_pitcher_report_eligible"("p_pitcher_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_pitcher_report_eligible"("p_pitcher_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_strike_cell"("p_row" integer, "p_col" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_strike_cell"("p_row" integer, "p_col" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_strike_cell"("p_row" integer, "p_col" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."is_team_coach"("check_team_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_team_coach"("check_team_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_team_coach"("check_team_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_team_head"("check_team_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_team_head"("check_team_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_team_head"("check_team_id" "uuid") TO "service_role";
GRANT ALL ON FUNCTION "public"."is_team_head"("check_team_id" "uuid") TO "anon";



GRANT ALL ON FUNCTION "public"."is_team_member"("check_team_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_team_member"("check_team_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_team_member"("check_team_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."join_team_as_coach"("p_token" "text", "p_profile" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."join_team_as_coach"("p_token" "text", "p_profile" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_team_as_coach"("p_token" "text", "p_profile" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."join_team_via_invite"("p_token" "text", "p_profile" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."join_team_via_invite"("p_token" "text", "p_profile" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."join_team_via_invite"("p_token" "text", "p_profile" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."leaderboard_exclusions_stamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."leaderboard_exclusions_stamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."leaderboard_exclusions_stamp"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_single_profile"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_single_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_single_profile"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_verification_status"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_verification_status"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_verification_status"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."pitcher_teams_g3_departure"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pitcher_teams_g3_departure"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."profiles_s4_cap"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."profiles_s4_cap"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."remove_coach"("p_team_id" "uuid", "p_coach_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."remove_coach"("p_team_id" "uuid", "p_coach_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_coach"("p_team_id" "uuid", "p_coach_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rename_team"("p_team_id" "uuid", "p_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rename_team"("p_team_id" "uuid", "p_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rename_team"("p_team_id" "uuid", "p_name" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."resolve_coach_invite"("p_token" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."resolve_coach_invite"("p_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_coach_invite"("p_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_coach_invite"("p_token" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."resolve_team_invite"("p_token" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."resolve_team_invite"("p_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."resolve_team_invite"("p_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resolve_team_invite"("p_token" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rotate_coach_invite"("p_team_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rotate_coach_invite"("p_team_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rotate_coach_invite"("p_team_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."rotate_team_invite"("p_team_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."rotate_team_invite"("p_team_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."rotate_team_invite"("p_team_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."s1_membership_sport"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."s1_membership_sport"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."s1_profiles_sport"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."s1_profiles_sport"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."s1_sessions_sport"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."s1_sessions_sport"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."s1_teams_sport"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."s1_teams_sport"() TO "service_role";



GRANT ALL ON FUNCTION "public"."session_dots_since"() TO "anon";
GRANT ALL ON FUNCTION "public"."session_dots_since"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."session_dots_since"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."session_notes_before_insert"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."session_notes_before_insert"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."session_notes_redot"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."session_notes_redot"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."sessions_g3_team_check"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sessions_g3_team_check"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_my_uniform_number"("p_team_id" "uuid", "p_number" smallint, "p_profile" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_my_uniform_number"("p_team_id" "uuid", "p_number" smallint, "p_profile" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_my_uniform_number"("p_team_id" "uuid", "p_number" smallint, "p_profile" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_uniform_number"("p_team_id" "uuid", "p_pitcher_id" "uuid", "p_number" smallint, "p_expected" smallint) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_uniform_number"("p_team_id" "uuid", "p_pitcher_id" "uuid", "p_number" smallint, "p_expected" smallint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_uniform_number"("p_team_id" "uuid", "p_pitcher_id" "uuid", "p_number" smallint, "p_expected" smallint) TO "service_role";



REVOKE ALL ON FUNCTION "public"."teams_level_default"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."teams_level_default"() TO "service_role";



GRANT ALL ON FUNCTION "public"."teams_set_invite_token"() TO "anon";
GRANT ALL ON FUNCTION "public"."teams_set_invite_token"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."teams_set_invite_token"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."verify_email"("p_token" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."verify_email"("p_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."verify_email"("p_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."verify_email"("p_token" "text") TO "service_role";



GRANT ALL ON TABLE "public"."accuracy_zones" TO "authenticated";
GRANT ALL ON TABLE "public"."accuracy_zones" TO "service_role";



GRANT ALL ON TABLE "public"."game_events" TO "anon";
GRANT ALL ON TABLE "public"."game_events" TO "authenticated";
GRANT ALL ON TABLE "public"."game_events" TO "service_role";



GRANT ALL ON TABLE "public"."invites" TO "anon";
GRANT ALL ON TABLE "public"."invites" TO "authenticated";
GRANT ALL ON TABLE "public"."invites" TO "service_role";



GRANT ALL ON TABLE "public"."leaderboard_exclusions" TO "authenticated";
GRANT ALL ON TABLE "public"."leaderboard_exclusions" TO "service_role";



GRANT ALL ON TABLE "public"."pitcher_team_departures" TO "service_role";



GRANT ALL ON TABLE "public"."pitcher_teams" TO "anon";
GRANT ALL ON TABLE "public"."pitcher_teams" TO "authenticated";
GRANT ALL ON TABLE "public"."pitcher_teams" TO "service_role";



GRANT ALL ON TABLE "public"."pitches" TO "anon";
GRANT ALL ON TABLE "public"."pitches" TO "authenticated";
GRANT ALL ON TABLE "public"."pitches" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "anon";
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT UPDATE("full_name") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("pitch_types") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("contact_emails") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("throws") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("relative_accuracy_enabled") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("uses_radar_gun") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("setup_dismissed_at") ON TABLE "public"."profiles" TO "authenticated";



GRANT UPDATE("headshot_updated_at") ON TABLE "public"."profiles" TO "authenticated";



GRANT ALL ON TABLE "public"."roster_seen" TO "authenticated";
GRANT ALL ON TABLE "public"."roster_seen" TO "service_role";



GRANT ALL ON TABLE "public"."session_notes" TO "service_role";
GRANT SELECT,INSERT,DELETE ON TABLE "public"."session_notes" TO "authenticated";



GRANT ALL ON TABLE "public"."session_opened" TO "authenticated";
GRANT ALL ON TABLE "public"."session_opened" TO "service_role";



GRANT ALL ON TABLE "public"."sessions" TO "anon";
GRANT ALL ON TABLE "public"."sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."sessions" TO "service_role";



GRANT ALL ON TABLE "public"."team_coaches" TO "authenticated";
GRANT ALL ON TABLE "public"."team_coaches" TO "service_role";



GRANT ALL ON TABLE "public"."teams" TO "anon";
GRANT ALL ON TABLE "public"."teams" TO "authenticated";
GRANT ALL ON TABLE "public"."teams" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







