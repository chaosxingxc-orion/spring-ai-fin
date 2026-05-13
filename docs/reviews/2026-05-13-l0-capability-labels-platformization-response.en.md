# Response to L0 Capability-Labels + Platformization Review

**Date:** 2026-05-13
**Reviewer document:** `docs/reviews/2026-05-13-l0-capability-labels-platformization.en.md`
**Methodology:** **Class-based self-audit** (per the 6th+7th cycle discipline). Reviewer findings categorized into 8 defect classes; each class systematically audited; **hidden defects beyond reviewer's named symptoms surfaced and resolved or explicitly deferred**.
**Cycle:** 14th (cohesive swarm + long-connection containment + capability-labels review).

---

## Executive Summary

| Reviewer proposal | Disposition | Class | Resolution |
|-------------------|-------------|-------|------------|
| A. Cohesive Agent Swarm Execution (5 named contracts + §4 + ADR) | **PARTIAL ACCEPT** | Classes 1, 2, 3, 6 | ADR-0053 + §4 #51 |
| B. Long-Connection Containment (5 named contracts + §4 + ADR) | **PARTIAL ACCEPT** | Classes 1, 2, 7 | ADR-0054 + §4 #52 |
| C. Module Capability Labels (B / B' / B'' / P) | **REJECT taxonomy / ACCEPT direction** | Classes 4, 8 | Response doc only; no active-corpus changes |

**Hidden defects surfaced:** ~20 beyond the reviewer's 15 named items. Most material: **Class 3 (Spawn Lifecycle Propagation Completeness)** — 11 of 15 parent→child dimensions are missing/implicit. Reviewer named the boundary; class-based audit revealed the boundary's content was largely unspecified.

---

## Class 1 — Contract Naming / Vocabulary Gaps

### Reviewer-named items

| Concept | Disposition | Resolution |
|---------|-------------|------------|
| `SwarmRun` | PARTIAL ACCEPT | L0 alias for `Run` with `RunScope.SWARM` (ADR-0032). No new Java type. |
| `ParentRunRef` | PARTIAL ACCEPT | L0 alias for `Run.parentRunId` + `Run.parentNodeKey` (§4 #9). |
| `SpawnEnvelope` | **ACCEPT (new contract)** | New L0 contract consolidating 15 lifecycle dimensions. Java type deferred to W2. See Class 3. |
| `SwarmJoinPolicy` | PARTIAL ACCEPT | L0 alias for `JoinPolicy: ALL \| ANY \| N_OF` (ADR-0019 §4 #19). |
| `CrossWorkflowHandoff` | **ACCEPT (new contract)** | Genuinely missing escape-hatch contract. Java type deferred to W2. |
| `LogicalCallHandle` | ACCEPT (new naming) | Consolidates `Run` + `SuspendSignal` (§4 #9). |
| `ConnectionLease` | ACCEPT (new naming) | Consolidates three-track channel isolation (§4 #28, ADR-0031) + bus traffic split (§4 #46, ADR-0048). |
| `LongCallAdmissionPolicy` | **REDUNDANT-DOCUMENT** | Already exactly named as `AdmissionDecision` (ADR-0050). Both names cited; canonical is `AdmissionDecision`. |
| `ConnectionPressureSignal` | **REDUNDANT-DOCUMENT** | Already exactly named as `BackpressureSignal` (ADR-0050). Both names cited; canonical is `BackpressureSignal`. |
| `SuspendInsteadOfHold` | ACCEPT (new principle name) | Semantics existed in §4 #12 + `SuspendReason.RateLimited` (ADR-0019). Naming it makes the principle discoverable. |

### Hidden defect surfaced

**Class 1 hidden defect: Envelope pattern across 5+ boundaries — no discoverable catalog.** Audit found `PermissionEnvelope` (ADR-0052), `ResumeEnvelope` (ADR-0049), `SymbolicReturnEnvelope` (ADR-0051), `CausalPayloadEnvelope` (ADR-0028), and the proposed `SpawnEnvelope` — five Envelope types serving as authority-context carriers across boundaries. The pattern was emerging but not codified.

**Resolution:** ADR-0053 codifies the Envelope pattern explicitly in the 5-boundary authority-transfer taxonomy.

---

## Class 2 — Implicit Architecture Invariants Not Promoted to §4

### Reviewer-named items

| Invariant | Before | After |
|-----------|--------|-------|
| "Child work stays under same workflow authority by default" | Implicit in ADR-0032 §4 #29 (RunScope hierarchy) | Promoted to §4 #51 via ADR-0053 |
| "Long calls represented as bounded runtime handles, not unbounded threads/sockets" | Implicit across §4 #9/#12/#28/#46/#48 | Promoted to §4 #52 via ADR-0054 |
| "Suspend instead of hold" as named principle | Implicit in §4 #12 + `SuspendReason.RateLimited` | Named in ADR-0054 |

### Hidden defect surfaced

**Class 2 hidden defect: Authority transfer must be explicit at every boundary — no unifying §4 rule existed.** The architecture has 5 authority-transfer boundaries (HTTP→Runtime, C→S, Parent→Child, Run→Skill, Cross-Workflow), each with different propagation handling. There was no unifying §4 statement forbidding implicit transfer.

**Resolution:** ADR-0053 documents the 5-boundary taxonomy with named carriers; §4 #51 forbids implicit cross-workflow transfer.

---

## Class 3 — Spawn Lifecycle Propagation Completeness ⚠️ MAJOR HIDDEN-DEFECT CLUSTER

The reviewer requested `SpawnEnvelope` as a naming consolidation. The class-based audit revealed this is not just a naming exercise: **only 1 of 15 lifecycle dimensions is fully propagated parent→child today**.

### 15-Dimension Propagation Status

| # | Dimension | W0 status | Wave | Disposition |
|---|-----------|-----------|------|-------------|
| 1 | `parentRunRef` | ✅ Propagated | W0 shipped | OK |
| 2 | `tenantId` | ✅ Propagated via `RunContext.tenantId()` | W0 shipped | OK |
| 3 | `permissionEnvelopeRef` | ❌ Design gap | W2 contract | **Hidden defect — named in ADR-0053** |
| 4 | `budgetEnvelope` (tokenBudget, wallClockMs, cpuMillis, costCap) | ❌ Design gap (`call_tree_budget_propagation`) | W2 | **Hidden defect — named in ADR-0053** |
| 5 | `cancellationPolicy` (`ChildFailurePolicy`) | ⚠️ Sealed type exists; not carrier-wired | W2 | Documented |
| 6 | `deadline` | ⚠️ Mandated; watchdog deferred | W2 | Documented |
| 7 | `traceCorrelation` (traceparent + tracestate) | ❌ Design gap (OTel W2) | W2 | **Hidden defect — named in ADR-0053** |
| 8 | `attemptId` + retry policy | ⚠️ Field exists; child gets fresh `null` | W2 | Documented |
| 9 | `posture` | ⚠️ Implicit-only (global env var) | W1+ explicit | **Hidden defect — named in ADR-0053** |
| 10 | `sessionId` | ❌ Not in SPI (only in MemoryMetadata) | W2 | **Hidden defect — named in ADR-0053** |
| 11 | `businessRuleSubsetRef` (ADR-0049) | ❌ C/S-protocol only; not in S-Side SPI | W2 contract | **Hidden defect — named in ADR-0053** |
| 12 | `placeholderPolicy` (ADR-0051) | ❌ Not in spawn interface | W2 contract / W3 enforcement | **Hidden defect — named in ADR-0053** |
| 13 | `memoryOwnershipScope` (C/S split) | ❌ No accessible-memory marker on child | W2 contract | **Hidden defect — named in ADR-0053** |
| 14 | `idempotencyContext` | ⚠️ Child gets fresh `null` | W1 promotion | Documented |
| 15 | `observabilityTags` (Micrometer + audit) | ⚠️ Edge-only at W0 | W1 / W2 | Documented |

### Resolution

- Each dimension is **explicitly enumerated** in ADR-0053's `SpawnEnvelope` field set.
- Each gets a `architecture-status.yaml` row OR cross-reference to an existing row.
- W2 implementers cannot silently drop a dimension; the per-dimension wave-status is auditable.
- The `spawn_envelope_contract` yaml row carries the full 15-field-summary.

---

## Class 4 — Vocabulary Coherence & Collision Risk

### 17 named taxonomies already in the active corpus

The audit cataloged: RunStatus (7 states), RunMode (GRAPH/AGENT_LOOP), RunScope (STEP_LOCAL/SWARM), SuspendReason (6 sealed variants), ChildFailurePolicy (3), JoinPolicy (3), AdmissionDecision (4), APP_POSTURE (3), Deployment Locus (S-Cloud/S-Edge/C-Device), S-Side / C-Side (substitution authority), SemanticOntology (4), SkillTrustTier (2), SkillKind (3), MemoryMetadata categories (M1–M6), ActionGuard stages (5), BackpressureSignal reasons (4), WorkStateEvent (7), BusinessFactEvent semantics (3).

Two documented overlap pairs:
- S-Side/C-Side ↔ S-Cloud/S-Edge/C-Device — mitigated in ADR-0033.
- RunStatus ↔ WorkStateEvent — composed in ADR-0050.

### Reviewer-proposed B/B'/B''/P — REJECTED

**REJECT rationale:**
1. Would introduce a 3rd vocabulary collision: `B''` (business core asset, business-owned) overlaps with `C-Side ownership` (ADR-0051); `P` (platform-owned) overlaps with `S-Side` platform-owned scope.
2. The proposed 10 module names (Evolution Layer, Spring Capability Foundation, Heterogeneous Agent Framework Compatibility, Workflow Intermediary Core, Context Engine, Heterogeneous Execution Kernel, Enterprise Agent Middleware, Bus Layer, Gateway Layer, Business Application Domain) do not map to current Maven structure (`agent-platform`, `agent-runtime`, `spring-ai-ascend-graphmemory-starter`, `spring-ai-ascend-dependencies`).
3. Adopting the notation would create HISTORY-PARADOX risk: existing active docs say "C-Side"; new docs would say "B''". Future readers would have to learn two equivalent vocabularies.

### Mapping table (informational; not adopted)

| Proposed label | Existing equivalent |
|----------------|---------------------|
| `B''` (Business core asset, business-owned, do not absorb) | C-Side business ontology (ADR-0051) |
| `P` (Platform deterministic capability) | S-Side platform-owned (ADR-0048 Service Layer; ADR-0049 S-Side trajectory ownership) |
| `B'` (Business-driven, evolve to P) | S-Side capability that is W1+ deferred and will be platform-owned at delivery |
| `B` (Productization transition) | S-Side capability currently shipped as design-only / contract-level; will be platform-owned at W2 |

### Hidden defect surfaced

**Class 4 hidden defect: no gate rule prevents a 4th overlapping taxonomy in the future.** Future reviewers may propose yet another labeling system. Mitigation: a future Gate Rule 30 candidate (`taxonomy_collision_check`) could enforce a single source of truth per concept. Deferred — not blocking L0.

---

## Class 5 — Implementation Coupling Discipline

### Audit result

**No defects.** Sweep across `ARCHITECTURE.md`, all ADRs, and READMEs confirms:
- Netty / epoll: absent from active corpus.
- Specific technologies (Postgres, Temporal, Kafka, NATS JetStream, Redpanda, Redis/Valkey, Vault, Graphiti, mem0, Docling, langchain4j, Caffeine, Tika) are all properly wave-gated W1+/W2+ with explicit deferral status.
- Gate Rule 8 (`no_hardcoded_versions_in_arch`) is active and catches inline version pins.
- L0-contract version statements (Spring Boot 4.0.5, Spring AI 2.0.0-M5, Java 21) are in `pom.xml` BoM only, not in active prose.

**Reviewer's Netty/epoll disclaimer is reinforced** in ADR-0054 as an explicit "implementation guidance, NOT L0 contract" clause.

---

## Class 6 — Authority Boundary Crossings

### 5 boundaries cataloged

| Boundary | Carrier | Status before 14th cycle | Resolution |
|----------|---------|--------------------------|------------|
| HTTP edge → Runtime | `TenantContextFilter` → MDC → `RunContext.tenantId()` | W0 shipped (§4 #22, ADR-0023) | Documented in ADR-0053 |
| C-Side → S-Side | `HydrationRequest` / `ResumeEnvelope` | L0 contract (ADR-0049, §4 #47) | Documented in ADR-0053 |
| Parent Run → Child Run | `SpawnEnvelope` (proposed) | Incomplete (11 dimensions missing — Class 3) | **Named + 15-dimension contract in ADR-0053** |
| Run → External Skill | `PermissionEnvelope` | L0 contract (ADR-0052, §4 #50) | Documented in ADR-0053 |
| Cross-Workflow | — | **Missing carrier** | **`CrossWorkflowHandoff` named in ADR-0053** |

### Hidden defect surfaced

**Class 6 hidden defect: cross-workflow escape hatch was undefined.** Without an explicit `CrossWorkflowHandoff`, W1+ implementers could create implicit cross-workflow paths (e.g. "spawn a Temporal workflow as a child"; "delegate to an external partner's agent system") that bypass the workflow-authority invariant. ADR-0053 names the contract and requires audit-grade attestation on every cross-workflow transfer.

---

## Class 7 — Resource Containment Coverage

### Audit of resource-explosion vectors

| Vector | Coverage |
|--------|----------|
| Thread pool exhaustion | ✅ `SuspendSignal` releases threads (§4 #12, ADR-0019) |
| Socket exhaustion | ⚠️ **No per-tenant socket cap at L0** |
| Event-loop saturation | ✅ `AdmissionDecision.LOCAL_SATURATION` (ADR-0050) |
| Heartbeat starvation | ✅ Rhythm track (ADR-0050) |
| File descriptor exhaustion | ❌ **Not explicitly addressed** |
| Memory-per-Run | ⚠️ §4 #13 16-KiB inline cap; no aggregate cap |
| In-flight Runs pool size | ❌ **Not explicitly bounded at L0** |

### Hidden defects surfaced

**Class 7 hidden defects: three resource-explosion vectors not bounded.** The reviewer named `ConnectionPressureSignal` (already exists as `BackpressureSignal`), but the audit found three explicit gaps:

1. **Per-tenant socket cap** — one tenant could exhaust cross-instance P2P sockets.
2. **File-descriptor bound** — Tika parsing, sandbox temp files could exhaust fd table.
3. **In-flight Runs pool cap** — instance could accept Runs until JVM heap saturates.

**Resolution:** Each vector is named in ADR-0054 with explicit W1+ deferred status + dedicated `architecture-status.yaml` rows (`socket_per_tenant_cap`, `file_descriptor_bound`, `in_flight_runs_pool_cap`). Each row carries an explicit re-introduction trigger so the vector cannot be silently dropped during W1+ design.

---

## Class 8 — Strategic Ownership Evolution

### Reviewer's "all modules → P" direction

Already committed via existing ADRs:
- **ADR-0048 (Service-Layer Microservice Commitment, §4 #46):** Service Layer (S-Side) is platform-owned and platform-evolved. Equivalent to the reviewer's "P" direction for the platform layer.
- **ADR-0051 (Memory & Knowledge Ownership Boundary, §4 #49):** C-Side business ontology is business-owned (never absorbed into platform). Equivalent to the reviewer's "B'' remains business-owned" direction.

### Disposition

The strategic direction is **ALREADY in the architecture**. Adopting the B/B'/B''/P notation would add no information and create vocabulary collision (Class 4). The reviewer's intent is preserved via the existing ADRs.

---

## Acceptance Criteria — Reviewer's 14 Questions

### Agent Swarm Cohesion (7 questions, all answered in ADR-0053)

1. **When a parent agent spawns child work, who owns the child lifecycle?** Parent's workflow authority by default; §4 #51 + ADR-0053. Encoded via `ParentRunRef` field of `SpawnEnvelope`.
2. **How does cancellation propagate from parent to child?** Via `ChildFailurePolicy: PROPAGATE | IGNORE | COMPENSATE` carried in `SpawnEnvelope.cancellationPolicy` (W2 implementation); cited from ADR-0019 §4 #19. W0 reference impl: parent cancellation propagates to child via Orchestrator state-machine.
3. **How is child failure reflected in parent state?** Via `JoinPolicy: ALL | ANY | N_OF` (ADR-0019) + `ChildFailurePolicy` aggregation rules. W2 fan-out impl required for non-trivial cases.
4. **How are quota, cost, and trace attribution preserved?** Via `SpawnEnvelope` dimensions: `budgetEnvelope` (W2), `traceCorrelation` (W2), `tenantId` (W0 shipped), `observabilityTags` (W1+). Per-dimension status in ADR-0053 dimension table.
5. **What information must be carried in a spawn request?** All 15 dimensions in `SpawnEnvelope` (ADR-0053).
6. **When is cross-workflow execution allowed?** Only via explicit `CrossWorkflowHandoff` (ADR-0053). Implicit cross-workflow is forbidden by §4 #51.
7. **What makes cross-workflow execution explicit rather than accidental?** `CrossWorkflowHandoff` produces (a) new lifecycle boundary, (b) fresh resume contract, (c) explicit ownership transfer, (d) audit-grade attestation. Implicit cross-workflow execution fails §4 #51 by definition.

### Long-Connection Containment (7 questions, all answered in ADR-0054)

1. **What is the difference between a logical call and a physical connection?** A logical call is a `LogicalCallHandle` (`Run` + `SuspendSignal`) — a stable lifecycle identity. A physical connection is a `ConnectionLease` (Netty channel, HTTP client, SSE, WebSocket, gRPC stream, ...) — a transient transport resource. The architecture explicitly forbids 1:1 mapping.
2. **When may the runtime suspend instead of holding a connection?** Whenever useful compute is not happening. Implemented at W0 via `SuspendReason.RateLimited` and `SuspendReason.AwaitTimer` (ADR-0019). Named principle: `SuspendInsteadOfHold` (ADR-0054).
3. **How is backpressure exposed to the workflow layer?** Via `BackpressureSignal` (ADR-0050; reviewer-named `ConnectionPressureSignal` is the same contract). Variants: `LOCAL_SATURATION | SKILL_SATURATION | TENANT_QUOTA_EXCEEDED | SHUTDOWN`.
4. **How are tenant and global capacity considered before admitting long calls?** Two-axis arbitration (§4 #12): horizontal `TenantQuota` × vertical `GlobalSkillCapacity` (ADR-0052). Admission decision via `AdmissionDecision` (ADR-0050; reviewer-named `LongCallAdmissionPolicy` is the same contract).
5. **What happens when the connection/runtime pool is saturated?** `AdmissionDecision.Yielded` is returned; the Run yields the dependent step (not the whole Run) via `SuspendSignal` with `SuspendReason.RateLimited`. The LLM inference thread is released (§4 #12, ADR-0052 `SkillSaturationYield`).
6. **Which parts are L0 architecture contracts?** `LogicalCallHandle`, `ConnectionLease`, `AdmissionDecision`, `BackpressureSignal`, `SuspendInsteadOfHold`. All defined in §4 #52 + ADR-0054.
7. **Which parts are later-wave Netty/epoll implementation details?** Concrete transport mechanics — Netty channels, epoll, channel pools, event-loop schedulers. These are W2+ implementation guidance and MUST NOT appear as L0 contract (ADR-0054 explicit disclaimer).

---

## Closes

- Reviewer P0 (Agent Swarm cohesion) → ADR-0053 + §4 #51.
- Reviewer P0 (Long-connection containment) → ADR-0054 + §4 #52.
- Reviewer P1 (status-ledger rows for swarm + connection contracts) → 10 new rows in `docs/governance/architecture-status.yaml`.
- Reviewer P1 (release note language) → v2 release note updated with two new Architectural Commitments subsections + baseline bumped to 52/54.
- Reviewer P2 (truth-gate coverage) → Gate Rule 30 candidate documented as deferred (not blocking L0).
- Reviewer Section "L0 Module Capability Labels" → B/B'/B''/P notation REJECTED; strategic direction preserved via existing ADR-0048/0051.

### Hidden defects surfaced and resolved

- Class 1: Envelope pattern across 5 boundaries — codified.
- Class 2: Authority transfer must be explicit at every boundary — added 5-boundary taxonomy.
- Class 3: 11 of 15 spawn-propagation dimensions missing/implicit — enumerated in ADR-0053.
- Class 4: No gate against future taxonomy collision — deferred (Gate Rule 30 candidate).
- Class 6: Cross-workflow escape-hatch undefined — `CrossWorkflowHandoff` named.
- Class 7: Three resource-explosion vectors uncovered — named in ADR-0054 + yaml rows with re-introduction triggers.

---

## Verification

- `bash gate/check_architecture_sync.sh` → `GATE: PASS` (29/29 rules; Rule 28 verifies new 52/54 baseline).
- `bash gate/test_architecture_sync_gate.sh` → `Tests passed: 35/35`.
- `./mvnw -q verify -DskipITs=false` → exit 0 (no Java changes).
- Every cited §4 / ADR / file:line reference resolves.
- B/B'/B''/P notation does NOT appear in any active-corpus file (verified by grep).
