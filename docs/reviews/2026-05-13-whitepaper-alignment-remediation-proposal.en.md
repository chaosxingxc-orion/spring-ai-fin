# Whitepaper Alignment Remediation Proposal

Date: 2026-05-13

Audience: Architecture Design Team

Reviewer stance: Java microservice architecture and agent-driven architecture, with special focus on dynamic planning, skills, memory, knowledge, workflow buses, and cross-service contracts.

Primary reference: `docs/spring-ai-ascend-architecture-whitepaper-en.md`

Current architecture baseline reviewed: `ARCHITECTURE.md`, `docs/governance/architecture-status.yaml`, ADR-0030, ADR-0031, ADR-0034, ADR-0046, ADR-0047, ADR-0048, and `docs/releases/2026-05-13-L0-architecture-release.en.md`.

## Executive Verdict

The current L0 architecture is not ready to be described as whitepaper-aligned.

It is a strong cold-state fortress: it has posture-aware defaults, a formal run state machine, tenant purity, contract-truth gates, and a deliberate Service Layer microservice commitment. That is valuable, but it is not the same as implementing or even fully codifying the whitepaper's target architecture. The distinction matters. Treating those two claims as equivalent is exactly how severe architecture drift entered the design review process.

ADR-0048 is a useful correction because it commits the Service Layer to long-running microservices and avoids per-agent microservice dictatorship. It also locks heavy data away from the central event bus. That is directionally consistent with the whitepaper. It is not sufficient. ADR-0048 handles deployment topology, but it does not fully encode the whitepaper's agent runtime contract: C/S dynamic hydration, three-state cursor handoff, workflow intermediary mailboxes, three-track bus isolation including rhythm, dual-track memory ownership, skill topology scheduling, and Chronos hydration.

The architecture team must stop publishing or implying an unconditional "L0 is whitepaper aligned" conclusion until the remediation package below is completed and self-audited. A safe statement is:

> L0 is a shipped architecture-contract spine and cold-state fortress. It has accepted the Service Layer microservice commitment, but the whitepaper's dynamic C/S hydration and workflow-intermediary architecture remains only partially codified and requires remediation before the system can claim whitepaper alignment.

This is not a wording issue. It is a contract-truth issue. The current architecture lets important whitepaper concepts disappear behind adjacent but non-equivalent terms such as `RunContext`, `event bus`, `GraphMemory`, and `microservice commitment`. That is unacceptable for an L0 architecture baseline.

This proposal intentionally recommends architecture-contract remediation first. It must not trigger broad Java runtime implementation in W0 except for document gates and truth checks that prevent drift.

Until the remediation is complete, the architecture team should treat this as a stop-ship condition for any release note, review response, or governance document that claims whitepaper-level alignment.

## Finding P0-1: Release-Note Baseline Drift Escaped Existing Gates

Observed failure:

`docs/releases/2026-05-13-L0-architecture-release.en.md` still reports 45 Section 4 constraints and 47 ADRs, while the canonical governance baseline now reports 46 Section 4 constraints and 48 ADRs after ADR-0048.

Execution path:

ADR-0048 and `ARCHITECTURE.md` moved the active architecture to Section 4 constraint #46 and ADR count 48. `docs/governance/architecture-status.yaml` was updated to the same baseline. The release note remained at the previous 45/47 baseline. Existing gate rules passed because the active-entrypoint baseline gate cross-checks README counts, but not release-note baseline counts.

Root cause statement:

Release-note baseline drift happens because Gate Rule 27 only compares README baseline counts to `architecture-status.yaml`, while `docs/releases/*.md` baseline-count tables are outside that canonical count comparison, allowing the release artifact to preserve stale 45/47 counts after ADR-0048 added #46/0048.

Evidence:

- `docs/releases/2026-05-13-L0-architecture-release.en.md:23` reports `45 (#1-#45)`.
- `docs/releases/2026-05-13-L0-architecture-release.en.md:24` reports `47 (ADR-0001-ADR-0047)`.
- `docs/releases/2026-05-13-L0-architecture-release.en.md:185` references `ARCHITECTURE.md` as full Section 4 constraint list `#1-#45`.
- `docs/releases/2026-05-13-L0-architecture-release.en.md:186` references ADR index `0001-0047`.
- `docs/governance/architecture-status.yaml:68` states the canonical baseline is `46 Section 4 constraints (#1-#46); 48 ADRs (0001-0048)`.
- `ARCHITECTURE.md:520` introduces Section 4 constraint #46.
- `docs/adr/README.md:60` indexes ADR-0048.

