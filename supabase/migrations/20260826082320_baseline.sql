-- Baseline migration for the Knuckleball schema.
-- Generated from supabase/schema/schema.sql (a schema-only dump of production
-- fkgccjhuimkkbupbanxp taken 2026-08-25, per task P0-02) since supabase/migrations/
-- never existed before this -- every table/policy/function here was previously
-- applied to production by hand, with no record of when or why. This file is
-- that missing record, and the starting point for every migration from here on.
-- Intended for a FRESH database only (a new staging project, or disaster
-- recovery per BACKUPS.md) -- do not run this against production, which already
-- has this schema natively.




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



CREATE OR REPLACE FUNCTION "public"."is_team_coach"("check_team_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.teams t where t.id = check_team_id and t.coach_id = auth.uid()
  );
$$;


ALTER FUNCTION "public"."is_team_coach"("check_team_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_team_member"("check_team_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1 from public.pitcher_teams pt where pt.team_id = check_team_id and pt.pitcher_id = auth.uid()
  );
$$;


ALTER FUNCTION "public"."is_team_member"("check_team_id" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


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


CREATE TABLE IF NOT EXISTS "public"."pitcher_teams" (
    "pitcher_id" "uuid" NOT NULL,
    "team_id" "uuid" NOT NULL,
    "joined_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."pitcher_teams" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pitches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "velo" integer,
    "ts" timestamp with time zone DEFAULT "now"() NOT NULL,
    "target_row" integer DEFAULT 0 NOT NULL,
    "target_col" integer DEFAULT 0 NOT NULL,
    "actual_row" integer DEFAULT 0 NOT NULL,
    "actual_col" integer DEFAULT 0 NOT NULL,
    "accuracy_mode" "text",
    CONSTRAINT "pitches_accuracy_mode_check" CHECK ((("accuracy_mode" IS NULL) OR ("accuracy_mode" = ANY (ARRAY['ring'::"text", 'nothingUp'::"text", 'nothingLow'::"text", 'nothingAway'::"text", 'nothingInside'::"text"]))))
);


ALTER TABLE "public"."pitches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "full_name" "text" NOT NULL,
    "pitch_types" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "contact_emails" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['coach'::"text", 'pitcher'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pitcher_id" "uuid" NOT NULL,
    "team_id" "uuid" NOT NULL,
    "started_at" timestamp with time zone NOT NULL,
    "ended_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "logged_by" "uuid" NOT NULL
);


ALTER TABLE "public"."sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."teams" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "coach_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."teams" OWNER TO "postgres";


ALTER TABLE ONLY "public"."invites"
    ADD CONSTRAINT "invites_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pitcher_teams"
    ADD CONSTRAINT "pitcher_teams_pkey" PRIMARY KEY ("pitcher_id", "team_id");



ALTER TABLE ONLY "public"."pitches"
    ADD CONSTRAINT "pitches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sessions"
    ADD CONSTRAINT "sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invites"
    ADD CONSTRAINT "invites_invited_by_fkey" FOREIGN KEY ("invited_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."invites"
    ADD CONSTRAINT "invites_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pitcher_teams"
    ADD CONSTRAINT "pitcher_teams_pitcher_id_fkey" FOREIGN KEY ("pitcher_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pitcher_teams"
    ADD CONSTRAINT "pitcher_teams_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pitches"
    ADD CONSTRAINT "pitches_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sessions"
    ADD CONSTRAINT "sessions_logged_by_fkey" FOREIGN KEY ("logged_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."sessions"
    ADD CONSTRAINT "sessions_pitcher_id_fkey" FOREIGN KEY ("pitcher_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sessions"
    ADD CONSTRAINT "sessions_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."teams"
    ADD CONSTRAINT "teams_coach_id_fkey" FOREIGN KEY ("coach_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Coaches manage own team invites" ON "public"."invites" USING ((EXISTS ( SELECT 1
   FROM "public"."teams" "t"
  WHERE (("t"."id" = "invites"."team_id") AND ("t"."coach_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."teams" "t"
  WHERE (("t"."id" = "invites"."team_id") AND ("t"."coach_id" = "auth"."uid"())))));



CREATE POLICY "Coaches manage own teams" ON "public"."teams" USING (("coach_id" = "auth"."uid"())) WITH CHECK (("coach_id" = "auth"."uid"()));



CREATE POLICY "Coaches manage pitches for their team's sessions" ON "public"."pitches" USING ((EXISTS ( SELECT 1
   FROM ("public"."sessions" "s"
     JOIN "public"."teams" "t" ON (("t"."id" = "s"."team_id")))
  WHERE (("s"."id" = "pitches"."session_id") AND ("t"."coach_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."sessions" "s"
     JOIN "public"."teams" "t" ON (("t"."id" = "s"."team_id")))
  WHERE (("s"."id" = "pitches"."session_id") AND ("t"."coach_id" = "auth"."uid"())))));



CREATE POLICY "Coaches manage sessions for their team" ON "public"."sessions" USING ((EXISTS ( SELECT 1
   FROM "public"."teams" "t"
  WHERE (("t"."id" = "sessions"."team_id") AND ("t"."coach_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."teams" "t"
  WHERE (("t"."id" = "sessions"."team_id") AND ("t"."coach_id" = "auth"."uid"())))));



CREATE POLICY "Coaches remove pitchers from their team" ON "public"."pitcher_teams" FOR DELETE USING ("public"."is_team_coach"("team_id"));



CREATE POLICY "Coaches view memberships for their teams" ON "public"."pitcher_teams" FOR SELECT USING ("public"."is_team_coach"("team_id"));



CREATE POLICY "Coaches view pitches for their team's sessions" ON "public"."pitches" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."sessions" "s"
     JOIN "public"."teams" "t" ON (("t"."id" = "s"."team_id")))
  WHERE (("s"."id" = "pitches"."session_id") AND ("t"."coach_id" = "auth"."uid"())))));



CREATE POLICY "Coaches view sessions logged under their team" ON "public"."sessions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."teams" "t"
  WHERE (("t"."id" = "sessions"."team_id") AND ("t"."coach_id" = "auth"."uid"())))));



CREATE POLICY "Coaches view their pitchers' profiles" ON "public"."profiles" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."pitcher_teams" "pt"
  WHERE (("pt"."pitcher_id" = "profiles"."id") AND "public"."is_team_coach"("pt"."team_id")))));



CREATE POLICY "Invited person marks their invite accepted" ON "public"."invites" FOR UPDATE USING (("email" = ("auth"."jwt"() ->> 'email'::"text"))) WITH CHECK (("email" = ("auth"."jwt"() ->> 'email'::"text")));



CREATE POLICY "Invited person views invite addressed to their email" ON "public"."invites" FOR SELECT USING (("email" = ("auth"."jwt"() ->> 'email'::"text")));



CREATE POLICY "Pitchers accept invite by inserting own membership" ON "public"."pitcher_teams" FOR INSERT WITH CHECK (("pitcher_id" = "auth"."uid"()));



CREATE POLICY "Pitchers manage own sessions" ON "public"."sessions" USING (("pitcher_id" = "auth"."uid"())) WITH CHECK (("pitcher_id" = "auth"."uid"()));



CREATE POLICY "Pitchers manage pitches in own sessions" ON "public"."pitches" USING ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND ("s"."pitcher_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sessions" "s"
  WHERE (("s"."id" = "pitches"."session_id") AND ("s"."pitcher_id" = "auth"."uid"())))));



