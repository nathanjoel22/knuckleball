begin;
create temp table r(n int, test text, result text) on commit drop;
grant all on r to authenticated, service_role;
create or replace function pg_temp.as_user(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', u::text, true);
end $$;
-- T1-T4 as the pitcher / coach (role authenticated)
select pg_temp.as_user('14345e15-dca3-4bc7-8126-2639b6504aad');
set local role authenticated;
insert into r select 1, 'mistyped confirmation', public.request_account_deletion('delete')::text;
insert into r select 2, 'request for another login''s player', public.request_account_deletion('DELETE', '6d6483f5-3b61-4316-ad38-a5a370e2ff1c')::text;
insert into r select 3, 'pitcher requests', (public.request_account_deletion('DELETE')->>'status');
insert into r select 4, 'second request (no-op)', (public.request_account_deletion('DELETE')->>'status');
insert into r select 5, 'status shows a due date', (public.account_deletion_status()->>'due_at' is not null)::text;
insert into r select 6, 'cancel', (public.cancel_account_deletion()->>'status');
insert into r select 7, 'status after cancel', coalesce(public.account_deletion_status()->>'due_at','none');
reset role;
select pg_temp.as_user('84c1d3f1-0509-49b2-8b3f-30aae98dcbf3');
set local role authenticated;
insert into r select 8, 'head coach requests', (select (j->>'error')||' '||jsonb_array_length(j->'teams')||' teams' from (select public.request_account_deletion('DELETE') j) x);
-- T5: a direct clear of a saved session's pitcher is refused (app role: RLS gives no UPDATE at all)
insert into r select 9, 'app role can run the purge?', (select has_function_privilege('authenticated','public.a1_purge_profile(uuid)','EXECUTE'))::text;
reset role;
set local role service_role;
do $$ begin
  update public.sessions set pitcher_id = null where pitcher_id = '14345e15-dca3-4bc7-8126-2639b6504aad' and ended_at is not null;
  insert into r values (10, 'service role clears a pitcher directly', 'ALLOWED (bad)');
exception when others then insert into r values (10, 'service role clears a pitcher directly', 'refused: ' || sqlerrm);
end $$;
-- T6: the purge of a pitcher (service role, as the scheduled run)
insert into r select 11, 'purge Staging Pitcher', public.a1_purge_profile('14345e15-dca3-4bc7-8126-2639b6504aad')::text;
reset role;
insert into r select 12, 'his profile left', (select count(*) from public.profiles where id='14345e15-dca3-4bc7-8126-2639b6504aad')::text;
insert into r select 13, 'sessions still naming him', (select count(*) from public.sessions where pitcher_id='14345e15-dca3-4bc7-8126-2639b6504aad')::text;
insert into r select 14, 'tombstones with no pitcher (deleted_account)', (select count(*) from public.sessions where pitcher_id is null and deleted_by_role='deleted_account')::text;
insert into r select 15, 'pitches/events left in those tombstones', (select count(*) from public.pitches p join public.sessions s on s.id=p.session_id where s.pitcher_id is null)::text || '/' || (select count(*) from public.game_events e join public.sessions s on s.id=e.session_id where s.pitcher_id is null)::text;
insert into r select 16, 'a tombstone keeps a name?', (select count(*) from public.sessions where pitcher_id is null and deleted_by_name is not null)::text;
-- T7: a coach, after handing his team off (done here directly for the test)
update public.teams set coach_id = '5db9c5c9-6a72-494f-bdfd-b076dd5d81a8' where coach_id = '9703ef34-193d-4a6f-abe4-f461a8b8b26b';
insert into r select 17, 'coach charted (before)', (select count(*) from public.sessions where logged_by='9703ef34-193d-4a6f-abe4-f461a8b8b26b' and pitcher_id is distinct from '9703ef34-193d-4a6f-abe4-f461a8b8b26b')::text;
create temp table charted on commit drop as select id, pitcher_id from public.sessions where logged_by='9703ef34-193d-4a6f-abe4-f461a8b8b26b';
set local role service_role;
insert into r select 18, 'purge Coach Joel', (select (j->>'recharted')||' recharted, '||(j->>'notes')||' notes' from (select public.a1_purge_profile('9703ef34-193d-4a6f-abe4-f461a8b8b26b') j) x);
reset role;
insert into r select 19, 'his charted sessions still the pitcher''s, not deleted', (select count(*) from public.sessions s join charted c on c.id=s.id where s.pitcher_id = c.pitcher_id and s.logged_by is null and (s.deleted_at is null or s.deleted_by_role<>'deleted_account'))::text || ' of ' || (select count(*) from charted)::text;
-- T8: a parent's player only
insert into r select 20, 'purge player Malachi (service role)', (select (j->>'tombstoned')||' tombstoned' from (select public.a1_purge_profile('6d6483f5-3b61-4316-ad38-a5a370e2ff1c') j) x);
insert into r select 21, 'player gone / parent login stays', (select count(*) from public.profiles where id='6d6483f5-3b61-4316-ad38-a5a370e2ff1c')::text || ' / ' || (select count(*) from public.profiles where id='a591ac1c-64ad-40c8-a336-ecbaef286dc4')::text;
select n, test, left(result, 120) as result from r order by n;
rollback;
