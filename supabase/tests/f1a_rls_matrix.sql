-- F1-A: the whole-database read matrix (read-only; ends by raising its result, so nothing is kept).
-- As EVERY login on the project, one at a time with RLS on: for every public table with row security, how many rows
-- that login sees and a digest of exactly which rows; plus what the visibility functions return for them
-- (pitcher_workload over every pitcher, pitcher_session_teams, get_roster_verification / get_roster_closing per team
-- they coach, pitcher_report_block per pitcher). Run before and after the f1a migration: every existing login's line
-- must be identical (kind='team' behaviour unchanged). Facility logins made after the migration are listed separately.
--   supabase db query --linked --project-ref <ref> -f supabase/tests/f1a_rls_matrix.sql
do $$
declare
  u record; t record; n bigint; h text; out text := ''; per text; totals jsonb := '{}'; tm text;
  pitchers uuid[]; teamids uuid[]; cols text;
begin
  select array_agg(id order by id) into pitchers from public.profiles where role = 'pitcher';
  for u in select id, (exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'organizations')) as f1a
             from auth.users order by id loop
    perform set_config('request.jwt.claims', json_build_object('sub', u.id, 'role', 'authenticated')::text, true);
    set local role authenticated;
    per := '';
    for t in select c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
              where s.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity order by c.relname loop
      begin
        -- only the columns a client may read (profiles and teams have column grants, never secret columns)
        select string_agg(format('%I', a.attname), ', ' order by a.attnum) into cols from pg_attribute a
          where a.attrelid = ('public.' || quote_ident(t.relname))::regclass and a.attnum > 0 and not a.attisdropped
            and has_column_privilege('authenticated', a.attrelid, a.attname, 'SELECT')
            and not (t.relname = 'teams' and a.attname in ('org_id', 'kind'));   -- F1-A's new columns: compared in the facility matrix
        execute format('select count(*), coalesce(md5(string_agg(md5(x::text), '','' order by md5(x::text))), ''-'') from (select %s from public.%I) x', coalesce(cols, '1'), t.relname) into n, h;
      exception when insufficient_privilege then n := -1; h := 'denied';
      end;
      per := per || t.relname || '=' || n || ':' || left(h, 8) || ' ';
      totals := jsonb_set(totals, array[t.relname], to_jsonb(coalesce((totals ->> t.relname)::bigint, 0) + greatest(n, 0)));
    end loop;
    -- visibility functions
    select coalesce(md5(string_agg(w::text, ',' order by w::text)), '-') into h from public.pitcher_workload(pitchers) w;
    per := per || 'fn:workload=' || left(h, 8);
    select coalesce(md5(string_agg(x::text, ',' order by x::text)), '-') into h
      from (select p, public.pitcher_report_block(p) b from unnest(pitchers) p) x where x.b is not null;
    per := per || ' fn:report_block=' || left(h, 8);
    select coalesce(md5(string_agg(x::text, ',' order by x::text)), '-') into h
      from (select p, s.* from unnest(pitchers) p, lateral public.pitcher_session_teams(p) s) x;
    per := per || ' fn:session_teams=' || left(h, 8);
    select array_agg(tc.team_id order by tc.team_id) into teamids from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id
      where pr.account_id = u.id;
    select coalesce(md5(string_agg(x::text, ',' order by x::text)), '-') into h
      from (select tid, v.* from unnest(coalesce(teamids, '{}')) tid, lateral public.get_roster_verification(tid) v) x;
    per := per || ' fn:roster_verif=' || left(h, 8);
    select coalesce(md5(string_agg(x::text, ',' order by x::text)), '-') into h
      from (select tid, v.* from unnest(coalesce(teamids, '{}')) tid, lateral public.get_roster_closing(tid) v) x;
    per := per || ' fn:roster_closing=' || left(h, 8);
    reset role;
    out := out || E'\n' || left(u.id::text, 8) || ' ' || per;
  end loop;
  select string_agg(k || '=' || v, ' ' order by k) into tm from jsonb_each_text(totals) e(k, v);
  raise exception 'MATRIX(read-only) logins=% policies=% %', (select count(*) from auth.users),
    (select count(*) from pg_policies where schemaname = 'public'), E'\nTOTALS ' || tm || out;
end $$;
