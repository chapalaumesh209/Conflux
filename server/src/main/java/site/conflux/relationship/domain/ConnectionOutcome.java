package site.conflux.relationship.domain;

public record ConnectionOutcome(ConnectionStatus status, boolean conversationCreated) {}
