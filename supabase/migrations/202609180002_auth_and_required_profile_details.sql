-- Required identity and matching information collected after email OTP verification.
-- This is a separate additive migration so it can be applied after the foundation
-- migration, including on a project where the foundation was retried.

alter table public.cf_profiles add column if not exists interests text[] not null default '{}';
alter table public.cf_profiles add column if not exists date_of_birth date;
alter table public.cf_profiles add column if not exists gender text;
alter table public.cf_profile_contacts add column if not exists mobile_number text;

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
  requested_portfolio_url text default null,
  requested_mobile_number text default null
)
returns void language plpgsql security definer set search_path = public, auth as $$
declare actor uuid := auth.uid();
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

  insert into public.cf_profiles (id, username, full_name, headline, skills, interests, current_build, looking_for, date_of_birth, gender, email_verified, onboarding_complete, is_discoverable)
  values (actor, trim(requested_username), trim(requested_full_name), nullif(trim(requested_headline), ''), requested_skills, requested_interests, trim(requested_build), trim(requested_connections), requested_date_of_birth, requested_gender, true, true, true)
  on conflict (id) do update set
    username = excluded.username,
    full_name = excluded.full_name,
    headline = excluded.headline,
    skills = excluded.skills,
    interests = excluded.interests,
    current_build = excluded.current_build,
    looking_for = excluded.looking_for,
    date_of_birth = excluded.date_of_birth,
    gender = excluded.gender,
    email_verified = true,
    onboarding_complete = true,
    updated_at = now();

  insert into public.cf_profile_contacts (profile_id, linkedin_url, github_url, website_url, mobile_number, links_visible_to_connections)
  values (actor, trim(requested_linkedin_url), trim(requested_github_url), nullif(trim(requested_portfolio_url), ''), nullif(trim(requested_mobile_number), ''), true)
  on conflict (profile_id) do update set
    linkedin_url = excluded.linkedin_url,
    github_url = excluded.github_url,
    website_url = excluded.website_url,
    mobile_number = excluded.mobile_number,
    updated_at = now();
end;
$$;

revoke all on function public.cf_complete_onboarding(text, text, text, text[], text[], text, text, date, text, text, text, text, text) from public;
grant execute on function public.cf_complete_onboarding(text, text, text, text[], text[], text, text, date, text, text, text, text, text) to authenticated;
