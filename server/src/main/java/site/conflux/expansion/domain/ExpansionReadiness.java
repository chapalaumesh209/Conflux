package site.conflux.expansion.domain;

import java.util.Set;

public record ExpansionReadiness(boolean ready, Set<String> missingEvidence) {}
