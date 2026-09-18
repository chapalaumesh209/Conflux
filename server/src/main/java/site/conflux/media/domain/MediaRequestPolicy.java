package site.conflux.media.domain;

import java.time.Instant;
import site.conflux.meet.domain.MeetSessionStatus;

/** Both participants opt in; any expiry or decline falls back to text. */
public final class MediaRequestPolicy {
    private MediaRequestPolicy() {}

    public static MediaRequestStatus respond(
        MediaRequest request,
        MeetSessionStatus sessionStatus,
        boolean accepted,
        Instant now
    ) {
        if (request.status() != MediaRequestStatus.PENDING) return request.status();
        if (sessionStatus != MeetSessionStatus.ACTIVE || !now.isBefore(request.expiresAt())) {
            return MediaRequestStatus.EXPIRED;
        }
        return accepted ? MediaRequestStatus.ACCEPTED : MediaRequestStatus.DECLINED;
    }

    public static boolean hasActiveMedia(MediaRequestStatus status) {
        return status == MediaRequestStatus.ACCEPTED;
    }
}
