package site.conflux.media.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import site.conflux.meet.domain.MeetSessionStatus;

class MediaRequestPolicyTests {
    private static final Instant NOW = Instant.parse("2026-09-18T00:00:00Z");

    @Test
    void activatesMediaOnlyWhenTheOtherPersonExplicitlyAcceptsAnActiveRequest() {
        var request = requestAt(NOW.plusSeconds(20));

        var status = MediaRequestPolicy.respond(request, MeetSessionStatus.ACTIVE, true, NOW);

        assertThat(status).isEqualTo(MediaRequestStatus.ACCEPTED);
        assertThat(MediaRequestPolicy.hasActiveMedia(status)).isTrue();
    }

    @Test
    void returnsToTextWhenARequestExpiresOrTheMeetEnds() {
        var request = requestAt(NOW.plusSeconds(20));

        var status = MediaRequestPolicy.respond(request, MeetSessionStatus.COMPLETED, true, NOW);

        assertThat(status).isEqualTo(MediaRequestStatus.EXPIRED);
        assertThat(MediaRequestPolicy.hasActiveMedia(status)).isFalse();
    }

    private MediaRequest requestAt(Instant expiresAt) {
        return new MediaRequest(
            UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(), MediaMode.VIDEO,
            MediaRequestStatus.PENDING, expiresAt
        );
    }
}
