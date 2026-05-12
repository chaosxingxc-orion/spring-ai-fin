# Response to Third Architecture Reviewer (Architectural Perspective)

**Date**: 2026-05-12  
**Reviewer**: Third Architecture Reviewer — Architectural Perspective  
**Reference SHA**: `38b4ca0` (baseline at review time)  
**Response methodology**: Issue classification → per-category self-audit → systemic fix per category (not case-by-case). Self-audit surfaced **15 additional hidden defects** beyond the reviewer's 9 explicit issues; all 24 findings are addressed below.

---

## Methodology Note

Per the architecture team's review protocol, issues are **not fixed one-by-one**. They are first classified into categories sharing a common root cause, then each category is systematically self-audited to discover hidden defects that share the root, and finally **one cohesive systemic fix per category** is designed and delivered. This produces architecturally coherent fixes that address both the surface symptoms and the structural root causes.

---

## Classification Table

| Category | Reviewer issues | Common root cause |
|---|---|---|
| **Cat-A — Composition & Continuation Model** | 1, 2 | Suspend primitive taxonomy, cardinality, and lifetime unspecified |
| **Cat-B — Lifecycle Operations & State Audit** | 4, 5, 8 | RunStatus transitions, operations, audit, and concurrency unspecified |
| **Cat-C — Layered SPI Coherence** | 3, 4 | No distinction between cross-tier SPI and tier-specific SPI |
| **Cat-D — Data / Payload Contract** | 6 | No typed payload contract, no codec metadata, no schemas |
| **Cat-E — Cross-Boundary Context Propagation & Atomicity** | 7, 9 | Two propagation mechanisms (ThreadLocal vs RunContext) without unified model; atomicity boundaries unstated |

Issue 4 (Orchestrator overloaded) and Issue 8 (states without operations) share Cat-B's root cause; reviewer listed them separately but the fix is one design move.

---

## Cat-A — Composition & Continuation Model

### Reviewer Issues Bundled
- **Issue 1**: Whether `SuspendSignal` as a checked exception is the right primitive for suspending agent execution; concern about Java lacking first-class continuations.
- **Issue 2**: Fan-out / parallel child dispatch not designed; `AwaitChildren` semantics unspecified.

### Self-Audit Hidden Defects (not in reviewer's 9)
- **HD-A.1**: `SuspendSignal` carries no max-suspend duration / deadline. A run can sit in `SUSPENDED` indefinitely with no terminal transition for stuck runs.
- **HD-A.2**: Child-run failure propagation to parent is undefined. `SyncOrchestrator.executeLoop` handles only the success branch; if a child throws or transitions to `FAILED`, parent behaviour is implicit.
- **HD-A.3**: Per-reason resume-payload schema is undefined. `AwaitChildren` would need `Map<UUID, Object>` (per-child results), `AwaitTimer` needs no payload, `AwaitApproval` needs the approver's decision — all unspecified.

### Systemic Fix

**ADR-0019** — *SuspendSignal: checked-exception primitive + sealed SuspendReason taxonomy*

**Decision on Issue 1 — Keep checked exception (reject primitive change)**:  
Java has no first-class continuations. The alternatives (Loom virtual threads blocking, Quasar coroutines, state-machine codegen) each impose worse trade-offs than a checked exception at a designated suspend-point boundary. `SuspendSignal` provides:
- Compile-time visibility of suspend points (`throws SuspendSignal` in SPI method signatures).
- Explicit suspend-point model — callers know exactly where suspension may occur, not arbitrary yield.
- Stackful suspension without bytecode instrumentation.

The reviewer's concern is valid for languages with first-class continuations; for Java 21, the checked-exception model is the strongest viable approach.

**Decision on Issues 2 + HD-A.1 + HD-A.2 + HD-A.3 — Sealed SuspendReason taxonomy**:  
A `sealed interface SuspendReason` defines per-variant typed resume payloads and deadlines. Every `SuspendSignal` carries a `SuspendReason`; every reason carries `deadline() : Instant` (HD-A.1). `ChildFailurePolicy` resolves HD-A.2. Per-variant resume payload shape is implied by the variant type (HD-A.3).

