> **Pre-refresh design rationale (DEFERRED in 2026-05-08 refresh)**
> MERGED INTO `agent-runtime/run/` and `agent-runtime/temporal/` in the refresh.
> The authoritative L0 is `ARCHITECTURE.md`; the
> systems-engineering plan is `docs/plans/architecture-systems-engineering-plan.md`.
> This file is retained as v6 design rationale and will be
> archived under `docs/v6-rationale/` at W0 close.

# runtime -- Reactor Scheduler + Harness (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) . L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`runtime/` (note: this is the `agent-runtime/runtime/` helper module, distinct from `agent-platform/runtime/` seam) owns **in-process primitives for executing work without depending on kernel-facade transport**.

Owns:

- `ReactorScheduler` -- single persistent `Scheduler` per process (Rule 5 enforcement)
- `CancellationToken` -- cooperative cancellation token; durable flag for cross-thread/process cancellation
- `HarnessExecutor` -- unified action lifecycle (PREPARED -> DISPATCHED -> SUCCEEDED/FAILED)
- `PermissionGate` -- fail-closed pre-dispatch check (RBAC + capability policy)
- `GovernanceEngine` -- effect-class validation
- `EvidenceStore` -- append-only audit trail per successful action

Does NOT own:

- Kernel facade transport (delegated to `agent-platform/runtime/RealKernelBackend`)
- HTTP route handling (delegated to `agent-platform/api/`)
- Capability registration (delegated to `../capability/`)
- LLM transport (delegated to `../llm/`)

---

## 2. ReactorScheduler -- the Rule 5 enforcement seam

```java
@Configuration
public class ReactorSchedulerConfig {
    /**
     * Single persistent Scheduler for the JVM process.
     * Rule 5: every reactive resource (WebClient, async DB calls, etc.) bound to THIS scheduler.
     * No per-call scheduler creation; no Mono.block() in library code.
     */
    @Bean(destroyMethod = "dispose")
    public Scheduler dispatchScheduler() {
        return Schedulers.newBoundedElastic(
            /* threadCap */ 64,
            /* queuedTaskCap */ 10000,
            /* threadNamePrefix */ "spring-ai-fin-dispatch",
            /* ttlSeconds */ 60,
            /* daemon */ true
        );
    }
}
```

**Rule 5 enforcement**: `ArchitectureRulesTest::noBlockOutsideEntryPoints` greps for `Mono.block()` / `Flux.blockLast()` outside `agent-platform/cli/`, `tests/`, and `main`. Every match must carry `// rule5-exempt: <reason>` annotation OR be in an entry point.

This is the canonical fix for hi-agent's 2026-04-22 prod incident (`Event loop is closed` on retry due to per-call `asyncio.run`). Java equivalent failure mode is "Reactor scheduler disposed" -- same root cause.

---

## 3. CancellationToken

```java
public class CancellationToken {
    private final AtomicBoolean cancelled = new AtomicBoolean(false);
    private final RunQueue runQueue;             // for durable cross-thread/process flag
    private final RunId runId;
    
    public boolean isCancelled() {
        if (cancelled.get()) return true;
        // Tier-2 check: durable flag survives process restart
        if (runQueue.isCancellationRequested(runId)) {
            cancelled.set(true);
            return true;
        }
        return false;
    }
    
    public void checkInterrupt() {
        if (isCancelled()) {
            throw new CancellationException("Run " + runId + " cancelled");
        }
    }
}
```

Used by `RunExecutor` between stage boundaries (Rule 8 step 6: cancellation honoured).

---

## 4. HarnessExecutor -- unified action pipeline

Every external action (LLM call, MCP tool invocation, database write, framework dispatch) flows through this pipeline:

```
PREPARED -> PermissionGate.check -> GovernanceEngine.validate -> CapabilityInvoker.invoke 
        -> DISPATCHED -> SUCCEEDED (record EvidenceStore) | FAILED (record fallback + propagate)
```

