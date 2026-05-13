# 0050. Workflow Intermediary Bus, Mailbox Backpressure, and Rhythm Track

**Status:** accepted
**Deciders:** architecture, chaos.xing.xc@gmail.com
**Date:** 2026-05-13
**Technical story:** Reviewer findings P0-3 and P0-4 (`docs/reviews/2026-05-13-whitepaper-alignment-remediation-proposal.en.md`): the whitepaper requires the Agent Bus to be a **workflow intermediary hub** with local supervisors, mailboxes, push-pull buffering, and backpressure — and to maintain **three physical channels** (Control / Data / Rhythm). ADR-0048 committed a transport split (data-P2P / control-event-bus) but did NOT define the local intermediary contract, mailbox semantics, or the "bus cannot force-start computation" rule. ADR-0048 also placed heartbeats on the centralized control event bus, collapsing the whitepaper's three-track design into two. This ADR closes both gaps by introducing the Workflow Intermediary contract and **restoring Rhythm as an independent third cross-service track**, with explicit `SleepDeclaration`, `WakeupPulse`, `TickEngine`, and `ChronosHydration` contracts.

## Context

The whitepaper (`docs/spring-ai-ascend-architecture-whitepaper-en.md`) §5.1–5.4 specifies:

- **Workflow Intermediary (Local Supervisor)** — the bus is stripped of authority to "force start" nodes; the bus only delivers intents and events. In front of every concrete compute node sits an extremely lightweight workflow intermediary that owns local admission control.
- **Push-Pull buffering with backpressure** — the bus PUSHES intents to a local mailbox; the local intermediary PULLS work based on its own memory level, token budgets, and skill saturation. This asynchronous decoupling forms a natural backpressure mechanism.
- **Three-track physical isolation** (whitepaper §5.2) — Control (high-priority out-of-band: KILL/PAUSE/RESUME/UPDATE_CONFIG), Data/Compute (heavy payloads, tool results, scraped text), and Heartbeat/Rhythm (survival signals, WAKEUP pulses, sleep declarations). Each track is **physically independent**.
- **Decentralized rhythm via Chronos Hydration** (whitepaper §5.4) — long-horizon agents declare sleep, self-destruct, and rely on the rhythm-track WAKEUP pulse to be rehydrated later. This dimensionally reduces long-horizon into countless safe instantaneous pull-ups.

ADR-0048 committed the Service Layer to microservice deployment and introduced a cross-service "data-P2P / control-event-bus" split, which is **directionally consistent** with the whitepaper but incomplete:

1. ADR-0048 did not name the **local intermediary** that pulls work from the bus. The transport split alone allows a broker to push work directly into a compute node, violating the whitepaper's push-pull contract.
2. ADR-0048 placed heartbeats on the central control event bus. The whitepaper specifically requires Rhythm to be an **independently protected channel** so WAKEUP pulses survive control-traffic congestion. Collapsing them is the failure mode the whitepaper warns about.

This ADR introduces the missing contracts and amends ADR-0048's heartbeat placement.

## Decision Drivers

- Reviewer P0-3: the bus must not force-start computation; the local intermediary owns admission.
- Reviewer P0-4: heartbeat/rhythm must be on an independently protected channel, not the control bus.
- Whitepaper §5.4 Chronos Hydration cannot work without an independent rhythm track and explicit `SleepDeclaration`/`WakeupPulse` contracts.
- ADR-0048's microservice commitment remains valid; this ADR adds the missing local-admission and rhythm-track contracts on top.

## Considered Options

1. **Introduce `WorkflowIntermediary` + restore Rhythm as an independent third cross-service track + amend ADR-0048 heartbeat placement** (this decision).
2. **Keep heartbeats on the control bus with priority partitioning** — rejected per reviewer P0-4: priority partitioning does not survive control-traffic congestion in the way an independent physical track does; the whitepaper's distinction is physical isolation, not logical priority.
3. **Push admission control into the central bus broker (force-start model)** — rejected per reviewer P0-3: this re-introduces the whitepaper §1.3 "Microservice Dictatorship" trap and contradicts the workflow-intermediary pattern.
4. **Defer Rhythm to W4+** — rejected: long-horizon Chronos Hydration (whitepaper §5.4) is a core architectural concept that needs naming at L0 even though implementation is W4+.

## Decision Outcome

**Chosen option:** Option 1.

### Workflow Intermediary contract (closes P0-3)

