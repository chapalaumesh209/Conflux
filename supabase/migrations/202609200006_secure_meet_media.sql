-- Secure Meet media transport support.
-- WebRTC media itself is DTLS-SRTP encrypted. This migration limits the
-- signaling topic and keeps every consent / Pro decision server-authoritative.

alter table public.cf_meet_media_requests
  drop constraint if exists cf_meet_media_requests_media_type_check;
alter table public.cf_meet_media_requests
  add constraint cf_meet_media_requests_media_type_check
  check (media_type in ('AUDIO', 'VIDEO', 'SCREEN'));

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
begin
  if choice not in ('CONNECT', 'NEXT') then raise exception 'INVALID_DECISION'; end if;

  select * into meeting
  from public.cf_meet_sessions as ms
  where ms.id = session_id
  for update;

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
  else
    update public.cf_meet_sessions as ms set b_decision = choice, updated_at = now() where ms.id = session_id;
  end if;
  if old_choice is null then
    insert into public.cf_meet_events (meet_session_id, actor_id, event_type) values (session_id, actor, choice);
  end if;

  select * into meeting from public.cf_meet_sessions as ms where ms.id = session_id;
  if choice = 'NEXT' or meeting.a_decision = 'NEXT' or meeting.b_decision = 'NEXT' then
    update public.cf_meet_sessions as ms set status = 'CLOSED', ended_at = now(), updated_at = now() where ms.id = session_id;
    update public.cf_meet_media_requests as mr set status = 'CANCELLED', resolved_at = now()
      where mr.meet_session_id = session_id and mr.status = 'PENDING';
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
    update public.cf_meet_media_requests as mr set status = 'CANCELLED', resolved_at = now()
      where mr.meet_session_id = session_id and mr.status = 'PENDING';
    insert into public.cf_notifications (profile_id, kind, payload) values
      (meeting.participant_a_id, 'MUTUAL_CONNECTION', jsonb_build_object('connection_id', connection)),
      (meeting.participant_b_id, 'MUTUAL_CONNECTION', jsonb_build_object('connection_id', connection));
    return query select 'MUTUAL_CONNECTION'::text, connection;
    return;
  end if;

  return query select 'PENDING_ONE_WAY'::text, null::uuid;
end;
$$;

create or replace function public.cf_request_meet_media(requested_session_id uuid, requested_type text)
returns public.cf_meet_media_requests
language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  target uuid;
  inserted public.cf_meet_media_requests;
begin
  if requested_type not in ('AUDIO', 'VIDEO', 'SCREEN') then raise exception 'VALIDATION_ERROR'; end if;
  if requested_type = 'SCREEN' and not public.cf_is_pro(actor) then raise exception 'PRO_ENTITLEMENT_REQUIRED'; end if;

  select case when ms.participant_a_id = actor then ms.participant_b_id else ms.participant_a_id end into target
  from public.cf_meet_sessions as ms
  where ms.id = requested_session_id and ms.status = 'ACTIVE'
    and actor in (ms.participant_a_id, ms.participant_b_id);
  if target is null then raise exception 'ROOM_ACCESS_REQUIRED'; end if;
  if exists (
    select 1 from public.cf_meet_media_requests as mr
    where mr.meet_session_id = requested_session_id and mr.requester_id = actor and mr.target_id = target
      and mr.media_type = requested_type and mr.status = 'PENDING'
  ) then raise exception 'MEDIA_REQUEST_PENDING'; end if;

  insert into public.cf_meet_media_requests (meet_session_id, requester_id, target_id, media_type)
    values (requested_session_id, actor, target, requested_type) returning * into inserted;
  update public.cf_meet_media_states as state set
    audio_state = case when requested_type = 'AUDIO' then 'REQUESTED' else state.audio_state end,
    video_state = case when requested_type = 'VIDEO' then 'REQUESTED' else state.video_state end,
    updated_at = now()
    where state.meet_session_id = requested_session_id and state.profile_id = actor;
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type, payload)
    values (requested_session_id, actor, 'MEDIA_REQUESTED', jsonb_build_object('type', requested_type));
  return inserted;
end;
$$;

create or replace function public.cf_can_share_meet_screen(requested_session_id uuid)
returns boolean language sql stable security definer set search_path = public, auth as $$
  select public.cf_is_pro(auth.uid()) and exists (
    select 1 from public.cf_meet_sessions as ms
    where ms.id = requested_session_id and ms.status = 'ACTIVE'
      and auth.uid() in (ms.participant_a_id, ms.participant_b_id)
  );
$$;

-- Supabase Realtime Broadcast is private for each active Meet. Without these
-- policies a JWT cannot subscribe to the WebRTC setup channel.
drop policy if exists "meet participants receive secure signals" on realtime.messages;
drop policy if exists "meet participants send secure signals" on realtime.messages;
create policy "meet participants receive secure signals"
on realtime.messages for select to authenticated using (
  realtime.messages.extension = 'broadcast'
  and exists (
    select 1 from public.cf_meet_sessions as ms
    where realtime.topic() = ('meet-signal:' || ms.id::text)
      and auth.uid() in (ms.participant_a_id, ms.participant_b_id)
  )
);
create policy "meet participants send secure signals"
on realtime.messages for insert to authenticated with check (
  realtime.messages.extension = 'broadcast'
  and exists (
    select 1 from public.cf_meet_sessions as ms
    where realtime.topic() = ('meet-signal:' || ms.id::text)
      and ms.status = 'ACTIVE'
      and auth.uid() in (ms.participant_a_id, ms.participant_b_id)
  )
);

revoke all on function public.cf_can_share_meet_screen(uuid) from public;
grant execute on function public.cf_can_share_meet_screen(uuid) to authenticated;