Required remediation:

1. Update the L0 release note baseline table and referenced document list to 46 Section 4 constraints and 48 ADRs, or explicitly mark the release note as a historical artifact frozen at the earlier semantic release SHA.
2. If the release note is intended to remain the current L0 release artifact, add ADR-0048 to its review-cycle table and related-document list.
3. Extend the release-note truth gate so baseline counts in `docs/releases/*.md` cannot drift from `architecture-status.yaml`.
4. Add positive and negative self-tests for this new gate behavior.

Acceptance criteria:

- A deliberate `45` or `47` count in an active release-note baseline table fails the architecture-sync gate when the canonical YAML says 46/48.
- The gate output names the specific release note and the stale count.
- The release note's current or historical status is unambiguous.

## Finding P0-2: C/S Dynamic Hydration Is Not a First-Class Architecture Contract

Observed failure:

The whitepaper's central agent contract is C/S separation with a lightweight C-side `Task Cursor` and an S-side dynamic hydration engine. Current L0 architecture contains orchestration SPI contracts and microservice topology, but it does not define the wire vocabulary, ownership boundary, or handoff protocol for `Task Cursor + Business Rule Subset + Available Skill Pool Limitations`.

Execution path:

The whitepaper defines C-side business ownership and S-side context-engine ownership, then defines Dynamic Hydration and three return modes. Current architecture instead centers on `RunContext`, `SuspendSignal`, `Checkpointer`, `RunRepository`, and deployment topology. Those primitives are useful for W0 lifecycle integrity, but they do not yet express the C/S protocol that business applications and platform runtime must share.

Root cause statement:

C/S hydration drift exists because current L0 promoted internal orchestration primitives and Service Layer deployment constraints to the active contract, but did not add an ADR that turns the whitepaper's C-side cursor, business-rule subset, skill-pool limitation, and three-state handoff into named request and response contracts.

Evidence:

