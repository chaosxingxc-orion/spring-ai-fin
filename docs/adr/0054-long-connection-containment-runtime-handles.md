# 0054. Long-Connection Containment — Logical Runtime Handle Invariant

**Status:** accepted
**Deciders:** architecture, chaos.xing.xc@gmail.com
**Date:** 2026-05-13
**Technical story:** Reviewer finding P0 (`docs/reviews/2026-05-13-l0-capability-labels-platformization.en.md`): an architecture review proposed naming five L0 contracts for "long-connection containment via managed runtime handles" — `LogicalCallHandle`, `ConnectionLease`, `LongCallAdmissionPolicy`, `ConnectionPressureSignal`, `SuspendInsteadOfHold` — and requested that "long-running calls must be admitted through a bounded runtime-resource model" be promoted to a §4 architecture constraint. The reviewer also flagged Netty/epoll as implementation guidance, NOT L0 contract. The class-based self-audit (14th cycle) found that **5 of 5 concepts already exist semantically**, with `AdmissionDecision` (ADR-0050) and `BackpressureSignal` (ADR-0050) already exactly named, but **three resource-explosion vectors are uncovered**: socket-per-tenant cap, file-descriptor bound, in-flight Runs pool cap.

## Context

Existing connection-containment semantics:

- `Run` entity (W0 shipped) + `SuspendSignal` checked exception (ADR-0019, §4 #19) — together form a logical-call-handle model: the Run is the lifecycle identity; the SuspendSignal is the one interrupt primitive that releases physical resources without losing the logical call.
- §4 #11 — three-mode northbound handoff: synchronous `Object` return (W0 shipped), streamed `Flux<RunEvent>` (W2 deferred), yield-via-`SuspendSignal` (W0 shipped).
- §4 #12 — two-axis resource arbitration (`tenantQuota`, `globalSkillCapacity`). Skill saturation MUST suspend (`SUSPENDED + suspendedAt + reason=RateLimited`) rather than fail.
- §4 #19 — `SuspendReason.RateLimited(String resourceKey, Instant retryAfter)` is the canonical "step yields when resource is saturated" primitive.
- §4 #28 — three-track channel isolation (Control / Data / Heartbeat) with bounded buffers (default 64 events, DROP_OLDEST overflow; Terminal events never dropped).
- §4 #46 — Service-Layer Microservice Commitment: data-P2P / control-event-bus split; bounded cross-instance traffic.
- §4 #48 — Workflow Intermediary + Mailbox Backpressure: `AdmissionDecision: Accepted | Delayed | Rejected | Yielded`; `BackpressureSignal: LOCAL_SATURATION | SKILL_SATURATION | TENANT_QUOTA_EXCEEDED | SHUTDOWN`.

**Class-based audit findings:**

| Reviewer-named concept | Semantic backing in current architecture |
|------------------------|-------------------------------------------|
| `LogicalCallHandle` | `Run` (lifecycle entity) + `SuspendSignal` (interrupt primitive). §4 #9. |
| `ConnectionLease` | Three-track channel isolation + bounded buffers (§4 #28, ADR-0031). Bus traffic split (§4 #46, ADR-0048). |
| `LongCallAdmissionPolicy` | **`AdmissionDecision` is already this exact contract** (ADR-0050, §4 #48). |
| `ConnectionPressureSignal` | **`BackpressureSignal` is already this exact contract** (ADR-0050, §4 #48). |
| `SuspendInsteadOfHold` | Implicit in §4 #12 ("skill saturation MUST suspend") + `SuspendReason.RateLimited` (ADR-0019). Never named as an explicit principle. |

**Hidden-defect cluster surfaced:** three resource-explosion vectors are not explicitly bounded at L0:

1. Socket exhaustion per tenant (no per-tenant socket cap).
2. File-descriptor exhaustion (not explicitly addressed).
3. In-flight Runs pool size per instance (not bounded — an instance could accept Runs until JVM heap saturates).

These are W1+ implementation concerns but they are part of the long-connection containment contract surface and must be named so they aren't silently dropped during W1/W2 design.

## Decision Drivers

- Reviewer P0: name the long-connection contracts as L0 vocabulary; promote the invariant to §4.
- Reviewer P1: Netty / epoll must be implementation guidance, NOT L0 contract.
- Class-based audit P1 (hidden): three uncovered resource-explosion vectors must be named at L0 so they receive explicit W1+ wave-status, not implicit drift.
- Avoid duplication: `AdmissionDecision` and `BackpressureSignal` already exist with exact semantics — cross-reference rather than rename.
- Name `SuspendInsteadOfHold` as a discoverable principle so future implementers can cite the rule.

## Considered Options

1. **New ADR consolidating the 5 names + naming `SuspendInsteadOfHold` + documenting 3 uncovered vectors + Netty/epoll disclaimer** (this decision).
2. Extend ADR-0050 in place — rejected: would conflate the Workflow Intermediary contract (specific to cross-service bus) with the broader containment invariant (covers in-process too).
3. Defer to W2 — rejected: leaves the containment invariant unstated; permits implementers to silently introduce one-call-one-thread assumptions.
4. Rename `AdmissionDecision` to `LongCallAdmissionPolicy` — rejected: would force a renumbering of ADR-0050 and break existing code references; the simpler answer is "the reviewer's name and our existing name describe the same contract" and cite both.

## Decision Outcome

**Chosen option:** Option 1.

### The five contract names

| Contract | Status | Maps to existing |
|----------|--------|-------------------|
| `LogicalCallHandle` | Alias at L0 contract level | `Run` (W0 shipped) + `SuspendSignal` (W0 shipped). The Run is the stable identity for a long call; the SuspendSignal is the suspend mechanism. A `LogicalCallHandle` is NOT equivalent to a TCP connection, thread, or Netty channel. |
| `ConnectionLease` | Alias at L0 contract level | Three-track channel isolation (§4 #28, ADR-0031) + bounded buffers + bus traffic split (§4 #46, ADR-0048). Implementation may back the lease with Netty channels, HTTP clients, SSE connections, WebSocket sessions, or gRPC streams. L0 standardizes the lease concept, not the transport. |
| `LongCallAdmissionPolicy` | **Exact existing contract: `AdmissionDecision`** (ADR-0050) | The runtime rule that decides whether a new long-running call may start, wait, be queued, be degraded, or yield. Variants: `Accepted \| Delayed \| Rejected \| Yielded`. Considers: tenant quota, global connection capacity, per-skill / per-model capacity, stream count, expected duration, priority, cancellation sensitivity, posture, trust tier. |
| `ConnectionPressureSignal` | **Exact existing contract: `BackpressureSignal`** (ADR-0050) | The signal emitted when the runtime approaches or exceeds safe capacity. Variants: `LOCAL_SATURATION \| SKILL_SATURATION \| TENANT_QUOTA_EXCEEDED \| SHUTDOWN`. Additionally: too-many-active-streams, channel-pool-saturation, event-loop-saturation, suspended-but-retained-call cap, heartbeat-delay risk (Rhythm track per ADR-0050). |
| `SuspendInsteadOfHold` | **New named principle** | A long wait MUST become a suspended workflow state when useful compute is not happening. Implemented at W0 via `SuspendReason.RateLimited` (ADR-0019) and `SuspendReason.AwaitTimer` (ADR-0019). The principle: idle waits must NOT consume scarce physical resources (threads, sockets, connections, event-loop slots). |

### Required architecture rule (§4 #52)

> **Long-Connection Containment.** Long-running agent calls must be admitted through a bounded runtime-resource model. The architecture MUST NOT assume one logical call equals one blocking thread, one dedicated socket, or one permanently retained physical connection. Logical calls are represented by runtime handles (`LogicalCallHandle` ≡ `Run` + `SuspendSignal`) that can be suspended, resumed, streamed, cancelled, and accounted for independently from the physical connection used at any moment. Admission control is enforced via `AdmissionDecision` (`Accepted | Delayed | Rejected | Yielded` — ADR-0050); resource pressure is signaled via `BackpressureSignal` (ADR-0050); idle waits MUST follow `SuspendInsteadOfHold` (suspend, not block — §4 #12, ADR-0019). Concrete transport mechanics (Netty, epoll, channel pools, event-loop schedulers) are W2+ implementation guidance and MUST NOT appear as L0 contract.

### Uncovered resource-explosion vectors (W1+ deferred items)

The class-based audit identified three vectors that are NOT bounded at L0. Each is added to the architecture status ledger with explicit deferred wave-status:

| Vector | Wave | Yaml row |
|--------|------|----------|
| Per-tenant socket cap | W1+ | `socket_per_tenant_cap` (status: design_accepted; shipped: false) |
| File-descriptor bound (per-instance + per-tenant fairness) | W1+ | `file_descriptor_bound` (status: design_accepted; shipped: false) |
| In-flight Runs pool cap per Agent Service instance | W1+ | `in_flight_runs_pool_cap` (status: design_accepted; shipped: false) |

These are NOT new SPI contracts — they are operational bounds that the W1+ deployment must enforce. Naming them here prevents future drift where an implementer assumes "the runtime model is bounded" without verifying the specific vectors.

### Implementation guidance, NOT L0 contract

The following wording is recorded as W2+ implementation guidance:

> A Spring-integrated Netty runtime, using native Linux epoll where available, is the preferred later-wave implementation direction for high-concurrency long-running calls. This is an implementation strategy for the connection-containment contract, not the contract itself. The L0 contract standardizes the `LogicalCallHandle` / `ConnectionLease` / `AdmissionDecision` / `BackpressureSignal` / `SuspendInsteadOfHold` semantics; the transport may be Netty/epoll, alternative non-blocking IO, or another mechanism that satisfies the same invariants.

Netty/epoll MUST NOT be cited as a hard L0 dependency in any active normative document. Gate Rule 8 (`no_hardcoded_versions_in_arch`) catches version-pinned coupling; reviewers must catch named-tech coupling that does not pin a version.

### Non-Goals

This decision does NOT require:

- A Netty implementation at W0.
- A specific channel-pool algorithm.
- A specific event-loop topology.
- New SPI surfaces beyond the cross-reference of existing types.
- Implementation of the three deferred vectors (W1+ work).

The L0 requirement is naming + invariant statement + deferred-vector visibility.

## Consequences

**Positive:**
- Long-connection containment is now a hard §4 constraint (#52), enforceable at gate time.
- `SuspendInsteadOfHold` is a discoverable principle name; future reviewers can cite it directly.
- Three uncovered resource-explosion vectors are visible in the ledger; they cannot be silently dropped during W1+ design.
- Netty/epoll disclaimer is explicit and prevents implementation coupling at L0.
- `AdmissionDecision` and `BackpressureSignal` are confirmed as the canonical names; the reviewer's `LongCallAdmissionPolicy` / `ConnectionPressureSignal` are documented as aliases so future readers connecting from the reviewer's vocabulary can find the canonical types.

**Negative:**
- Two terminologies for the same contracts (`AdmissionDecision` vs `LongCallAdmissionPolicy`; `BackpressureSignal` vs `ConnectionPressureSignal`) — risk of confusion. Mitigation: this ADR explicitly states the mapping; future docs use canonical names with the alias noted on first mention if needed.
- Three deferred vectors remain implementation TODOs; if W1+ work skips them, they could re-introduce resource explosion. Mitigation: yaml rows + ADR text + this ADR's reference list ensure visibility.

## References

- `ARCHITECTURE.md` §4 #52 — the constraint this ADR anchors.
- `ARCHITECTURE.md` §4 #9 — dual-mode runtime + interrupt-driven nesting (Run + SuspendSignal as the logical-call-handle model).
- `ARCHITECTURE.md` §4 #11 — three-mode northbound handoff.
- `ARCHITECTURE.md` §4 #12 — two-axis resource arbitration; skill saturation suspends rather than fails.
- `ARCHITECTURE.md` §4 #19 — SuspendReason taxonomy (RateLimited as `SuspendInsteadOfHold` primitive).
- `ARCHITECTURE.md` §4 #28 — three-track channel isolation.
- `ARCHITECTURE.md` §4 #46 — Service-Layer Microservice Commitment (data-P2P / control-event-bus split).
- `ARCHITECTURE.md` §4 #48 — Workflow Intermediary + Mailbox Backpressure (AdmissionDecision, BackpressureSignal, Rhythm track).
- ADR-0019 — SuspendReason taxonomy.
- ADR-0031 — Three-track channel isolation.
- ADR-0048 — Service-Layer Microservice Commitment.
- ADR-0050 — Workflow Intermediary + Mailbox Backpressure + Rhythm Track.
- ADR-0052 — Skill Topology Scheduler and Capability Bidding (SkillSaturationYield).
- `docs/reviews/2026-05-13-l0-capability-labels-platformization.en.md` — reviewer input.
- `docs/reviews/2026-05-13-l0-capability-labels-platformization-response.en.md` — class-organized response.
