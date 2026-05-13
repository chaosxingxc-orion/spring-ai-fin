# L0 Architecture Proposal: Cohesive Agent Swarm Execution and Long-Connection Containment

Date: 2026-05-13

Audience: Architecture Design Team

Reviewer stance: Agent runtime architecture, workflow-engine boundary, long-running service-layer execution, and connection/resource containment.

Scope: Agent Swarm execution cohesion, subprocess/delegate spawning inside a workflow engine, long-running call connection containment, and the architectural boundary between workflow execution, agent services, and transport/runtime resources.

## Executive Verdict

The architecture should add two L0-level decisions before the agent runtime grows into W1/W2 implementation:

1. Agent Swarm execution must be cohesive by default.  
   When an agent run spawns child agents, delegates, sub-tasks, or tool-mediated subprocesses, those derived executions should remain inside the same workflow-engine authority boundary unless an explicit cross-engine handoff contract is used.

2. Long-running agent calls must be protected by a connection-containment model.  
   The platform should avoid one-task-one-blocking-connection or one-agent-one-dedicated-thread assumptions. Long-running calls, streaming responses, and suspended/resumable execution should be represented as managed runtime resources, not as unbounded physical connections.

These are L0 architecture-contract decisions, not W0 implementation requirements.

The proposal should not prescribe a full Netty pipeline, epoll configuration, channel pool implementation, or concrete scheduler algorithm at L0. Those belong to later implementation waves. L0 should instead define ownership, invariants, failure boundaries, and acceptance criteria so that future W1/W2/W3 work cannot accidentally create fragmented swarm execution or connection explosion.

A safe release statement after this proposal is accepted would be:

> L0 defines cohesive Agent Swarm execution and long-connection containment as architecture invariants. Child/delegate execution spawned by an agent run remains under the same workflow authority by default, and long-running calls are admitted through a bounded resource model rather than unbounded blocking connections. Concrete Netty, epoll, channel-pool, mailbox, and scheduler mechanics remain implementation-level decisions for later waves.

## Problem Statement

The current architecture is moving toward long-running Service Layer microservices and workflow-intermediary style execution. That direction is sound. However, two architectural gaps remain.

First, Agent Swarm execution can be misread as a set of loosely related agent processes. If a parent agent delegates work to child agents or subprocesses without a common workflow authority, the system risks losing unified lifecycle control, cancellation, checkpointing, quota accounting, traceability, and resume semantics.

Second, long-running agent calls can easily produce connection explosion. Enterprise agent workloads may hold streaming responses, tool calls, wakeup waits, human approval waits, or external system calls for long durations. If the architecture treats each long call as a dedicated blocking thread, direct socket, or independently owned process lane, runtime resources will scale with wait time rather than useful compute.

The architecture needs a minimal L0 contract for these two concerns before later waves add distributed scheduling, workflow intermediary mailboxes, skill bidding, memory recall, streaming, and cross-service hydration.

## Proposed L0 Decision 1: Cohesive Agent Swarm Execution

### Decision

Agent Swarm execution should be modeled as a cohesive workflow-owned execution tree.

When an agent run spawns child agents, delegates, sub-tasks, or subprocess-like work, the spawned execution must remain attached to the parent run's workflow authority unless the system explicitly performs a cross-workflow handoff.

This means the workflow engine owns the logical execution boundary for:

- parent-child run relationship;
- lifecycle state;
- cancellation and timeout propagation;
- checkpoint and resume coordination;
- quota and cost attribution;
- trace correlation;
- permission and capability inheritance;
- terminal-state aggregation.

The child execution may run in a different service instance, skill runtime, model gateway, or worker process. That physical placement does not change the logical rule: it is still part of the same workflow-owned execution tree unless explicitly handed off.

### L0 Contract Vocabulary

The architecture should introduce the following minimal vocabulary.

#### `SwarmRun`

A logical run that may contain one or more agent participants, delegated steps, or spawned child executions.

