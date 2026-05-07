# observability — Spine + Metrics + Traces (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) · L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`observability/` is the **cross-cutting spine** of spring-ai-fin. Every other subsystem emits through it; no subsystem consumes from another directly. Outside test paths, no module owns its own counter, log redaction, or trace-context primitive.

Owns:

- **`RunEventEmitter`** — 12 typed run-lifecycle events (`recordRunSubmitted`, `recordRunStarted`, `recordRunCompleted`, `recordRunFailed`, `recordRunCancelled`, `recordRunResumed`, `recordStageStarted`, `recordStageCompleted`, `recordStageFailed`, `recordArtifactCreated`, `recordExperimentPosted`, `recordFeedbackSubmitted`)
- **`SpineEmitter`** — 14 layer probes emitting at every cross-subsystem boundary (LLM call, tool call, heartbeat renewed, run manager, scheduler bridge, HTTP transport, gRPC sidecar, etc.)
- **`FallbackRecorder`** — Rule 7 four-prong fallback recording (Countable + Attributable + Inspectable + Gate-asserted)
- **`MetricsRegistry`** — Spring Boot Actuator + Micrometer + (optional) Phoenix exporter
- **`TraceContextManager`** — OpenTelemetry trace propagation (W3C `traceparent` ingestion)
- **`AuditLogger`** — structured audit events with WORM-store sink

Does NOT own:

- Durable run state (delegated to `../server/EventStore`)
- Event streaming to clients (delegated to `agent-platform/api/RunsExtendedController` SSE)
- Trace lake storage (delegated to deferred Tier-2 Phoenix or ClickHouse)

---

## 2. Why one spine, not subsystem-local metrics

v5.0's emergent metrics declarations would have produced 30+ collectors with subtle differences. Hi-agent's W35 audit found 11 orphan metrics (declarations with no producer) in its predecessor; the lesson: **metric declaration must be tied to producer at landing time**.

v6.0 design: `observability/` is the single-construction-path for metrics, traces, audit. Subsystems call into `RunEventEmitter` / `SpineEmitter` / `FallbackRecorder`. Adding a new metric requires:

1. Adding a constant to `MetricsRegistry.METRIC_DEFS`
2. Adding the producer call site (must exist at landing time)
3. Adding `MetricsCatalogTest` row asserting the metric is consumed downstream

CI fails on declaration without producer.

---

## 3. RunEventEmitter — 12 typed events

