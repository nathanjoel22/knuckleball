-- F1-C1: Chat inside a training facility -- the facility thread (the manager posts to everyone) and private threads
-- (a pitcher's coach and the pitcher / the parent who created them). Packet: plans/f1-training-facilities.md v2;
-- decisions: plans/f1c1-preconditions.md (Joel, Oct 29 2026). No guardian link here (decision B: its own stage).
-- Every chat table is reached only through the SECURITY DEFINER functions below: no client grant, no policy (the
-- policy count stays 32). Who may read or post is chat_access(), computed from today's memberships, so a pitcher who
-- moves coaches takes the conversation with them and the new coach reads its history.
-- Rollback: supabase/rollback/20261031000000_f1c1_chat_down.sql. Test: supabase/tests/f1c1_chat_acceptance.sql.

-- ---------------------------------------------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------------------------------------------

create table public.chat_threads (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations(id) on delete cascade,
  kind            text not null constraint chat_threads_kind_check check (kind in ('facility', 'private')),
  team_id         uuid references public.teams(id) on delete cascade,          -- private: the side
  group_id        uuid references public.coach_groups(id) on delete set null,  -- private: the coach's group
  pitcher_id      uuid references public.profiles(id) on delete set null,      -- private: whose family
  created_at      timestamptz not null default now(),
  last_message_at timestamptz,
  archived_at     timestamptz,          -- closed: read-only; the manager reads it until clear_after
  archived_by     uuid,                 -- the login that closed it (null: closed by the system)
  clear_after     timestamptz,          -- the daily job deletes it after this (archived_at + 90 days)
  constraint chat_threads_facility_shape check (kind = 'private' or (team_id is null and group_id is null and pitcher_id is null))
);
create unique index chat_threads_one_facility on public.chat_threads (org_id) where kind = 'facility';
create unique index chat_threads_one_open_private on public.chat_threads (group_id, pitcher_id) where kind = 'private' and archived_at is null;
create index chat_threads_org on public.chat_threads (org_id);
create index chat_threads_pitcher on public.chat_threads (pitcher_id);

create table public.chat_messages (
  id                uuid primary key default gen_random_uuid(),
  thread_id         uuid not null references public.chat_threads(id) on delete cascade,
  author_profile_id uuid references public.profiles(id) on delete set null,
  author_login      uuid references auth.users(id) on delete set null,
  author_name       text not null,
  author_role       text not null constraint chat_messages_role_check check (author_role in ('manager', 'coach', 'pitcher', 'parent')),
  body              text not null,
  created_at        timestamptz not null default now(),
  deleted_at        timestamptz,          -- "This message was deleted" (the text stays for the manager)
  pinned_at         timestamptz,
  pinned_by         uuid,
  author_deleted    boolean not null default false,   -- an account purge: "Deleted account", text blanked (decision D)
  constraint chat_messages_body_length check (author_deleted or char_length(btrim(body)) between 1 and 2000)
);
create index chat_messages_thread on public.chat_messages (thread_id, created_at);
create index chat_messages_author on public.chat_messages (author_login);

create table public.chat_reads (
  thread_id    uuid not null references public.chat_threads(id) on delete cascade,
  login        uuid not null references auth.users(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (thread_id, login)
);

create table public.chat_reports (
  id          uuid primary key default gen_random_uuid(),
  message_id  uuid not null references public.chat_messages(id) on delete cascade,
  reported_by uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid,
  unique (message_id, reported_by)
);

alter table public.chat_threads enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_reads enable row level security;
alter table public.chat_reports enable row level security;
revoke all on public.chat_threads, public.chat_messages, public.chat_reads, public.chat_reports from anon, authenticated;

-- ---------------------------------------------------------------------------------------------------------------
-- 2. Who may read or post
-- ---------------------------------------------------------------------------------------------------------------

-- The caller's login is this pitcher's (their own login) or the parent who created them (a parent-created player
-- sits on the parent's login). 13-17 logins need the guardian's approval first, and the age must have been answered
-- (the report gate's rule; decision C).
create function public.chat_family_ok(p_pitcher uuid) returns boolean
  language sql stable security definer set search_path to '' as $$
  select coalesce((
    select p.account_id = auth.uid()
           and acct.age_attestation is not null
           and (acct.age_attestation = 'adult' or acct.guardian_consented_at is not null)
      from public.profiles p join public.profiles acct on acct.id = p.account_id
     where p.id = p_pitcher), false);
$$;

-- 'post', 'read' or null for the caller on one thread.
--   facility: the manager posts; every coach on either side, and every pitcher / parent of a pitcher on either side,
--             reads.
--   private:  the pitcher's coach (the group's coach) posts, then the side's manager reads (manager = also a coach:
--             their own group posts), then -- while open -- the family posts; once closed the family keeps reading
--             (departed families: read-only until it clears) and the coach no longer sees it.
create function public.chat_access(p_thread uuid) returns text
  language plpgsql stable security definer set search_path to '' as $$
declare t public.chat_threads%rowtype; v_uid uuid := auth.uid();
begin
  if v_uid is null then return null; end if;
  select * into t from public.chat_threads where id = p_thread;
  if not found then return null; end if;
  if t.kind = 'facility' then
    if exists (select 1 from public.organizations o where o.id = t.org_id and o.manager_login = v_uid) then return 'post'; end if;
    if exists (select 1 from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id join public.teams tt on tt.id = tc.team_id
                where tt.org_id = t.org_id and pr.account_id = v_uid) then return 'read'; end if;
    if exists (select 1 from public.pitcher_teams pt join public.teams tt on tt.id = pt.team_id
                where tt.org_id = t.org_id and public.chat_family_ok(pt.pitcher_id)) then return 'read'; end if;
    return null;
  end if;
  if t.archived_at is null and exists (select 1 from public.coach_groups g join public.profiles pr on pr.id = g.coach_id
                                        where g.id = t.group_id and pr.account_id = v_uid) then return 'post'; end if;
  if public.is_org_manager(t.team_id) then return 'read'; end if;
  if t.pitcher_id is null or not public.chat_family_ok(t.pitcher_id) then return null; end if;
  if t.archived_at is not null then return 'read'; end if;
  if exists (select 1 from public.coach_group_members m where m.group_id = t.group_id and m.pitcher_id = t.pitcher_id) then return 'post'; end if;
  return 'read';
end;
$$;
revoke execute on function public.chat_family_ok(uuid), public.chat_access(uuid) from public, anon;

-- The orgs the caller is connected to (manager, coach on a side, or family of a pitcher on a side).
create function public.chat_my_orgs() returns setof uuid
  language sql stable security definer set search_path to '' as $$
  select o.id from public.organizations o where o.manager_login = auth.uid()
  union
  select tt.org_id from public.team_coaches tc join public.profiles pr on pr.id = tc.coach_id join public.teams tt on tt.id = tc.team_id
   where pr.account_id = auth.uid() and tt.org_id is not null
  union
  select tt.org_id from public.pitcher_teams pt join public.profiles p on p.id = pt.pitcher_id join public.teams tt on tt.id = pt.team_id
   where p.account_id = auth.uid() and tt.org_id is not null and public.chat_family_ok(pt.pitcher_id)
  union   -- a departed family still reads its closed threads
  select t.org_id from public.chat_threads t join public.profiles p on p.id = t.pitcher_id where p.account_id = auth.uid();
$$;
revoke execute on function public.chat_my_orgs() from public, anon;

-- ---------------------------------------------------------------------------------------------------------------
-- 3. What the app calls
-- ---------------------------------------------------------------------------------------------------------------

-- The caller's threads (any they can read), newest first, with the unread count. A private thread shows once it has
-- a message; the facility thread always shows for its manager.
create function public.chat_my_threads() returns table (
  thread_id uuid, kind text, team_id uuid, sport text, title text, subtitle text, access text, archived boolean,
  last_at timestamptz, last_preview text, last_author text, unread integer, i_manage boolean)
  language plpgsql stable security definer set search_path to '' as $$
declare t record; v_access text; v_uid uuid := auth.uid();
begin
  for t in select th.*, o.name as org_name, o.manager_login,
                  tm.sport as t_sport, p.full_name as pitcher_name, cp.full_name as coach_name
             from public.chat_threads th join public.organizations o on o.id = th.org_id
             left join public.teams tm on tm.id = th.team_id
             left join public.profiles p on p.id = th.pitcher_id
             left join public.coach_groups g on g.id = th.group_id
             left join public.profiles cp on cp.id = g.coach_id
            where th.org_id in (select public.chat_my_orgs()) loop
    v_access := public.chat_access(t.id);
    continue when v_access is null;
    continue when t.last_message_at is null and not (t.kind = 'facility' and v_access = 'post');
    thread_id := t.id; kind := t.kind; team_id := t.team_id; sport := t.t_sport; access := v_access;
    archived := t.archived_at is not null; last_at := t.last_message_at;
    i_manage := t.manager_login = v_uid;
    if t.kind = 'facility' then
      title := 'Everyone at ' || t.org_name; subtitle := null;
    elsif t.pitcher_id is not null and exists (select 1 from public.profiles x where x.id = t.pitcher_id and x.account_id = v_uid) then
      title := coalesce(t.coach_name, 'Former coach'); subtitle := t.pitcher_name;    -- the family sees the coach
    else
      title := coalesce(t.pitcher_name, 'Deleted account'); subtitle := coalesce(t.coach_name, 'No coach');
    end if;
    select case when m.deleted_at is not null then 'This message was deleted' when m.author_deleted then 'Deleted account'
                else left(m.body, 140) end, m.author_name
      into last_preview, last_author
      from public.chat_messages m where m.thread_id = t.id order by m.created_at desc limit 1;
    select count(*) into unread from public.chat_messages m
     where m.thread_id = t.id and m.author_login is distinct from v_uid and m.deleted_at is null
       and m.created_at > coalesce((select r.last_read_at from public.chat_reads r where r.thread_id = t.id and r.login = v_uid), '-infinity');
    return next;
  end loop;
end;
$$;

-- The tab's badge: whether Chat shows at all, the unread count, and (a manager) the open reports. A manager's count
-- is the facility thread plus their own trainees' threads, not every family's (they read those when they choose).
create function public.chat_summary() returns jsonb
  language sql stable security definer set search_path to '' as $$
  select jsonb_build_object(
    'enabled', exists (select public.chat_my_orgs()),
    'unread', coalesce((select sum(t.unread) from public.chat_my_threads() t where t.access = 'post' or not t.i_manage), 0),
    'reports', (select count(*) from public.chat_reports r join public.chat_messages m on m.id = r.message_id
                  join public.chat_threads th on th.id = m.thread_id join public.organizations o on o.id = th.org_id
                 where r.resolved_at is null and o.manager_login = auth.uid()));
$$;

-- Who the compose button offers (decision: the packet's model). Manager: the facility thread. Coach: each pitcher in
-- each of their groups. Pitcher / parent: each coach the pitcher has here ("My coach").
create function public.chat_compose_targets() returns jsonb
  language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(x order by x ->> 'sort'), '[]'::jsonb) from (
    select jsonb_build_object('kind', 'facility', 'org_id', o.id, 'label', 'Everyone at ' || o.name, 'sort', '0' || o.name) x
      from public.organizations o where o.manager_login = auth.uid()
    union all
    select jsonb_build_object('kind', 'private', 'group_id', g.id, 'pitcher_id', p.id, 'label', p.full_name,
                              'detail', 'Family of ' || p.full_name, 'sport', tm.sport, 'sort', '1' || p.full_name)
      from public.coach_groups g join public.profiles cp on cp.id = g.coach_id and cp.account_id = auth.uid()
      join public.coach_group_members m on m.group_id = g.id join public.profiles p on p.id = m.pitcher_id
      join public.teams tm on tm.id = g.team_id
     where tm.kind = 'facility' and tm.archived_at is null
    union all
    select jsonb_build_object('kind', 'private', 'group_id', g.id, 'pitcher_id', p.id, 'label', cp.full_name,
                              'detail', 'Coach for ' || p.full_name, 'sport', tm.sport, 'sort', '2' || cp.full_name)
      from public.profiles p join public.coach_group_members m on m.pitcher_id = p.id
      join public.coach_groups g on g.id = m.group_id join public.profiles cp on cp.id = g.coach_id
      join public.teams tm on tm.id = g.team_id
     where p.account_id = auth.uid() and p.role = 'pitcher' and tm.kind = 'facility' and tm.archived_at is null
       and public.chat_family_ok(p.id)
  ) s;
$$;

-- Opens (or makes) a thread the caller may post in, and returns its id.
create function public.chat_open(p_kind text, p_org uuid, p_group uuid, p_pitcher uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_id uuid; v_team uuid; v_org uuid;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'error', 'not_authenticated'); end if;
  if p_kind = 'facility' then
    if not exists (select 1 from public.organizations o where o.id = p_org and o.manager_login = auth.uid()) then
      return jsonb_build_object('ok', false, 'error', 'not_allowed');
    end if;
    insert into public.chat_threads (org_id, kind) values (p_org, 'facility') on conflict do nothing;
    select id into v_id from public.chat_threads where org_id = p_org and kind = 'facility';
    return jsonb_build_object('ok', true, 'thread_id', v_id);
  end if;
  select g.team_id, tm.org_id into v_team, v_org from public.coach_groups g join public.teams tm on tm.id = g.team_id
   where g.id = p_group and tm.kind = 'facility';
  if v_team is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not exists (select 1 from public.coach_group_members m where m.group_id = p_group and m.pitcher_id = p_pitcher) then
    return jsonb_build_object('ok', false, 'error', 'not_in_group');
  end if;
  if not (exists (select 1 from public.coach_groups g join public.profiles pr on pr.id = g.coach_id where g.id = p_group and pr.account_id = auth.uid())
          or public.chat_family_ok(p_pitcher)) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  insert into public.chat_threads (org_id, kind, team_id, group_id, pitcher_id) values (v_org, 'private', v_team, p_group, p_pitcher)
    on conflict (group_id, pitcher_id) where kind = 'private' and archived_at is null do nothing;
  select id into v_id from public.chat_threads where kind = 'private' and group_id = p_group and pitcher_id = p_pitcher and archived_at is null;
  return jsonb_build_object('ok', true, 'thread_id', v_id);
end;
$$;

-- A thread's messages, oldest first (the newest p_limit). A deleted message's text goes only to the manager.
create function public.chat_thread(p_thread uuid, p_limit integer default 200) returns jsonb
  language plpgsql stable security definer set search_path to '' as $$
declare v_access text := public.chat_access(p_thread); v_mgr boolean; t public.chat_threads%rowtype; v_coach boolean;
begin
  if v_access is null then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  select * into t from public.chat_threads where id = p_thread;
  v_mgr := exists (select 1 from public.organizations o where o.id = t.org_id and o.manager_login = auth.uid());
  -- pins: the thread's coach (private) or the manager (facility), while they can post
  v_coach := v_access = 'post' and (t.kind = 'facility' or exists (select 1 from public.coach_groups g join public.profiles pr on pr.id = g.coach_id
                                                                     where g.id = t.group_id and pr.account_id = auth.uid()));
  return jsonb_build_object('ok', true, 'access', v_access, 'kind', t.kind, 'archived', t.archived_at is not null,
    'clear_after', t.clear_after, 'can_pin', v_coach, 'can_close', v_coach and t.kind = 'private',
    'messages', coalesce((select jsonb_agg(jsonb_build_object(
        'id', m.id, 'author', m.author_name, 'role', m.author_role, 'mine', m.author_login = auth.uid(),
        'body', case when m.author_deleted then null when m.deleted_at is not null and not v_mgr then null else m.body end,
        'deleted', m.deleted_at is not null, 'author_deleted', m.author_deleted,
        'pinned', m.pinned_at is not null, 'at', m.created_at) order by m.created_at)
      from (select * from public.chat_messages where thread_id = p_thread order by created_at desc limit greatest(1, least(p_limit, 500))) m), '[]'::jsonb));
end;
$$;

-- Posts one message. Who it's from: the manager (facility thread), the group's coach, the pitcher themself, or the
-- parent who created the player.
create function public.chat_post(p_thread uuid, p_body text) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare t public.chat_threads%rowtype; v_body text := btrim(coalesce(p_body, '')); v_prof uuid; v_role text; v_name text; v_id uuid;
begin
  if public.chat_access(p_thread) is distinct from 'post' then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if char_length(v_body) < 1 or char_length(v_body) > 2000 then return jsonb_build_object('ok', false, 'error', 'invalid_length'); end if;
  select * into t from public.chat_threads where id = p_thread;
  if t.kind = 'facility' then
    select tm.coach_id into v_prof from public.teams tm where tm.org_id = t.org_id order by tm.sport limit 1;
    v_role := 'manager';
  else
    select g.coach_id into v_prof from public.coach_groups g join public.profiles pr on pr.id = g.coach_id
     where g.id = t.group_id and pr.account_id = auth.uid();
    if v_prof is not null then v_role := 'coach';
    else
      select case when p.managed_by is null then p.id else p.managed_by end, case when p.managed_by is null then 'pitcher' else 'parent' end
        into v_prof, v_role from public.profiles p where p.id = t.pitcher_id;
    end if;
  end if;
  select full_name into v_name from public.profiles where id = v_prof;
  insert into public.chat_messages (thread_id, author_profile_id, author_login, author_name, author_role, body)
    values (p_thread, v_prof, auth.uid(), coalesce(v_name, 'Someone'), v_role, v_body) returning id into v_id;
  update public.chat_threads set last_message_at = now() where id = p_thread;
  insert into public.chat_reads (thread_id, login, last_read_at) values (p_thread, auth.uid(), now())
    on conflict (thread_id, login) do update set last_read_at = excluded.last_read_at;
  return jsonb_build_object('ok', true, 'id', v_id);
end;
$$;

create function public.chat_mark_read(p_thread uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
begin
  if public.chat_access(p_thread) is null then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  insert into public.chat_reads (thread_id, login, last_read_at) values (p_thread, auth.uid(), now())
    on conflict (thread_id, login) do update set last_read_at = excluded.last_read_at;
  return jsonb_build_object('ok', true);
end;
$$;

-- The author deletes their own message: "This message was deleted" for everyone; the text stays for the manager.
create function public.chat_delete_message(p_message uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
begin
  update public.chat_messages set deleted_at = now(), pinned_at = null, pinned_by = null
   where id = p_message and author_login = auth.uid() and deleted_at is null and not author_deleted;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- Pin / unpin (the thread's coach, or the manager on the facility thread); at most 5 pinned per thread.
create function public.chat_pin(p_message uuid, p_on boolean) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_thread uuid; v jsonb;
begin
  select thread_id into v_thread from public.chat_messages where id = p_message and deleted_at is null and not author_deleted;
  if v_thread is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  v := public.chat_thread(v_thread, 1);
  if not coalesce((v ->> 'can_pin')::boolean, false) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  if p_on and (select count(*) from public.chat_messages where thread_id = v_thread and pinned_at is not null and id <> p_message) >= 5 then
    return jsonb_build_object('ok', false, 'error', 'pin_limit');
  end if;
  update public.chat_messages set pinned_at = case when p_on then coalesce(pinned_at, now()) end,
                                  pinned_by = case when p_on then auth.uid() end
   where id = p_message;
  return jsonb_build_object('ok', true);
end;
$$;

-- Anyone who can read the thread can report a message to the facility's manager.
create function public.chat_report(p_message uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_thread uuid;
begin
  select thread_id into v_thread from public.chat_messages where id = p_message;
  if v_thread is null or public.chat_access(v_thread) is null then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  insert into public.chat_reports (message_id, reported_by) values (p_message, auth.uid()) on conflict do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

-- The manager's open reports, and resolving one.
create function public.chat_open_reports() returns jsonb
  language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'thread_id', m.thread_id, 'message_id', m.id, 'author', m.author_name,
           'body', case when m.author_deleted then null else m.body end, 'deleted', m.deleted_at is not null, 'at', m.created_at,
           'reported_at', r.created_at) order by r.created_at desc), '[]'::jsonb)
    from public.chat_reports r join public.chat_messages m on m.id = r.message_id
    join public.chat_threads th on th.id = m.thread_id join public.organizations o on o.id = th.org_id
   where r.resolved_at is null and o.manager_login = auth.uid();
$$;
create function public.chat_resolve_report(p_report uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
begin
  update public.chat_reports r set resolved_at = now(), resolved_by = auth.uid()
    from public.chat_messages m, public.chat_threads th, public.organizations o
   where r.id = p_report and m.id = r.message_id and th.id = m.thread_id and o.id = th.org_id and o.manager_login = auth.uid()
     and r.resolved_at is null;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- A coach "deleting" a private thread closes it: read-only, gone from the coach's list, readable by the manager (and
-- the family) until the daily job clears it after 90 days.
create function public.chat_close(p_thread uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
begin
  if not coalesce((public.chat_thread(p_thread, 1) ->> 'can_close')::boolean, false) then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  update public.chat_threads set archived_at = now(), archived_by = auth.uid(), clear_after = now() + interval '90 days'
   where id = p_thread and archived_at is null;
  return jsonb_build_object('ok', true);
end;
$$;

revoke execute on function public.chat_my_threads(), public.chat_summary(), public.chat_compose_targets(),
  public.chat_open(text, uuid, uuid, uuid), public.chat_thread(uuid, integer), public.chat_post(uuid, text),
  public.chat_mark_read(uuid), public.chat_delete_message(uuid), public.chat_pin(uuid, boolean), public.chat_report(uuid),
  public.chat_open_reports(), public.chat_resolve_report(uuid), public.chat_close(uuid) from public, anon;

-- ---------------------------------------------------------------------------------------------------------------
-- 4. Threads follow the groups; the daily clear
-- ---------------------------------------------------------------------------------------------------------------

-- A pitcher leaving a coach's group (removed, or off the side, or the coach gone) closes that private thread: the
-- family keeps reading it until it clears (departed families, read-only).
create function public.f1c1_close_on_leave() returns trigger
  language plpgsql security definer set search_path to '' as $$
begin
  update public.chat_threads set archived_at = now(), clear_after = now() + interval '90 days'
   where kind = 'private' and group_id = old.group_id and pitcher_id = old.pitcher_id and archived_at is null;
  return old;
end;
$$;
create trigger coach_group_members_f1c1_chat after delete on public.coach_group_members
  for each row execute function public.f1c1_close_on_leave();

-- Deletes closed threads 90 days after they closed (pg_cron, daily). Returns how many.
create function public.chat_clear_archived() returns integer
  language plpgsql security definer set search_path to '' as $$
declare n int;
begin
  delete from public.chat_threads where clear_after is not null and clear_after < now();
  get diagnostics n = row_count;
  return n;
end;
$$;
revoke execute on function public.f1c1_close_on_leave(), public.chat_clear_archived() from public, anon, authenticated;
select cron.schedule('f1c1-chat-clear', '41 9 * * *', 'select public.chat_clear_archived()');

-- ---------------------------------------------------------------------------------------------------------------
-- 5. Two existing functions, the live text with only the marked lines added
-- ---------------------------------------------------------------------------------------------------------------

create or replace function public.move_between_groups(p_pitcher uuid, p_from uuid, p_to uuid) returns jsonb
  language plpgsql security definer set search_path to '' as $$
declare v_team uuid; v_to_team uuid;
begin
  select team_id into v_team from public.coach_groups where id = p_from;
  select team_id into v_to_team from public.coach_groups where id = p_to;
  if v_team is null or v_to_team is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if v_team <> v_to_team then return jsonb_build_object('ok', false, 'error', 'other_side'); end if;
  if not public.is_org_manager(v_team) then return jsonb_build_object('ok', false, 'error', 'not_allowed'); end if;
  -- F1-C1: the open private thread goes with the pitcher (unless one with the new coach is already open), before the
  -- membership row goes -- the leave trigger then finds nothing to close
  update public.chat_threads set group_id = p_to
   where kind = 'private' and group_id = p_from and pitcher_id = p_pitcher and archived_at is null
     and not exists (select 1 from public.chat_threads x where x.kind = 'private' and x.group_id = p_to and x.pitcher_id = p_pitcher and x.archived_at is null);
  delete from public.coach_group_members where group_id = p_from and pitcher_id = p_pitcher;
  if not found then return jsonb_build_object('ok', false, 'error', 'not_in_group'); end if;
  insert into public.coach_group_members (group_id, pitcher_id, added_by, flagged_new)
    values (p_to, p_pitcher, public.f1a_my_coach_profile(v_team), false)
    on conflict (group_id, pitcher_id) do nothing;
  return jsonb_build_object('ok', true);
end;
$$;

CREATE OR REPLACE FUNCTION public.a1_purge_profile(p_profile uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_reports text[];
  v_tombstoned int := 0;
  v_pitches int := 0;
  v_notes int := 0;
  v_recharted int := 0;
  s record;
  n int;
  v_child jsonb;
  v_child_profiles int := 0;
begin
  if not exists (select 1 from public.profiles where id = p_profile) then
    return jsonb_build_object('ok', true, 'status', 'already_gone');
  end if;
  if exists (select 1 from public.teams where coach_id = p_profile) then
    return jsonb_build_object('error', 'still_head');
  end if;
  -- a parent's managed players first: deleting the parent's profile would otherwise CASCADE them (and their
  -- sessions) without tombstones
  for s in select id from public.profiles where managed_by = p_profile and id <> p_profile loop
    v_child := public.a1_purge_profile(s.id);
    if v_child ? 'error' then return v_child; end if;
    v_child_profiles := v_child_profiles + 1 + coalesce((v_child->>'profiles')::int, 0);
    v_tombstoned := v_tombstoned + coalesce((v_child->>'tombstoned')::int, 0);
    v_pitches := v_pitches + coalesce((v_child->>'pitches')::int, 0);
    v_notes := v_notes + coalesce((v_child->>'notes')::int, 0);
    v_reports := coalesce(v_reports, '{}') || coalesce(array(select jsonb_array_elements_text(v_child->'reports')), '{}');
  end loop;
  -- the report files of every session this profile pitched (tombstoned or not)
  v_reports := coalesce(v_reports, '{}') || coalesce((select array_agg(report_path) filter (where report_path is not null)
                                                        from public.sessions where pitcher_id = p_profile), '{}');
  -- his own sessions -> tombstones (a record only)
  for s in select id, deleted_at from public.sessions where pitcher_id = p_profile loop
    if s.deleted_at is null then
      select count(*) into n from public.pitches where session_id = s.id;
      v_pitches := v_pitches + n;
      update public.sessions set deleted_at = now(), deleted_by = null, deleted_by_role = 'deleted_account',
             deleted_by_name = null, pitch_count = n
       where id = s.id;
      v_tombstoned := v_tombstoned + 1;
    else
      update public.sessions set deleted_by = null, deleted_by_role = 'deleted_account', deleted_by_name = null
       where id = s.id;
    end if;
    delete from public.game_events where session_id = s.id;
    delete from public.pitches where session_id = s.id;
    delete from public.session_notes where session_id = s.id;
    delete from public.session_opened where session_id = s.id;
  end loop;
  update public.sessions set pitcher_id = null, report_path = null, report_generated_at = null
   where pitcher_id = p_profile;
  -- sessions he charted for other pitchers stay theirs; he becomes a former coach
  update public.sessions set logged_by = null where logged_by = p_profile;
  get diagnostics v_recharted = row_count;
  -- a tombstone he wrote (deleting someone's session as head) loses his name
  update public.sessions set deleted_by = null, deleted_by_role = 'deleted_account', deleted_by_name = null
   where deleted_by = p_profile;
  -- notes he wrote are deleted
  delete from public.session_notes where author_id = p_profile;
  get diagnostics v_notes = row_count;
  delete from public.invites where invited_by = p_profile;
  update public.team_coaches set invited_by = null where invited_by = p_profile;
  -- memberships first: removing a pitcher_teams row makes G3's trigger log a departure that references this profile,
  -- which would then block the profile delete (the CLAUDE.md "deleting a team with a rostered pitcher" landmine)
  delete from public.pitcher_teams where pitcher_id = p_profile;
  delete from public.pitcher_team_departures where pitcher_id = p_profile;
  -- F1-C1 (decision D): their chat messages read "Deleted account" with the text blanked; private threads about them
  -- close (and clear 90 days on, like any closed thread)
  update public.chat_messages set body = '', author_name = 'Deleted account', author_deleted = true, author_profile_id = null,
         pinned_at = null, pinned_by = null
   where author_profile_id = p_profile;
  update public.chat_threads set archived_at = coalesce(archived_at, now()), clear_after = coalesce(clear_after, now() + interval '90 days')
   where pitcher_id = p_profile;
  -- the profile itself; staff rows, red-dot state, accuracy zones and managed players cascade
  delete from public.profiles where id = p_profile;
  return jsonb_build_object('ok', true, 'reports', to_jsonb(coalesce(v_reports, '{}')), 'tombstoned', v_tombstoned,
                            'pitches', v_pitches, 'notes', v_notes, 'recharted', v_recharted, 'profiles', v_child_profiles);
end;
$function$;
