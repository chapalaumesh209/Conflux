package site.conflux.safety.domain;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SafetyPolicyTests {
    @Test
    void blockHidesThePersonWithoutNotifyingThem() {
        var action = SafetyPolicy.block();

        assertThat(action.hidesPersonImmediately()).isTrue();
        assertThat(action.notifySubject()).isFalse();
        assertThat(SafetyPolicy.canBeMatched(true, false)).isFalse();
    }

    @Test
    void reportCreatesPrivateAuditActionAndNeedsAReason() {
        var action = SafetyPolicy.report(ReportReason.SPAM_OR_SCAM);

        assertThat(action.auditEvent()).isEqualTo("SAFETY_REPORT_SUBMITTED");
        assertThat(action.notifySubject()).isFalse();
    }
}
