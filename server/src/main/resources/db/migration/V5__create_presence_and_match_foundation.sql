CREATE TABLE availability_windows (
    user_id UUID PRIMARY KEY REFERENCES user_accounts (id),
    meet_mode VARCHAR(32) NOT NULL,
    available_since TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE meet_sessions (
    id UUID PRIMARY KEY,
    participant_one_id UUID NOT NULL REFERENCES user_accounts (id),
    participant_two_id UUID NOT NULL REFERENCES user_accounts (id),
    session_status VARCHAR(32) NOT NULL,
    requested_mode VARCHAR(32) NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT meet_sessions_distinct_participants CHECK (participant_one_id <> participant_two_id)
);

CREATE TABLE match_exclusions (
    id UUID PRIMARY KEY,
    source_user_id UUID NOT NULL REFERENCES user_accounts (id),
    excluded_user_id UUID NOT NULL REFERENCES user_accounts (id),
    exclusion_reason VARCHAR(32) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT match_exclusions_distinct_users CHECK (source_user_id <> excluded_user_id)
);

CREATE INDEX availability_windows_expires_at_idx ON availability_windows (expires_at);
CREATE INDEX meet_sessions_participant_one_idx ON meet_sessions (participant_one_id, session_status);
CREATE INDEX meet_sessions_participant_two_idx ON meet_sessions (participant_two_id, session_status);
CREATE INDEX match_exclusions_source_target_idx ON match_exclusions (source_user_id, excluded_user_id);