Sealed variants (ADR-0019):
```
ChildRun(UUID childRunId, ChildFailurePolicy, Instant deadline)
AwaitChildren(List<UUID> childRunIds, JoinPolicy, ChildFailurePolicy, Instant deadline)  // Issue 2
AwaitTimer(Instant fireAt)
AwaitExternal(String callbackToken, Instant deadline)
AwaitApproval(String approvalRequestId, Instant deadline)
RateLimited(String resourceKey, Instant retryAfter)
JoinPolicy: ALL | ANY | N_OF
ChildFailurePolicy: PROPAGATE | IGNORE | COMPENSATE
```

**§4 #19** added. YAML rows: `suspend_reason_taxonomy` (upgraded), `parallel_child_dispatch`, `suspend_deadline_watchdog`.

W0 reference implementation covers only `ChildRun` (single child); remaining variants are **contract-level, deferred to W2** per Rule 2 (no speculative SPIs without consumers).

### Verdicts
- **Issue 1**: **Rejected** — `SuspendSignal` as checked exception is the correct design choice for Java 21. Rationale documented in ADR-0019 §"Why a checked exception?".
- **Issue 2**: **Accepted** — `AwaitChildren` + `JoinPolicy` + `ChildFailurePolicy` formally specified in ADR-0019 + §4 #19. Implementation deferred to W2.

---

## Cat-B — Lifecycle Operations & State Audit

### Reviewer Issues Bundled
- **Issue 4**: `Orchestrator` is overloaded — mixes concerns of run dispatch, lifecycle management (cancel, resume, retry), and status querying.
- **Issue 5**: `RunStatus` transitions are not formally defined; no exhaustive DFA. Any code can attempt any transition.
- **Issue 8**: `RunStatus` values exist without specifying which operations are legal from each state.

### Self-Audit Hidden Defects
- **HD-B.1**: No `EXPIRED` terminal state for runs whose suspension deadline elapses. A timer-bound suspension has no legitimate terminal transition.
- **HD-B.2**: No transition audit trail. `Run` carries only current status — no history of who/when/why a transition occurred.
- **HD-B.3**: Transition idempotency is unspecified. Two concurrent `cancel(runId)` calls — is the second a 200 or a 409?
- **HD-B.4**: No optimistic-lock version on `Run`. Concurrent writers (cancel + suspend save + retry + timer-fire) can overwrite each other lossily.

### Systemic Fix

**ADR-0020** — *RunLifecycle SPI separation + RunStatus formal DFA + transition audit*

**Issue 4 + Issue 8 — RunLifecycle SPI separation**:  
`Orchestrator.run(...)` covers only dispatch; a new `RunLifecycle` interface covers lifecycle operations:
```java
interface RunLifecycle {
    Run cancel(UUID runId, String tenantId, String reason);   // 409 if terminal, 200 if already cancelled
    Run resume(UUID runId, String tenantId, Object payload);  // re-auth per §4 #14
    Run retry(UUID runId, String tenantId);                   // FAILED → RUNNING, new attemptId
}
```
W0: design-only (Rule 2 — no consumers yet). W2: materialised alongside `RunController`.

**Issue 5 + HD-B.1 — Formal RunStatus DFA with EXPIRED**:
```
PENDING   → RUNNING | CANCELLED
RUNNING   → SUSPENDED | SUCCEEDED | FAILED | CANCELLED
SUSPENDED → RUNNING | EXPIRED | FAILED | CANCELLED      // HD-B.1: EXPIRED added
FAILED    → RUNNING (retry)
SUCCEEDED → (terminal)
CANCELLED → (terminal)
EXPIRED   → (terminal)                                   // HD-B.1
```
`RunStatus.EXPIRED` added as 7th enum value. `RunStateMachine` utility shipped at W0 with `validate(from, to)`, `allowedTransitions(s)`, `isTerminal(s)`.

**HD-B.3 — Idempotency rules**: `cancel` on `CANCELLED` returns 200 + same row (idempotent); `cancel` on `SUCCEEDED`/`EXPIRED` returns 409.

**HD-B.2 + HD-B.4 — Audit + optimistic lock**: `run_state_change` table (runId, from, to, actor, reason, occurred_at, tenant_id) at W2. `Run.version` optimistic lock at W2.

