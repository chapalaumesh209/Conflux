# CONFLUX.site

CONFLUX.site is a verified, people-first networking product for developers. It is designed around a deliberately small core loop: meet someone, talk with useful context, connect or choose next, then make the relationships worth returning to.

## Repository layout

- `src/` — Next.js web client and presentation layer.
- `src/lib/api/` — typed browser-to-service API boundary.
- `server/` — Java 21 Spring Boot modular-monolith baseline.
- `docs/adr/` — architecture decisions that guide future modules.

## Run locally

### Web

```bash
npm ci
cp .env.example .env.local
npm run dev
```

The web client opens at `http://localhost:3000` (or the next available port).

### Service

```bash
cd server
cp .env.example .env
docker compose up -d
SPRING_PROFILES_ACTIVE=persistence ./gradlew bootRun
```

The service opens at `http://localhost:8080`. Its probes are available at:

- `GET /api/v1/system/health`
- `GET /actuator/health/liveness`
- `GET /actuator/health/readiness`

## Checks

```bash
npm run check
cd server && ./gradlew test
```

## Foundation rules

- The browser is not authoritative for identity, verification, matching, timers, entitlements, or safety decisions.
- Free members can meet, connect, chat, revisit connections, and voluntarily share professional links.
- Discovery remains finite; it is never a feed.
- New capabilities must include their API contract, validation, authorization, state handling, observability, tests, and relevant documentation.

The current service migrations establish the audit, identity, consent, profile, skill, project, connection, conversation, message, presence, Meet-session, decision-ledger, media-consent, finite-discovery, subscription, entitlement, payment-webhook, Build Room, relationship-memory, safety/moderation, product-event, and feature-flag schema. Their APIs are added only with authenticated request handling; no browser screen can promote itself to a verified or match-ready account, infer a mutual connection, create its own match session, override the server-issued Meet expiry, activate voice/video without mutual consent, create an unbounded discovery feed, grant itself Pro access, or create a Build Room without the corresponding connection and entitlement checks. Relationship memory accepts bounded structured signals, not raw chat content by default. Blocks and reports immediately remove a person from the reporter’s matching surfaces without notifying the subject. Beta analytics use an explicit structured event vocabulary and reject raw-content payloads.

V1 deliberately excludes groups, events, organisation features, marketplaces, content feeds, team matching, and native mobile clients. See [ADR 0003](docs/adr/0003-v1-scope-boundary.md) for the evidence gate that must be met before those modes are considered.

The service currently provides the Phase 0 health, configuration, CORS, request-trace, PostgreSQL migration, and Redis runtime baseline. Authentication, OAuth, payments, and realtime adapters are intentionally not simulated in the browser; they are introduced as server-backed phases with their own migrations and tests.
# Conflux
# Conflux
