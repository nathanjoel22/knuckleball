-- Down migration for 20261005000000_teams_hotfix.sql: restores the previous (unsafe) state verbatim.
-- Only for an emergency rollback; it reopens the cascade and direct-write holes.
drop function if exists public.set_team_level(uuid, text);
alter table public.sessions drop constraint sessions_team_id_fkey;
alter table public.sessions add constraint sessions_team_id_fkey foreign key (team_id) references public.teams(id) on delete cascade;
grant insert, update, delete, truncate on public.teams to anon, authenticated;
CREATE POLICY "Coaches manage own teams" ON "public"."teams" USING ("public"."is_team_head"("id")) WITH CHECK ("public"."is_team_head"("id"));

