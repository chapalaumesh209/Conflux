-- CONFLUX availability, repeat introductions, and public product showcases.
-- Availability is an explicit user signal, never an implicit permission to
-- start a call. A previous non-connection can be ranked again after 24 hours.

alter table public.cf_profiles
  add column if not exists meet_available boolean not null default false;
alter table public.cf_profiles
  add column if not exists meet_available_updated_at timestamptz;

alter table public.cf_projects
  add column if not exists showcase_enabled boolean not null default false;
alter table public.cf_projects
  add column if not exists showcase_pitch text check (char_length(showcase_pitch) <= 500);
alter table public.cf_projects
  add column if not exists demo_url text check (char_length(demo_url) <= 2048);

create index if not exists cf_profiles_available_meet_idx
  on public.cf_profiles (meet_available, updated_at desc)
  where meet_available;
create index if not exists cf_projects_showcase_idx
  on public.cf_projects (showcase_enabled, is_public, archived_at, updated_at desc)
  where showcase_enabled;

create or replace function public.cf_touch_meet_availability()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.meet_available is distinct from old.meet_available then
    new.meet_available_updated_at = now();
  end if;
  return new;
end;
$$;

drop trigger if exists cf_profiles_meet_availability_touch on public.cf_profiles;
create trigger cf_profiles_meet_availability_touch
  before update of meet_available on public.cf_profiles
  for each row execute procedure public.cf_touch_meet_availability();

create or replace function public.cf_get_meet_availability(requested_candidate_id uuid)
returns boolean language sql stable security definer set search_path = public, auth as $$
  select coalesce(profile.meet_available, false)
  from public.cf_profiles as profile
  where profile.id = requested_candidate_id
    and profile.is_discoverable
    and profile.onboarding_complete
    and not exists (
      select 1 from public.cf_blocks as block
      where (block.blocker_id = auth.uid() and block.blocked_id = profile.id)
         or (block.blocker_id = profile.id and block.blocked_id = auth.uid())
    );
$$;

