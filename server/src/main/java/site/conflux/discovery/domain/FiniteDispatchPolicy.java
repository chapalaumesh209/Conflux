package site.conflux.discovery.domain;

import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import java.util.stream.IntStream;
import site.conflux.profile.domain.ProfileVisibility;

/** Applies privacy and finite-product rules before the dispatch reaches a user. */
public final class FiniteDispatchPolicy {
    public static final int MAX_ITEMS = 6;

    private FiniteDispatchPolicy() {}

    public static List<DiscoveryItem> create(UUID viewerId, List<DiscoveryCandidate> candidates) {
        var eligible = candidates.stream()
            .filter(candidate -> !candidate.userId().equals(viewerId))
            .filter(candidate -> candidate.visibility() == ProfileVisibility.DISCOVERABLE)
            .filter(DiscoveryCandidate::matchEligible)
            .filter(candidate -> !candidate.blocked())
            .filter(candidate -> !candidate.recentlyShown())
            .sorted(Comparator.comparingInt(DiscoveryCandidate::relevanceRank).reversed())
            .limit(MAX_ITEMS)
            .toList();
        return IntStream.range(0, eligible.size())
            .mapToObj(index -> new DiscoveryItem(
                eligible.get(index).userId(),
                index + 1,
                eligible.get(index).explainableReason()
            ))
            .toList();
    }
}
