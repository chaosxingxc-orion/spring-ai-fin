# Non-Functional Requirements

> Owner: architecture | Wave: W0 | Last updated: 2026-05-13 (post-seventh third-pass)

## W0 shipped SLOs (GET /v1/health only)

| Posture | p99 latency |
|---------|-------------|
| `dev` | < 50ms |
| `research` | < 50ms |
| `prod` | < 30ms |

Verified by `PostureBindingIT` and manual health-endpoint smoke.

## Deferred SLOs (W1+)

SLOs for POST /v1/runs, PUT /v1/runs/{id}/cancel, GET /v1/runs/{id}, workspace
endpoints, tool calls, OPA decisions, outbox throughput, availability, durability,
cost, and capacity targets are deferred to the wave that ships each surface.
Design intent preserved in the 2026-05-08 architecture docs (docs/v6-rationale/).

SLOs become enforceable once the corresponding route handler ships and a
Rule 8 operator-shape gate run records evidence in docs/delivery/.

## Active constraints (all waves)

- LLM latency: budget = `5 x median(provider_p95)`; excluded from hard SLO.
- Cardinality: <= 50 distinct series per metric label at research/prod (see docs/observability/policy.md).
- Error budget: alert when > 5% of monthly budget consumed in 1 hour (W2 alerting gate).
