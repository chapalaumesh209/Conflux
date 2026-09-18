package site.conflux.relationship.domain;

/** Deliberately nullable value for API responses that must redact a contact address. */
public record ExternalLinkProjection(String type, String value, boolean available) {}
