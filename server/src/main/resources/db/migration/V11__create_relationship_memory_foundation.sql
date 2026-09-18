CREATE TABLE relationship_events (
    id UUID PRIMARY KEY,
    connection_id UUID NOT NULL REFERENCES connections (id),
    actor_user_id UUID REFERENCES user_accounts (id),
    event_type VARCHAR(64) NOT NULL,
    event_summary VARCHAR(280) NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE relationship_memories (
    id UUID PRIMARY KEY,
    connection_id UUID NOT NULL REFERENCES connections (id),
    memory_summary VARCHAR(1000) NOT NULL,
    source_kind VARCHAR(64) NOT NULL,
    generated_by VARCHAR(64) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE assistant_suggestions (
    id UUID PRIMARY KEY,
    connection_id UUID REFERENCES connections (id),
    room_id UUID REFERENCES build_rooms (id),
    suggestion_type VARCHAR(64) NOT NULL,
    suggestion_text VARCHAR(500) NOT NULL,
    suggestion_status VARCHAR(32) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    actioned_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX relationship_events_connection_idx ON relationship_events (connection_id, occurred_at);
CREATE INDEX relationship_memories_connection_idx ON relationship_memories (connection_id, updated_at);
CREATE INDEX assistant_suggestions_connection_idx ON assistant_suggestions (connection_id, suggestion_status);