- **`WorkflowIntermediary`** — a per-Agent-Service local supervisor. **Required** in every Agent Service instance under the ADR-0048 microservice deployment. Responsibilities:
  - **Mailbox polling** — pulls work from the Agent Service's Mailbox; does NOT accept push-based execution.
  - **Local admission control** — decides accept/delay/reject/yield per current load, memory headroom, token budget, skill saturation, tenant quota.
  - **Lease checks** — verifies the bus-issued lease for each work item; rejects stale or revoked leases.
  - **Dispatch into in-process workers** — once admitted, hands the work to a virtual thread or worker pool inside the Agent Service instance.
  - **Backpressure signal emission** — when admission rejects/delays, emits `BackpressureSignal` back to the bus for scheduling feedback.
- **`IntentEvent`** — the central event-bus payload. Carries:
  - `capability` (the requested capability tag, resolves via `CapabilityRegistry` in ADR-0052)
  - `workClass` (e.g. `LONG_RUNNING`, `INTERACTIVE`, `BACKGROUND`)
  - `priority` (numeric or enum)
  - `tenantId`
  - `permissionEnvelopeRef` (reference to a `PermissionEnvelope` issued by the S-side per ADR-0052; NOT the envelope itself)
  - `pointerRefs[]` (URIs / SHA-256 references to heavy data; NOT inline payloads)
  - `leaseToken`, `intentExpiresAt`
- **No heavy payloads on intents.** Heavy data (LLM context, tool results, scraped documents) flows on the **Data track (P2P)** addressable via the `pointerRefs[]`.
- **`Mailbox`** — durable or semi-durable queue visible to the local `WorkflowIntermediary`. The bus enqueues; the intermediary pulls. Backed by the chosen event-bus substrate (Kafka topic partition / NATS JetStream stream / Redpanda topic — substrate choice deferred).
- **`AdmissionDecision`** — sealed:
  - `Accepted` — admit and dispatch.
  - `Delayed` — defer; reason: `LOCAL_BACK_PRESSURE | SKILL_SATURATION | TENANT_QUOTA | TRANSIENT_RESOURCE_PRESSURE`.
  - `Rejected` — refuse; reason: `INSUFFICIENT_PERMISSION | EXPIRED_LEASE | INTENT_MALFORMED | CAPABILITY_UNAVAILABLE`.
  - `Yielded` — the work was admitted previously and is now yielding back (e.g. mid-execution Skill saturation per ADR-0052 `SkillSaturationYield`).
- **`BackpressureSignal`** — emitted by the intermediary back to the bus to inform scheduling:
  - `LOCAL_SATURATION` (CPU / memory / virtual-thread pool exhaustion)
  - `SKILL_SATURATION` (an in-flight or planned skill is saturated at its quota; per ADR-0052)
  - `TENANT_QUOTA_EXCEEDED`
  - `SHUTDOWN` (graceful drain initiated)
- **`WorkStateEvent`** — emitted by the intermediary to the bus for cross-instance observability:
  - `Claimed | Running | Yielded | Succeeded | Failed | Cancelled | Expired`.
  - These compose with the `Run.RunStatus` DFA (Rule 20 / ADR-0020) — `WorkStateEvent` is the **cross-instance broadcast** of state transitions that already happen locally.

### Hard rule: bus MUST NOT force-start computation

The central event bus is **publishers and observers**, not a work executor. The contract:

- The bus enqueues `IntentEvent`s to `Mailbox`es.
- The bus emits `WorkStateEvent`s observed across instances.
- The bus delivers `ControlEvent`s and `WakeupPulse`s.
- The bus **MUST NOT** invoke any Agent Service instance's worker pool directly.
- The bus **MUST NOT** assume an enqueued `IntentEvent` will be executed; it MAY be `Delayed` or `Rejected` by the local intermediary.

This rule is the architectural guard against ADR-0048's "control event bus" being misread as a work-dispatching broker.

### Three-track cross-service bus (closes P0-4 — restores Rhythm)

ADR-0048 named two tracks (data-P2P / control-event-bus). The whitepaper requires three. This ADR restores the third track and reclassifies heartbeats.

#### Track 1 — Control (centralized event bus, high priority)

Carries: `PauseRun`, `KillRun`, `ResumeRun`, `UpdateConfig`, scheduling decisions, cancellation commands, safety commands.

- **Centralized broker** (event-bus substrate; choice deferred — Kafka / NATS JetStream / Redpanda).
- **High priority** — partition / topic tier reserved for control; published with priority routing where the substrate supports it.
- Receivers: every Agent Service instance subscribes to control events for its instance ID and for tenants it serves.

