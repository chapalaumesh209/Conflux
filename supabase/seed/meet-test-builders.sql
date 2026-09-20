-- CONFLUX local/production test fixture
--
-- Creates 20 clearly-labelled test identities, completed discoverable profiles,
-- contact records, and 12 public test projects. It is idempotent and never
-- deletes, updates, or reads non-test identities. Do not use these identities
-- as production members.
--
-- Test sign-in: test-builder-01@conflux.test through test-builder-20@conflux.test
-- Test password: ConfluxTest!2026

create extension if not exists pgcrypto;

do $$
declare
  item integer;
  account_id uuid;
  account_email text;
  account_username text;
  account_name text;
  tenant_id uuid;
  builder_skills text[];
  builder_domains text[];
  builder_goals text[];
begin
  select instance_id into tenant_id
  from auth.users
  where instance_id is not null
  limit 1;

  for item in 1..20 loop
    account_email := format('test-builder-%s@conflux.test', lpad(item::text, 2, '0'));
    account_username := format('test_builder_%s', lpad(item::text, 2, '0'));
    account_name := format('Test Builder %s', lpad(item::text, 2, '0'));

    case item % 5
      when 0 then
        builder_skills := array['TypeScript', 'React', 'AI', 'Product design'];
        builder_domains := array['AI products', 'Creator tools'];
        builder_goals := array['Build useful AI tools', 'Find a frontend collaborator'];
      when 1 then
        builder_skills := array['Python', 'PostgreSQL', 'AI', 'FastAPI'];
        builder_domains := array['Developer tools', 'Applied AI'];
        builder_goals := array['Ship an AI product', 'Find a product collaborator'];
      when 2 then
        builder_skills := array['React', 'TypeScript', 'Accessibility', 'Design systems'];
        builder_domains := array['Product design', 'Web platforms'];
        builder_goals := array['Build a better workflow', 'Find a backend collaborator'];
      when 3 then
        builder_skills := array['Node.js', 'PostgreSQL', 'APIs', 'Docker'];
        builder_domains := array['SaaS', 'Developer tools'];
        builder_goals := array['Build useful AI tools', 'Find a design collaborator'];
      else
        builder_skills := array['Figma', 'Research', 'Product strategy', 'AI'];
        builder_domains := array['Creator tools', 'Product design'];
        builder_goals := array['Ship an AI product', 'Find an engineering collaborator'];
    end case;

    select id into account_id from auth.users where email = account_email;
    if account_id is null then
      account_id := gen_random_uuid();
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at
      ) values (
        tenant_id, account_id, 'authenticated', 'authenticated', account_email,
        crypt('ConfluxTest!2026', gen_salt('bf')), now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('name', account_name, 'conflux_test_account', true), now(), now()
      );
    else
      update auth.users
      set encrypted_password = crypt('ConfluxTest!2026', gen_salt('bf')),
          email_confirmed_at = coalesce(email_confirmed_at, now()),
          raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('conflux_test_account', true),
          updated_at = now()
      where id = account_id;
    end if;

    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), account_id,
      jsonb_build_object('sub', account_id::text, 'email', account_email, 'email_verified', true),
      'email', account_email, now(), now(), now()
    ) on conflict (provider_id, provider) do update
      set user_id = excluded.user_id,
          identity_data = excluded.identity_data,
          updated_at = now();

    insert into public.cf_profiles (
      id, username, full_name, headline, bio, city, experience_band,
      skills, domains, goals, interests, current_build, looking_for, can_offer,
      is_discoverable, onboarding_complete, email_verified, github_verified, linkedin_verified
    ) values (
      account_id, account_username, account_name, 'CONFLUX test builder',
      'Synthetic account for exercising the CONFLUX Meet and discovery flows.',
      case item % 4 when 0 then 'Bengaluru' when 1 then 'Hyderabad' when 2 then 'Mumbai' else 'Pune' end,
      case item % 4 when 0 then 'FOUNDER' when 1 then 'MID' when 2 then 'EARLY' else 'STUDENT' end,
      builder_skills, builder_domains, builder_goals, builder_domains,
      format('Test project %s: a focused collaboration exercise for the Meet flow.', lpad(item::text, 2, '0')),
      builder_goals[2], 'Thoughtful collaboration and clear technical context.',
      true, true, true, false, false
    ) on conflict (id) do update set
      username = excluded.username,
      full_name = excluded.full_name,
      headline = excluded.headline,
      bio = excluded.bio,
      city = excluded.city,
      experience_band = excluded.experience_band,
      skills = excluded.skills,
      domains = excluded.domains,
      goals = excluded.goals,
      interests = excluded.interests,
      current_build = excluded.current_build,
      looking_for = excluded.looking_for,
      can_offer = excluded.can_offer,
      is_discoverable = true,
      onboarding_complete = true,
      email_verified = true,
      github_verified = false,
      linkedin_verified = false,
      updated_at = now();

    insert into public.cf_profile_contacts (
      profile_id, github_url, linkedin_url, website_url, links_visible_to_connections
    ) values (
      account_id,
      format('https://github.com/conflux-test-%s', lpad(item::text, 2, '0')),
      format('https://www.linkedin.com/in/conflux-test-%s', lpad(item::text, 2, '0')),
      format('https://test-%s.conflux.local', lpad(item::text, 2, '0')),
      true
    ) on conflict (profile_id) do update set
      github_url = excluded.github_url,
      linkedin_url = excluded.linkedin_url,
      website_url = excluded.website_url,
      links_visible_to_connections = true,
      updated_at = now();

    if item <= 12 then
      insert into public.cf_projects (
        owner_id, slug, name, idea, summary, problem, goals, stage,
        is_public, visibility, collaboration_enabled
      ) values (
        account_id,
        format('test-project-%s', lpad(item::text, 2, '0')),
        format('Test Project %s', lpad(item::text, 2, '0')),
        format('A CONFLUX test project that needs %s collaboration.', lower(builder_skills[1])),
        format('Public test build %s. This exists only to exercise the Discover-to-Build Room flow.', lpad(item::text, 2, '0')),
        'A controlled test project for validating introductions, project relevance, and room access.',
        format('Looking for %s support and a thoughtful collaborator.', lower(builder_skills[1])),
        case item % 4 when 0 then 'LIVE' when 1 then 'BUILDING' when 2 then 'BETA' else 'PLANNING' end,
        true, 'PUBLIC', true
      ) on conflict (slug) do update set
        owner_id = excluded.owner_id,
        name = excluded.name,
        idea = excluded.idea,
        summary = excluded.summary,
        problem = excluded.problem,
        goals = excluded.goals,
        stage = excluded.stage,
        is_public = true,
        visibility = 'PUBLIC',
        collaboration_enabled = true,
        updated_at = now();
    end if;
  end loop;
end;
$$;

-- Expected validation: 20 completed test profiles and 12 public test projects.
select
  (select count(*) from auth.users where email like 'test-builder-%@conflux.test') as test_users,
  (select count(*) from public.cf_profiles where username like 'test_builder_%') as test_profiles,
  (select count(*) from public.cf_projects where slug like 'test-project-%') as test_projects;
