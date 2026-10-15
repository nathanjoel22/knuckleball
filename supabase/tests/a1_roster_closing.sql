-- A1 roster tag: get_roster_closing returns a closing date only to coaches of the pitcher's team. Rolled back
-- (the block ends by raising its results).
do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723';   -- Staging Knights
  H uuid := '84c1d3f1-0509-49b2-8b3f-30aae98dcbf3';   -- its head coach
  P uuid := '14345e15-dca3-4bc7-8126-2639b6504aad';   -- Staging Pitcher, on it
  X uuid; out text := ''; n int; d timestamptz;
begin
  select tc.coach_id into X from public.team_coaches tc where tc.team_id <> T
    and not exists (select 1 from public.team_coaches t2 where t2.team_id = T and t2.coach_id = tc.coach_id) limit 1;
  select count(*) into n from public.get_roster_closing(T);   -- as the owner (no login): sees nothing
  out := out || 'before, no login=' || n;
  update public.profiles set deletion_requested_at = now(), deletion_due_at = now() + interval '7 days' where id = P;
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*), max(closing_on) into n, d from public.get_roster_closing(T);
  out := out || ' | head coach=' || n || (case when d::date = (now() + interval '7 days')::date then ' (date right)' else ' (date WRONG)' end);
  perform set_config('request.jwt.claims', json_build_object('sub', X, 'role', 'authenticated')::text, true);
  select count(*) into n from public.get_roster_closing(T);
  out := out || ' | other team''s coach=' || n;
  perform set_config('request.jwt.claims', json_build_object('sub', P, 'role', 'authenticated')::text, true);
  select count(*) into n from public.get_roster_closing(T);
  out := out || ' | the pitcher=' || n;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  set local role anon;
  begin select count(*) into n from public.get_roster_closing(T); out := out || ' | anon=' || n;
  exception when insufficient_privilege then out := out || ' | anon=refused'; end;
  raise exception 'RESULT %', out;
end $$;
