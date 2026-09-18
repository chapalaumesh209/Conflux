CREATE TABLE user_accounts (
    id UUID PRIMARY KEY,
    email VARCHAR(320) NOT NULL UNIQUE,
    account_status VARCHAR(32) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE verification_records (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    provider VARCHAR(32) NOT NULL,
    verification_status VARCHAR(32) NOT NULL,
    provider_subject VARCHAR(512),
    verified_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT verification_records_user_provider_key UNIQUE (user_id, provider)
);

CREATE INDEX verification_records_user_id_idx ON verification_records (user_id);
CREATE INDEX verification_records_provider_subject_idx ON verification_records (provider, provider_subject);

CREATE TABLE consent_records (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    consent_type VARCHAR(64) NOT NULL,
    policy_version VARCHAR(64) NOT NULL,
    granted_at TIMESTAMP WITH TIME ZONE NOT NULL,
    withdrawn_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX consent_records_user_id_idx ON consent_records (user_id);
