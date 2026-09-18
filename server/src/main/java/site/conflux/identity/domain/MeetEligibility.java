package site.conflux.identity.domain;

import java.util.Set;

public record MeetEligibility(boolean eligible, Set<IdentityProvider> missingProviders) {}
