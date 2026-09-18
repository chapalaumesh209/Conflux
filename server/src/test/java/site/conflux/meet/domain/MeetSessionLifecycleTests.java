package site.conflux.meet.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import site.conflux.relationship.domain.MeetDecision;

class MeetSessionLifecycleTests {
    private static final Instant NOW = Instant.parse("2026-09-18T00:00:00Z");

    @Test
    void serverStartsAndCompletesAPersistentSessionWithoutAProductDeadline() {
        var session = MeetSessionLifecycle.create(UUID.randomUUID(), NOW);
        var started = MeetSessionLifecycle.start(session, NOW.plusSeconds(2));
        var completed = MeetSessionLifecycle.complete(started.session(), NOW.plusSeconds(60 * 60));

        assertThat(started.accepted()).isTrue();
        assertThat(completed.accepted()).isTrue();
        assertThat(completed.session().status()).isEqualTo(MeetSessionStatus.COMPLETED);
    }

    @Test
    void aValidSessionDoesNotExpireBecauseOfAProductTimer() {
        var session = MeetSessionLifecycle.create(UUID.randomUUID(), NOW);
        var started = MeetSessionLifecycle.start(session, NOW.plusSeconds(90));

        assertThat(started.accepted()).isTrue();
        assertThat(started.session().expiresAt()).isNull();
    }

    @Test
    void acceptsOnlyOneDecisionPerParticipantAfterCompletion() {
        var ledger = new MeetDecisionLedger();
        var participant = UUID.randomUUID();

        assertThat(ledger.record(participant, MeetDecision.CONNECT, MeetSessionStatus.COMPLETED)).isTrue();
        assertThat(ledger.record(participant, MeetDecision.NEXT, MeetSessionStatus.COMPLETED)).isFalse();
        assertThat(ledger.record(UUID.randomUUID(), MeetDecision.CONNECT, MeetSessionStatus.ACTIVE)).isFalse();
    }
}
