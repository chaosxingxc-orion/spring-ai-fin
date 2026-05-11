> ARCHIVED 2026-05-12. Pre-refresh design rationale; not active spec. Current state: see docs/STATE.md.

# Failure Modes Catalog -- cross-cutting policy

> Owner: architecture | Wave: W0..W4 (per-mode owner wave varies) | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

For every active L1 / L2 module, lists the credible failure modes,
how the design detects them, how it mitigates them, and what the
observable outcome is. Replaces module-by-module Risks sections that
focus on architectural risks; this catalog focuses on **runtime
failure modes** the design must handle.

Format per row: `Mode | Detect | Mitigation | Observable outcome`.

## 2. agent-platform/web

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Tomcat thread starvation | thread-pool gauge | virtual threads + HikariCP sized to fan-out | 503 + circuit breaker open (Resilience4j) |
| OOM on large body | request-size lint | Spring Boot multipart caps; per-endpoint maxPayload | 413 Payload Too Large |
| Unhandled exception | global handler | `GlobalExceptionHandler` -> RFC-7807 5xx | 500 sanitized body (research/prod) |
| OpenAPI generation error | startup test | `OpenApiContractIT` fails | startup blocks |

## 3. agent-platform/auth

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| JWKS endpoint down | HTTP error in JWKS fetch | cached JWKS within TTL | 401 only when both fresh fetch fails AND TTL expired |
| JWT alg manipulation (HS256 forced) | algorithm-allowlist mismatch | explicit allowlist; not header-driven | 401 + AUTH_ALG_REJECTED |
| Clock skew | exp/nbf check fails | 30s tolerance; metric increments | 401 + AUTH_TOKEN_EXPIRED |
| Stolen token replay | replayed `jti` | idempotency dedup on `jti` (W1+) | 409 IDEM_KEY_CONFLICT |

## 4. agent-platform/tenant

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Cross-tenant query | RLS predicate evaluation | RLS policy filters rows | empty result; RUN_NOT_FOUND if expected |
| GUC empty at tx start | trigger fires | `BEFORE INSERT/UPDATE` trigger raises | 5xx (TENANT_GUC_EMPTY) -- bug not data leak |
| Tenant suspended mid-request | check on read of `tenants.is_active` | filter at TenantBinder | 403 TENANT_SUSPENDED |
| Tenant impersonation header in research/prod | filter rejection | `auth/` filter rejects | 401 / 403 |

## 5. agent-platform/idempotency

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Duplicate POST with same key | UNIQUE INDEX violation | retrieve cached response; emit `Idempotent-Replayed` | 200 with original body + header |
| Concurrent POST with same key (in-flight) | row-level lock contention | second request waits + 409 | 409 IDEM_KEY_CONFLICT |
| Response body too large to cache | size check | skip caching; re-execute on retry | 200 first; second call may produce different result -- documented |
| TTL cleanup lag | `outbox_unsent_age_seconds_max` analog | `pg_cron` daily job; alert if backlog > 24h | data growth alarm |

## 6. agent-platform/bootstrap

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Required env missing in research/prod | `PostureBootGuard` | fail-closed exit 1 + structured log | container restart loop until env supplied |
| Boot timeout exceeded | startup probe | configurable; default 90s | K8s marks pod unhealthy |
| Config server unreachable on boot | config-fetch retry | retry with backoff; fail-closed if exceeded | startup fails |

## 7. agent-platform/config

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Tenant override conflicts with default | type-check at load | `ConfigKey<T>` registry rejects bad types | startup fails OR 5xx if hot-loaded |
| Cache staleness across replicas | TTL-driven refresh | 60s TTL + explicit invalidate API | up to 60s drift -- documented |
| Cloud Config server outage | health probe | use last-known-good cache + alert | degraded but operational |

## 8. agent-platform/contracts

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| OpenAPI snapshot drift | `OpenApiContractIT` | fail CI on diff | merge blocked |
| Validation on input fails | `@Valid` violation | `MethodArgumentNotValidException` -> 400 | RFC-7807 with field-level errors |
| Forward-incompat field added (extra fields in body) | accept policy | tolerant parsing; ignore unknown | 200 + ignored |

## 9. agent-runtime/run

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| LLM call exceeds per-step timeout | activity timeout (Temporal) or sync timeout | timeout exception; cancel run; refund partial budget | 504 LLM_PROVIDER_TIMEOUT (sync); workflow continues with retry (Temporal) |
| Provider returns 5xx | response status | circuit breaker opens after N failures | 502 LLM_PROVIDER_UNAVAILABLE; retry policy decides |
| Mid-run JVM crash | absent heartbeat | reaper marks RUNNING > timeout as FAILED; Temporal resumes (W4) | 5xx until reaper; Temporal: workflow recovers |
| Cancel signal arrives after terminal | state check | cancel ignored if status != RUNNING | 200 (idempotent); status unchanged |
| Parallel runs over per-tenant cap | counter check | reject with 429 BUDGET_RUN_LIMIT | 429 |

## 10. agent-runtime/llm

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Provider key invalid | 401 from provider | rotate via Vault watcher; alert | LLM_PROVIDER_UNAVAILABLE |
| Provider quota exceeded | 429 from provider | escalate to next tier (cheaper provider); else 429 | 429 LLM_QUOTA_EXCEEDED |
| Token-budget exceeded for tenant | `BudgetGuard` | reject pre-call | 429 BUDGET_TENANT_EXHAUSTED |
| Cost-tier escalation triggered | rule fire | log + metric; allow but mark | success + cost above median |
| Prompt-cache miss after assumed hit | cache-stat metric | accept; alert if hit-rate drops | success but slower |

