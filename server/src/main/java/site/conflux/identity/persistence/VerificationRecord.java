package site.conflux.identity.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import site.conflux.identity.domain.IdentityProvider;
import site.conflux.identity.domain.VerificationSignal;
import site.conflux.identity.domain.VerificationStatus;

@Entity
@Table(name = "verification_records")
public class VerificationRecord {
    @Id
    private UUID id;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private UserAccount user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private IdentityProvider provider;

    @Enumerated(EnumType.STRING)
    @Column(name = "verification_status", nullable = false, length = 32)
    private VerificationStatus verificationStatus;

    @Column(name = "provider_subject", length = 512)
    private String providerSubject;

    @Column(name = "verified_at")
    private Instant verifiedAt;

    @Column(name = "revoked_at")
    private Instant revokedAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected VerificationRecord() {}

    public VerificationSignal signal() {
        return new VerificationSignal(provider, verificationStatus, verifiedAt);
    }
}
