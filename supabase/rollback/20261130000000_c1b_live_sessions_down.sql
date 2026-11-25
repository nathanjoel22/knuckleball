-- Rollback for C1 Stage B (20261130000000_c1b_live_sessions): the live tables and their functions. Nothing else in the
-- database refers to them; saved sessions are untouched (each piece was saved through sync_session as usual).
drop function if exists public.live_summary();
drop function if exists public.live_set_state(uuid, jsonb);
drop function if exists public.live_put_offline(uuid, jsonb);
drop function if exists public.live_put_outcome(uuid, int, jsonb, boolean);
drop function if exists public.live_no_pitch(uuid, int);
drop function if exists public.live_unconfirm(uuid, int);
drop function if exists public.live_put_intent(uuid, text, int, int, text);
drop function if exists public.live_poll(uuid, integer);
drop function if exists public.live_leave(uuid, uuid);
drop function if exists public.live_join(uuid, text, uuid);
drop function if exists public.live_start(uuid, uuid, text, text, uuid, uuid);
drop function if exists public.c1_live_view(uuid, integer);
drop function if exists public.c1_my_part(uuid);
drop function if exists public.c1_can_chart(uuid, uuid);
drop table if exists public.live_pitches;
drop table if exists public.live_parts;
drop table if exists public.live_sessions;
