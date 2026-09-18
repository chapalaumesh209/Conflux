-- CONFLUX Production Foundation
--
-- Additive migration only. The cf_ prefix avoids silently colliding with an
-- unknown existing schema. Inspect and map the live project before applying.

create extension if not exists pgcrypto;

create table if not exists public.cf_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[A-Za-z0-9_]{3,30}$'),
  full_name text not null check (char_length(full_name) between 1 and 120),
  headline text check (char_length(headline) <= 180),
  bio text check (char_length(bio) <= 1200),
  city text check (char_length(city) <= 100),
  experience_band text check (experience_band in ('STUDENT', 'EARLY', 'MID', 'SENIOR', 'FOUNDER')),
  skills text[] not null default '{}',
  domains text[] not null default '{}',
  goals text[] not null default '{}',
  current_build text check (char_length(current_build) <= 240),
  looking_for text check (char_length(looking_for) <= 240),
  can_offer text check (char_length(can_offer) <= 240),
  avatar_url text,
  is_discoverable boolean not null default true,
  onboarding_complete boolean not null default false,
  email_verified boolean not null default false,
  github_verified boolean not null default false,
  linkedin_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cf_profile_contacts (
  profile_id uuid primary key references public.cf_profiles(id) on delete cascade,
  github_url text,
  linkedin_url text,
  website_url text,
  email_visible boolean not null default false,
  links_visible_to_connections boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.cf_blocks (
  blocker_id uuid not null references public.cf_profiles(id) on delete cascade,
  blocked_id uuid not null references public.cf_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.cf_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.cf_profiles(id) on delete cascade,
  subject_id uuid not null references public.cf_profiles(id) on delete cascade,
  reason text not null check (reason in ('SPAM', 'HARASSMENT', 'IMPERSONATION', 'SAFETY', 'OTHER')),
  detail text check (char_length(detail) <= 1200),
  created_at timestamptz not null default now(),
  check (reporter_id <> subject_id)
);

create table if not exists public.cf_meet_sessions (
  id uuid primary key default gen_random_uuid(),
  participant_a_id uuid not null references public.cf_profiles(id) on delete cascade,
  participant_b_id uuid not null references public.cf_profiles(id) on delete cascade,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'CLOSED', 'SAFETY_CLOSED')),
  a_decision text check (a_decision in ('CONNECT', 'NEXT')),
  b_decision text check (b_decision in ('CONNECT', 'NEXT')),
  connection_id uuid,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (participant_a_id <> participant_b_id)
);

create table if not exists public.cf_connections (
  id uuid primary key default gen_random_uuid(),
  low_profile_id uuid not null references public.cf_profiles(id) on delete cascade,
  high_profile_id uuid not null references public.cf_profiles(id) on delete cascade,
  meet_session_id uuid references public.cf_meet_sessions(id) on delete set null,
  created_at timestamptz not null default now(),
  check (low_profile_id < high_profile_id),
  unique (low_profile_id, high_profile_id)
);

alter table public.cf_meet_sessions
  add constraint cf_meet_sessions_connection_id_fkey
  foreign key (connection_id) references public.cf_connections(id) on delete set null;

