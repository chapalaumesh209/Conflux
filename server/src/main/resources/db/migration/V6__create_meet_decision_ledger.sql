CREATE TABLE meet_decisions (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES meet_sessions (id),
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    decision VARCHAR(32) NOT NULL,
    decided_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT meet_decisions_unique_actor UNIQUE (session_id, user_id)
);

CREATE INDEX meet_decisions_session_id_idx ON meet_decisions (session_id);