A `SwarmRun` is not a separate deployment unit. It is a lifecycle and traceability boundary.

#### `ParentRunRef`

A reference from a child execution back to the parent run or parent step that created it.

It must be sufficient for lifecycle propagation, trace correlation, quota attribution, and terminal-state aggregation.

#### `SpawnEnvelope`

The minimal contract used when a parent agent creates derived work.

It should carry:

- parent run reference;
- tenant and session boundary;
- requested capability or role;
- inherited constraints;
- permission envelope reference;
- budget or quota envelope;
- cancellation and timeout policy;
- trace/correlation identity;
- expected return mode.

#### `SwarmJoinPolicy`

The rule that defines how child results affect the parent run.

Examples:

- wait for all;
- wait for first successful;
- collect best effort;
- yield parent until child resumes;
- fail parent on critical child failure;
- isolate optional child failure.

L0 only needs to define that such a policy exists. It does not need to define a complete policy language.

#### `CrossWorkflowHandoff`

An explicit escape hatch when child execution is not owned by the same workflow authority.

This should be rare and must produce a new lifecycle boundary, new resume contract, and explicit ownership transfer.

### Required Architecture Rule

Add a Section 4 architecture constraint similar to:

> Agent-spawned child work must remain under the same workflow authority by default. A parent agent may spawn child agents, delegated tasks, or subprocess-like work only through a `SpawnEnvelope` that preserves parent-run reference, tenant boundary, permission scope, quota attribution, cancellation semantics, and trace correlation. Cross-workflow execution requires an explicit handoff contract and must not be implicit.

### Non-Goals

This decision does not require:

- a full distributed workflow engine in W0;
- a concrete child-agent scheduler;
- a specific actor model;
- a specific process model;
- per-agent microservices;
- mandatory Temporal, Cadence, Camunda, or another workflow engine;
- implementation of all swarm join policies.

The L0 requirement is contract shape and boundary discipline.

## Proposed L0 Decision 2: Long-Connection Containment via Managed Runtime Handles

### Decision

Long-running calls must be represented as managed runtime handles, not as unbounded physical connections.

The architecture should prohibit designs where each long-running agent call, streaming task, human wait, external tool wait, or child-agent wait requires a dedicated blocking thread or unbounded persistent socket.

Instead, the platform should define a connection-containment boundary:

- logical calls are represented as resumable run handles;
- physical connections are pooled, multiplexed, bounded, or released when possible;
- long waits become workflow state, mailbox state, checkpoint state, or rhythm/wakeup state;
- admission control prevents connection and thread explosion;
- backpressure is visible at the run/workflow level.

Spring-integrated Netty, Linux epoll, non-blocking IO, channel pooling, and event-loop based execution are acceptable implementation directions, but they should not be hard-coded as the L0 contract. L0 should only require that the runtime has a bounded, observable, backpressure-aware resource model for long-running calls.

### L0 Contract Vocabulary

#### `LogicalCallHandle`

A stable logical reference to a long-running operation.

It is not equivalent to a TCP connection, thread, or Netty channel.

A logical call may be active, suspended, streaming, waiting for external input, waiting for child execution, or resumable.

#### `ConnectionLease`

A bounded claim on physical transport resources.

The lease may be backed by Netty channels, HTTP clients, SSE connections, WebSocket sessions, gRPC streams, or other transports in later waves.

L0 should define the lease concept, not the transport implementation.

#### `LongCallAdmissionPolicy`

The runtime rule that decides whether a new long-running call may start, wait, be queued, be degraded, or yield.

The policy should consider:

- tenant quota;
- global connection capacity;
- per-skill or per-model capacity;
- stream count;
- expected duration;
- priority;
- cancellation sensitivity;
- posture and trust tier.

#### `ConnectionPressureSignal`

A signal emitted when the runtime approaches or exceeds safe capacity.

Examples:

- too many active streams;
- channel-pool saturation;
- event-loop saturation;
- per-tenant quota saturation;
- too many suspended-but-retained calls;
- heartbeat/rhythm delay risk.

