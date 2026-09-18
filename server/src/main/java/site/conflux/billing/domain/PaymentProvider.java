package site.conflux.billing.domain;

import java.util.UUID;

/** Provider adapters verify signatures server-side before changing entitlements. */
public interface PaymentProvider {
    CheckoutSession createCheckout(UUID userId, PlanCode plan);
    VerifiedWebhook verifyWebhook(String signature, byte[] rawPayload);
}
