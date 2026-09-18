package site.conflux.meet.domain;

import java.time.Instant;
import java.util.UUID;

/** Server-authoritative lifecycle for a persistent V2 Meet conversation.
 * Infrastructure may close an inactive room separately; product state has no fixed timeout. */
public final class MeetSessionLifecycle {
    private MeetSessionLifecycle() {}

    public static MeetSessionSnapshot create(UUID sessionId, Instant now) {
        return new MeetSessionSnapshot(sessionId, MeetSessionStatus.MATCHED, null, null);
    }

    public static MeetSessionTransition start(MeetSessionSnapshot session, Instant now) {
        if (session.status() != MeetSessionStatus.MATCHED) return reject(session, "NOT_MATCHED");
        return accept(new MeetSessionSnapshot(session.sessionId(), MeetSessionStatus.ACTIVE, now, session.expiresAt()));
    }

    public static MeetSessionTransition complete(MeetSessionSnapshot session, Instant now) {
        if (session.status() != MeetSessionStatus.ACTIVE) return reject(session, "NOT_ACTIVE");
        return accept(new MeetSessionSnapshot(session.sessionId(), MeetSessionStatus.COMPLETED, session.startedAt(), session.expiresAt()));
    }

    private static MeetSessionTransition accept(MeetSessionSnapshot session) {
        return new MeetSessionTransition(session, true, "ACCEPTED");
    }

    private static MeetSessionTransition reject(MeetSessionSnapshot session, String reason) {
        return new MeetSessionTransition(session, false, reason);
    }
}