create table if not exists public.cf_meet_messages (
  id uuid primary key default gen_random_uuid(),
  meet_session_id uuid not null references public.cf_meet_sessions(id) on delete cascade,
  sender_id uuid not null references public.cf_profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

create table if not exists public.cf_messages (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.cf_connections(id) on delete cascade,
  sender_id uuid not null references public.cf_profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  client_message_id uuid unique,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.cf_projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.cf_profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 160),
  idea text not null check (char_length(idea) between 1 and 280),
  problem text check (char_length(problem) <= 2000),
  goals text check (char_length(goals) <= 2000),
  stage text not null default 'IDEA' check (stage in ('IDEA', 'PLANNING', 'BUILDING', 'BETA', 'LIVE', 'PAUSED', 'COMPLETED')),
  is_public boolean not null default false,
  collaboration_enabled boolean not null default false,
  live_url text,
  repository_url text,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cf_project_members (
  project_id uuid not null references public.cf_projects(id) on delete cascade,
  profile_id uuid not null references public.cf_profiles(id) on delete cascade,
  role text not null default 'CONTRIBUTOR' check (role in ('OWNER', 'LEAD', 'CONTRIBUTOR', 'VIEWER')),
  responsibilities text check (char_length(responsibilities) <= 1200),
  joined_at timestamptz not null default now(),
  primary key (project_id, profile_id)
);

create table if not exists public.cf_project_join_requests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.cf_projects(id) on delete cascade,
  requester_id uuid not null references public.cf_profiles(id) on delete cascade,
  message text check (char_length(message) <= 1000),
  status text not null default 'PENDING' check (status in ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  unique (project_id, requester_id)
);

create table if not exists public.cf_project_tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.cf_projects(id) on delete cascade,
  assignee_id uuid references public.cf_profiles(id) on delete set null,
  title text not null check (char_length(title) between 1 and 240),
  status text not null default 'TODO' check (status in ('TODO', 'IN_PROGRESS', 'DONE')),
  priority text not null default 'MEDIUM' check (priority in ('LOW', 'MEDIUM', 'HIGH')),
  due_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cf_project_milestones (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.cf_projects(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 240),
  objective text check (char_length(objective) <= 1200),
  status text not null default 'OPEN' check (status in ('OPEN', 'IN_PROGRESS', 'DONE')),
  target_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cf_project_messages (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.cf_projects(id) on delete cascade,
  sender_id uuid not null references public.cf_profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);

create table if not exists public.cf_entitlements (
  profile_id uuid primary key references public.cf_profiles(id) on delete cascade,
  plan text not null default 'FREE' check (plan in ('FREE', 'PRO')),
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'PAST_DUE', 'CANCELLED', 'EXPIRED')),
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.cf_notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.cf_profiles(id) on delete cascade,
  kind text not null,
  payload jsonb not null default '{}',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists cf_profiles_discovery_idx on public.cf_profiles (is_discoverable, updated_at desc);
create index if not exists cf_connections_low_idx on public.cf_connections (low_profile_id, created_at desc);
create index if not exists cf_connections_high_idx on public.cf_connections (high_profile_id, created_at desc);
create index if not exists cf_messages_connection_idx on public.cf_messages (connection_id, created_at desc);
create index if not exists cf_projects_owner_idx on public.cf_projects (owner_id, archived_at, updated_at desc);
create index if not exists cf_tasks_project_idx on public.cf_project_tasks (project_id, status, due_at);
create index if not exists cf_notifications_profile_idx on public.cf_notifications (profile_id, read_at, created_at desc);

create or replace function public.cf_touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;

drop trigger if exists cf_profiles_touch on public.cf_profiles;
create trigger cf_profiles_touch before update on public.cf_profiles for each row execute procedure public.cf_touch_updated_at();
drop trigger if exists cf_projects_touch on public.cf_projects;
create trigger cf_projects_touch before update on public.cf_projects for each row execute procedure public.cf_touch_updated_at();
drop trigger if exists cf_tasks_touch on public.cf_project_tasks;
create trigger cf_tasks_touch before update on public.cf_project_tasks for each row execute procedure public.cf_touch_updated_at();

create or replace function public.cf_add_project_owner()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.cf_project_members (project_id, profile_id, role)
  values (new.id, new.owner_id, 'OWNER') on conflict do nothing;
  return new;
end; $$;
drop trigger if exists cf_projects_add_owner on public.cf_projects;
create trigger cf_projects_add_owner after insert on public.cf_projects for each row execute procedure public.cf_add_project_owner();

create or replace function public.cf_is_connection_participant(connection uuid, actor uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.cf_connections c where c.id = connection and actor in (c.low_profile_id, c.high_profile_id));
$$;

create or replace function public.cf_is_project_member(project uuid, actor uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.cf_project_members m where m.project_id = project and m.profile_id = actor);
$$;

create or replace function public.cf_is_pro(actor uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.cf_entitlements e where e.profile_id = actor and e.plan = 'PRO' and e.status = 'ACTIVE' and (e.expires_at is null or e.expires_at > now()));
$$;

create or replace function public.cf_discover_profiles(result_limit integer default 12)
returns table (id uuid, username text, full_name text, headline text, city text, experience_band text, skills text[], domains text[], goals text[], current_build text, looking_for text, avatar_url text, email_verified boolean, github_verified boolean, linkedin_verified boolean, match_reason text)
language sql stable security definer set search_path = public as $$
  select p.id, p.username, p.full_name, p.headline, p.city, p.experience_band, p.skills, p.domains, p.goals, p.current_build, p.looking_for, p.avatar_url, p.email_verified, p.github_verified, p.linkedin_verified,
    case when p.skills && coalesce((select skills from public.cf_profiles where id = auth.uid()), '{}'::text[]) then 'Shared skills'
         when p.domains && coalesce((select domains from public.cf_profiles where id = auth.uid()), '{}'::text[]) then 'Shared domain'
         else 'Open to a relevant introduction' end
  from public.cf_profiles p
  where p.id <> auth.uid() and p.is_discoverable and p.onboarding_complete
    and not exists (select 1 from public.cf_blocks b where (b.blocker_id = auth.uid() and b.blocked_id = p.id) or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
    and not exists (select 1 from public.cf_connections c where auth.uid() in (c.low_profile_id, c.high_profile_id) and p.id in (c.low_profile_id, c.high_profile_id))
    and not exists (select 1 from public.cf_meet_sessions s where auth.uid() in (s.participant_a_id, s.participant_b_id) and p.id in (s.participant_a_id, s.participant_b_id))
  order by p.updated_at desc
  limit greatest(1, least(result_limit, 24));
$$;

create or replace function public.cf_open_meet(candidate_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare session_id uuid; actor uuid := auth.uid();
begin
  if actor is null or actor = candidate_id then raise exception 'MEET_NOT_ALLOWED'; end if;
  if not exists (select 1 from public.cf_profiles where id = candidate_id and is_discoverable and onboarding_complete) then raise exception 'CANDIDATE_UNAVAILABLE'; end if;
  update public.cf_meet_sessions set status = 'CLOSED', ended_at = now() where status = 'ACTIVE' and actor in (participant_a_id, participant_b_id);
  insert into public.cf_meet_sessions (participant_a_id, participant_b_id) values (actor, candidate_id) returning id into session_id;
  return session_id;
end; $$;

create or replace function public.cf_record_meet_decision(session_id uuid, choice text)
returns table (status text, connection_id uuid) language plpgsql security definer set search_path = public as $$
declare actor uuid := auth.uid(); s public.cf_meet_sessions; low_id uuid; high_id uuid; connection uuid;
begin
  if choice not in ('CONNECT', 'NEXT') then raise exception 'INVALID_DECISION'; end if;
  select * into s from public.cf_meet_sessions where id = session_id for update;
  if not found or actor not in (s.participant_a_id, s.participant_b_id) or s.status <> 'ACTIVE' then raise exception 'MEET_NOT_ACTIVE'; end if;
  if actor = s.participant_a_id then update public.cf_meet_sessions set a_decision = choice where id = session_id;
  else update public.cf_meet_sessions set b_decision = choice where id = session_id; end if;
  select * into s from public.cf_meet_sessions where id = session_id;
  if choice = 'NEXT' or s.a_decision = 'NEXT' or s.b_decision = 'NEXT' then
    update public.cf_meet_sessions set status = 'CLOSED', ended_at = now() where id = session_id;
    return query select 'CLOSED'::text, null::uuid; return;
  end if;
  if s.a_decision = 'CONNECT' and s.b_decision = 'CONNECT' then
    low_id := least(s.participant_a_id, s.participant_b_id); high_id := greatest(s.participant_a_id, s.participant_b_id);
    insert into public.cf_connections (low_profile_id, high_profile_id, meet_session_id) values (low_id, high_id, session_id)
      on conflict (low_profile_id, high_profile_id) do update set meet_session_id = excluded.meet_session_id returning id into connection;
    update public.cf_meet_sessions set status = 'CLOSED', ended_at = now(), connection_id = connection where id = session_id;
    insert into public.cf_notifications (profile_id, kind, payload) values
      (s.participant_a_id, 'MUTUAL_CONNECTION', jsonb_build_object('connection_id', connection)),
      (s.participant_b_id, 'MUTUAL_CONNECTION', jsonb_build_object('connection_id', connection));
    return query select 'MUTUAL_CONNECTION'::text, connection; return;
  end if;
  return query select 'PENDING_ONE_WAY'::text, null::uuid;
end; $$;

create or replace function public.cf_request_project_join(project uuid, note text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare request_id uuid; actor uuid := auth.uid(); owner uuid;
begin
  if not public.cf_is_pro(actor) then raise exception 'FORBIDDEN_PRO_REQUIRED'; end if;
  select owner_id into owner from public.cf_projects where id = project and collaboration_enabled and archived_at is null;
  if owner is null or owner = actor then raise exception 'PROJECT_NOT_JOINABLE'; end if;
  insert into public.cf_project_join_requests (project_id, requester_id, message) values (project, actor, note)
    on conflict (project_id, requester_id) do update set message = excluded.message, status = 'PENDING', created_at = now(), decided_at = null returning id into request_id;
  insert into public.cf_notifications (profile_id, kind, payload) values (owner, 'PROJECT_JOIN_REQUEST', jsonb_build_object('request_id', request_id, 'project_id', project));
  return request_id;
end; $$;

create or replace function public.cf_decide_project_join(request uuid, accept boolean, member_role text default 'CONTRIBUTOR')
returns void language plpgsql security definer set search_path = public as $$
declare r public.cf_project_join_requests; actor uuid := auth.uid();
begin
  select * into r from public.cf_project_join_requests where id = request for update;
  if not found or not exists (select 1 from public.cf_projects where id = r.project_id and owner_id = actor) then raise exception 'NOT_PROJECT_OWNER'; end if;
  if r.status <> 'PENDING' then raise exception 'REQUEST_ALREADY_DECIDED'; end if;
  update public.cf_project_join_requests set status = case when accept then 'ACCEPTED' else 'DECLINED' end, decided_at = now() where id = request;
  if accept then insert into public.cf_project_members (project_id, profile_id, role) values (r.project_id, r.requester_id, member_role) on conflict do nothing; end if;
  insert into public.cf_notifications (profile_id, kind, payload) values (r.requester_id, case when accept then 'PROJECT_JOIN_ACCEPTED' else 'PROJECT_JOIN_DECLINED' end, jsonb_build_object('project_id', r.project_id));
end; $$;

alter table public.cf_profiles enable row level security;
alter table public.cf_profile_contacts enable row level security;
alter table public.cf_blocks enable row level security;
alter table public.cf_reports enable row level security;
alter table public.cf_meet_sessions enable row level security;
alter table public.cf_meet_messages enable row level security;
alter table public.cf_connections enable row level security;
alter table public.cf_messages enable row level security;
alter table public.cf_projects enable row level security;
alter table public.cf_project_members enable row level security;
alter table public.cf_project_join_requests enable row level security;
alter table public.cf_project_tasks enable row level security;
alter table public.cf_project_milestones enable row level security;
alter table public.cf_project_messages enable row level security;
alter table public.cf_entitlements enable row level security;
alter table public.cf_notifications enable row level security;

create policy "profiles read permitted discovery fields" on public.cf_profiles for select to authenticated using (
  is_discoverable
  or id = auth.uid()
  or exists (
    select 1
    from public.cf_connections c
    where public.cf_profiles.id in (c.low_profile_id, c.high_profile_id)
      and auth.uid() in (c.low_profile_id, c.high_profile_id)
  )
);
create policy "profiles insert self" on public.cf_profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update self" on public.cf_profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "contacts owner or mutual connection" on public.cf_profile_contacts for select to authenticated using (profile_id = auth.uid() or (links_visible_to_connections and exists (select 1 from public.cf_connections c where profile_id in (c.low_profile_id, c.high_profile_id) and auth.uid() in (c.low_profile_id, c.high_profile_id))));
create policy "contacts owner write" on public.cf_profile_contacts for all to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "blocks owner" on public.cf_blocks for all to authenticated using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create policy "reports reporter" on public.cf_reports for insert to authenticated with check (reporter_id = auth.uid());
create policy "meet participants" on public.cf_meet_sessions for select to authenticated using (auth.uid() in (participant_a_id, participant_b_id));
create policy "meet messages participants read" on public.cf_meet_messages for select to authenticated using (exists (select 1 from public.cf_meet_sessions s where s.id = meet_session_id and auth.uid() in (s.participant_a_id, s.participant_b_id)));
create policy "meet messages participants send" on public.cf_meet_messages for insert to authenticated with check (sender_id = auth.uid() and exists (select 1 from public.cf_meet_sessions s where s.id = meet_session_id and s.status = 'ACTIVE' and auth.uid() in (s.participant_a_id, s.participant_b_id)));
create policy "connections participants" on public.cf_connections for select to authenticated using (auth.uid() in (low_profile_id, high_profile_id));
create policy "messages connection participants read" on public.cf_messages for select to authenticated using (public.cf_is_connection_participant(connection_id));
create policy "messages connection participants send" on public.cf_messages for insert to authenticated with check (sender_id = auth.uid() and public.cf_is_connection_participant(connection_id));
create policy "projects public owner member read" on public.cf_projects for select to authenticated using (is_public or owner_id = auth.uid() or public.cf_is_project_member(id));
create policy "projects owner create" on public.cf_projects for insert to authenticated with check (owner_id = auth.uid());
create policy "projects owner update" on public.cf_projects for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "project members member read" on public.cf_project_members for select to authenticated using (public.cf_is_project_member(project_id) or exists (select 1 from public.cf_projects p where p.id = project_id and p.is_public));
create policy "project tasks members read" on public.cf_project_tasks for select to authenticated using (public.cf_is_project_member(project_id));
create policy "project tasks members write" on public.cf_project_tasks for all to authenticated using (public.cf_is_project_member(project_id)) with check (public.cf_is_project_member(project_id));
create policy "milestones members read" on public.cf_project_milestones for select to authenticated using (public.cf_is_project_member(project_id));
create policy "milestones members write" on public.cf_project_milestones for all to authenticated using (public.cf_is_project_member(project_id)) with check (public.cf_is_project_member(project_id));
create policy "project messages members read" on public.cf_project_messages for select to authenticated using (public.cf_is_project_member(project_id));
create policy "project messages members send" on public.cf_project_messages for insert to authenticated with check (sender_id = auth.uid() and public.cf_is_project_member(project_id));
create policy "join requests requester or owner read" on public.cf_project_join_requests for select to authenticated using (requester_id = auth.uid() or exists (select 1 from public.cf_projects p where p.id = project_id and p.owner_id = auth.uid()));
create policy "entitlements self read" on public.cf_entitlements for select to authenticated using (profile_id = auth.uid());
create policy "notifications self" on public.cf_notifications for select to authenticated using (profile_id = auth.uid());
create policy "notifications self read update" on public.cf_notifications for update to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());

do $$ begin
  alter publication supabase_realtime add table public.cf_meet_messages;
  alter publication supabase_realtime add table public.cf_messages;
  alter publication supabase_realtime add table public.cf_project_messages;
  alter publication supabase_realtime add table public.cf_notifications;
exception when duplicate_object or undefined_object then null; end $$;

revoke all on function public.cf_discover_profiles(integer) from public;
revoke all on function public.cf_open_meet(uuid) from public;
revoke all on function public.cf_record_meet_decision(uuid, text) from public;
revoke all on function public.cf_request_project_join(uuid, text) from public;
revoke all on function public.cf_decide_project_join(uuid, boolean, text) from public;
grant execute on function public.cf_discover_profiles(integer), public.cf_open_meet(uuid), public.cf_record_meet_decision(uuid, text), public.cf_request_project_join(uuid, text), public.cf_decide_project_join(uuid, boolean, text) to authenticated;
