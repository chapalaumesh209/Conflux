package site.conflux.memory.domain;

import java.util.List;

/** Future AI adapters receive only validated, structured signals. */
public interface RelationshipMemoryProvider {
    String summarize(List<RelationshipSignal> signals);
}
