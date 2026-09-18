package site.conflux.profile.domain;

import java.util.Set;

/** Ensures self-published claims stay chosen by the user, not inferred by imports. */
public final class ProfilePublicationPolicy {
    private ProfilePublicationPolicy() {}

    public static boolean acceptsGoals(Set<ProfileGoal> goals) {
        return goals != null && goals.size() <= 5 && goals.stream().allMatch(goal ->
            goal.category() != null
                && (goal.detail() == null || goal.detail().length() <= 280)
        );
    }

    public static boolean acceptsExternalLink(String link) {
        return link != null && (link.startsWith("https://") || link.startsWith("http://"));
    }
}
