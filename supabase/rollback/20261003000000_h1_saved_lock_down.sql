-- Down migration for 20261003000000_h1_saved_lock.sql: back to the pre-H1 rules (verbatim from
-- supabase/schema/schema.sql). The app must be rolled back to its pre-H1 version first (it calls sync_session).
drop function if exists public.sync_session(jsonb, jsonb, jsonb);
drop trigger if exists sessions_h1_lock on public.sessions;
drop trigger if exists pitches_h1_lock on public.pitches;
drop trigger if exists game_events_h1_lock on public.game_events;
drop function if exists public.sessions_h1_lock();
drop function if exists public.h1_child_lock();
drop policy if exists "Sessions: read by the pitcher and the team's coaches" on public.sessions;
drop policy if exists "Sessions: report link written by the pitcher and the team's coaches" on public.sessions;
drop policy if exists "H1 grace: old-app session insert" on public.sessions;
drop policy if exists "Pitches: read by the pitcher and the team's coaches" on public.pitches;
drop policy if exists "H1 grace: old-app pitch insert" on public.pitches;
drop policy if exists "H1 grace: old-app pitch re-send" on public.pitches;
drop policy if exists "Game events: read by the pitcher and the team's coaches" on public.game_events;
drop policy if exists "H1 grace: old-app event insert" on public.game_events;
drop policy if exists "H1 grace: old-app event re-send" on public.game_events;

CREATE POLICY "Pitchers manage own sessions" ON "public"."sessions" USING ("public"."is_my_profile"("pitcher_id")) WITH CHECK ("public"."is_my_profile"("pitcher_id"));

CREATE POLICY "Coaches manage sessions for their team" ON "public"."sessions" USING ("public"."is_team_coach"("team_id")) WITH CHECK ("public"."is_team_coach"("team_id"));

CREATE POLICY "Coaches view sessions logged under their team" ON "public"."sessions" FOR SELECT USING ("public"."is_team_coach"("team_id"));

CREATE POLICY "Pitchers manage pitches in own sessions" ON "public"."pitches" USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND "public"."is_my_profile"("s"."pitcher_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND "public"."is_my_profile"("s"."pitcher_id")))));

CREATE POLICY "Coaches manage pitches for their team's sessions" ON "public"."pitches" USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND "public"."is_team_coach"("s"."team_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND "public"."is_team_coach"("s"."team_id")))));

CREATE POLICY "Coaches view pitches for their team's sessions" ON "public"."pitches" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND "public"."is_team_coach"("s"."team_id")))));

CREATE POLICY "Pitchers manage events in own sessions" ON "public"."game_events" USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "game_events"."session_id") AND "public"."is_my_profile"("s"."pitcher_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "game_events"."session_id") AND "public"."is_my_profile"("s"."pitcher_id")))));

CREATE POLICY "Coaches manage events for their team's sessions" ON "public"."game_events" USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "game_events"."session_id") AND "public"."is_team_coach"("s"."team_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "game_events"."session_id") AND "public"."is_team_coach"("s"."team_id")))));

CREATE POLICY "Coaches view events for their team's sessions" ON "public"."game_events" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "game_events"."session_id") AND "public"."is_team_coach"("s"."team_id")))));


alter table public.sessions drop column if exists sealed_at;