- `docs/spring-ai-ascend-architecture-whitepaper-en.md:44` defines the precise C-side and S-side boundary.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:48` assigns the C-side ownership of the `Task Cursor` and business rules.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:52` assigns the S-side ownership of the context engine and trajectory closed loop.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:64` introduces Dynamic Hydration.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:68` defines the C-side request payload shape.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:73` through `docs/spring-ai-ascend-architecture-whitepaper-en.md:75` define Sync State, Sub-Stream, and Yield & Handoff.
- `ARCHITECTURE.md:11` lists the W0 shipped subset, which contains orchestration SPI contracts but no C/S hydration protocol.

Required remediation:

Create ADR-0049, tentatively titled `C/S Dynamic Hydration Protocol and Cursor Handoff`.

ADR-0049 should define at least:

- `TaskCursor`: a business-owned, lightweight progress coordinate. It must be opaque to S-side business semantics except for protocol-level fields required for routing, lease, and resume.
- `BusinessRuleSubset`: C-side selected constraints injected for the current run or resume boundary. It must be treated as authoritative and must not be mutated by the S-side.
- `SkillPoolLimit`: C-side restrictions on available skills, tools, budgets, regions, credentials, and compliance fences.
- `HydrationRequest`: `tenantId`, `taskCursor`, `businessRuleSubset`, `skillPoolLimit`, requested handoff mode, idempotency key, and optional resume token.
- `HydratedRunContext`: S-side runtime state built from the request, clearly distinct from business-owned task state.
- `SyncStateResponse`: minimal cursor advancement and result summary.
- `SubStreamFrame`: pass-through reasoning or progress fragments for UI streaming, with explicit non-persistence guidance for the C-side unless separately approved.
- `YieldResponse`: suspension reason, required permission or credential, resume handle, expiry, and safe user-facing explanation.
- `ResumeEnvelope`: C-side approval or credential payload that re-awakens an S-side trajectory without giving the S-side authority to alter business goals.

ADR-0049 should also map the protocol to existing W0 primitives:

- `RunContext` remains an internal S-side execution context.
- `SuspendSignal` becomes one possible internal cause of `YieldResponse`.
- `Checkpointer` stores S-side trajectory state, not C-side business facts.
- `RunRepository` stores platform lifecycle and accounting state, not business ontology.

Acceptance criteria:

- Active architecture text can answer: "What exactly does the C-side send to hydrate an S-side agent?"
- Active architecture text can answer: "What exactly may the S-side return?"
- Active architecture text can answer: "Who owns task goals, business rules, and execution trajectory?"
- No active document implies that `RunContext` alone is the C/S protocol.

## Finding P0-3: Workflow Intermediary Bus Is Collapsed Into Event-Bus Topology

Observed failure:

The whitepaper requires the Agent Bus to act as a workflow intermediary hub with local supervisors, mailboxes, push-pull buffering, and backpressure. Current ADR-0048 commits to data-P2P plus a centralized control event bus, but it does not define the local intermediary object, mailbox semantics, pull admission, or the rule that the bus must deliver intent only and must not force-start compute.

Execution path:

ADR-0048 makes a deployment decision: Service Layer microservices, heavy data P2P, control messages through a central event bus. That decision reduces congestion risk, but it can still be implemented as a broker that directly starts work, pushes too aggressively, or overloads compute nodes. The whitepaper's protection is not only a transport split; it is the workflow intermediary and mailbox pattern in front of each compute node.

Root cause statement:

Workflow-bus drift exists because ADR-0048 encoded the transport topology but not the local supervisor/mailbox contract, so the architecture can satisfy "data-P2P/control-event-bus" while still violating the whitepaper's push-pull buffering and backpressure model.

Evidence:

- `docs/spring-ai-ascend-architecture-whitepaper-en.md:168` starts the Agent Bus refactoring chapter.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:174` requires establishing the Workflow Intermediary concept.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:178` through `docs/spring-ai-ascend-architecture-whitepaper-en.md:179` state that the bus delivers intents and events, while a lightweight workflow intermediary sits in front of every concrete compute node.
- `docs/adr/0048-service-layer-microservice-architecture-commitment.md:41` defines the Service Layer as long-running microservices.
- `docs/adr/0048-service-layer-microservice-architecture-commitment.md:52` assigns control flow to a centralized event bus.
- `docs/adr/0048-service-layer-microservice-architecture-commitment.md:65` says the bus owns scheduling, capability bidding, and work-state recording, but does not define mailbox pull, local admission, or force-start prohibition.

Required remediation:

Create ADR-0050, tentatively titled `Workflow Intermediary Bus, Mailbox Backpressure, and Rhythm Track`.

ADR-0050 should define:

- `WorkflowIntermediary`: a per-Agent-Service local supervisor responsible for mailbox polling, local admission control, lease checks, and dispatch into in-process workers.
- `IntentEvent`: the central bus payload. It should express desired capability, work class, priority, tenant, permission envelope reference, and pointer references, but not heavy payloads.
- `Mailbox`: the durable or semi-durable queue visible to the local intermediary. The bus may enqueue intent; the local intermediary decides when to pull.
- `AdmissionDecision`: accepted, delayed, rejected, or yielded, with reason codes.
- `BackpressureSignal`: local saturation, skill saturation, tenant quota, or shutdown.
- `WorkStateEvent`: claimed, running, yielded, succeeded, failed, cancelled, expired.
- A hard rule that the bus cannot force-start concrete computation inside an Agent Service instance.

ADR-0050 should reconcile with ADR-0048:

- ADR-0048's data-P2P/control-event-bus split remains valid.
- The central event bus carries intents and control events.
- The local `WorkflowIntermediary` owns pull-based execution admission.
- Heavy data remains outside the central broker and outside intent events.

Acceptance criteria:

- A future implementer cannot equate "central event bus" with "direct work executor".
- Architecture text states where backpressure decisions are made.
- Architecture text states how a compute node refuses, delays, or yields work without losing the task.

## Finding P0-4: Heartbeat and Rhythm Are Not an Independent Physical Track

Observed failure:

The whitepaper requires strict three-track physical isolation: high-priority control, data/compute, and heartbeat/rhythm. Current ADR-0048 describes heavy data P2P and control through the centralized event bus, and explicitly includes heartbeats in the control bus. That collapses heartbeat/rhythm into the control track.

Execution path:

ADR-0031 discusses three-track isolation for run events in the HTTP/SSE context. ADR-0048 then defines cross-service bus traffic as data-P2P plus centralized control bus, with PAUSE/KILL/RESUME, scheduling, bidding, and heartbeats on the same control flow. The whitepaper gives heartbeat/rhythm its own physical channel because WAKEUP pulses and survival signals must continue even when control traffic is congested.

Root cause statement:

Rhythm-track drift exists because the cross-service bus decision in ADR-0048 reduced the whitepaper's three physical tracks into two deployment tracks, then placed heartbeats in the control event bus instead of preserving heartbeat/rhythm as an independently protected channel.

Evidence:

- `docs/spring-ai-ascend-architecture-whitepaper-en.md:188` requires strict three-track physical isolation.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:195` assigns heartbeat packets and WAKEUP pulses to the rhythm track.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:217` through `docs/spring-ai-ascend-architecture-whitepaper-en.md:218` define Chronos Hydration through WAKEUP pulses and snapshot-based rehydration.
- `docs/adr/0048-service-layer-microservice-architecture-commitment.md:52` includes heartbeats in the centralized event bus control flow.
- `ARCHITECTURE.md:525` through `ARCHITECTURE.md:530` lock data flow as P2P and control flow as centralized event bus, including heartbeats.
- `docs/adr/0031-three-track-channel-isolation.md:189` through `docs/adr/0031-three-track-channel-isolation.md:201` forwards ADR-0031 under ADR-0048, but does not fully restore an independent cross-service rhythm track.

Required remediation:

ADR-0050 should explicitly preserve the third cross-service track:

- Track 1: Control. PAUSE, KILL, RESUME, UPDATE_CONFIG, scheduling decisions, cancellation, and safety commands. This track is high priority.
- Track 2: Data/Compute. Heavy payloads, LLM chunks, artifacts, and large tool outputs. This track is P2P or pointer-based and must not traverse the central broker.
- Track 3: Heartbeat/Rhythm. Survival heartbeats, tick events, sleep declarations, WAKEUP pulses, lease renewal, and Chronos hydration triggers. This track must remain independently protected from control-command congestion.

ADR-0050 should define:

- `SleepDeclaration`: an agent's durable request to suspend compute until a time, condition, or external signal.
- `WakeupPulse`: rhythm-track event that identifies a snapshot or checkpoint and asks a local intermediary to rehydrate.
- `TickEngine`: the component responsible for durable timer evaluation.
- `ChronosHydration`: the flow from sleep declaration to compute self-destruction to WAKEUP pulse to S-side rehydration.

Acceptance criteria:

- Active architecture cannot place heartbeats and WAKEUP pulses only on the same bus partition or priority class as general control traffic.
- A congestion failure in capability bidding cannot prevent survival heartbeats or wakeup pulses from being delivered.
- ADR-0048 is amended or linked so its two-track shorthand cannot override the whitepaper's rhythm-track requirement.

## Finding P0-5: Memory and Knowledge Ownership Can Be Misread as Platform Ownership of Business Ontology

Observed failure:

The whitepaper states that business ontology and fact accumulation belong to the C-side, while S-side stores execution trajectories and platform state. Current ADR-0034 defines M1 through M6 memory categories, including M3 Semantic Long-Term, M4 Graph Relationship, and M5 Knowledge Index. Without an explicit ownership boundary, these categories can be misread as platform-owned business memory.

Execution path:

ADR-0034 was created to remove ambiguity around memory taxonomy and GraphMemory scope. It is useful for platform design. However, the whitepaper later clarifies that business facts discovered during dialogue must be emitted as structured events and ultimately persisted by the C-side business database or knowledge graph. The active architecture needs a new ownership rule to distinguish platform memory from business ontology events.

Root cause statement:

Memory-ownership drift exists because the architecture defines memory categories and a GraphMemory SPI from the S-side perspective, but has not codified the whitepaper's dual-track ownership rule that business facts and ontology updates are emitted to and owned by the C-side by default.

Evidence:

- `docs/spring-ai-ascend-architecture-whitepaper-en.md:81` assigns business ontology and fact accumulation to the C-side.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:82` assigns execution trajectories and multi-tenant platform state to the S-side.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:83` defines placeholder exemption and symbolic preservation.
- `ARCHITECTURE.md:383` lists M4 Graph Relationship Memory.
- `ARCHITECTURE.md:389` names Graphiti as the W1 reference sidecar for graph relationship memory.
- `docs/governance/architecture-status.yaml:820` describes six memory categories including M3, M4, and M5.
- `docs/adr/0034-memory-and-knowledge-taxonomy-at-l0.md:48` defines M4 as entity-entity relationships and knowledge graph style memory.
- `docs/adr/0034-memory-and-knowledge-taxonomy-at-l0.md:76` designates Graphiti as the W1 reference sidecar for M4.

Required remediation:

Create ADR-0051, tentatively titled `Memory and Knowledge Ownership Boundary`.

ADR-0051 should define:

- C-side owned memory:
  - Business ontology.
  - Business entity state.
  - User preferences.
  - Domain facts discovered during agent execution.
  - Business knowledge graph or business database persistence.
- S-side owned memory:
  - Run trajectory.
  - Token usage.
  - Model version and gateway telemetry.
  - Tool-call trace.
  - Retry and failure diagnostics.
  - Execution snapshots required for resume.
  - Platform scheduling, quota, and billing state.
- Shared or delegated memory:
  - Only allowed through an explicit delegation contract with tenant scope, retention, redaction state, visibility scope, and export/delete semantics.

ADR-0051 should update ADR-0034:

- M1 and platform execution trace categories may remain S-side owned.
- M3/M4/M5 must be split into platform-derived operational memory versus business-owned ontology/fact events.
- `GraphMemoryRepository` must not be described as the default owner of customer business ontology.
- Graphiti can remain the W1 reference sidecar for platform graph relationship memory or delegated memory, but not as an implicit sink for all business facts.

ADR-0051 should also define:

- `BusinessFactEvent`: structured event emitted from S-side to C-side.
- `OntologyUpdateCandidate`: candidate fact requiring C-side acceptance.
- `PlaceholderPreservationPolicy`: S-side must preserve placeholders such as `[USER_ID_102]` without resolving or enriching them unless authorized.
- `SymbolicReturnEnvelope`: response that returns placeholder-bearing results without identity collapse.

Acceptance criteria:

- No active architecture prose implies that S-side memory owns C-side business facts by default.
- Any future M4 or Graphiti adapter must state whether it stores platform graph state, delegated business graph state, or both.
- Placeholder preservation is represented as a first-class rule, not an incidental privacy note.

## Finding P1-1: Skill Architecture Lacks Topology Scheduling and Pre-Authorized Capability Bidding

Observed failure:

The whitepaper requires a global Skill Topology Scheduler, prediction and queuing by skill saturation, pre-authorized capability access, bidding, and permission issuance to delegates. Current architecture has Skill SPI and resource-tier classification, but it does not fully express the global topology scheduler or capability authorization model as the cross-service scheduling contract.

Execution path:

Current architecture treats skills primarily as platform SPI and resource declarations. The whitepaper treats skills as independently scheduled resource pools with tenant quota, global capacity, bidding, and explicit permission envelopes. These are related but not equivalent.

Root cause statement:

Skill-topology drift exists because current architecture classifies skill resource tiers but does not define the global scheduling matrix and pre-authorized capability-bidding protocol required for long-running enterprise agents.

Evidence:

- `docs/spring-ai-ascend-architecture-whitepaper-en.md:134` requires the S-side to establish a global Skill Topology Scheduler.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:135` requires prediction and queuing based on skill dependency weight and saturation.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:202` requires a pre-authorized access system for capability tags.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:204` restricts bidding to delegates that hold the pre-authorized domain identifier.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:206` requires the S-side to issue specific work permissions to the winning delegate.
- `docs/adr/0038-skill-spi-resource-tier-classification.md:50` updates resource-tier language, but this is not yet a full topology scheduler contract.

Required remediation:

Update ADR-0030 and ADR-0038, or create ADR-0052 if the team wants a separate decision record.

The architecture should define:

- `SkillResourceMatrix`: tenant quota by skill, global skill capacity, current utilization, reserved capacity, and saturation reason.
- `CapabilityRegistry`: capability tags bound to domain permission identifiers and physical sandbox constraints.
- `BidRequest`: intent, capability, tenant, budget, required permissions, expected duration, and data-pointer references.
- `BidResponse`: capacity, expected start time, required substitutions, and confidence.
- `PermissionEnvelope`: action/tool permissions issued to the winning delegate and propagated only within its allowed subsumption boundary.
- `SkillSaturationYield`: a yield reason that queues only the dependent agent or skill step instead of consuming LLM inference threads.

Acceptance criteria:

- Architecture text distinguishes "a Java SPI for skills" from "a distributed skill resource scheduler".
- Tenant quota and global skill capacity are both represented.
- Permission issuance to delegates is explicit and traceable.

## Finding P1-2: Degradation Authority Is Not Explicitly Bound to C-Side Versus S-Side Rights

Observed failure:

The whitepaper draws a hard red line: the S-side may compensate compute methods, but it cannot change C-side task goals. Business degradation belongs to the C-side. Current architecture has resilience and orchestration contracts, but the degradation authority split is not named as a hard platform rule.

Execution path:

Without the authority split, a future fallback, retry, or skill-substitution policy could accidentally mutate the task goal under the name of resilience. That would violate the whitepaper even if the runtime remains technically reliable.

Root cause statement:

Degradation-authority drift exists because resilience and fallback are documented as platform concerns, but the architecture does not state the governance boundary that S-side compensation must preserve task goals and that business degradation requires C-side decision authority.

Evidence:

- `docs/spring-ai-ascend-architecture-whitepaper-en.md:142` states that S-side has no authority to modify C-side task goals.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:144` through `docs/spring-ai-ascend-architecture-whitepaper-en.md:147` allow S-side underlying compute compensation.
- `docs/spring-ai-ascend-architecture-whitepaper-en.md:148` through `docs/spring-ai-ascend-architecture-whitepaper-en.md:150` reserve business task degradation to the C-side.
- `ARCHITECTURE.md:11` lists `ResilienceContract` as W0 shipped SPI, but the C/S degradation authority rule is not part of the active W0 contract list.

