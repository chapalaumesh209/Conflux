package site.conflux.analytics.domain;

import java.util.Set;

public final class ProductEventPolicy {
    private static final Set<String> FORBIDDEN_PAYLOAD_KEYS = Set.of(
        "message", "chat", "email", "phone", "accessToken", "refreshToken", "reportDetail"
    );

    private ProductEventPolicy() {}

    public static boolean accepts(ProductEvent event) {
        if (event == null || event.type() == null || blank(event.sourceSurface()) || event.payload() == null) return false;
        return event.payload().keySet().stream().noneMatch(FORBIDDEN_PAYLOAD_KEYS::contains);
    }

    private static boolean blank(String value) {
        return value == null || value.isBlank();
    }
}
