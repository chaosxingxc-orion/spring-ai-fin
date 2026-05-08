# observability — Spine + Metrics + Traces (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) · L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`observability/` is the **cross-cutting telemetry spine** of spring-ai-fin: metrics, traces, lifecycle events, fallback records, and redaction primitives. Every other subsystem emits through it; no subsystem consumes from another directly. Outside test paths, no module owns its own counter, log redaction primitive, or trace-context primitive.

> **Boundary with `audit/`** (per `../audit/` AD-9): mandatory regulatory evidence (`AuditClass.SECURITY_EVENT / REGULATORY_AUDIT / PII_ACCESS / FINANCIAL_ACTION`), WORM anchoring, hash-chain tamper-evidence, and PII reveal protocols **live in `agent-runtime/audit/`**, not here. Observability spine emitters are best-effort and **never raise on the request path**; audit class writers are mandatory and **must raise on failure**. Crossing the two would re-introduce the silent-failure pattern the security review flagged in P0-8.

Owns:

- **`RunEventEmitter`** — 12 typed run-lifecycle events
- **`SpineEmitter`** — 14 layer probes emitting at every cross-subsystem boundary (LLM call, tool call, heartbeat renewed, run manager, scheduler bridge, HTTP transport, gRPC sidecar, etc.)
- **`SpineEmitterFailureCounter`** — per-emit-failure counter exposed for readiness gating (see §5)
- **`FallbackRecorder`** — Rule 7 four-prong fallback recording (Countable + Attributable + Inspectable + Gate-asserted)
- **`MetricsRegistry`** — Spring Boot Actuator + Micrometer + (optional) Phoenix exporter
- **`TraceContextManager`** — OpenTelemetry trace propagation (W3C `traceparent` ingestion)
- **`Redactor`** — primitives for redacting PII, secrets, prompts, and tool arguments before any value reaches a metric label, log record, or trace attribute
- **`ObservabilityPrivacyPolicy`** — declarative policy + CI gate for what may and may not appear in observability surfaces (see §6)
- **`CardinalityBudget`** — per-metric cardinality budget enforcement against `docs/observability/cardinality-policy.md` (see §7)

Does NOT own:

- Durable run state (delegated to `../server/EventStore`)
- Event streaming to clients (delegated to `agent-platform/api/RunsExtendedController` SSE)
- Trace lake storage (delegated to deferred Tier-2 Phoenix or ClickHouse)
- **Audit, WORM anchoring, hash-chain tamper-evidence, PII reveal protocol** (delegated to `../audit/`)

---

## 2. Why one spine, not subsystem-local metrics

v5.0's emergent metrics declarations would have produced 30+ collectors with subtle differences. Hi-agent's W35 audit found 11 orphan metrics (declarations with no producer) in its predecessor; the lesson: **metric declaration must be tied to producer at landing time**.

v6.0 design: `observability/` is the single-construction-path for metrics, traces, and redaction. Subsystems call into `RunEventEmitter` / `SpineEmitter` / `FallbackRecorder` / `Redactor`. Adding a new metric requires:

1. Adding a constant to `MetricsRegistry.METRIC_DEFS`
2. Adding the producer call site (must exist at landing time)
3. Adding `MetricsCatalogTest` row asserting the metric is consumed downstream
4. If the metric carries a `tenant_id` raw label, adding an entry to `docs/observability/cardinality-policy.md` (see §7)

CI fails on declaration without producer.

---

## 3. RunEventEmitter — 12 typed events

```java
@Component
public class RunEventEmitter {
    private final EventStore eventStore;
    private final MeterRegistry meterRegistry;

    public void recordRunSubmitted(RunContext ctx) { ... }
    public void recordRunStarted(RunContext ctx) { ... }
    public void recordRunCompleted(RunContext ctx, Duration d) { ... }
    public void recordRunFailed(RunContext ctx, String reason) { ... }
    public void recordRunCancelled(RunContext ctx, String reason) { ... }
    public void recordRunResumed(RunContext ctx, String fromStage) { ... }
    public void recordStageStarted(RunContext ctx, String stageId) { ... }
    public void recordStageCompleted(RunContext ctx, String stageId, Duration d) { ... }
    public void recordStageFailed(RunContext ctx, String stageId, String reason) { ... }
    public void recordArtifactCreated(RunContext ctx, String artifactType) { ... }
    public void recordExperimentPosted(RunContext ctx, String experimentId) { ... }
    public void recordFeedbackSubmitted(RunContext ctx) { ... }
}
```

Each method:

