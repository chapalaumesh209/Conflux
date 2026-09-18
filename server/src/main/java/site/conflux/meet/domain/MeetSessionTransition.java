package site.conflux.meet.domain;

public record MeetSessionTransition(MeetSessionSnapshot session, boolean accepted, String reason) {}
