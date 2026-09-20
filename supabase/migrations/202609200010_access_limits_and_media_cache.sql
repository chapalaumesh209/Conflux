-- CONFLUX access limits and media-state cache recovery
--
-- This migration is intentionally additive. It restores the final Meet media
-- RPC if an earlier partial SQL-editor run omitted it, then makes Build Room
-- creation, Build Room collaboration, and daily connection limits server
-- authoritative.

alter table public.cf_meet_events
  drop constraint if exists cf_meet_events_event_type_check;
alter table public.cf_meet_events
  add constraint cf_meet_events_event_type_check
  check (event_type in (
    'MEET_STARTED', 'CANDIDATE_SHOWN', 'MESSAGE_SENT', 'CONNECT', 'NEXT',
    'ENDED', 'BLOCKED', 'MEDIA_REQUESTED', 'MEDIA_RESOLVED',
    'MEDIA_MIC_ENABLED', 'MEDIA_CAMERA_ENABLED', 'SCREEN_SHARE_STARTED',
    'SCREEN_SHARE_STOPPED'
 ));

create or replace function public.cf_set_meet_media_state(
  requested_session_id uuid,
  requested_mic_enabled boolean,
  requested_camera_enabled boolean
)
returns public.cf_meet_media_states
language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  result public.cf_meet_media_states;
begin
  if actor is null or not exists (
    select 1 from public.cf_meet_sessions as ms
    where ms.id = requested_session_id
      and ms.status = 'ACTIVE'
      and actor in (ms.participant_a_id, ms.participant_b_id)
  ) then
    raise exception 'ROOM_ACCESS_REQUIRED';
  end if;

  insert into public.cf_meet_media_states (
    meet_session_id, profile_id, audio_state, video_state
  )
  values (
    requested_session_id,
    actor,
    case when requested_mic_enabled then 'ACTIVE' else 'OFF' end,
    case when requested_camera_enabled then 'ACTIVE' else 'OFF' end
  )
  on conflict (meet_session_id, profile_id) do update set
    audio_state = excluded.audio_state,
    video_state = excluded.video_state,
    updated_at = now()
  returning * into result;

  insert into public.cf_meet_events (meet_session_id, actor_id, event_type, payload)
  values (
    requested_session_id,
    actor,
    case when requested_mic_enabled then 'MEDIA_MIC_ENABLED' else 'MEDIA_CAMERA_ENABLED' end,
    jsonb_build_object(
      'mic_enabled', requested_mic_enabled,
      'camera_enabled', requested_camera_enabled
    )
  );

  return result;
end;
$$;

revoke all on function public.cf_set_meet_media_state(uuid, boolean, boolean) from public;
grant execute on function public.cf_set_meet_media_state(uuid, boolean, boolean) to authenticated;

-- A Free member has one active Build Room. Archiving that room releases the
-- slot; an active Pro entitlement permits additional rooms. Direct table
-- inserts are disabled so this rule cannot be bypassed from the browser.
create or replace function public.cf_create_build_room(
  requested_name text,
  requested_idea text,
  requested_stage text default 'IDEA',
  requested_is_public boolean default false,
  requested_collaboration_enabled boolean default false
)
returns public.cf_projects
language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  room public.cf_projects;
  normalized_stage text := upper(trim(coalesce(requested_stage, 'IDEA')));
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if char_length(trim(coalesce(requested_name, ''))) not between 1 and 160 then
    raise exception 'ROOM_NAME_INVALID';
  end if;
  if char_length(trim(coalesce(requested_idea, ''))) not between 1 and 280 then
    raise exception 'ROOM_IDEA_INVALID';
  end if;
  if normalized_stage not in ('IDEA', 'PLANNING', 'BUILDING', 'BETA', 'LIVE', 'PAUSED', 'COMPLETED') then
    raise exception 'ROOM_STAGE_INVALID';
  end if;

  -- Lock the owner's profile row before checking the quota. This makes two
  -- simultaneous Free-tier create attempts deterministic.
  perform p.id from public.cf_profiles as p where p.id = actor for update;
  if not found then raise exception 'PROFILE_REQUIRED'; end if;

  if not public.cf_is_pro(actor) and exists (
    select 1 from public.cf_projects as project
    where project.owner_id = actor and project.archived_at is null
  ) then
    raise exception 'FREE_BUILD_ROOM_LIMIT_REACHED';
  end if;

  insert into public.cf_projects (
    owner_id, name, idea, summary, stage, is_public, visibility,
    collaboration_enabled
  ) values (
    actor,
    trim(requested_name),
    trim(requested_idea),
    trim(requested_idea),
    normalized_stage,
    coalesce(requested_is_public, false),
    case when coalesce(requested_is_public, false) then 'PUBLIC' else 'PRIVATE' end,
    coalesce(requested_collaboration_enabled, false)
  ) returning * into room;

  return room;
