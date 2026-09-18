package site.conflux.identity.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

class MeetEligibilityPolicyTests {
    private static final Instant VERIFIED_AT = Instant.parse("2026-01-01T00:00:00Z");

    @Test
    void permitsMeetOnlyWhenEveryRequiredSignalIsCurrent() {
        var result = MeetEligibilityPolicy.evaluate(List.of(
            new VerificationSignal(IdentityProvider.EMAIL, VerificationStatus.VERIFIED, VERIFIED_AT),
            new VerificationSignal(IdentityProvider.GITHUB, VerificationStatus.VERIFIED, VERIFIED_AT),
            new VerificationSignal(IdentityProvider.LINKEDIN, VerificationStatus.VERIFIED, VERIFIED_AT)
        ));

        assertThat(result.eligible()).isTrue();
        assertThat(result.missingProviders()).isEmpty();
    }

    @Test
    void treatsRevokedOrTimestampFreeSignalsAsIneligible() {
        var result = MeetEligibilityPolicy.evaluate(List.of(
            new VerificationSignal(IdentityProvider.EMAIL, VerificationStatus.VERIFIED, VERIFIED_AT),
            new VerificationSignal(IdentityProvider.GITHUB, VerificationStatus.REVOKED, VERIFIED_AT),
            new VerificationSignal(IdentityProvider.LINKEDIN, VerificationStatus.VERIFIED, null)
        ));

        assertThat(result.eligible()).isFalse();
        assertThat(result.missingProviders()).containsExactlyInAnyOrder(
            IdentityProvider.GITHUB,
            IdentityProvider.LINKEDIN
        );
    }
}
