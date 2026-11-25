-- C1 follow-up (Joel, Nov 25 2026): the Intent device in a shared Live Game shows the game's scoreboard -- inning, outs,
-- count, runs and pitch count -- as the Outcome & Response device keeps it. live_set_state now keeps those too, merging
-- only the keys a device sends (the caller's device sends the at-bat and side; the other device the whole scoreboard).
-- Small numbers only; nothing else changes. Policies unchanged. Rollback: supabase/rollback/20261202000000_c1d_live_scoreboard_down.sql.
create or replace function public.live_set_state(p_live uuid, p_state jsonb)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare v jsonb;
begin
  if public.c1_my_part(p_live) is null then return jsonb_build_object('ok', false, 'error', 'not_holding'); end if;
  if jsonb_typeof(p_state) <> 'object' or pg_column_size(p_state) > 1024 then return jsonb_build_object('ok', false, 'error', 'invalid'); end if;
  select coalesce(jsonb_object_agg(e.key, e.value), '{}'::jsonb) into v
    from jsonb_each(p_state) e
   where e.key in ('ab', 'side', 'inning', 'outs', 'balls', 'strikes', 'runs', 'pc')
     and (jsonb_typeof(e.value) = 'null' or (jsonb_typeof(e.value) = 'number' and (e.value #>> '{}')::numeric between 0 and 9999)
          or (e.key = 'side' and e.value #>> '{}' in ('R', 'L')));
  update public.live_sessions set state = state || v || jsonb_build_object('at', now()), last_activity_at = now() where id = p_live;
  return jsonb_build_object('ok', true);
end;
$$;
