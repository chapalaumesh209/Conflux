package site.conflux.identity.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Durable account identity. Provider credentials are intentionally absent. */
@Entity
@Table(name = "user_accounts")
public class UserAccount {
    @Id
    private UUID id;

    @Column(nullable = false, unique = true, length = 320)
    private String email;

    @Column(name = "account_status", nullable = false, length = 32)
    private String accountStatus;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected UserAccount() {}

    public UserAccount(UUID id, String email, Instant now) {
        this.id = id;
        this.email = email;
        this.accountStatus = "ACTIVE";
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID id() { return id; }
    public String email() { return email; }
}
