-- U14 reset, step 2 (Joel, Oct 15 2026): clears every painted zone and turns every switch (the remembered answer) off.
-- Run only after step 1's list is saved. Pitches are never touched -- proven by the checksum taken before and after,
-- in the same transaction (the whole block fails if they differ).
do $$
declare
  v_before text; v_after text; v_pb bigint; v_pa bigint; v_z bigint; v_s bigint;
begin
  select count(*), md5(coalesce(string_agg(id::text || ':' || coalesce(in_accuracy_zone::text, '-') || ':' ||
         coalesce(array_to_string(accuracy_zone_cells, '|'), '-'), ',' order by id), ''))
    into v_pb, v_before from public.pitches;
  delete from public.accuracy_zones;
  get diagnostics v_z = row_count;
  update public.profiles set relative_accuracy_enabled = false where relative_accuracy_enabled;
  get diagnostics v_s = row_count;
  select count(*), md5(coalesce(string_agg(id::text || ':' || coalesce(in_accuracy_zone::text, '-') || ':' ||
         coalesce(array_to_string(accuracy_zone_cells, '|'), '-'), ',' order by id), ''))
    into v_pa, v_after from public.pitches;
  if v_before <> v_after or v_pb <> v_pa then
    raise exception 'U14 reset: pitches changed -- nothing was cleared';
  end if;
  raise notice 'U14 reset: % zones cleared, % switches off; pitches % rows, checksum % (unchanged)', v_z, v_s, v_pa, v_after;
end $$;
select (select count(*) from public.accuracy_zones) as zones_left,
       (select count(*) from public.profiles where relative_accuracy_enabled) as switches_on,
       (select count(*) from public.pitches) as pitches,
       (select count(*) from public.pitches where in_accuracy_zone is not null) as zone_scored_pitches;
