---
principle_id: P-M
title: "Heterogeneous Engine Contract & Server-Sovereign Boundary"
level: L0
view: logical
authority: "Layer 0 governing principle (CLAUDE.md); W2.x engine contract structural wave"
enforced_by_rules: [43, 44, 45, 46, 47, 48]
kernel: |
  P-M — Heterogeneous Engine Contract & Server-Sovereign Boundary.
  The platform supports heterogeneous execution engines through a structured
  contract surface: a lightweight configuration envelope governs registration
  / routing / observability, strict matching prevents silent reinterpretation
  of engine-specific payloads, runtime-owned middleware attaches via
  engine-declared lifecycle hooks, server-to-client capability invocation is
  an explicit asynchronous protocol bound to the suspend/resume loop, and the
  evolution mechanism manages only server-controlled execution scope by
  default.
  Enforced by Rules 43–47; cross-cutting structural invariant operationalised
  by Rule 48 (Schema-First Domain Contracts).
---

## Motivation

This principle exists because **a platform that supports more than one execution engine without a structured contract surface degenerates into N parallel implementations, N policy stacks, and N observability surfaces** — every engine ends up patched independently with cross-cutting concerns (model gateway, tool authz, memory governance, tenant policy, quota, observability, sandbox routing, checkpoint, failure handling), the platform team loses control of the policy boundary, and "heterogeneous engine support" becomes "heterogeneous bug surface". P-M imposes a five-rule structural contract — **envelope + strict matching + hook-based middleware + S2C protocol + evolution scope boundary** — and a sixth cross-cutting rule (Rule 48 — Schema-First Domain Contracts) ensures every NEW fixed-vocabulary taxonomy lands as `yaml schema → Java type → runtime self-validate` rather than as prose drift. The "Server-Sovereign Boundary" wording captures the second half: the evolution mechanism manages only server-controlled execution scope, not client-supplied execution.

## Operationalising rules

- Rule 43 — Engine Envelope Single Authority ([`docs/governance/rules/rule-43.md`](../rules/rule-43.md))
- Rule 44 — Strict Engine Matching ([`docs/governance/rules/rule-44.md`](../rules/rule-44.md))
- Rule 45 — Runtime-Owned Middleware via Engine Hooks ([`docs/governance/rules/rule-45.md`](../rules/rule-45.md))
- Rule 46 — S2C Callback Envelope + Lifecycle Bound ([`docs/governance/rules/rule-46.md`](../rules/rule-46.md))
- Rule 47 — Evolution Scope Default Boundary ([`docs/governance/rules/rule-47.md`](../rules/rule-47.md))
- Rule 48 — Schema-First Domain Contracts ([`docs/governance/rules/rule-48.md`](../rules/rule-48.md))

## Cross-references

- ADR-0071 (umbrella ADR for the W2.x engine contract structural wave)
- ADR-0072 (engine envelope + strict matching — Rules 43/44)
- ADR-0073 (engine hooks + runtime-owned middleware — Rule 45)
- ADR-0074 (S2C callback envelope + lifecycle bound — Rule 46)
- ADR-0075 (evolution scope default boundary — Rule 47)
- ADR-0077 (schema-first domain contracts — Rule 48 cross-cutting invariant)
- Contract sources of truth under `docs/contracts/`: `engine-envelope.v1.yaml`, `engine-hooks.v1.yaml`, `s2c-callback.v1.yaml`; governance scope at `docs/governance/evolution-scope.v1.yaml`
- Deferred sub-clauses: 44.b, 44.c (matching follow-on), 45.b (Run-state consumption of HookOutcome — W2 Telemetry Vertical), 46.b, 46.c (S2C async orchestrator), 48.b, 48.c (schema-first follow-on) — see [`docs/CLAUDE-deferred.md`](../../CLAUDE-deferred.md)
- Related: P-D (SPI + DFX + TCK) — P-M is the W2.x extension of P-D into engine pluggability
- Related: P-H (Chronos Hydration) — S2C callback (Rule 46) uses SuspendSignal sealed checked-suspension variant