Required remediation:

Add this rule to ADR-0049 or ADR-0051:

- `ComputeCompensation`: S-side may substitute tools, models, routes, or additional compute while preserving task goals and C-side constraints.
- `BusinessDegradationRequest`: if equal-quality completion is impossible, S-side must yield with reason code and options; only C-side can accept degraded business outcome.
- `GoalMutationProhibition`: S-side fallback code must not reinterpret, narrow, broaden, or replace the C-side task goal.

Acceptance criteria:

- Every future fallback policy can be classified as either compute compensation or business degradation.
- Business degradation requires a C-side approval or policy decision.
- S-side resilience never silently changes business semantics.

## Finding P2-1: Whitepaper Target Versus L0 Shipped Scope Needs a Formal Mapping

Observed failure:

The project now has a whitepaper target architecture, a W0 cold-state shipped subset, and a Service Layer microservice commitment. The active docs do not yet include a single map that marks each whitepaper concept as shipped, active design-only, deferred, archived, or intentionally rejected.

Execution path:

The architecture has become safer through many truth gates, but the whitepaper adds a target-state layer that can drift separately from ADR and release artifacts. Without a concept map, reviewers can pass local truth gates while missing global semantic drift from the whitepaper.

Root cause statement:

Whitepaper-scope drift exists because current gates verify document-to-code and active-entrypoint consistency, but they do not maintain a concept-level traceability matrix from whitepaper principles to active architecture decisions, deferrals, or exclusions.

