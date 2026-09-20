-- CONFLUX final Meet contract
--
-- The prior media-request tables are retained for backwards-compatible audit
-- history, but peer request/accept flows are no longer callable by clients.
-- Mic and camera are local browser controls. Screen share remains a
-- server-authorized Pro capability.

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
    where ms.id = requested_session_id and ms.status = 'ACTIVE'
      and actor in (ms.participant_a_id, ms.participant_b_id)
  ) then
    raise exception 'ROOM_ACCESS_REQUIRED';
  end if;

  insert into public.cf_meet_media_states (meet_session_id, profile_id, audio_state, video_state)
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
    jsonb_build_object('mic_enabled', requested_mic_enabled, 'camera_enabled', requested_camera_enabled)
  );
  return result;
end;
$$;

create or replace function public.cf_begin_meet_screen_share(requested_session_id uuid)
returns boolean
language plpgsql security definer set search_path = public, auth as $$
declare actor uuid := auth.uid();
begin
  if actor is null or not public.cf_is_pro(actor) then
    raise exception 'FORBIDDEN_PRO_REQUIRED';
  end if;
  if not exists (
    select 1 from public.cf_meet_sessions as ms
    where ms.id = requested_session_id and ms.status = 'ACTIVE'
      and actor in (ms.participant_a_id, ms.participant_b_id)
  ) then
    raise exception 'ROOM_ACCESS_REQUIRED';
  end if;

  update public.cf_meet_media_states
     set screen_share_active = false, updated_at = now()
   where meet_session_id = requested_session_id;
  update public.cf_meet_media_states
     set screen_share_active = true, updated_at = now()
   where meet_session_id = requested_session_id and profile_id = actor;
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type)
  values (requested_session_id, actor, 'SCREEN_SHARE_STARTED');
  return true;
end;
$$;

create or replace function public.cf_end_meet_screen_share(requested_session_id uuid)
returns void
language plpgsql security definer set search_path = public, auth as $$
declare actor uuid := auth.uid();
begin
  if actor is null or not exists (
    select 1 from public.cf_meet_sessions as ms
    where ms.id = requested_session_id
      and actor in (ms.participant_a_id, ms.participant_b_id)
  ) then
    raise exception 'ROOM_ACCESS_REQUIRED';
  end if;
  update public.cf_meet_media_states
     set screen_share_active = false, updated_at = now()
   where meet_session_id = requested_session_id and profile_id = actor;
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type)
  values (requested_session_id, actor, 'SCREEN_SHARE_STOPPED');
end;
$$;

-- Connect remains directional. The recipient receives a persisted notification;
-- reciprocal Connect follows this same function and atomically creates the
-- canonical connection. The existing connection trigger creates one durable
-- conversation for that connection.
create or replace function public.cf_record_meet_decision(session_id uuid, choice text)
returns table (status text, connection_id uuid)
language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  meeting public.cf_meet_sessions;
  low_id uuid;
  high_id uuid;
  connection uuid;
  old_choice text;
  peer_id uuid;
begin
  if choice not in ('CONNECT', 'NEXT') then raise exception 'INVALID_DECISION'; end if;
  select * into meeting from public.cf_meet_sessions as ms where ms.id = session_id for update;
  if not found or actor not in (meeting.participant_a_id, meeting.participant_b_id) then raise exception 'ROOM_ACCESS_REQUIRED'; end if;
  if meeting.status <> 'ACTIVE' then
    if meeting.connection_id is not null then return query select 'MUTUAL_CONNECTION'::text, meeting.connection_id;
    else return query select 'CLOSED'::text, null::uuid; end if;
    return;
  end if;

  old_choice := case when actor = meeting.participant_a_id then meeting.a_decision else meeting.b_decision end;
  if old_choice is not null and old_choice <> choice then raise exception 'DECISION_ALREADY_RECORDED'; end if;
  if actor = meeting.participant_a_id then
    update public.cf_meet_sessions as ms set a_decision = choice, updated_at = now() where ms.id = session_id;
    peer_id := meeting.participant_b_id;
  else
    update public.cf_meet_sessions as ms set b_decision = choice, updated_at = now() where ms.id = session_id;
    peer_id := meeting.participant_a_id;
  end if;
  if old_choice is null then
    insert into public.cf_meet_events (meet_session_id, actor_id, event_type) values (session_id, actor, choice);
    if choice = 'CONNECT' then
      insert into public.cf_notifications (profile_id, kind, payload)
      values (peer_id, 'MEET_CONNECT_PENDING', jsonb_build_object('meet_session_id', session_id, 'candidate_id', actor));
    end if;
  end if;

  select * into meeting from public.cf_meet_sessions as ms where ms.id = session_id;
  if choice = 'NEXT' or meeting.a_decision = 'NEXT' or meeting.b_decision = 'NEXT' then
    update public.cf_meet_sessions as ms set status = 'CLOSED', ended_at = now(), updated_at = now() where ms.id = session_id;
    return query select 'CLOSED'::text, null::uuid;
    return;
  end if;
  if meeting.a_decision = 'CONNECT' and meeting.b_decision = 'CONNECT' then
    low_id := least(meeting.participant_a_id, meeting.participant_b_id);
    high_id := greatest(meeting.participant_a_id, meeting.participant_b_id);
    insert into public.cf_connections (low_profile_id, high_profile_id, meet_session_id)
      values (low_id, high_id, session_id)
      on conflict (low_profile_id, high_profile_id) do update set meet_session_id = excluded.meet_session_id
      returning id into connection;
    update public.cf_meet_sessions as ms
       set status = 'CLOSED', ended_at = now(), updated_at = now(), connection_id = connection
     where ms.id = session_id;
    insert into public.cf_notifications (profile_id, kind, payload) values
      (meeting.participant_a_id, 'MUTUAL_CONNECTION', jsonb_build_object('connection_id', connection)),
      (meeting.participant_b_id, 'MUTUAL_CONNECTION', jsonb_build_object('connection_id', connection));
    return query select 'MUTUAL_CONNECTION'::text, connection;
    return;
  end if;
  return query select 'PENDING_ONE_WAY'::text, null::uuid;
end;
$$;

revoke execute on function public.cf_request_meet_media(uuid, text) from authenticated;
revoke execute on function public.cf_respond_meet_media(uuid, text) from authenticated;
revoke all on function public.cf_set_meet_media_state(uuid, boolean, boolean) from public;
revoke all on function public.cf_begin_meet_screen_share(uuid) from public;
revoke all on function public.cf_end_meet_screen_share(uuid) from public;
grant execute on function public.cf_set_meet_media_state(uuid, boolean, boolean), public.cf_begin_meet_screen_share(uuid), public.cf_end_meet_screen_share(uuid) to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.cf_meet_media_states;
exception when duplicate_object or undefined_object then null;
end $$;
