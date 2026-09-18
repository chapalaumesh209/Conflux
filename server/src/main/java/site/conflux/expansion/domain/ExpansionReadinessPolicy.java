package site.conflux.expansion.domain;

import java.util.LinkedHashSet;
import java.util.Set;

/** Prevents V1 drift into groups, events, or organisations without proof. */
public final class ExpansionReadinessPolicy {
    private ExpansionReadinessPolicy() {}

    public static ExpansionReadiness evaluate(V1Evidence evidence) {
        var missing = new LinkedHashSet<String>();
        if (!evidence.coreLoopStable()) missing.add("coreLoopStable");
        if (!evidence.safetyOperationsReady()) missing.add("safetyOperationsReady");
        if (!evidence.betaValidated()) missing.add("betaValidated");
        if (!evidence.userDemandConfirmed()) missing.add("userDemandConfirmed");
        return new ExpansionReadiness(missing.isEmpty(), Set.copyOf(missing));
    }
}
