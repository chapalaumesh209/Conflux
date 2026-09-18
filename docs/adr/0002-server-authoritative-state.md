# ADR 0002 Server Authoritative Product State

## Status

Accepted for V1.

## Decision

The service is the source of truth for account identity, verification, entitlements, match eligibility, Meet timing, connection state, visibility rules, and safety actions. The web client renders a projection of that state and may keep only reversible presentation state locally.

Every state-changing endpoint will require authentication, validate its input, authorize the action against current server state, and emit a traceable event. Sensitive provider credentials, payment signatures, moderation evidence, and private preference data never enter browser bundles or public profile payloads. Meet eligibility requires current Email, GitHub, and LinkedIn verification records evaluated by the service.

## Consequences

Optimistic UI is permitted only when it is reconciled with a server response. Hiding a control in the UI is not authorization. Future realtime messages must be treated as state notifications, not as permission grants.
