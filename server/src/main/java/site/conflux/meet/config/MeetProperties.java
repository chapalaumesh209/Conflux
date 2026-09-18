package site.conflux.meet.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Infrastructure timing only. No value here is exposed as a product conversation countdown. */
@ConfigurationProperties(prefix = "conflux.meet")
public record MeetProperties(int reconnectWindowSeconds, int inactiveRoomTimeoutMinutes) {
    public MeetProperties {
        reconnectWindowSeconds = reconnectWindowSeconds > 0 ? reconnectWindowSeconds : 120;
        inactiveRoomTimeoutMinutes = inactiveRoomTimeoutMinutes > 0 ? inactiveRoomTimeoutMinutes : 30;
    }
}
