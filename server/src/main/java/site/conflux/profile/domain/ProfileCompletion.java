package site.conflux.profile.domain;

import java.util.Set;

public record ProfileCompletion(boolean readyForMatching, Set<String> missingFields) {}
