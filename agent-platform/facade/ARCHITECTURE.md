> **Pre-refresh design rationale (DEFERRED in 2026-05-08 refresh)**
> DEFERRED in the refresh. Facade responsibilities are folded into `agent-platform/ARCHITECTURE.md` (L1).
> The authoritative L0 is `ARCHITECTURE.md`; the
> systems-engineering plan is `docs/plans/architecture-systems-engineering-plan.md`.
> This file is retained as v6 design rationale and will be
> archived under `docs/v6-rationale/` at W0 close.

# facade -- Contract<->Kernel Adaptation (L2)

> **L2 sub-architecture of `agent-platform/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) . L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`agent-platform/facade/` adapts contract DTOs (from `../contracts/v1/`) to kernel callables (from `agent-runtime/server/`). The five facades each own one resource family and translate between the wire shape (frozen) and the kernel shape (free to evolve).

Each facade is **constructor-injected with callables, not typed protocols** (mirrors hi-agent's W23-F decision). The same facade works against both `RealKernelBackend` and a stub backend in tests; backend choice is a `bootstrap/` concern.

Owns:

- `RunFacade` -- start, get, cancel, signal, iter-events
- `EventFacade` -- append, query, SSE source
- `ArtifactFacade` -- register, fetch, list-by-run
- `ManifestFacade` -- render manifest, capability matrix, posture, version constants
- `IdempotencyFacade` -- reserve-or-replay, mark-complete, query
- `AuditFacade` -- append, query (read-only inspector role), dual-approval decode

Does NOT own:

- HTTP transport (delegated to `../api/`)
- Kernel implementation (delegated to `agent-runtime/server/`)
- Idempotency persistence (delegated to `agent-runtime/server/IdempotencyStore`)

---

## 2. The 200-LOC budget (SAS-8)

Every facade is **<= 200 lines** (excluding imports + Javadoc). Enforced by `FacadeLocTest`. The discipline: facades translate, not compute. Computation lives in the kernel.

If a facade exceeds 200 LOC, the wave's GOV track requires either:
- (a) splitting the facade into two, or
- (b) moving computation into the kernel, or
- (c) recording an allowlist entry with expiry_wave + replacement_test.

Hi-agent's W31-N had one allowlisted facade (`RunFacade.start` exceeded 200 LOC during the W32 real-kernel binding); the entry expired and was refactored at W33.

---

## 3. Constructor injection pattern

```java
public class RunFacade {
    // Each callable is a Function<Input, Output> or BiFunction injected at construction.
    // No typed protocol -- keeps facade free of agent-runtime.* imports (SAS-1).
    private final BiFunction<TenantContext, RunRequest, RunResponse> startFn;
    private final BiFunction<TenantContext, RunId, Optional<RunResponse>> getFn;
    private final BiFunction<TenantContext, RunId, Mono<Void>> cancelFn;
    private final BiFunction<TenantContext, RunId, Flux<Event>> iterEventsFn;
    
    public RunFacade(
        BiFunction<TenantContext, RunRequest, RunResponse> startFn,
        BiFunction<TenantContext, RunId, Optional<RunResponse>> getFn,
        BiFunction<TenantContext, RunId, Mono<Void>> cancelFn,
        BiFunction<TenantContext, RunId, Flux<Event>> iterEventsFn
    ) {
        this.startFn = Objects.requireNonNull(startFn);
        this.getFn = Objects.requireNonNull(getFn);
        this.cancelFn = Objects.requireNonNull(cancelFn);
        this.iterEventsFn = Objects.requireNonNull(iterEventsFn);
    }
    
    public RunResponse start(TenantContext ctx, RunRequest req) {
        validateSpine(req);                          // contract-level validation
        return startFn.apply(ctx, req);              // delegate to kernel
    }
    // ... 4 more thin methods
}
```

Bootstrap wires the callables:

```java
@Bean
RunFacade runFacade(RealKernelBackend backend) {
    return new RunFacade(
        backend::startRun,        // method reference; SAS-1 seam concentrated in bootstrap
        backend::getRun,
        backend::cancelRun,
        backend::iterEvents
    );
}
```

Test bootstrap wires stub callables; same facade, different backend.

---

## 4. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: Constructor-injected callables, not protocols** | `BiFunction<...>`, not typed interfaces | Keeps facade free of `agent-runtime.*` typing imports; SAS-1 layering preserved |
| **AD-2: SAS-8 <= 200 LOC per facade** | Enforced by `FacadeLocTest` | Forces facades to translate, not compute; computation is kernel's job |
| **AD-3: Tenant-scoped composite keys** | `(tenantId, key)` for idempotency, `(tenantId, runId)` for runs | Cross-tenant collision impossible by construction |
| **AD-4: Strict-posture orphan filtering (HD-4)** | Under research/prod, facade filters orphan artifact records | hi-agent W23 pattern -- kernel may have orphans during recovery; facade hides them |
| **AD-5: Identity strip on idempotency snapshots (HD-7)** | strip `requestId, traceId` before storing replay snapshot | Otherwise replay returns identity-leaked response |
| **AD-6: Each facade owns ONE resource family** | RunFacade for runs only, etc. | Easier to enforce 200 LOC; clearer ownership |

---

## 5. Cross-cutting hooks

- **SAS-1**: 3 facades carry `// sas-1-seam: <reason>` annotation (RunFacade for SSE, IdempotencyFacade for store access, AuditFacade for audit-decode). Others don't.
- **SAS-8**: `FacadeLocTest` enforces 200-LOC budget; allowlist required for any over.
- **Rule 7**: contract-error-only across boundary; facade re-throws kernel errors as `ContractError`.
- **Rule 11**: tenant_id mandatory first argument on every facade method; spine validation at facade entry.

---

## 6. Quality

| Attribute | Target | Verification |
|---|---|---|
| LOC per facade | <= 200 | `FacadeLocTest` |
| Tenant required-arg | every facade method | `FacadeTenantArgTest` |
| Backend agnosticism | same facade, real + stub | `tests/integration/FacadeBackendIT` |
| Error envelope discipline | only `ContractError` thrown across boundary | `FacadeErrorEnvelopeTest` |

## 7. Risks

- **Kernel evolution leaks into facade**: kernel-shape change forces facade-signature change; mitigated by `BiFunction<...>` rather than typed protocol. If shape genuinely needs to change, facade signature update + contract version bump as v2 if breaking.
- **Facade scope creep**: SAS-8 budget catches; reviewer audit on every PR.

## 8. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Hi-agent prior art: `D:/chao_workspace/hi-agent/agent_server/facade/ARCHITECTURE.md`
- Contracts: [`../contracts/ARCHITECTURE.md`](../contracts/ARCHITECTURE.md)
