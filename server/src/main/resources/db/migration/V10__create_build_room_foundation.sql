CREATE TABLE build_rooms (
    id UUID PRIMARY KEY,
    connection_id UUID NOT NULL REFERENCES connections (id),
    created_by_user_id UUID NOT NULL REFERENCES user_accounts (id),
    room_name VARCHAR(160) NOT NULL,
    objective VARCHAR(500) NOT NULL,
    room_status VARCHAR(32) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE build_room_members (
    room_id UUID NOT NULL REFERENCES build_rooms (id),
    user_id UUID NOT NULL REFERENCES user_accounts (id),
    member_role VARCHAR(32) NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (room_id, user_id)
);

CREATE TABLE build_room_goals (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES build_rooms (id),
    created_by_user_id UUID NOT NULL REFERENCES user_accounts (id),
    goal_text VARCHAR(280) NOT NULL,
    goal_status VARCHAR(32) NOT NULL,
    due_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE build_room_notes (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES build_rooms (id),
    author_user_id UUID NOT NULL REFERENCES user_accounts (id),
    note_body VARCHAR(8000) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE build_room_activities (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES build_rooms (id),
    actor_user_id UUID REFERENCES user_accounts (id),
    activity_type VARCHAR(64) NOT NULL,
    activity_summary VARCHAR(280) NOT NULL,
    occurred_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX build_rooms_connection_idx ON build_rooms (connection_id, room_status);
CREATE INDEX build_room_goals_room_idx ON build_room_goals (room_id, goal_status);
CREATE INDEX build_room_notes_room_idx ON build_room_notes (room_id, created_at);
CREATE INDEX build_room_activities_room_idx ON build_room_activities (room_id, occurred_at);
