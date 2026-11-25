-- C1 Stage B (Joel, Nov 25 2026; plans/c1-charting-parts.md, decisions in plans/c1-preconditions.md): shared charting.
-- When the person who starts a session charts only one part, the session is LIVE and OPEN: someone else who can chart
-- that pitcher takes the other part on a second device, and the two chart the same, server-numbered pitches in step.
--
-- The one exception to "nothing reaches the server before End session & save": pitches in progress are sent as they're
-- tapped -- into these live tables, never sessions / pitches. Each charter's own piece is still saved through
-- sync_session, unchanged. (Stage C puts the pieces together.)
--
-- Access: no client grant and no policy on any of the three tables (policies stay 32 / 12): every read and write goes
-- through the functions below, each of which checks:
--   * the caller can chart this pitcher today, by the same tests sync_session uses: their own profile, the parent who
--     created the player or a linked guardian / the player's own sign-in (can_chart_for), a coach who sees the pitcher
--     on that team (coach_sees_pitcher, the pitcher on the team), an open one-session assignment (F2), or a camp on its
--     day (F2 Stage 4) -- c1_can_chart;
--   * and, for anything but the list of open sessions and joining, that the caller holds a part in that live session.
-- Nobody gains a read of sessions, pitches, history or reports from any of this (an assigned or camp coach still can't).

create table public.live_sessions (
  id               uuid primary key default gen_random_uuid(),
  pitcher_id       uuid not null references public.profiles(id) on delete cascade,
  team_id          uuid references public.teams(id) on delete cascade,   -- null: the pitcher's independent session
  kind             text not null check (kind in ('bullpen', 'game')),
  sport            text,
  started_by_login uuid not null,
  started_at       timestamptz not null default now(),
  last_activity_at timestamptz not null default now(),
  closed_at        timestamptz,
  next_seq         integer not null default 1,
  state            jsonb not null default '{}'::jsonb,   -- a game: the at-bat and batter side (whoever sets it)
  successor_id     uuid references public.live_sessions(id) on delete set null   -- a pitching change: the next pitcher's
);
create index live_sessions_open on public.live_sessions (pitcher_id, kind) where closed_at is null;
alter table public.live_sessions enable row level security;
revoke all on public.live_sessions from public, anon, authenticated;

create table public.live_parts (
  live_id       uuid not null references public.live_sessions(id) on delete cascade,
  part          text not null check (part in ('intent', 'outcome')),
  holder_login  uuid not null,
  holder_profile uuid references public.profiles(id) on delete set null,
  joined_at     timestamptz not null default now(),
  from_seq      integer not null default 1,    -- a joiner picks up at the next pitch
  left_at       timestamptz,
  piece_session_id uuid                        -- the session this charter saved (Stage C compiles from them)
);
create unique index live_parts_one_holder on public.live_parts (live_id, part) where left_at is null;   -- first tap wins
alter table public.live_parts enable row level security;
revoke all on public.live_parts from public, anon, authenticated;

create table public.live_pitches (
  live_id        uuid not null references public.live_sessions(id) on delete cascade,
  seq            integer not null,
  -- Intent: the call
  type           text,
  target_row     smallint check (target_row between 0 and 4),
  target_col     smallint check (target_col between 0 and 4),
  batter_side    text check (batter_side in ('R', 'L')),
  intent_at      timestamptz,
  intent_login   uuid,
  no_pitch       boolean not null default false,   -- called, never thrown (stepped off, time)
  -- Outcome (a game: & Response): the device's own pitch fields, as it saves them
  outcome        jsonb check (outcome is null or pg_column_size(outcome) <= 8192),
  outcome_at     timestamptz,
  outcome_login  uuid,
  skipped_intent boolean not null default false,  -- "Chart without it": no call came
  primary key (live_id, seq)
);
alter table public.live_pitches enable row level security;
revoke all on public.live_pitches from public, anon, authenticated;

-- Can the caller chart this pitcher (for this team) right now? sync_session's tests, without a session.
create or replace function public.c1_can_chart(p_pitcher uuid, p_team uuid)
 returns boolean language sql stable security definer set search_path to '' as $$
  select public.can_chart_for(p_pitcher)
      or (p_team is not null and public.coach_sees_pitcher(p_team, p_pitcher)
          and exists (select 1 from public.pitcher_teams pt where pt.team_id = p_team and pt.pitcher_id = p_pitcher))
      or exists (select 1 from public.session_assignments a join public.profiles c on c.id = a.coach_id
                  where a.pitcher_id = p_pitcher and a.team_id is not distinct from p_team and c.account_id = auth.uid()
                    and a.released_at is null and a.cancelled_at is null and now() <= a.window_ends_at)
      or exists (select 1 from public.camp_rosters c join public.profiles cp on cp.id = c.coach_id
                  where c.team_id is not distinct from p_team and cp.account_id = auth.uid() and c.ended_at is null
                    and (now() at time zone 'America/New_York')::date between c.first_day and c.last_day
                    and exists (select 1 from public.camp_roster_pitchers x where x.camp_id = c.id and x.pitcher_id = p_pitcher))
$$;
revoke all on function public.c1_can_chart(uuid, uuid) from public, anon, authenticated;

-- The part the caller holds in an open live session, or null.
create or replace function public.c1_my_part(p_live uuid)
 returns text language sql stable security definer set search_path to '' as $$
  select lp.part from public.live_parts lp join public.live_sessions l on l.id = lp.live_id
   where lp.live_id = p_live and lp.holder_login = auth.uid() and lp.left_at is null and l.closed_at is null
   order by lp.part limit 1
$$;
revoke all on function public.c1_my_part(uuid) from public, anon, authenticated;

-- The live session's picture for a holder: who holds what, the game state, and the latest pitches.
create or replace function public.c1_live_view(p_live uuid, p_after integer)
 returns jsonb language sql stable security definer set search_path to '' as $$
  select jsonb_build_object('ok', true, 'server_now', now(),
    'live', jsonb_build_object('id', l.id, 'kind', l.kind, 'pitcher_id', l.pitcher_id, 'team_id', l.team_id,
      'closed', l.closed_at is not null, 'state', l.state, 'next_seq', l.next_seq, 'successor_id', l.successor_id,
      'parts', (select coalesce(jsonb_object_agg(lp.part, jsonb_build_object('held', true, 'mine', lp.holder_login = auth.uid(), 'from_seq', lp.from_seq)), '{}'::jsonb)
                  from public.live_parts lp where lp.live_id = l.id and lp.left_at is null)),
    'pitches', (select coalesce(jsonb_agg(jsonb_build_object('seq', x.seq, 'type', x.type, 'target_row', x.target_row,
                  'target_col', x.target_col, 'batter_side', x.batter_side, 'intent_at', x.intent_at, 'no_pitch', x.no_pitch,
                  'has_outcome', x.outcome is not null, 'outcome_at', x.outcome_at, 'skipped_intent', x.skipped_intent) order by x.seq), '[]'::jsonb)
                  from public.live_pitches x where x.live_id = l.id and x.seq > greatest(0, coalesce(p_after, 0) - 30)))
    from public.live_sessions l where l.id = p_live
$$;
revoke all on function public.c1_live_view(uuid, integer) from public, anon, authenticated;

-- Start a live session (the starter charts one part). Refused while an open one exists for this pitcher and kind:
-- the app offers its open part instead (live_exists).
create or replace function public.live_start(p_pitcher uuid, p_team uuid, p_kind text, p_part text, p_profile uuid, p_after uuid default null)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare v_id uuid; v_other uuid; v_sport text;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  if p_kind not in ('bullpen', 'game') or p_part not in ('intent', 'outcome') then return jsonb_build_object('ok', false, 'error', 'invalid'); end if;
  if not public.c1_can_chart(p_pitcher, p_team) then return jsonb_build_object('ok', false, 'error', 'not_entitled'); end if;
  if p_profile is not null and not (public.is_my_profile(p_profile) or (p_profile = p_pitcher and public.can_chart_for(p_pitcher))) then
    return jsonb_build_object('ok', false, 'error', 'not_entitled');
  end if;
  select l.id into v_other from public.live_sessions l
   where l.pitcher_id = p_pitcher and l.kind = p_kind and l.closed_at is null and l.last_activity_at > now() - interval '3 hours'
     and (p_after is null or l.id <> p_after) limit 1;
  if v_other is not null then
    return jsonb_build_object('ok', false, 'error', 'live_exists', 'live_id', v_other);
  end if;
  select p.sport into v_sport from public.profiles p where p.id = p_pitcher;
  insert into public.live_sessions (pitcher_id, team_id, kind, sport, started_by_login) values (p_pitcher, p_team, p_kind, v_sport, auth.uid())
    returning id into v_id;
  insert into public.live_parts (live_id, part, holder_login, holder_profile) values (v_id, p_part, auth.uid(), p_profile);
  -- a pitching change: the previous pitcher's live session points at this one ("Keep calling for ...?")
  if p_after is not null and public.c1_my_part(p_after) is not null then
    update public.live_sessions set successor_id = v_id where id = p_after;
  end if;
  return jsonb_build_object('ok', true, 'live_id', v_id) || public.c1_live_view(v_id, 0);
end;
$$;
revoke all on function public.live_start(uuid, uuid, text, text, uuid, uuid) from public, anon;
grant execute on function public.live_start(uuid, uuid, text, text, uuid, uuid) to authenticated;

-- Take the open part. The first to tap gets it (the unique index); they pick up at the next pitch.
create or replace function public.live_join(p_live uuid, p_part text, p_profile uuid)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare l public.live_sessions%rowtype; v_from int;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  select * into l from public.live_sessions where id = p_live for update;
  if not found or l.closed_at is not null then return jsonb_build_object('ok', false, 'error', 'closed'); end if;
  if not public.c1_can_chart(l.pitcher_id, l.team_id) then return jsonb_build_object('ok', false, 'error', 'not_entitled'); end if;
  if p_profile is not null and not (public.is_my_profile(p_profile) or (p_profile = l.pitcher_id and public.can_chart_for(l.pitcher_id))) then
    return jsonb_build_object('ok', false, 'error', 'not_entitled');
  end if;
  if public.c1_my_part(p_live) is not null then return jsonb_build_object('ok', false, 'error', 'already_holding'); end if;
  v_from := l.next_seq;
  begin
    insert into public.live_parts (live_id, part, holder_login, holder_profile, from_seq) values (p_live, p_part, auth.uid(), p_profile, v_from);
  exception when unique_violation then
    return jsonb_build_object('ok', false, 'error', 'taken');
  end;
  update public.live_sessions set last_activity_at = now() where id = p_live;
  return jsonb_build_object('ok', true, 'from_seq', v_from) || public.c1_live_view(p_live, v_from);
end;
$$;
revoke all on function public.live_join(uuid, text, uuid) from public, anon;
grant execute on function public.live_join(uuid, text, uuid) to authenticated;

-- Leave (End session & save): the part is open again from the next pitch; the session closes when nobody holds one.
create or replace function public.live_leave(p_live uuid, p_piece uuid default null)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
begin
  update public.live_parts set left_at = now(), piece_session_id = coalesce(p_piece, piece_session_id)
   where live_id = p_live and holder_login = auth.uid() and left_at is null;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_holding'); end if;
  update public.live_sessions set last_activity_at = now(),
         closed_at = case when exists (select 1 from public.live_parts where live_id = p_live and left_at is null) then null else now() end
   where id = p_live;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.live_leave(uuid, uuid) from public, anon;
grant execute on function public.live_leave(uuid, uuid) to authenticated;

-- What a holder polls (1-3 s while charting).
create or replace function public.live_poll(p_live uuid, p_after integer default 0)
 returns jsonb language plpgsql stable security definer set search_path to '' as $$
begin
  if exists (select 1 from public.live_parts where live_id = p_live and holder_login = auth.uid()) then   -- held now, or before (the last poll after leaving)
    return public.c1_live_view(p_live, p_after);
  end if;
  return jsonb_build_object('ok', false, 'error', 'not_holding');
end;
$$;
revoke all on function public.live_poll(uuid, integer) from public, anon;
grant execute on function public.live_poll(uuid, integer) to authenticated;

-- Intent: Confirm Pitch. The server numbers the pitch.
create or replace function public.live_put_intent(p_live uuid, p_type text, p_row int, p_col int, p_side text)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare v_seq int;
begin
  if public.c1_my_part(p_live) is distinct from 'intent' then return jsonb_build_object('ok', false, 'error', 'not_holding'); end if;
  if p_type is null or char_length(p_type) > 40 or p_row not between 0 and 4 or p_col not between 0 and 4 then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  update public.live_sessions set next_seq = next_seq + 1, last_activity_at = now() where id = p_live returning next_seq - 1 into v_seq;
  insert into public.live_pitches (live_id, seq, type, target_row, target_col, batter_side, intent_at, intent_login)
  values (p_live, v_seq, p_type, p_row, p_col, case when p_side in ('R', 'L') then p_side end, now(), auth.uid());
  return jsonb_build_object('ok', true, 'seq', v_seq, 'server_now', now());
end;
$$;
revoke all on function public.live_put_intent(uuid, text, int, int, text) from public, anon;
grant execute on function public.live_put_intent(uuid, text, int, int, text) to authenticated;

-- Intent: Back on a confirmed pitch -- only while nobody has recorded against it and no later call was confirmed
-- (Joel: "Back is locked once someone builds on it").
create or replace function public.live_unconfirm(p_live uuid, p_seq int)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare x public.live_pitches%rowtype;
begin
  if public.c1_my_part(p_live) is distinct from 'intent' then return jsonb_build_object('ok', false, 'error', 'not_holding'); end if;
  select * into x from public.live_pitches where live_id = p_live and seq = p_seq for update;
  if not found or x.intent_at is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if x.outcome is not null then return jsonb_build_object('ok', false, 'error', 'locked'); end if;
  if exists (select 1 from public.live_pitches where live_id = p_live and seq > p_seq and intent_at is not null) then
    return jsonb_build_object('ok', false, 'error', 'locked');
  end if;
  delete from public.live_pitches where live_id = p_live and seq = p_seq;
  update public.live_sessions set last_activity_at = now() where id = p_live;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.live_unconfirm(uuid, int) from public, anon;
grant execute on function public.live_unconfirm(uuid, int) to authenticated;

-- Intent: "No pitch" -- the last call was never thrown; the other device skips it.
create or replace function public.live_no_pitch(p_live uuid, p_seq int)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
begin
  if public.c1_my_part(p_live) is distinct from 'intent' then return jsonb_build_object('ok', false, 'error', 'not_holding'); end if;
  update public.live_pitches set no_pitch = true where live_id = p_live and seq = p_seq and outcome is null and intent_at is not null;
  if not found then return jsonb_build_object('ok', false, 'error', 'locked'); end if;
  update public.live_sessions set last_activity_at = now() where id = p_live;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.live_no_pitch(uuid, int) from public, anon;
grant execute on function public.live_no_pitch(uuid, int) to authenticated;

-- Outcome: the other half of a called pitch (p_seq), or a pitch of its own when nobody holds Intent, or "Chart without
-- it" (p_skip) when the call never arrived.
create or replace function public.live_put_outcome(p_live uuid, p_seq int, p_outcome jsonb, p_skip boolean default false)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare v_seq int; x public.live_pitches%rowtype;
begin
  if public.c1_my_part(p_live) is distinct from 'outcome' then return jsonb_build_object('ok', false, 'error', 'not_holding'); end if;
  if p_outcome is null or jsonb_typeof(p_outcome) <> 'object' or pg_column_size(p_outcome) > 8192 then
    return jsonb_build_object('ok', false, 'error', 'invalid');
  end if;
  if p_seq is not null then
    select * into x from public.live_pitches where live_id = p_live and seq = p_seq for update;
    if not found or x.intent_at is null or x.no_pitch or x.outcome is not null then
      return jsonb_build_object('ok', false, 'error', 'not_open');
    end if;
    update public.live_pitches set outcome = p_outcome, outcome_at = now(), outcome_login = auth.uid() where live_id = p_live and seq = p_seq;
    v_seq := p_seq;
  else
    -- a pitch of its own: only with nobody on Intent, or skipping a call that never came
    if not coalesce(p_skip, false) and exists (select 1 from public.live_parts where live_id = p_live and part = 'intent' and left_at is null) then
      return jsonb_build_object('ok', false, 'error', 'wait_for_intent');
    end if;
    update public.live_sessions set next_seq = next_seq + 1 where id = p_live returning next_seq - 1 into v_seq;
    insert into public.live_pitches (live_id, seq, outcome, outcome_at, outcome_login, skipped_intent)
    values (p_live, v_seq, p_outcome, now(), auth.uid(), coalesce(p_skip, false));
  end if;
  update public.live_sessions set last_activity_at = now() where id = p_live;
  return jsonb_build_object('ok', true, 'seq', v_seq, 'server_now', now());
end;
$$;
revoke all on function public.live_put_outcome(uuid, int, jsonb, boolean) from public, anon;
grant execute on function public.live_put_outcome(uuid, int, jsonb, boolean) to authenticated;

-- A device that charted without a signal sends what it charted, in order, with each tap's time corrected to the
-- server's clock (Joel, Nov 25: matched by time). Rule (plans/c1-preconditions.md section 8): an outcome at t matches
-- the earliest open call confirmed 0.5-30 s before it (+-2 s for the clocks); a call at t matches the earliest pitch
-- whose outcome came 0.5-30 s after it and has no call. Order never crosses (each match is after the device's last).
-- Anything that doesn't line up is left empty for that part: "we can only report what we can reconcile."
create or replace function public.live_put_offline(p_live uuid, p_items jsonb)
 returns jsonb language plpgsql volatile security definer set search_path to '' as $$
declare v_part text := public.c1_my_part(p_live); it jsonb; t timestamptz; x public.live_pitches%rowtype;
        v_last int := 0; v_kept int := 0; v_dropped int := 0; v_seq int; v_res jsonb := '[]'::jsonb;
begin
  if v_part is null then return jsonb_build_object('ok', false, 'error', 'not_holding'); end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) > 300 then return jsonb_build_object('ok', false, 'error', 'invalid'); end if;
  for it in select value from jsonb_array_elements(p_items) loop
    t := (it ->> 'at')::timestamptz;
    v_seq := null;
    if v_part = 'outcome' then
      select * into x from public.live_pitches
       where live_id = p_live and seq > v_last and intent_at is not null and not no_pitch and outcome is null
         and t - intent_at between interval '0.5 seconds' - interval '2 seconds' and interval '30 seconds' + interval '2 seconds'
       order by seq limit 1;
      if found then
        update public.live_pitches set outcome = it -> 'outcome', outcome_at = t, outcome_login = auth.uid() where live_id = p_live and seq = x.seq;
        v_seq := x.seq;
      elsif not exists (select 1 from public.live_parts where live_id = p_live and part = 'intent' and left_at is null)
            and not exists (select 1 from public.live_pitches where live_id = p_live and intent_at is not null and outcome is null and not no_pitch) then
        update public.live_sessions set next_seq = next_seq + 1 where id = p_live returning next_seq - 1 into v_seq;   -- nobody calling: its own pitch
        insert into public.live_pitches (live_id, seq, outcome, outcome_at, outcome_login) values (p_live, v_seq, it -> 'outcome', t, auth.uid());
      end if;
    else
      select * into x from public.live_pitches
       where live_id = p_live and seq > v_last and intent_at is null and outcome is not null and not skipped_intent
         and outcome_at - t between interval '0.5 seconds' - interval '2 seconds' and interval '30 seconds' + interval '2 seconds'
       order by seq limit 1;
      if found then
        update public.live_pitches set type = it ->> 'type', target_row = (it ->> 'row')::smallint, target_col = (it ->> 'col')::smallint,
               batter_side = case when it ->> 'side' in ('R', 'L') then it ->> 'side' end, intent_at = t, intent_login = auth.uid()
         where live_id = p_live and seq = x.seq;
        v_seq := x.seq;
      end if;
    end if;
    if v_seq is null then v_dropped := v_dropped + 1; else v_kept := v_kept + 1; v_last := v_seq; end if;
    v_res := v_res || jsonb_build_array(jsonb_build_object('key', it ->> 'key', 'seq', v_seq));
  end loop;
  update public.live_sessions set last_activity_at = now() where id = p_live;
  return jsonb_build_object('ok', true, 'kept', v_kept, 'dropped', v_dropped, 'items', v_res);
end;
$$;
revoke all on function public.live_put_offline(uuid, jsonb) from public, anon;
grant execute on function public.live_put_offline(uuid, jsonb) to authenticated;

-- A game: the at-bat and the batter side, so the other device stays with the same batter.
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
revoke all on function public.live_set_state(uuid, jsonb) from public, anon;
grant execute on function public.live_set_state(uuid, jsonb) to authenticated;

-- The Live marks: open live sessions (active in the last 3 hours) for pitchers the caller can chart, with the part
-- that's open; never one the caller is already in. Names come from the caller's own roster on the device.
create or replace function public.live_summary()
 returns jsonb language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('live_id', l.id, 'pitcher_id', l.pitcher_id, 'team_id', l.team_id, 'kind', l.kind,
           'open', (select coalesce(jsonb_agg(p.part), '[]'::jsonb) from unnest(array['intent', 'outcome']) p(part)
                     where not exists (select 1 from public.live_parts lp where lp.live_id = l.id and lp.part = p.part and lp.left_at is null)),
           'started_at', l.started_at) order by l.started_at desc), '[]'::jsonb)
    from public.live_sessions l
   where l.closed_at is null and l.last_activity_at > now() - interval '3 hours'
     and not exists (select 1 from public.live_parts lp where lp.live_id = l.id and lp.holder_login = auth.uid() and lp.left_at is null)
     and exists (select 1 from unnest(array['intent', 'outcome']) p(part)
                  where not exists (select 1 from public.live_parts lp where lp.live_id = l.id and lp.part = p.part and lp.left_at is null))
     and public.c1_can_chart(l.pitcher_id, l.team_id)
$$;
revoke all on function public.live_summary() from public, anon;
grant execute on function public.live_summary() to authenticated;
