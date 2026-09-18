package site.conflux.meet.domain;

import java.time.Instant;
import java.util.UUID;

/** Server projection of a short conversation; expiry is never derived in the UI. */
public record MeetSessionSnapshot(
    UUID sessionId,
    MeetSessionStatus status,
    Instant startedAt,
    Instant expiresAt
) {}
