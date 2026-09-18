package site.conflux.presence.domain;

import java.time.Instant;
import java.util.UUID;

/** Hard gates run before compatibility scoring or any candidate ranking. */
public final class MatchEligibilityPolicy {
    private MatchEligibilityPolicy() {}

    public static MatchEligibility evaluate(UUID requesterId, MatchCandidate candidate, Instant now) {
        if (requesterId.equals(candidate.userId())) return reject("SELF");
        if (!candidate.meetEligible()) return reject("UNVERIFIED");
        if (candidate.availability() != AvailabilityState.AVAILABLE) return reject("UNAVAILABLE");
        if (!candidate.availabilityExpiresAt().isAfter(now)) return reject("AVAILABILITY_EXPIRED");
        if (candidate.blocked()) return reject("BLOCKED");
        if (candidate.recentMatch()) return reject("RECENT_MATCH");
        return new MatchEligibility(true, "ELIGIBLE");
    }

    private static MatchEligibility reject(String reason) {
        return new MatchEligibility(false, reason);
    }
}
