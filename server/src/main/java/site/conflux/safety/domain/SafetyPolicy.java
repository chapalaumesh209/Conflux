package site.conflux.safety.domain;

/** Safety actions protect the reporter first and always leave an audit trail. */
public final class SafetyPolicy {
    private SafetyPolicy() {}

    public static SafetyAction block() {
        return new SafetyAction(true, false, "USER_BLOCKED");
    }

    public static SafetyAction report(ReportReason reason) {
        if (reason == null) throw new IllegalArgumentException("A report reason is required");
        return new SafetyAction(true, false, "SAFETY_REPORT_SUBMITTED");
    }

    public static boolean canBeMatched(boolean blockedByEitherPerson, boolean underActiveModeration) {
        return !blockedByEitherPerson && !underActiveModeration;
    }
}
