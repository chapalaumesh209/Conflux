-- CONFLUX V3 production foundation
--
-- Forward-only companion to 202609180001 and 202609180002. This migration
-- preserves existing cf_ records, backfills canonical conversation and room
-- identifiers, and tightens authorization without accepting browser claims.

-- ---------------------------------------------------------------------------
-- Versioned onboarding drafts. A completed profile remains the canonical
-- profile; drafts only protect an incomplete, authenticated onboarding flow.
-- ---------------------------------------------------------------------------
create table if not exists public.cf_onboarding_drafts (
  profile_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  revision integer not null default 1 check (revision > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cf_onboarding_drafts_updated_idx on public.cf_onboarding_drafts (updated_at desc);

create or replace function public.cf_touch_draft_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists cf_onboarding_drafts_touch on public.cf_onboarding_drafts;
create trigger cf_onboarding_drafts_touch
before update on public.cf_onboarding_drafts
for each row execute procedure public.cf_touch_draft_updated_at();

create or replace function public.cf_save_onboarding_draft(
  draft_payload jsonb,
  expected_revision integer default null
)
returns table (revision integer, updated_at timestamptz)
language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  saved public.cf_onboarding_drafts;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if jsonb_typeof(coalesce(draft_payload, '{}'::jsonb)) <> 'object' then raise exception 'INVALID_DRAFT'; end if;
  if exists (select 1 from public.cf_profiles where id = actor and onboarding_complete) then
    raise exception 'ONBOARDING_ALREADY_COMPLETE';
  end if;

  if expected_revision is null then
    insert into public.cf_onboarding_drafts (profile_id, payload)
    values (actor, coalesce(draft_payload, '{}'::jsonb))
    on conflict (profile_id) do update
      set payload = excluded.payload,
          revision = public.cf_onboarding_drafts.revision + 1,
          updated_at = now()
    returning * into saved;
  else
    update public.cf_onboarding_drafts
       set payload = coalesce(draft_payload, '{}'::jsonb),
           revision = revision + 1,
           updated_at = now()
     where profile_id = actor and revision = expected_revision
    returning * into saved;

    if not found then
      raise exception 'DRAFT_CONFLICT';
    end if;
  end if;

  return query select saved.revision, saved.updated_at;
end;
$$;

create or replace function public.cf_clear_completed_onboarding_draft()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.onboarding_complete then
    delete from public.cf_onboarding_drafts where profile_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists cf_profiles_clear_onboarding_draft on public.cf_profiles;
create trigger cf_profiles_clear_onboarding_draft
after insert or update of onboarding_complete on public.cf_profiles
for each row execute procedure public.cf_clear_completed_onboarding_draft();

alter table public.cf_onboarding_drafts enable row level security;
drop policy if exists "onboarding drafts owner only" on public.cf_onboarding_drafts;
create policy "onboarding drafts owner only" on public.cf_onboarding_drafts
for select to authenticated using (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- A connection is a mutual relationship. A conversation is its durable,
-- canonical chat resource. Existing connection-scoped messages are retained
-- and backfilled rather than copied or deleted.
-- ---------------------------------------------------------------------------
create table if not exists public.cf_conversations (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null unique references public.cf_connections(id) on delete cascade,
  state text not null default 'ACTIVE' check (state in ('ACTIVE', 'CLOSED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cf_conversation_member_state (
  conversation_id uuid not null references public.cf_conversations(id) on delete cascade,
  profile_id uuid not null references public.cf_profiles(id) on delete cascade,
  last_read_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (conversation_id, profile_id)
);

create index if not exists cf_conversation_member_read_idx on public.cf_conversation_member_state (profile_id, last_read_at);

create or replace function public.cf_touch_conversation_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists cf_conversations_touch on public.cf_conversations;
create trigger cf_conversations_touch before update on public.cf_conversations
for each row execute procedure public.cf_touch_conversation_updated_at();
drop trigger if exists cf_conversation_member_state_touch on public.cf_conversation_member_state;
create trigger cf_conversation_member_state_touch before update on public.cf_conversation_member_state
for each row execute procedure public.cf_touch_conversation_updated_at();

create or replace function public.cf_create_connection_conversation()
returns trigger language plpgsql security definer set search_path = public as $$
declare conversation uuid;
begin
  insert into public.cf_conversations (connection_id)
  values (new.id)
  on conflict (connection_id) do nothing
  returning id into conversation;

  if conversation is null then
    select id into conversation from public.cf_conversations where connection_id = new.id;
  end if;

  insert into public.cf_conversation_member_state (conversation_id, profile_id)
  values (conversation, new.low_profile_id), (conversation, new.high_profile_id)
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists cf_connections_create_conversation on public.cf_connections;
create trigger cf_connections_create_conversation
after insert on public.cf_connections
for each row execute procedure public.cf_create_connection_conversation();

insert into public.cf_conversations (connection_id)
select id from public.cf_connections
on conflict (connection_id) do nothing;

insert into public.cf_conversation_member_state (conversation_id, profile_id)
select c.id, pair.profile_id
from public.cf_conversations c
join public.cf_connections connection on connection.id = c.connection_id
cross join lateral (values (connection.low_profile_id), (connection.high_profile_id)) as pair(profile_id)
on conflict do nothing;

alter table public.cf_messages add column if not exists conversation_id uuid references public.cf_conversations(id) on delete cascade;

update public.cf_messages message
set conversation_id = conversation.id
from public.cf_conversations conversation
where conversation.connection_id = message.connection_id
  and message.conversation_id is null;

create or replace function public.cf_assign_message_conversation()
returns trigger language plpgsql security definer set search_path = public as $$
declare expected_conversation uuid;
begin
  select id into expected_conversation
  from public.cf_conversations
  where connection_id = new.connection_id;

  if expected_conversation is null then
    raise exception 'CONVERSATION_NOT_FOUND';
  end if;

  if new.conversation_id is null then
    new.conversation_id = expected_conversation;
  elsif new.conversation_id <> expected_conversation then
    raise exception 'CONNECTION_CONVERSATION_MISMATCH';
  end if;
  return new;
end;
$$;

drop trigger if exists cf_messages_assign_conversation on public.cf_messages;
create trigger cf_messages_assign_conversation
before insert or update of connection_id, conversation_id on public.cf_messages
for each row execute procedure public.cf_assign_message_conversation();

alter table public.cf_messages alter column conversation_id set not null;
create index if not exists cf_messages_conversation_idx on public.cf_messages (conversation_id, created_at desc);

create or replace function public.cf_relationship_is_blocked(profile_a uuid, profile_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.cf_blocks
    where (blocker_id = profile_a and blocked_id = profile_b)
       or (blocker_id = profile_b and blocked_id = profile_a)
  );
$$;

create or replace function public.cf_can_access_connection(connection uuid, actor uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.cf_connections c
    where c.id = connection
      and actor in (c.low_profile_id, c.high_profile_id)
      and not public.cf_relationship_is_blocked(c.low_profile_id, c.high_profile_id)
  );
$$;

create or replace function public.cf_can_access_conversation(conversation uuid, actor uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.cf_conversations c
    where c.id = conversation and c.state = 'ACTIVE'
      and public.cf_can_access_connection(c.connection_id, actor)
  );
$$;

create or replace function public.cf_send_message(
  requested_conversation_id uuid,
  requested_body text,
  requested_client_message_id uuid
)
returns public.cf_messages
language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  connection uuid;
  existing public.cf_messages;
  inserted public.cf_messages;
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if requested_client_message_id is null then raise exception 'CLIENT_MESSAGE_ID_REQUIRED'; end if;
  if char_length(trim(coalesce(requested_body, ''))) not between 1 and 4000 then raise exception 'INVALID_MESSAGE_BODY'; end if;

  select connection_id into connection from public.cf_conversations where id = requested_conversation_id;
  if connection is null or not public.cf_can_access_conversation(requested_conversation_id, actor) then
    raise exception 'CONVERSATION_ACCESS_DENIED';
  end if;

  select * into existing from public.cf_messages where client_message_id = requested_client_message_id;
  if found then
    if existing.conversation_id <> requested_conversation_id or existing.sender_id <> actor then
      raise exception 'IDEMPOTENCY_KEY_CONFLICT';
    end if;
    return existing;
  end if;

  begin
    insert into public.cf_messages (connection_id, conversation_id, sender_id, body, client_message_id)
    values (connection, requested_conversation_id, actor, trim(requested_body), requested_client_message_id)
    returning * into inserted;
  exception when unique_violation then
    select * into existing from public.cf_messages where client_message_id = requested_client_message_id;
    if not found or existing.conversation_id <> requested_conversation_id or existing.sender_id <> actor then
      raise exception 'IDEMPOTENCY_KEY_CONFLICT';
    end if;
    return existing;
  end;

  insert into public.cf_notifications (profile_id, kind, payload)
  select member.profile_id, 'CHAT_MESSAGE', jsonb_build_object('conversation_id', requested_conversation_id, 'message_id', inserted.id)
  from public.cf_conversation_member_state member
  where member.conversation_id = requested_conversation_id and member.profile_id <> actor;
  return inserted;
end;
$$;

create or replace function public.cf_mark_conversation_read(requested_conversation_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare actor uuid := auth.uid();
begin
  if actor is null or not public.cf_can_access_conversation(requested_conversation_id, actor) then
    raise exception 'CONVERSATION_ACCESS_DENIED';
  end if;
  update public.cf_conversation_member_state
     set last_read_at = now(), updated_at = now()
   where conversation_id = requested_conversation_id and profile_id = actor;
end;
$$;

alter table public.cf_conversations enable row level security;
alter table public.cf_conversation_member_state enable row level security;

drop policy if exists "connections participants" on public.cf_connections;
create policy "connections participants" on public.cf_connections for select to authenticated using (
  auth.uid() in (low_profile_id, high_profile_id)
  and not public.cf_relationship_is_blocked(low_profile_id, high_profile_id)
);

drop policy if exists "messages connection participants read" on public.cf_messages;
drop policy if exists "messages connection participants send" on public.cf_messages;
create policy "messages connection participants read" on public.cf_messages for select to authenticated using (
  public.cf_can_access_connection(connection_id)
);
-- Client message writes must use cf_send_message so the idempotency key,
-- conversation relationship, and notification state are checked atomically.
create policy "messages direct browser insert disabled" on public.cf_messages for insert to authenticated with check (false);

drop policy if exists "contacts owner or mutual connection" on public.cf_profile_contacts;
create policy "contacts owner or mutual connection" on public.cf_profile_contacts for select to authenticated using (
  profile_id = auth.uid() or (
    links_visible_to_connections and exists (
      select 1 from public.cf_connections c
      where profile_id in (c.low_profile_id, c.high_profile_id)
        and auth.uid() in (c.low_profile_id, c.high_profile_id)
        and not public.cf_relationship_is_blocked(c.low_profile_id, c.high_profile_id)
    )
  )
);

drop policy if exists "profiles read permitted discovery fields" on public.cf_profiles;
create policy "profiles read permitted discovery fields" on public.cf_profiles for select to authenticated using (
  id = auth.uid()
  or (
    is_discoverable and not public.cf_relationship_is_blocked(id, auth.uid())
  )
  or exists (
    select 1 from public.cf_connections c
    where public.cf_profiles.id in (c.low_profile_id, c.high_profile_id)
      and auth.uid() in (c.low_profile_id, c.high_profile_id)
      and not public.cf_relationship_is_blocked(c.low_profile_id, c.high_profile_id)
  )
);

drop policy if exists "conversations participants" on public.cf_conversations;
create policy "conversations participants" on public.cf_conversations for select to authenticated using (
  public.cf_can_access_conversation(id)
);
drop policy if exists "conversation states participants" on public.cf_conversation_member_state;
create policy "conversation states participants" on public.cf_conversation_member_state for select to authenticated using (
  public.cf_can_access_conversation(conversation_id)
);

-- ---------------------------------------------------------------------------
-- Build Room canonical identifiers and durable collaboration foundation.
-- Existing UUID-based project APIs remain readable during the route migration.
-- ---------------------------------------------------------------------------
alter table public.cf_projects add column if not exists slug text;
alter table public.cf_projects add column if not exists summary text check (char_length(summary) <= 480);
alter table public.cf_projects add column if not exists visibility text not null default 'PRIVATE' check (visibility in ('PRIVATE', 'PUBLIC', 'UNLISTED'));
alter table public.cf_projects add column if not exists version integer not null default 1 check (version > 0);

update public.cf_projects
set slug = concat('room-', replace(id::text, '-', ''))
where slug is null or btrim(slug) = '';

alter table public.cf_projects alter column slug set not null;
create unique index if not exists cf_projects_slug_unique_idx on public.cf_projects (slug);
create index if not exists cf_projects_visibility_idx on public.cf_projects (visibility, archived_at, updated_at desc);

create or replace function public.cf_assign_project_slug()
returns trigger language plpgsql as $$
begin
  if new.slug is null or btrim(new.slug) = '' then
    new.slug = concat('room-', replace(new.id::text, '-', ''));
  end if;
  if new.summary is null then new.summary = new.idea; end if;
  if new.is_public then new.visibility = 'PUBLIC'; end if;
  return new;
end;
$$;

drop trigger if exists cf_projects_assign_slug on public.cf_projects;
create trigger cf_projects_assign_slug before insert or update of slug, summary, is_public on public.cf_projects
for each row execute procedure public.cf_assign_project_slug();

create or replace function public.cf_touch_project_version()
returns trigger language plpgsql as $$
begin
  new.version = old.version + 1;
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists cf_projects_version_touch on public.cf_projects;
create trigger cf_projects_version_touch before update on public.cf_projects
for each row execute procedure public.cf_touch_project_version();

alter table public.cf_project_tasks add column if not exists milestone_id uuid references public.cf_project_milestones(id) on delete set null;
alter table public.cf_project_tasks add column if not exists version integer not null default 1 check (version > 0);
create index if not exists cf_project_tasks_milestone_idx on public.cf_project_tasks (milestone_id, status);

do $$
declare existing_check text;
begin
  for existing_check in
    select conname
    from pg_constraint
    where conrelid = 'public.cf_project_tasks'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%status%'
  loop
    execute format('alter table public.cf_project_tasks drop constraint %I', existing_check);
  end loop;
end;
$$;

alter table public.cf_project_tasks
  add constraint cf_project_tasks_status_v3_check
  check (status in ('BACKLOG', 'TODO', 'IN_PROGRESS', 'BLOCKED', 'DONE', 'CANCELLED'));

create or replace function public.cf_touch_task_version()
returns trigger language plpgsql as $$
begin
  new.version = old.version + 1;
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists cf_tasks_version_touch on public.cf_project_tasks;
create trigger cf_tasks_version_touch before update on public.cf_project_tasks
for each row execute procedure public.cf_touch_task_version();

create or replace function public.cf_can_manage_project_work(project uuid, actor uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.cf_project_members m
    where m.project_id = project and m.profile_id = actor and m.role in ('OWNER', 'LEAD')
  );
$$;

drop policy if exists "project tasks members write" on public.cf_project_tasks;
create policy "project tasks owner lead write" on public.cf_project_tasks for all to authenticated
using (public.cf_can_manage_project_work(project_id))
with check (public.cf_can_manage_project_work(project_id));
drop policy if exists "milestones members write" on public.cf_project_milestones;
create policy "milestones owner lead write" on public.cf_project_milestones for all to authenticated
using (public.cf_can_manage_project_work(project_id))
with check (public.cf_can_manage_project_work(project_id));

create table if not exists public.cf_project_links (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.cf_projects(id) on delete cascade,
  type text not null check (type in ('LIVE', 'REPOSITORY', 'DESIGN', 'DOCS', 'OTHER')),
  url text not null check (char_length(url) between 8 and 2048),
  visibility text not null default 'MEMBERS' check (visibility in ('PUBLIC', 'MEMBERS')),
  created_at timestamptz not null default now()
);

create table if not exists public.cf_project_notes (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.cf_projects(id) on delete cascade,
  author_id uuid not null references public.cf_profiles(id) on delete cascade,
  type text not null default 'NOTE' check (type in ('NOTE', 'DECISION', 'RETROSPECTIVE')),
  title text not null check (char_length(title) between 1 and 240),
  body text not null default '' check (char_length(body) <= 20000),
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cf_project_files (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.cf_projects(id) on delete cascade,
  uploader_id uuid not null references public.cf_profiles(id) on delete cascade,
  object_path text not null unique check (char_length(object_path) between 1 and 1024),
  filename text not null check (char_length(filename) between 1 and 255),
  content_type text,
  size_bytes bigint check (size_bytes >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.cf_project_activity (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.cf_projects(id) on delete cascade,
  actor_id uuid references public.cf_profiles(id) on delete set null,
  event_type text not null check (char_length(event_type) between 1 and 80),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.cf_project_calls (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.cf_projects(id) on delete cascade,
  initiator_id uuid not null references public.cf_profiles(id) on delete cascade,
  state text not null default 'PENDING' check (state in ('PENDING', 'ACTIVE', 'ENDED')),
  provider_metadata jsonb not null default '{}'::jsonb,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.cf_project_links enable row level security;
alter table public.cf_project_notes enable row level security;
alter table public.cf_project_files enable row level security;
alter table public.cf_project_activity enable row level security;
alter table public.cf_project_calls enable row level security;

drop policy if exists "project links visible by access" on public.cf_project_links;
create policy "project links visible by access" on public.cf_project_links for select to authenticated using (
  visibility = 'PUBLIC' or public.cf_is_project_member(project_id)
);
drop policy if exists "project links owner lead write" on public.cf_project_links;
create policy "project links owner lead write" on public.cf_project_links for all to authenticated
using (public.cf_can_manage_project_work(project_id))
with check (public.cf_can_manage_project_work(project_id));
drop policy if exists "project notes member read" on public.cf_project_notes;
create policy "project notes member read" on public.cf_project_notes for select to authenticated using (public.cf_is_project_member(project_id));
drop policy if exists "project notes member write" on public.cf_project_notes;
create policy "project notes member write" on public.cf_project_notes for insert to authenticated
with check (author_id = auth.uid() and public.cf_is_project_member(project_id));
drop policy if exists "project notes author lead update" on public.cf_project_notes;
create policy "project notes author lead update" on public.cf_project_notes for update to authenticated
using (author_id = auth.uid() or public.cf_can_manage_project_work(project_id))
with check (author_id = auth.uid() or public.cf_can_manage_project_work(project_id));
drop policy if exists "project files member read" on public.cf_project_files;
create policy "project files member read" on public.cf_project_files for select to authenticated using (public.cf_is_project_member(project_id));
drop policy if exists "project files member write" on public.cf_project_files;
create policy "project files member write" on public.cf_project_files for insert to authenticated
with check (uploader_id = auth.uid() and public.cf_is_project_member(project_id));
drop policy if exists "project activity member read" on public.cf_project_activity;
create policy "project activity member read" on public.cf_project_activity for select to authenticated using (public.cf_is_project_member(project_id));
drop policy if exists "project calls member read" on public.cf_project_calls;
create policy "project calls member read" on public.cf_project_calls for select to authenticated using (public.cf_is_project_member(project_id));

create or replace view public.cf_project_milestone_progress
with (security_invoker = true) as
select
  milestone.id as milestone_id,
  milestone.project_id,
  count(task.id) filter (where task.status <> 'CANCELLED') as actionable_task_count,
  count(task.id) filter (where task.status = 'DONE') as completed_task_count,
  case
    when count(task.id) filter (where task.status <> 'CANCELLED') = 0 then 0
    else round(
      100.0 * count(task.id) filter (where task.status = 'DONE') /
      count(task.id) filter (where task.status <> 'CANCELLED'), 0
    )
  end as completion_percent
from public.cf_project_milestones milestone
left join public.cf_project_tasks task on task.milestone_id = milestone.id
group by milestone.id, milestone.project_id;

-- Security-definer RPCs are deliberately the only browser mutation path for
-- drafts and direct messages. They remain unavailable to anon/public roles.
revoke all on function public.cf_save_onboarding_draft(jsonb, integer) from public;
revoke all on function public.cf_send_message(uuid, text, uuid) from public;
revoke all on function public.cf_mark_conversation_read(uuid) from public;
grant execute on function public.cf_save_onboarding_draft(jsonb, integer), public.cf_send_message(uuid, text, uuid), public.cf_mark_conversation_read(uuid) to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.cf_conversation_member_state;
exception when duplicate_object or undefined_object then null; end $$;
