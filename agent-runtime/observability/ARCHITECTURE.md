# agent-runtime/observability -- L2 architecture (2026-05-08 refresh)

> Owner: runtime | Wave: W2 | Maturity: L0 | Reads: -- | Writes: metrics + traces + logs
> Last refreshed: 2026-05-08

## 1. Purpose

Custom metrics + span propagation + JSON logs. Standardizes naming and
cardinality so dashboards and alerts work uniformly across modules.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Micrometer | (BOM) | metrics SDK |
| Prometheus client | (BOM) | exposition |
| OpenTelemetry Java agent | 2.x | auto-instrumented traces |
| Logback | (BOM) | logging |
| logstash-logback-encoder | 8.x | JSON logs |
| Loki | (compose) | log store |
| Grafana | (compose) | dashboards |
| Tempo (optional) | (compose) | traces store |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `observability/MetricsConfig.java` | common tags | 60 |
| `observability/SpanCustomizer.java` | tenant + run id propagation | 80 |
| `observability/LogbackConfig.xml` | JSON encoder + appenders | 60 |
| `observability/CardinalityGuard.java` | reject high-cardinality labels | 100 |
| `ops/grafana/dashboards/*.json` | runs, llm cost, outbox lag | 200 |

## 4. Public contract

Standard label set on every metric: `service`, `tenant_bucket`,
`posture`. `tenant_id` itself is **not** a label by default; it goes
through `CardinalityGuard` which buckets to `<= 50` distinct values
(hash mod) unless an explicit allowlist row is present in
`docs/cross-cutting/observability-policy.md`.

Span attributes: `tenant.id`, `run.id`, `agent.capability`,
`llm.provider`, `llm.model`. Attributes follow OpenTelemetry semconv.

Log fields: `ts`, `level`, `service`, `tenant_id`, `run_id`,
`trace_id`, `span_id`, `msg`, `kv`.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Trace sample rate | 100% | 10% | 1% |
| Log level | DEBUG | INFO | INFO |
| Cardinality budget per metric | unbounded | 50 | 50 |
| Tenant-id raw label allowed | yes | only via allowlist | only via allowlist |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `CardinalityBudgetIT` | Integration | exceeding budget logs warning + drops to bucket |
| `TraceTenantPropagationIT` | Integration | child span has tenant.id attribute |
| `LogFieldShapeIT` | Integration | every log line has required fields |
| `MetricNamingIT` | Integration | every custom metric matches naming policy |
| `EmitterFailureCounterIT` | Integration | sink outage increments `*_emitter_failure_total` |

## 7. Out of scope

- Domain-specific dashboards: lives next to the dashboard JSON files.
- Alerting rules: Prometheus alert files + Alertmanager are
  ops-defined, not in this module's source.

## 8. Wave landing

W2: metrics + auto-traces + JSON logs. W3: cardinality guard + Grafana
dashboards. W4: alert rules + emitter-failure counter wired to
readiness.

## 9. Risks

- Cardinality blowup if a developer labels by `tenant_id` directly:
  prevented by `CardinalityGuard` + CI lint that scans for
  `Tag.of("tenant_id", ...)` outside the allowlist file.
- OTel agent version drift: pinned via BOM; nightly upgrade test.
- Log volume in prod: Loki retention tiered; high-volume tenants
  documented.
