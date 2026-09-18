package site.conflux.profile.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Set;
import org.junit.jupiter.api.Test;

class ProfilePublicationPolicyTests {
    @Test
    void acceptsUpToFiveStructuredGoalsAndUserControlledLinks() {
        assertThat(ProfilePublicationPolicy.acceptsGoals(Set.of(
            new ProfileGoal(GoalCategory.BUILD, "Launch a focused developer tool"),
            new ProfileGoal(GoalCategory.COLLABORATE, "Find a frontend collaborator")
        ))).isTrue();
        assertThat(ProfilePublicationPolicy.acceptsExternalLink("https://github.com/conflux")).isTrue();
        assertThat(ProfilePublicationPolicy.acceptsExternalLink("javascript:alert(1)")).isFalse();
    }
}
