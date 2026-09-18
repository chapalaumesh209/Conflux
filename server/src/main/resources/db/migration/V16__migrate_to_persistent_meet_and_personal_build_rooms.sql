-- V2 Meet is persistent. These legacy fields stay nullable for audit compatibility only.
ALTER TABLE meet_sessions ALTER COLUMN expires_at DROP NOT NULL;
ALTER TABLE meet_sessions ALTER COLUMN duration_seconds DROP DEFAULT;
UPDATE meet_sessions SET duration_seconds = NULL, expires_at = NULL, scheduled_end_at = NULL
WHERE session_status IN ('MATCHED', 'ACTIVE');

-- A room belongs to its owner; it may optionally originate from a connection.
ALTER TABLE build_rooms ALTER COLUMN connection_id DROP NOT NULL;
ALTER TABLE build_rooms ADD COLUMN room_slug VARCHAR(120);
ALTER TABLE build_rooms ADD COLUMN project_summary VARCHAR(1000);
ALTER TABLE build_rooms ADD COLUMN project_vision VARCHAR(1000);
ALTER TABLE build_rooms ADD COLUMN project_stage VARCHAR(32) NOT NULL DEFAULT 'IDEA';
ALTER TABLE build_rooms ADD COLUMN visibility VARCHAR(32) NOT NULL DEFAULT 'PRIVATE';
ALTER TABLE build_rooms ADD COLUMN live_url VARCHAR(2048);
ALTER TABLE build_rooms ADD COLUMN repository_url VARCHAR(2048);
CREATE UNIQUE INDEX build_rooms_slug_unique_idx ON build_rooms (room_slug);

ALTER TABLE build_room_members ADD COLUMN member_status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE';
ALTER TABLE build_room_members ADD COLUMN permission_level VARCHAR(32) NOT NULL DEFAULT 'OWNER';
ALTER TABLE build_room_members ADD COLUMN responsibilities VARCHAR(1000);

CREATE TABLE build_room_join_requests (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES build_rooms (id),
    requester_id UUID NOT NULL REFERENCES user_accounts (id),
    request_status VARCHAR(32) NOT NULL,
    requested_role VARCHAR(160),
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL,
    responded_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT build_room_join_request_unique UNIQUE (room_id, requester_id, request_status)
);

CREATE TABLE build_room_milestones (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES build_rooms (id),
    milestone_name VARCHAR(280) NOT NULL,
    milestone_status VARCHAR(32) NOT NULL,
    due_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE build_room_tasks (
    id UUID PRIMARY KEY,
    room_id UUID NOT NULL REFERENCES build_rooms (id),
    milestone_id UUID REFERENCES build_room_milestones (id),
    assignee_id UUID REFERENCES user_accounts (id),
    created_by_user_id UUID NOT NULL REFERENCES user_accounts (id),
    task_title VARCHAR(280) NOT NULL,
    task_description VARCHAR(4000),
    task_status VARCHAR(32) NOT NULL,
    priority VARCHAR(32) NOT NULL DEFAULT 'MEDIUM',
    due_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX build_room_join_requests_room_idx ON build_room_join_requests (room_id, request_status);
CREATE INDEX build_room_milestones_room_idx ON build_room_milestones (room_id, milestone_status);
CREATE INDEX build_room_tasks_room_idx ON build_room_tasks (room_id, task_status);