Evidence:

- `docs/spring-ai-ascend-architecture-whitepaper-en.md:36` defines the next-step target as Dual-Layer Lifecycle Architecture and Workflow Intermediary Bus.
- `docs/governance/architecture-status.yaml:68` states the current baseline and ADR-0048 commitment.
- `docs/adr/0048-service-layer-microservice-architecture-commitment.md:95` references only selected whitepaper sections as related documents, while many whitepaper concepts remain unclassified.

Required remediation:

Create `docs/governance/whitepaper-alignment-matrix.md` or an equivalent YAML-backed matrix.

Minimum columns:

- Whitepaper concept.
- Source line or section.
- Current architecture artifact.
- Status: shipped, active-design, deferred, archived, rejected.
- Wave: W0, W1, W2, W3, W4+.
- Owner side: C-side, S-side, shared, external.
- Gate coverage: yes/no.
- Notes and risk.

Initial rows should include:

- C/S separation.
- Task Cursor.
- Dynamic Hydration.
- Sync State.
- Sub-Stream.
- Yield & Handoff.
- Business ontology ownership.
- S-side execution trajectory ownership.
- Placeholder exemption.
- Full Trace versus Node Snapshot.
- Lazy mounting and bypass context store.
- Skill Topology Scheduler.
- C-side business degradation authority.
- Session/context decoupling.
- Workflow Intermediary.
- Three-track bus.
- Capability bidding.
- Permission issuance.
- Chronos Hydration.
- Service Layer microservice commitment.