#### Track 2 — Data/Compute (P2P, NEVER on central broker)

Carries: heavy payloads, LLM context windows, tool call results, scraped documents, artifact blobs.

- **Point-to-point between Agent Service instances** (gRPC streaming over mTLS or equivalent).
- **Pointer-based**: when an `IntentEvent` references heavy data via `pointerRefs[]`, the receiving instance fetches the bytes directly from the originating instance (or a content-addressed object store) — never through the central broker.
- This is the whitepaper §5.2 protection against "network serialization disasters".

#### Track 3 — Heartbeat / Rhythm (independent, restored)

Carries: survival heartbeats, `TickEngine` tick events, `SleepDeclaration`, `WakeupPulse`, lease renewal heartbeats, `ChronosHydration` triggers.

- **Independently protected** from control-traffic congestion. Implementation MUST use a separate transport, partition, topic, or substrate (e.g. a dedicated NATS subject, a separate Kafka topic on a separate broker partition, or a lightweight gossip protocol).
- Cadence: heartbeats every `max(10s, min(30s, executorIterationBudget / 2))` (matching ADR-0031's in-process cadence).
- Failure mode: congestion in Track 1 (control) MUST NOT delay Track 3 (rhythm). If they share substrate, the substrate MUST provide physical isolation (separate brokers, separate partitions with dedicated network paths, or equivalent).

### Rhythm contracts (Chronos Hydration)

- **`SleepDeclaration`** — an agent's durable request to suspend compute until time/condition/external signal. Carries:
  - `runId`
  - `snapshotRef` (Checkpointer-stored snapshot identifier; see ADR-0021 Layer 3)
  - `wakeupCondition` ∈ {`AtTime(Instant)`, `OnEvent(eventType, predicate)`, `OnExternal(callbackToken)`}
  - `tenantId`
  - `leaseExpiry`
  - Emitted on Track 3 (rhythm).
- **`WakeupPulse`** — rhythm-track event that identifies a snapshot and asks a local intermediary to rehydrate.
  - `runId`
  - `snapshotRef`
  - `pulseReason` (e.g. `TIMER_FIRED`, `EVENT_TRIGGERED`, `EXTERNAL_CALLBACK`)
  - `tenantId`
  - **Idempotent** — the same pulse delivered twice MUST result in at most one rehydration.
- **`TickEngine`** — component responsible for durable timer evaluation. Lives outside any Agent Service instance (an independent platform service or a cross-service capability of the bus substrate). Reads `SleepDeclaration` registrations; emits `WakeupPulse` on the Rhythm track when conditions fire.
- **`ChronosHydration`** — the end-to-end flow:
  1. Agent completes phased work; emits `SleepDeclaration` on Rhythm track.
  2. Local `WorkflowIntermediary` confirms snapshot is durable (Checkpointer); releases compute resources.
  3. Agent Service instance MAY scale down (per ADR-0048; no forced scale-down at W0).
  4. `TickEngine` evaluates conditions over time.
  5. When fired, `TickEngine` emits `WakeupPulse` on Rhythm track.
  6. Scheduler routes the pulse to an Agent Service instance with capacity; the instance's `WorkflowIntermediary` admits the rehydration, loads the snapshot via `Checkpointer`, and resumes execution.

### Reconciliation with ADR-0031 and ADR-0048

#### ADR-0031 (in-process three-track SPI) — preserved

ADR-0031 defined `RunControlSink` (control), `Flux<RunEvent>` (data), `Flux<Instant>` (heartbeat) for the in-process HTTP/SSE northbound surface. That contract is **preserved unchanged**. This ADR extends the three-track model to **cross-service**: the same Track 1/Track 2/Track 3 split now applies between Agent Service instances on the bus, not just within a single instance's HTTP response stream.

ADR-0031's in-process SPI seam remains the boundary for the northbound HTTP/SSE surface (C-Side ↔ S-Side `SubStreamFrame` delivery per ADR-0049). The cross-service wire formats for the same three tracks are defined here.

#### ADR-0048 (microservice commitment) — amended (see ADR-0048 changes)

ADR-0048's "data-P2P / control-event-bus" split remains valid for Tracks 1 + 2. Heartbeats are **moved from Track 1 to Track 3** per this ADR's P0-4 restoration. ADR-0048 is amended in its own file with a forward note pointing here.

### Substrate choices (deferred)

This ADR locks the **track contract**; substrate selection is W2+ work. Candidates:

- **Track 1 (Control event bus)**: Kafka, NATS JetStream, Redpanda. Decision factors: ordering, durability, multi-tenant topic isolation, ops familiarity.
- **Track 2 (P2P data)**: gRPC streaming over mTLS, QUIC, custom binary transport. Decision factors: throughput, mTLS overhead, multiplexing.
- **Track 3 (Rhythm)**: dedicated NATS subject, separate Kafka topic on isolated partition, lightweight gossip (Serf / HashiCorp memberlist), or custom UDP heartbeat. Decision factors: independence from Track 1 congestion, low overhead, durability for `SleepDeclaration`.
- `TickEngine`: Temporal (already in BoM for W4), Quartz, Spring `@Scheduled` with persistent store, or a Redis-backed timer service. Decision factors: durability across `TickEngine` restarts, scale, missed-fire semantics.

### Out of scope

- Substrate selection (deferred to W2+).
- Java types for `WorkflowIntermediary`, `IntentEvent`, `Mailbox`, `BackpressureSignal`, `WorkStateEvent`, `SleepDeclaration`, `WakeupPulse`, `TickEngine` (Java types follow in a separate wave-tagged ADR/PR per reviewer non-goals).
- W4 Chronos Hydration implementation (Temporal-backed `TickEngine` or equivalent).

### Consequences

**Positive:**
- Reviewer P0-3 closed: the bus cannot force-start computation; `WorkflowIntermediary` owns admission; backpressure is explicit; future implementations cannot conflate "central event bus" with "direct work executor".
- Reviewer P0-4 closed: Rhythm is restored as an independent third cross-service track; heartbeats/WAKEUP pulses survive control-traffic congestion.
- `ChronosHydration` is named end-to-end; long-horizon agents have a path from sleep → self-destruct → wakeup → rehydrate.
- ADR-0048's microservice commitment is preserved; this ADR is additive (not a reversal).

**Negative:**
- Three substrates to operate (event bus + P2P transport + rhythm track) instead of two — additional ops surface. Mitigated by allowing Track 1 and Track 3 to share a substrate as long as physical isolation is maintained (separate partitions/topics with isolated network paths).
- `TickEngine` is a new platform service to operate, fund, and monitor. Mitigated by deferring impl to W4 and allowing Temporal (already in BoM) to back it.
- Local `WorkflowIntermediary` is a per-instance component; every Agent Service instance must include it.

### Acceptance criteria (reviewer P0-3 + P0-4)

- A future implementer **cannot** equate "central event bus" with "direct work executor" — Yes; the hard rule "bus MUST NOT force-start computation" is explicit.
- Architecture text states **where backpressure decisions are made** — Yes; the local `WorkflowIntermediary` owns admission; emits `BackpressureSignal`.
- Architecture text states **how a compute node refuses, delays, or yields work without losing the task** — Yes; via `AdmissionDecision` variants (`Delayed`, `Rejected`, `Yielded`) and `WorkStateEvent` broadcast.
- Active architecture cannot place heartbeats and WAKEUP pulses only on the same bus partition/priority class as general control traffic — Yes; Track 3 is independently protected and ADR-0048 is amended.
- A congestion failure in capability bidding cannot prevent survival heartbeats or wakeup pulses from being delivered — Yes; Track 3 is physically isolated from Track 1.
- ADR-0048 is amended so its two-track shorthand cannot override the whitepaper's rhythm-track requirement — Yes; see ADR-0048 amendment.

## References

- Reviewer source: `docs/reviews/2026-05-13-whitepaper-alignment-remediation-proposal.en.md` (findings P0-3 + P0-4)
- Whitepaper: `docs/spring-ai-ascend-architecture-whitepaper-en.md` §5.1, §5.2, §5.4
- ARCHITECTURE.md §4 #48 (this ADR's anchoring constraint)
- ADR-0031: in-process three-track channel isolation (preserved; extended cross-service here)
- ADR-0048: Service-Layer Microservice-Architecture Commitment (deployment topology; amended in same PR)
- ADR-0049: C/S Dynamic Hydration Protocol (companion; uses `YieldResponse` which composes with `SuspendReason` variants here)
- ADR-0052: Skill Topology Scheduler and Capability Bidding (defines `PermissionEnvelope` referenced by `IntentEvent`; defines `SkillSaturationYield` consumed by `WorkflowIntermediary`)
- Whitepaper alignment matrix: `docs/governance/whitepaper-alignment-matrix.md` — rows for Workflow Intermediary, Three-track bus, Capability bidding, Chronos Hydration
- `architecture-status.yaml` rows: `workflow_intermediary_bus`, `three_track_cross_service_rhythm`