#### `SuspendInsteadOfHold`

The rule that a long wait should become a suspended workflow state when useful compute is not happening.

This prevents idle waits from consuming scarce physical resources.

### Required Architecture Rule

Add a Section 4 architecture constraint similar to:

> Long-running agent calls must be admitted through a bounded runtime-resource model. The architecture must not assume one logical call equals one blocking thread, one dedicated socket, or one independently retained connection. Logical calls must be represented by runtime handles that can be suspended, resumed, streamed, cancelled, and accounted for independently from the physical connection used at any moment.

### Implementation Guidance, Not L0 Contract

The following wording can be added as guidance without making it a hard L0 dependency:

> A Spring-integrated Netty runtime, using native Linux epoll where available, is the preferred later-wave implementation direction for high-concurrency long-running calls. This is an implementation strategy for the connection-containment contract, not the contract itself.

This keeps the proposal aligned with the desired direction while avoiding premature implementation coupling.

## Architecture Fit

### Fit with Workflow Intermediary

Cohesive Agent Swarm execution complements the workflow intermediary pattern.

The central bus or workflow scheduler should not directly force-start arbitrary child work. Instead, it should create intent or spawn envelopes. Local workflow intermediaries or service runtimes perform admission, leasing, and dispatch.

This gives the architecture a clean separation:

- workflow authority owns lifecycle;
- local intermediary owns admission;
- physical runtime owns connection/resource containment;
- agent logic owns reasoning and delegation decisions within policy.

### Fit with C/S Hydration

The C-side remains the owner of business task goals and business constraints.

The S-side may spawn child work only inside the hydrated runtime boundary and only within the C-side-provided constraints.

A spawned child must not silently broaden the business goal, acquire new business authority, or persist business ontology outside the approved ownership boundary.

### Fit with Skill Scheduling

Agent-spawned child work should become schedulable demand, not immediate physical execution.

A parent agent can request a capability, but the runtime decides whether that capability is admitted now, queued, yielded, or rejected.

This avoids a design where agent swarm expansion directly causes uncontrolled skill, model, thread, or connection fan-out.

### Fit with Streaming and Rhythm Track

Streaming should be a logical output mode, not proof that a physical connection must remain attached forever.

If a run yields, sleeps, waits for approval, waits for a child, or waits for external IO, the runtime may release or downgrade physical resources and later resume through heartbeat/rhythm or mailbox mechanisms.

## Risks If Not Addressed

### Risk 1: Fragmented Swarm Lifecycle

Without cohesive swarm execution, child agents can become detached from parent workflow state.

Consequences:

- cancellation does not propagate;
- parent run finishes while children continue;
- child failure is not aggregated;
- trace trees become incomplete;
- quota and cost accounting are wrong;
- resume cannot reconstruct the full execution tree.

### Risk 2: Connection Explosion

Without connection containment, long-running tasks scale physical resource usage with wall-clock duration.

Consequences:

- thread pool exhaustion;
- socket exhaustion;
- event-loop saturation;
- backpressure hidden until failure;
- heartbeat starvation;
- cancellation delay;
- degraded tenant isolation.

### Risk 3: Implicit Business Authority Expansion

Without spawn envelopes and inherited constraints, child agents may acquire broader capability than the parent was allowed to use.

Consequences:

- permission leakage;
- policy bypass;
- unsafe tool access;
- unclear audit responsibility;
- business-goal mutation.

### Risk 4: Over-Coupling L0 to One Runtime Implementation

If L0 directly mandates Netty/epoll mechanics, the architecture may become over-specific.

Consequences:

- implementation detail becomes contract;
- alternate transports become unnecessarily difficult;
- tests assert pipeline mechanics rather than architecture invariants;
- W0/W1 work becomes heavier than needed.

The proposal should therefore make Netty/epoll the preferred implementation direction, not the L0 abstraction.

## Required Remediation

### P0: Add an Agent Swarm Cohesion ADR

Create a new ADR, tentatively:

