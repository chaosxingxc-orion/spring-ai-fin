# Architecture Review Response — Second Reviewer

**Response SHA**: bf99770 (delivery record SHA at response time)  
**Reviewer document**: `docs/spring-ai-ascend-architecture-whitepaper-en.md`  
**Response date**: 2026-05-12  
**Classification**: `design_response`  
**Responding to**: Second reviewer — "C/S Separation and Long-Horizon Swarm Collaboration" proposal

---

## Method Note

This response does not address the reviewer's 17 claims individually. A claim-by-claim response reproduces the reviewer's narrative chapter structure and produces 17 disconnected patches — each appearing to close a gap while leaving the underlying architectural category untouched.

Instead: the 17 claims are grouped into 6 architectural categories. Each category is then self-audited independently to surface hidden defects the reviewer did not name. This approach yields one binding architectural constraint per category rather than 17 surface patches.

**Result: 13 hidden defects surfaced beyond the reviewer's critique.** Three are severe:

1. **(C4, CRITICAL)** `SuspendSignal.resumePayload` is an in-process `Object`. Our published claim — "one SPI spans in-memory + Postgres + Temporal" — is currently aspirational, not factual. Cross-JVM resume is blocked until W2 closes the serialization contract.
2. **(C5, SEVERE)** Tenant context is not revalidated at resume. A resume request from tenant B carrying a Run owned by tenant A is currently allowed through. This is a real tenant-isolation hole at the resume boundary.
3. **(C6, HIGH)** `ExecutorDefinition.NodeFunction` and `Reasoner` are inline lambdas. These cannot be serialized across Temporal activity boundaries. The W4 path requires a `CapabilityRegistry` indirection that does not yet exist in design.

---

## Summary Adjudication

| Reviewer claim | Category | Decision | Action artifact |
|---|---|---|---|
| 1.1 Sync HTTP bottleneck — no autonomous pulse | C1 Lifecycle | Accept | §4 #10, `suspend_reason_taxonomy` |
| 1.2 Static SPI locks JVM — cross-language | C6 Topology | Reject | ADR-0015 + MCP W3 (see §11) |
| 1.3 `Run` is cold — no long-horizon identity | C1 Lifecycle | Accept | §4 #10, `agent_subject_identity` |
| 2.2 N:1 long-lived worker model missing | C1 Lifecycle | Accept (deferred) | §4 #10, `repository_paging_contract` |
| 2.3 Three handoff modes (Sync/SSE/Yield) | C2 Communication | Accept | §4 #11, Rule 15, `streamed_handoff_mode` |
| 2.3 Yield credential injection | C5 Trust | Accept (partial) | §4 #14, Rule 17, `resume_reauthorization_check` |
| 2.4 Dual-track memory + placeholder | C4 Data Plane | Reject (speculative) | See §11 |
| 3.1 Full-trace vs node-snapshot framing | C4 Data Plane | Already shipped | `Checkpointer.save` opaque `byte[]` (C33) |
| 3.2 Interrupt-driven nesting | C6 Topology | Already shipped | C32–C34, `NestedDualModeIT` |
| 3.3 Lazy mount for heavy payloads | C4 Data Plane | Accept | §4 #13, `payload_store_spi` |
| 4.1 Skill-dimensional resource pooling | C3 Resource Gov | Accept | §4 #12, Rule 16, `skill_capacity_matrix` |
| 4.2 C-side vs S-side degradation red line | C3 Resource Gov | Accept | §4 #12, Rule 17 |
| 4.3 Session-context orthogonal decoupling | C4 Data Plane | Accept | §4 #13, `checkpoint_eviction_policy` |
| 5.1 Push-pull intermediary + backpressure | C2 Communication | Accept | §4 #11, Rule 15 |
| 5.2 Three-track channel isolation | C2 Communication | Accept (design) | §4 #11, `orchestrator_cancellation_handshake` |
| 5.3 Pre-authorized delegate bidding | C5 Trust + C6 | Reject | ADR-0010 + W3 ActionGuard (see §11) |
| 5.4 Tick Engine — autonomous pulse | C1 Lifecycle | Accept (design) | §4 #10, `suspend_reason_taxonomy` |

---

## C1. Lifecycle & Identity

**Reviewer claims in this category**: 1.1 (sync HTTP, no autonomous pulse), 1.3 (Run is cold), 2.2 (N:1 long-lived worker), 5.4 (Tick Engine).

### Already shipped (reviewer missed)

