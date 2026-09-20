-- CONFLUX Meet invitations and participant presence
--
-- A Meet begins with a directed, persisted invitation. The recipient decides
-- Join or Ignore; only after Join do text, audio, video, and Connect become
-- available. Ephemeral online presence is delivered through a private Realtime
-- topic, while the invite/decision stays durable in Postgres.

alter table public.cf_meet_sessions
  drop constraint if exists cf_meet_sessions_status_check;
alter table public.cf_meet_sessions
  add constraint cf_meet_sessions_status_check
  check (status in ('PENDING_JOIN', 'ACTIVE', 'CLOSED', 'SAFETY_CLOSED'));

create table if not exists public.cf_meet_participant_states (
  meet_session_id uuid not null references public.cf_meet_sessions(id) on delete cascade,
  profile_id uuid not null references public.cf_profiles(id) on delete cascade,
  state text not null check (state in ('INVITED', 'JOINED', 'IGNORED', 'LEFT')),
  updated_at timestamptz not null default now(),
  primary key (meet_session_id, profile_id)
);

alter table public.cf_meet_participant_states enable row level security;
drop policy if exists "meet participant states participants read" on public.cf_meet_participant_states;
drop policy if exists "meet participant states direct write disabled" on public.cf_meet_participant_states;
create policy "meet participant states participants read"
  on public.cf_meet_participant_states for select to authenticated using (
    exists (
      select 1 from public.cf_meet_sessions as session
      where session.id = meet_session_id
        and auth.uid() in (session.participant_a_id, session.participant_b_id)
    )
  );
create policy "meet participant states direct write disabled"
  on public.cf_meet_participant_states for insert to authenticated with check (false);

-- Older active Meets were created before invitation states existed. Treat both
-- participants as joined so previously open conversations remain usable.
insert into public.cf_meet_participant_states (meet_session_id, profile_id, state)
select session.id, session.participant_a_id, 'JOINED'
from public.cf_meet_sessions as session
where session.status = 'ACTIVE'
on conflict (meet_session_id, profile_id) do nothing;

insert into public.cf_meet_participant_states (meet_session_id, profile_id, state)
select session.id, session.participant_b_id, 'JOINED'
from public.cf_meet_sessions as session
where session.status = 'ACTIVE'
on conflict (meet_session_id, profile_id) do nothing;

create or replace function public.cf_open_meet(candidate_id uuid)
returns uuid language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  existing_session_id uuid;
  new_session_id uuid;
begin
  if actor is null or actor = candidate_id then raise exception 'MEET_NOT_ALLOWED'; end if;

  select session.id into existing_session_id
  from public.cf_meet_sessions as session
  where actor in (session.participant_a_id, session.participant_b_id)
    and session.status in ('PENDING_JOIN', 'ACTIVE')
  order by session.created_at desc
  limit 1;
  if existing_session_id is not null then return existing_session_id; end if;

  if not exists (
    select 1 from public.cf_profiles as profile
    where profile.id = candidate_id
      and profile.is_discoverable
      and profile.onboarding_complete
      and not exists (
        select 1 from public.cf_blocks as block
        where (block.blocker_id = actor and block.blocked_id = profile.id)
           or (block.blocker_id = profile.id and block.blocked_id = actor)
      )
      and not exists (
        select 1 from public.cf_connections as connection
        where actor in (connection.low_profile_id, connection.high_profile_id)
          and profile.id in (connection.low_profile_id, connection.high_profile_id)
      )
      and not exists (
        select 1 from public.cf_meet_sessions as prior
        where actor in (prior.participant_a_id, prior.participant_b_id)
          and profile.id in (prior.participant_a_id, prior.participant_b_id)
      )
  ) then raise exception 'CANDIDATE_UNAVAILABLE'; end if;

  insert into public.cf_meet_sessions (participant_a_id, participant_b_id, status)
  values (actor, candidate_id, 'PENDING_JOIN')
  returning id into new_session_id;

  insert into public.cf_meet_participant_states (meet_session_id, profile_id, state)
  values
    (new_session_id, actor, 'JOINED'),
    (new_session_id, candidate_id, 'INVITED');
  insert into public.cf_meet_media_states (meet_session_id, profile_id)
  values (new_session_id, actor), (new_session_id, candidate_id)
  on conflict do nothing;
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type, payload)
  values (new_session_id, actor, 'MEET_STARTED', jsonb_build_object('candidate_id', candidate_id));
  insert into public.cf_notifications (profile_id, kind, payload)
  values (
    candidate_id,
    'MEET_JOIN_REQUEST',
    jsonb_build_object('meet_session_id', new_session_id, 'candidate_id', actor)
  );

  return new_session_id;
