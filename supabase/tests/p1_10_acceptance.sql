-- P1-10 acceptance (database side). Rolled back.
do $$
declare
  T uuid := '18fa6885-c85e-4c2a-88e9-e301c6f93723'; H uuid := '84c1d3f1-0509-49b2-8b3f-30aae98dcbf3';
  AD uuid := 'aaaaaaaa-0000-4000-8000-0000000000e1';  -- new adult pitcher
  MI uuid := 'aaaaaaaa-0000-4000-8000-0000000000e2';  -- new 13-17 pitcher
  NA uuid := 'aaaaaaaa-0000-4000-8000-0000000000e3';  -- existing, never answered
  CO uuid := 'aaaaaaaa-0000-4000-8000-0000000000e4';  -- new coach
  out text := ''; r jsonb; c int; v text; tok text; ptok text; ctok text;
begin
  select invite_token, coach_invite_token into ptok, ctok from public.teams where id = T;
  insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
    (AD, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','p110-adult@example.invalid','{"intended_role":"pitcher","full_name":"Ada Adult","intended_sport":"baseball"}', now(), now()),
    (MI, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','p110-minor@example.invalid','{"intended_role":"pitcher","full_name":"Mia <b>Minor</b>","intended_sport":"baseball"}', now(), now()),
    (NA, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','p110-none@example.invalid','{"intended_role":"pitcher","full_name":"Ned None","intended_sport":"baseball"}', now(), now()),
    (CO, '00000000-0000-0000-0000-000000000000','authenticated','authenticated','p110-coach@example.invalid','{"intended_role":"coach","full_name":"Cal Coach","intended_sport":"baseball"}', now(), now());
  insert into public.profiles (id, role, full_name, sport, email_verified_at) values
    (AD,'pitcher','Ada Adult','baseball', now()), (MI,'pitcher','Mia <b>Minor</b>','baseball', now()), (NA,'pitcher','Ned None','baseball', now()), (CO,'coach','Cal Coach','baseball', now())
  on conflict (id) do update set email_verified_at = excluded.email_verified_at;

  -- 1. adult pitcher
  perform set_config('request.jwt.claims', json_build_object('sub', AD, 'role','authenticated', 'email','p110-adult@example.invalid')::text, true); execute 'set local role authenticated';
  r := public.record_attestation('adult', '2026-10-02', null, 'signup');
  out := out || ' | 1 adult: ' || (r->>'ok') || ' -> ' || (select age_attestation || '/' || attested_via || '/' || terms_version || '/' || (attested_at is not null) from public.profiles where id = AD);
  r := public.join_team_via_invite(ptok); out := out || ', joins team: ' || coalesce(r->>'ok', r->>'error');
  execute 'reset role';
  out := out || ', report eligible: ' || public.is_pitcher_report_eligible(AD);

  -- 2. 13-17 pitcher
  perform set_config('request.jwt.claims', json_build_object('sub', MI, 'role','authenticated', 'email','p110-minor@example.invalid')::text, true); execute 'set local role authenticated';
  r := public.record_attestation('minor_13_17', '2026-10-02', 'P110-Minor@example.invalid', 'signup'); out := out || ' | 2 own email as guardian: ' || (r->>'error');
  r := public.record_attestation('minor_13_17', '2026-10-02', 'not-an-email', 'signup'); out := out || ', bad email: ' || (r->>'error');
  r := public.record_attestation('minor_13_17', '2026-10-02', 'Parent+Mia@example.invalid', 'signup');
  out := out || ', valid: ' || (r->>'ok') || ' needs_guardian=' || (r->>'needs_guardian');
  r := public.join_team_via_invite(ptok); out := out || ', joins team: ' || coalesce(r->>'ok', r->>'error');
  r := public.record_attestation('adult', '2026-10-02', null, 'signup'); out := out || ', switch to adult: ' || (r->>'error');
  -- 10. send: first ok (to the STORED address), second within 10 min refused
  r := public.claim_guardian_send(); out := out || ' | 10 first send: ' || (r->>'ok') || ' to ' || (r->>'email') || ' name=' || (r->>'name');
  tok := r->>'token';
  r := public.claim_guardian_send(); out := out || ', second send: ' || (r->>'error') || ' (retry in ' || (r->>'retry_after_seconds') || 's)';
  execute 'reset role';
  out := out || ' | 2 db: ' || (select age_attestation || ' guardian=' || guardian_email || ' token=' || (guardian_consent_token is not null) || ' approved=' || (guardian_consented_at is not null) from public.profiles where id = MI);
  out := out || ', report eligible: ' || public.is_pitcher_report_eligible(MI);
  perform set_config('request.jwt.claims', json_build_object('sub', MI, 'role','authenticated')::text, true); execute 'set local role authenticated';
  out := out || ', block reason: ' || public.pitcher_report_block(MI);
  execute 'reset role';

  -- 9. coach roster + secrets
  perform set_config('request.jwt.claims', json_build_object('sub', H, 'role','authenticated')::text, true); execute 'set local role authenticated';
  select count(*) into c from public.get_roster_verification(T) where pitcher_id = MI and guardian_pending; out := out || ' | 9 roster shows Guardian pending: ' || (c = 1);
  begin select guardian_email into v from public.profiles where id = MI; out := out || ', coach reads guardian_email: ALLOWED (BAD)';
  exception when others then out := out || ', coach reads guardian_email: refused'; end;
  begin select guardian_consent_token into v from public.profiles where id = MI; out := out || ', coach reads token: ALLOWED (BAD)';
  exception when others then out := out || ', coach reads token: refused'; end;
  begin update public.profiles set guardian_consented_at = now() where id = MI; get diagnostics c = row_count; out := out || ', coach writes approval: ' || c || ' rows (BAD)';
  exception when others then out := out || ', coach writes approval: refused'; end;
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', MI, 'role','authenticated')::text, true); execute 'set local role authenticated';
  begin update public.profiles set guardian_consented_at = now() where id = MI; get diagnostics c = row_count; out := out || ', teen approves himself: ' || c || ' rows (BAD)';
  exception when others then out := out || ', teen approves himself: refused'; end;
  execute 'reset role';

  -- 3. guardian link (anon)
  execute 'set local role anon';
  r := public.get_guardian_request(tok); out := out || ' | 3 guardian page shows: ' || (r->>'first_name') || ' (' || (r->>'sport') || ')';
  r := public.record_guardian_consent(tok); out := out || ', approve: ' || (r->>'ok');
  r := public.record_guardian_consent(tok); out := out || ', reuse: ' || (r->>'error');
  r := public.get_guardian_request('0000'); out := out || ', bad token: ' || (r->>'error');
  execute 'reset role';
  out := out || ', db: ' || (select 'consent_via=' || consent_via || ' token_cleared=' || (guardian_consent_token is null) from public.profiles where id = MI) || ', report eligible now: ' || public.is_pitcher_report_eligible(MI);

  -- 5. coaches are adults only
  perform set_config('request.jwt.claims', json_build_object('sub', CO, 'role','authenticated', 'email','p110-coach@example.invalid')::text, true); execute 'set local role authenticated';
  r := public.record_attestation('minor_13_17', '2026-10-02', 'mom@example.invalid', 'signup'); out := out || ' | 5 coach as minor: ' || (r->>'error');
  -- 6. joins refuse without an answer
  r := public.join_team_as_coach(ctok); out := out || ' | 6 unanswered coach joins as assistant: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', NA, 'role','authenticated')::text, true); execute 'set local role authenticated';
  r := public.join_team_via_invite(ptok); out := out || ', unanswered pitcher joins: ' || coalesce(r->>'error', 'ALLOWED (BAD)');
  -- 4. there is no under-13 answer to record
  r := public.record_attestation('under_13', '2026-10-02', null, 'signup'); out := out || ' | 4 under_13: ' || (r->>'error');
  -- insert hardening
  begin insert into public.profiles (id, role, full_name, sport, email_verified_at) values (gen_random_uuid(), 'pitcher', 'Forged', 'baseball', now()); out := out || ' | client profile insert: ALLOWED (BAD)';
  exception when others then out := out || ' | client profile insert: refused'; end;
  execute 'reset role';
  -- existing-account report gate (Joel: option a)
  insert into public.pitcher_teams (pitcher_id, team_id) values (NA, T);
  out := out || ' | unanswered existing pitcher, verified + on team: report eligible=' || public.is_pitcher_report_eligible(NA);

  raise exception 'RESULTS(rolled back):%', out;
end $$;
