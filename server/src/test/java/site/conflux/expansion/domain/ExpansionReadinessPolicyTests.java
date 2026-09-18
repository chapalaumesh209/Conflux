package site.conflux.expansion.domain;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class ExpansionReadinessPolicyTests {
    @Test
    void defersFutureModesUntilTheCoreProductHasEvidence() {
        var readiness = ExpansionReadinessPolicy.evaluate(new V1Evidence(true, true, false, false));

        assertThat(readiness.ready()).isFalse();
        assertThat(readiness.missingEvidence()).containsExactlyInAnyOrder("betaValidated", "userDemandConfirmed");
    }

    @Test
    void permitsPlanningOnlyWhenAllV1ProofIsPresent() {
        var readiness = ExpansionReadinessPolicy.evaluate(new V1Evidence(true, true, true, true));

        assertThat(readiness.ready()).isTrue();
    }
}
