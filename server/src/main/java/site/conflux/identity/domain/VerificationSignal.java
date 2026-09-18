package site.conflux.identity.domain;

import java.time.Instant;

/** A provider state safe to use in policy evaluation; it never contains tokens. */
public record VerificationSignal(
    IdentityProvider provider,
    VerificationStatus status,
    Instant verifiedAt
) {}