end;
$$;

drop function if exists public.cf_get_active_meet();
create function public.cf_get_active_meet()
returns table (
  session_id uuid,
  candidate_id uuid,
  username text,
  full_name text,
  headline text,
  city text,
  experience_band text,
  skills text[],
  domains text[],
  goals text[],
  current_build text,
  looking_for text,
  avatar_url text,
  email_verified boolean,
  github_verified boolean,
  linkedin_verified boolean,
  my_decision text,
  their_decision text,
  session_status text,
  my_presence text,
  peer_presence text,
  created_at timestamptz
)
language sql stable security definer set search_path = public, auth as $$
  select
    session.id,
    peer.id,
    peer.username,
    peer.full_name,
    peer.headline,
    peer.city,
    peer.experience_band,
    peer.skills,
    peer.domains,
    peer.goals,
    peer.current_build,
    peer.looking_for,
    peer.avatar_url,
    peer.email_verified,
    peer.github_verified,
    peer.linkedin_verified,
    case when session.participant_a_id = auth.uid() then session.a_decision else session.b_decision end,
    case when session.participant_a_id = auth.uid() then session.b_decision else session.a_decision end,
    session.status,
    coalesce(my_state.state, case when session.status = 'ACTIVE' then 'JOINED' else 'INVITED' end),
    coalesce(peer_state.state, case when session.status = 'ACTIVE' then 'JOINED' else 'INVITED' end),
    session.created_at
  from public.cf_meet_sessions as session
  join public.cf_profiles as peer on peer.id = case
    when session.participant_a_id = auth.uid() then session.participant_b_id
    else session.participant_a_id
  end
  left join public.cf_meet_participant_states as my_state
    on my_state.meet_session_id = session.id and my_state.profile_id = auth.uid()
  left join public.cf_meet_participant_states as peer_state
    on peer_state.meet_session_id = session.id and peer_state.profile_id = peer.id
  where auth.uid() in (session.participant_a_id, session.participant_b_id)
    and session.status in ('PENDING_JOIN', 'ACTIVE')
  order by session.created_at desc
  limit 1;
$$;

create or replace function public.cf_join_meet(requested_session_id uuid)
returns table (status text, peer_presence text)
language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  meeting public.cf_meet_sessions;
  peer_id uuid;
begin
  select * into meeting from public.cf_meet_sessions as session
  where session.id = requested_session_id for update;
  if not found or actor not in (meeting.participant_a_id, meeting.participant_b_id) then
    raise exception 'ROOM_ACCESS_REQUIRED';
  end if;
  if meeting.status not in ('PENDING_JOIN', 'ACTIVE') then raise exception 'MEET_NOT_ACTIVE'; end if;
  if actor <> meeting.participant_b_id and meeting.status = 'PENDING_JOIN' then
    raise exception 'WAITING_FOR_RECIPIENT';
  end if;

  peer_id := case when actor = meeting.participant_a_id then meeting.participant_b_id else meeting.participant_a_id end;
  update public.cf_meet_participant_states
  set state = 'JOINED', updated_at = now()
  where meet_session_id = requested_session_id and profile_id = actor;
  update public.cf_meet_sessions
  set status = 'ACTIVE', updated_at = now()
  where id = requested_session_id and status = 'PENDING_JOIN';
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type)
  values (requested_session_id, actor, 'CANDIDATE_SHOWN');
  insert into public.cf_notifications (profile_id, kind, payload)
  values (
    peer_id,
    'MEET_JOINED',
    jsonb_build_object('meet_session_id', requested_session_id, 'candidate_id', actor)
  );
  return query select 'ACTIVE'::text, 'JOINED'::text;
