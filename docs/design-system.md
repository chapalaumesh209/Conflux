# CONFLUX Design System

## Purpose

The interface should help a builder make one useful move, not invite endless consumption. Components need to preserve the same visual and behavioral meaning wherever they appear.

## Foundations

`src/app/tokens.css` is the source for semantic colour, typography, spacing, elevation, motion, and layer tokens. Use the semantic name, such as `--color-live` or `--color-ready`, instead of reaching directly for a hex value in new component styles.

## Component rules

- **Primary action** uses readiness green and appears once per decision area.
- **Navigation and live state** use cobalt; they do not imply a successful match.
- **Trust** is compact, descriptive, and never an attention-grabbing hero element.
- **Urgent or safety-related actions** use coral only when time or risk needs attention.
- **Panels** use `--radius-panel` and `--shadow-panel`; ordinary controls use `--radius-control`.
- **Measurements** such as timers and counts use DM Mono. Interface text uses Bricolage Grotesque.

## State contract

Every new interactive screen needs explicit loading, empty, success, error, retry, and permission-denied states. Prefer a text-first recovery path whenever media or realtime services are unavailable. Do not represent server-authoritative state as a durable browser truth.

## Accessibility and motion

All controls need visible focus, semantic labels, keyboard access, and an equivalent text path. Motion should clarify a state change, use the shared timing tokens, and respect the existing reduced-motion media query.