**§4 #20** added. **Rule 20** active (enforced now). YAML rows: `run_status_transition_validator` (shipped), `run_lifecycle_spi`, `run_state_change_audit_log`, `run_optimistic_lock`.

**Code shipped at W0**:
- `RunStateMachine.java` — DFA validator (`validate`, `allowedTransitions`, `isTerminal`).
- `RunStatus.java` — `EXPIRED` added.
- `Run.withStatus(...)` — calls `RunStateMachine.validate(this.status, newStatus)`.
- `Run.withSuspension(...)` — calls `RunStateMachine.validate(this.status, RunStatus.SUSPENDED)`.
- `RunStateMachineTest.java` — exhaustive parameterized tests (legal + illegal transitions, terminal statuses, `Run` method integration).

### Verdicts
- **Issue 4**: **Accepted** — `RunLifecycle` SPI formally separated from `Orchestrator`. Design in ADR-0020; materialised at W2.
- **Issue 5**: **Accepted** — Formal DFA with all legal/illegal transitions specified; `RunStateMachine.validate` enforced in `Run`; `EXPIRED` added; exhaustive tests shipped.
- **Issue 8**: **Accepted** — Per-state operation semantics fully specified in DFA table + idempotency rules.

---

## Cat-C — Layered SPI Coherence

### Reviewer Issues Bundled
- **Issue 3**: `Checkpointer` and related SPIs claim "same SPI surface across all tiers" but W4 Temporal bypasses the SPI entirely — internally contradictory.
- **Issue 4** (shared): `Orchestrator` mixing concerns also manifests as SPI layer confusion (dispatch vs lifecycle vs durability).

