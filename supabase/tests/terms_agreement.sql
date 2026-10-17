-- Terms agreement (Oct 17 2026) acceptance, staging. Runs as an existing primary profile and ROLLS BACK.
begin;
create temp table t_out (n int, check_name text, result text) on commit drop;
grant all on t_out to authenticated, anon;
do $$ declare v uuid; begin
  select id into v from public.profiles where is_primary and age_attestation is not null order by created_at limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  insert into t_out values (0, 'test login', v::text);
end $$;
set local role authenticated;
insert into t_out select 1, 'bad version refused', (public.agree_to_terms('latest'))->>'error';
insert into t_out select 2, 'agree ok', (public.agree_to_terms('2026-10-17'))->>'ok';
insert into t_out select 3, 'stored version', terms_version from public.profiles where id = auth.uid();
insert into t_out select 4, 'stored time set', (terms_agreed_at is not null)::text from public.profiles where id = auth.uid();
insert into t_out select 5, 'second agree keeps first time', (public.agree_to_terms('2026-10-17'))->>'already';
do $$ begin
  begin update public.profiles set terms_agreed_at = now() where id = auth.uid();
        insert into t_out values (6, 'client direct write refused', 'NO -- write allowed');
  exception when insufficient_privilege then insert into t_out values (6, 'client direct write refused', 'yes'); end;
end $$;
reset role;
set local role anon;
do $$ begin
  begin perform public.agree_to_terms('2026-10-17'); insert into t_out values (7, 'anon refused', 'NO');
  exception when insufficient_privilege then insert into t_out values (7, 'anon refused', 'yes'); end;
end $$;
reset role;
select n, check_name, result from t_out order by n;
rollback;
