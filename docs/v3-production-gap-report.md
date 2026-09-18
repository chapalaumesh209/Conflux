# CONFLUX V3 Production Gap Report

## Decision and scope

This report records the repository state against `CONFLUX_site_V3_Codex_Complete_Production_Specification_FINAL.docx` before the next implementation batch. V3 is the controlling contract. Existing implementation is not treated as evidence that a V3 feature is complete.

**Architecture decision: A — Supabase-centric production architecture.** The deployed Next.js application reads and writes Supabase Auth, Postgres, Realtime, and RLS directly. The Java 21/Spring module contains useful domain policy classes, Flyway history, a health endpoint, and Redis dependencies, but it does not expose the V3 product API and is not connected to the deployed frontend. Introducing it as an unplanned second authority would create split authorization and data ownership. Supabase is therefore the canonical data and authorization authority for this migration path. Redis/cache behavior will be introduced through a managed cache/Edge or trusted server boundary in its dedicated phase; it is not currently claimed as active.

This decision deliberately does not claim that the production app currently runs on Java/Spring or Redis. The Java module remains a reference/policy asset until a separately approved migration makes it the sole server boundary.

## Repository architecture summary

| Layer | Current state | Finding |
| --- | --- | --- |
| Web | Next.js 15 / React 19 app on Vercel | Production UI exists and is built from route entry files plus a shared client product shell. |
| Identity and data | Supabase Auth + `cf_` Postgres tables + RLS | Actual deployed data path; public URL and anon key are browser configuration only. |
| Realtime | Supabase Realtime enabled for Meet messages, direct messages, project messages, notifications | Messages subscribe directly, but acknowledgements, read state, reconnect recovery, and conversation state are incomplete. |
| Server module | Java 21 / Spring Boot modular monolith | Domain policies and Flyway migrations exist, but no product API is consumed by the web app. |
| Cache/runtime | No active cache configuration or client/server adapter found | Redis is a V3 gap, not an implemented feature. |
| Deployment | Vercel deployment with `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Production configuration cannot be inferred from source. The canonical intended site URL is `https://conflux.site`. |

## Current route inventory

| Current route | Current behavior | V3 disposition |
| --- | --- | --- |
| `/` | Marketing landing page | Canonical; preserve. |
| `/auth` | Sign-in form | Compatibility alias; redirect to `/login`. |
| `/register` | Sign-up plus email OTP | Compatibility alias; redirect to `/signup`. |
| `/onboarding` | Required profile completion after OTP | Canonical but needs draft autosave/resume. |
| `/meet` | Candidate selection, Meet text, directional Connect/Next | Canonical; needs lifecycle/media correctness. |
| `/connections` | Mutual connections and direct messages | Canonical list; individual relation and chat routes missing. |
| `/build-rooms` | Project list and task UI | Compatibility alias; redirect to `/buildroom`. |
| `/profile` | Profile editor | Becomes settings/profile successor; public profile route missing. |

V3 routes not yet implemented: `/discover`, `/search`, `/connections/:id`, `/chat/:conversationId`, `/u/:username`, the Build Room subtree, `/notifications`, `/pro`, settings routes, `/blocked`, and `/report`.

## Current schema and migration inventory

`202609180001_conflux_production_foundation.sql` defines `cf_profiles`, contacts, safety records, Meet sessions/messages, durable pairwise connections/messages, projects, tasks, milestones, join requests, entitlements, notifications, RLS policies, and five authenticated RPCs. It also enables Realtime for the current message and notification tables.

`202609180002_auth_and_required_profile_details.sql` adds interests, date of birth, gender, optional mobile number, and the authenticated `cf_complete_onboarding` RPC. This migration is required for the current registration/onboarding contract and must be deployed after migration 001.

The first two migrations are intentionally additive but are not the full canonical V3 model. They lack normalized profile joins/verification records, onboarding drafts, conversations/read state, room slugs and collaboration artifacts, ranking events/features, saved search, audit/subscription records, and explicit versioned autosave contracts.

