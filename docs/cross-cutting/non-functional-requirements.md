# Non-Functional Requirements -- cross-cutting policy

> Owner: architecture | Wave: W0..W4 (per-NFR target wave varies) | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Pins concrete numerical targets for latency, throughput, availability,
durability, cost, and capacity. The L0 architecture references this
doc as the authoritative source of NFR numbers; every L2 module
inherits the targets relevant to its surface and may NOT loosen them
without an L0 change. Replaces the implicit "p99 < target" placeholders
in module Tests sections.

## 2. Service Level Objectives (SLOs)

### 2.1 Latency (per request, server-side)

| Endpoint class | dev | research | prod |
|---|---|---|---|
| `GET /v1/health` | p99 < 50ms | p99 < 50ms | p99 < 30ms |
| `POST /v1/runs` (sync, fake LLM) | p99 < 500ms | p99 < 300ms | p99 < 200ms |
| `POST /v1/runs` (sync, real LLM) | p99 < 8s | p99 < 5s | p99 < 5s |
| `POST /v1/runs/{id}/cancel` | p99 < 200ms | p99 < 200ms | p99 < 100ms |
| `GET /v1/runs/{id}` | p99 < 200ms | p99 < 100ms | p99 < 80ms |
| `POST /v1/workspace` | p99 < 300ms | p99 < 200ms | p99 < 150ms |
| Tool call (in-process bean) | p99 < 100ms | p99 < 50ms | p99 < 50ms |
| Tool call (out-of-process MCP) | p99 < 500ms | p99 < 300ms | p99 < 200ms |
| OPA decision | p99 < 10ms | p99 < 5ms | p99 < 5ms |
| Postgres read (single tenant tx) | p99 < 30ms | p99 < 20ms | p99 < 15ms |
| Postgres write (audit + outbox) | p99 < 60ms | p99 < 40ms | p99 < 30ms |

LLM-call latency is provider-dependent and excluded from server-side
SLO; budget = `5 x median(provider_p95)` per call.

### 2.2 Throughput

| Surface | dev | research | prod |
|---|---|---|---|
| HTTP requests / second / replica | n/a | 50 | 200 |
| Concurrent in-flight runs / replica | n/a | 100 | 400 |
| Sustained outbox publish rate / replica | n/a | 100/s | 500/s |
| Tenant-onboarding rate | n/a | 10/day | 100/day |

### 2.3 Availability

| Service | research | prod |
|---|---|---|
| Public HTTP API | 99.5% monthly | 99.9% monthly |
| LLM gateway (LlmRouter) | 99% (degrades to fake on outage) | 99.5% |
| Run lifecycle (sync) | 99.5% | 99.9% |
| Run lifecycle (Temporal) | 99.9% | 99.95% (durability dominates) |
| Postgres | 99.9% (single instance v1) | 99.95% (replica v2) |

Error-budget burn alerts when consumed > 5% of monthly budget in 1
hour.

### 2.4 Durability

| Data class | RPO | RTO |
|---|---|---|
| Run table | 1h | 4h |
| Audit log | 0 (append-only + S3 anchor in W4) | n/a |
| Outbox | 1h (re-published from source) | 4h |
| Memory L1 / L2 | 24h | 24h (rebuildable) |
| Tenant config | 1h | 4h |
| Tenant identity (Keycloak) | external responsibility | external |

### 2.5 Cost (per posture, indicative)

| Cost item | research | prod |
|---|---|---|
| Per-run LLM cost (cheap-tier escalation) | <= $0.005 median | <= $0.003 median |
| Per-run platform compute | <= $0.0005 | <= $0.0003 |
| Per-tenant infra fixed | <= $50/month | <= $10/month at 100 tenants |
| Eval suite nightly cost | <= $5 per 200-case run | <= $5 per 200-case run |

Cost telemetry: `agent_run_cost_usd_total{tenant,model}` Prometheus
counter (per `agent-runtime/llm/CostMetering.java`).

### 2.6 Capacity (v1 design point)

| Resource | dev | research | prod |
|---|---|---|---|
| Tenants | 1 | 1-10 | up to 1000 (Postgres single-instance limit) |
| Concurrent users / tenant | 10 | 100 | 1000 |
| Runs / tenant / day | 100 | 10000 | 100000 |
| Active tools / tenant | 10 | 50 | 200 |
| Long-term memory rows / tenant | 1k | 100k | 1M (pgvector limit; Qdrant trigger > 5M) |
| Audit log retention | 30d | 365d | 7y (W4 partition + S3 archive) |

## 3. Mapping to L2 modules

| NFR | L2 owner | Test |
|---|---|---|
| Run sync latency | `agent-runtime/run` | `RunHappyPathIT` (p99 assert) |
| Run cancel latency | `agent-runtime/run` | `RunCancellationIT` |
| OPA latency | `agent-runtime/action` | `ActionGuardLatencyIT` |
| Postgres tx latency | `agent-platform/tenant` | `TenantIsolationIT` (timed) |
| Outbox publish rate | `agent-runtime/outbox` | `OutboxAtLeastOnceIT` (rate assert) |
| HTTP throughput | `agent-platform/web` | `ConcurrencyLoadIT` |
| Cost per run | `agent-runtime/llm` | `LlmCostMeterIT` (assert ratio) |
| Eval cost | `agent-eval` | nightly cost gauge |

## 4. Per-posture defaults

The numbers above are starting targets. Production lower bounds are
non-negotiable; research and dev are looser. Acceptance gates per wave
(in `docs/plans/engineering-plan-W0-W4.md`) reference these targets.

## 5. Out of scope

- Per-customer SLA contracts (commercial; not architectural).
- SLO error-budget policies (separate ops doc; W4+).
- Customer-facing dashboards (W4+).

## 6. References

- `ARCHITECTURE.md` sec-13 (the in-line summary points here)
- `docs/cross-cutting/observability-policy.md` (where SLOs are
  monitored)
- `docs/plans/engineering-plan-W0-W4.md` per-wave Acceptance gates