`ADR-005X-agent-swarm-cohesive-workflow-execution.md`

It should define:

- `SwarmRun`;
- `ParentRunRef`;
- `SpawnEnvelope`;
- `SwarmJoinPolicy`;
- `CrossWorkflowHandoff`;
- lifecycle propagation rules;
- cancellation and timeout propagation;
- quota and trace attribution;
- permission inheritance and restriction;
- non-goals for W0.

### P0: Add a Long-Connection Containment ADR

Create a new ADR, tentatively:

`ADR-005Y-long-connection-containment-runtime-handles.md`

It should define:

- `LogicalCallHandle`;
- `ConnectionLease`;
- `LongCallAdmissionPolicy`;
- `ConnectionPressureSignal`;
- `SuspendInsteadOfHold`;
- relationship to streaming, heartbeat/rhythm, workflow mailboxes, and checkpoint/resume;
- Netty/epoll as preferred later-wave implementation guidance, not L0 contract.

### P1: Update Root Architecture Constraints

Add two Section 4 constraints:

1. Agent-spawned child work remains under the same workflow authority by default.
2. Long-running calls must be represented by bounded logical runtime handles, not unbounded physical connections.

### P1: Update Architecture Status Ledger

Add governance rows for:

- `agent_swarm_cohesive_execution`;
- `spawn_envelope_contract`;
- `long_connection_containment`;
- `logical_call_handle`;
- `connection_pressure_signal`.

Each row should state whether it is:

- shipped;
- active design;
- deferred;
- implementation guidance;
- or rejected.

### P1: Add Release Note Language

The L0 release note should not claim that full swarm scheduling or Netty-based connection management is implemented.

It may claim only:

- cohesive swarm execution is accepted as an architecture invariant;
- long-connection containment is accepted as an architecture invariant;
- implementation is staged for later waves.

### P2: Add Truth-Gate Coverage Later

Later gates should detect active documents that:

- describe child-agent spawning without parent workflow reference;
- imply child work can escape tenant, quota, permission, or trace inheritance;
- equate logical calls with blocking physical connections;
- claim Netty/epoll is shipped before implementation exists;
- claim connection containment without any admission/backpressure contract.

## Acceptance Criteria

This proposal is accepted when active architecture documents can answer the following questions.

### Agent Swarm Cohesion

1. When a parent agent spawns child work, who owns the child lifecycle?
2. How does cancellation propagate from parent to child?
3. How is child failure reflected in parent state?
4. How are quota, cost, and trace attribution preserved?
5. What information must be carried in a spawn request?
6. When is cross-workflow execution allowed?
7. What makes cross-workflow execution explicit rather than accidental?

### Long-Connection Containment

1. What is the difference between a logical call and a physical connection?
2. When may the runtime suspend instead of holding a connection?
3. How is backpressure exposed to the workflow layer?
4. How are tenant and global capacity considered before admitting long calls?
5. What happens when the connection/runtime pool is saturated?
6. Which parts are L0 architecture contracts?
7. Which parts are later-wave Netty/epoll implementation details?

## Suggested Architecture Constraint Text

### Constraint: Cohesive Agent Swarm Execution

Agent-spawned child work must remain under the same workflow authority by default. A parent agent may create child agents, delegated tasks, or subprocess-like work only through a spawn contract that preserves parent-run reference, tenant boundary, permission scope, quota attribution, cancellation semantics, timeout policy, and trace correlation. Cross-workflow execution requires an explicit handoff contract and must not occur implicitly.

### Constraint: Long-Connection Containment

Long-running agent calls must be admitted through a bounded runtime-resource model. The architecture must not assume that one logical call equals one blocking thread, one dedicated socket, or one permanently retained physical connection. Logical calls must be represented by runtime handles that can be suspended, resumed, streamed, cancelled, and accounted for independently from the physical connection used at any moment.

## Suggested ADR Summary Text

### ADR-005X Summary

