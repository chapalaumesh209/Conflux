package site.conflux.safety.domain;

public record SafetyAction(boolean hidesPersonImmediately, boolean notifySubject, String auditEvent) {}
