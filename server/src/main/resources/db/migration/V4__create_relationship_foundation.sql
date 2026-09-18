CREATE TABLE connections (
    id UUID PRIMARY KEY,
    participant_one_id UUID NOT NULL REFERENCES user_accounts (id),
    participant_two_id UUID NOT NULL REFERENCES user_accounts (id),
    connection_status VARCHAR(32) NOT NULL,
    connected_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT connections_unique_pair UNIQUE (participant_one_id, participant_two_id),
    CONSTRAINT connections_distinct_participants CHECK (participant_one_id <> participant_two_id)
);

CREATE TABLE conversations (
    id UUID PRIMARY KEY,
    connection_id UUID NOT NULL UNIQUE REFERENCES connections (id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE messages (
    id UUID PRIMARY KEY,
    conversation_id UUID NOT NULL REFERENCES conversations (id),
    sender_id UUID NOT NULL REFERENCES user_accounts (id),
    message_body VARCHAR(4000) NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX connections_participant_one_idx ON connections (participant_one_id, connection_status);
CREATE INDEX connections_participant_two_idx ON connections (participant_two_id, connection_status);
CREATE INDEX messages_conversation_sent_idx ON messages (conversation_id, sent_at);
