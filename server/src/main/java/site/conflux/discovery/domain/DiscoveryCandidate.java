package site.conflux.discovery.domain;

import java.util.UUID;
import site.conflux.profile.domain.ProfileVisibility;

/** Ranking input after profile visibility and safety data have been joined. */
public record DiscoveryCandidate(
    UUID userId,
    ProfileVisibility visibility,
    boolean matchEligible,
    boolean blocked,
    boolean recentlyShown,
    int relevanceRank,
    String explainableReason
) {}
