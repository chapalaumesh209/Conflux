CREATE TABLE audit_events (
    id UUID PRIMARY KEY,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
    trace_id VARCHAR(100) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    actor_id UUID,
    payload TEXT NOT NULL
);

CREATE INDEX audit_events_trace_id_idx ON audit_events (trace_id);
CREATE INDEX audit_events_occurred_at_idx ON audit_events (occurred_at);