1. Writes to `EventStore` (durable; survives restart)
2. Increments Micrometer counter (`springaifin_run_*`)
3. Adds OpenTelemetry span attribute
4. Surface via `/v1/runs/{id}/events` SSE

---

## 4. SpineEmitter — 14 layer probes

Cross-subsystem layer probes. Each emit is **wrapped in try/catch + log-only fallback on the request path** — spine emitters NEVER raise into the caller. Reason: an observability bug must not crash the request path.

But: failures are not silent. They are **counted and exposed for readiness gating** (§5).

```java
@Component
public class SpineEmitter {
    private final MeterRegistry meterRegistry;
    private final SpineEmitterFailureCounter failureCounter;

    public void emitLlmCall(RunContext ctx, String provider, String model, Duration latency, int tokens) {
        try {
            meterRegistry.counter("springaifin_spine_llm_calls_total",
                "provider", provider, "model", model, "tenant_bucket", tenantBucket(ctx))
                .increment();
            log.info("spine: llm_call provider={} model={} latency_ms={} tokens={} run_id={} tenant_id={}",
                provider, model, latency.toMillis(), tokens, ctx.runId(), ctx.tenantId());
        } catch (Exception e) {
            // never raise, but count + log so readiness can degrade.
            log.error("spine emitter failed (layer=llm_call)", e);
            failureCounter.record("llm_call", classifyReason(e));
        }
    }

    // emitToolCall, emitHeartbeatRenewed, emitRunManagerCall, emitSchedulerSubmit,
    // emitHttpRequest, emitGrpcSidecarCall, emitOutboxRelay, emitMemoryWrite,
    // emitKnowledgeRetrieval, emitSkillRegistration, emitGateOpened, emitGateDecided,
    // emitTenantContext (the 14 layers); each calls failureCounter on exception.
}
```

