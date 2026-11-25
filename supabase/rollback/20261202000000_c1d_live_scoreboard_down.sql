-- Rollback for 20261202000000_c1d_live_scoreboard: live_set_state keeps only the at-bat and side again.
create or replace function public.live_set_state(p_live uuid, p_state jsonb)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
begin
  if public.c1_my_part(p_live) is null then return jsonb_build_object('ok', false, 'error', 'not_holding'); end if;
  if jsonb_typeof(p_state) <> 'object' or pg_column_size(p_state) > 1024 then return jsonb_build_object('ok', false, 'error', 'invalid'); end if;
  update public.live_sessions set state = state || jsonb_build_object('ab', p_state -> 'ab', 'side', p_state -> 'side', 'at', now()),
         last_activity_at = now() where id = p_live;
  return jsonb_build_object('ok', true);
end;
$$;
