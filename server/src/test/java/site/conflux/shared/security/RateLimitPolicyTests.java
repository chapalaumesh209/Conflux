package site.conflux.shared.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import org.junit.jupiter.api.Test;

class RateLimitPolicyTests {
    @Test
    void definesBoundedWindowsForSensitiveActions() {
        assertThat(RateLimitPolicy.loginAttempt()).isEqualTo(
            new RateLimitWindow("login-attempt", 8, Duration.ofMinutes(10))
        );
        assertThat(RateLimitPolicy.reportSubmission().maxRequests()).isEqualTo(5);
        assertThat(RateLimitPolicy.key("match-join", "user-123"))
            .isEqualTo("conflux:rate-limit:match-join:user-123");
    }
}
