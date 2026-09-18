package site.conflux.memory.domain;

/** Deterministic baseline before an optional model provider is introduced. */
public final class NextStepSuggestionPolicy {
    private NextStepSuggestionPolicy() {}

    public static NextStepSuggestion propose(boolean openGoal, boolean sharedProject, boolean recentMeet) {
        if (openGoal) return new NextStepSuggestion("GOAL", "Choose one owner and a realistic due date for the open goal.");
        if (sharedProject) return new NextStepSuggestion("REVIEW", "Share the smallest useful artifact and agree on a review time.");
        if (recentMeet) return new NextStepSuggestion("FOLLOW_UP", "Send a short follow-up while the conversation context is fresh.");
        return new NextStepSuggestion("CHECK_IN", "Reconnect with a concrete question or a useful update.");
    }
}