## 11. agent-runtime/tool

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Tool not registered for tenant | registry lookup | reject pre-dispatch | 403 TOOL_NOT_REGISTERED |
| Tool version not found | version match | fall back to latest enabled OR reject | 422 TOOL_VERSION_NOT_FOUND |
| MCP out-of-process tool unresponsive | Resilience4j timeout | circuit breaker per tool | 504 + audit row |
| HTTP allowlist host not permitted | host check | reject pre-call | 403 TOOL_HOST_NOT_ALLOWED |
| Tool quota exceeded for tenant | counter | reject | 429 |

## 12. agent-runtime/action (5-stage chain)

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| OPA outage | OPA HTTP error | fail-closed deny in research/prod | 403 + audit row |
| Audit row write fails | DB error during Witness | retry once; if persistent, refuse to ack the action | 5xx (consistency over throughput) |
| Outbox write fails in same tx as side effect | DB error | tx rolls back; side effect not committed | 5xx; client retries with same idempotency key |
| Capability allowlist denied | Authorize stage check | reject before Execute | 403 |
| Stage exception | per-stage try/catch | dispatch to GlobalExceptionHandler | 5xx + audit row |

## 13. agent-runtime/memory

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| L0 cache eviction loses fact | scope-aware re-fetch | re-read from L1 on miss | success but slower |
| L1 retention TTL deletes recent fact | retention check | per-tenant TTL override | data loss within configured window |
| L2 embedding-model mismatch | row-level (provider, model) check | reject retrieval | 422 MEM_DIM_MISMATCH |
| Memory quota exceeded for tenant | counter | reject write | 429 MEM_QUOTA_EXCEEDED |
| pgvector index DoS via mass insert | per-tenant rate limit | throttle; alert | 429 |

## 14. agent-runtime/outbox

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Sink unreachable | Resilience4j | retry per row; max-retries -> DLQ | events accumulate then dead-letter |
| Multiple publishers race | `FOR UPDATE SKIP LOCKED` | each publisher gets distinct rows | no duplicate-emit |
| Per-tenant ordering broken | scheduled-batch ordering | ORDER BY (tenant_id, created_at, id) within batch | preserved within batch |
| DLQ grows unbounded | DLQ count metric | alert; manual replay procedure | tracked, not lost |
| Crash mid-batch | uncommitted `sent_at` rolls back | next tick reprocesses unsent rows | at-least-once |

## 15. agent-runtime/temporal

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Worker dies mid-workflow | Temporal heartbeat | activity retried on healthy worker | workflow continues |
| Cluster failover | client retry | client connects to new frontend | latency spike then recovers |
| Workflow non-determinism in code | replay-test failure (linter) | workflow lint in CI; replay tests pass | merge blocked |
| Activity timeout | Temporal activity-timeout | retry with backoff per RetryOptions | eventual success or terminal failure |
| Signal lost (cancel before workflow start) | start-with-signal pattern | use `WorkflowClient.signalWithStart` | cancel applied at start |
| Schema migration during in-flight workflow | versioning marker | use Temporal versioning API | continues with old code path |

## 16. agent-runtime/observability

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Metric cardinality explosion | `cardinality_budget_exceeded_total` counter | bucket via `CardinalityGuard` | alarm + bucketed labels |
| Loki backpressure | log-drop metric | rate-limit at Logback | structured drop log |
| Tempo drop | OTel trace-drop metric | head-based sampling | partial trace coverage |
| Span propagation broken | span-context check | force MDC + OTel context; integration test | trace gaps -- detected |

## 17. agent-eval (W4)

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Eval suite over budget | per-run cost cap | abort suite; report partial | partial fail not total fail |
| Provider non-determinism | flake retry budget | retry up to N; mark flaky | result has flake_rate metric |
| Baseline file conflict in PR | snapshot test | manual review required | merge requires baseline rationale |

## 18. Cross-cutting

| Mode | Detect | Mitigation | Outcome |
|---|---|---|---|
| Vault outage | secret-fetch error | cached secrets continue; readiness degrades | service degraded but operational |
| Posture mismatch (env vs code expectation) | `PostureBootGuard` at startup | fail-closed | startup fails |
| Date / clock skew on host | OTel + Postgres comparison | NTP enforced via base image | metric anomaly alerts |
| Disk full on Postgres | DB error | alert; readiness probe fails | rejects writes; service degraded |
| Disk full on app pod (logs) | filesystem-check + alert | log rotation + Loki backpressure | logs drop; service operational |

## 19. Aggregate observability

Every failure mode above maps to one of:

- A counter metric (`*_failure_total`, `*_fallback_total`, etc.).
- A WARNING+ structured log (with run_id + tenant_id + trace_id).
- An entry in `fallback_events` JSONB on the run row (terminal-time
  visibility per Rule 7).

**Per Rule 7 (resilience must not mask signals)**: every fallback path
above MUST emit at least the metric + log + run-row entry. The gate
checks for fallback paths without these signals (W3 ActionGuard rule
+ W4 broader scan).

## 20. Iteration cadence

- Re-run the catalog when a new module lands (W0..W4).
- Re-run after every incident (post-mortem additions).
- Cross-link tested modes to test names in the relevant L2 doc.

## 21. References

- `docs/cross-cutting/non-functional-requirements.md` sec-2.3 (availability)
- `docs/cross-cutting/threat-model.md` (security failure modes)
- `docs/cross-cutting/observability-policy.md` (metric naming)
- `docs/plans/engineering-plan-W0-W4.md` per-wave Risks subsections
