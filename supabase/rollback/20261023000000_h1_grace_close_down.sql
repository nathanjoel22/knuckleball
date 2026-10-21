-- Rollback of 20261023000000_h1_grace_close: re-creates the five "H1 grace" policies exactly as production had them on
-- Oct 21 2026 (read from pg_policies before the close). Sessions sealed by the close stay sealed (the H1 lock never
-- unseals), so this only re-opens the old-app path for sessions saved after it runs.

create policy "H1 grace: old-app event insert" on public.game_events
  as permissive for insert to public
  with check ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = game_events.session_id) AND (s.ended_at IS NOT NULL) AND (s.sealed_at IS NULL) AND (is_my_profile(s.pitcher_id) OR is_team_coach(s.team_id))))));

create policy "H1 grace: old-app event re-send" on public.game_events
  as permissive for update to public
  using ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = game_events.session_id) AND (s.sealed_at IS NULL) AND (is_my_profile(s.pitcher_id) OR is_team_coach(s.team_id))))))
  with check ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = game_events.session_id) AND (s.sealed_at IS NULL) AND (is_my_profile(s.pitcher_id) OR is_team_coach(s.team_id))))));

create policy "H1 grace: old-app pitch insert" on public.pitches
  as permissive for insert to public
  with check ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = pitches.session_id) AND (s.ended_at IS NOT NULL) AND (s.sealed_at IS NULL) AND (is_my_profile(s.pitcher_id) OR is_team_coach(s.team_id))))));

create policy "H1 grace: old-app pitch re-send" on public.pitches
  as permissive for update to public
  using ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = pitches.session_id) AND (s.sealed_at IS NULL) AND (is_my_profile(s.pitcher_id) OR is_team_coach(s.team_id))))))
  with check ((EXISTS ( SELECT 1
   FROM sessions s
  WHERE ((s.id = pitches.session_id) AND (s.sealed_at IS NULL) AND (is_my_profile(s.pitcher_id) OR is_team_coach(s.team_id))))));

create policy "H1 grace: old-app session insert" on public.sessions
  as permissive for insert to public
  with check (((is_my_profile(pitcher_id) OR is_team_coach(team_id)) AND (ended_at IS NOT NULL) AND (sealed_at IS NULL)));

