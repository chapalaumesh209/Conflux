package site.conflux.relationship.domain;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class ExternalLinkVisibilityPolicyTests {
    @Test
    void redactsContactValuesBeforeTwoPeopleMutuallyConnect() {
        var projection = ExternalLinkVisibilityPolicy.project(
            new ExternalLink("GITHUB", "https://github.com/zoya/study-copilot", true), false
        );

        assertThat(projection.available()).isFalse();
        assertThat(projection.value()).isNull();
    }

    @Test
    void revealsOnlyLinksTheOwnerChoseToShareAfterConnection() {
        var shared = ExternalLinkVisibilityPolicy.project(new ExternalLink("GITHUB", "https://github.com/zoya", true), true);
        var privateLink = ExternalLinkVisibilityPolicy.project(new ExternalLink("EMAIL", "zoya@example.com", false), true);

        assertThat(shared.value()).isEqualTo("https://github.com/zoya");
        assertThat(privateLink.value()).isNull();
    }
}
