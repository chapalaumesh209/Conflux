package site.conflux.discovery.domain;

import java.util.UUID;

/** The small, ordered result the browser is allowed to render. */
public record DiscoveryItem(UUID candidateUserId, int position, String matchReason) {}
