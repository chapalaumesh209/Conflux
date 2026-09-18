package site.conflux.analytics.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ProductEventPolicyTests {
    @Test
    void acceptsStructuredOutcomeSignalsButRejectsRawContent() {
        assertThat(ProductEventPolicy.accepts(new ProductEvent(
            ProductEventType.MEET_COMPLETED, "meet", Map.of("sessionId", "safe-id", "endReason", "participant_left")
        ))).isTrue();
        assertThat(ProductEventPolicy.accepts(new ProductEvent(
            ProductEventType.MESSAGE_SENT, "network", Map.of("message", "private text")
        ))).isFalse();
    }

    @Test
    void keepsFeatureAssignmentDeterministicAndBounded() {
        var user = UUID.randomUUID();

        assertThat(FeatureFlagPolicy.enabled("new-discovery", user, 0)).isFalse();
        assertThat(FeatureFlagPolicy.enabled("new-discovery", user, 100)).isTrue();
        assertThat(FeatureFlagPolicy.enabled("new-discovery", user, 50))
            .isEqualTo(FeatureFlagPolicy.enabled("new-discovery", user, 50));
    }
}
