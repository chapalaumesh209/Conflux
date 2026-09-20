-- V3 Discover: a finite, privacy-safe ranked surface that shares Meet's
-- eligibility rules. The functions deliberately return only discovery-safe
-- profile and public-project fields; contact records are never selected.

create index if not exists cf_profiles_discover_v3_idx
  on public.cf_profiles (is_discoverable, onboarding_complete, updated_at desc);

create index if not exists cf_projects_discover_v3_idx
  on public.cf_projects (is_public, visibility, archived_at, updated_at desc);

create or replace function public.cf_discover_builders_v3(
  result_limit integer default 4,
  result_offset integer default 0
)
returns table (
  id uuid,
  username text,
  full_name text,
  headline text,
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
  match_reasons text[],
  ranker_version text
)
language sql stable security definer set search_path = public, auth as $$
  with me as (
    select skills, domains, goals, current_build
    from public.cf_profiles
    where id = auth.uid()
  ), eligible as (
    select
      p.*,
      array(
        select item
        from unnest(coalesce(p.skills, '{}'::text[])) item
        where item = any(coalesce(me.skills, '{}'::text[]))
        order by lower(item)
      ) as shared_skills,
      array(
        select item
        from unnest(coalesce(p.domains, '{}'::text[])) item
        where item = any(coalesce(me.domains, '{}'::text[]))
        order by lower(item)
      ) as shared_domains,
      array(
        select item
        from unnest(coalesce(p.goals, '{}'::text[])) item
        where item = any(coalesce(me.goals, '{}'::text[]))
        order by lower(item)
      ) as shared_goals
    from public.cf_profiles p
    cross join me
    where p.id <> auth.uid()
      and p.is_discoverable
      and p.onboarding_complete
      and not exists (
        select 1 from public.cf_blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
           or (b.blocker_id = p.id and b.blocked_id = auth.uid())
      )
      and not exists (
        select 1 from public.cf_connections c
        where auth.uid() in (c.low_profile_id, c.high_profile_id)
          and p.id in (c.low_profile_id, c.high_profile_id)
      )
      and not exists (
        select 1 from public.cf_meet_sessions s
        where auth.uid() in (s.participant_a_id, s.participant_b_id)
          and p.id in (s.participant_a_id, s.participant_b_id)
      )
  ), ranked as (
    select
      eligible.*,
      array_remove(array[
        case when cardinality(shared_skills) > 0
          then 'You both work with ' || array_to_string(shared_skills[1:2], ' and ') end,
        case when cardinality(shared_domains) > 0
          then 'You both explore ' || array_to_string(shared_domains[1:2], ' and ') end,
        case when cardinality(shared_goals) > 0
          then 'You both care about ' || array_to_string(shared_goals[1:2], ' and ') end,
        case when current_build is not null and nullif(btrim(current_build), '') is not null
          then 'They are actively building ' || left(btrim(current_build), 92) end,
        case when looking_for is not null and nullif(btrim(looking_for), '') is not null
          then 'Their collaboration intent is clear' end,
        case when email_verified and (github_verified or linkedin_verified)
          then 'Their identity has verified signals' end
      ], null) as reasons,
      (cardinality(shared_skills) * 40)
        + (cardinality(shared_domains) * 24)
        + (cardinality(shared_goals) * 18)
        + case when current_build is not null and nullif(btrim(current_build), '') is not null then 8 else 0 end
        + case when looking_for is not null and nullif(btrim(looking_for), '') is not null then 7 else 0 end
        + case when email_verified then 3 else 0 end
        + case when github_verified or linkedin_verified then 3 else 0 end as relevance_score
    from eligible
  )
  select
    id, username, full_name, headline, experience_band, skills, domains, goals,
    current_build, looking_for, avatar_url, email_verified, github_verified,
    linkedin_verified,
    case when cardinality(reasons) > 0 then reasons[1:3]
         else array['Their public builder context is ready for a focused introduction']::text[] end,
    'discover-v3.1'::text
  from ranked
  order by relevance_score desc, updated_at desc, id
  offset greatest(0, result_offset)
  limit greatest(1, least(result_limit, 8));
$$;

