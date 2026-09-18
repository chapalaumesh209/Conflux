package site.conflux.billing.domain;

public record VerifiedWebhook(String providerEventId, String eventType, String payloadHash) {}