```java
public class HarnessExecutor {
    public <R> R execute(Action<R> action, RunContext ctx) {
        // 1. Permission check (fail-closed)
        permissionGate.check(action, ctx).orThrow();
        
        // 2. Governance validation (effect class, side-effect budget)
        governance.validate(action, ctx).orThrow();
        
        // 3. Dispatch via injected CapabilityInvoker
        try {
            R result = capabilityInvoker.invoke(action, ctx);
            
            // 4. Record evidence (success path)
            evidenceStore.append(EvidenceRecord.success(action, ctx, result));
            return result;
        } catch (Exception e) {
            // 5. Record evidence (failure path) + propagate
            evidenceStore.append(EvidenceRecord.failure(action, ctx, e));
            fallbackRecorder.recordFallback(ctx, "harness-action-failed", e);
            throw new HarnessFailureException(action, e);
        }
    }
}
```

Mirrors hi-agent's `HarnessExecutor`. Strict pipeline; no partial-state success.

---

## 5. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: One persistent Scheduler** | `Schedulers.newBoundedElastic` daemon; bound at boot | Rule 5: prevent "Reactor disposed" on retry |
| **AD-2: AsyncBridgeService = process singleton ExecutorService** | Replaces per-call `ThreadPoolExecutor` allocations | Hi-agent's 04-23 latency regression class |
| **AD-3: HarnessExecutor requires injected `EvidenceStore`** | No inline default -- raises if absent | Rule 6 applied; hi-agent's pattern |
| **AD-4: Strict harness pipeline** | PermissionGate -> GovernanceEngine -> CapabilityInvoker -> EvidenceStore | No partial-state success |
| **AD-5: Cancellation durable flag in RunQueue** | survives across thread / restart | Tenant-scoped via RunQueue (W33 D.2 in hi-agent) |
| **AD-6: Rule 5 enforcement test** | grep for `Mono.block()` outside entry points | CI gate `ArchitectureRulesTest::noBlockOutsideEntryPoints` |
| **AD-7: Permission gate fail-closed** | refuses if descriptor's posture flag is false | Rule 1 strongest interpretation |

---

## 6. Cross-cutting hooks

- **Rule 5**: this IS the Rule 5 enforcement layer
- **Rule 6**: HarnessExecutor + ReactorScheduler + EvidenceStore each `@Bean`-built once
- **Rule 7**: every harness action emits Evidence record; failure paths emit FallbackRecorder
- **Rule 8**: cancellation round-trip is honoured via `CancellationToken`
- **Spine**: `RunContext` carries spine; harness propagates to evidence

---

## 7. Quality

| Attribute | Target | Verification |
|---|---|---|
| Scheduler lifecycle | one per JVM | `tests/integration/SchedulerLifecycleIT` |
| Cancellation propagation | mid-stage cancel drives terminal in <= 30s | `gate/check_cancel.sh` |
| Harness pipeline correctness | no partial-state success | `tests/unit/HarnessPipelineTest` |
| Rule 5 enforcement | zero `Mono.block()` outside entry points | `ArchitectureRulesTest::noBlockOutsideEntryPoints` |
| Evidence completeness | every successful action has EvidenceRecord | `tests/integration/EvidenceCoverageIT` |

## 8. Risks

- **Scheduler tuning**: thread cap + queue cap empirically tuned at OperatorShapeGate; default may need adjustment per workload
- **Permission gate over-strict**: occasional dev-time friction; relaxed under dev posture
- **Rule 5 escape via reflection**: caught at runtime by Reactor; mitigated by review

## 9. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Server (consumer): [`../server/ARCHITECTURE.md`](../server/ARCHITECTURE.md)
- Hi-agent prior art: `D:/chao_workspace/hi-agent/hi_agent/runtime/ARCHITECTURE.md` -- same SyncBridge pattern
- Reactor Schedulers: https://projectreactor.io/docs/core/release/reference/schedulers.html
