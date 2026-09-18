CREATE TABLE discovery_dispatches (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    dispatched_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    dispatch_status VARCHAR(32) NOT NULL
);

CREATE TABLE discovery_items (
    id UUID PRIMARY KEY,
    dispatch_id UUID NOT NULL REFERENCES discovery_dispatches (id),
    candidate_user_id UUID NOT NULL REFERENCES user_accounts (id),
    position INTEGER NOT NULL,
    match_reason VARCHAR(280) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT discovery_items_unique_candidate UNIQUE (dispatch_id, candidate_user_id),
    CONSTRAINT discovery_items_unique_position UNIQUE (dispatch_id, position)
);

CREATE TABLE recommendation_impressions (
    id UUID PRIMARY KEY,
    dispatch_id UUID NOT NULL REFERENCES discovery_dispatches (id),
    candidate_user_id UUID NOT NULL REFERENCES user_accounts (id),
    position INTEGER NOT NULL,
    shown_at TIMESTAMP WITH TIME ZONE NOT NULL,
    opened_at TIMESTAMP WITH TIME ZONE,
    dismissed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX discovery_dispatches_user_idx ON discovery_dispatches (user_id, expires_at);
CREATE INDEX recommendation_impressions_dispatch_idx ON recommendation_impressions (dispatch_id, position);
