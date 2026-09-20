-- CONFLUX direct Meet, privacy-scoped availability, and showcase intent.
--
-- Ranked Meet remains deliberately finite. These additions are for an explicit
-- person the member selected from Discover, a connection, or a Build Room.
-- An invitation never enables chat or media until the recipient joins.

alter table public.cf_profiles
  add column if not exists showcase_intents text[] not null default '{}';

alter table public.cf_meet_sessions
  add column if not exists meeting_kind text not null default 'STANDARD';
alter table public.cf_meet_sessions
  drop constraint if exists cf_meet_sessions_meeting_kind_check;
alter table public.cf_meet_sessions
  add constraint cf_meet_sessions_meeting_kind_check
  check (meeting_kind in ('STANDARD', 'SHOWCASE'));

alter table public.cf_profiles
  drop constraint if exists cf_profiles_showcase_intents_limit;
alter table public.cf_profiles
  add constraint cf_profiles_showcase_intents_limit
  check (cardinality(showcase_intents) <= 6);

create index if not exists cf_profiles_showcase_intents_idx
  on public.cf_profiles using gin (showcase_intents);

-- A short server-side heartbeat is intentionally minimal. It exposes only a
-- coarse availability state to an already eligible viewer; it never exposes a
-- user's page, IP address, device, or last-seen history to the browser.
create table if not exists public.cf_profile_presence (
  profile_id uuid primary key references public.cf_profiles(id) on delete cascade,
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.cf_profile_presence enable row level security;
drop policy if exists "profile presence direct reads disabled" on public.cf_profile_presence;
drop policy if exists "profile presence direct writes disabled" on public.cf_profile_presence;
create policy "profile presence direct reads disabled"
  on public.cf_profile_presence for select to authenticated using (false);
create policy "profile presence direct writes disabled"
  on public.cf_profile_presence for insert to authenticated with check (false);

create or replace function public.cf_heartbeat_presence()
returns void language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null or not exists (
    select 1 from public.cf_profiles
    where id = actor and onboarding_complete
  ) then
    raise exception 'AUTH_REQUIRED';
  end if;

  insert into public.cf_profile_presence (profile_id, last_seen_at, updated_at)
  values (actor, now(), now())
  on conflict (profile_id) do update set
    last_seen_at = excluded.last_seen_at,
    updated_at = excluded.updated_at;
end;
$$;

-- This is deliberately a coarse, present-tense status. It is only available
-- for a discoverable builder or an existing mutual connection, and is computed
-- on the server rather than trusting a client-provided presence claim.
create or replace function public.cf_get_direct_meet_status(requested_candidate_id uuid)
returns table (status text)
language sql stable security definer set search_path = public, auth as $$
  select case
    when exists (
      select 1 from public.cf_meet_sessions as session
      where requested_candidate_id in (session.participant_a_id, session.participant_b_id)
        and session.status in ('PENDING_JOIN', 'ACTIVE')
    ) then 'IN_MEET'
    when presence.last_seen_at >= now() - interval '90 seconds'
      and profile.meet_available then 'ONLINE_AVAILABLE'
    when presence.last_seen_at >= now() - interval '90 seconds' then 'ONLINE'
    else 'OFFLINE'
  end
  from public.cf_profiles as profile
  left join public.cf_profile_presence as presence on presence.profile_id = profile.id
  where requested_candidate_id <> auth.uid()
    and profile.id = requested_candidate_id
    and profile.onboarding_complete
    and not exists (
      select 1 from public.cf_blocks as block
      where (block.blocker_id = auth.uid() and block.blocked_id = profile.id)
         or (block.blocker_id = profile.id and block.blocked_id = auth.uid())
    )
    and (
      profile.is_discoverable
      or exists (
        select 1 from public.cf_connections as connection
        where auth.uid() in (connection.low_profile_id, connection.high_profile_id)
          and profile.id in (connection.low_profile_id, connection.high_profile_id)
      )
    );
$$;

-- Direct Meet is an explicit invitation, not a bypass around ranked discovery.
-- Previous Meets and mutual connections are intentionally eligible here, while
-- blocks, active sessions, and recipient consent remain server-authoritative.
create or replace function public.cf_open_direct_meet(
  candidate_id uuid,
  requested_source text default 'DIRECT'
)
returns uuid language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  new_session_id uuid;
  source text := upper(trim(coalesce(requested_source, 'DIRECT')));
begin
  if actor is null or actor = candidate_id then
    raise exception 'MEET_NOT_ALLOWED';
  end if;
  if source not in ('DIRECT', 'SHOWCASE', 'CONNECTION', 'BUILD_ROOM') then
    source := 'DIRECT';
  end if;

  if exists (
    select 1 from public.cf_meet_sessions as session
    where actor in (session.participant_a_id, session.participant_b_id)
      and session.status in ('PENDING_JOIN', 'ACTIVE')
  ) then
    raise exception 'MEET_ALREADY_ACTIVE';
  end if;

  if exists (
    select 1 from public.cf_meet_sessions as session
    where candidate_id in (session.participant_a_id, session.participant_b_id)
      and session.status in ('PENDING_JOIN', 'ACTIVE')
  ) then
    raise exception 'CANDIDATE_IN_MEET';
  end if;

  if not exists (
    select 1 from public.cf_profiles as profile
    where profile.id = candidate_id
      and profile.onboarding_complete
      and not exists (
        select 1 from public.cf_blocks as block
        where (block.blocker_id = actor and block.blocked_id = profile.id)
           or (block.blocker_id = profile.id and block.blocked_id = actor)
      )
      and (
        profile.is_discoverable
        or exists (
          select 1 from public.cf_connections as connection
          where actor in (connection.low_profile_id, connection.high_profile_id)
            and profile.id in (connection.low_profile_id, connection.high_profile_id)
        )
      )
  ) then
    raise exception 'CANDIDATE_UNAVAILABLE';
  end if;

  insert into public.cf_meet_sessions (
    participant_a_id, participant_b_id, status, meeting_kind
  ) values (
    actor,
    candidate_id,
    'PENDING_JOIN',
    case when source = 'SHOWCASE' then 'SHOWCASE' else 'STANDARD' end
  )
  returning id into new_session_id;

  insert into public.cf_meet_participant_states (meet_session_id, profile_id, state)
  values
    (new_session_id, actor, 'JOINED'),
    (new_session_id, candidate_id, 'INVITED');
  insert into public.cf_meet_media_states (meet_session_id, profile_id)
  values (new_session_id, actor), (new_session_id, candidate_id)
  on conflict do nothing;
  insert into public.cf_meet_events (meet_session_id, actor_id, event_type, payload)
  values (
    new_session_id,
    actor,
    'MEET_STARTED',
    jsonb_build_object('candidate_id', candidate_id, 'mode', 'DIRECT', 'source', source)
  );
  insert into public.cf_notifications (profile_id, kind, payload)
  values (
    candidate_id,
    case when source = 'SHOWCASE' then 'SHOWCASE_MEET_INVITE' else 'MEET_JOIN_REQUEST' end,
    jsonb_build_object(
      'meet_session_id', new_session_id,
      'candidate_id', actor,
      'mode', 'DIRECT',
      'source', source
    )
  );

  return new_session_id;
end;
$$;

-- Keep the original onboarding signature available to older clients. New
-- clients send this explicit, bounded preference set as part of the same
-- server-authoritative profile completion transaction.
create or replace function public.cf_complete_onboarding(
  requested_username text,
  requested_full_name text,
  requested_headline text,
  requested_skills text[],
  requested_interests text[],
  requested_build text,
  requested_connections text,
  requested_date_of_birth date,
  requested_gender text,
  requested_linkedin_url text,
  requested_github_url text,
  requested_portfolio_url text,
  requested_mobile_number text,
  requested_showcase_intents text[]
)
returns void language plpgsql security definer set search_path = public, auth as $$
declare
  actor uuid := auth.uid();
  clean_showcase_intents text[] := coalesce(requested_showcase_intents, '{}'::text[]);
begin
  if actor is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists (select 1 from auth.users where id = actor and email_confirmed_at is not null) then raise exception 'EMAIL_NOT_VERIFIED'; end if;
  if requested_username !~ '^[A-Za-z0-9_]{3,30}$' then raise exception 'INVALID_USERNAME'; end if;
  if char_length(trim(requested_full_name)) < 1 then raise exception 'NAME_REQUIRED'; end if;
  if coalesce(cardinality(requested_skills), 0) < 1 then raise exception 'SKILL_REQUIRED'; end if;
  if coalesce(cardinality(requested_interests), 0) < 1 then raise exception 'INTEREST_REQUIRED'; end if;
  if char_length(trim(requested_build)) < 1 then raise exception 'BUILD_REQUIRED'; end if;
  if char_length(trim(requested_connections)) < 1 then raise exception 'CONNECTION_INTENT_REQUIRED'; end if;
  if requested_date_of_birth is null or requested_date_of_birth > current_date - interval '16 years' then raise exception 'AGE_REQUIREMENT_NOT_MET'; end if;
  if requested_gender not in ('WOMAN', 'MAN', 'NON_BINARY', 'SELF_DESCRIBE', 'PREFER_NOT_TO_SAY') then raise exception 'GENDER_REQUIRED'; end if;
  if requested_linkedin_url !~* '^https?://(www\.)?linkedin\.com/' then raise exception 'VALID_LINKEDIN_REQUIRED'; end if;
  if requested_github_url !~* '^https?://(www\.)?github\.com/' then raise exception 'VALID_GITHUB_REQUIRED'; end if;
  if coalesce(cardinality(clean_showcase_intents), 0) > 6 then raise exception 'SHOWCASE_INTENT_LIMIT_REACHED'; end if;

  insert into public.cf_profiles (
    id, username, full_name, headline, skills, interests, current_build,
    looking_for, date_of_birth, gender, showcase_intents, email_verified,
    onboarding_complete, is_discoverable
  ) values (
    actor, trim(requested_username), trim(requested_full_name),
    nullif(trim(requested_headline), ''), requested_skills, requested_interests,
    trim(requested_build), trim(requested_connections), requested_date_of_birth,
    requested_gender, clean_showcase_intents, true, true, true
  ) on conflict (id) do update set
    username = excluded.username,
    full_name = excluded.full_name,
    headline = excluded.headline,
    skills = excluded.skills,
    interests = excluded.interests,
    current_build = excluded.current_build,
    looking_for = excluded.looking_for,
    date_of_birth = excluded.date_of_birth,
    gender = excluded.gender,
    showcase_intents = excluded.showcase_intents,
    email_verified = true,
    onboarding_complete = true,
    updated_at = now();

  insert into public.cf_profile_contacts (
    profile_id, linkedin_url, github_url, website_url, mobile_number,
    links_visible_to_connections
  ) values (
    actor, trim(requested_linkedin_url), trim(requested_github_url),
    nullif(trim(requested_portfolio_url), ''),
    nullif(trim(requested_mobile_number), ''), true
  ) on conflict (profile_id) do update set
    linkedin_url = excluded.linkedin_url,
    github_url = excluded.github_url,
    website_url = excluded.website_url,
    mobile_number = excluded.mobile_number,
    updated_at = now();
end;
$$;

revoke all on function public.cf_heartbeat_presence() from public;
revoke all on function public.cf_get_direct_meet_status(uuid) from public;
revoke all on function public.cf_open_direct_meet(uuid, text) from public;
revoke all on function public.cf_complete_onboarding(text, text, text, text[], text[], text, text, date, text, text, text, text, text, text[]) from public;
grant execute on function public.cf_heartbeat_presence(), public.cf_get_direct_meet_status(uuid), public.cf_open_direct_meet(uuid, text), public.cf_complete_onboarding(text, text, text, text[], text[], text, text, date, text, text, text, text, text, text[]) to authenticated;

notify pgrst, 'reload schema';
