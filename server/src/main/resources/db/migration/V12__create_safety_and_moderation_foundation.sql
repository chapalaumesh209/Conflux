CREATE TABLE user_blocks (
    id UUID PRIMARY KEY,
    blocker_user_id UUID NOT NULL REFERENCES user_accounts (id),
    blocked_user_id UUID NOT NULL REFERENCES user_accounts (id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT user_blocks_unique_pair UNIQUE (blocker_user_id, blocked_user_id),
    CONSTRAINT user_blocks_distinct_users CHECK (blocker_user_id <> blocked_user_id)
);

CREATE TABLE safety_reports (
    id UUID PRIMARY KEY,
    reporter_user_id UUID NOT NULL REFERENCES user_accounts (id),
    reported_user_id UUID NOT NULL REFERENCES user_accounts (id),
    meet_session_id UUID REFERENCES meet_sessions (id),
    report_reason VARCHAR(64) NOT NULL,
    report_detail VARCHAR(2000),
    report_status VARCHAR(32) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    resolved_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT safety_reports_distinct_users CHECK (reporter_user_id <> reported_user_id)
);

CREATE TABLE moderation_actions (
    id UUID PRIMARY KEY,
    subject_user_id UUID NOT NULL REFERENCES user_accounts (id),
    moderator_actor_id UUID REFERENCES user_accounts (id),
    action_type VARCHAR(64) NOT NULL,
    action_reason VARCHAR(500) NOT NULL,
    action_status VARCHAR(32) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX user_blocks_blocker_idx ON user_blocks (blocker_user_id, blocked_user_id);
CREATE INDEX safety_reports_status_idx ON safety_reports (report_status, created_at);
CREATE INDEX moderation_actions_subject_idx ON moderation_actions (subject_user_id, action_status);
