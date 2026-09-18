package site.conflux.billing.domain;

public record CheckoutSession(String providerSessionReference, String redirectUrl) {}
