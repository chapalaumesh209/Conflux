# Production Audit V3

## Scope

This audit compares the checked-in CONFLUX application with the Production Application Master Specification v3. It is the Phase 0 baseline for the production conversion. It does not apply database migrations or change production data.

## Evidence reviewed

- Production Application Master Specification v3, including the Phase 0 to Phase 8 implementation gates.
- The Next.js web client in `src/`.
- The Spring Boot service in `server/` and its Flyway migrations.
- Local environment availability without printing any secret values.

## Current implementation state

### Web client

The web client is a single client-rendered screen with an in-memory view state machine. It contains hard-coded people, connections, profile content, project content, counters, chat text, notifications, entitlement state, and delayed Meet preview behavior. Buttons update local state or show a toast; they do not perform authenticated, persisted product actions.

The client has a typed API boundary, but no product screen uses it. It has no Supabase dependency, no Supabase auth/session integration, no realtime channel, and no configured production API origin in the checked-in environment files.

### Service

The Spring Boot service provides health probes, CORS, request tracing, error handling, domain policies, and PostgreSQL/Flyway/Redis configuration. It contains no authenticated product controllers beyond the health endpoint and no Supabase JWT verification, websocket signaling, payment adapter, or realtime persistence adapter.

The existing Flyway migrations are a valuable schema foundation, but they target a generic PostgreSQL runtime. Their relation to the active Supabase schema is not yet known and must not be assumed.

### Production configuration available to this workspace

The local process does not currently have a Supabase URL, Supabase anon key, Supabase service-role key, PostgreSQL connection values, or a configured public API origin. The audit intentionally checked only whether values were present; it did not read or expose credentials.

## Required corrections before a real-data release

1. Replace every prototype record and local-only interaction in user-facing routes with authenticated queries and mutations. Empty, loading, unauthorized, and retry states must replace demo fallbacks.
2. Establish one production data path: Supabase Postgres is the system of record, and sensitive transitions run through the trusted service or protected RPCs.
3. Inspect the live Supabase schema, indexes, RLS policies, triggers, and existing data. Map each current relation to the canonical entities before creating any forward migration.
4. Add Supabase authentication and session handling. Browser code receives only public configuration; service-role credentials remain server-only.
5. Build server-authoritative APIs for profile, candidate discovery, Meet lifecycle, decisions, mutual connection, conversations, messages, projects, membership requests, tasks, milestones, notifications, moderation, and entitlement checks.
6. Add realtime delivery for messages, read state, presence, Meet events, and Build Room activity. Add a TURN-backed WebRTC signaling design before enabling audio, video, or screen-share controls.
7. Enforce privacy, mutual-connection chat gating, Pro-only join and screen-share initiation, idempotency, RLS, rate limits, and audit trails in the data/service layer rather than the browser.

## Phase 0 acceptance gate

Phase 1 may begin only after the following inputs are available and recorded outside source control:

- A read-only export or inspection of the active Supabase schema, including tables, columns, constraints, indexes, RLS policies, triggers, and current migration history.
- The production deployment topology: public frontend URL, deployed API URL, and whether the Spring service or Supabase Edge Functions owns trusted mutations.
- Server-only database/service credentials supplied through secure deployment environment variables, plus public Supabase URL and anon key for browser authentication.
- The production auth providers, billing provider, and TURN provider selected for this release.

## Migration safety rule

No existing Supabase table, RLS policy, column, or record may be deleted or renamed until the schema map, forward migration, rollback plan, backfill validation, and owner/member/non-member/anonymous RLS tests are complete.

## Next implementation slice

Once the Phase 0 inputs are available, the first production slice is the canonical data foundation: inspect and map the live schema, write additive forward migrations, add RLS tests, and ship real authentication plus persisted profiles before enabling Meet or Build Room mutations.
