-- Close the H1 grace path (Joel, Oct 21 2026; CLAUDE.md "Saved sessions and sync (H1)").
--   H1 shipped to production Oct 5 2026 (v145) with a grace path for devices on v144 and earlier: five
--   "H1 grace" policies let an old app INSERT into saved-but-unsealed sessions. Conditions met: >= 14 days since H1
--   (Oct 5 -> Oct 19), and no old-path write for over a week (production's newest unsealed session was created
--   Oct 7; none since). Joel saw the leftovers first (production: 69 saved-but-unsealed, 0 unsaved; staging: 49 and
--   2 old unsaved test rows, which he had deleted on staging).
--   * drops the five grace policies (production 34 -> 29; CLAUDE.md's "six" was a miscount -- H1 created five);
--   * seals every saved session still unsealed (contents unchanged; sessions_h1_lock allows sealing, never unsealing).
-- From now on every saved session is sealed and only sync_session writes sessions, pitches and game_events.
-- Rollback: supabase/rollback/20261023000000_h1_grace_close_down.sql (re-creates the policies; sealing stays).

drop policy "H1 grace: old-app event insert" on public.game_events;
drop policy "H1 grace: old-app event re-send" on public.game_events;
drop policy "H1 grace: old-app pitch insert" on public.pitches;
drop policy "H1 grace: old-app pitch re-send" on public.pitches;
drop policy "H1 grace: old-app session insert" on public.sessions;

update public.sessions set sealed_at = now() where ended_at is not null and sealed_at is null;
