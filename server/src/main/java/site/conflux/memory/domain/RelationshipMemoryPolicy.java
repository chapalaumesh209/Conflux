package site.conflux.memory.domain;

import java.util.List;

/** Limits memory inputs to explicit structured signals with bounded summaries. */
public final class RelationshipMemoryPolicy {
    public static final int MAX_SIGNALS = 12;
    public static final int MAX_SUMMARY_LENGTH = 280;

    private RelationshipMemoryPolicy() {}

    public static boolean accepts(List<RelationshipSignal> signals) {
        if (signals == null || signals.isEmpty() || signals.size() > MAX_SIGNALS) return false;
        return signals.stream().allMatch(signal ->
            signal.sourceKind() != null
                && signal.occurredAt() != null
                && signal.summary() != null
                && !signal.summary().isBlank()
                && signal.summary().length() <= MAX_SUMMARY_LENGTH
        );
    }
}
