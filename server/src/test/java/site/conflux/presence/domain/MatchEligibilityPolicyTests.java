package site.conflux.presence.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import site.conflux.profile.domain.MeetMode;

class MatchEligibilityPolicyTests {
    private static final Instant NOW = Instant.parse("2026-09-18T00:00:00Z");

    @Test
    void acceptsOnlyAVerifiedAvailableAndFreshCandidate() {
        var requester = UUID.randomUUID();
        var candidate = new MatchCandidate(
            UUID.randomUUID(), true, AvailabilityState.AVAILABLE,
            NOW.plusSeconds(60), MeetMode.TEXT_FIRST, false, false
        );

        var result = MatchEligibilityPolicy.evaluate(requester, candidate, NOW);

        assertThat(result).isEqualTo(new MatchEligibility(true, "ELIGIBLE"));
    }

    @Test
    void excludesARecentOrBlockedCandidateBeforeRanking() {
        var candidate = new MatchCandidate(
            UUID.randomUUID(), true, AvailabilityState.AVAILABLE,
            NOW.plusSeconds(60), MeetMode.TEXT_FIRST, true, true
        );

        var result = MatchEligibilityPolicy.evaluate(UUID.randomUUID(), candidate, NOW);

        assertThat(result).isEqualTo(new MatchEligibility(false, "BLOCKED"));
    }
}
