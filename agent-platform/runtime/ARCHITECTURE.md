# runtime — Kernel Binding Seam (L2)

> **L2 sub-architecture of `agent-platform/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) · L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`agent-platform/runtime/` is the **second SAS-1 seam** that may import `agent-runtime.*` (every line annotated with `// sas-1-seam:`). The first seam is `bootstrap/` (assembly); this is the runtime-binding seam (production-only — stub-binding doesn't import `agent-runtime.*`).

Three concerns:

1. **Real-kernel binding**: `RealKernelBackend` wraps `agent-runtime.server.AgentRuntime` and exposes 7 facade callables.
2. **Lifespan supervisor**: `LifespanController` runs background tasks (rehydrate, lease-expiry, watchdog, idempotency-purge, outbox-relay, SIGTERM drain).
3. **JWT validation seam**: `AuthSeam` mounts `agent-runtime.auth.JwtValidator` and exposes a façade callable for the filter chain.

Does NOT own:

- HTTP transport (delegated to `../api/`).
- Contract adaptation (delegated to `../facade/`).
- Run logic itself (delegated to `agent-runtime/server/RunManager.java`).
- LLM transport (delegated to `agent-runtime/llm/`).

---

## 2. Why two seams (not one)

Hi-agent's W31-N introduced this split: bootstrap was approaching its LOC budget while needing to import every kernel symbol. Splitting kernel binding into `runtime/` keeps `bootstrap/` minimal AND preserves "only two places import `agent-runtime.*`" as a CI invariant.

```
agent-platform/                <- can NOT import agent-runtime.* anywhere except:
├── bootstrap/                 [SEAM #1] assembly
│   └── PlatformBootstrap.java   // 100–200 LOC, declarative @Bean
└── runtime/                   [SEAM #2] kernel binding
    ├── RealKernelBackend.java     // sas-1-seam: real-kernel-binding
    ├── LifespanController.java    // sas-1-seam: lifespan tasks
    └── AuthSeam.java              // sas-1-seam: JWT primitives
```

Every line that imports `agent-runtime.*` carries a `// sas-1-seam: <reason>` annotation. CI gate `ArchitectureRulesTest::facadeSeams` enumerates these and fails on missing annotations.

---

## 3. RealKernelBackend

```java
public class RealKernelBackend {
    // sas-1-seam: real-kernel-binding
    private final AgentRuntime agentRuntime;
    
    @Setter // package-private; only PlatformBootstrap sets it
    IdempotencyStore idempotencyStore;     // surfaced for LifespanController
    
    public RealKernelBackend(Path stateDir, AppPosture posture) {
        this.agentRuntime = AgentRuntime.build(stateDir, posture);
    }
    
    // 7 facade callables; constructor-injected into facades
    public RunResponse startRun(TenantContext ctx, RunRequest req) { ... }
    public Optional<RunResponse> getRun(TenantContext ctx, RunId id) { ... }
    public Mono<Void> cancelRun(TenantContext ctx, RunId id) { ... }
    public Flux<Event> iterEvents(TenantContext ctx, RunId id) { ... }
    public ArtifactRef registerArtifact(TenantContext ctx, ArtifactRequest req) { ... }
    public ManifestSnapshot getManifest(TenantContext ctx) { ... }
    public IdempotencyResult reserveOrReplay(TenantContext ctx, String key, byte[] bodyHash) { ... }
}
```

**Rule 6**: `RealKernelBackend` is built exactly once by `PlatformBootstrap::realKernelBackend @Bean`. Inline fallback patterns (`backend != null ? backend : new StubBackend()`) are forbidden.

---

## 4. LifespanController

Background tasks tied to Spring Boot's `ApplicationReadyEvent`:

```java
@Component
public class LifespanController {
    private final RealKernelBackend backend;
    private final ScheduledExecutorService scheduler;
    
    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        // 1. Rehydrate runs (mirrors hi-agent W35-T9 attempt_id bump)
        backend.agentRuntime().rehydrateRuns();
        
        // 2. Background loops
        scheduler.scheduleAtFixedRate(this::leaseExpiryTick, 5, 5, SECONDS);
        scheduler.scheduleAtFixedRate(this::currentStageWatchdogTick, 15, 15, SECONDS);
        scheduler.scheduleAtFixedRate(this::idempotencyPurgeTick, 15, 15, MINUTES);
        scheduler.scheduleAtFixedRate(this::outboxRelayTick, 100, 100, MILLISECONDS);
        
        // 3. SIGTERM drain handler
        Runtime.getRuntime().addShutdownHook(new Thread(this::drain));
    }
    
    private void drain() {
        // Hi-agent W33-C.2 pattern:
        // 1. stop accepting new runs (mark RunQueue rejecting)
        // 2. wait for in-flight runs up to drainTimeout
        // 3. mark remaining runs for re-lease on next startup
        // 4. flush outbox
        // 5. close idempotency store
        // 6. yield
    }
}
```

