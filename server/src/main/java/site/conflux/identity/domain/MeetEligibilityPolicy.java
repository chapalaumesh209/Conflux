package site.conflux.identity.domain;

import java.util.Collection;
import java.util.EnumSet;
import java.util.Set;

/**
 * The policy is evaluated by the service, not the browser. It provides one
 * deterministic gate for queue entry even after a provider is revoked.
 */
public final class MeetEligibilityPolicy {
    private static final Set<IdentityProvider> REQUIRED = Set.of(
        IdentityProvider.EMAIL,
        IdentityProvider.GITHUB,
        IdentityProvider.LINKEDIN
    );

    private MeetEligibilityPolicy() {}

    public static MeetEligibility evaluate(Collection<VerificationSignal> signals) {
        Set<IdentityProvider> verified = EnumSet.noneOf(IdentityProvider.class);
        for (VerificationSignal signal : signals) {
            if (signal.status() == VerificationStatus.VERIFIED && signal.verifiedAt() != null) {
                verified.add(signal.provider());
            }
        }

        Set<IdentityProvider> missing = EnumSet.copyOf(REQUIRED);
        missing.removeAll(verified);
        return new MeetEligibility(missing.isEmpty(), Set.copyOf(missing));
    }
}
