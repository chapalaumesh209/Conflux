package site.conflux.meet.domain;

import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import site.conflux.relationship.domain.MeetDecision;

/** Enforces one final decision per participant for a completed session. */
public final class MeetDecisionLedger {
    private final Set<UUID> decisionMakers = new HashSet<>();

    public boolean record(UUID participantId, MeetDecision decision, MeetSessionStatus sessionStatus) {
        if (sessionStatus != MeetSessionStatus.COMPLETED) return false;
        if (decision == null) return false;
        return decisionMakers.add(participantId);
    }
}
