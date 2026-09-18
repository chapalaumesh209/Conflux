package site.conflux.profile.persistence;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import site.conflux.identity.persistence.UserAccount;
import site.conflux.profile.domain.MeetMode;
import site.conflux.profile.domain.ProfileIntent;
import site.conflux.profile.domain.ProfileVisibility;

/** Canonical profile record. Search documents are derived from this source later. */
@Entity
@Table(name = "developer_profiles")
public class DeveloperProfile {
    @Id
    @Column(name = "user_id")
    private UUID userId;

    @OneToOne(optional = false)
    @JoinColumn(name = "user_id", insertable = false, updatable = false)
    private UserAccount user;

    @Column(name = "display_name", nullable = false, length = 120)
    private String displayName;

    @Column(nullable = false, length = 180)
    private String headline;

    @Column(name = "current_focus", nullable = false, length = 280)
    private String currentFocus;

    @Enumerated(EnumType.STRING)
    @Column(name = "primary_intent", nullable = false, length = 32)
    private ProfileIntent primaryIntent;

    @Enumerated(EnumType.STRING)
    @Column(name = "meet_mode", nullable = false, length = 32)
    private MeetMode meetMode;

    @Enumerated(EnumType.STRING)
    @Column(name = "profile_visibility", nullable = false, length = 32)
    private ProfileVisibility profileVisibility;

    @Column(name = "profile_version", nullable = false)
    private int profileVersion;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected DeveloperProfile() {}
}