We accept cohesive Agent Swarm execution as an L0 architecture invariant. Child or delegated work spawned during an agent run remains inside the parent workflow authority by default. This preserves lifecycle control, cancellation, quota attribution, permission inheritance, trace correlation, and resume semantics. Physical execution may be distributed, but logical ownership remains workflow-cohesive unless an explicit cross-workflow handoff is performed.

### ADR-005Y Summary

We accept long-connection containment as an L0 architecture invariant. Long-running calls are represented as logical runtime handles and admitted through bounded resource policies. Physical connections, event loops, channels, streams, and threads are implementation resources that must be pooled, leased, multiplexed, released, or backpressured. Spring-integrated Netty with Linux epoll is the preferred later-wave implementation direction, but L0 only standardizes the containment contract.

# L0 Module Capability Labels and Target Evolution Direction

## 1. Current Classification

| L0 Module | Current Label | Current Ownership |
|---|---:|---|
| Business Application Domain | B'' | Deterministically owned by the business side |
| Gateway Layer | P | Deterministically owned by Enterprise IT / Platform team |
| Bus Layer | P | Deterministically owned by Enterprise IT / Platform team |
| Evolution Layer | B' | Business-driven capability |
| Spring Capability Foundation | B' | Business-driven / customer IT adaptation capability |
| Heterogeneous Agent Framework Compatibility | B | Productization transition capability |
| Workflow Intermediary Core | B | Productization transition capability |
| Context Engine | B | Productization transition capability |
| Heterogeneous Execution Kernel | B' | Business-driven execution capability |
| Enterprise Agent Middleware | P | Deterministically owned by Enterprise IT / Platform team |

---

## 2. Target Evolution Direction

| L0 Module | Current Label | Target Label | Evolution Direction |
|---|---:|---:|---|
| Business Application Domain | B'' | B'' | Remains deterministically owned by the business side and should not be converted into platform ownership |
| Gateway Layer | P | P | Already a deterministic platform capability |
| Bus Layer | P | P | Already a deterministic platform capability |
| Evolution Layer | B' | P | Evolves from a business-driven capability into a platform-level evolution / data-flywheel capability |
| Spring Capability Foundation | B' | P | Evolves from customer IT adaptation into a standardized platform foundation |
| Heterogeneous Agent Framework Compatibility | B | P | Evolves from project-level compatibility work into a platform-level Agent Framework Adapter |
| Workflow Intermediary Core | B | P | Evolves from a productization transition capability into a platform-level Workflow / Agent Runtime |
| Context Engine | B | P | Evolves from a productization transition capability into a platform-level Context Runtime |
| Heterogeneous Execution Kernel | B' | P | Evolves from a business-driven execution capability into a platform-level heterogeneous execution kernel |
| Enterprise Agent Middleware | P | P | Already a deterministic platform capability |

---

## 3. Label Semantics

| Label | Meaning |
|---|---|
| B'' | Business core asset. It is deterministically owned by the business side and remains outside platform ownership. |
| B' | Business-driven capability. It is initially shaped by business scenarios and customer IT conditions, but should evolve into platform capability once stable patterns emerge. |
| B | Productization transition capability. It is temporarily carried by product / delivery work and should eventually converge into platform capability. |
| P | Platform deterministic capability. It is owned, governed, operated, and evolved by Enterprise IT / Platform teams. |

---

## 4. Evolution Rule

| Current Label | Target Label | Rule |
|---|---:|---|
| B'' | B'' | Business core assets remain owned by the business side and should not be absorbed into P. |
| B' | P | Business-driven capabilities should be platformized after their reusable patterns become stable. |
| B | P | Productization transition capabilities should converge into standardized platform capabilities. |
| P | P | Platform deterministic capabilities remain platform-owned. |

---

## 5. One-Sentence Summary

The target evolution direction of Spring-AI-Ascend is: **except for the Business Application Domain, which remains B'' and is deterministically owned by the business side, all other L0 modules should eventually evolve into P and become platform capabilities owned, governed, and operated by Enterprise IT / Platform teams.**
