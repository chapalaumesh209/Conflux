-- Meet rotation keeps the entry surface intentional: a member can ask for a
-- different eligible introduction without seeing the same person again. The
-- ranked result shares the same hard eligibility checks as cf_open_meet.

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
    from public.cf_profiles
    where id = auth.uid()
  ), eligible as (
    select
      p.*,
      array(
        select item from unnest(coalesce(p.skills, '{}'::text[])) item
        where item = any(coalesce(me.skills, '{}'::text[]))
        order by lower(item)
      ) as shared_skills,
      array(
        select item from unnest(coalesce(p.interests, '{}'::text[])) item
        where item = any(coalesce(me.interests, '{}'::text[]))
        order by lower(item)
      ) as shared_interests,
      array(
        select item from unnest(coalesce(p.domains, '{}'::text[])) item
        where item = any(coalesce(me.domains, '{}'::text[]))
        order by lower(item)
      ) as shared_domains,
      array(
        select item from unnest(coalesce(p.goals, '{}'::text[])) item
        where item = any(coalesce(me.goals, '{}'::text[]))
        order by lower(item)
      ) as shared_goals
    from public.cf_profiles p
    cross join me
    where p.id <> auth.uid()
      and p.id <> all(coalesce(excluded_candidate_ids, '{}'::uuid[]))
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
        case when cardinality(shared_interests) > 0
          then 'You both care about ' || array_to_string(shared_interests[1:2], ' and ') end,
        case when cardinality(shared_domains) > 0
          then 'You both explore ' || array_to_string(shared_domains[1:2], ' and ') end,
        case when cardinality(shared_goals) > 0
          then 'You are both working toward ' || array_to_string(shared_goals[1:2], ' and ') end,
        case when looking_for is not null and (select current_build from me) is not null
          then 'Their collaboration goal may fit what you are building' end
      ], null) as reasons,
      (cardinality(shared_skills) * 40)
        + (cardinality(shared_interests) * 30)
        + (cardinality(shared_domains) * 22)
        + (cardinality(shared_goals) * 18)
        + case when looking_for is not null and (select current_build from me) is not null then 6 else 0 end as relevance_score
    from eligible
  )
  select
    id, username, full_name, headline, city, experience_band, skills, domains,
    goals, current_build, looking_for, avatar_url, email_verified,
    github_verified, linkedin_verified,
    coalesce(reasons[1], 'Their public builder context is ready for a focused introduction'),
    case when cardinality(reasons) > 0 then reasons[1:3]
         else array['Their public builder context is ready for a focused introduction']::text[] end
  from ranked
  order by relevance_score desc, updated_at desc, id
  limit 1;
$$;

revoke all on function public.cf_meet_candidate_preview(uuid[]) from public;
grant execute on function public.cf_meet_candidate_preview(uuid[]) to authenticated;
