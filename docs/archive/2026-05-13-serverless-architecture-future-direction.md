# Archived Analysis: Five-Tier Topology and Serverless Direction for the Service Layer

> **Status**: future direction, archived 2026-05-13.
>
> **Superseded by**: [ADR-0048](../adr/0048-service-layer-microservice-architecture-commitment.md) + ARCHITECTURE.md §4 #46 (Service-Layer Microservice-Architecture Commitment) for near-term direction.
>
> **Reason for archive**: this analysis recommends a five-tier topology with per-Run serverless execution within long-running Agent Service instances. The W0 implementation reality is that the serverless-friendly SPI primitives (`SuspendSignal` / `Checkpointer` / `RunRepository` / `RunStateMachine` DFA / ADR-0024 atomicity) are shipped, but the production implementations are not: `InMemoryCheckpointer` / `InMemoryRunRegistry` are dev-only stubs (fail-closed in research/prod via `AppPostureGate`); production serverless requires W2 Postgres checkpointer + W2 `PayloadCodec` (ADR-0022 deferred) + W2 `CapabilityRegistry` to replace inline lambdas (§4 #15 deferred) + W4 Temporal — none shipped. Industry trajectory in enterprise agent platforms is microservice-first; team familiarity with Spring Cloud is high; cold-start latency for LLM agents is unsolved; cross-JVM serialization of agent context (MBs of conversation + tool results) has real overhead. Betting unproven serverless implementations on the W2–W4 horizon was judged not pragmatic. The Service Layer commits to microservice architecture in the near term.
>
> **Preservation note**: the W0 SPI primitives remain **serverless-friendly**. ADR-0048 commits the *deployment* model at the service-layer level, not the *SPI* level. W4+ migration to per-Run hydration as the deployment model remains open. This document is preserved so that future migration work can pick up the design rationale and the five-tier topology recommendation without re-discovery.
>
> **Future-work parking lot** (also see ADR-0048 references):
> - Revise ADR-0030 (Skill SPI) for the outside-in skill-dispatch view (MCP as primary wire; `JAVA_NATIVE` as trusted in-process fast path).
> - Expand ADR-0031 (three-track bus) for the cross-process bus contract — wire format, substrate choice, scheduling semantics, capability bidding mechanism, work-state event schema. Bus traffic split is locked at ADR-0048: data flow P2P; control flow on event bus.
> - Audit ADR-0034 (memory taxonomy M1–M6) for platform-colonization risk: adopt Graphiti's schema verbatim for M4 vs imposing our envelope.
> - Build the Agent Client SDK (C-Side library) as a wave-tagged design slot.
> - Resolve the `S-side / C-side` vocabulary collision (three meanings: whitepaper, Rule 17, ADR-0033) before any whitepaper refresh.
> - Inventory the middleware universe as a permanent living document (e.g. `docs/cross-cutting/middleware-universe.md`).
> - Whitepaper refresh: mark target-vs-shipped honestly (mirror `ARCHITECTURE.md §1` per ADR-0047).

---

# Architectural Analysis: Whitepaper Realization, Three-Layer Model, Serverless vs Microservice

> Plan-mode analytical artifact (2026-05-13). This is a discussion document, not an implementation plan. It answers three architectural questions raised by the user, references the codebase truth (ARCHITECTURE.md, `architecture-status.yaml`, ADRs 0016/0018/0021/0030/0031/0033/0034), and proposes a recommendation only at the end.

> **Revision (2026-05-13, mid-discussion)** — two corrections incorporated during discussion:
>
> 1. **Middleware framing**: middleware (memory backends, skill hubs, MCP server registries, knowledge stores, LLM gateways, sandboxes, observability stacks, eval frameworks) is **third-party resource systems independent of the agent service** — a peer layer. The correct lens is **outside-in**: start with the external middleware universe, classify what qualifies as middleware, then have the platform **conform to industry integration protocols** (MCP, OpenTelemetry, OpenAI-compat) rather than inventing platform-centric SPIs that force middleware to adapt to us.
>
> 2. **Agent Bus is PLATFORM, not middleware**: the bus carries **scheduling semantics, task management, and cross-process work-state recording**. It is cross-agent-service / cross-docker by design. It is the platform's distributed coordination backbone — owned by the platform, even when it rides on top of standard messaging substrates (NATS / Kafka / Redpanda / gRPC streaming). MCP is a client-server tool-invocation protocol — wrong abstraction for distributed coordination; do not reduce the bus to "an MCP transport".
>
> Part 2 point 3, Part 2.5 (Outside-In Middleware Classification + bus clarification), Part 3 (five-tier topology including Agent Bus and Agent Service instances as separate tiers), and Part 4 recommendation #3 reflect both revisions. Earlier text in this file is preserved for context but should be read in light of these corrections.

---

## Context

The user posed three coupled architectural questions in plan mode:

1. **Realization audit**: Have we actually implemented the design philosophy of `docs/spring-ai-ascend-architecture-whitepaper-en.md`, or only part of it?
2. **Three-layer model**: The user describes a mental model with three layers — (a) Agent Client SDK inside business systems, (b) Agent Server (current architecture), (c) Middleware (Mem0, LLMWiki, Graphiti). Is "middleware" its own layer, or does it fold into Agent Server?
3. **Serverless vs Microservice**: Some reviewers describe the current design as "elegantly serverless". The user wants a design-difficulty / engineering-difficulty comparison and a recommendation.

The output of this plan is the analytical document below. No code changes are proposed in this artifact.

---

## Part 1 — Did we realize the whitepaper? (~30% realized, intentionally)

### What the whitepaper proposes (Chapters 2–5)

The whitepaper proposes a "third path" between **Microservice Dictatorship** (rejected: Spring AI Alibaba A2A bus over Nacos JSON-RPC) and **Monolithic Asynchronous Loss of Control** (rejected: AgentScope-style coroutine free-fall). The third path has four moving parts:

1. **C-Side** = Business Application Side — holds Task Cursor + business rules + business memory; lightweight; lives inside CRM/OA/etc.
2. **S-Side** = Platform Runtime Side — holds Context Engine + full trajectory + N:1 multiplexed agents; long-lived; this is `spring-ai-ascend` itself.
3. **Workflow Intermediary Bus** — three-track channel isolation (Control/Data/Heartbeat) + Capability Registry + Pre-Authorized Access + decentralized Tick Engine for wake-up pulses.
4. **Skills/Tools as plug-ins** — registered into the bus with `SkillKind` + `SkillTrustTier`; reached by both Java native beans and out-of-process sidecars (MCP / GraalVM Polyglot).

### What W0 actually ships

Per `ARCHITECTURE.md` §5 + `docs/governance/architecture-status.yaml`:

| Whitepaper concept | W0 reality | Where it lives |
|---|---|---|
| Cold-state fortress (contract spine) | shipped | `TenantContextFilter`, `IdempotencyHeaderFilter`, `Run` entity, `RunStateMachine` DFA, `RunStatus` 7-value enum incl. `EXPIRED`, posture model + `AppPostureGate` |
| Run lifecycle + state machine | shipped | Rule 20 enforced; `RunStateMachine.validate()` + ArchUnit tests |
| Dual-mode runtime (Graph + AgentLoop) | shipped (reference impl only) | `SyncOrchestrator`, `SequentialGraphExecutor`, `IterativeAgentLoopExecutor`; in-memory only; dev-posture only |
| `SuspendSignal` interrupt-driven nesting | shipped (single-child only) | Single-`ChildRun` variant; full `SuspendReason` taxonomy (AwaitChildren / Timer / External / Approval / RateLimited) is deferred W2 (ADR-0019) |
| C-Side (Agent Client SDK) | **zero implementation, zero SPI** | No client library, no Task Cursor type, no Dynamic Hydration handoff protocol |
| Context Engine | only `GraphMemoryRepository` SPI scaffold | Full M1–M6 memory taxonomy is design-only (ADR-0034); Graphiti is W1 reference adapter not shipped |
| Workflow Intermediary Bus | design-only | ADR-0031 names the three-track contract; no code; `Flux<RunEvent>` streaming SPI deferred W2 |
| Capability Registry | design-only | Currently `NodeFunction` / `Reasoner` are inline lambdas (correct only for in-process W0); must become named registry entries by W2 (§4 #15) |
| `AgentSubject` long-horizon identity | deferred W2 | Today `Run` is execution-record only; no day-spanning agent identity |
| N:1 multiplexing + hot migration | deferred | Checkpoint payload cap (16 KiB) shipped via `InMemoryCheckpointer`; cross-JVM checkpointer deferred W2 (Postgres) and W4 (Temporal) |
| Skill SPI (lifecycle / `SkillResourceMatrix` / `SkillTrustTier`) | design-only | ADR-0030; sandbox enforcement for UNTRUSTED skills deferred W3 (ADR-0018 + Rule 27) |
| Three-track channel isolation | design-only | ADR-0031; deferred W2 |
| Tick Engine (decentralized rhythm) | deferred W4 | Whitepaper §5.4 — no code, no SPI |
| Memory taxonomy M1–M6 | design-only | ADR-0034; Graphiti = W1 reference for M4; mem0 + Cognee explicitly **not selected** |
| SWARM scope + parallel children | design-only | ADR-0032; `RunScope.SWARM` enum and `SuspendReason.SwarmDelegation` are deferred W2 |

**Honest summary**: the whitepaper's own framing was "cold-state fortress" (Chapter 1) versus "dynamic hub" (Chapters 2–5). **The fortress is built; the hub is paper.** That isn't a failure — it's the deliberate wave-by-wave staging documented in §4 of ARCHITECTURE.md and the 47 ADRs. But it does mean a reader of the whitepaper would substantially overestimate today's runtime capability.

### Vocabulary collision worth surfacing (not in the user's question, but blocks clean discussion)

`S-side / C-side` is currently used in **three incompatible senses** across the active corpus:

1. **Whitepaper (§2.1)**: C-Side = Business Brain (in CRM/OA); S-Side = Platform Runtime (= `spring-ai-ascend`).
2. **Rule 17 (codebase)**: C-side = consumer-authoritative (consumers implement, platform adapts); S-side = substitution-authoritative (platform implements, consumers adapt).
3. **ADR-0033 (deployment locus)**: `S-Cloud` / `S-Edge` / `C-Device` — *where* the code runs.

These are three orthogonal axes. A VETTED Java Skill is C-side under Rule 17 (consumer-provided), runs at S-Cloud per ADR-0033, and lives inside S-Side under the whitepaper. Today this is asking for confusion. **Recommendation flagged at end** — pick one canonical phrasing per axis and rename the whitepaper if needed.

---

## Part 2 — The three-layer model: examined

### The user's mental model

```
+----------------------------------------------+
|  Layer 1: Agent Client SDK                   |   embedded inside business systems
|  - context-engineering engine                |   accepts business semantics
|  - aggregates request, calls Layer 2         |   ~= whitepaper's C-Side
+----------------------------------------------+
|  Layer 2: Agent Server                       |   "the current architecture"
|  - microservice                              |   one Docker, manages sub-agents
|  - northbound stable contract                |   inter-agent: microservice discovery + RPC
|  - southbound to middleware                  |
+----------------------------------------------+
|  Layer 3: Middleware (?)                     |   Mem0 / LLMWiki / Graphiti
|  - undecided: own layer or part of L2?       |
+----------------------------------------------+
```

### The whitepaper's actual model

```
+-----------------------------------------------------------------+
|  C-Side (Business Brain)                                         |
|  Task Cursor + Business Rules + Business Memory + Ontology       |
+-----------------------------------------------------------------+
|  Dynamic Hydration Protocol                                      |
|  (cursor + rule subset + skill pool -> S-Side; SyncState /       |
|   SubStream / Yield-and-Handoff back to C-Side)                  |
+-----------------------------------------------------------------+
|  S-Side (Platform Runtime -- spring-ai-ascend)                   |
|  Context Engine + Trajectory + N:1 multiplexed long-lived agents |
|  Posture-aware, multi-tenant, fail-closed in research/prod       |
+-----------------------------------------------------------------+
|  Workflow Intermediary Bus                                       |
|  Control (out-of-band) / Data (Flux<RunEvent>) / Heartbeat       |
|  Capability Registry (pre-authorized) + Bidding + Tick Engine    |
+-----------------------------------------------------------------+
|  Skills / Tools / Memory Backends (pluggable via Skill SPI)      |
|  Java native beans, MCP tool servers, GraalVM polyglot, REST     |
|  sidecars (Mem0, Graphiti, LLMWiki belong here)                  |
+-----------------------------------------------------------------+
```

### Differences to call out

1. **The user's "Agent Server is one Docker that manages sub-agents"** does not match the whitepaper or the current codebase trajectory. In the whitepaper (§5.4) the compute process **self-destructs** after queuing its next wake-up; sub-agents are not "managed" by a parent process — they are hydrated on demand by the platform from snapshots. The current `SuspendSignal` + `Checkpointer` + `RunRepository` triple already commits to this model: when a Run suspends, the persisted state is sufficient for *any* worker to resume it later (ADR-0024 atomicity contract). The user's "Docker with sub-agents inside" framing is a microservice mental model that doesn't fit the existing W0 codebase.

2. **The user collapses "Bus + Skills/Middleware" into one third layer**. The whitepaper keeps them separate because they answer different questions:
   - **Bus** = how agent instances and their lifecycles talk to each other (intra-platform plumbing).
   - **Skills/Middleware** = how the platform reaches *external* OSS capabilities (Mem0 stores facts; Graphiti stores a graph; LLMWiki stores knowledge; code-interpreter executes Python).
   - Folding them together hides the distinction between *control-plane* (bus) and *capability-plane* (skills).

3. **Middleware IS a peer layer (corrected per user revision)**:
   - The original (now-discarded) verdict said middleware is *not* a peer architectural layer. The user corrected this: **middleware is a third-party resource ecosystem that exists and evolves independently of the agent service**. Skill Hubs (LangChain Hub, MCP server registries) belong to a category — Skill Middleware — that is itself an example of the broader middleware layer.
   - The right analogy is **K8s + CRI/CNI/CSI**: Kubernetes does not own container runtimes, networks, or storage. It defines (or conforms to) interfaces, and independent third-party systems implement them. Replacing one implementation with another is a deployment choice, not a platform fork.
   - Under this lens, the existing `spring-ai-ascend-graphmemory-starter` pattern is fine as a **wiring artifact** (it lives in our build, registers a Spring bean) but should not be confused with the platform "owning" the middleware. The middleware (Graphiti) is external; the starter is the platform's adapter that conforms to Graphiti's API.
   - **Architectural implication**: the platform's design should be **outside-in**. Inventory the external middleware universe, identify the industry protocols (MCP for tool dispatch, OpenTelemetry for observability, OpenAI-compatible API for LLM gateway), and have the platform conform. Inventing platform-specific SPIs for categories that already have industry protocols is **platform-colonization** and an anti-pattern.
   - **What this changes**: ADR-0030 (Skill SPI) needs revision — currently platform-centric; should be reframed as "platform's internal abstraction that conforms to MCP at the wire level". ADR-0031 (three-track bus) needs revision — much of the bus contract can be MCP transport; reserve custom protocol only for things MCP does not address (out-of-band cancel, heartbeat cadence). ADR-0034 (M1-M6 memory taxonomy) should be audited for platform-colonization risk: are we imposing our schema on memory backends, or adopting the schema of the most prominent OSS (Graphiti for M4) and calling it our M4? The latter is outside-in.
   - **What stays platform**: Run lifecycle, Orchestrator, Checkpointer, RunRepository, RunStateMachine, TenantContextFilter, idempotency, posture, audit. These are the platform's substance and are not pluggable in the middleware sense.
   - See **Part 2.5** below for the classification framework and the enumeration of the middleware universe.

4. **Agent Client SDK is genuinely missing**. Today there is **no C-Side artifact at all** — not even a stub SPI for the Task Cursor handoff protocol. The whitepaper's §2.3 three-mode handoff (Sync State / Sub-Stream / Yield-and-Handoff) corresponds to the W0 northbound: `Object` return + future `Flux<RunEvent>` (W2) + `SuspendSignal` yield (shipped). But there is no client-side counterpart that *holds* the cursor and re-injects it. If the user wants the whitepaper realized, this is the largest single missing piece.

---

## Part 2.5 — Outside-In Middleware Classification (per user revision)

### Classification criteria

A capability qualifies as **middleware** (independent third-party, reached via integration contract) iff *all four* of:

1. It exists and evolves independently of any one agent platform.
2. It has multiple alternative implementations (switching is a cost, not impossible).
3. There is an existing or emerging industry protocol to reach it — or one can reasonably be designed.
4. The platform remains useful without it (the platform itself is not the middleware).

Anything failing the test is **platform** — owned by us, evolved with our waves.

### The middleware universe — outside-in enumeration

| Category | Representative third-party systems | Integration protocol | Industry standard? |
|---|---|---|---|
| **Memory** | Mem0, Graphiti, Zep, MemGPT, Letta | REST + framework-specific schemas | No single standard — adopt prominent OSS schema (e.g. Graphiti for graph memory) |
| **Knowledge** | LLMWiki, weaviate, qdrant, pinecone, pgvector | REST + vector-DB APIs | LangChain / LlamaIndex have rough conventions |
| **Skill Middleware** (Skill Hubs + tool servers) | LangChain Hub, MCP server registries, OpenAPI tool catalogs, ChatGPT Actions | **MCP** (Model Context Protocol) for runtime; HTTP/GraphQL for catalogs | **MCP is the emerging standard** |
| **LLM gateway** | LiteLLM, Portkey, OpenRouter, AWS Bedrock | OpenAI-compatible chat-completions API | OpenAI schema is de facto |
| **Workflow engine** | Temporal, Camunda, Argo, Airflow | Native SDKs (no cross-engine standard) | Each has its own SDK |
| **Sandbox** | E2B, Docker, GraalVM Polyglot, Riza, WASM runtimes | REST + per-runtime APIs | No cross-runtime standard yet |
| **Observability** | LangSmith, LangFuse, Phoenix, Helicone | OpenTelemetry + custom traces | **OTel is the standard** |
| **Eval** | Ragas, DeepEval, OpenAI Evals, Promptfoo | CLI + Python APIs | Loose convergence on eval-as-code |
| **Vector / RAG orchestration** | LlamaIndex, Haystack, DSPy | Python SDKs; exposed to us via MCP servers | None — wrap behind MCP |

### What stays platform (NOT middleware)

- `Run` lifecycle entity + `RunStatus` + `RunStateMachine` DFA
- `Orchestrator` / `GraphExecutor` / `AgentLoopExecutor` SPI + reference impls
- `Checkpointer` SPI + posture-aware in-memory ref
- `RunRepository` SPI
- `TenantContextFilter` + idempotency edge filters
- Posture model + `AppPostureGate`
- `ResilienceContract` (per-operation routing SPI)
- Audit trail / `run_state_change` audit row (W2)
- **Agent Bus** — distributed coordination backbone carrying scheduling, task management, work-state recording, three-track Control/Data/Heartbeat split, cross-docker / cross-service communication. May ride on standard messaging substrates (NATS / Kafka / Redpanda / gRPC streaming) but the contract is platform.
- **Capability Registry** — per-tenant authorization, pre-authorized access, capability bidding, intent routing. Consumes MCP-style discovery as input but the registry itself is platform.
- **Run scheduler / dispatcher** — selects which Agent Service instance hydrates which Run; manages per-instance concurrency caps, tenant fairness, skill-saturation backpressure (§4 #12).
- C-Side Agent Client SDK (when built — it is the client of our platform, not third-party)

Replacing any of these means replacing `spring-ai-ascend` itself; they are platform substance.

### Ambiguous cases — decide explicitly

1. **LLM provider clients** (OpenAI SDK, Anthropic SDK, Spring AI ChatClient): could be direct platform deps OR funneled through LiteLLM as middleware. **Recommendation**: treat the LLM gateway as middleware (LiteLLM or equivalent); platform talks to one OpenAI-compat surface. Keeps the platform LLM-vendor-agnostic.

2. **Inter-agent bus (PLATFORM — not ambiguous, corrected per user revision)**: the Agent Bus is the platform's distributed coordination backbone. It carries: (a) **scheduling semantics** — which Agent Service instance picks up which Run / which capability bid wins; (b) **task management** — queueing, priority, dependency tracking, child-run join policies, parallel fan-out; (c) **work-state recording** — every agent's current state is written to the bus so other Agent Service instances and observers can see and react; (d) **cross-docker / cross-service communication** — multiple Agent Service instances in different containers coordinate through it. MCP is the **wrong abstraction** for this — MCP is a client-server tool-invocation protocol, not a distributed coordination protocol. The bus may *ride on* standard messaging substrates (NATS / Kafka / Redpanda / gRPC streaming) as its transport, but the bus contract (scheduling decisions, capability bidding, run-state events, three-track Control/Data/Heartbeat split per whitepaper §5.2) is platform-owned. ADR-0031 defines the in-process Java-side SPI; the cross-process wire format and messaging-substrate choice are deferred to expanded ADR-0031.

3. **Capability Registry** (PLATFORM): the registry owns per-tenant authorization, pre-authorized access (whitepaper §5.3), capability bidding, and routing decisions — all platform concerns. MCP-style discovery (server lists, capability descriptors) is one *input* the registry consumes when an external MCP server is part of the capability pool, but the registry itself is not MCP. It is how the platform decides which agent or capability handles a given intent under multi-tenant + scheduling + trust-tier constraints.

4. **Workflow engine** (Temporal at W4): Temporal IS middleware. The platform's `Orchestrator` SPI is platform; the Temporal-backed `Orchestrator` impl is the middleware adapter. ADR-0021's "layered SPI taxonomy" already anticipates this (Temporal bypasses Layer 3 entirely).

### Outside-in design heuristic

When designing a new integration, ask in this order:

1. **Is there an industry protocol** for this category (MCP, OTel, OpenAI-compat)? -> Conform to it. Don't invent.
2. **Is there a dominant OSS schema** (Graphiti, LiteLLM, Mem0)? -> Adopt the schema with the largest ecosystem; treat our SPI as an alias for that schema.
3. **Is the design space genuinely fragmented?** -> Invent minimally; document conformance points for future industry alignment; version the SPI explicitly.
4. **Is this the platform's core** (run lifecycle, tenant, audit)? -> Own it fully; this is what makes us a platform.

### Architectural implications

- The platform's **surface area shrinks**. Many things currently designed as platform-owned SPIs (Skill SPI per ADR-0030, bus per ADR-0031, parts of memory taxonomy per ADR-0034) should be reframed as **conformance layers** for industry protocols.
- The platform's **value moves up the stack**. Multi-tenancy + posture + run lifecycle + audit + idempotency + Spring-ecosystem fit + serverless-ready execution model are what the platform owns. Middleware integration is *table stakes* and should not be where we invest novel design effort.
- The **outside-in classification becomes a living document**. As the agent ecosystem matures (new MCP-style standards emerge), categories migrate from "fragmented — invent minimally" to "industry protocol available — conform". The platform's design must accommodate that migration without breaking changes.

---

## Part 3 — Serverless vs Microservice agent service layer

### The framings collide because they answer different questions

| Axis | "Microservice agent server" framing | "Serverless agent service" framing |
|---|---|---|
| **Unit of deployment** | One container per agent type, always-on | Workers pulled from a pool, ephemeral, scale-to-zero |
| **Where state lives** | Inside the agent process (long-lived heap + local state) | Externalized to `Checkpointer` / `RunRepository`; the process is replaceable |
| **Inter-agent communication** | Service discovery + RPC (REST/gRPC/JSON-RPC) | Bus + Capability Registry; addressed by intent, not endpoint |
| **Long-horizon sleep** | Awkward: a 3-month sleep is held by a long-living container | Natural: agent self-destructs, bus delivers wake-up later (§5.4) |
| **Cold start** | None | Real cost — hydration time matters |
| **Operational surface** | N services x M operations x observability per service | One worker pool + bus + storage |
| **Familiar to** | Spring Cloud / SOA engineers | Cloud / event-driven engineers |
| **What the whitepaper says** | §1.3 Trap 1: "Microservice Dictatorship" — explicitly rejected | §5.4 endorses self-destruct + Chronos Hydration |

### Design difficulty (the *thinking* cost)

**Microservice agent server** — design difficulty **MEDIUM**:
- The mental model is familiar; engineers default to it.
- Hard problems are downstream of the choice: distributed transactions, retry storms, partial failure, cross-service idempotency. These have textbook answers (saga, outbox, circuit breaker — all of which `spring-ai-ascend` already has policy slots for via `ResilienceContract`).
- The whitepaper's specific rejection is concrete and worth taking seriously: as agent count grows, control-flow becomes network-flow, and the "thought loop" of an agent (microsecond cognitive ops) competes with millisecond network hops.

**Serverless agent service layer** — design difficulty **HIGH (but the work is mostly done)**:
- Every operation must be resumable. Every payload that crosses a JVM boundary must be wire-serializable.
- Every external resource (DB conn, tool session, sandbox) must support a `suspend / resume` lifecycle (this is exactly why ADR-0030 puts `init / execute / suspend / teardown` on Skill SPI).
- State versioning is a hard problem: snapshots taken at version V must remain hydratable at version V+1. The codebase has *not* tackled this yet; it's implicit in the `PayloadCodec` SPI (ADR-0022, deferred W2).
- The architecture already chose this difficulty: `SuspendSignal` + `Checkpointer` + `RunStateMachine` + posture-aware fail-closed semantics are all serverless-friendly primitives. Backing out now would mean throwing away W0.

### Engineering implementation difficulty (the *building* cost)

**Microservice approach** — engineering difficulty **HIGH** in ops, **MEDIUM** in code:
- Per-agent-type service mesh, registry, deployment pipeline, observability slice.
- Heavy operational baseline cost: even 10 agent types is 10 always-on processes, 10 observability dashboards, 10 CI pipelines.
- Code-wise mostly familiar: Spring Cloud Gateway + Nacos + Resilience4j + OpenTelemetry — the BoM already pins these.

**Serverless approach** — engineering difficulty **LOW** in ops, **HIGH** in code:
- One worker pool, one bus, one storage tier; horizontal scaling is the pool's problem.
- Code is harder: every primitive needs to support `suspend`. The serialization-versioning question is genuinely hard.
- But — critically — most of the *hard code* is already required by the current SPI contracts (ADR-0022 typed payload, ADR-0024 atomicity, ADR-0028 causal envelope). The serverless path doesn't add net difficulty; it makes the existing difficulty load-bearing.

### Where each path puts the cost

Microservice path puts the cost on **operators** (running N services, debugging cross-service failures).
Serverless path puts the cost on **the framework author** (you have to nail snapshot/hydration/versioning).

For a framework that wants to be adopted, serverless is structurally better: the framework absorbs the hard part, and the operator gets a simpler topology. For an in-house product, microservice can be cheaper if the agent fleet is small and the team already runs Spring Cloud.

### The right answer is layered, not binary

The current codebase trajectory implies a **five-tier topology**, each with its own deployment style. Crucially: "serverless vs microservice" is a false dichotomy *at the system level* — they apply at different layers, like Kubernetes (kubelet long-running + Pods ephemeral) or Spark (driver long-running + Tasks ephemeral).

| Tier | Style | Why |
|---|---|---|
| **Run execution (per-Run)** | **Serverless** (hydrated from snapshot, ephemeral, replaceable) | Whitepaper §5.4 + W0 `Checkpointer` / `SuspendSignal` / `RunRepository` SPI already commit here. A Run can suspend in instance A and resume in instance B with no awareness from the C-Side. |
| **Agent Service instance (host process)** | **Long-running microservice** | A single JVM process in a Docker container. Holds an in-flight pool of hydrated Runs and acts as a worker on the bus. Multiple replicas are deployed and coordinate via the bus. The *instance* is microservice-shaped; the *Run within an instance* is serverless-shaped. |
| **Agent Bus** | **Always-on distributed coordination** | Cross-instance, cross-docker. Carries scheduling, task management, work-state recording, three-track Control/Data/Heartbeat. Rides on standard messaging substrates (NATS / Kafka / Redpanda / gRPC streaming) but the contract is platform-owned. |
| **Other platform infrastructure** (Capability Registry, Run scheduler/dispatcher, storage gateway, audit sink) | Conventional services, multi-replica | Per-tenant authorization, capability routing, storage abstraction. Always-on. |
| **Middleware** (Mem0, Graphiti, LLMWiki, LLM gateway via LiteLLM, sandbox runners, MCP servers, observability stack, eval frameworks) | Independent third-party (their own sidecars / their own SaaS / on-prem deployments) | Outside our ownership boundary; reached via industry protocols (MCP / OTel / OpenAI-compat) where they exist. |
| **C-Side SDK** | Library (no service) | Embedded in business app; not a deployable tier of its own. |

The "elegantly serverless" framing some reviewers gave is correct *for the Run execution tier only*. Calling the entire stack serverless overstates it (the Agent Service instances + bus + registry are all long-running). Calling the whole stack microservice understates the per-Run ephemerality (and recreates the "Microservice Dictatorship" trap the whitepaper §1.3 rejects). The actual answer is layered, and the W0 codebase already commits to it at the SPI level.

---

## Part 4 — Recommendation (now superseded by ADR-0048 for near-term direction)

> **Note on supersession**: recommendation #1 below proposed a serverless commitment ADR; the user chose microservice instead (see ADR-0048). Recommendations #3 (peer-layer middleware + bus-as-platform), #4 (Agent Client SDK), #5 (vocabulary collision), and #6 (whitepaper refresh) remain valid as future-work parking-lot items.

1. **Confirm the implicit serverless commitment for agent execution and make it explicit in a new ADR**. The W0 SPI already commits here in everything but name; an ADR would close the door on accidental drift toward "one Docker per agent type" and give reviewers a citable principle. **Status**: superseded by ADR-0048 (microservice commitment for near-term; serverless preserved as future direction; SPI stays serverless-friendly).

2. **Reject the "Agent Server = one Docker with sub-agents inside" framing**. It conflicts with §4 #9 (dual-mode + interrupt-driven nesting), §4 #13 (16-KiB inline payload + PayloadStore), ADR-0024 (suspension atomicity across JVM), and whitepaper §5.4 (self-destruct on suspension). The user's mental model is a microservice intuition that doesn't fit the existing trajectory. **Status**: partially incorporated into ADR-0048's microservice-trap mitigation — the microservice commitment is for the *service layer*, not for individual agents inside a service instance.

3. **Treat middleware as a peer layer; treat the Agent Bus as platform (corrected per both user revisions)**. The middleware layer (memory backends, skill hubs, MCP servers, LLM gateways, workflow engines, sandboxes, observability stacks, eval frameworks) is an **independent third-party resource ecosystem** — the platform conforms to industry protocols (MCP, OpenTelemetry, OpenAI-compat) rather than inventing platform-centric SPIs. **The Agent Bus is NOT middleware** — it is the platform's distributed coordination backbone, carrying scheduling, task management, work-state recording, and cross-docker / cross-service communication. The bus may ride on standard messaging substrates (NATS / Kafka / Redpanda / gRPC streaming) but its contract (scheduling, capability bidding, run-state events, three-track Control/Data/Heartbeat split) is platform-owned. **Status**: bus-as-platform locked at ADR-0048. Middleware-as-peer-layer captured here for future work. Skill SPI MCP-reframing parked.

4. **Promote the Agent Client SDK from "not on the roadmap" to "wave-tagged design slot"**. It is the largest single gap between the whitepaper and the codebase. The handoff protocol (Sync State / Sub-Stream / Yield-and-Handoff) needs a counterpart SPI on the client side. Suggested first move: an ADR naming `AgentClientSdk` as a separate Maven module with a wave landing (probably W2 — needs the streaming surface from §4 #11 to be useful). **Status**: parking-lot for follow-up.

5. **Resolve the `S-side / C-side` vocabulary collision before W1 ships**. Three meanings (whitepaper / Rule 17 / ADR-0033) on one phrase will burn reviewer time and create plan-document drift. Suggested rename: whitepaper adopts **"Business-Side / Runtime-Side"** (or **"BizApp-Side / Platform-Side"**) for the responsibility split; Rule 17 retains `S-side / C-side` for substitution authority; ADR-0033 retains `S-Cloud / S-Edge / C-Device` for locus. This is purely a documentation move, but it should land in the same wave as any whitepaper refresh. **Status**: parking-lot.

6. **Treat the whitepaper itself as needing a refresh pass**. Today it reads as if the dynamic hub is shipped; it isn't. A "vision vs. shipped" header (mirroring `ARCHITECTURE.md §1`'s target-vs-W0 split per ADR-0047) would make the whitepaper honest and consistent with the rest of the corpus. **Status**: parking-lot.

---

## Open questions for the user (now resolved or parked)

These were not blockers for the analysis — they shaped what came next:

- **Deployment target**: SaaS multi-tenant (favors serverless aggressively), self-hosted enterprise (microservice is more palatable), or both? — **Resolved by ADR-0048**: microservice for the service layer is the near-term answer regardless of deployment target.
- **Decision depth wanted**: pure exploration, commit-to-direction, or wave-roadmap update? — **Resolved**: commit-to-direction via ADR-0048; wave-roadmap update parked.
- **Whitepaper refresh**: parked (recommendation #6 above).
- **Mem0 vs Graphiti**: ADR-0034 already chose Graphiti as W1 reference and explicitly *not selected* mem0. — Unchanged.

---

## Critical files & ADRs referenced (snapshot at archival time)

- `docs/spring-ai-ascend-architecture-whitepaper-en.md` — the vision under analysis
- `ARCHITECTURE.md` §1 (target vs W0 split per ADR-0047), §4 (45 constraints at archival; now 46 with §4 #46), §5 (shipped capabilities), §6 (roadmap pointers)
- `docs/governance/architecture-status.yaml` — per-capability shipped/deferred ledger
- `agent-platform/ARCHITECTURE.md` — northbound module, stateless across replicas
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/*` — `Orchestrator`, `SuspendSignal`, `Checkpointer`, `RunContext` (the serverless-friendly primitives — preserved under ADR-0048)
- `spring-ai-ascend-graphmemory-starter/` — the canonical adapter-pattern reference
- ADR-0016 — A2A federation deferred post-W4 (`AgentCard`, `RemoteAgentClient` reserved names)
- ADR-0018 — `SandboxExecutor` SPI (GraalVM Polyglot at W3 for untrusted skills)
- ADR-0021 — layered SPI taxonomy (stable cross-tier core vs tier-specific adapters; Temporal bypasses Layer 3)
- ADR-0024 — suspension write atomicity (W0 sequential -> W2 transactional -> W4 Temporal)
- ADR-0030 — Skill SPI lifecycle (`init / execute / suspend / teardown` + `SkillResourceMatrix` + `SkillTrustTier`)
- ADR-0031 — three-track channel isolation (Control / Data / Heartbeat) — design-only at W0
- ADR-0033 — Logical Identity Equivalence + deployment-locus vocabulary (S-Cloud / S-Edge / C-Device)
- ADR-0034 — memory taxonomy M1–M6; Graphiti is W1 reference for M4; mem0 + Cognee not selected
- ADR-0048 — Service-Layer Microservice-Architecture Commitment (the ADR that supersedes this analysis for near-term direction)
