package site.conflux.rooms.domain;

/** V2 room policy: ownership is free; active work in another person's room is Pro-gated. */
public final class BuildRoomAccessPolicy {
    private BuildRoomAccessPolicy() {}

    public static BuildRoomAccess canCreatePersonal(boolean existingActiveRoom) {
        if (existingActiveRoom) return denied("PERSONAL_ROOM_LIMIT_REACHED");
        return new BuildRoomAccess(true, "ALLOWED");
    }

    public static BuildRoomAccess canRequestToJoin(boolean memberEntitled, boolean blocked, boolean existingOpenRequest) {
        if (!memberEntitled) return denied("PREMIUM_ENTITLEMENT_REQUIRED");
        if (blocked) return denied("COLLABORATION_SUSPENDED");
        if (existingOpenRequest) return denied("JOIN_REQUEST_ALREADY_OPEN");
        return new BuildRoomAccess(true, "ALLOWED");
    }

    public static BuildRoomAccess canStartScreenShare(boolean participantEntitled, boolean roomMember) {
        if (!roomMember) return denied("ROOM_MEMBERSHIP_REQUIRED");
        if (!participantEntitled) return denied("PREMIUM_ENTITLEMENT_REQUIRED");
        return new BuildRoomAccess(true, "ALLOWED");
    }

    private static BuildRoomAccess denied(String reason) {
        return new BuildRoomAccess(false, reason);
    }
}
