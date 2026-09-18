package site.conflux.profile.domain;

import java.util.LinkedHashSet;
import java.util.Set;

/** Keeps onboarding brief while ensuring the matcher receives structured signal. */
public final class ProfileCompletionPolicy {
    private ProfileCompletionPolicy() {}

    public static ProfileCompletion evaluate(ProfileDraft draft) {
        Set<String> missing = new LinkedHashSet<>();
        if (blank(draft.displayName())) missing.add("displayName");
        if (blank(draft.headline())) missing.add("headline");
        if (blank(draft.currentFocus())) missing.add("currentFocus");
        if (draft.primaryIntent() == null) missing.add("primaryIntent");
        if (draft.meetMode() == null) missing.add("meetMode");
        if (draft.canonicalSkills() == null || draft.canonicalSkills().isEmpty()) missing.add("skills");
        return new ProfileCompletion(missing.isEmpty(), Set.copyOf(missing));
    }

    private static boolean blank(String value) {
        return value == null || value.isBlank();
    }
}
