package site.conflux.memory.domain;

import java.time.Instant;

/** Privacy-safe fact supplied to the memory system. */
public record RelationshipSignal(
    MemorySourceKind sourceKind,
    String summary,
    Instant occurredAt
) {}