Mirrors hi-agent exactly (same 12 events; hi-agent's `RunEventEmitter` is battle-tested over 32 waves).

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

Cross-subsystem layer probes. Each emit is **wrapped in try/catch + log-only fallback** — spine emitters NEVER raise. Reason: an observability bug must not crash the request path.

```java
@Component
public class SpineEmitter {
    public void emitLlmCall(RunContext ctx, String provider, String model, Duration latency, int tokens) {
        try {
            meterRegistry.counter("springaifin_spine_llm_calls_total", 
                "provider", provider, "model", model, "tenant_id", ctx.tenantId())
                .increment();
            log.info("spine: llm_call provider={} model={} latency_ms={} tokens={} run_id={} tenant_id={}",
                provider, model, latency.toMillis(), tokens, ctx.runId(), ctx.tenantId());
        } catch (Exception e) {
            log.error("spine emitter failed", e);  // never raise
        }
    }
    
    // emitToolCall, emitHeartbeatRenewed, emitRunManagerCall, emitSchedulerSubmit,
    // emitHttpRequest, emitGrpcSidecarCall, emitOutboxRelay, emitMemoryWrite,
    // emitKnowledgeRetrieval, emitSkillRegistration, emitGateOpened, emitGateDecided,
    // emitTenantContext (the 14 layers)
}
```

The "spine emitters never raise" decision (mirrors hi-agent's ADR-OBS-3) is annotated `// rule7-exempt: spine emitters must never block execution path  // expiry_wave: permanent` because Rule 7 normally requires fail-closed; spine is the exception.

---

## 5. FallbackRecorder — Rule 7 four-prong

```java
@Component
public class FallbackRecorder {
    public void recordFallback(RunContext ctx, String fallbackType, Throwable cause) {
        // 1. Countable
        meterRegistry.counter("springaifin_" + fallbackType + "_fallback_total",
            "tenant_id", ctx.tenantId(), "reason", classifyReason(cause))
            .increment();
        
        // 2. Attributable
        log.warn("fallback: type={} reason={} run_id={} tenant_id={} cause={}",
            fallbackType, classifyReason(cause), ctx.runId(), ctx.tenantId(), cause.toString());
        
        // 3. Inspectable
        ctx.runMetadata().fallbackEvents().add(new FallbackEvent(
            fallbackType, classifyReason(cause), Instant.now(), cause.getMessage()));
        
        // 4. Gate-asserted: operator-shape gate asserts *_fallback_total == 0
        //    (no code-side check; gate enforces externally)
    }
}
```

Every silent-degradation path in the platform calls `fallbacks.recordFallback(...)`. CI gate `Rule7CompletenessTest` walks code for `// fallback:` comments and asserts each has a paired `recordFallback` call.

---

## 6. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: One observability spine, not subsystem-local** | Single MetricsRegistry; single RunEventEmitter; single SpineEmitter | Avoids 30+ declarations with subtle drift; metrics-catalog enforced by CI |
| **AD-2: 12 typed run events (mirrors hi-agent)** | Inherit hi-agent's RunEventEmitter shape | Battle-tested over 32 waves |
| **AD-3: Spine emitters never raise** | wrap each emit in try/catch + log-only fallback | Observability bug must not crash request path; annotated `rule7-exempt` |
| **AD-4: Rule 7 four-prong codified in FallbackRecorder** | every fallback path calls `recordFallback`; CI gate `Rule7CompletenessTest` | Hi-agent's pre-W12 silent-fallback class of defects; gate prevents regression |
| **AD-5: tenant_id raw label, not bucketed** | `springaifin_*_total{tenant_id=...}` | Mirrors hi-agent's W35-corrective C-1; cardinality control is ops-side concern |
| **AD-6: OpenTelemetry traces alongside Micrometer counters** | OTel for trace context propagation; Micrometer for metrics | OTel-Micrometer integration is mature; Spring Boot 3.x first-class |
| **AD-7: Phoenix as default trace lake (not Langfuse)** | Phoenix is Apache 2.0; Langfuse is AGPL | License risk per L0 D-15 |
| **AD-8: Audit log is WORM-anchored** | Daily Merkle root anchored to RFC-3161 timestamp service | Compliance-defensible audit immutability |

---

## 7. Cross-cutting hooks

| Concern | Implementation |
|---|---|
| **Posture (Rule 11)** | `dev` permits in-memory metrics + log-only audit; `research`/`prod` requires Phoenix + WORM-anchored audit |
| **Spine (Rule 11)** | every event carries `tenant_id, run_id, parent_run_id, attempt_id, capability_name` per applicability |
| **Resilience (Rule 7)** | spine emitters wrapped in suppress; recordFallback is the four-prong codification |
| **Operator-shape (Rule 8)** | every release HEAD passes `gate/check_observability_spine_real.sh` (5 of 14 layers must show real provenance) |
| **License audit (D-15)** | Langfuse + Loki rejected; Phoenix + VictoriaLogs adopted |

---

## 8. Quality

| Attribute | Target | Verification |
|---|---|---|
| All 12 RunEventEmitter methods produce metrics | 100% | `MetricsCatalogTest` |
| All 14 SpineEmitter layers covered | 100% | `SpineCoverageTest` |
| Spine emitters never raise | proven by chaos test injecting failures | `tests/chaos/SpineEmitterChaosIT` |
| Rule 7 four-prong on every fallback | enforced by CI | `Rule7CompletenessTest` |
| Audit immutability | WORM-anchored daily Merkle root | `tests/integration/AuditImmutabilityIT` |
| Cross-tenant cardinality (raw tenant_id) | Prometheus storage scales to 1000+ tenants without recording rules | benchmarked at OperatorShapeGate |

---

## 9. Risks

- **Cardinality explosion**: raw `tenant_id` label may produce millions of series at scale; ops-side recording rules required. Tracked as `docs/observability/cardinality-policy.md`
- **Phoenix is younger than Langfuse**: feature gaps possible; if a critical Langfuse feature missing, may need commercial license escape
- **OpenTelemetry version churn**: track upstream
- **Spine emitter performance**: profile shows < 5µs per emit; should not be hot-path concern

## 10. References

- Hi-agent prior art: `D:/chao_workspace/hi-agent/hi_agent/observability/ARCHITECTURE.md` — same 12+14 split, same Rule 7 pattern
- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Phoenix (Apache 2.0): https://github.com/Arize-ai/phoenix
- OpenTelemetry: https://opentelemetry.io/
- Micrometer: https://micrometer.io/