create or replace function public.cf_discover_projects_v3(
  result_limit integer default 3,
  result_offset integer default 0
)
returns table (
  id uuid,
  slug text,
  name text,
  summary text,
  idea text,
  stage text,
  goals text,
  collaboration_enabled boolean,
  owner_id uuid,
  owner_username text,
  owner_full_name text,
  match_reasons text[],
  ranker_version text
)
language sql stable security definer set search_path = public, auth as $$
  with me as (
    select skills, domains, goals
    from public.cf_profiles
    where id = auth.uid()
  ), eligible as (
    select
      project.*,
      owner.username as candidate_username,
      owner.full_name as candidate_full_name,
      array(
        select skill
        from unnest(coalesce(me.skills, '{}'::text[])) skill
        where char_length(btrim(skill)) >= 2
          and lower(concat_ws(' ', project.name, project.idea, project.summary, project.problem, project.goals))
            like '%' || lower(btrim(skill)) || '%'
        order by lower(skill)
        limit 2
      ) as matching_skills,
      array(
        select domain
        from unnest(coalesce(me.domains, '{}'::text[])) domain
        where char_length(btrim(domain)) >= 2
          and lower(concat_ws(' ', project.name, project.idea, project.summary, project.problem, project.goals))
            like '%' || lower(btrim(domain)) || '%'
        order by lower(domain)
        limit 2
      ) as matching_domains,
      array(
        select goal
        from unnest(coalesce(me.goals, '{}'::text[])) goal
        where char_length(btrim(goal)) >= 2
          and lower(concat_ws(' ', project.name, project.idea, project.summary, project.problem, project.goals))
            like '%' || lower(btrim(goal)) || '%'
        order by lower(goal)
        limit 1
      ) as matching_goals
    from public.cf_projects project
    join public.cf_profiles owner on owner.id = project.owner_id
    cross join me
    where project.owner_id <> auth.uid()
      and project.archived_at is null
      and (project.is_public or project.visibility = 'PUBLIC')
      and owner.is_discoverable
      and owner.onboarding_complete
      and not exists (
        select 1 from public.cf_blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = owner.id)
           or (b.blocker_id = owner.id and b.blocked_id = auth.uid())
      )
      and not exists (
        select 1 from public.cf_connections c
        where auth.uid() in (c.low_profile_id, c.high_profile_id)
          and owner.id in (c.low_profile_id, c.high_profile_id)
      )
      and not exists (
        select 1 from public.cf_meet_sessions s
        where auth.uid() in (s.participant_a_id, s.participant_b_id)
          and owner.id in (s.participant_a_id, s.participant_b_id)
      )
  ), ranked as (
    select
      eligible.*,
      array_remove(array[
        case when cardinality(matching_skills) > 0
          then 'Your ' || array_to_string(matching_skills, ' and ') || ' skills match this project''s public direction' end,
        case when cardinality(matching_domains) > 0
          then 'It is relevant to your ' || array_to_string(matching_domains, ' and ') || ' focus' end,
        case when cardinality(matching_goals) > 0
          then 'Its public goal aligns with ' || array_to_string(matching_goals, ' and ') end,
        case when collaboration_enabled then 'The owner is open to collaboration requests' end,
        case when stage in ('BUILDING', 'BETA', 'LIVE') then 'This is an active ' || lower(stage) || ' project' end
      ], null) as reasons,
      (cardinality(matching_skills) * 40)
        + (cardinality(matching_domains) * 24)
        + (cardinality(matching_goals) * 18)
        + case when collaboration_enabled then 8 else 0 end
        + case when stage in ('BUILDING', 'BETA', 'LIVE') then 5 else 0 end as relevance_score
    from eligible
  )
  select
    id, slug, name, summary, idea, stage, goals, collaboration_enabled,
    owner_id, candidate_username, candidate_full_name,
    case when cardinality(reasons) > 0 then reasons[1:3]
         else array['Its public project context is ready for a focused introduction']::text[] end,
    'discover-v3.1'::text
  from ranked
  order by relevance_score desc, updated_at desc, id
  offset greatest(0, result_offset)
  limit greatest(1, least(result_limit, 6));
$$;

revoke all on function public.cf_discover_builders_v3(integer, integer) from public;
revoke all on function public.cf_discover_projects_v3(integer, integer) from public;
grant execute on function public.cf_discover_builders_v3(integer, integer), public.cf_discover_projects_v3(integer, integer) to authenticated;
