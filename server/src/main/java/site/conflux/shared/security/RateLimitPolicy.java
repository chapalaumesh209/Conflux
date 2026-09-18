package site.conflux.shared.security;

import java.time.Duration;

public final class RateLimitPolicy {
    private RateLimitPolicy() {}

    public static RateLimitWindow loginAttempt() {
        return new RateLimitWindow("login-attempt", 8, Duration.ofMinutes(10));
    }

    public static RateLimitWindow matchJoin() {
        return new RateLimitWindow("match-join", 10, Duration.ofMinutes(1));
    }

    public static RateLimitWindow reportSubmission() {
        return new RateLimitWindow("report-submission", 5, Duration.ofHours(1));
    }

    public static String key(String policyName, String actorId) {
        return "conflux:rate-limit:" + policyName + ":" + actorId;
    }
}
