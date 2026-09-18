# ADR 0001 Modular Monolith Baseline

## Status

Accepted for V1.

## Context

CONFLUX needs a reliable core loop before it needs independently deployed services. The product requires server-authoritative identity, verification, matching, session timing, connections, billing, safety, and privacy decisions. Splitting these responsibilities early would make that consistency harder to preserve.

## Decision

The system starts as a Java 21 Spring Boot modular monolith in `server/` and a separate Next.js web client in `src/`.

- PostgreSQL is the source of truth for durable data. Its migrations live under `server/src/main/resources/db/migration`.
- Redis holds only ephemeral presence, queue, rate-limit, and coordination data.
- Browser code calls the service through the typed API client boundary in `src/lib/api/`.
- Browser state is never authoritative for identity, verification, timers, matching, permissions, or billing.
- Modules own their contracts: identity, profile, presence, meet, connections, discovery, rooms, billing, and safety. Shared code is limited to cross-cutting concerns such as errors, tracing, and configuration.

## Consequences

This keeps transactional consistency and deployment simple while preserving clear seams for later extraction. New API work must add a typed web contract, service validation, authorization, audit/trace behavior where appropriate, tests, and an ADR when it changes a cross-module boundary.
