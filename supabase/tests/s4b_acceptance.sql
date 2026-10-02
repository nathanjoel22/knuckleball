-- S4 Stage B acceptance (database side). Rolled back: run as
--   cat supabase/migrations/20261002060000_s4b_players.sql supabase/tests/s4b_acceptance.sql > /tmp/x.sql
--   supabase db query --linked --project-ref <staging> -f /tmp/x.sql
-- before the migration is applied, or alone after it is.
do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723'; H uuid := '84c1d3f1-0509-49b2-8b3f-30aae98dcbf3';
  PA uuid := 'aaaaaaaa-0000-4000-8000-0000000000f1';  -- parent signup
  MI uuid := 'aaaaaaaa-0000-4000-8000-0000000000f2';  -- 13-17 pitcher
  NA uuid := 'aaaaaaaa-0000-4000-8000-0000000000f3';  -- never answered
  AD uuid := 'aaaaaaaa-0000-4000-8000-0000000000f4';  -- another adult login
  out text := ''; r jsonb; c int; v text; ptok text; kid uuid; kid2 uuid;
begin
  select invite_token into ptok from public.teams where id = T;
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
    (PA, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','s4b-parent@example.invalid','{"intended_role":"parent","full_name":"Pat Parent"}', now(), now()),
    (MI, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','s4b-minor@example.invalid','{"intended_role":"pitcher","full_name":"Mo Minor","intended_sport":"baseball"}', now(), now()),
    (NA, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','s4b-none@example.invalid','{"intended_role":"pitcher","full_name":"Ned None","intended_sport":"baseball"}', now(), now()),
    (AD, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','s4b-adult@example.invalid','{"intended_role":"pitcher","full_name":"Ada Adult","intended_sport":"baseball"}', now(), now());
  insert into public.profiles (id, role, full_name, sport) values
    (MI,'pitcher','Mo Minor','baseball'), (NA,'pitcher','Ned None','baseball'), (AD,'pitcher','Ada Adult','baseball')
  on conflict (id) do nothing;

  -- 9. parent signup: primary profile 'parent', adult statement, Add a player
  perform set_config('request.jwt.claims', json_build_object('sub', PA, 'role','authenticated', 'email','s4b-parent@example.invalid')::text, true); execute 'set local role authenticated';
  r := public.ensure_account_setup('parent', 'Pat Parent'); out := out || '9 parent setup: ' || (r->>'profile') || '/' || (r->>'role');
  r := public.record_attestation('minor_13_17', '2026-10-03', 'kid@example.invalid', 'signup'); out := out || ', parent as minor: ' || (r->>'error');
  r := public.add_player('Emma Kid', 'baseball', 'R', true); out := out || ', add before attesting: ' || (r->>'error');
  r := public.record_attestation('adult', '2026-10-03', null, 'signup'); out := out || ', attest adult: ' || (r->>'ok');
  r := public.add_player('Emma Kid', 'baseball', 'R', false); out := out || ', add without consent: ' || (r->>'error');
  r := public.add_player('   ', 'baseball', 'R', true); out := out || ', blank name: ' || (r->>'error');
  r := public.add_player('Emma Kid', 'cricket', 'R', true); out := out || ', bad sport: ' || (r->>'error');
  r := public.add_player('Emma Kid', 'baseball', 'R', true); out := out || ', add Emma: ' || (r->>'ok'); kid := (r->>'id')::uuid;
  r := public.add_player('Sam Kid', 'softball', null, true); out := out || ', add Sam (softball): ' || (r->>'ok'); kid2 := (r->>'id')::uuid;
  r := public.join_team_via_invite(ptok); out := out || ' | join with no profile chosen: ' || coalesce(r->>'error', 'ok');
  begin r := public.join_team_via_invite(ptok, kid2); out := out || ', join baseball team as Sam: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  exception when others then out := out || ', join baseball team as Sam: ' || replace(sqlerrm, '"', ''); end;
  r := public.join_team_via_invite(ptok, kid); out := out || ', join as Emma: ' || coalesce(r->>'ok', r->>'error');
  begin update public.profiles set guardian_consented_at = null where id = kid; get diagnostics c = row_count; out := out || ', parent clears consent: ' || c || ' rows (BAD)';
  exception when others then out := out || ', parent edits consent column: refused'; end;
  execute 'reset role';
  out := out || ' | Emma row: ' || (select 'account=parent:' || (account_id = PA) || ' managed_by=parent:' || (managed_by = PA) || ' role=' || role || ' sport=' || sport
        || ' consent_via=' || consent_via || ' consented=' || (guardian_consented_at is not null) || ' age=' || coalesce(age_attestation, 'none')
        || ' report_to=' || (contact_emails->>'pitcher') || ' on_team=' || exists (select 1 from public.pitcher_teams where pitcher_id = kid and team_id = T)
        from public.profiles where id = kid);
  out := out || ', own login for Emma: ' || exists (select 1 from auth.users where id = kid);
  out := out || ', parent primary: ' || (select role || ' sport=' || coalesce(sport, 'none') || ' primary=' || is_primary from public.profiles where id = PA);

  -- 12. report gate: managed player of a verified parent login
  out := out || ' | 12 Emma eligible, parent unverified: ' || public.is_pitcher_report_eligible(kid);
  update public.profiles set email_verified_at = now() where id = PA;
  out := out || ', parent verified: ' || public.is_pitcher_report_eligible(kid);
  update public.profiles set guardian_consented_at = null where id = kid;
  out := out || ', consent stamp missing: ' || public.is_pitcher_report_eligible(kid);
  perform set_config('request.jwt.claims', json_build_object('sub', PA, 'role','authenticated')::text, true); execute 'set local role authenticated';
  out := out || ' (reason ' || public.pitcher_report_block(kid) || ')';
  execute 'reset role';
  update public.profiles set guardian_consented_at = now() where id = kid;

  -- 13. coach roster: Parent account, and secrets still unreadable
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  select count(*) into c from public.get_roster_verification(T) where pitcher_id = kid and managed and email = 's4b-parent@example.invalid' and email_confirmed and age_answered and not guardian_pending;
  out := out || ' | 13 roster: Emma = Parent account, reports to parent email, verified: ' || (c = 1);
  select count(*) into c from public.get_roster_verification(T) where managed and pitcher_id <> kid;
  out := out || ', other rows flagged managed: ' || c;
  begin select guardian_email into v from public.profiles where id = PA; out := out || ', coach reads parent guardian_email: ALLOWED (BAD)';
  exception when others then out := out || ', coach reads guardian_email: refused (' || replace(sqlerrm, '"', '') || ')'; end;
  begin select guardian_consent_token into v from public.profiles where id = kid; out := out || ', coach reads token: ALLOWED (BAD)';
  exception when others then out := out || ', coach reads token: refused'; end;
  execute 'reset role';

  -- 10. Add a player refused for a 13-17 login and an unattested one
  perform set_config('request.jwt.claims', json_build_object('sub', MI, 'role','authenticated', 'email','s4b-minor@example.invalid')::text, true); execute 'set local role authenticated';
  r := public.record_attestation('minor_13_17', '2026-10-03', 'mom-s4b@example.invalid', 'signup');
  r := public.add_player('Little Bro', 'baseball', 'R', true); out := out || ' | 10 minor adds a player: ' || (r->>'error');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', NA, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.add_player('Little Bro', 'baseball', 'R', true); out := out || ', unattested adds a player: ' || (r->>'error');
  -- 11. still no under-13 self-signup answer
  r := public.record_attestation('under_13', '2026-10-03', null, 'signup'); out := out || ' | 11 under_13 self-attest: ' || (r->>'error');
  execute 'reset role';

  -- crafted: another login uses the parent's player
  perform set_config('request.jwt.claims', json_build_object('sub', AD, 'role','authenticated', 'email','s4b-adult@example.invalid')::text, true); execute 'set local role authenticated';
  r := public.record_attestation('adult', '2026-10-03', null, 'signup');
  r := public.join_team_via_invite(ptok, kid); out := out || ' | another login joins as Emma: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  select count(*) into c from public.profiles where id = kid; out := out || ', reads Emma: ' || c || ' rows';
  begin update public.profiles set full_name = 'Hacked' where id = kid; get diagnostics c = row_count; out := out || ', renames Emma: ' || c || ' rows';
  exception when others then out := out || ', renames Emma: refused'; end;
  execute 'reset role';
  -- anon can't add players
  execute 'set local role anon';
  begin r := public.add_player('X', 'baseball', 'R', true); out := out || ' | anon add_player: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  exception when others then out := out || ' | anon add_player: refused'; end;
  execute 'reset role';

  raise exception 'RESULTS(rolled back):%', out;
end $$;
