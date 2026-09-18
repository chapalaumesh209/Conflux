package site.conflux.relationship.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import site.conflux.relationship.domain.ConnectionStatus;

/** Canonical mutual relationship. Ordering is normalized by the service layer. */
@Entity
@Table(name = "connections")
public class Connection {
    @Id
    private UUID id;

    @Column(name = "participant_one_id", nullable = false)
    private UUID participantOneId;

    @Column(name = "participant_two_id", nullable = false)
    private UUID participantTwoId;

    @Enumerated(EnumType.STRING)
    @Column(name = "connection_status", nullable = false, length = 32)
    private ConnectionStatus connectionStatus;

    @Column(name = "connected_at")
    private Instant connectedAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Connection() {}
}
