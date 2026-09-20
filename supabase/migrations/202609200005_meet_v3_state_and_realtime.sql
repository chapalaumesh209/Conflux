-- CONFLUX V3 Meet state, messaging, safety, and consent foundation.
--
-- This migration keeps the V2 no-countdown product behavior. It provides the
-- authoritative state required by the Meet client; WebRTC transport still
-- needs separately configured signaling and TURN infrastructure.

alter table public.cf_meet_messages
  add column if not exists client_message_id uuid;

create unique index if not exists cf_meet_messages_client_message_unique_idx
  on public.cf_meet_messages (client_message_id)
  where client_message_id is not null;

create table if not exists public.cf_meet_media_requests (
  id uuid primary key default gen_random_uuid(),
  meet_session_id uuid not null references public.cf_meet_sessions(id) on delete cascade,
  requester_id uuid not null references public.cf_profiles(id) on delete cascade,
  target_id uuid not null references public.cf_profiles(id) on delete cascade,
  media_type text not null check (media_type in ('AUDIO', 'VIDEO')),
  status text not null default 'PENDING' check (status in ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (requester_id <> target_id)
);

create unique index if not exists cf_meet_media_requests_one_pending_idx
  on public.cf_meet_media_requests (meet_session_id, requester_id, target_id, media_type)
  where status = 'PENDING';

create table if not exists public.cf_meet_media_states (
  meet_session_id uuid not null references public.cf_meet_sessions(id) on delete cascade,
  profile_id uuid not null references public.cf_profiles(id) on delete cascade,
  audio_state text not null default 'OFF' check (audio_state in ('OFF', 'REQUESTED', 'ACTIVE', 'FAILED')),
  video_state text not null default 'OFF' check (video_state in ('OFF', 'REQUESTED', 'ACTIVE', 'FAILED')),
  screen_share_active boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (meet_session_id, profile_id)
);

create table if not exists public.cf_meet_events (
  id uuid primary key default gen_random_uuid(),
  meet_session_id uuid not null references public.cf_meet_sessions(id) on delete cascade,
  actor_id uuid references public.cf_profiles(id) on delete set null,
  event_type text not null check (event_type in ('MEET_STARTED', 'CANDIDATE_SHOWN', 'MESSAGE_SENT', 'CONNECT', 'NEXT', 'ENDED', 'BLOCKED', 'MEDIA_REQUESTED', 'MEDIA_RESOLVED')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists cf_meet_events_session_created_idx
  on public.cf_meet_events (meet_session_id, created_at desc);

alter table public.cf_meet_media_requests enable row level security;
alter table public.cf_meet_media_states enable row level security;
alter table public.cf_meet_events enable row level security;

drop policy if exists "meet media request participants read" on public.cf_meet_media_requests;
drop policy if exists "meet media request direct write disabled" on public.cf_meet_media_requests;
drop policy if exists "meet media state participants read" on public.cf_meet_media_states;
drop policy if exists "meet media state direct write disabled" on public.cf_meet_media_states;
drop policy if exists "meet events participants read" on public.cf_meet_events;
drop policy if exists "meet events direct write disabled" on public.cf_meet_events;
drop policy if exists "meet messages participants send" on public.cf_meet_messages;
drop policy if exists "meet messages direct browser insert disabled" on public.cf_meet_messages;

create policy "meet media request participants read" on public.cf_meet_media_requests for select to authenticated using (
  auth.uid() in (requester_id, target_id)
);
create policy "meet media request direct write disabled" on public.cf_meet_media_requests for insert to authenticated with check (false);
create policy "meet media state participants read" on public.cf_meet_media_states for select to authenticated using (
  exists (select 1 from public.cf_meet_sessions s where s.id = meet_session_id and auth.uid() in (s.participant_a_id, s.participant_b_id))
);
create policy "meet media state direct write disabled" on public.cf_meet_media_states for insert to authenticated with check (false);
create policy "meet events participants read" on public.cf_meet_events for select to authenticated using (
  exists (select 1 from public.cf_meet_sessions s where s.id = meet_session_id and auth.uid() in (s.participant_a_id, s.participant_b_id))
);
create policy "meet events direct write disabled" on public.cf_meet_events for insert to authenticated with check (false);
create policy "meet messages direct browser insert disabled" on public.cf_meet_messages for insert to authenticated with check (false);

create or replace function public.cf_meet_candidate_preview()
returns table (
  id uuid,
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
  match_reason text,
  match_reasons text[]
)
language sql stable security definer set search_path = public, auth as $$
  with me as (
    select * from public.cf_profiles where id = auth.uid()
  ), eligible as (
    select p.*,
      array_remove(array[
        case when p.skills && coalesce((select skills from me), '{}'::text[])
          then 'Shared skills: ' || array_to_string(array(select unnest(p.skills) intersect select unnest(coalesce((select skills from me), '{}'::text[])) limit 2), ', ') end,
        case when p.domains && coalesce((select domains from me), '{}'::text[])
          then 'You both explore ' || array_to_string(array(select unnest(p.domains) intersect select unnest(coalesce((select domains from me), '{}'::text[])) limit 2), ' and ') end,
        case when p.goals && coalesce((select goals from me), '{}'::text[])
          then 'Aligned on ' || array_to_string(array(select unnest(p.goals) intersect select unnest(coalesce((select goals from me), '{}'::text[])) limit 1), '') end,
        case when p.looking_for is not null and (select current_build from me) is not null
          then 'Their collaboration goal may fit what you are building' end
      ], null) as reasons
    from public.cf_profiles p
    where p.id <> auth.uid()
      and p.is_discoverable
      and p.onboarding_complete
      and not exists (select 1 from public.cf_blocks b where (b.blocker_id = auth.uid() and b.blocked_id = p.id) or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
      and not exists (select 1 from public.cf_connections c where auth.uid() in (c.low_profile_id, c.high_profile_id) and p.id in (c.low_profile_id, c.high_profile_id))
      and not exists (select 1 from public.cf_meet_sessions s where auth.uid() in (s.participant_a_id, s.participant_b_id) and p.id in (s.participant_a_id, s.participant_b_id))
  )
  select id, username, full_name, headline, city, experience_band, skills, domains, goals, current_build, looking_for, avatar_url,
    email_verified, github_verified, linkedin_verified,
    coalesce(reasons[1], 'Open to a relevant introduction'),
    case when cardinality(reasons) > 0 then reasons else array['Open to a relevant introduction']::text[] end
  from eligible
  order by cardinality(reasons) desc, updated_at desc
  limit 1;
$$;

create or replace function public.cf_get_active_meet()
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
  created_at timestamptz
)
language sql stable security definer set search_path = public, auth as $$
  select s.id, p.id, p.username, p.full_name, p.headline, p.city, p.experience_band, p.skills, p.domains, p.goals,
    p.current_build, p.looking_for, p.avatar_url, p.email_verified, p.github_verified, p.linkedin_verified,
    case when s.participant_a_id = auth.uid() then s.a_decision else s.b_decision end,
    case when s.participant_a_id = auth.uid() then s.b_decision else s.a_decision end,
    s.created_at
  from public.cf_meet_sessions s
  join public.cf_profiles p on p.id = case when s.participant_a_id = auth.uid() then s.participant_b_id else s.participant_a_id end
  where auth.uid() in (s.participant_a_id, s.participant_b_id) and s.status = 'ACTIVE'
  order by s.created_at desc
  limit 1;
$$;

create or replace function public.cf_open_meet(candidate_id uuid)
returns uuid language plpgsql security definer set search_path = public, auth as $$
declare actor uuid := auth.uid(); session_id uuid;
begin
  if actor is null or actor = candidate_id then raise exception 'MEET_NOT_ALLOWED'; end if;
  select id into session_id from public.cf_meet_sessions
  where actor in (participant_a_id, participant_b_id) and status = 'ACTIVE'
  order by created_at desc limit 1;
  if session_id is not null then return session_id; end if;
  if not exists (
    select 1 from public.cf_profiles p
    where p.id = candidate_id and p.is_discoverable and p.onboarding_complete
      and not exists (select 1 from public.cf_blocks b where (b.blocker_id = actor and b.blocked_id = p.id) or (b.blocker_id = p.id and b.blocked_id = actor))
      and not exists (select 1 from public.cf_connections c where actor in (c.low_profile_id, c.high_profile_id) and p.id in (c.low_profile_id, c.high_profile_id))
      and not exists (select 1 from public.cf_meet_sessions s where actor in (s.participant_a_id, s.participant_b_id) and p.id in (s.participant_a_id, s.participant_b_id))
  ) then raise exception 'CANDIDATE_UNAVAILABLE'; end if;
  insert into public.cf_meet_sessions (participant_a_id, participant_b_id) values (actor, candidate_id) returning id into session_id;
  insert into public.cf_meet_media_states (meet_session_id, profile_id) values (session_id, actor), (session_id, candidate_id);
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type, payload) values (session_id, actor, 'MEET_STARTED', jsonb_build_object('candidate_id', candidate_id));
  return session_id;
end;
$$;

create or replace function public.cf_send_meet_message(requested_session_id uuid, requested_body text, requested_client_message_id uuid)
returns public.cf_meet_messages language plpgsql security definer set search_path = public, auth as $$
declare actor uuid := auth.uid(); existing public.cf_meet_messages; inserted public.cf_meet_messages;
begin
  if actor is null then raise exception 'UNAUTHENTICATED'; end if;
  if requested_client_message_id is null then raise exception 'CLIENT_MESSAGE_ID_REQUIRED'; end if;
  if char_length(trim(coalesce(requested_body, ''))) not between 1 and 2000 then raise exception 'VALIDATION_ERROR'; end if;
  if not exists (select 1 from public.cf_meet_sessions where id = requested_session_id and status = 'ACTIVE' and actor in (participant_a_id, participant_b_id)) then raise exception 'ROOM_ACCESS_REQUIRED'; end if;
  select * into existing from public.cf_meet_messages where client_message_id = requested_client_message_id;
  if found then
    if existing.meet_session_id <> requested_session_id or existing.sender_id <> actor then raise exception 'IDEMPOTENCY_KEY_CONFLICT'; end if;
    return existing;
  end if;
  insert into public.cf_meet_messages (meet_session_id, sender_id, body, client_message_id)
  values (requested_session_id, actor, trim(requested_body), requested_client_message_id) returning * into inserted;
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type) values (requested_session_id, actor, 'MESSAGE_SENT');
  return inserted;
end;
$$;

create or replace function public.cf_record_meet_decision(session_id uuid, choice text)
returns table (status text, connection_id uuid) language plpgsql security definer set search_path = public, auth as $$
declare actor uuid := auth.uid(); s public.cf_meet_sessions; low_id uuid; high_id uuid; connection uuid; old_choice text;
begin
  if choice not in ('CONNECT', 'NEXT') then raise exception 'INVALID_DECISION'; end if;
  select * into s from public.cf_meet_sessions where id = session_id for update;
  if not found or actor not in (s.participant_a_id, s.participant_b_id) then raise exception 'ROOM_ACCESS_REQUIRED'; end if;
  if s.status <> 'ACTIVE' then
    if s.connection_id is not null then return query select 'MUTUAL_CONNECTION'::text, s.connection_id; else return query select 'CLOSED'::text, null::uuid; end if;
    return;
  end if;
  old_choice := case when actor = s.participant_a_id then s.a_decision else s.b_decision end;
  if old_choice is not null and old_choice <> choice then raise exception 'DECISION_ALREADY_RECORDED'; end if;
  if actor = s.participant_a_id then update public.cf_meet_sessions set a_decision = choice, updated_at = now() where id = session_id;
  else update public.cf_meet_sessions set b_decision = choice, updated_at = now() where id = session_id; end if;
  if old_choice is null then insert into public.cf_meet_events (meet_session_id, actor_id, event_type) values (session_id, actor, choice); end if;
  select * into s from public.cf_meet_sessions where id = session_id;
  if choice = 'NEXT' or s.a_decision = 'NEXT' or s.b_decision = 'NEXT' then
    update public.cf_meet_sessions set status = 'CLOSED', ended_at = now(), updated_at = now() where id = session_id;
    update public.cf_meet_media_requests set status = 'CANCELLED', resolved_at = now() where meet_session_id = session_id and status = 'PENDING';
    return query select 'CLOSED'::text, null::uuid; return;
  end if;
  if s.a_decision = 'CONNECT' and s.b_decision = 'CONNECT' then
    low_id := least(s.participant_a_id, s.participant_b_id); high_id := greatest(s.participant_a_id, s.participant_b_id);
    insert into public.cf_connections (low_profile_id, high_profile_id, meet_session_id) values (low_id, high_id, session_id)
      on conflict (low_profile_id, high_profile_id) do update set meet_session_id = excluded.meet_session_id returning id into connection;
    update public.cf_meet_sessions set status = 'CLOSED', ended_at = now(), updated_at = now(), connection_id = connection where id = session_id;
    update public.cf_meet_media_requests set status = 'CANCELLED', resolved_at = now() where meet_session_id = session_id and status = 'PENDING';
    insert into public.cf_notifications (profile_id, kind, payload) values
      (s.participant_a_id, 'MUTUAL_CONNECTION', jsonb_build_object('connection_id', connection)),
      (s.participant_b_id, 'MUTUAL_CONNECTION', jsonb_build_object('connection_id', connection));
    return query select 'MUTUAL_CONNECTION'::text, connection; return;
  end if;
  return query select 'PENDING_ONE_WAY'::text, null::uuid;
end;
$$;

create or replace function public.cf_end_meet(requested_session_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare actor uuid := auth.uid();
begin
  if actor is null or not exists (select 1 from public.cf_meet_sessions where id = requested_session_id and status = 'ACTIVE' and actor in (participant_a_id, participant_b_id)) then raise exception 'ROOM_ACCESS_REQUIRED'; end if;
  update public.cf_meet_sessions set status = 'CLOSED', ended_at = now(), updated_at = now() where id = requested_session_id;
  update public.cf_meet_media_requests set status = 'CANCELLED', resolved_at = now() where meet_session_id = requested_session_id and status = 'PENDING';
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type) values (requested_session_id, actor, 'ENDED');
end;
$$;

create or replace function public.cf_request_meet_media(requested_session_id uuid, requested_type text)
returns public.cf_meet_media_requests language plpgsql security definer set search_path = public, auth as $$
declare actor uuid := auth.uid(); target uuid; inserted public.cf_meet_media_requests;
begin
  if requested_type not in ('AUDIO', 'VIDEO') then raise exception 'VALIDATION_ERROR'; end if;
  select case when participant_a_id = actor then participant_b_id else participant_a_id end into target
  from public.cf_meet_sessions where id = requested_session_id and status = 'ACTIVE' and actor in (participant_a_id, participant_b_id);
  if target is null then raise exception 'ROOM_ACCESS_REQUIRED'; end if;
  if exists (select 1 from public.cf_meet_media_requests where meet_session_id = requested_session_id and requester_id = actor and target_id = target and media_type = requested_type and status = 'PENDING') then raise exception 'MEDIA_REQUEST_PENDING'; end if;
  insert into public.cf_meet_media_requests (meet_session_id, requester_id, target_id, media_type) values (requested_session_id, actor, target, requested_type) returning * into inserted;
  update public.cf_meet_media_states set audio_state = case when requested_type = 'AUDIO' then 'REQUESTED' else audio_state end, video_state = case when requested_type = 'VIDEO' then 'REQUESTED' else video_state end, updated_at = now() where meet_session_id = requested_session_id and profile_id = actor;
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type, payload) values (requested_session_id, actor, 'MEDIA_REQUESTED', jsonb_build_object('type', requested_type));
  return inserted;
