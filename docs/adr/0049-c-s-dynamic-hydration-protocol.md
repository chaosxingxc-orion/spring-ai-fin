# 0049. C/S Dynamic Hydration Protocol and Cursor Handoff

**Status:** accepted
**Deciders:** architecture, chaos.xing.xc@gmail.com
**Date:** 2026-05-13
**Technical story:** Reviewer finding P0-2 (`docs/reviews/2026-05-13-whitepaper-alignment-remediation-proposal.en.md`): the whitepaper's central agent contract is C/S separation with a lightweight C-side `Task Cursor` and an S-side dynamic hydration engine. Current L0 architecture contains orchestration SPI contracts and microservice topology, but it does NOT define the wire vocabulary, ownership boundary, or handoff protocol for `Task Cursor + Business Rule Subset + Available Skill Pool Limitations`. `RunContext` is an internal S-side execution context and is NOT the C/S protocol. Reviewer P1-2 (degradation authority red line) is incorporated into the same ADR because it shares the C/S boundary semantics.

## Context

The whitepaper (`docs/spring-ai-ascend-architecture-whitepaper-en.md`) §2.1–2.4 defines a Client/Server separation with two ownership domains:

- **C-Side (Business Application Side / Business Brain)** — lives inside specific business systems (CRM, OA, intelligent customer service workbench, etc.); holds business goals, task completion status, strict business rules, long-term business knowledge and ontology; carries only a lightweight **Task Cursor**.
- **S-Side (Platform Runtime Side / Compute Factory)** — `spring-ai-ascend` itself; long-lived; multi-tenant; carries the **Context Engine**; closes the loop on tool-call chains, LLM Chain-of-Thought planning, and user-guided dialogue flow.

Communication between the two domains is **not** a heavy full-data packaging but a cursor-handoff protocol based on **Dynamic Hydration**. The C-Side sends `Task Cursor + Business Rule Subset + Available Skill Pool Limitations`; the S-Side hydrates the request into a runtime context, executes, and returns one of three handoff modes.

The reviewer observed that none of this is currently named in active architecture artifacts. The orchestration SPI (`Orchestrator`, `RunContext`, `SuspendSignal`, `Checkpointer`, `RunRepository`) is correctly scoped as **internal S-side execution context** but it has been routinely confused with — and asked to stand in for — the C/S protocol. That confusion is the architectural drift this ADR closes.

This ADR also incorporates reviewer finding P1-2 (degradation authority red line): the whitepaper §4.2 draws a hard boundary that the S-side may compensate compute *methods* (alternative tools, models, routes) while preserving task *goals*; only the C-side may decide to accept a degraded business outcome. That boundary needs to be a first-class platform rule, not buried in resilience policy.

## Decision Drivers

- Reviewer P0-2: C/S Dynamic Hydration must be a first-class architecture contract.
- Reviewer P1-2: degradation authority must be explicitly bound to the C/S boundary.
- Active architecture text must answer: "What does C-side send? What may S-side return? Who owns task goals, business rules, and execution trajectory?"
- No active document should imply that `RunContext` alone is the C/S protocol.
- The protocol is wave-deferred for implementation but must be named at L0 contract level so the team cannot drift further.

## Considered Options

1. **Name the C/S Dynamic Hydration Protocol and the degradation-authority red line in a single ADR; map to existing W0 primitives** (this decision).
2. **Wait for W2 implementation work to name the protocol** — rejected: leaves L0 silent on the central whitepaper concept; permits further drift.
3. **Split degradation authority into a separate ADR** — rejected: the authority red line shares the C/S boundary and is best named together; future ADRs (resilience, fallback) reference this single boundary.
4. **Force the protocol into Java SPI code now** — rejected per reviewer non-goal: "It must not trigger broad Java runtime implementation in W0 except for document gates and truth checks that prevent drift." Java types will follow in a separate wave-tagged PR.

## Decision Outcome

**Chosen option:** Option 1.

### Protocol vocabulary

The C/S Dynamic Hydration Protocol is named at L0 contract level via the following named contracts. Each is a **named architecture contract**, not a Java type — Java types are deferred to a follow-up wave.

#### Request side (C-Side → S-Side)

- **`TaskCursor`** — business-owned, lightweight progress coordinate. **Opaque to S-side business semantics** except for protocol-level fields required for routing, lease, and resume:
  - `tenantId` (routing).
  - `taskId` (business-defined opaque identifier; S-side may correlate but not interpret).
  - `cursorState` (business-defined opaque payload; S-side stores and returns unchanged unless explicitly delegated).
  - `leaseHandle` (S-side-issued lease identifier for resume).
  - `resumeKey` (used when re-awakening a suspended trajectory).
