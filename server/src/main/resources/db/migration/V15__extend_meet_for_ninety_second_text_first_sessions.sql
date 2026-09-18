ALTER TABLE meet_sessions ADD COLUMN duration_seconds INTEGER NOT NULL DEFAULT 90;
ALTER TABLE meet_sessions ADD COLUMN scheduled_end_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE meet_sessions ADD COLUMN ended_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE meet_sessions ADD COLUMN end_reason VARCHAR(32);
ALTER TABLE meet_sessions ADD COLUMN ranking_version VARCHAR(64);
ALTER TABLE meet_sessions ADD COLUMN ranking_inputs TEXT;

UPDATE meet_sessions SET scheduled_end_at = expires_at WHERE scheduled_end_at IS NULL;

CREATE TABLE meet_messages (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES meet_sessions (id),
    sender_id UUID NOT NULL REFERENCES user_accounts (id),
    message_body VARCHAR(2000) NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX meet_messages_session_sent_idx ON meet_messages (session_id, sent_at);
