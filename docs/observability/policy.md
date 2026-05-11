# Observability Policy

> Owner: observability | Wave: W0 (logs + metrics) + W1 (traces) + W2 (cardinality + dashboards) | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Defines the cardinality budget, label schemes, span attribute schemes,
and log fields. The OSS stack is Micrometer + Prometheus + OpenTelemetry
+ Logback + Loki + Grafana. Replaces the pre-refresh
`docs/observability/cardinality-policy.md`.

## 2. Cardinality budget

`tenant_id` is the highest-risk label. Direct use as a label is
forbidden by default. The runtime exposes a single allowlist registry
(below) and a `CardinalityGuard` lint that rejects unauthorized direct
use.

| Posture | Cardinality budget per metric | tenant_id raw label allowed |
|---|---|---|
| `dev` | unbounded | yes |
| `research` | <= 50 | only via this allowlist |
| `prod` | <= 50 | only via this allowlist |

### Allowlist (W2)

| Metric | Reason | Cap |
|---|---|---|
| `agent_run_started_total{tenant_id}` | per-tenant volume tracking | <= 50 distinct |
| `agent_run_cost_usd_total{tenant_id,model}` | per-tenant per-model cost | <= 50 * 10 |

Outside the allowlist, `tenant_id` is bucketed (`hash(tenant_id) % 50`)
into a synthetic `tenant_bucket` label.

## 3. Standard label set

Every Micrometer-emitted metric carries:

- `service` -- `agent-platform` or `agent-runtime`.
- `posture` -- `dev | research | prod`.
- `version` -- the deployment version (set at startup).

Plus, when relevant:

- `tenant_bucket` -- hashed bucket of `tenant_id`.
- `outcome` -- `success | failure | cancelled` (terminal events).

## 4. Standard span attributes (OpenTelemetry semconv)

| Attribute | Required when |
|---|---|
| `tenant.id` | always (within request scope) |
| `run.id` | within run orchestration |
| `agent.capability` | within tool / action call |
| `llm.provider` | within LLM call span |
| `llm.model` | within LLM call span |
| `llm.tokens.input` / `llm.tokens.output` | within LLM call span |
| `tool.name` | within tool call span |
| `db.operation` / `db.statement` (sanitized) | within DB span |

Sample rates per posture:

| Posture | Sample rate | Notes |
|---|---|---|
| `dev` | 100% | full traces |
| `research` | 10% | head-based |
| `prod` | 1% | head-based; tail-based on errors via Tempo collector |

## 5. Standard log fields

JSON encoder emits:

```json
{
  "ts": "2026-05-09T...",
  "level": "INFO|WARN|ERROR",
  "service": "agent-platform",
  "posture": "research",
  "tenant_id": "<uuid|null>",
  "run_id": "<uuid|null>",
  "trace_id": "<otel-trace-id>",
  "span_id": "<otel-span-id>",
  "msg": "...",
  "kv": { ... structured fields ... }
}
```

## 6. Required metrics by module

| Metric | Owner module | Wave |
|---|---|---|
| `agent_run_started_total` | `agent-runtime/run` | W2 |
| `agent_run_terminal_total{outcome}` | `agent-runtime/run` | W2 |
| `agent_run_cost_usd_total{tenant_id,model}` | `agent-runtime/llm` | W2 |
| `agent_runs_pending` (gauge) | `agent-runtime/run` | W2 |
| `outbox_unsent_age_seconds_max` (gauge) | `agent-runtime/outbox` | W2 |
| `*_fallback_total` (per fallback branch) | various | W2 (LlmRouter), W3 (ActionGuard / OPA) |
| `app_secret_rotation_total{secret}` | `agent-platform/bootstrap` | W2 |
| `cardinality_budget_exceeded_total{metric}` | `agent-runtime/observability` | W2 |
| `llm_prompt_cache_hit_total{provider,model}` | `agent-runtime/llm` | W2 |
| `actionguard_decision_total{outcome}` | `agent-runtime/action` | W3 |
| `eval_pass_rate{suite}` | `agent-eval` | W4 |

## 7. Dashboards (W2)

`ops/grafana-dashboards/`:

- `runs.json` -- run volume, terminal outcome breakdown, latency p50/p95/p99.
- `cost.json` -- cost per tenant per model.
- `outbox.json` -- pending count, lag, DLQ.
- `actionguard.json` -- decision breakdown, OPA latency.
- `eval.json` -- eval pass-rate trends.

## 8. Tests

| Test | Layer | Asserts |
|---|---|---|
| `CardinalityBudgetIT` | Integration | exceeding budget logs warning + drops to bucket |
| `TraceTenantPropagationIT` | Integration | child span has `tenant.id` attribute |
| `LogFieldShapeIT` | Integration | every log line has required fields |
| `MetricNamingIT` | Integration | every custom metric matches naming policy |
| `SampleRateIT` (per posture) | Integration | trace sample rate matches posture |

## 9. Open issues / deferred

- Tail-based sampling on errors (Tempo collector config): W3+.
- Cost-per-prompt-template metric: W4+.
- Per-tenant alerting (alertmanager rules): W4+.

## 10. References

- `agent-runtime/ARCHITECTURE.md`
- `docs/v6-rationale/v6-security-control-matrix.md` (archived 2026-05-12)
