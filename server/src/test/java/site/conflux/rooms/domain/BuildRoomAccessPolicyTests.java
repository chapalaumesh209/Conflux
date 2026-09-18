package site.conflux.rooms.domain;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class BuildRoomAccessPolicyTests {

    @Test
    void letsEveryUserCreateOnePersonalRoom() {
        assertThat(BuildRoomAccessPolicy.canCreatePersonal(false))
            .isEqualTo(new BuildRoomAccess(true, "ALLOWED"));
        assertThat(BuildRoomAccessPolicy.canCreatePersonal(true)).isEqualTo(
            new BuildRoomAccess(false, "PERSONAL_ROOM_LIMIT_REACHED")
        );
    }

    @Test
    void requiresProOnlyForActiveCollaborationInAnotherRoom() {
        assertThat(BuildRoomAccessPolicy.canRequestToJoin(true, false, false)).isEqualTo(new BuildRoomAccess(true, "ALLOWED"));
        assertThat(BuildRoomAccessPolicy.canRequestToJoin(false, false, false)).isEqualTo(
            new BuildRoomAccess(false, "PREMIUM_ENTITLEMENT_REQUIRED")
        );
    }

    @Test
    void appliesScreenShareEntitlementToTheBroadcasterNotTheViewer() {
        assertThat(BuildRoomAccessPolicy.canStartScreenShare(true, true).allowed()).isTrue();
        assertThat(BuildRoomAccessPolicy.canStartScreenShare(false, true).reason()).isEqualTo("PREMIUM_ENTITLEMENT_REQUIRED");
    }
}