end;
$$;

create or replace function public.cf_respond_meet_media(request_id uuid, requested_status text)
returns public.cf_meet_media_requests language plpgsql security definer set search_path = public, auth as $$
declare actor uuid := auth.uid(); result public.cf_meet_media_requests;
begin
  if requested_status not in ('ACCEPTED', 'DECLINED') then raise exception 'VALIDATION_ERROR'; end if;
  update public.cf_meet_media_requests r set status = requested_status, resolved_at = now()
  where r.id = request_id and r.target_id = actor and r.status = 'PENDING'
    and exists (select 1 from public.cf_meet_sessions s where s.id = r.meet_session_id and s.status = 'ACTIVE' and actor in (s.participant_a_id, s.participant_b_id))
  returning * into result;
  if not found then raise exception 'MEDIA_REQUEST_UNAVAILABLE'; end if;
  update public.cf_meet_media_states set audio_state = case when result.media_type = 'AUDIO' and requested_status = 'DECLINED' then 'OFF' else audio_state end, video_state = case when result.media_type = 'VIDEO' and requested_status = 'DECLINED' then 'OFF' else video_state end, updated_at = now() where meet_session_id = result.meet_session_id and profile_id = result.requester_id;
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type, payload) values (result.meet_session_id, actor, 'MEDIA_RESOLVED', jsonb_build_object('type', result.media_type, 'status', requested_status));
  return result;
