-- U14 reset, step 1 (read-only): every pitcher with the relative-accuracy switch on or any painted zone.
-- Save the output to plans/u14-evidence/ BEFORE running u14_reset_run.sql (the cleared zones are not restored).
select pr.full_name as pitcher, pr.sport,
       coalesce((select string_agg(t.name, ', ' order by t.name) from public.pitcher_teams pt
                   join public.teams t on t.id = pt.team_id where pt.pitcher_id = pr.id), '(no team)') as teams,
       pr.relative_accuracy_enabled as switch_on,
       (select count(*) from public.accuracy_zones z where z.pitcher_id = pr.id) as zones,
       (select string_agg(z.pitch_type || ' ' || z.batter_side || ':' || cardinality(z.cells), ', ' order by z.pitch_type, z.batter_side)
          from public.accuracy_zones z where z.pitcher_id = pr.id) as cells_per_zone
  from public.profiles pr
 where pr.relative_accuracy_enabled or exists (select 1 from public.accuracy_zones z where z.pitcher_id = pr.id)
 order by pr.full_name;
