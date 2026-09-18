CREATE TABLE developer_profiles (
    user_id UUID PRIMARY KEY REFERENCES user_accounts (id),
    display_name VARCHAR(120) NOT NULL,
    headline VARCHAR(180) NOT NULL,
    region VARCHAR(120),
    bio VARCHAR(500),
    current_focus VARCHAR(280) NOT NULL,
    primary_intent VARCHAR(32) NOT NULL,
    meet_mode VARCHAR(32) NOT NULL,
    profile_visibility VARCHAR(32) NOT NULL,
    profile_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE skills (
    id UUID PRIMARY KEY,
    canonical_key VARCHAR(120) NOT NULL UNIQUE,
    display_name VARCHAR(120) NOT NULL,
    skill_version INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE profile_skills (
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    skill_id UUID NOT NULL REFERENCES skills (id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (user_id, skill_id)
);

CREATE TABLE projects (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    title VARCHAR(160) NOT NULL,
    summary VARCHAR(500) NOT NULL,
    project_stage VARCHAR(32) NOT NULL,
    external_url VARCHAR(2048),
    visibility VARCHAR(32) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX developer_profiles_intent_idx ON developer_profiles (primary_intent);
CREATE INDEX profile_skills_skill_id_idx ON profile_skills (skill_id);
CREATE INDEX projects_user_id_idx ON projects (user_id);
