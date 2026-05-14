# Telemetry Policy

> Owner: telemetry-vertical | Wave: L1.x (contract surface) + W2 (engine) + W3 (client SDK) + W4 (MCP replay) | Maturity: L1 module-level
> Last refreshed: 2026-05-14 (Telemetry Vertical L1.x introduction)
> Authority: `ARCHITECTURE.md §0.5.3` + §4 #53–#59 + ADR-0061 / ADR-0062 / ADR-0063
> Prior name: `docs/observability/policy.md` (renamed; see ADR-0061 §2)

## 1. Purpose

Defines the data model, wire format, propagation contract, sampling, cardinality budget, label/attribute scheme, and log field shape for the Telemetry Vertical (§0.5.3). Every horizontal layer (HTTP edge → orchestration → executor → adapter → MCP) MUST emit into this vertical through `TraceContext` or the Hook SPI; no layer emits telemetry directly. OSS stack: Micrometer + Prometheus + OpenTelemetry (W2) + Logback + Tempo/Jaeger/Langfuse (any OTLP/HTTP sink) + Loki + Grafana.

## 2. Cardinality budget (metrics)

`tenant_id` is the highest-risk meter tag. Direct use as a raw label is forbidden by `TenantTagMeterFilter` (L1, commit `b193911`). The runtime exposes a single allowlist and a `CardinalityGuard` lint (W2) that rejects unauthorised direct use.

| Posture | Cardinality budget per metric | tenant_id raw label allowed |
|---|---|---|
| `dev` | unbounded | yes |
| `research` | ≤ 50 | only via the allowlist |
| `prod` | ≤ 50 | only via the allowlist |

### Allowlist (W2)

| Metric | Reason | Cap |
|---|---|---|
| `agent_run_started_total{tenant_id}` | per-tenant volume tracking | ≤ 50 distinct |
| `agent_run_cost_usd_total{tenant_id,model}` | per-tenant per-model cost | ≤ 50 × 10 |

Outside the allowlist, `tenant_id` is bucketed (`hash(tenant_id) % 50`) into a synthetic `tenant_bucket` label.