CREATE POLICY "Pitchers view own memberships" ON "public"."pitcher_teams" FOR SELECT USING (("pitcher_id" = "auth"."uid"()));



CREATE POLICY "Pitchers view teams they belong to" ON "public"."teams" FOR SELECT USING ("public"."is_team_member"("id"));



CREATE POLICY "Users insert own profile" ON "public"."profiles" FOR INSERT WITH CHECK (("id" = "auth"."uid"()));



CREATE POLICY "Users update own profile" ON "public"."profiles" FOR UPDATE USING (("id" = "auth"."uid"()));



CREATE POLICY "Users view own profile" ON "public"."profiles" FOR SELECT USING (("id" = "auth"."uid"()));



ALTER TABLE "public"."invites" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pitcher_teams" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pitches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."teams" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."is_team_coach"("check_team_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_team_coach"("check_team_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_team_coach"("check_team_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_team_member"("check_team_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_team_member"("check_team_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_team_member"("check_team_id" "uuid") TO "service_role";



GRANT ALL ON TABLE "public"."invites" TO "anon";
GRANT ALL ON TABLE "public"."invites" TO "authenticated";
GRANT ALL ON TABLE "public"."invites" TO "service_role";



GRANT ALL ON TABLE "public"."pitcher_teams" TO "anon";
GRANT ALL ON TABLE "public"."pitcher_teams" TO "authenticated";
GRANT ALL ON TABLE "public"."pitcher_teams" TO "service_role";



GRANT ALL ON TABLE "public"."pitches" TO "anon";
GRANT ALL ON TABLE "public"."pitches" TO "authenticated";
GRANT ALL ON TABLE "public"."pitches" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."sessions" TO "anon";
GRANT ALL ON TABLE "public"."sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."sessions" TO "service_role";



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







