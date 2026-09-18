# Controlled Beta Launch

## Entry criteria

- Production readiness, migration, health, and rollback checks are green.
- OAuth, payment, and TURN provider credentials are set only through the secret manager.
- Safety triage owner and response process are available before inviting beta users.
- Feature flags start at zero-percent rollout and increase only after observability review.

## Beta signals

Track structured outcome events: profile completion, Meet start/completion, Connect/Next choices, mutual connections, messages, Build Room creation/activity, and Pro conversion. Do not add raw chat content, contact data, provider tokens, or report details to product events.

## Rollback

Disable a feature flag first. If a schema rollback is needed, use a forward corrective migration unless a tested reversible migration exists. Keep trace IDs with incident notes and safety actions.