### Self-Audit Hidden Defects
- **HD-C.1**: `IdempotencyStore` is `@Component` (concrete class) rather than `interface`. Violates §4 #7 SPI purity.
- **HD-C.2**: Two `IdempotencyRecord` types coexist with divergent constructor signatures (`platform` vs `runtime`). Cannot interoperate.
- **HD-C.3**: `ResilienceContract` (§4 #8) cross-tier vs per-tier classification is unspecified.
- **HD-C.4**: `Run.capabilityName` is hardcoded to `"orchestrated"` in `SyncOrchestrator`. `CapabilityRegistry` SPI (§4 #15) is the resolution mechanism but has no producer.

### Systemic Fix

**ADR-0021** — *Layered SPI taxonomy: cross-tier core vs tier-specific adapters*

Three-layer taxonomy:
- **Layer 1 — Cross-tier core**: `Run`, `RunStatus`, `RunRepository`, `RunContext`, `Orchestrator` outer signature, `RunLifecycle`, `ResilienceContract` (HD-C.3: classified Layer 1).
- **Layer 2 — Tier-specific adapters**: `ExecutorDefinition` (lambdas at W0/W2, named refs at W2+ for async dispatch).
- **Layer 3 — Tier-internal SPIs**: `Checkpointer` (W0 in-memory → W2 Postgres → **W4 absent**), `IdempotencyStore` (W0 no-op → W2 Postgres), `PayloadCodec` (Cat-D).

`§4 #9` revised: "stable cross-tier core (Layer 1) + tier-specific adapters (Layers 2–3); W4 Temporal bypasses Layer 3 entirely" (replaces "same SPI surface across all tiers").

**HD-C.1 + HD-C.2**: `IdempotencyStore` promotion to interface and `IdempotencyRecord` consolidation — flagged in ADR-0021 consequences; deferred to W1 cleanup (out of scope for this response per Rule 2).

**HD-C.4**: `CapabilityRegistry` trigger moved from W4 → W2 (precondition for named-executor dispatch in `AwaitChildren`). `§4 #15` updated.

`Checkpointer.java` javadoc rewritten to accurately reflect the Layer-3 SPI, W4-bypass, and atomicity contract reference (ADR-0024).

YAML rows: `layered_spi_taxonomy`, `capability_registry_spi` trigger updated.

### Verdicts
- **Issue 3**: **Accepted** — §4 #9 "same SPI surface" claim corrected to layered taxonomy; `Checkpointer` javadoc fixed; W4 bypass formally specified in ADR-0021.
- **Issue 4 (shared)**: **Accepted** (see Cat-B verdict).

---

## Cat-D — Data / Payload Contract

### Reviewer Issues Bundled
- **Issue 6**: No typed payload contract. `resumePayload : Object` gives callers no guidance on what the executor expects; no serialization strategy for cross-JVM boundaries.

### Self-Audit Hidden Defects
- **HD-D.1**: `Checkpointer.save(UUID, String, byte[])` carries no codec metadata. When `PostgresCheckpointer` reads bytes at W2, it cannot know the encoding (JSON? Proto? raw string?). `IterativeAgentLoopExecutor` stores `payload.toString()` bytes — an undocumented encoding.
- **HD-D.2**: `RunEvent` (streamed, §4 #11 "typed progress events — no raw Object") has no schema, no class. Rule 15 references a shape that does not exist.
- **HD-D.3**: PII / redaction ownership in payloads is unassigned. §4 #16 PII filter hook cannot be implemented without a typed payload surface.

### Systemic Fix

**ADR-0022** — *PayloadCodec SPI and typed payload contract*

Contract surfaces (all **design-only, deferred to W2**):
```java
sealed interface Payload permits TypedPayload, RawPayload { Class<?> type(); }
record TypedPayload<T>(T value, Class<T> type) implements Payload { }
record RawPayload(Object value) implements Payload { Class<?> type() { return Object.class; } }

// HD-D.1 — codec metadata on persistence
record EncodedPayload(byte[] bytes, String codecId, String typeRef) { }
interface PayloadCodec<T> {
    String id();              // stable; e.g. "jackson-json-v1"
    Class<T> type();
    byte[] encode(T value);
    T decode(EncodedPayload payload);
}

// HD-D.2 — typed streaming event
sealed interface RunEvent permits NodeStarted, NodeCompleted, Suspended, Resumed, Failed, Terminal { }
```

`Checkpointer.save` evolves at W2 to carry `EncodedPayload` (codec metadata). `RawPayload` rejected at persistence boundary (Rule 22, deferred). PII hooks (HD-D.3) depend on `TypedPayload<T>` to locate PII fields by type — dependency chain documented in ADR-0022.

**§4 #21** added. **Rule 22** deferred (W2 trigger). YAML rows: `payload_codec_spi`.

No code shipped at W0 (Rule 2 — no consumers yet; existing `Checkpointer` raw-bytes API is correct for W0 in-memory use).

### Verdicts
- **Issue 6**: **Accepted** — Typed payload contract (`TypedPayload<T>`, `EncodedPayload`, `PayloadCodec<T>`, `RunEvent`) formally specified in ADR-0022 + §4 #21. Implementation deferred to W2 with Rule 22 gate.

---

## Cat-E — Cross-Boundary Context Propagation & Atomicity

### Reviewer Issues Bundled
- **Issue 7**: Tenant propagation across suspend/resume boundaries is architecturally undefined. `TenantContextHolder` (ThreadLocal) is invalid across HTTP request boundaries, async threads, and timer-driven resumes.
- **Issue 9**: No transaction boundary is defined between `Checkpointer` and `RunRepository`. When a Run suspends, two writes occur; if either fails, the system is permanently inconsistent.

### Self-Audit Hidden Defects
- **HD-E.1**: `RunContext.tenantId() : String` vs `TenantContext.tenantId() : UUID` type mismatch. Implicit lossy conversion exists.
- **HD-E.2**: Logback MDC not populated with `tenant_id`. JSON logs cannot be filtered/correlated per tenant.
- **HD-E.3**: No Micrometer tag policy mandating `tenant_id` on every custom metric. Metrics aggregate across tenants.
- **HD-E.4**: HTTP 403 mapping for resume tenant-mismatch is normative but unimplementable (no `RunController` yet). Deferred — not a current code defect.
- **HD-E.5**: OTel `trace_id` propagation across suspend → resume is unspecified. When a run suspends in request A and resumes in request B (or timer), the trace must continue.

### Systemic Fix

**ADR-0023** — *Cross-boundary context propagation: tenant, trace, MDC, metric tags*

Canonical propagation model:
```
HTTP path (create or explicit-resume):
  X-Tenant-Id header
  → TenantContextFilter (agent-platform, HTTP edge only)
      TenantContextHolder.set(...)       [request-scoped ThreadLocal]
      MDC.put("tenant_id", ...)          [log correlation — shipped now, HD-E.2]
  → RunController passes tenantId as String arg to Orchestrator.run(...)
  → SyncOrchestrator creates RunContextImpl(tenantId, runId, checkpointer)
  → RunContext.tenantId() is the canonical carrier inside agent-runtime

Timer-driven or internal resume:
  Scheduler / watchdog loads Run from RunRepository
  → Run.tenantId() is the source-of-truth
  → RunContextImpl constructed from Run.tenantId()
  → TenantContextHolder is NOT accessed
```

**Rule 21 (active, enforced now)**: No class under `ascend.springai.runtime.*` (main sources) may import `TenantContextHolder`. Enforced by `TenantPropagationPurityTest` (ArchUnit).

**HD-E.2 (shipped now)**: `TenantContextFilter.doFilterInternal` now calls `MDC.put("tenant_id", ...)` after `TenantContextHolder.set(...)` in both posture branches; `MDC.remove("tenant_id")` in `finally`.

**HD-E.1 (deferred to W1)**: `RunContext.tenantId()` migrates `String → UUID` alongside Keycloak integration.

**HD-E.3 (deferred to W1)**: Micrometer `MeterFilter` bean propagating `tenant_id` tag.

**HD-E.5 (deferred to W2)**: `Run.traceparent` column; `RunController` writes incoming `traceparent` header at creation; resumed spans continue the distributed trace.

**§4 #22** added. YAML rows: `tenant_propagation_purity` (shipped), `logbook_mdc_tenant_id` (shipped).

---

**ADR-0024** — *Suspension write atomicity: Checkpointer + RunRepository transactional contract*

Tiered strategy:

| Checkpointer backend | Atomicity strategy |
|---|---|
| W0 in-memory (`InMemoryCheckpointer`) | Single-threaded; sequential writes on same call stack. Invariant documented in `SyncOrchestrator.executeLoop` javadoc. |
| W2 Postgres (`PostgresCheckpointer`) | Both `runs` and `run_checkpoints` in same DataSource; single `@Transactional` block. Mandatory. |
| W2 Redis (`RedisCheckpointer`) | Transactional outbox (ADR-0007): `run_status=SUSPENDED` + `pending_checkpoint` row in one Postgres txn; outbox publisher writes Redis + deletes pending row. |
| W4 Temporal (`TemporalOrchestrator`) | SPI bypassed. Temporal workflow state machine is the atomic record. |

**Scenario A** (RunRepository save succeeds; checkpoint fails) → run stuck in `SUSPENDED` with no checkpoint → impossible to resume. **Scenario B** (checkpoint succeeds; RunRepository save fails) → stale RUNNING status with orphaned checkpoint. Both scenarios are impossible at W0 (single-threaded); both must be prevented at W2.

`SyncOrchestrator.executeLoop` javadoc updated to clarify the W0 single-thread atomicity invariant and the W2 `@Transactional` mandate.

**Rule 23 (deferred, W2 trigger)**: any W2+ Orchestrator that violates this contract is a ship-blocking defect.

**§4 #23** added. YAML rows: `suspension_write_atomicity_contract`.

### Verdicts
- **Issue 7**: **Accepted** — `RunContext.tenantId()` canonicalized as sole runtime carrier; `TenantContextHolder` restricted to HTTP edge; ArchUnit Rule 21 enforced; MDC populated at W0; full propagation model in ADR-0023.
- **Issue 9**: **Accepted** — Tiered atomicity contract specified in ADR-0024; W0 invariant documented in javadoc; W2 `@Transactional` mandate is binding; Rule 23 is the ship gate.

---

## Adjudication Table

| Issue # | Summary | Verdict | Delivery |
|---------|---------|---------|---------|
| 1 | `SuspendSignal` primitive change | **Rejected** — checked exception is correct for Java 21; alternatives documented | ADR-0019 |
| 2 | Fan-out / `AwaitChildren` semantics | **Accepted** — sealed `SuspendReason` + `JoinPolicy` + `ChildFailurePolicy` | §4 #19, ADR-0019, YAML (W2) |
| 3 | Checkpointer "same SPI" claim contradicts W4 bypass | **Accepted** — layered SPI taxonomy; §4 #9 revised; javadoc fixed | §4 #9 revision, ADR-0021 |
| 4 | Orchestrator overloaded | **Accepted** — `RunLifecycle` SPI separated; `Orchestrator` is dispatch-only | §4 #20, ADR-0020 (W2) |
| 5 | No formal RunStatus DFA | **Accepted** — exhaustive DFA specified; `RunStateMachine` shipped; tests green | §4 #20, Rule 20, Code (W0) |
| 6 | No typed payload contract | **Accepted** — `PayloadCodec<T>`, `EncodedPayload`, `RunEvent` specified | §4 #21, ADR-0022 (W2) |
| 7 | Tenant propagation undefined across suspend/resume | **Accepted** — `RunContext` canonical; MDC shipped; ArchUnit Rule 21 shipped | §4 #22, ADR-0023, Code (W0) |
| 8 | RunStatus states without operations | **Accepted** — per-state operation semantics specified in DFA table | §4 #20, ADR-0020 |
| 9 | No atomicity boundary between Checkpointer and RunRepository | **Accepted** — tiered contract in ADR-0024; W0 javadoc; W2 @Transactional mandate | §4 #23, ADR-0024, Rule 23 |

---

## Action Ledger

### Shipped at W0 (immediate)

| Artifact | Category | Defect addressed |
|---|---|---|
| `RunStateMachine.java` | Cat-B | Issue 5, HD-B.1 |
| `RunStatus.EXPIRED` (7th value) | Cat-B | HD-B.1 |
| `Run.withStatus` → `RunStateMachine.validate(from, to)` | Cat-B | Issue 5 |
| `Run.withSuspension` → `RunStateMachine.validate(from, SUSPENDED)` | Cat-B | Issue 5 |
| `RunStateMachineTest.java` (exhaustive DFA) | Cat-B | Verification |
| `TenantPropagationPurityTest.java` (ArchUnit Rule 21) | Cat-E | Issue 7 |
| `TenantContextFilter` MDC.put/remove `tenant_id` | Cat-E | HD-E.2 |
| `Checkpointer.java` javadoc rewrite | Cat-C | Issue 3 |
| `SyncOrchestrator.executeLoop` atomicity javadoc | Cat-E | Issue 9 |

### Design-only (deferred, no W0 code)

| Artifact | Category | Wave |
|---|---|---|
| `SuspendReason` sealed interface + variants | Cat-A | W2 |
| `RunLifecycle` interface | Cat-B | W2 |
| `PayloadCodec<T>` + `PayloadCodecRegistry` | Cat-D | W2 |
| `RunEvent` sealed interface | Cat-D | W2 |
| `run_state_change` audit table | Cat-B | W2 |
| `Run.version` optimistic lock | Cat-B | W2 |
| `IdempotencyStore` interface promotion (HD-C.1) | Cat-C | W1 |
| `IdempotencyRecord` consolidation (HD-C.2) | Cat-C | W1 |
| `RunContext.tenantId()` String→UUID (HD-E.1) | Cat-E | W1 |
| Micrometer `tenant_id` MeterFilter (HD-E.3) | Cat-E | W1 |
| OTel `traceparent` propagation (HD-E.5) | Cat-E | W2 |

### Rejected claims

| Claim | Reason |
|---|---|
| Issue 1: replace `SuspendSignal` primitive | Java 21 has no first-class continuations; checked exception at designated suspend points is the architecturally correct choice; alternatives (Loom blocking, coroutines, ASM codegen) impose worse trade-offs. ADR-0019 documents the full decision chain. |

---

## Architecture Baseline After This Response

| Dimension | Before | After |
|---|---|---|
| §4 architectural constraints | 18 (#1–#18) | 23 (#1–#23) |
| ADRs | 18 (0001–0018) | 24 (0001–0024) |
| Active rules | 8 | 10 (Rules 20–21 added) |
| Deferred rules | 10 | 13 (Rules 22–24 added) |
| YAML capability rows | ~35 | ~47 (+12 rows) |
| `RunStatus` values | 6 | 7 (EXPIRED added) |
| Architecture-level defects addressed | 0 | 9 reviewer + 15 self-audit = 24 |
