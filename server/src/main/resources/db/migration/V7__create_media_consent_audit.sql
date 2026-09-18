CREATE TABLE media_requests (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES meet_sessions (id),
    requester_id UUID NOT NULL REFERENCES user_accounts (id),
    requested_mode VARCHAR(32) NOT NULL,
    request_status VARCHAR(32) NOT NULL,
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL,
    responded_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX media_requests_session_id_idx ON media_requests (session_id, request_status);