end;
$$;

create or replace function public.cf_block_meet_participant(requested_session_id uuid, requested_subject_id uuid)
returns void language plpgsql security definer set search_path = public, auth as $$
declare actor uuid := auth.uid();
begin
  if actor is null or actor = requested_subject_id or not exists (select 1 from public.cf_meet_sessions where id = requested_session_id and status = 'ACTIVE' and actor in (participant_a_id, participant_b_id) and requested_subject_id in (participant_a_id, participant_b_id)) then raise exception 'ROOM_ACCESS_REQUIRED'; end if;
  insert into public.cf_blocks (blocker_id, blocked_id) values (actor, requested_subject_id) on conflict do nothing;
  update public.cf_meet_sessions set status = 'SAFETY_CLOSED', ended_at = now(), updated_at = now() where id = requested_session_id;
  update public.cf_meet_media_requests set status = 'CANCELLED', resolved_at = now() where meet_session_id = requested_session_id and status = 'PENDING';
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type) values (requested_session_id, actor, 'BLOCKED');
end;
$$;

revoke all on function public.cf_meet_candidate_preview() from public;
revoke all on function public.cf_get_active_meet() from public;
revoke all on function public.cf_open_meet(uuid) from public;
revoke all on function public.cf_send_meet_message(uuid, text, uuid) from public;
revoke all on function public.cf_record_meet_decision(uuid, text) from public;
revoke all on function public.cf_end_meet(uuid) from public;
revoke all on function public.cf_request_meet_media(uuid, text) from public;
revoke all on function public.cf_respond_meet_media(uuid, text) from public;
revoke all on function public.cf_block_meet_participant(uuid, uuid) from public;
grant execute on function public.cf_meet_candidate_preview(), public.cf_get_active_meet(), public.cf_open_meet(uuid), public.cf_send_meet_message(uuid, text, uuid), public.cf_record_meet_decision(uuid, text), public.cf_end_meet(uuid), public.cf_request_meet_media(uuid, text), public.cf_respond_meet_media(uuid, text), public.cf_block_meet_participant(uuid, uuid) to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.cf_meet_sessions;
  alter publication supabase_realtime add table public.cf_meet_media_requests;
  alter publication supabase_realtime add table public.cf_meet_media_states;
exception when duplicate_object or undefined_object then null;
end $$;
