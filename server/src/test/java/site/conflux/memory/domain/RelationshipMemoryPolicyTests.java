package site.conflux.memory.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

class RelationshipMemoryPolicyTests {
    @Test
    void acceptsOnlyBoundedStructuredSignals() {
        var signals = List.of(new RelationshipSignal(
            MemorySourceKind.BUILD_ROOM_GOAL,
            "Both agreed to share the first prototype this week.",
            Instant.parse("2026-09-18T00:00:00Z")
        ));

        assertThat(RelationshipMemoryPolicy.accepts(signals)).isTrue();
        assertThat(RelationshipMemoryPolicy.accepts(List.of(new RelationshipSignal(
            MemorySourceKind.BUILD_ROOM_NOTE, "", Instant.now()
        )))).isFalse();
    }

    @Test
    void favorsAGoalBasedNextStepBeforeAChasingReminder() {
        var suggestion = NextStepSuggestionPolicy.propose(true, true, true);

        assertThat(suggestion.type()).isEqualTo("GOAL");
    }
}