Each tick method is wrapped in try/catch + spine emitter; failure is recorded as `springaifin_lifespan_tick_errors_total{loop, reason}` (Rule 7 four-prong).

---

## 5. AuthSeam

```java
public class AuthSeam {
    // sas-1-seam: JWT validation
    private final JwtValidator validator;
    
    public AuthSeam(JwtValidator validator) {
        this.validator = validator;
    }
    
    public ValidationOutcome validateAuthorization(String header) {
        // dev: passthrough; research/prod: validate HMAC
        // returns ValidationOutcome { authClaims, error }
    }
}
```

`AuthSeam` is the only `agent-platform/` file that imports `agent-runtime.auth.*`. `JWTAuthFilter` calls into `AuthSeam` rather than directly into `JwtValidator`. This preserves R-AS-1 layering at the filter level.

---

## 6. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: SAS-1 single seam (with the bootstrap split)** | `runtime/` is seam #2; bootstrap is seam #1 | Lets bootstrap stay minimal while preserving "only two import sites" |
| **AD-2: One AgentRuntime + one event scheduler bound to Reactor** | No per-call `Mono.block()` (Rule 5) | hi-agent's 04-22 prod incident class |
| **AD-3: Lifespan tasks via @EventListener(ApplicationReadyEvent)** | Spring Boot lifecycle integration | Standard Spring pattern; ensures all beans resolved before tasks start |
| **AD-4: SIGTERM drain handler** | Spring Boot shutdown hook drains in-flight | Production-shape requirement (Rule 8) |
| **AD-5: AuthSeam mediates JWT validation** | Filter calls into seam, not JwtValidator directly | Preserves SAS-1 layering at filter level |
| **AD-6: idempotencyStore surfaced on backend** | `backend.idempotencyStore` set in bootstrap; LifespanController reads it without ApplicationContext lookup | Hi-agent W35-T4 pattern; avoids `ApplicationContext.getBean` in the lifespan loop |
| **AD-7: Production-only seam** | Stub backend (for tests) does NOT live here; lives in `tests/` | Production seam stays free of test code; SAS-1 invariant clearer |

---

## 7. Cross-cutting hooks

- **Rule 5**: ScheduledExecutorService is a process-singleton; tasks are non-blocking
- **Rule 6**: `RealKernelBackend`, `LifespanController`, `AuthSeam` each built once via `@Bean`; no inline fallback
- **Rule 7**: every lifespan tick emits Counter + WARNING + structured failure event + gate-asserted
- **Rule 8**: SIGTERM drain is part of operator-shape gate step 1 (long-lived process)

---

## 8. Quality

| Attribute | Target | Verification |
|---|---|---|
| Lifespan startup time | ≤ 5s | OperatorShapeGate |
| SIGTERM drain | ≤ 30s for in-flight runs | `gate/check_sigterm_drain.sh` |
| Lease expiry | re-claims within `lease_ttl + 1s` | `tests/integration/LeaseRecoveryIT` |
| Idempotency purge | clears expired rows; emits counter | `tests/integration/IdempotencyTtlPurgeIT` |
| Outbox relay | publishes pending events ≤ 200ms | `tests/integration/OutboxLatencyIT` |
| Auth seam | rejects malformed JWT in research/prod; passes in dev | `tests/integration/AuthSeamIT` |

---

## 9. Risks

- **Hot-path freeze**: every commit invalidates T3 until fresh gate run
- **Lifespan task startup ordering**: if rehydrateRuns fails before background loops start, runs may be stuck. Mitigation: rehydrate is idempotent and may be re-run
- **SIGTERM drain timeout**: too short = data loss; too long = slow restart. Default 30s; configurable

## 10. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Hi-agent prior art: `D:/chao_workspace/hi-agent/agent_server/runtime/ARCHITECTURE.md`
- Spring Boot ApplicationReadyEvent: https://docs.spring.io/spring-boot/api/java/org/springframework/boot/context/event/ApplicationReadyEvent.html
