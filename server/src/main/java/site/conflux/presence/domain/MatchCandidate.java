package site.conflux.presence.domain;

import java.time.Instant;
import java.util.UUID;
import site.conflux.profile.domain.MeetMode;

/** Read model assembled by the matching service, never posted by the browser. */
public record MatchCandidate(
    UUID userId,
    boolean meetEligible,
    AvailabilityState availability,
    Instant availabilityExpiresAt,
    MeetMode preferredMode,
    boolean blocked,
    boolean recentMatch
) {}
