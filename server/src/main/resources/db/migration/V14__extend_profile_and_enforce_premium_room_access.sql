ALTER TABLE developer_profiles ADD COLUMN username VARCHAR(40);
ALTER TABLE developer_profiles ADD COLUMN current_exploration VARCHAR(280);
ALTER TABLE developer_profiles ADD COLUMN timezone VARCHAR(80);
ALTER TABLE developer_profiles ADD COLUMN profile_state VARCHAR(32) NOT NULL DEFAULT 'ACTIVE';
CREATE UNIQUE INDEX developer_profiles_username_unique_idx ON developer_profiles (username);

ALTER TABLE profile_skills ADD COLUMN proficiency_level SMALLINT;

ALTER TABLE projects ADD COLUMN user_role VARCHAR(160);
ALTER TABLE projects ADD COLUMN repository_url VARCHAR(2048);
ALTER TABLE projects ADD COLUMN outcome VARCHAR(280);
ALTER TABLE projects ADD COLUMN started_on DATE;
ALTER TABLE projects ADD COLUMN ended_on DATE;
ALTER TABLE projects ADD COLUMN is_current BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE profile_domains (
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    domain_key VARCHAR(80) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (user_id, domain_key)
);

CREATE TABLE profile_goals (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    goal_category VARCHAR(32) NOT NULL,
    goal_detail VARCHAR(280),
    goal_state VARCHAR(32) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE profile_looking_for (
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    need_key VARCHAR(80) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (user_id, need_key)
);

CREATE TABLE profile_offers (
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    offer_key VARCHAR(80) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (user_id, offer_key)
);

CREATE TABLE profile_links (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    link_type VARCHAR(32) NOT NULL,
    link_url VARCHAR(2048) NOT NULL,
    visibility VARCHAR(32) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE profile_availability_preferences (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    day_of_week SMALLINT NOT NULL,
    start_time VARCHAR(5) NOT NULL,
    end_time VARCHAR(5) NOT NULL,
    visible_to_matches BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT profile_availability_day_range CHECK (day_of_week BETWEEN 1 AND 7)
);

CREATE INDEX profile_goals_user_idx ON profile_goals (user_id, goal_state);
CREATE INDEX profile_domains_domain_idx ON profile_domains (domain_key);
CREATE INDEX profile_links_user_idx ON profile_links (user_id);
CREATE INDEX projects_current_idx ON projects (user_id, is_current);
