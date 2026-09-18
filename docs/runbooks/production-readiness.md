# Production Readiness Runbook

## Startup

Run the service with the `persistence` profile only after PostgreSQL and Redis are healthy. The readiness probe must be checked separately from liveness before sending traffic to an instance.

## Traceability

Every response includes `X-Request-Id`. Support, logs, metrics, and audit records should use that value when diagnosing a state transition. Never log provider tokens, webhook secrets, raw chat content, or report detail in broad application logs.

## Dependencies

- PostgreSQL is durable source of truth and receives versioned Flyway migrations.
- Redis holds only short-lived presence, queues, locks, and rate-limit counters.
- Failed dependency readiness keeps the service out of traffic; it must not silently fall back to browser or in-memory authority.

## Security checks before release

- Configure HTTPS at the edge and restrict CORS origins.
- Inject OAuth, Razorpay, TURN, and webhook secrets through a secret manager.
- Verify provider webhook signatures before changing subscriptions or entitlements.
- Confirm rate limits for login, Match queue joins, and reports are enforced through Redis.
- Review error responses for safe detail and a trace id.
