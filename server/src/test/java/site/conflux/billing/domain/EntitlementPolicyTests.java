package site.conflux.billing.domain;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class EntitlementPolicyTests {

    @Test
    void freeKeepsTheCoreNetworkingLoopWithoutProFeatures() {
        assertThat(EntitlementPolicy.freeCoreCapabilities()).contains(
            "MEET", "CONNECT", "CHAT", "REVISIT_CONNECTIONS", "SHARE_PROFESSIONAL_LINKS",
            "PERSONAL_BUILD_ROOM", "PROJECT_SHOWCASE", "VIEW_PUBLIC_BUILD_ROOMS"
        );
        assertThat(EntitlementPolicy.allows(PlanCode.FREE, FeatureCode.ADVANCED_DISCOVERY)).isFalse();
    }

    @Test
    void proEnablesIntentionalAccessAndDeeperCollaboration() {
        assertThat(EntitlementPolicy.allows(PlanCode.PRO, FeatureCode.ADVANCED_DISCOVERY)).isTrue();
        assertThat(EntitlementPolicy.allows(PlanCode.PRO, FeatureCode.ROOM_COLLABORATION)).isTrue();
    }
}