-- The Meet queue stays finite: previously seen people are suppressed for a
-- calendar day, then may be ranked again only if they are still eligible and
-- no mutual connection was formed.
create or replace function public.cf_meet_candidate_preview(
  excluded_candidate_ids uuid[] default '{}'::uuid[]
)
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
    select skills, domains, goals, interests, current_build
    from public.cf_profiles where id = auth.uid()
  ), eligible as (
    select p.*,
      array(select item from unnest(coalesce(p.skills, '{}'::text[])) item where item = any(coalesce(me.skills, '{}'::text[])) order by lower(item)) as shared_skills,
      array(select item from unnest(coalesce(p.interests, '{}'::text[])) item where item = any(coalesce(me.interests, '{}'::text[])) order by lower(item)) as shared_interests,
      array(select item from unnest(coalesce(p.domains, '{}'::text[])) item where item = any(coalesce(me.domains, '{}'::text[])) order by lower(item)) as shared_domains,
      array(select item from unnest(coalesce(p.goals, '{}'::text[])) item where item = any(coalesce(me.goals, '{}'::text[])) order by lower(item)) as shared_goals
    from public.cf_profiles p cross join me
    where p.id <> auth.uid()
      and p.id <> all(coalesce(excluded_candidate_ids, '{}'::uuid[]))
      and p.is_discoverable and p.onboarding_complete
      and not exists (select 1 from public.cf_blocks b where (b.blocker_id = auth.uid() and b.blocked_id = p.id) or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
      and not exists (select 1 from public.cf_connections c where auth.uid() in (c.low_profile_id, c.high_profile_id) and p.id in (c.low_profile_id, c.high_profile_id))
      and not exists (
        select 1 from public.cf_meet_sessions s
        where auth.uid() in (s.participant_a_id, s.participant_b_id)
          and p.id in (s.participant_a_id, s.participant_b_id)
          and s.created_at >= now() - interval '24 hours'
      )
  ), ranked as (
    select p.*,
      array_remove(array[
        case when cardinality(shared_skills) > 0 then 'You both work with ' || array_to_string(shared_skills[1:2], ' and ') end,
        case when cardinality(shared_interests) > 0 then 'You both care about ' || array_to_string(shared_interests[1:2], ' and ') end,
        case when cardinality(shared_domains) > 0 then 'You both explore ' || array_to_string(shared_domains[1:2], ' and ') end,
        case when cardinality(shared_goals) > 0 then 'You are both working toward ' || array_to_string(shared_goals[1:2], ' and ') end,
        case when looking_for is not null and (select current_build from me) is not null then 'Their collaboration goal may fit what you are building' end
      ], null) as reasons,
      (cardinality(shared_skills) * 40) + (cardinality(shared_interests) * 30) + (cardinality(shared_domains) * 22) + (cardinality(shared_goals) * 18)
        + case when p.meet_available then 12 else 0 end
        + case when looking_for is not null and (select current_build from me) is not null then 6 else 0 end as relevance_score
    from eligible as p
  )
  select id, username, full_name, headline, city, experience_band, skills, domains, goals, current_build, looking_for, avatar_url, email_verified, github_verified, linkedin_verified,
    coalesce(reasons[1], 'Their public builder context is ready for a focused introduction'),
    case when cardinality(reasons) > 0 then reasons[1:3] else array['Their public builder context is ready for a focused introduction']::text[] end
  from ranked
  order by meet_available desc, relevance_score desc, updated_at desc, id
  limit 1;
$$;

drop function if exists public.cf_discover_projects_v3(integer, integer);
create function public.cf_discover_projects_v3(
  result_limit integer default 3,
  result_offset integer default 0
)
returns table (
  id uuid, slug text, name text, summary text, idea text, stage text, goals text,
  collaboration_enabled boolean, showcase_enabled boolean, showcase_pitch text,
  demo_url text, owner_id uuid, owner_username text, owner_full_name text,
  match_reasons text[], ranker_version text
)
language sql stable security definer set search_path = public, auth as $$
  with me as (select skills, domains, goals from public.cf_profiles where id = auth.uid()),
  eligible as (
    select project.*, owner.username as candidate_username, owner.full_name as candidate_full_name,
      array(select skill from unnest(coalesce(me.skills, '{}'::text[])) skill where char_length(btrim(skill)) >= 2 and lower(concat_ws(' ', project.name, project.idea, project.summary, project.problem, project.goals, project.showcase_pitch)) like '%' || lower(btrim(skill)) || '%' order by lower(skill) limit 2) as matching_skills,
      array(select domain from unnest(coalesce(me.domains, '{}'::text[])) domain where char_length(btrim(domain)) >= 2 and lower(concat_ws(' ', project.name, project.idea, project.summary, project.problem, project.goals, project.showcase_pitch)) like '%' || lower(btrim(domain)) || '%' order by lower(domain) limit 2) as matching_domains,
      array(select goal from unnest(coalesce(me.goals, '{}'::text[])) goal where char_length(btrim(goal)) >= 2 and lower(concat_ws(' ', project.name, project.idea, project.summary, project.problem, project.goals, project.showcase_pitch)) like '%' || lower(btrim(goal)) || '%' order by lower(goal) limit 1) as matching_goals
    from public.cf_projects project join public.cf_profiles owner on owner.id = project.owner_id cross join me
    where project.owner_id <> auth.uid() and project.archived_at is null and (project.is_public or project.visibility = 'PUBLIC')
      and owner.is_discoverable and owner.onboarding_complete
      and not exists (select 1 from public.cf_blocks b where (b.blocker_id = auth.uid() and b.blocked_id = owner.id) or (b.blocker_id = owner.id and b.blocked_id = auth.uid()))
      and not exists (select 1 from public.cf_connections c where auth.uid() in (c.low_profile_id, c.high_profile_id) and owner.id in (c.low_profile_id, c.high_profile_id))
  ), ranked as (
    select eligible.*, array_remove(array[
      case when cardinality(matching_skills) > 0 then 'Your ' || array_to_string(matching_skills, ' and ') || ' skills match this product''s direction' end,
      case when cardinality(matching_domains) > 0 then 'It is relevant to your ' || array_to_string(matching_domains, ' and ') || ' focus' end,
      case when cardinality(matching_goals) > 0 then 'Its public goal aligns with ' || array_to_string(matching_goals, ' and ') end,
      case when collaboration_enabled then 'The presenter is open to collaboration requests' end,
      case when showcase_enabled then 'This owner chose to present their product publicly' end
    ], null) as reasons,
    (cardinality(matching_skills) * 40) + (cardinality(matching_domains) * 24) + (cardinality(matching_goals) * 18) + case when collaboration_enabled then 8 else 0 end + case when showcase_enabled then 10 else 0 end as relevance_score
    from eligible
  )
  select id, slug, name, summary, idea, stage, goals, collaboration_enabled, showcase_enabled, showcase_pitch, demo_url, owner_id, candidate_username, candidate_full_name,
    case when cardinality(reasons) > 0 then reasons[1:3] else array['Its public product context is ready for a focused introduction']::text[] end,
    'showcase-v1'::text
  from ranked order by relevance_score desc, updated_at desc, id
  offset greatest(0, result_offset) limit greatest(1, least(result_limit, 6));
$$;

revoke all on function public.cf_get_meet_availability(uuid) from public;
grant execute on function public.cf_get_meet_availability(uuid), public.cf_meet_candidate_preview(uuid[]), public.cf_discover_projects_v3(integer, integer) to authenticated;
notify pgrst, 'reload schema';
