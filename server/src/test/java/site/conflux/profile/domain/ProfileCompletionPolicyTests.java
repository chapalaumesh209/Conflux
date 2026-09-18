package site.conflux.profile.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Set;
import org.junit.jupiter.api.Test;

class ProfileCompletionPolicyTests {

    @Test
    void acceptsTheMinimumStructuredProfileForMatching() {
        var completion = ProfileCompletionPolicy.evaluate(new ProfileDraft(
            "Dev Malhotra",
            "Frontend engineer",
            "A calmer way to meet collaborators",
            ProfileIntent.BUILD,
            MeetMode.TEXT_FIRST,
            Set.of("react", "nextjs")
        ));

        assertThat(completion.readyForMatching()).isTrue();
        assertThat(completion.missingFields()).isEmpty();
    }

    @Test
    void identifiesMissingStructuredSignalsWithoutRejectingOptionalBioFields() {
        var completion = ProfileCompletionPolicy.evaluate(new ProfileDraft(
            "",
            "Frontend engineer",
            "",
            null,
            null,
            Set.of()
        ));

        assertThat(completion.readyForMatching()).isFalse();
        assertThat(completion.missingFields()).containsExactlyInAnyOrder(
            "displayName", "currentFocus", "primaryIntent", "meetMode", "skills"
        );
    }
}