Acceptance criteria:

- A reviewer can inspect one file and see exactly how each whitepaper concept maps to active architecture.
- Any "whitepaper aligned" release note must reference this matrix.
- The architecture-sync gate can later validate at least required row presence and status vocabulary.

## Strategic Decision on ADR-0048

ADR-0048 should be retained, but narrowed.

Keep:

- Service Layer as long-running Java/Spring microservices.
- Agent Service instances as long-lived process boundaries.
- Heavy data and artifacts outside the central broker.
- Data/compute transport as P2P or pointer-based.
- Control commands as high-priority centralized events.
- Per-agent microservice packaging explicitly rejected.
- Serverless SPI friendliness preserved for W4+.

Amend or qualify:

- Do not describe the bus as only two tracks. Cross-service rhythm must remain an independent heartbeat/WAKEUP track.
- Do not let the central control bus imply direct work execution. Work admission belongs to the local workflow intermediary.
- Do not let Service Layer topology stand in for C/S Dynamic Hydration.
- Do not let platform memory categories imply default ownership of C-side business ontology.

Recommended text to add to ADR-0048:

> ADR-0048 is a deployment-topology commitment, not the complete whitepaper realization. It is subordinate to the future C/S Dynamic Hydration Protocol, Workflow Intermediary Bus, Rhythm Track, and Memory Ownership Boundary ADRs. Its "data-P2P/control-event-bus" shorthand must not collapse heartbeat/rhythm isolation or bypass local intermediary admission control.

