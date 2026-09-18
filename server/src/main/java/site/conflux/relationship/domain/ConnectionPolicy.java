package site.conflux.relationship.domain;

/** A relationship exists only when both people independently choose Connect. */
public final class ConnectionPolicy {
    private ConnectionPolicy() {}

    public static ConnectionOutcome resolve(MeetDecision first, MeetDecision second) {
        if (first == MeetDecision.CONNECT && second == MeetDecision.CONNECT) {
            return new ConnectionOutcome(ConnectionStatus.CONNECTED, true);
        }
        if (first == MeetDecision.NEXT || second == MeetDecision.NEXT) {
            return new ConnectionOutcome(ConnectionStatus.DECLINED, false);
        }
        return new ConnectionOutcome(ConnectionStatus.PENDING, false);
    }
}