- **`BusinessRuleSubset`** — C-Side selected constraints injected for the current run or resume boundary. **Authoritative**; S-side MUST NOT mutate, narrow, broaden, or reinterpret. Examples: jurisdiction fences, compliance flags, allowable persona profiles, tone constraints, prohibited topics.
- **`SkillPoolLimit`** — C-Side restrictions on the available skill universe for this hydration. Includes: allowed skills/tools by name, budget caps (token / cost / time), region/residency fences, allowed credentials, allowed external endpoints, compliance fences. The S-Side scheduler (ADR-0052) MUST respect these as hard limits.
- **`HydrationRequest`** — the unified envelope:
  - `tenantId`
  - `taskCursor`
  - `businessRuleSubset`
  - `skillPoolLimit`
  - `requestedHandoffMode` ∈ {`Sync`, `SubStream`, `YieldAndHandoff`}
  - `idempotencyKey` (per §4 #4)
  - `resumeToken` (nullable; present on resume from prior `YieldResponse`)
- **`ResumeEnvelope`** — C-Side approval or credential payload that re-awakens an S-Side trajectory. Contains:
  - `resumeKey` (matches the prior `YieldResponse.resumeHandle`)
  - `approvalGrant` (e.g. SMS confirmation, signed approval token)
  - `additionalCredentials` (e.g. a step-up credential required for a high-risk operation)
  - **MUST NOT** alter the business goal; the S-Side rejects any `ResumeEnvelope` that attempts to mutate the original `TaskCursor` business state.

#### Server-internal state (S-Side, NOT part of C/S protocol)

- **`HydratedRunContext`** — S-Side runtime state built from the request. Distinct from the business-owned `TaskCursor`; carries the full Context Engine state, executor pointers, tool sessions, etc. **MUST NOT** be visible to the C-Side; the C-Side only sees the response handoff mode payload.
- The existing W0 primitives map to S-Side internals:
  - **`RunContext`** (orchestration SPI) — internal S-Side execution context; **NOT** the C/S protocol.
  - **`SuspendSignal`** — one possible internal cause of a `YieldResponse`; the C-Side never sees `SuspendSignal` directly.
  - **`Checkpointer`** — stores S-Side trajectory state; NEVER stores C-Side business facts (those flow back to C-Side per ADR-0051).
  - **`RunRepository`** — stores platform lifecycle and accounting state (run start, status transitions, billing); NEVER stores business ontology.

#### Response side (S-Side → C-Side)

Three standard handoff modes (whitepaper §2.3):

- **`SyncStateResponse`** — **Cursor Advancement Mode**. S-Side completes some number of internal steps and returns:
  - Updated `taskCursor` (only the parts the C-Side owns; opaque `cursorState` returned unchanged or with C-Side-delegated mutations).
  - Minimalist `result` payload (the actual business answer or output).
  - `costReceipt` (token/wall-clock/$ usage; per Rule 13 and ADR-0052).
  - **No internal trajectory leakage**.
- **`SubStreamFrame`** (stream of frames) — **Pass-Through Interaction Mode**. Geared toward end-user UI rendering. S-Side passes reasoning fragments and progress events:
  - `frameType` ∈ {`thinking_chunk`, `tool_invocation_start`, `tool_invocation_done`, `partial_answer`, ...}.
  - `frameBody` (UI-renderable text or structured event).
  - **Explicit non-persistence guidance**: the C-Side SHOULD render and discard. If the C-Side persists frames, it MUST tag them clearly as reasoning trace, NOT as canonical business state.
- **`YieldResponse`** — **Permission Suspension Mode**. S-Side suspends because a high-risk operation requires C-Side authorization or credentials. Carries:
  - `suspensionReason` (typed; see ADR-0050 `BackpressureSignal` and the §4 #19 sealed `SuspendReason` taxonomy)
  - `requiredPermissionOrCredential` (what the C-Side must furnish)
  - `resumeHandle` (opaque; C-Side passes back in `ResumeEnvelope`)
  - `expiry` (instant after which the suspended trajectory is `EXPIRED`)
  - `userFacingExplanation` (safe string for end-user surfacing; no internal trajectory leakage)

### Degradation authority red line (reviewer P1-2)

The S-Side and C-Side have asymmetric authority over fallback behavior. This is a **first-class platform rule**, not a resilience-policy detail.

- **`ComputeCompensation`** — what the S-Side **MAY** do when a preferred tool/model/route fails:
  - Substitute alternative tools, models, gateways, regions, retry strategies.
  - Spend additional tokens/time to detour to an equal-quality outcome.
  - **MUST preserve** the C-Side task goal, business rules, and skill-pool limits.
  - The C-Side remains unaware (no `YieldResponse`) as long as the same-quality outcome is delivered.
- **`BusinessDegradationRequest`** — what the S-Side **MUST DO** when same-quality completion is impossible:
  - Yield via `YieldResponse` with reason code `BUSINESS_DEGRADATION_REQUIRED`.
  - Offer `options[]` — each option is a degraded outcome the C-Side may explicitly accept (e.g. "skip optional summarisation", "return partial result", "abandon task and refund").
  - **Only the C-Side** has authority to accept a degraded business outcome.
- **`GoalMutationProhibition`** — what the S-Side **MUST NOT** do under any resilience strategy:
  - Reinterpret, narrow, broaden, or replace the C-Side task goal.
  - Silently lower the quality bar to avoid yielding.
  - Substitute business rules with platform defaults.
  - Resolve a placeholder (`[USER_ID_102]`) when the C-Side has not authorized identity resolution (see ADR-0051 `PlaceholderPreservationPolicy`).

Every future resilience or fallback ADR MUST reference this red line and classify each strategy as either `ComputeCompensation` (S-Side authority) or `BusinessDegradationRequest` (C-Side authority).

### Wave staging

- **L0 (this PR)**: protocol vocabulary named; existing W0 primitives mapped to internal S-Side scope; degradation authority red line stated.
- **W2**: Java types for `HydrationRequest`, `TaskCursor`, `BusinessRuleSubset`, `SkillPoolLimit`, `SyncStateResponse`, `SubStreamFrame`, `YieldResponse`, `ResumeEnvelope` (separate ADR/PR).
- **W2**: northbound HTTP/SSE/gRPC bindings (in conjunction with §4 #11 streaming surface and ADR-0050 cross-service bus).
- **W3+**: `agent-client-sdk/` Maven module — C-Side library implementing the protocol (deferred design slot per archived analysis at `docs/archive/2026-05-13-serverless-architecture-future-direction.md`).

> **Post-impl note (2026-05-17 six-module materialization PR):** the W3+ module landed as a skeleton under the short name `agent-client/` (not `agent-client-sdk/`) — the long suffix was redundant once the team-facing six-module decomposition (AgentClient / AgentService / Middleware / AgentBus / AgentEvolve / AgentExecutionEngine) made the module name self-describing. Skeleton contents: `agent-client/pom.xml`, `agent-client/module-metadata.yaml` (plane: `edge`, kind: `domain`), `agent-client/ARCHITECTURE.md`, `agent-client/src/main/java/ascend/springai/client/spi/package-info.java`, `docs/dfx/agent-client.yaml`. Full protocol implementation remains deferred to W3+ per this ADR.

### Out of scope

- Java implementation of any of the named contracts (deferred to W2+).
- Wire formats (JSON / protobuf / SSE / gRPC) — deferred to W2 in conjunction with ADR-0050.
- The whitepaper-target-vs-W0-shipped split inside the whitepaper itself (separate PR).
- `S-side / C-side` vocabulary collision with Rule 17 and ADR-0033 (separate PR; this ADR uses the whitepaper sense for protocol naming and explicitly notes the other senses remain in their existing meaning).

### Consequences

**Positive:**
- Reviewers can now answer the four P0-2 acceptance questions by reading this ADR + ARCHITECTURE.md §4 #47.
- The C/S boundary is concept-named; future work cannot quietly substitute `RunContext` for `TaskCursor` without violating this ADR.
- Degradation authority red line prevents resilience strategies from silently mutating business goals.
- L0 contract truth is restored; the architecture no longer implies that microservice topology and orchestration SPI together constitute the whitepaper's agent contract.

**Negative:**
- Adds eight named contracts that have no Java implementation at W0. Reviewers reading the codebase will see prose-level types only; this is intentional per non-goal "broad Java runtime implementation".
- The protocol shape is design-only; W2 implementation will likely require iteration on field shapes once it meets real C-Side integrations. The named contracts are a starting point, not a final binding.

### Acceptance criteria (reviewer P0-2 + P1-2)

- Active architecture text answers: "What exactly does the C-side send to hydrate an S-side agent?" — Yes, via `HydrationRequest` shape above.
- Active architecture text answers: "What exactly may the S-side return?" — Yes, via the three handoff modes (`SyncStateResponse` / `SubStreamFrame` / `YieldResponse`).
- Active architecture text answers: "Who owns task goals, business rules, and execution trajectory?" — Yes, via the C-Side / S-Side ownership split above and ADR-0051 cross-ref.
- No active document implies that `RunContext` alone is the C/S protocol — Yes, this ADR explicitly states the opposite.
- Every future fallback policy classifiable as compute compensation or business degradation — Yes, via the degradation authority red line.
- Business degradation requires a C-side decision — Yes, stated.
- S-side resilience never silently changes business semantics — Yes, `GoalMutationProhibition` rule.

## References

- Reviewer source: `docs/reviews/2026-05-13-whitepaper-alignment-remediation-proposal.en.md` (findings P0-2 + P1-2)
- Whitepaper: `docs/spring-ai-ascend-architecture-whitepaper-en.md` §2.1, §2.3, §4.2
- ARCHITECTURE.md §4 #47 (this ADR's anchoring constraint)
- ADR-0050: Workflow Intermediary, Mailbox Backpressure, Rhythm Track (companion ADR — same review cycle)
- ADR-0051: Memory and Knowledge Ownership Boundary (defines what the S-Side may store; complements this ADR's C/S protocol)
- ADR-0052: Skill Topology Scheduler and Capability Bidding (enforces `SkillPoolLimit`)
- ADR-0048: Service-Layer Microservice-Architecture Commitment (deployment topology; this ADR is at the protocol layer above)
- Whitepaper alignment matrix: `docs/governance/whitepaper-alignment-matrix.md` — rows for C/S separation, Task Cursor, Dynamic Hydration, Sync State, Sub-Stream, Yield & Handoff, C-side business degradation authority
- `architecture-status.yaml` row: `c_s_dynamic_hydration_protocol`
