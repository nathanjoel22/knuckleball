-- Down migration for 20261005020000_r4_cross_team.sql: previous rules and functions verbatim from schema.sql.
drop policy if exists "Sessions: read by the pitcher, the recording team's coaches and his current teams' coaches" on public.sessions;
drop policy if exists "Pitches: read by the pitcher, the recording team's coaches and his current teams' coaches" on public.pitches;
drop policy if exists "Game events: read by the pitcher, the recording team's coaches and his current teams' coaches" on public.game_events;
drop policy if exists "Notes readable by author, pitcher, the recording team's coaches and his current teams' coaches" on public.session_notes;
CREATE POLICY "Sessions: read by the pitcher and the team's coaches" ON "public"."sessions" FOR SELECT USING (("public"."is_my_profile"("pitcher_id") OR "public"."is_team_coach"("team_id")));

CREATE POLICY "Pitches: read by the pitcher and the team's coaches" ON "public"."pitches" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND ("public"."is_my_profile"("s"."pitcher_id") OR "public"."is_team_coach"("s"."team_id"))))));

CREATE POLICY "Game events: read by the pitcher and the team's coaches" ON "public"."game_events" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "game_events"."session_id") AND ("public"."is_my_profile"("s"."pitcher_id") OR "public"."is_team_coach"("s"."team_id"))))));

CREATE POLICY "Notes readable by author, pitcher and his team's coaches" ON "public"."session_notes" FOR SELECT USING (("public"."is_my_profile"("author_id") OR (EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "session_notes"."session_id") AND "public"."is_my_profile"("s"."pitcher_id")))) OR "public"."is_coach_of_session_team"("session_id")));

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

drop function if exists public.pitcher_workload(uuid[]);
drop function if exists public.pitcher_session_teams(uuid);
drop function if exists public.is_current_coach_of_pitcher(uuid, timestamptz);