The "spine emitters never raise on request path" decision (mirrors hi-agent's ADR-OBS-3) is annotated `// rule7-exempt: spine emitters must never block execution path  // expiry_wave: permanent` because Rule 7 normally requires fail-closed; spine is the exception. **Mandatory regulatory evidence is NOT spine emitter territory** — that lives in `../audit/` and DOES raise.

---

## 5. SpineEmitterFailureCounter + readiness gating

Per remediation §9: keep the request path non-throwing, but make failures **observable and gate-aware**.

```java
@Component
public class SpineEmitterFailureCounter {
    private final MeterRegistry meterRegistry;

    public void record(String layer, String reason) {
        meterRegistry.counter("springaifin_spine_emit_failures_total",
            "layer", layer, "reason", reason).increment();
    }
}
```

Readiness rule (consumed by Spring Boot Actuator `HealthIndicator`):

```text
if (sum(rate(springaifin_spine_emit_failures_total[5m]) by (layer)) > threshold)
  during a contiguous gate window:
    /actuator/health/readiness => DEGRADED
    operator-shape gate         => FAIL
```

Default threshold under research/prod: 0 failures during the gate window. Threshold under dev: configurable; default 5 / 5min.

The operator-shape gate asserts `springaifin_spine_emit_failures_total == 0` over N≥3 sequential runs on the happy path. A single emitter failure on the happy path blocks ship.

---

## 6. ObservabilityPrivacyPolicy

Observability surfaces (metrics, logs, traces, prompt cache keys, span attributes) MUST NOT carry the following:

| Forbidden value | Why | Where it would otherwise leak |
|---|---|---|
| Raw prompt text or any `PromptSegment.content` | Prompt is privileged input that may contain PII, account ids, customer instructions | `springaifin_llm_request_*` metric labels; `OTel span.attributes("prompt", ...)`; `log.info("prompt={}", ...)` |
| Raw retrieved-document text from RAG | Retrieved chunks may carry PII regardless of prompt safety | Trace span attributes on retrieval calls |
| PII tokens (account ids, names, emails, government ids) before redaction | Direct PII reveal | Any metric label using a customer identifier; `tenant_id` is permitted as an opaque tenant key under §7's policy, but PII fields are never permitted |
| Tool arguments in full | Tool args may contain PII or financial values | `springaifin_spine_tool_calls_total` labels; trace span attributes |
| Tokens, secrets, credentials, headers | Secret leak | `Authorization` header logging; provider API key in error messages |
| Customer financial values (raw amount) without bucketing or explicit approval | Unbucketed financial labels are direct customer signal | `springaifin_*_amount{value=...}` patterns are forbidden; bucketed `*_amount_bucket` is permitted with reviewer approval |

Enforcement:

- `Redactor.classifyAndRedact(value)` is the only sanctioned path to derive a label / log / trace value from data that *might* be sensitive. It computes a stable hash + class tag (e.g., `pii:hash:abc123` or `redacted:reason=tool_args`).
- Prompt cache keys store **section-classified** content only: see `../llm/` §6.3.
- `ObservabilityPrivacyPolicyTest` is a CI gate composed of:
  - `NoRawPromptInLogsTest` — grep + bytecode scan asserts no log statement passes a raw prompt to the formatter
  - `NoPiiInMetricLabelsTest` — reflective walk over metric registrations asserts label values are typed and the typed values reject PII patterns
  - `NoRawToolArgsInTracesTest` — tracer spy in test profile asserts span attributes derived from tool arguments go through `Redactor`
  - `PromptCacheClassificationTest` — runs against the prompt cache and asserts every cache key path invoked `Redactor.classifyAndRedact` for any user-attributed input

A test failure in this suite blocks the operator-shape gate.

---

## 7. Cardinality budget for tenant_id labels

Per remediation §9.4: raw `tenant_id` metric labels require an explicit cardinality budget.

The default behaviour for a `tenant_id`-tagged metric is one of:

- `tenant_bucket` — eight-bucket hash of `tenant_id`
- `tenant_class` — typed class (`internal`, `pilot`, `enterprise`) supplied at boot
- the label is omitted from the metric and the value lives in the trace span attribute instead

A metric may use **raw** `tenant_id` only when listed in `docs/observability/cardinality-policy.md` with the five required fields (metric name, budget, retention, recording rule, owner). The CI gate `CardinalityBudgetIT` walks `MetricsRegistry.METRIC_DEFS` and fails the build when a `tenant_id`-labelled metric is missing from the policy.

The policy is reviewed at every wave's operator-shape gate; entries that exceed budget at gate time are downgraded to bucketed labels and removed.

---

## 8. FallbackRecorder — Rule 7 four-prong

```java
@Component
public class FallbackRecorder {
    public void recordFallback(RunContext ctx, String fallbackType, Throwable cause) {
        // 1. Countable
        meterRegistry.counter("springaifin_" + fallbackType + "_fallback_total",
            "tenant_bucket", tenantBucket(ctx), "reason", classifyReason(cause))
            .increment();

        // 2. Attributable
        log.warn("fallback: type={} reason={} run_id={} tenant_id={} cause={}",
            fallbackType, classifyReason(cause), ctx.runId(), ctx.tenantId(),
            redactor.classifyAndRedact(cause));   // §6: never log raw cause that may contain PII

        // 3. Inspectable
        ctx.runMetadata().fallbackEvents().add(new FallbackEvent(
            fallbackType, classifyReason(cause), Instant.now(), redactor.classifyAndRedact(cause)));

        // 4. Gate-asserted: operator-shape gate asserts *_fallback_total == 0
        //    (no code-side check; gate enforces externally)
    }
}
```

Every silent-degradation path in the platform calls `fallbacks.recordFallback(...)`. CI gate `Rule7CompletenessTest` walks code for `// fallback:` comments and asserts each has a paired `recordFallback` call.

---

## 9. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: One observability spine, not subsystem-local** | Single MetricsRegistry; single RunEventEmitter; single SpineEmitter | Avoids 30+ declarations with subtle drift; metrics-catalog enforced by CI |
| **AD-2: 12 typed run events (mirrors hi-agent)** | Inherit hi-agent's RunEventEmitter shape | Battle-tested over 32 waves |
| **AD-3: Spine emitters never raise on request path** | wrap each emit in try/catch + log + counter | Observability bug must not crash request path; annotated `rule7-exempt` |
| **AD-4: Rule 7 four-prong codified in FallbackRecorder** | every fallback path calls `recordFallback`; CI gate `Rule7CompletenessTest` | Hi-agent's pre-W12 silent-fallback class of defects; gate prevents regression |
| **AD-5: tenant_id label requires cardinality budget** | Default is `tenant_bucket` or trace span attribute; raw `tenant_id` requires entry in `docs/observability/cardinality-policy.md` | Remediation §9.4; uncontrolled cardinality produces production failure modes at scale |
| **AD-6: OpenTelemetry traces alongside Micrometer counters** | OTel for trace context propagation; Micrometer for metrics | OTel-Micrometer integration is mature; Spring Boot 3.x first-class |
| **AD-7: Phoenix as default trace lake (not Langfuse)** | Phoenix is Apache 2.0; Langfuse is AGPL | License risk per L0 D-15 |
| **AD-8: Audit broken out into `agent-runtime/audit/`** | `observability/` no longer owns AuditLogger, WormAnchor, hash chain, or PII reveal protocol | The security boundary between best-effort telemetry (never raises) and mandatory regulatory evidence (must raise) must be sharp. Addresses P0-8 (status: design_accepted). |
| **AD-9: ObservabilityPrivacyPolicy is a CI gate** | Forbidden categories defined in §6; named tests block the gate; no allowlist | Closes leak channels (logs, metrics, traces, prompt cache keys) for prompts, PII, secrets, raw tool args, customer financial values |
| **AD-10: SpineEmitterFailureCounter + readiness rule** | Failures counted and gate-asserted to zero on happy path; readiness goes DEGRADED above threshold | Remediation §9.1-§9.3; keeps request path non-throwing while making failures observable |

---

## 10. Cross-cutting hooks

| Concern | Implementation |
|---|---|
| **Posture (Rule 11)** | `dev` permits in-memory metrics; `research`/`prod` require Phoenix exporter and trace lake reachable |
| **Spine (Rule 11)** | every event carries `tenant_id, run_id, parent_run_id, attempt_id, capability_name` per applicability — but `tenant_id` label use is governed by §7 |
| **Resilience (Rule 7)** | spine emitters wrapped in suppress + counter; recordFallback is the four-prong codification |
| **Operator-shape (Rule 8)** | every release HEAD passes `gate/check_observability_spine_real.sh` (5 of 14 layers must show real provenance) AND `ObservabilityPrivacyPolicyTest` AND `springaifin_spine_emit_failures_total == 0` |
| **License audit (D-15)** | Langfuse + Loki rejected; Phoenix + VictoriaLogs adopted |

---

## 11. Quality

| Attribute | Target | Verification |
|---|---|---|
| All 12 RunEventEmitter methods produce metrics | 100% | `MetricsCatalogTest` |
| All 14 SpineEmitter layers covered | 100% | `SpineCoverageTest` |
| Spine emitter failures counted, not silent | every catch invokes `failureCounter.record` | `SpineEmitterFailureCounterIT` |
| Spine emitter failure rate is zero on happy path | gate-asserted | `gate/run_operator_shape_smoke.*` |
| Rule 7 four-prong on every fallback | enforced by CI | `Rule7CompletenessTest` |
| Cardinality budget enforced | every `tenant_id`-labelled metric has a policy entry | `CardinalityBudgetIT` |
| No raw prompt in logs / traces / metric labels | enforced by CI | `NoRawPromptInLogsTest`, `NoRawToolArgsInTracesTest` |
| No PII in metric labels | enforced by CI | `NoPiiInMetricLabelsTest` |
| Prompt cache uses section-classified content only | enforced by CI | `PromptCacheClassificationTest` |

---

## 12. Risks

- **Cardinality budget gating becomes burdensome**: mitigation — bucketed default; only raw `tenant_id` requires policy entry
- **Phoenix is younger than Langfuse**: feature gaps possible; if a critical Langfuse feature missing, may need commercial license escape
- **OpenTelemetry version churn**: track upstream
- **Spine emitter performance**: profile shows < 5µs per emit; should not be hot-path concern
- **Privacy policy bypass via new emit path**: every new metric / span / log statement must route through `Redactor` for any value derived from request data; PR review enforces
- **Readiness flapping** when spine emitter fails sporadically: rate-window evaluation (`rate[5m]`) plus gate window prevents single-event flap

---

## 13. References

- Hi-agent prior art: `D:/chao_workspace/hi-agent/hi_agent/observability/ARCHITECTURE.md` — same 12+14 split, same Rule 7 pattern
- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Audit (mandatory regulatory evidence): [`../audit/ARCHITECTURE.md`](../audit/ARCHITECTURE.md)
- Cardinality policy: [`../../docs/observability/cardinality-policy.md`](../../docs/observability/cardinality-policy.md)
- LLM (prompt-section, taint, cache classification): [`../llm/ARCHITECTURE.md`](../llm/ARCHITECTURE.md)
- Phoenix (Apache 2.0): https://github.com/Arize-ai/phoenix
- OpenTelemetry: https://opentelemetry.io/
- Micrometer: https://micrometer.io/
- Systematic-architecture-improvement-plan: [`../../docs/systematic-architecture-improvement-plan-2026-05-07.en.md`](../../docs/systematic-architecture-improvement-plan-2026-05-07.en.md) §4.7
- Systematic-architecture-remediation-plan: [`../../docs/systematic-architecture-remediation-plan-2026-05-08.en.md`](../../docs/systematic-architecture-remediation-plan-2026-05-08.en.md) §9
