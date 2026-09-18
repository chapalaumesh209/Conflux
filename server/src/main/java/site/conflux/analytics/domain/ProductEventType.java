package site.conflux.analytics.domain;

/** Explicit event vocabulary keeps beta analytics useful and privacy-bounded. */
public enum ProductEventType {
    PROFILE_COMPLETED,
    PROFILE_UPDATED,
    RECOMMENDATION_IMPRESSION,
    PROFILE_OPENED,
    MEET_STARTED,
    MEET_COMPLETED,
    CONNECT_CLICKED,
    NEXT_CLICKED,
    MUTUAL_MATCH,
    MESSAGE_SENT,
    BUILD_ROOM_CREATED,
    BUILD_ROOM_ACTIVE,
    SUBSCRIPTION_STARTED
}
