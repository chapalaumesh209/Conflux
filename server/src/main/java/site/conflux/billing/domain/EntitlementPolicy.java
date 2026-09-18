package site.conflux.billing.domain;

import java.util.EnumSet;
import java.util.Set;

/** Server-side policy. UI visibility is never treated as entitlement control. */
public final class EntitlementPolicy {
    private static final Set<FeatureCode> PRO_FEATURES = EnumSet.allOf(FeatureCode.class);

    private EntitlementPolicy() {}

    public static boolean allows(PlanCode plan, FeatureCode feature) {
        return plan == PlanCode.PRO && PRO_FEATURES.contains(feature);
    }

    public static Set<String> freeCoreCapabilities() {
        return Set.of(
            "MEET", "CONNECT", "CHAT", "REVISIT_CONNECTIONS", "SHARE_PROFESSIONAL_LINKS",
            "PERSONAL_BUILD_ROOM", "PROJECT_SHOWCASE", "VIEW_PUBLIC_BUILD_ROOMS"
        );
    }
}