**Span vs metric reconciliation** (§4 #57): metrics keep `tenant_bucket` because every metric emission carries every label; spans get raw `tenant.id` because span storage is sampled (1-10 %) and span attributes are not aggregation dimensions. The two policies do not collide.

## 3. Standard meter labels

Every Micrometer-emitted metric carries:

- `service` — `agent-platform` or `agent-runtime`.
- `posture` — `dev | research | prod`.
- `version` — deployment version (set at startup).

Plus, when relevant:

- `tenant_bucket` — hashed bucket of `tenant_id`.
- `outcome` — `success | failure | cancelled` (terminal events).

## 4. Standard span attributes (Telemetry Vertical, §4 #56–#57)

Required attributes by emission site:

| Attribute | Required when |
|---|---|
| `tenant.id` | always (every span — §4 #57) |
| `run.id` | within run orchestration |
| `session.id` | when `RunContext.sessionId()` is non-null |
| `agent.capability` | within a capability/skill span |
| `gen_ai.system` | within an LLM call span (§4 #56) |
| `gen_ai.request.model` | within an LLM call span (§4 #56) |
| `gen_ai.usage.input_tokens` | within an LLM call span (§4 #56) |
| `gen_ai.usage.output_tokens` | within an LLM call span (§4 #56) |
| `langfuse.cost_usd` | within an LLM call span (§4 #56) |
| `langfuse.latency_ms` | within an LLM call span (§4 #56) |
| `tool.name` | within a tool call span |
| `mcp.tool.name` | within an MCP tool call span |
| `db.operation` / `db.statement` (sanitised) | within a DB span |

Prohibited attributes (§4 #58 negative invariant): raw prompt, completion, tool-input, tool-output content. These MUST be stored in `PayloadStore` and referenced via `payload_ref://<id>` in posture=research/prod.

### Sampling

| Posture | Sample rate | Notes |
|---|---|---|
| `dev` | 100 % | optional stdout-OTLP |
| `research` | 10 % | head-based |
| `prod` | 1 % | head-based + tail-on-error (W4 via Tempo collector) |

## 5. Wire format (W2 engine, L1.x contract)

**OTLP/HTTP** is the wire format (no gRPC). Endpoint configurable via `springai.telemetry.otlp.endpoint`. Compatible backends: Tempo, Jaeger, Langfuse, SigNoz, Honeycomb.

**Dual-write**: every Span is also written to `trace_store` (Postgres, ADR-0017 schema) via an outbox-style writer so the MCP replay surface (W4) can serve `get_run_trace` / `list_runs` / `get_llm_call` / `list_sessions` without an external sink dependency.

## 6. Propagation contract (HTTP edge, L1.x)

`TraceExtractFilter` (order 10, before JWT/Tenant/Idempotency) parses the W3C version-00 `traceparent` header on every inbound request:

- Present and well-formed → adopt `trace_id`, originate a fresh server `span_id` as a child of the inbound `parent_span_id`.
- Absent or malformed → originate a fresh `trace_id` + `span_id`. Increment `springai_ascend_traceparent_invalid_total{posture}` if malformed.

MDC is populated with `trace_id`, `span_id`, `parent_span_id` for the request scope (cleared in `finally`). On every outbound response (200/4xx/5xx), the filter emits `traceresponse: 00-<trace_id>-<server_span_id>-01` for W3 client SDK correlation (ADR-0063 §1).

OTel Baggage (`tenant.id`, `session.id`, `user.id`) is W2 wire — L1.x keeps `X-Tenant-Id` header mandatory per §4 #37.

## 7. Standard log fields (Logback JSON encoder)

```json
{
  "ts":             "2026-05-14T...",
  "level":          "INFO|WARN|ERROR",
  "service":        "agent-platform",
  "posture":        "research",
  "tenant_id":      "<uuid|null>",
  "run_id":         "<uuid|null>",
  "trace_id":       "<32 hex|null>",
  "span_id":        "<16 hex|null>",
  "parent_span_id": "<16 hex|null>",
  "msg":            "...",
  "kv":             { "...": "structured fields" }
}
```

MDC populates `tenant_id` (existing — `TenantContextFilter`), `trace_id` + `span_id` + `parent_span_id` (L1.x — `TraceExtractFilter`), and `run_id` (L1.x — `RunController` inline, after the Run is materialised; ADR-0061 §4 records the rationale for inline vs filter placement).

`session_id` is NOT in MDC at L1.x (Rule 2 — minimise MDC carriers); it is carried on the persisted Run row and propagated via baggage from W2.

## 8. Required metrics by module

| Metric | Owner module | Wave |
|---|---|---|
| `springai_ascend_trace_originated_total{posture,source}` | `agent-platform/observability` | **L1.x** |
| `springai_ascend_traceparent_invalid_total{posture}` | `agent-platform/observability` | **L1.x** |
| `agent_run_started_total` | `agent-runtime/runs` | W2 |
| `agent_run_terminal_total{outcome}` | `agent-runtime/runs` | W2 |
| `agent_run_cost_usd_total{tenant_id,model}` | `agent-runtime/llm` | W2 |
| `agent_runs_pending` (gauge) | `agent-runtime/runs` | W2 |
| `outbox_unsent_age_seconds_max` (gauge) | `agent-runtime/outbox` | W2 |
| `*_fallback_total` (per fallback branch) | various | W2 (LlmRouter), W3 (ActionGuard / OPA) |
| `app_secret_rotation_total{secret}` | `agent-platform/bootstrap` | W2 |
| `cardinality_budget_exceeded_total{metric}` | `agent-runtime/observability` | W2 |
| `llm_prompt_cache_hit_total{provider,model}` | `agent-runtime/llm` | W2 |
| `actionguard_decision_total{outcome}` | `agent-runtime/action` | W3 |
| `eval_pass_rate{suite}` | `agent-eval` | W4 |

## 9. Dashboards (W2)

`ops/grafana-dashboards/`:

- `runs.json` — run volume, terminal outcome breakdown, latency p50/p95/p99.
- `cost.json` — cost per tenant per model.
- `outbox.json` — pending count, lag, DLQ.
- `actionguard.json` — decision breakdown, OPA latency.
- `eval.json` — eval pass-rate trends.

## 10. Tests

| Test | Layer | Ships | Asserts |
|---|---|---|---|
| `TelemetryVerticalArchTest` | ArchUnit | L1.x | §4 #53 — no class outside hook/observability packages writes to a TraceWriter sink |
| `RunContextIdentityAccessorsTest` | ArchUnit | L1.x | §4 #54 — RunContext exposes traceId/spanId/sessionId/traceContext |
| `RunTraceSessionConsistencyIT` | Integration | L1.x | §4 #54 — Run.traceId 32-hex when populated; child inherits session |
| `TraceExtractFilterIT` | Integration | L1.x | §4 #55 — inbound traceparent honoured; outbound traceresponse emitted |
| `LogFieldShapeIT` | Integration | L1.x | MDC carries tenant_id + trace_id + span_id + run_id |
| `LlmGatewayHookChainOnlyTest` | ArchUnit | L1.x | §4 #56 — no LLM call outside HookChain (vacuous at L1.x; arms for W2) |
| `SpanTenantAttributeRequiredTest` | ArchUnit | L1.x | §4 #57 — emission sites declare tenant.id (vacuous at L1.x; arms for W2) |
| `PostureBootPiiHookPresenceContractIT` | Integration | L1.x | §4 #58 — boot-gate contract for PiiRedactionHook in research/prod |
| `McpReplaySurfaceArchTest` | ArchUnit | L1.x | §4 #59 — no @RestController in web/replay, web/trace, web/session |
| `GenerationSpanSchemaIT` | Integration | W2 | §4 #56 — actual span emission carries gen_ai.* + langfuse.* |
| `McpTraceLookupTenantIsolationIT` | Integration | W2 | §4 #57 — MCP replay 403 on tenant mismatch |
| `PiiSpanAttributeIT` | Integration | W2 | §4 #58 — synthetic PII fingerprint NOT in exported spans |
| `CardinalityBudgetIT` | Integration | W2 | exceeding budget logs warning + drops to bucket |
| `SampleRateIT` (per posture) | Integration | W2 | trace sample rate matches posture |

## 11. Open issues / deferred

- OTel SDK + `opentelemetry-spring-boot-starter` dep: W2.
- `Score` entity (Langfuse-style eval/feedback): W3.
- `springai-ascend-client` (Java/Kotlin, then JS/Python): W3 / W3+.
- Tail-based sampling on errors (Tempo collector config): W4.
- Cost-per-prompt-template metric: W4+.
- Per-tenant alerting (alertmanager rules): W4+.
- MCP replay tools (`get_run_trace`, `list_runs`, `get_llm_call`, `list_sessions`): W4 (ADR-0017).

## 12. References

- `ARCHITECTURE.md §0.5.3` (Telemetry Vertical position)
- `ARCHITECTURE.md §4 #53–#59` (binding constraints)
- ADR-0061 — Telemetry Vertical Layer
- ADR-0062 — Trace ↔ Run ↔ Session N:M identity
- ADR-0063 — Client SDK observability contract (W3)
- ADR-0017 — Dev-time trace replay (MCP, no Admin UI)
- ADR-0009 — Micrometer observability foundation
- `docs/governance/enforcers.yaml` rows E38–E46
