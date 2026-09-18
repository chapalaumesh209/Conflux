package site.conflux.discovery.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import site.conflux.profile.domain.ProfileVisibility;

class FiniteDispatchPolicyTests {

    @Test
    void returnsAtMostSixEligibleDiscoverableAndFreshPeopleInRankOrder() {
        var viewer = UUID.randomUUID();
        var candidates = new ArrayList<DiscoveryCandidate>();
        candidates.add(candidate(viewer, 99, ProfileVisibility.DISCOVERABLE, true, false, false));
        candidates.add(candidate(UUID.randomUUID(), 98, ProfileVisibility.NETWORK, true, false, false));
        candidates.add(candidate(UUID.randomUUID(), 97, ProfileVisibility.DISCOVERABLE, true, true, false));
        for (int rank = 1; rank <= 7; rank++) {
            candidates.add(candidate(UUID.randomUUID(), rank, ProfileVisibility.DISCOVERABLE, true, false, false));
        }

        var dispatch = FiniteDispatchPolicy.create(viewer, candidates);

        assertThat(dispatch).hasSize(6);
        assertThat(dispatch).extracting(DiscoveryItem::position).containsExactly(1, 2, 3, 4, 5, 6);
        assertThat(dispatch).extracting(DiscoveryItem::matchReason).containsExactly(
            "Reason 7", "Reason 6", "Reason 5", "Reason 4", "Reason 3", "Reason 2"
        );
    }

    private DiscoveryCandidate candidate(
        UUID id, int rank, ProfileVisibility visibility, boolean eligible, boolean blocked, boolean shown
    ) {
        return new DiscoveryCandidate(id, visibility, eligible, blocked, shown, rank, "Reason " + rank);
    }
}