## Mandatory Systematic Self-Audit

The architecture team must run a full self-audit before submitting the next response. Do not patch only the findings named in this review. The prior review process already missed severe drift because it inspected local consistency while failing to test whitepaper-level semantic equivalence.

The self-audit must produce a written artifact, not an informal statement. It should be submitted alongside the remediation PR or review response.

Minimum required self-audit sections:

1. Whitepaper concept inventory.

   List every major concept in `docs/spring-ai-ascend-architecture-whitepaper-en.md`, including C/S separation, `Task Cursor`, Dynamic Hydration, three-state handoff, business ontology ownership, S-side trajectory ownership, placeholder preservation, Full Trace, Node Snapshot, bypass context store, lazy mounting, Skill Topology Scheduler, degradation authority, session/context decoupling, Workflow Intermediary, three-track bus, capability bidding, permission issuance, rhythm, and Chronos Hydration.

2. Exact architecture mapping.

   For each concept, identify the exact current artifact that owns it: `ARCHITECTURE.md` section, ADR, governance YAML row, gate rule, release note, or deferred document. If no owner exists, mark it as a gap. Do not substitute an adjacent concept. For example, `RunContext` is not automatically `Task Cursor`; `event bus` is not automatically `Workflow Intermediary`; `GraphMemory` is not automatically business ontology ownership.

3. Contract-equivalence check.

   For each mapped concept, state whether the current architecture has the same boundary, same authority model, same data ownership, same failure behavior, and same lifecycle semantics as the whitepaper. If any of these differ, the concept is not equivalent.

4. Over-design check.

   Identify any architecture component that adds platform-owned complexity beyond L0 without a current enforcement rule, implementation plan, or explicit deferral. Pay special attention to memory categories, graph memory, skill middleware, bus topology, and scheduler vocabulary.

5. Gate-coverage check.

   For every "enforced by", "asserted by", "tested by", or release-baseline claim, name the exact gate or test that would fail if the claim drifted. If there is no failing mechanism, label it as "socially reviewed only" and decide whether a gate is required.

6. Release-note truth check.

   Verify that release notes, README files, ADR index, `architecture-status.yaml`, and root `ARCHITECTURE.md` all agree on counts, shipped surface, deferred surface, and target-only language. The current 45/47 versus 46/48 drift proves this cannot be skipped.

7. Negative-test discipline.

   For every new gate added during remediation, include a negative self-test that intentionally creates the drift and proves the gate fails. A gate without a negative test is not sufficient evidence.

8. Explicit residual-risk statement.

   If any whitepaper concept remains design-only or deferred, state that directly. Do not bury it in positive release language. The architecture team must say what is not shipped, what is not yet contract-complete, and what remains outside L0.

The self-audit must end with one of these exact conclusions:

- `PASS: L0 is whitepaper-aligned at the architecture-contract level, with all non-shipped concepts explicitly mapped as design-only or deferred.`
- `FAIL: L0 remains whitepaper-alignment incomplete. The following architecture-contract gaps remain: ...`

Any weaker conclusion is not acceptable. Any self-audit that only says "all review comments addressed" is not acceptable.

## Remediation Package

### P0: Correct release-note truth drift

