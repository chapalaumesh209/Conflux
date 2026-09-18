CREATE TABLE product_events (
    id UUID PRIMARY KEY,
    actor_user_id UUID REFERENCES user_accounts (id),
    event_type VARCHAR(96) NOT NULL,
    source_surface VARCHAR(64) NOT NULL,
    trace_id VARCHAR(100) NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL,
    payload_json TEXT NOT NULL
);

CREATE TABLE feature_flags (
    id UUID PRIMARY KEY,
    flag_key VARCHAR(120) NOT NULL UNIQUE,
    flag_status VARCHAR(32) NOT NULL,
    rollout_percentage INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT feature_flags_percentage_range CHECK (rollout_percentage BETWEEN 0 AND 100)
);

CREATE TABLE experiment_assignments (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    experiment_key VARCHAR(120) NOT NULL,
    variant_key VARCHAR(120) NOT NULL,
    assigned_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT experiment_assignments_unique_user_experiment UNIQUE (user_id, experiment_key)
);

CREATE INDEX product_events_type_occurred_idx ON product_events (event_type, occurred_at);
CREATE INDEX product_events_actor_occurred_idx ON product_events (actor_user_id, occurred_at);
CREATE INDEX experiment_assignments_experiment_idx ON experiment_assignments (experiment_key, variant_key);
