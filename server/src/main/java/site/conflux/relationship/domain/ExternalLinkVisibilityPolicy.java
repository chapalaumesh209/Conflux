package site.conflux.relationship.domain;

/** Enforces the connection boundary on the server, before a profile response is serialized. */
public final class ExternalLinkVisibilityPolicy {
    private ExternalLinkVisibilityPolicy() {}

    public static ExternalLinkProjection project(ExternalLink link, boolean isMutualConnection) {
        boolean available = isMutualConnection && link.shareAfterConnection();
        return new ExternalLinkProjection(link.type(), available ? link.value() : null, available);
    }
}
