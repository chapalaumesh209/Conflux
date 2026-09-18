package site.conflux.relationship.domain;

/** A value is retained internally but is never projected to a stranger. */
public record ExternalLink(String type, String value, boolean shareAfterConnection) {}