## RLS and security inventory

Existing RLS provides a solid starting point: users can only create/update their profiles, profile contacts are connection-gated, Meet and direct-message reads are participant-gated, public project summaries are available, and Pro join requests use a `security definer` entitlement check.

Gaps: an existing block does not consistently terminate access to established connections/messages; direct messages are scoped to a connection rather than a canonical conversation; task and milestone write policies give all members write access rather than a project role capability; storage access has no policy; no provider/webhook boundary exists for entitlement writes; and provider URL collection is not provider verification. No service-role secret is in the frontend source.

## Feature completion matrix

| V3 area | Current production behavior | Status |
| --- | --- | --- |
| Email/password and OTP | Supabase sign-up, signup OTP, email-confirmed onboarding guard | Partial — canonical routes and resilient confirmation configuration still required. |
| Provider identity | LinkedIn/GitHub URL validation only | Not complete — no OAuth/provider verification may be represented as verified. |
| Profile | Required onboarding fields persist on submit | Partial — no persisted drafts, resume, privacy model, or version conflict response. |
| Meet | Real candidate RPC, Meet session, text messages, Connect/Next, block/report actions | Partial — no active-session race hardening, action ledger, consent media, presence/cache, or reconnect protocol. |
| Mutual connection | Database unordered-pair uniqueness and transactional decision RPC | Partial — durable conversation and block termination are missing. |
| Chat | Real direct message persistence and Realtime subscription | Partial — no canonical conversation URL, unread/read state, explicit send RPC/idempotency at UI, retry, or block-safe access. |
| Build Room | Owner project creation, members, join requests, tasks/milestones/project messages | Partial — no slug routes, role capability model, expanded statuses, room notes/files/links/activity/calls, or revision safeguards. |
| Discovery | Simple profile RPC ranks by recent profile update and overlap text | Partial — no finite persisted dispatch, feature version, reciprocal scoring, diversity, cache, or explainable event ledger. |
| Pro | Database entitlement predicate gates join request RPC | Partial — no checkout, provider webhook, expiry reconciliation, or server-owned billing source. |
| Search | None | Not started. |
| Observability | Basic Java trace/filter policy exists but is not in deployed request path | Not started for deployed app. |

## V3 compliance and action table

| Requirement | Current | V3 target | Gap | Action | Priority |
| --- | --- | --- | --- | --- | --- |
| One production authority | Supabase UI plus dormant Java policy module | Explicit, consistent authority | Architecture is implicit | Document Supabase decision; keep Java inactive until a planned cutover | P0 |
| Canonical auth URLs | `/auth`, `/register` | `/login`, `/signup`; aliases only | Duplicate public entry URLs | Add canonical route pages and redirect aliases | P0 |
| Onboarding persistence | One final RPC submit | Draft, debounce, resume, server validation | Refresh loses work | Add versioned `cf_onboarding_drafts` and client autosave | P0 |
| Mutual relationship | Unique unordered pair | Idempotent durable connection plus chat | Conversation not materialized; block does not end access | Add conversation trigger, participant state, blocked-policy guard | P0 |
| Persistent chat | Connection-scoped messages | Conversation-scoped, deduped, read-aware, realtime | No conversation ID, client idempotency path, read state | Add conversation/message RPCs and client migration | P0 |
| Build Room identity | UUID projects | Stable slug and persistent room aggregate | No canonical room URL or version safety | Add slug/version and Build Room foundation objects | P0 |
| Authorization | RLS baseline | Ownership, member role, block, entitlement enforced | Member write privileges are overly broad | Add role capability predicate and replace affected policies | P0 |
| Provider verification | URL regex | Authentic provider state | URLs can look verified | Store verification state separately; do not set provider verified from URLs | P0 |
| Meet lifecycle | Direct active session create | Participant-safe active state, no timer | Candidate may be selected while active elsewhere | Lock eligible profiles and reject incompatible active state | P1 |
| Discovery | Recent-update list | Ranked finite recommendations | No scorer/version/cache/claim/dedup | Implement baseline ranker + events, then managed cache | P1 |
| Build collaboration | Projects/tasks/milestones/messages | Notes/files/activity/roles/calls | Supporting entities and routes absent | Add schema first, then room subroutes and CRUD | P1 |
| Pro billing | Entitlement table/manual predicate | Provider webhook authoritative | No payment integration | Add provider-selected server/Edge webhook flow | P1/provider-dependent |
| Media | Text-only Meet, no deceptive controls | Consent audio/video and Pro share enforcement | No actual media provider/signaling | Design and deploy trusted signaling/provider integration | P1/provider-dependent |
| Search | None | Pro custom/saved search | Entire feature absent | Implement after discovery + entitlement boundary | P1 |
| Cache/presence | None | Redis or equivalent managed cache | No runtime state adapter | Add managed cache boundary and DB fallback | P2 until discovery/Meet scaling requires it |
| Monitoring | None on deployed frontend | Error, DB, realtime, billing, media metrics | No observability integration | Select provider and instrument after core behavior | P2 |

