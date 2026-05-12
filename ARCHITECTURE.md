# spring-ai-ascend Platform — Architecture

> Last updated: 2026-05-13 (post-seventh follow-up — §4 #37-#38, ADR-0040-0041, Gate Rules 15-18, corpus truth refresh, HTTP contract reconciliation, SPI catalog split).

## 1. System boundary

spring-ai-ascend is a self-hostable agent runtime for financial-services operators.
It accepts authenticated tenant HTTP requests, drives LLMs through a tool-calling
loop with audit-grade evidence, and persists durable side effects through an
idempotent outbox. Built on Spring Boot 4.0.5 + Java 21.

**Not in scope:** admin UI, LangChain4j dispatch, Python sidecars (out-of-process IPC),
multi-region replication, on-device models. In-process polyglot (GraalVM Polyglot embedded in
the JVM) is a W3-optional sandbox impl per ADR-0018 — it is not a sidecar. See
`docs/CLAUDE-deferred.md` for deferred items.

---

## 2. Module layout

```
spring-ai-ascend/
  pom.xml                                      # parent BOM (Java 21, Spring Boot 4.0.5)

  spring-ai-ascend-dependencies/               # Bill of Materials — pins all module +
    pom.xml                                    #   OSS transitive coords; no code

  agent-platform/                              # Northbound facade (L1: HTTP, JWT, tenant, idempotency)
    src/main/java/ascend/springai/platform/
      PlatformApplication.java
      web/
        HealthController.java                  # GET /v1/health
        HealthResponse.java
        WebSecurityConfig.java
      tenant/
        TenantContextFilter.java               # X-Tenant-Id → TenantContextHolder
        TenantContextHolder.java
        TenantFilterAutoConfiguration.java
        TenantContext.java / TenantConstants.java
      idempotency/
        IdempotencyHeaderFilter.java           # Idempotency-Key header validation (W0; no dedup)
        IdempotencyStore.java                  # W0 stub; not registered as bean
        IdempotencyFilterAutoConfiguration.java
        IdempotencyKey.java / IdempotencyConstants.java
      persistence/
        HealthCheckRepository.java
      probe/
        OssApiProbe.java

  agent-runtime/                               # Cognitive runtime kernel (SPI contracts + domain entities)
    src/main/java/ascend/springai/runtime/
      memory/spi/
        GraphMemoryRepository.java             # SPI interface (interface only, W1+)
      probe/
        OssApiProbe.java
      resilience/
        ResilienceContract.java                # Per-operation resilience routing
        ResiliencePolicy.java
        YamlResilienceContract.java            # Map-backed impl (Spring wiring deferred to W2)
      runs/
        Run.java                               # Run entity (mode, parentRunId, parentNodeKey, SUSPENDED)
        RunMode.java                           # GRAPH | AGENT_LOOP discriminator
        RunStatus.java                         # PENDING/RUNNING/SUSPENDED/SUCCEEDED/FAILED/CANCELLED/EXPIRED
        RunStateMachine.java                   # DFA validator — validate/allowedTransitions/isTerminal (Rule 20, ADR-0020)
        RunRepository.java                     # SPI interface (pure Java)
      idempotency/
        IdempotencyRecord.java                 # Idempotency entity — Rule 11 contract spine
      orchestration/spi/
        Orchestrator.java                      # Entry point: owns suspend/checkpoint/resume loop
        RunContext.java                        # Per-run ctx: tenantId, checkpointer, suspendForChild
        GraphExecutor.java                     # SPI: deterministic graph traversal
        AgentLoopExecutor.java                 # SPI: ReAct-style iterative reasoning
        ExecutorDefinition.java                # Sealed: GraphDefinition | AgentLoopDefinition
        SuspendSignal.java                     # Checked exception — one interrupt for both modes
        Checkpointer.java                      # SPI: suspend-point persistence
      orchestration/inmemory/
        InMemoryCheckpointer.java              # Dev-posture: ConcurrentHashMap-backed
        InMemoryRunRegistry.java               # Dev-posture: ConcurrentHashMap-backed RunRepository
        SyncOrchestrator.java                  # Reference: single-threaded suspend/checkpoint/resume loop
        SequentialGraphExecutor.java           # Reference: node→edge traversal with checkpoint on suspend
        IterativeAgentLoopExecutor.java        # Reference: ReAct loop with iter+state checkpoint on suspend

  spring-ai-ascend-graphmemory-starter/        # E2 adapter shell (Graphiti W1 ref per ADR-0034; auto-config disabled; full code W2)
    src/main/java/ascend/springai/runtime/graphmemory/
      GraphMemoryAutoConfiguration.java
      GraphMemoryProperties.java

```

Module dependency direction (enforced by `ApiCompatibilityTest` ArchUnit rules):

```
agent-platform  ──────────────────────────────►  [Postgres / LLMs / sidecars]

agent-runtime  ──(no platform dep)─────────────►  [Postgres / LLMs / sidecars]

spring-ai-ascend-graphmemory-starter  ──────────►  agent-runtime SPI
```

At W0 neither module depends on the other at the Maven module level. The previously
declared `agent-runtime → agent-platform` pom dependency was unused at the source level
and has been removed (ADR-0026). W1 will introduce `agent-platform-contracts` as a shared
SPI module when `agent-runtime` first needs a common type (e.g. `TenantContext` for
`RunController`).

`agent-platform` MUST NOT import `agent-runtime` Java types directly (enforced by
`ApiCompatibilityTest`). SPI packages (`ascend.springai.runtime.*.spi.*`) import
only `java.*` (enforced by `OrchestrationSpiArchTest`, `MemorySpiArchTest`).

---

## 3. OSS dependencies

| Component | Version | Role |
|---|---|---|
| Spring Boot | 4.0.5 | HTTP server, DI container, actuator |
| Spring AI | 2.0.0-M5 | ChatClient, VectorStore, MCP adapters |
| Spring Security | 6.x | JWT filter chain, SecurityFilterChain |
| Spring Cloud Gateway | see parent POM (`spring-cloud.version`) | Edge routing (W2) |
| MCP Java SDK | see parent POM (`mcp.version`) | Tool protocol (W3) |
| Java (OpenJDK) | 21 | Virtual threads (Project Loom) |
| PostgreSQL | 16 | Relational + vector (pgvector) + outbox |
| Flyway | see parent POM | Schema migrations |
| HikariCP | see parent POM | Connection pool |
| Temporal Java SDK | see parent POM (`temporal.version`) | Durable workflow engine (W4) |
| Resilience4j | see parent POM (`resilience4j.version`) | Circuit breaker, rate limiter |
| Caffeine | see parent POM (`caffeine.version`) | In-process L0 cache |
| Apache Tika | see parent POM | Document parsing (W3) |
| Micrometer + Prometheus | latest | Metrics (`springai_ascend_*` prefix) |
| Testcontainers | see parent POM (`testcontainers.version`) | Integration test containers |
| Maven | 3.9 | Build, multi-module |

---

## 4. Architecture constraints

1. **Dependency direction**: neither `agent-platform` nor `agent-runtime` depends on
   the other at the Maven module level. `agent-platform` MUST NOT import `agent-runtime`
   Java types (enforced by `ApiCompatibilityTest`). The `agent-runtime/pom.xml` dependency
   on `agent-platform` was a speculative dead-weight reference with zero source imports; it
   has been removed (ADR-0026). W1 will add `agent-platform-contracts` as a shared SPI
   module when a common type is genuinely needed.

2. **Posture model**: `APP_POSTURE={dev|research|prod}`. Read once at boot.
   `dev` is permissive (in-memory stores, relaxed validation).
   `research` and `prod` are fail-closed (Vault secrets, durable stores, strict JWT).

3. **Tenant isolation** (phased by wave):
   - W0 (shipped): `TenantContextFilter` reads `X-Tenant-Id` header (UUID shape),
     stores in `TenantContextHolder` + MDC. Every persistent record carries
     `tenant_id NOT NULL`.
   - W1 (planned): add JWT `tenant_id` claim cross-check against the existing
     `X-Tenant-Id` header; validate against `tenants` table (ADR-0040).
   - W2 (planned): add `SET LOCAL app.tenant_id = :id` GUC inside each transaction;
     enable Postgres RLS policies on tenant tables. See ADR-0005, ADR-0023.

4. **Idempotency** (phased by wave):
   - W0 (shipped): `IdempotencyHeaderFilter` validates the `Idempotency-Key` header
     (UUID shape, required on POST/PUT/PATCH; missing returns 400 in research/prod).
     No deduplication, no caching, no `IdempotencyStore` interaction.
   - W1 (planned): wire `IdempotencyStore` with `(tenant_id, key)` claim/replay
     semantics; concurrent duplicate returns 409; backed by Postgres `idempotency_dedup`
     table. See ADR-0027.

5. **Metric naming**: all custom Micrometer metrics use the prefix
   `springai_ascend_`. No bare or provider-prefixed names on platform meters.

6. **OSS-first**: every core concern is delegated to an existing OSS project.
   New glue must answer "why is this not a configuration of an existing OSS dep?"
   Glue LOC target ≤ 1 500 at W0 close.

7. **SPI purity**: SPI interfaces under `ascend.springai.runtime.*.spi.*`
   import only `java.*`. No Spring, Micrometer, or platform types in SPIs.

8. **Per-operation resilience routing**: `ResilienceContract` maps `operationId`
   (e.g. `"llm-call"`, `"vector-search"`) to a `ResiliencePolicy(cbName, retryName, tlName)`.
   Call sites use Resilience4j annotations with the resolved names. Spring
   `@ConfigurationProperties` wiring is deferred to W2 LLM gateway.

9. **Dual-mode runtime + interrupt-driven nesting**: both `GraphExecutor` (deterministic
   state machine) and `AgentLoopExecutor` (ReAct-style) use one interrupt primitive
   (`SuspendSignal`) to delegate to a child run. Ownership at suspension is split:
   executors persist executor-local **resume cursors** (keys `_graph_next_node`,
   `_loop_resume_iter`, `_loop_resume_state`) via `Checkpointer.save()`; the
   `Orchestrator` persists the **Run row** (status=SUSPENDED) via `RunRepository.save()`.
   Both writes must be observable atomically (ADR-0024 — sequential at W0, transactional
   at W2). `Run.mode` discriminates `GRAPH` vs `AGENT_LOOP`; `Run.parentRunId` +
   `Run.parentNodeKey` encode the nesting chain. Durability tiers: in-memory (dev/W0)
   → Postgres checkpoint (W2) → Temporal child workflow (W4). Layered SPI taxonomy:
   stable cross-tier core (Layer 1: `Run`, `RunStatus`, `RunRepository`, `RunContext`,
   `Orchestrator`) + tier-specific adapters (Layers 2–3: `Checkpointer`,
   `IdempotencyStore`); W4 Temporal bypasses Layer 3 entirely (ADR-0021).

10. **Long-horizon lifecycle.** `Run` is an execution record; long-horizon agent identity
    is `AgentSubject` (deferred — `agent_subject_identity`). `SuspendSignal` will gain typed
    reasons (`ChildRun | AwaitTimer | AwaitExternal | AwaitApproval | RateLimited`); single-cause
    suspend is a W0 reference-only constraint. `RunRepository` queries that may return unbounded
    sets MUST gain `Pageable` parameters before W2 (`repository_paging_contract`). No `archivedAt`
    hook at W0; archival lifecycle is deferred.

11. **Northbound handoff contract.** Three modes: synchronous `Object` return (shipped), streamed
    `Flux<RunEvent>` (deferred W2 — Rule 15), yield-via-`SuspendSignal` (shipped). When streaming
    is introduced, the surface MUST carry: (a) backpressure strategy, (b) cancellation propagation
    to `RunStatus.CANCELLED`, (c) heartbeat cadence ≤ 30 s, (d) terminal frame with `runId` +
    final `RunStatus`, (e) typed progress events — no raw `Object`. The W2 streamed surface is
    split into three physical tracks (§4 #28): Control (cancel/suspend commands), Data
    (`Flux<RunEvent>` progress), Heartbeat (liveness cadence). See `streamed_handoff_mode`,
    `orchestrator_cancellation_handshake`, `three_track_channel_isolation`, ADR-0031.

12. **Two-axis resource arbitration.** `ResilienceContract.resolve(operationId)` extends to a
    two-axis policy `(tenantQuota, globalSkillCapacity)` (`skill_capacity_matrix`). Skill saturation
    MUST suspend the Run (`SUSPENDED + suspendedAt + reason=RateLimited`) rather than fail. Call-tree
    budget propagates through `RunContext` (`call_tree_budget_propagation`). Per Rule 16. The Skill
    SPI (§4 #27) adds per-skill `SkillResourceMatrix` declarations that feed into both quota axes;
    see ADR-0030.

13. **Payload addressing and serialization contract.** `Checkpointer.save` carries opaque bytes
    ≤ 16 KiB inline; larger payloads MUST be references to `PayloadStore` (`payload_store_spi`).
    The 16-KiB cap is enforced at W0 by `InMemoryCheckpointer` (posture-aware: dev warns, research/
    prod throws). `SuspendSignal.resumePayload` is an in-process `Object` correct for W0 in-memory
    only; when the durability tier crosses JVM boundaries (W2 Postgres, W4 Temporal), resumePayload
    MUST be serializable to bytes (`serializable_resume_payload`). Above the serialization layer,
    every payload that crosses a suspend boundary MUST be wrapped in a `CausalPayloadEnvelope`
    (§4 #25) declaring its `SemanticOntology` and carrying a SHA-256 fingerprint for tamper
    detection. Checkpoint eviction: Runs in terminal status become evictable after N days (deferred
    — `checkpoint_eviction_policy`). See ADR-0028.

14. **Resume re-authorization.** Resuming a suspended Run is a re-authorization boundary.
    The resume request's tenant context MUST match the original `Run.tenantId`; mismatch returns
    403 (`resume_reauthorization_check`). Actor identity at resume is captured in an audit envelope.
    Degradation authority: S-side may substitute means (alternative tool/model) without C-side
    approval; ends-modification requires explicit C-side authority. Per Rule 17.

15. **SPI serialization path.** Orchestration SPI types are pure Java (`OrchestrationSpiArchTest`)
    AND must be wire-serializable by W4. `ExecutorDefinition.NodeFunction` / `Reasoner` are inline
    lambdas at W0 — correct for in-process; before W2 Postgres-backed async orchestrator, they
    MUST become named `CapabilityRegistry` entries resolved by name, not inline closures
    (`capability_registry_spi`, `executor_definition_serialization`).

16. **Runtime Hook SPI.** Every LLM invocation, tool call, and agent lifecycle boundary flows
    through a hook chain. Hook positions: `PRE_LLM_CALL` / `POST_LLM_CALL` / `PRE_TOOL_INVOKE` /
    `POST_TOOL_INVOKE` / `PRE_AGENT_TURN` / `POST_AGENT_TURN`. Hooks are pluggable `@Bean`s
    implementing typed `RuntimeHook` interfaces; the chain is ordered and failsafe (hook failure
    logs at `WARNING+` and does not abort the invocation). Reference hooks shipped in W2: PII
    filter, token counter, summariser, tool-call-limit. Direct LLM/tool calls that bypass
    `HookChain` are a gate-blocking defect (Rule 19 — deferred W2; `HookChain` SPI and
    `HookChainConformanceTest` do not exist at W0).

17. **Graph DSL conformance.** `ExecutorDefinition.GraphDefinition` MUST support beyond W2:
    (a) per-key `StateReducer` registry (`OverwriteReducer` — last-write-wins; `AppendReducer` —
    list concat; `DeepMergeReducer` — recursive map merge) applied when a node returns a partial
    state update;
    (b) typed `Edge` records replacing the flat `Map<String,String>` edges — an `Edge` may carry
    an optional predicate (`Function<RunContext, Boolean>`) for conditional routing;
    (c) JSON and Mermaid export of the compiled graph topology for debugging and documentation.
    A backward-compatible factory method (`GraphDefinition.simple(nodes, edges, startNode)`)
    retains the existing API. Implementation deferred to W3 (`graph_dsl_conformance`).

18. **Eval Harness Contract.** Every shipped capability MUST declare, by W4: (a) a golden
    corpus in `docs/eval/<capability>/corpus.jsonl` — versioned input/expected pairs;
    (b) an LLM-as-judge evaluator definition (judge model, prompt template, metric name);
    (c) a per-metric regression threshold checked in as `docs/eval/<capability>/thresholds.yaml`.
    Pre-merge gate (Rule 18, W4+): re-run corpus; any metric below its threshold blocks merge.
    Evaluation infrastructure (corpus loader, judge runner, result store) deferred to W4
    (`eval_harness_contract`).

19. **Fan-out, suspend-reason taxonomy, and suspend-deadline contract.** `SuspendSignal` MUST
    carry a sealed `SuspendReason` identifying why the run is suspended. Every reason MUST carry a
    `deadline() : Instant` at which the suspended run transitions to `EXPIRED` if not resumed.
    Sealed variants: `ChildRun(UUID childRunId, ChildFailurePolicy, Instant deadline)` |
    `AwaitChildren(List<UUID> childRunIds, JoinPolicy, ChildFailurePolicy, Instant deadline)` |
    `AwaitTimer(Instant fireAt)` | `AwaitExternal(String callbackToken, Instant deadline)` |
    `AwaitApproval(String approvalRequestId, Instant deadline)` |
    `RateLimited(String resourceKey, Instant retryAfter)`.
    `JoinPolicy: ALL | ANY | N_OF`; `ChildFailurePolicy: PROPAGATE | IGNORE | COMPENSATE`.
    W0 reference impl covers only single-`ChildRun`; remaining variants are contract-level,
    deferred to W2 (`suspend_reason_taxonomy`, `parallel_child_dispatch`, `suspend_deadline_watchdog`).
    See ADR-0019.

20. **RunStatus formal transition DFA + transition audit trail.** Legal transitions:
    `PENDING → RUNNING | CANCELLED`; `RUNNING → SUSPENDED | SUCCEEDED | FAILED | CANCELLED`;
    `SUSPENDED → RUNNING | EXPIRED | FAILED | CANCELLED`; `FAILED → RUNNING` (retry, new `attemptId`);
    `SUCCEEDED`, `CANCELLED`, `EXPIRED` are terminal. Every `Run.withStatus(newStatus)` MUST invoke
    `RunStateMachine.validate(from, to)`, throwing `IllegalStateException` on illegal transitions
    (Rule 20, enforced at W0). Idempotency: `cancel` on already-cancelled run returns 200 + same row;
    `cancel` on `SUCCEEDED`/`EXPIRED` returns 409. Every transition writes a `run_state_change` audit
    row (W2); optimistic lock (`version` field) required before W2 Postgres. See ADR-0020.

21. **Typed payload + PayloadCodec SPI.** Every payload crossing a JVM boundary (checkpoint bytes,
    resume payload, streaming event) MUST be encoded via a registered `PayloadCodec<T>` with stable
    `codecId` and `typeRef`. `RawPayload(Object)` is valid only within a single JVM. `EncodedPayload
    (byte[], String codecId, String typeRef)` is the persistence contract. `RunEvent` (streamed
    northbound per §4 #11) is a sealed interface: `NodeStarted | NodeCompleted | Suspended | Resumed |
    Failed | Terminal`. PII redaction hooks (§4 #16) depend on `TypedPayload<T>` to locate PII fields
    per type. All implementation deferred to W2 (Rule 22). See ADR-0022.

22. **Canonical run context propagation.** `RunContext.tenantId()` is the sole carrier of tenant
    identity inside `agent-runtime`. `TenantContextHolder` (HTTP-edge ThreadLocal in `agent-platform`)
    MUST NOT be read by any production class under `ascend.springai.runtime.*`. Enforced at W0 by
    `TenantPropagationPurityTest` (ArchUnit — Rule 21). Timer-driven and async resumes source tenant
    from `Run.tenantId`. `TenantContextFilter` populates Logback MDC `tenant_id` alongside
    `TenantContextHolder` for log correlation (shipped at W0). `RunContext.tenantId() : String` migrates
    to `UUID` at W1 alongside Keycloak integration. Micrometer `tenant_id` tag enforcement and OTel
    `traceparent` propagation across suspend are deferred to W1/W2. See ADR-0023.

23. **Suspension write atomicity.** At the suspension boundary, `RunRepository.save(suspended)` and
    `checkpointer.save(runId, nodeKey, payload)` MUST be observable atomically. Tiered contract:
    W0 in-memory — single-threaded, sequential on same call stack (invariant documented in
    `SyncOrchestrator.executeLoop` javadoc); W2 Postgres — both in one `@Transactional` block;
    W2 Redis Checkpointer — transactional outbox (ADR-0007); W4 Temporal — SPI bypassed entirely.
    Any W2+ orchestrator that violates this contract is a ship-blocking defect (Rule 23, deferred).
    See ADR-0024.

24. **Typed payload + PayloadCodec SPI.** *(Renumbered — formerly constraint #21 in this list.)*
    See §4 #21 above. No content change; number preserved for backward reference in older docs.

25. **Causal payload envelope and semantic ontology.** Every payload that crosses a suspend/resume
    boundary at W2+ MUST be wrapped in a `CausalPayloadEnvelope` declaring: (a) `SemanticOntology`
    tag — `FACT | PLACEHOLDER | HYPOTHESIS | REDACTED`; (b) `payloadFingerprint` — SHA-256 hex of
    encoded bytes (tamper detection on resume); (c) `byteSize` and `decayed` flag (logical decay:
    payloads exceeding 16 KiB inline cap are replaced with a `PayloadStoreRef`). Consumers MUST
    inspect the `SemanticOntology` tag before passing content to LLM context: `PLACEHOLDER` data
    MUST NOT be interpreted as a verified fact. The PII filter hook (§4 #16) exempts `PLACEHOLDER`
    and `REDACTED` payloads from further field-level redaction. Implementation deferred to W2.
    See ADR-0028, `causal_payload_envelope`, `semantic_ontology_tags`, `payload_fingerprint_precommit`.

26. **Cognition-Action separation.** Cognitive processes (LLM-driven reasoning, plan synthesis,
    hallucination tolerance) are isolated from action processes (database writes, tool invocations,
    RLS-bound transactions, idempotent outbox events) by the orchestration SPI boundary. Cognitive
    processes observe and produce *intent*; action processes execute *verified intent* with full
    determinism and auditability. Neither layer may bypass the SPI to reach the other directly.
    Language policy: the cognitive layer MAY be implemented in any language that can call the
    `Orchestrator` SPI. W0-W2 default: Spring AI Java (ChatClient). W3 optional: GraalVM in-process
    polyglot (ADR-0018), MCP Java SDK remote tool server. No language is mandatory.
    `CapabilityRegistry` entries carry a `SkillKind` discriminator (`JAVA_NATIVE | MCP_TOOL |
    SANDBOXED_CODE_INTERPRETER`) defining the dispatch path. See ADR-0029, `cognition_action_separation`.

27. **Skill SPI: lifecycle, ResourceMatrix, posture-mandatory sandbox.** Every external capability
    MUST be registered via the `Skill` SPI with: (a) lifecycle methods `init / execute / suspend /
    teardown` — `teardown` is called unconditionally even when `execute` throws; (b)
    `SkillResourceMatrix` declaring `(tenantQuotaKey, globalCapacityKey, tokenBudget, wallClockMs,
    cpuMillis, maxMemoryBytes, concurrencyCap)` — the Orchestrator validates declared limits before
    `init()` AND enforces the subset supported by the dispatch path (see ADR-0038 §4 tiers); (c)
    `SkillTrustTier (VETTED | UNTRUSTED)` — in research/prod posture, `UNTRUSTED`
    skills MUST route through a non-`NoOp` `SandboxExecutor` (ADR-0018); startup gate asserts
    (Rule 27, deferred W3). Every `execute()` returns a `SkillCostReceipt` for Rule 13 (P1). When
    a Run is SUSPENDED, `Skill.suspend()` releases heavy resources; `Skill.resume(token)` reconnects
    before the next `execute()`. Implementation deferred to W2 (SPI) + W3 (mandatory sandbox).
    See ADR-0030, `skill_spi_lifecycle`, `skill_resource_matrix`, `untrusted_skill_sandbox_mandatory`.

28. **Three-track channel isolation.** The W2 northbound streaming surface (§4 #11) is physically
    split into three tracks: (1) **Control** — `RunControlSink.push(RunControlCommand)`: out-of-band
    cancel/priority-suspend commands delivered before the next executor iteration boundary; (2)
    **Data** — `Flux<RunEvent>`: typed progress events with caller-controlled demand and bounded
    buffer (default 64 events, DROP_OLDEST overflow — Terminal events never dropped); (3)
    **Heartbeat** — `Flux<Instant>`: liveness cadence on a dedicated scheduler independent of data
    channel load, cadence `≤ 30 s`. `CapabilityRegistry.resolve(name, runContext)` is tenant-scoped:
    lookups for capabilities not authorised for the requesting tenant are rejected. A `RunDispatcher`
    SPI separates intent-enqueue from intent-execute for async dispatch at W2. Implementation
    deferred to W2. See ADR-0031, `three_track_channel_isolation`, `run_dispatcher_spi`.

29. **Scope-based run hierarchy + planner contract.** `Run` carries a `RunScope` discriminator
    (`STEP_LOCAL | SWARM`): `STEP_LOCAL` runs are orchestrator-local, directly addressable by
    `parentRunId` chain; `SWARM` runs are federated across multiple orchestrators and visible only
    via `AgentRegistry`. `SuspendReason.SwarmDelegation` variant covers delegation to a SWARM child.
    Minimal planner contract: `PlanState` (current plan status) and `RunPlanRef` (reference from a
    Run row to its associated plan artifact) are the design-level types; full `RunPlanSheet` toolset
    deferred to W4. `RunRepository.findRootRuns(tenantId)` (shipped W0) returns top-level runs with
    `parentRunId == null`. `RunScope` Java field on the `Run` entity deferred to W2. See ADR-0032.

30. **Logical identity equivalence + deployment-locus vocabulary.** The platform recognizes three
    deployment loci: `S-Cloud` (server-side, cloud-hosted), `S-Edge` (server-side, edge-deployed
    at network boundary), `C-Device` (client-resident, on-device). A capability designated for
    `S-Cloud` MUST remain functionally equivalent when deployed at `S-Edge` (same SPI, same
    security controls, same tenant isolation — only the execution venue differs). The existing
    Rule 17 vocabulary `S-side / C-side` is **preserved unchanged** — it expresses substitution
    authority (who may substitute means vs ends), not deployment location. No `edge` posture
    variant is introduced; the three-posture model (`dev/research/prod`) is sufficient. Locus
    scheduling is post-W4. See ADR-0033, `logical_identity_equivalence`.

31. **Memory and knowledge taxonomy.** The platform recognizes six memory categories:
    M1 Short-Term Run Context (in-process per run, TTL = run lifetime);
    M2 Episodic Session Memory (across turns in a session, tenant-scoped);
    M3 Semantic Long-Term (persistent embeddings, tenant-scoped);
    M4 Graph Relationship Memory (graph nodes/edges, tenant-scoped);
    M5 Knowledge Index (indexable documents/chunks, tenant-scoped);
    M6 Retrieved Context (ephemeral RAG results, TTL = turn lifetime).
    All persistent memory entries carry a common `MemoryMetadata` schema:
    `{tenantId, runId?, sessionId?, source, ontologyTag, confidence, retentionExpiry,
    embeddingModel?, redactionState, visibilityScope}`.
    W1 reference sidecar: Graphiti (graph relationship memory, M4). mem0 and Cognee are not
    selected. Code-level implementation deferred to W2. See ADR-0034, `memory_knowledge_taxonomy`.

32. **Posture enforcement single-construction-path.** All posture reads MUST flow through
    `AppPostureGate.requireDevForInMemoryComponent(componentName)`. No class other than
    `AppPostureGate` may call `System.getenv("APP_POSTURE")` (Rule 6 single-construction-path).
    `dev` or missing: emits WARN to stderr and continues; `research`/`prod`: throws
    `IllegalStateException` with ADR-0035 reference. Gate Rule 12 enforces the literal
    `AppPostureGate.requireDev` in `SyncOrchestrator`, `InMemoryRunRegistry`, and
    `InMemoryCheckpointer`. `docs/cross-cutting/posture-model.md` is the canonical posture-truth
    ledger; every posture-aware component row MUST appear there. See ADR-0035,
    `posture_single_construction_path`.

33. **Contract-surface truth (generalized Rule 25).** Beyond the four original Rule 25 cases,
    two additional truth constraints are gate-enforced: Gate Rule 13 — `contract-catalog.md` MUST
    NOT reference any deleted SPI interface name or deleted starter coordinate (deleted-name list
    sourced from `architecture-status.yaml` `sdk_spi_starters` note); Gate Rule 14 — every method
    name appearing in a code-fence block in `agent-platform/ARCHITECTURE.md` or
    `agent-runtime/ARCHITECTURE.md` MUST exist in the named Java class (pragmatic regex sweep).
    See ADR-0036, `contract_surface_truth_generalization`.

34. **Wave authority consolidation.** A single chain of authority governs wave-planning decisions:
    (1) `ARCHITECTURE.md` §1 + §4 — wave boundary constraints; (2)
    `docs/governance/architecture-status.yaml` — per-capability shipped/deferred status;
    (3) `docs/CLAUDE-deferred.md` — deferred engineering rules with re-introduction triggers.
    All other planning documents are informational or archived. Stale parallel plans
    (`roadmap-W0-W4.md`, `engineering-plan-W0-W4.md`) are archived in
    `docs/archive/2026-05-13-plans-archived/`. See ADR-0037, `wave_authority_consolidation`.

35. **Skill SPI resource-tier classification.** `SkillResourceMatrix` fields are grouped into four
    enforceability tiers: (a) **Hard-enforceable** — quota key, token budget, wall-clock timeout,
    concurrency cap, trust tier, sandbox requirement for UNTRUSTED; Orchestrator checks these before
    `init()` and blocks or routes through sandbox; (b) **Sandbox-enforceable** — CPU millis and
    max-memory-bytes; enforced only when the dispatch path routes through a non-NoOp
    `SandboxExecutor`; (c) **Advisory/receipt** — observed CPU time, memory, and wall-clock logged
    as `SkillCostReceipt`; no enforcement, only cost attribution; (d) **Skill-specific hints** —
    freeform metadata passed through to the skill implementation. Claims about CPU/memory enforcement
    in documentation MUST qualify which tier they target. See ADR-0038, `skill_spi_resource_tiers`.

36. **Payload migration adapter strategy.** There is one normative migration path for payload types:
    raw `Object` → `Payload` (typed, ADR-0022) → `CausalPayloadEnvelope` (causally annotated,
    ADR-0028). Any `NodeFunction` or `Reasoner` implementation using raw `Object` parameters MUST
    be wrapped with `PayloadAdapter.wrap(Object)` before being passed to a typed boundary. A
    `@Deprecated` annotation window is mandatory on any method with raw `Object` payload before
    removal; removal without an adapter wrapper is a ship-blocking defect. See ADR-0039,
    `payload_migration_adapter`.

37. **W1 HTTP contract reconciliation.** W1 tenant identity: `X-Tenant-Id` header stays required;
    W1 adds JWT `tenant_id` claim cross-check against the header value (403 on mismatch). The
    initial run status is `PENDING` (matching `RunStatus` enum and RunStateMachine DFA). Cancellation
    is a state transition expressed as `POST /v1/runs/{id}/cancel` (not `DELETE`); run records survive
    cancellation as terminal records. Gate Rule 16 enforces these three points across the five active
    HTTP contract documents. See ADR-0040, `w1_http_contract_reconciliation`.

38. **Active-corpus truth sweep.** No active document outside `docs/archive/` and `docs/reviews/`
    may reference the two deleted plan paths (the engineering plan and the roadmap archived under
    `docs/archive/2026-05-13-plans-archived/` per ADR-0037). Wave-planning information from those
    files lives exclusively in the single wave authority (§4 #34). ADR references are repointed to
    the archived copies. The companion systems-engineering plan is archived alongside its peers.
    Gate Rule 15 enforces the deleted-path freeze. See ADR-0041, `active_corpus_truth_sweep`.

---

## 5. W0 shipped capabilities

- `GET /v1/health` — liveness probe; JSON `{status, sha, db_ping_ns, ts}`.
- `TenantContextFilter` — extracts `X-Tenant-Id` header (UUID shape), propagates via
  `TenantContextHolder` + MDC `tenant_id`. (W0: header-only; W1: JWT claim; W2: GUC+RLS.)
- `IdempotencyHeaderFilter` — validates UUID shape of `Idempotency-Key` header on
  POST/PUT/PATCH; missing key returns 400 in research/prod. (W0: validation only;
  W1: dedup + caching backed by `IdempotencyStore`. See ADR-0027.)
- `IdempotencyStore` — `@Component` present but not injected at W0 (dev: WARNING log;
  research/prod: throws `IllegalStateException`). Wired in W1.
- `GraphMemoryRepository` SPI — interface only; no implementation shipped.
- `ResilienceContract` + `YamlResilienceContract` — per-operation resilience routing (operationId → policy triple).
- `Run` entity + `RunRepository` SPI — contract-spine entity (Rule 11 target); `mode` field (`GRAPH`|`AGENT_LOOP`) discriminates executor type; `parentRunId` + `parentNodeKey` + `SUSPENDED` status support interrupt-driven nesting.
- `IdempotencyRecord` entity — contract-spine entity with mandatory `tenantId` (Rule 11 target).
- `OssApiProbeTest` — compile-time probe verifying Spring AI + Spring Boot API surface.
- `ApiCompatibilityTest` — ArchUnit rules enforcing SPI purity and dependency direction.
- `TenantPropagationPurityTest` — ArchUnit Rule 21: no `agent-runtime` main class may import `TenantContextHolder`.
- `Orchestrator` SPI + `GraphExecutor` + `AgentLoopExecutor` + `SuspendSignal` + `Checkpointer` — dual-mode runtime SPIs (§4 constraint #9).
- `RunStateMachine` — DFA validator enforcing §4 #20 legal transitions; `validate/allowedTransitions/isTerminal` (Rule 20). `RunStatus.EXPIRED` added as 7th terminal value.
- `InMemoryCheckpointer` — dev-posture in-memory checkpoint store with posture-aware 16-KiB
  payload cap (§4 #13 / §4 #25): dev posture emits WARN on oversize; research/prod throws
  `IllegalStateException`. W2: replaced by Postgres-backed impl.
- `SyncOrchestrator` + `SequentialGraphExecutor` + `IterativeAgentLoopExecutor` + `InMemoryRunRegistry`
  — reference executors proving 3-level bidirectional graph↔agent-loop nesting via `SuspendSignal`
  interrupt. `IterativeAgentLoopExecutor` enforces W0 String-cursor contract: throws
  `IllegalStateException` (with ADR-0022 reference) when a non-String payload would be silently
  corrupted by `Object.toString()` (HD-A.8 fix). Dev-posture only; not on the production code path.

---

## 6. Roadmap pointers

- Deferred capabilities and re-introduction triggers: `docs/CLAUDE-deferred.md`
- Current per-capability state and maturity levels: `docs/STATE.md`
- Per-capability shipped/deferred status: `docs/governance/architecture-status.yaml`
- Design rationale for pre-C26 decisions: `docs/v6-rationale/`
- Wave delivery plan (archived): `docs/archive/2026-05-13-plans-archived/` (see ADR-0037)
- OSS BoM with per-dep verification level: `docs/cross-cutting/oss-bill-of-materials.md`
