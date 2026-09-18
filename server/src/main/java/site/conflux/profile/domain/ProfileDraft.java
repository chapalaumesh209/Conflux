package site.conflux.profile.domain;

import java.util.Set;

/** Input boundary for profile completion; UI strings are normalized before use. */
public record ProfileDraft(
    String displayName,
    String headline,
    String currentFocus,
    ProfileIntent primaryIntent,
    MeetMode meetMode,
    Set<String> canonicalSkills
) {}