end;
$$;

drop policy if exists "projects owner create" on public.cf_projects;
drop policy if exists "projects direct browser create disabled" on public.cf_projects;
create policy "projects direct browser create disabled"
  on public.cf_projects for insert to authenticated with check (false);

revoke all on function public.cf_create_build_room(text, text, text, boolean, boolean) from public;
grant execute on function public.cf_create_build_room(text, text, text, boolean, boolean) to authenticated;

-- Joining a different person's room requires both a mutual relationship and
-- an active Pro entitlement. The owner still decides whether to accept.
create or replace function public.cf_request_project_join(project uuid, note text default null)
returns uuid language plpgsql security definer set search_path = public, auth as $$
declare
  request_id uuid;
  actor uuid := auth.uid();
  owner uuid;
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  select owner_id into owner
  from public.cf_projects
  where id = project and collaboration_enabled and archived_at is null;
  if owner is null or owner = actor then raise exception 'PROJECT_NOT_JOINABLE'; end if;
  if not exists (
    select 1 from public.cf_connections as connection
    where actor in (connection.low_profile_id, connection.high_profile_id)
      and owner in (connection.low_profile_id, connection.high_profile_id)
  ) then
    raise exception 'MUTUAL_CONNECTION_REQUIRED';
  end if;
  if not public.cf_is_pro(actor) then raise exception 'FORBIDDEN_PRO_REQUIRED'; end if;

  insert into public.cf_project_join_requests (project_id, requester_id, message)
  values (project, actor, nullif(trim(note), ''))
  on conflict (project_id, requester_id) do update set
    message = excluded.message,
    status = 'PENDING',
    created_at = now(),
    decided_at = null
  returning id into request_id;

  insert into public.cf_notifications (profile_id, kind, payload)
  values (
    owner,
    'PROJECT_JOIN_REQUEST',
    jsonb_build_object('request_id', request_id, 'project_id', project)
  );
  return request_id;
end;
$$;

revoke all on function public.cf_request_project_join(uuid, text) from public;
grant execute on function public.cf_request_project_join(uuid, text) to authenticated;

-- A profile can form at most ten new connections per UTC calendar day. The
-- profile locks make the count safe when reciprocal Connect actions arrive at
-- the same time. This trigger covers every connection source, not only Meet.
create or replace function public.cf_enforce_daily_connection_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  utc_day_start timestamptz := date_trunc('day', now() at time zone 'UTC') at time zone 'UTC';
begin
  if exists (
    select 1 from public.cf_connections as existing
    where existing.low_profile_id = new.low_profile_id
      and existing.high_profile_id = new.high_profile_id
  ) then
    return new;
  end if;

  perform profile.id
  from public.cf_profiles as profile
  where profile.id in (new.low_profile_id, new.high_profile_id)
  order by profile.id
  for update;

  if (select count(*) from public.cf_connections as connection
      where connection.created_at >= utc_day_start
        and new.low_profile_id in (connection.low_profile_id, connection.high_profile_id)) >= 10
    or
     (select count(*) from public.cf_connections as connection
      where connection.created_at >= utc_day_start
        and new.high_profile_id in (connection.low_profile_id, connection.high_profile_id)) >= 10 then
    raise exception 'DAILY_CONNECTION_LIMIT_REACHED';
  end if;

  return new;
end;
$$;

drop trigger if exists cf_connections_daily_limit on public.cf_connections;
create trigger cf_connections_daily_limit
  before insert on public.cf_connections
  for each row execute procedure public.cf_enforce_daily_connection_limit();

-- PostgREST normally sees DDL quickly. Explicit reload prevents a stale schema
-- cache from reporting the media RPC as missing after this migration runs.
notify pgrst, 'reload schema';
