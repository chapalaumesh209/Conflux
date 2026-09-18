package site.conflux.analytics.domain;

import java.util.Map;

/** Payloads carry IDs and coarse counts only; no raw chat or contact content. */
public record ProductEvent(
    ProductEventType type,
    String sourceSurface,
    Map<String, String> payload
) {}