`Run.parentRunId` + `Run.parentNodeKey` + `RunStatus.SUSPENDED` + `Run.suspendedAt` landed in C32 (SHA 5ef3069). `SuspendSignal` + `Checkpointer` SPI + 3-level `NestedDualModeIT` landed in C33–C34. The substrate for long-horizon *nested* execution is already in tree. The reviewer's framing of W0 as purely request-scoped misses this.

### Hidden defects surfaced by self-audit

1. **`SuspendSignal` has only one suspend cause: child-run dispatch.** There is no `SuspendForTimer(Duration)` variant and no `SuspendForExternalSignal(eventName)` variant. A Run cannot suspend itself for wall-clock wakeup; every suspend must dispatch a child. The Tick Engine pattern (§5.4) is architecturally impossible until the suspend taxonomy is widened. This was not raised by the reviewer; it surfaces from auditing `SuspendSignal.java` against the §5.4 wakeup requirement.
2. **No cross-Run subject identity.** `parentRunId` chains *nested* Runs (this Run was forked from that Run). It does not chain *sequential* Runs of the same logical agent across time. There is no `subjectId` / `agentId` / `correlationId` field. Without it, "this agent has been operating for 3 months" is unprovable from the schema.
3. **`RunRepository.findByTenantAndStatus(SUSPENDED)` returns an unbounded result.** No pagination. For a platform with thousands of suspended Runs, this query is a footgun when W2 persistence lands.
4. **No archival/cold-storage tier.** All Runs live in the hot index forever. A Run that completed 6 months ago should be evictable; the schema has no `archivedAt` and no archival lifecycle hook.

### Binding constraint

**§4 #10 — Long-horizon lifecycle** (ARCHITECTURE.md). `SuspendSignal` gains typed reasons (`ChildRun | AwaitTimer | AwaitExternal | AwaitApproval | RateLimited`) before W2. Long-horizon agent identity is deferred as `AgentSubject` (`agent_subject_identity`). `RunRepository` unbounded queries gain `Pageable` parameters before W2 (`repository_paging_contract`).

---

## C2. Communication Surface

**Reviewer claims in this category**: 2.3 (Sync/SSE/Yield handoff modes), 5.1 (push-pull intermediary + backpressure), 5.2 (three-track channel isolation).

### Already shipped (reviewer missed)

Synchronous `Object` return from `Orchestrator.run(...)` and yield via `SuspendSignal` are both in tree. Two of the three handoff modes the reviewer proposes already exist.

### Hidden defects surfaced by self-audit

1. **`Orchestrator.run(...)` has no cancellation handshake.** Once started, the caller cannot interrupt. `RunStatus.CANCELLED` exists as an enum value but has no producer anywhere in the SPI surface.
2. **No heartbeat / liveness signal.** A caller polling `RunRepository.findById` sees `updatedAt` — this does not distinguish "orchestrator is working" from "orchestrator is wedged". The reviewer's §5.2 heartbeat channel requires a positive liveness signal.
3. **Idempotency and cancellation do not compose.** If `Idempotency-Key=K` is submitted, cancelled mid-flight, and re-submitted with the same key, `IdempotencyHeaderFilter` returns the cancelled record. There is no "kill in-flight, re-attach" path. The reviewer did not raise this.
4. **`Orchestrator.run(...)` return type `Object` precludes typed progress events.** Any streaming variant must carry `(progress, cost_so_far, tool_calls_so_far, partial_output)` tuples. The current return type cannot carry these; the streaming design must define a typed event shape.

### Binding constraint

**§4 #11 — Northbound handoff contract** (ARCHITECTURE.md). Three modes: synchronous (shipped), streamed `Flux<RunEvent>` (deferred W2), yield-via-`SuspendSignal` (shipped). The streaming surface MUST carry cancel handshake, heartbeat ≤ 30 s, typed progress events. **Rule 15** gates this at the first `Flux<T>` / SSE surface commit.

---

## C3. Resource Governance

**Reviewer claims in this category**: 1.2 static SPI lock (rejected in C6), 4.1 (skill-dimensional resource pool), 4.2 (C-side vs S-side degradation red line).

### Already shipped (reviewer missed)

`ResilienceContract.resolve(operationId)` accepts any `String` — skill-namespaced operationIds (e.g., `"skill:credit-check"`) work today without any API change.

### Hidden defects surfaced by self-audit