end;
$$;

create or replace function public.cf_ignore_meet(requested_session_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  meeting public.cf_meet_sessions;
begin
  select * into meeting from public.cf_meet_sessions as session
  where session.id = requested_session_id for update;
  if not found or actor <> meeting.participant_b_id or meeting.status <> 'PENDING_JOIN' then
    raise exception 'MEET_INVITE_NOT_AVAILABLE';
  end if;
  update public.cf_meet_participant_states
  set state = 'IGNORED', updated_at = now()
  where meet_session_id = requested_session_id and profile_id = actor;
  update public.cf_meet_sessions
  set status = 'CLOSED', ended_at = now(), updated_at = now()
  where id = requested_session_id;
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type)
  values (requested_session_id, actor, 'NEXT');
  insert into public.cf_notifications (profile_id, kind, payload)
  values (
    meeting.participant_a_id,
    'MEET_IGNORED',
    jsonb_build_object('meet_session_id', requested_session_id, 'candidate_id', actor)
  );
end;
$$;

create or replace function public.cf_cancel_meet_invitation(requested_session_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  meeting public.cf_meet_sessions;
begin
  select * into meeting from public.cf_meet_sessions as session
  where session.id = requested_session_id for update;
  if not found or actor <> meeting.participant_a_id or meeting.status <> 'PENDING_JOIN' then
    raise exception 'MEET_INVITE_NOT_AVAILABLE';
  end if;
  update public.cf_meet_participant_states
  set state = 'LEFT', updated_at = now()
  where meet_session_id = requested_session_id and profile_id = actor;
  update public.cf_meet_sessions
  set status = 'CLOSED', ended_at = now(), updated_at = now()
  where id = requested_session_id;
end;
$$;

revoke all on function public.cf_get_active_meet() from public;
revoke all on function public.cf_join_meet(uuid) from public;
revoke all on function public.cf_ignore_meet(uuid) from public;
revoke all on function public.cf_cancel_meet_invitation(uuid) from public;
grant execute on function public.cf_get_active_meet(), public.cf_open_meet(uuid), public.cf_join_meet(uuid), public.cf_ignore_meet(uuid), public.cf_cancel_meet_invitation(uuid) to authenticated;

-- Realtime presence is authorization-scoped to exactly the two participants.
drop policy if exists "meet participants receive secure signals" on realtime.messages;
drop policy if exists "meet participants send secure signals" on realtime.messages;
create policy "meet participants receive secure signals"
on realtime.messages for select to authenticated using (
  realtime.messages.extension in ('broadcast', 'presence')
  and exists (
    select 1 from public.cf_meet_sessions as session
    where realtime.topic() in (
      'meet-signal:' || session.id::text,
      'meet-presence:' || session.id::text
    )
      and auth.uid() in (session.participant_a_id, session.participant_b_id)
      and session.status in ('PENDING_JOIN', 'ACTIVE')
  )
);
create policy "meet participants send secure signals"
on realtime.messages for insert to authenticated with check (
  (
    realtime.messages.extension = 'broadcast'
    and exists (
      select 1 from public.cf_meet_sessions as session
      where realtime.topic() = ('meet-signal:' || session.id::text)
        and auth.uid() in (session.participant_a_id, session.participant_b_id)
        and session.status = 'ACTIVE'
    )
  ) or (
    realtime.messages.extension = 'presence'
    and exists (
      select 1 from public.cf_meet_sessions as session
      where realtime.topic() = ('meet-presence:' || session.id::text)
        and auth.uid() in (session.participant_a_id, session.participant_b_id)
        and session.status in ('PENDING_JOIN', 'ACTIVE')
    )
  )
);

notify pgrst, 'reload schema';
