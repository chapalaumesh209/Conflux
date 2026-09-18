package site.conflux.shared.security;

import java.time.Duration;

/** Server policy; the Redis adapter will enforce these limits atomically. */
public record RateLimitWindow(String name, int maxRequests, Duration duration) {
    public RateLimitWindow {
        if (name == null || name.isBlank()) throw new IllegalArgumentException("Rate limit name is required");
        if (maxRequests < 1) throw new IllegalArgumentException("Rate limit must allow at least one request");
        if (duration == null || duration.isNegative() || duration.isZero()) {
            throw new IllegalArgumentException("Rate limit duration must be positive");
        }
    }
}
