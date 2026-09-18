package site.conflux.presence.domain;

import java.util.UUID;

/** Redis keys are namespaced and avoid leaking email or provider identifiers. */
public final class PresenceKey {
    private PresenceKey() {}

    public static String availability(UUID userId) {
        return "conflux:presence:availability:" + userId;
    }

    public static String queue(String intent) {
        return "conflux:match:queue:" + intent.toLowerCase();
    }
}