1. **`ResiliencePolicy` is a single-axis triple `(cbName, retryName, tlName)`.** It cannot express "tenant T may invoke skill S up to N concurrent times AND the global cap for S is M." The two-axis matrix the reviewer's §4.1 demands (`tenant × skill`) requires a policy shape change that does not exist.
2. **No call-tree budget propagation.** If a parent Run is granted a $5 token budget and suspends to dispatch a child Run, the child has no awareness of the remaining budget. `RunContext` does not carry a budget handle. This composes with Rule 13 (P1 cost-of-use) but does not appear in the rule.
3. **`Run.attemptId` is structurally orphaned.** The field exists for retry semantics, but no SPI consumer references it. No executor has a "we are on attempt N, stop or escalate" branch. The field is data without behaviour.
4. **`ResilienceContract` controls retry/circuit-break/time-limit but not admission.** Admission control (queue/suspend-and-wait when a skill is saturated) is different from time-limiting. A time-limit triggers failure; skill saturation should suspend the Run and resume it when capacity frees — not fail it.

### Binding constraint

**§4 #12 — Two-axis resource arbitration** (ARCHITECTURE.md). `ResilienceContract` extends to a two-axis policy `(tenantQuota, globalSkillCapacity)`. Saturation suspends the Run (`SUSPENDED + reason=RateLimited`) rather than failing. Call-tree budget propagates through `RunContext`. **Rule 16** gates this at the first external skill invocation.

---

## C4. Data Plane

**Reviewer claims in this category**: 2.4 (dual-track memory — business vs trajectory), 3.1 (full-trace vs node-snapshot), 3.3 (lazy mount for heavy payloads), 4.3 (session-context decoupling with memory paging).

### Already shipped (reviewer missed)

`Checkpointer.save(runId, nodeKey, byte[])` stores opaque bytes — the executor owns the shape. Full-trace and node-snapshot are both expressible today; the distinction is an executor implementation choice, not a missing SPI concept.

### Hidden defects surfaced by self-audit

1. **CRITICAL: `SuspendSignal.resumePayload: Object` is an in-process reference.** `SyncOrchestrator` catches `SuspendSignal`, dispatches the child synchronously, takes the child's return `Object`, and calls `parent.execute(ctx, def, childResultObject)`. This works in a single JVM. In W2 (Postgres-backed orchestrator) or W4 (Temporal), the parent's resume may occur in a different JVM — and the child's return `Object` will not exist there. The `byte[]` checkpoint is correctly designed; `resumePayload` is the hole. **Our published claim "one SPI spans in-memory + Postgres + Temporal" is aspirational at W0, not factual.** W2 must close this contract.
2. **No content-addressable storage primitive.** If a tool returns 5 MB of HTML referenced in 8 successive checkpoints, the bytes are stored 8 times. The reviewer's "lazy mount with URI/hash pointers" implies content-addressing; no `PayloadStore` interface exists.
3. **`Checkpointer.load` returns `Optional<byte[]>` — eager full-load, no streaming.** A large checkpoint blocks the executor during load. W2+ requires an `InputStream` variant.
4. **No GC / eviction policy on checkpoints.** Terminal Runs keep their checkpoints forever. This bites in W2 (Postgres) before any memory-tier concern.
5. **No size bound on `byte[]`.** A misbehaving executor could checkpoint 1 GB. The SPI contract must state: bytes exceeding N KiB inline MUST use a `PayloadStore` reference.

### Binding constraint

**§4 #13 — Payload addressing and serialization contract** (ARCHITECTURE.md). Inline bytes ≤ 16 KiB; larger payloads use `PayloadStore` reference (`payload_store_spi`). `SuspendSignal.resumePayload` is in-process `Object` at W0 only; W2 must make it byte-serializable (`serializable_resume_payload`). Checkpoint eviction deferred (`checkpoint_eviction_policy`).

---

## C5. Trust & Authorization

**Reviewer claims in this category**: 2.3 yield-handoff credential injection, 5.3 pre-authorized delegate bidding.

### Already shipped (reviewer missed)

`TenantContextFilter` validates `X-Tenant-Id` at the edge. `IdempotencyHeaderFilter` prevents replay. W3 plan includes `ActionGuard` 5-stage chain for tool-call authorization.

### Hidden defects surfaced by self-audit

