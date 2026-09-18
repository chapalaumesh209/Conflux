package site.conflux.media.domain;

import java.time.Instant;
import java.util.UUID;

/** Consent projection. A request is not a media permission grant. */
public record MediaRequest(
    UUID requestId,
    UUID sessionId,
    UUID requesterId,
    MediaMode requestedMode,
    MediaRequestStatus status,
    Instant expiresAt
) {}