## Database and migration safety report

1. Production schema must be inspected in Supabase before application. This repository cannot read the hosted schema with the public browser key alone.
2. Apply in order: `001`, `002`, then forward-only `003`. Migration 003 assumes the `cf_` tables from 001 and 002 exist; it does not drop user data.
3. Before applying, compare `information_schema.columns`, `pg_constraint`, RLS policies, functions, triggers, publication tables, counts, and existing Supabase migration history. Preserve any data outside the `cf_` namespace.
4. Migration 003 backfills a conversation for each existing connection and a stable project slug for each existing project. It adds foreign keys and uniqueness only after backfill.
5. Validate after deployment: profile/project/connection/message counts; orphan checks; slug/pair/client-message uniqueness; function permissions; anonymous and participant RLS checks; publication membership; and no accessible private links after a block.

## Implementation plan

1. **P0 foundation (this batch):** gap report, canonical route names and aliases, forward-only schema for onboarding drafts, conversations, block-safe access, room slugs/version fields, and expanded task lifecycle.
2. **P1 profile/onboarding:** client draft autosave/resume, saved/retry states, canonical profile/settings URLs, provider-state UI that never fabricates verification.
3. **P2 Meet and chat:** move UI to conversations; client idempotency/retry/read receipts; active-session and action behavior; truthful media consent states once a provider exists.
4. **P3 Build Rooms:** canonical slug routes and real room detail/task/milestone/member/discussion CRUD with role checks and conflict responses.
5. **P4 discovery/search/cache:** versioned ranking, event ledger, finite dispatch, managed cache with database fallback, Pro search and saved searches.
6. **P5 collaboration/media/billing/operations:** provider-selected billing/webhooks, files/storage policies, signaling/WebRTC, monitoring, RLS/E2E launch checks.

## Risks and external configuration

- Supabase production schema/history is not available from this workspace; migration application must be performed only after the stated live inspection.
- Supabase email confirmation must remain enabled and the confirmation email template must use `{{ .Token }}` for this OTP UI.
- GitHub and LinkedIn OAuth credentials, a billing provider/webhook secret, a managed cache endpoint, storage configuration, and a WebRTC/signaling provider are provider-dependent. They cannot be implemented honestly without their server-side configuration.
- Vercel must use `https://conflux.site` as its site URL and permit that URL (and `https://www.conflux.site/` only if used) in Supabase redirect configuration. No unimplemented callback URL should be added.

## Exact next phase

Execute **P0 foundation**: add the safe forward migration and canonical auth/build-room route contract, then run the frontend build and migration static checks. The next phase after acceptance is profile/onboarding autosave and resume.
