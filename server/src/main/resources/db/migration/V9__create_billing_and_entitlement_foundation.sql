CREATE TABLE subscriptions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    plan_code VARCHAR(32) NOT NULL,
    subscription_status VARCHAR(32) NOT NULL,
    provider_customer_ref VARCHAR(256),
    provider_subscription_ref VARCHAR(256),
    current_period_ends_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT subscriptions_provider_ref_unique UNIQUE (provider_subscription_ref)
);

CREATE TABLE feature_entitlements (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    feature_code VARCHAR(64) NOT NULL,
    entitlement_status VARCHAR(32) NOT NULL,
    source_subscription_id UUID REFERENCES subscriptions (id),
    valid_until TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT feature_entitlements_unique_feature UNIQUE (user_id, feature_code)
);

CREATE TABLE billing_webhook_events (
    id UUID PRIMARY KEY,
    provider_event_id VARCHAR(256) NOT NULL UNIQUE,
    provider_name VARCHAR(64) NOT NULL,
    event_type VARCHAR(128) NOT NULL,
    received_at TIMESTAMP WITH TIME ZONE NOT NULL,
    processed_at TIMESTAMP WITH TIME ZONE,
    processing_status VARCHAR(32) NOT NULL,
    payload_hash VARCHAR(128) NOT NULL
);

CREATE INDEX subscriptions_user_id_idx ON subscriptions (user_id, subscription_status);
CREATE INDEX feature_entitlements_user_idx ON feature_entitlements (user_id, entitlement_status);
