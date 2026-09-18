package site.conflux.analytics.domain;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.UUID;

/** Deterministic assignment prevents a user seeing experiment variants flicker. */
public final class FeatureFlagPolicy {
    private FeatureFlagPolicy() {}

    public static boolean enabled(String flagKey, UUID userId, int rolloutPercentage) {
        if (rolloutPercentage < 0 || rolloutPercentage > 100) throw new IllegalArgumentException("Rollout must be 0-100");
        int bucket = Math.floorMod(Arrays.hashCode((flagKey + userId).getBytes(StandardCharsets.UTF_8)), 100);
        return bucket < rolloutPercentage;
    }
}