Owner: Architecture governance.

Deliverables:

- Patch `docs/releases/2026-05-13-L0-architecture-release.en.md`.
- Add a release-note baseline-count gate or extend Gate Rule 26/27.
- Add self-tests for stale release-note count detection.

### P0: Add ADR-0049 for C/S Dynamic Hydration

Owner: Agent platform architecture.

Deliverables:

- New ADR-0049.
- Root `ARCHITECTURE.md` Section 4 constraint for C/S hydration.
- `architecture-status.yaml` row with status and implementation posture.
- Whitepaper alignment matrix rows for C/S concepts.

### P0: Add ADR-0050 for Workflow Intermediary, Backpressure, and Rhythm

Owner: Agent bus and runtime architecture.

Deliverables:

- New ADR-0050.
- Amendment to ADR-0031 and ADR-0048.
- Explicit three-track cross-service model.
- Definitions for `WorkflowIntermediary`, `Mailbox`, `WakeupPulse`, `SleepDeclaration`, and `ChronosHydration`.

### P0: Add ADR-0051 for Memory and Knowledge Ownership

Owner: Memory and knowledge architecture.

Deliverables:

- New ADR-0051.
- Amendment to ADR-0034.
- C-side versus S-side memory ownership table.
- Placeholder preservation rule.
- Explicit limits on GraphMemory and Graphiti as default business-ontology stores.

### P1: Expand skill architecture to topology scheduling

Owner: Skill/runtime scheduling architecture.

Deliverables:

- Update ADR-0030/ADR-0038 or add ADR-0052.
- Define `SkillResourceMatrix`, `CapabilityRegistry`, `BidRequest`, `BidResponse`, `PermissionEnvelope`, and `SkillSaturationYield`.
- Tie tenant quota and global skill capacity into the bus/intermediary scheduling model.

### P1: Add degradation-authority rule

Owner: Resilience and C/S protocol architecture.

Deliverables:

- Add `ComputeCompensation`, `BusinessDegradationRequest`, and `GoalMutationProhibition` to ADR-0049 or ADR-0051.
- Ensure future resilience and fallback ADRs reference this authority boundary.

### P2: Add whitepaper alignment matrix

Owner: Architecture governance.

Deliverables:

- New `docs/governance/whitepaper-alignment-matrix.md` or YAML equivalent.
- A status row for every major whitepaper concept.
- Release-note linkage requirement.

## Non-Goals for This Remediation

- Do not implement a full production Agent Bus in W0.
- Do not implement Graphiti or business knowledge storage in W0.
- Do not add new runtime fallbacks solely to satisfy whitepaper vocabulary.
- Do not replace the Java microservice commitment with per-run serverless in the current wave.
- Do not turn every whitepaper target into a shipped W0 claim.

The immediate goal is contract truth: active architecture must say exactly what is shipped, what is design-only, what is deferred, and what authority each side owns.

## Suggested Release-Note Language After Remediation

If the above remediation lands, the release note can safely say:

> L0 ships the cold-state architecture spine and Java Service Layer microservice commitment. It does not yet ship the full whitepaper runtime, but it now contains explicit architecture contracts for C/S Dynamic Hydration, Workflow Intermediary Bus semantics, independent Rhythm Track, memory and knowledge ownership, and skill topology scheduling. These target contracts are mapped to shipped, design-only, and deferred states through the whitepaper alignment matrix.

If the remediation does not land, the release note should instead say:

> L0 is not fully whitepaper aligned. It ships the cold-state contract spine and accepts the Service Layer microservice direction, while Dynamic Hydration, Workflow Intermediary, Rhythm, Memory Ownership, and Skill Topology remain unresolved architecture gaps.

## Final Recommendation

Treat the current state as "L0 cold-state ready, whitepaper-alignment incomplete."

The architecture team should not ask reviewers to accept another release note or readiness response until it completes a systematic whitepaper self-audit and closes the P0 gaps in this document. The most urgent correction is the release-note baseline drift because it proves that the existing truth gates still miss at least one active artifact class. The deeper correction is semantic: the architecture must stop replacing the whitepaper's precise contracts with nearby platform concepts that do not carry the same ownership, lifecycle, or authority boundaries.

Repair the architecture through explicit ADRs, governance rows, and gates. Do not hide unresolved whitepaper concepts behind optimistic release language. Do not claim alignment by intent. Claim alignment only when the active architecture can prove it concept by concept.
