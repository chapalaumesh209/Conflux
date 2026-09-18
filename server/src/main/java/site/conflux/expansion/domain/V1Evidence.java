package site.conflux.expansion.domain;

/** Evidence must be explicit before the V1 boundary is expanded. */
public record V1Evidence(
    boolean coreLoopStable,
    boolean safetyOperationsReady,
    boolean betaValidated,
    boolean userDemandConfirmed
) {}