1. **`SuspendSignal` has no `reason` taxonomy.** Every suspend is shape-identical regardless of why: child dispatch vs needs-approval vs rate-limited vs awaiting-external-event vs timer. The orchestrator cannot determine what action to take without a reason discriminator. (Shared with C1 defect #1.)
2. **Tenant context lifetime across suspend/resume is undefined — and wrong.** `TenantContextFilter` binds `tenantId` to a `ThreadLocal` at the HTTP request edge. When a suspended Run resumes hours later via a different HTTP request, the tenant context is re-established from that request's `X-Tenant-Id` header. **There is no verification that this matches the original `Run.tenantId`.** If tenant B's request carries Run X that was started by tenant A, the system currently allows it through. This is a real tenant-isolation hole at the resume boundary.
3. **No audit envelope on suspend/resume.** Who resumed a long-suspended Run? Did they have authority? `Run.updatedAt` is updated, but the resume-actor identity is not captured.
4. **Idempotency keys have no tenant-binding constraint in the SPI contract.** `IdempotencyStore.claimOrFind(key, tenantId, ...)` exists in stub form, but the contract does not formally state "a key from tenant A cannot collide with the same key from tenant B." A misconfigured implementation could allow cross-tenant collision.

### Binding constraint

**§4 #14 — Resume re-authorization** (ARCHITECTURE.md). Every resume on a `SUSPENDED` Run re-validates `(request.tenantId == Run.tenantId)`; mismatch returns 403 (`resume_reauthorization_check`). Actor identity is captured in an audit envelope. Degradation authority: S-side substitutes means only; ends-modification requires C-side authority. **Rule 17** gates this at the first soft-fallback path.

Pre-authorized delegate bidding (§5.3) is rejected — see §11.

---

## C6. Topology & Discovery

**Reviewer claims in this category**: 1.2 (static SPI locks JVM — reject), 3.2 (interrupt nesting — already shipped), 5.3 (registry-driven dynamic discovery).

### Already shipped (reviewer missed)

ADR-0015 deferred multi-framework dispatch deliberately — Spring AI sufficiency documented; reversal cost assessed as low. MCP Java SDK 2.0.0-M2 is the W3 cross-language tool protocol; it is already on the BoM.

`NestedDualModeIT` (C34) proves 3-level bidirectional graph → agent-loop → graph nesting. The reviewer's §3.2 interrupt-nesting framing describes exactly what was delivered.

### Hidden defects surfaced by self-audit

1. **No `CapabilityRegistry` SPI.** At W0 the orchestrator and two executors are hardcoded in the in-memory module. By W3 (MCP tool protocol), a registry is required to enumerate available skills/tools/executors by name. No SPI shape proposal exists yet (`capability_registry_spi`).
2. **SPI → wire format migration path is not designed.** The orchestration SPI is pure Java (`OrchestrationSpiArchTest` enforces `java.*`-only imports). When W4 introduces Temporal activities, `ExecutorDefinition` (sealed interface with records) must serialize across the activity boundary. Temporal's Jackson serializer requires registered subtypes; `OrchestrationSpiArchTest` enforces pure-Java but does not enforce serializable.
3. **`ExecutorDefinition.NodeFunction` and `Reasoner` are functional interfaces — unserializable to Temporal.** A `Function<RunContext, Object>` lambda captures the calling-side closure. W4 requires `NodeFunction` to become a named entry in a `CapabilityRegistry`, resolved by string, not an inline lambda. This is a fundamental shift the reviewer did not surface (`executor_definition_serialization`).

### Binding constraint

**§4 #15 — SPI serialization path** (ARCHITECTURE.md). Orchestration SPI types are pure Java (current; `OrchestrationSpiArchTest`) AND must be wire-serializable by W4. `NodeFunction`/`Reasoner` move from inline lambdas to named `CapabilityRegistry` entries before W4. Design only at W0.

---

## Action Ledger

| Category | Action | Artifact | Wave gate | Status |
|---|---|---|---|---|
| C1 | Typed suspend reasons | `suspend_reason_taxonomy` YAML row | W2 | design_accepted |
| C1 | AgentSubject long-horizon identity | `agent_subject_identity` YAML row | W2 | design_accepted |
| C1 | Paged RunRepository queries | `repository_paging_contract` YAML row | W2 (before Postgres impl) | design_accepted |
| C2 | Streaming handoff surface | `streamed_handoff_mode` YAML row + Rule 15 | W2 (first Flux<T>) | design_accepted |
| C2 | Cancellation handshake | `orchestrator_cancellation_handshake` YAML row | W2 | design_accepted |
| C3 | Two-axis skill capacity matrix | `skill_capacity_matrix` YAML row + Rule 16 | W2 (first skill invocation) | design_accepted |
| C3 | Call-tree budget propagation | `call_tree_budget_propagation` YAML row | W2 | design_accepted |
| C4 | PayloadStore SPI for large bytes | `payload_store_spi` YAML row | W2 | design_accepted |
| C4 | Serializable resumePayload | `serializable_resume_payload` YAML row | W2 (before Postgres orchestrator) | design_accepted |
| C4 | Checkpoint eviction policy | `checkpoint_eviction_policy` YAML row | W2 | design_accepted |
| C5 | Resume re-authorization check | `resume_reauthorization_check` YAML row + Rule 17 | W2 (before Postgres resume path) | design_accepted |
| C6 | CapabilityRegistry SPI | `capability_registry_spi` YAML row | W3 | design_accepted |
| C6 | ExecutorDefinition serialization | `executor_definition_serialization` YAML row | W3 (before W4) | design_accepted |

---

## Rejected Claims — with Citation

**Claim 1.2 — Static SPI locks JVM / cross-language expansion.**  
Rejected. ADR-0015 (`docs/adr/0015-layered-architecture-capability-model.md`) documents the deliberate choice: Spring AI 2.0.0-M5 provides native tool-calling, MCP adapters, and multi-model routing within the JVM. Python sidecar and LangChain4j dispatch are deferred to W4+ with explicitly low reversal cost assessed. MCP Java SDK 2.0.0-M2 (already on the BoM) is the W3 cross-language tool protocol — the concern is addressed through MCP, not JVM splitting.

**Claim 2.4 — Placeholder text exemption in dual-track memory.**  
Rejected as speculative. The reviewer argues that `[PLACEHOLDER]` text in trajectory checkpoints is a valid architectural pattern deserving formal exemption. This is not an architectural claim; it is an implementation convenience. If placeholder semantics are needed, the `byte[]` checkpoint shape is already capable of encoding them. No SPI-level concept is warranted.

**Claim 5.3 — Pre-authorized delegate bidding.**  
Rejected. `ARCHITECTURE.md §1` defines the system boundary: "self-hostable agent runtime for financial-services operators" — a single-operator deployment model. Multi-operator delegate bidding assumes an open marketplace that is explicitly out of scope. The authorization path for tool-call approval is the W3 `ActionGuard` 5-stage chain (documented in the engineering plan), which handles human-in-the-loop approval without requiring inter-agent trust negotiation. ADR-0010 (`docs/adr/0010-spring-security-oauth2.md`) grounds the authorization model in OAuth2 scopes, which is incompatible with autonomous delegate bidding.

---

## Cross-Cutting Notes

**On the C4 #1 finding (resumePayload serialization):** Our ARCHITECTURE.md §4 #9 states "same SPI surface across all three durability tiers." This is currently aspirational. The W0 in-memory `SyncOrchestrator` passes the child's return `Object` directly as `resumePayload` — a perfectly valid in-process design. However, a Postgres-backed orchestrator (W2) or Temporal-backed orchestrator (W4) would resume the parent in a potentially different JVM where that `Object` reference does not exist. §4 #13 now formally names this gap. W2 must define a byte-serialization contract for `resumePayload` as part of the Postgres orchestrator design. The SPI is not wrong; the constraint was simply not yet documented.

**On the C5 #2 finding (resume tenant isolation):** The current path in a single-JVM dev-posture deployment is safe because the `Orchestrator` holds the Run in memory through the full suspend/resume cycle. The hole only opens when resume happens across an HTTP boundary in W2+ persistence. §4 #14 and Rule 17 document this as a constraint that must be closed before any Postgres-backed resume path ships. This is not a W0 bug; it is a W2 pre-condition.

**On the C6 #3 finding (lambda serialization):** The inline-lambda shape of `NodeFunction`/`Reasoner` is correct and ergonomic for W0 and likely W2. It becomes a design conflict only at W4 Temporal, because Temporal's activity dispatch serializes the definition across the wire. §4 #15 documents the required migration path (named registry entries) without mandating premature design at W0.

**Re-review window:** The reviewer's core thesis — "cold-state fortress missing dynamic hub" — is substantively accepted. The 6 binding constraints in §4 #10–#15 constitute the dynamic-hub design commitment. Re-review opens at W2 close, when Postgres-backed persistence, streaming handoff, and resume re-authorization are all shipped.

---

## Status

| Field | Value |
|---|---|
| type | design_response |
| reviewer_doc | `docs/spring-ai-ascend-architecture-whitepaper-en.md` |
| response_sha | bf99770 (head at response time) |
| baseline_sha | 0c70964 (C34 — last code delivery reviewed) |
| constraints_added | ARCHITECTURE.md §4 #10–#15 |
| rules_added | Rule 15, Rule 16, Rule 17 (docs/CLAUDE-deferred.md) |
| yaml_rows_added | 13 design-accepted rows (docs/governance/architecture-status.yaml) |
| claims_accepted | 11 (with §4 constraint + YAML row) |
| claims_already_shipped | 2 (§3.1 node-snapshot, §3.2 interrupt nesting — C32–C34) |
| claims_rejected | 3 (§1.2 static SPI, §2.4 placeholder exemption, §5.3 delegate bidding) |
| hidden_defects_surfaced | 13 (4 C1, 4 C2, 4 C3, 5 C4, 4 C5, 3 C6) |
