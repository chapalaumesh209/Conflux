package site.conflux.memory.domain;

/** Sources are deliberately structured; raw chat is not an implicit source. */
public enum MemorySourceKind {
    MEET_METADATA,
    CONNECTION_EVENT,
    BUILD_ROOM_GOAL,
    BUILD_ROOM_NOTE
}
