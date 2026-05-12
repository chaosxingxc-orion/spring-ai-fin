# L0 Architecture Readiness Review: Java Microservice and Agent-Driven Runtime

Date: 2026-05-13

Audience: Architecture design team

Scope: current root and module `ARCHITECTURE.md` files, ADR-0022 through ADR-0031, `architecture-status.yaml`, active plans, contract documents, and the current Java W0 implementation.

## Executive verdict

Do not publish a clean L0 release note yet.

The active root and module architecture documents are materially cleaner than the earlier review state. The core W0 direction is sound: Java 21 + Spring Boot, Spring AI as the default cognitive surface, strict module dependency direction, tenant propagation purity, posture-aware idempotency, explicit run-state DFA, and a reference in-memory orchestration path. This is close to an L0 architecture baseline.

However, L0 is not fully release-note clean because several active companion documents still claim contracts that no longer exist, and several agent-driven contracts are either underspecified for future implementation or overstate what the Java microservice can enforce. These are architecture-design issues, not merely editorial nits, because a W1/W2 implementer could build against the wrong starter set, the wrong planning API, the wrong memory taxonomy, or the wrong runtime enforcement semantics.

## L0 standard used in this review

For this review, L0 is considered complete only when:

- The system boundary, waves, and contract spine are internally consistent across active architecture documents.
- Active documents do not claim missing modules, missing starters, missing interfaces, or missing tests as available contracts.
- Deferred W1/W2/W3 designs are explicit about what is design-only versus shipped.
- Agent-driven concepts such as planning, skills, memory, and knowledge have a minimum contract shape that future work can implement without breaking the W0 SPI unexpectedly.
- Overdesigned items are either reduced to the minimum L0 decision or explicitly marked as non-L0 / future research.

## Root-cause block

Observed failure: A clean L0 release note cannot be issued because the active architecture corpus still contains contradictory contract claims and several agent-driven contracts lack precise L0 boundaries.

Execution path: A developer reading `ARCHITECTURE.md` is directed to `docs/plans/engineering-plan-W0-W4.md`, `docs/contracts/contract-catalog.md`, ADRs, and `docs/governance/architecture-status.yaml`; these companion documents then point to deleted starters, stale wave definitions, non-existent API fields, or enforcement promises that the current code cannot satisfy.

Root cause: The 2026-05-12 Occam pass and fifth-review ADR updates refreshed the root/module architecture faster than the companion contract catalog, roadmap, engineering plan, and selected status-ledger rows, while some future agent abstractions were promoted into L0 text before their minimal enforceable contract was normalized.

Evidence: see findings below.

## What looks strong enough for L0

1. Java microservice boundary is clear.
   - `ARCHITECTURE.md:12-15` excludes admin UI, LangChain4j dispatch, out-of-process Python sidecars, multi-region replication, and on-device models.
   - `ARCHITECTURE.md:330-335` keeps cognition-action separation language-neutral while making Spring AI Java the W0-W2 default.

2. The W0 platform/runtime split is substantially repaired.
   - `ARCHITECTURE.md:100` states that `agent-platform` and `agent-runtime` do not depend on each other at the Maven module level.
   - `docs/governance/architecture-status.yaml:649` records the dependency-direction cleanup.

3. Tenant propagation and run-state validity have enforceable W0 anchors.
   - `ARCHITECTURE.md:296-303` defines `RunContext.tenantId()` as the runtime carrier and forbids runtime production reads from `TenantContextHolder`.
   - `ARCHITECTURE.md:283-286` defines the legal run-state DFA and terminal handling.

4. The no-mandatory-Python decision is good architecture hygiene.
   - ADR-0029 distinguishes out-of-process Python sidecars from optional in-process polyglot and MCP tool servers. This avoids turning language choice into a platform invariant too early.

These decisions do not appear overdesigned for L0. They give W1/W2 implementation teams a stable direction without forcing premature infrastructure.

## Findings That Should Block A Clean L0 Release Note

### P1 - Contract catalog still describes the deleted starter/SPI model

`docs/contracts/contract-catalog.md` is still written for the pre-Occam architecture:

- `docs/contracts/contract-catalog.md:16` claims "10 interfaces, all L1".
- `docs/contracts/contract-catalog.md:20` lists `LongTermMemoryRepository`, `ToolProvider`, `LayoutParser`, `DocumentSourceConnector`, `PolicyEvaluator`, `IdempotencyRepository`, and `ArtifactRepository`.
- `docs/contracts/contract-catalog.md:28` and `docs/contracts/contract-catalog.md:48` claim starter surfaces such as `-memory`, `-skills`, `-knowledge`, `-governance`, `-persistence`, `-resilience`, `-mem0`, `-docling`, and `-langchain4j-profile`.

This conflicts with the current source of truth:

- `docs/governance/architecture-status.yaml:11-15` says there are 4 reactor modules, 0 SDK SPI starters, and 1 sidecar adapter starter.
- `docs/governance/architecture-status.yaml:84` says 9 SDK SPI starters were deleted in the Occam pass.
- The only searched Java interface among the deleted SPI names that still exists is `ResilienceContract`; the listed deleted SPI interfaces are not present.
- `pom.xml:224-264` still keeps dependency-management coordinates for many deleted starters even though only `spring-ai-ascend-graphmemory-starter` exists as a module.

Recommendation:

- Rewrite `contract-catalog.md` around the current four-module reactor and actual SPI set.
- Remove or clearly mark stale dependency-management coordinates for deleted starters.
- Add a gate that fails when active contract docs name a starter artifact that has no module and no intentionally published coordinate.

### P1 - Roadmap and engineering plan are stale enough to mislead implementation

`docs/plans/roadmap-W0-W4.md` still conflicts with the current architecture:

- `docs/plans/roadmap-W0-W4.md:12` says W0 has `/health`, `/ready`, and stub run routes; the active W0 public route is `GET /v1/health` (`ARCHITECTURE.md:364`).
- `docs/plans/roadmap-W0-W4.md:42-48` labels W2 as "Security Gate" with an 11-stage ActionGuard; the refreshed architecture and engineering plan stage ActionGuard in W3 and use a 5-stage chain.
- `docs/plans/roadmap-W0-W4.md:88-98` describes LangChain4j and Python sidecar support gated behind W2; `ARCHITECTURE.md:12-15` excludes LangChain4j dispatch and out-of-process Python sidecars from scope.

`docs/plans/engineering-plan-W0-W4.md` is also stale:

- `docs/plans/engineering-plan-W0-W4.md:6` was last refreshed on 2026-05-08, while the active architecture was refreshed on 2026-05-12.
- `docs/plans/engineering-plan-W0-W4.md:362-364` still lists Spring AI 1.0.x coordinates, while `ARCHITECTURE.md:117` uses Spring AI 2.0.0-M5.
- `docs/plans/engineering-plan-W0-W4.md:493` says MCP Java SDK "likely 0.x", while the root architecture defers to the parent POM.
- `docs/plans/engineering-plan-W0-W4.md:616` still mentions multi-framework dispatch / Python sidecar as W4+ post work.
- `docs/plans/engineering-plan-W0-W4.md:8` and `docs/plans/engineering-plan-W0-W4.md:713` still use the old 32-dimension scoring framework language.

Recommendation:

- Either refresh these plans as active L0/W0-W4 planning documents or move them under an archive path with a banner saying they are historical.
- Make the root `ARCHITECTURE.md` and `architecture-status.yaml` the only active wave authority until the plans are refreshed.

### P1 - Posture and idempotency behavior has active truth drift

`docs/cross-cutting/posture-model.md` conflicts with the current W0 code and status ledger:

- `docs/cross-cutting/posture-model.md:20` only names missing `Idempotency-Key` on POST, while the filter applies to POST, PUT, and PATCH.
- `docs/cross-cutting/posture-model.md:22` says `IdempotencyStore.claimOrFind(...)` throws `UnsupportedOperationException` in research/prod.
- `agent-platform/src/main/java/ascend/springai/platform/idempotency/IdempotencyHeaderFilter.java:35-39` applies the filter to POST/PUT/PATCH.
- `agent-platform/src/main/java/ascend/springai/platform/idempotency/IdempotencyStore.java:41-46` throws `IllegalStateException`.
- `docs/governance/architecture-status.yaml:259` explicitly says there is no `UnsupportedOperationException` path for `claimOrFind`.

Recommendation:

- Update `posture-model.md` to match POST/PUT/PATCH and `IllegalStateException`.
- Add posture-model coverage to the architecture truth gate, because posture semantics are platform-contract semantics, not explanatory prose.

### P1 - Dynamic planning is not yet a stable L0 contract

The architecture names a planner-as-tool pattern, but the activation contract does not exist in code:

- `docs/governance/architecture-status.yaml:520-526` says planner-as-tool is activated by `AgentLoopDefinition.planningEnabled(true)`.
- `docs/plans/engineering-plan-W0-W4.md:603-608` repeats the same activation path.
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/ExecutorDefinition.java:36-44` defines `AgentLoopDefinition` with `reasoner`, `maxIterations`, and `initialContext`, but no `planningEnabled` flag.

There is also a timing concern. If dynamic planning is part of the platform's agent identity, W4 may be too late to define the minimum contract. W2/W3 features such as typed payloads, tool invocation, memory recall, and cost accounting will need to know whether a plan is:

- internal execution state,
- a persisted memory artifact,
- a user-visible run artifact,
- or a tool-call substrate.

Recommendation:

- Decide one of two L0 paths:
  - Make planning explicitly non-L0 and post-W4, removing `planningEnabled(true)` from active status and plans.
  - Or define a minimal `PlanState` / `RunPlanRef` contract now, without implementing the full RunPlanSheet toolset.
- If planning remains in the active W0-W4 architecture, add the missing status row and a migration-safe field strategy for `AgentLoopDefinition`.

### P1 - Memory and knowledge need a minimal taxonomy before W3 implementation

The current shipped memory SPI is intentionally small:

- `agent-runtime/src/main/java/ascend/springai/runtime/memory/spi/GraphMemoryRepository.java:14-27` provides `addFact`, `query`, `search`, `GraphEdge`, and `GraphMetadata`.
- `GraphMetadata` carries `tenantId`, `sessionId`, `runId`, and `createdAt`.

That is acceptable for a W0 shell, but the active architecture and supporting docs imply more than the SPI defines:

- `docs/governance/architecture-status.yaml:518` names hybrid BM25 + pgvector memory service behavior.
- `docs/cross-cutting/oss-bill-of-materials.md:201-202` still claims mem0 via `LongTermMemoryRepository` and Graphiti via `GraphMemoryRepository`.
- `docs/cross-cutting/oss-bill-of-materials.md:216-219` lists deleted SPI package names for memory and knowledge.
- `docs/cross-cutting/oss-bill-of-materials.md:248-250` and `docs/cross-cutting/oss-bill-of-materials.md:301` still leave Graphiti vs Cognee partly unresolved, while the graphmemory starter README already shows Graphiti as the example path.

The missing L0 design piece is not implementation. It is taxonomy. Future agent behavior depends on differentiating:

- short-term run context,
- episodic/session memory,
- semantic long-term memory,
- graph relationship memory,
- document/knowledge index entries,
- retrieved context that may enter the LLM window.

Recommendation:

- Add a short L0 "memory and knowledge taxonomy" section.
- Define common metadata required across these stores: `tenantId`, `runId` or `sessionId`, source/provenance, ontology tag, confidence, retention/expiry, embedding model/version where applicable, redaction state, and visibility scope.
- Decide whether Graphiti is the selected W1 sidecar or mark Graphiti/Cognee selection as still open. Do not keep both "selected" and "not yet picked" statements active.
- Keep `GraphMemoryRepository` small at W0, but state explicitly which metadata will be added before W3 memory recall becomes a product contract.

## P2 Findings And Overdesign Risks

### P2 - Skill SPI resource enforcement overpromises what native Java can enforce

The Skill SPI direction is good, but the current wording is too strong:

- `ARCHITECTURE.md:337-347` says every external capability must register via `Skill`, declares `SkillResourceMatrix`, and says the Orchestrator enforces declared limits before `init()`.
- `docs/adr/0030-skill-spi-lifecycle-resource-matrix.md:90-97` defines token, wall-clock, CPU, memory, and concurrency dimensions.
- `docs/adr/0030-skill-spi-lifecycle-resource-matrix.md:196-200` allows VETTED skills to use `NoOpSandboxExecutor` in all postures.

The Orchestrator can validate presence of a declaration, quota keys, token budget, concurrency cap, and perhaps wall-clock timeout. It generally cannot enforce CPU millis or max heap for in-process VETTED Java code before `init()` without a sandbox or separate process boundary.

Recommendation:

- Split `SkillResourceMatrix` into:
  - L0/W2 hard-enforceable fields: quota keys, token budget declaration, concurrency cap, wall-clock timeout, trust tier, sandbox requirement for UNTRUSTED.
  - Sandbox-enforceable fields: CPU millis and max memory bytes.
  - Advisory/receipt fields: actual CPU/time/memory observed, when reliable.
- Change "the Orchestrator enforces declared limits before init()" to "the Orchestrator validates declared limits before init and enforces the subset supported by the dispatch path."

### P2 - Payload evolution stacks multiple breaking changes without a crisp migration plan

The current W0 code uses raw objects:

- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/ExecutorDefinition.java:50-63` uses `Object` in `NodeFunction`, `Reasoner`, and `ReasoningResult`.
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/ExecutorDefinition.java:36-44` uses `Map<String, Object>` for `initialContext`.

The architecture stacks two deferred W2 changes:

- ADR-0022 changes `NodeFunction` to typed payload (`docs/adr/0022-payload-codec-spi.md:95-99`).
- ADR-0028 changes `ReasoningResult` and `AgentLoopDefinition.initialContext` to payload/envelope forms (`docs/adr/0028-causal-payload-envelope-and-semantic-ontology.md:106-112`).

This is directionally right, but it risks breaking all executor and agent-loop code at W2 unless the adapter strategy is made normative.

Recommendation:

- Define a single W2 migration story: raw `Object` -> `Payload` -> `CausalPayloadEnvelope`.
- Add a compatibility adapter requirement for W0 `NodeFunction` and `Reasoner` implementations.
- Avoid duplicating the typed-payload constraint in the root architecture (`ARCHITECTURE.md:288-294` and `ARCHITECTURE.md:313-324`) unless the duplicate numbering is strictly necessary for backwards references.

### P2 - Three-track streaming is reasonable, but the ADR has a terminal-event contradiction and missing status row

The three-track idea is not inherently overdesigned for W2: control, data, and heartbeat channels are a clean answer to cancel starvation and liveness ambiguity. But the active text has two contract issues:

- `docs/adr/0031-three-track-channel-isolation.md:88` says "DROP_OLDEST with counter metric; DROP_LATEST for Terminal events (never dropped)", which is contradictory.
- `ARCHITECTURE.md:358` and `docs/adr/0031-three-track-channel-isolation.md:199` reference `run_dispatcher_spi`, but `docs/governance/architecture-status.yaml` has no `run_dispatcher_spi` row.

Recommendation:

- Reword terminal behavior as "Terminal events bypass the normal drop policy or use a reserved terminal slot; terminal events are never dropped."
- Add a `run_dispatcher_spi` status row or remove the row reference from root and ADR text.

### P2 - Status ledger and module doc still contain stale W0 claims

Examples:

- `docs/governance/architecture-status.yaml:45-55` says `agent_runtime_kernel` has no kernel logic and W2 delivers run lifecycle, even though W0 now has Run, RunRepository, RunStateMachine, orchestration SPI, in-memory executors, and tests.
- `docs/governance/architecture-status.yaml:297-314` says orchestration has no reference executor yet, while `docs/governance/architecture-status.yaml:316-327` immediately lists the in-memory orchestrator and reference executors.
- `agent-runtime/ARCHITECTURE.md:35-37` says `probe.check()` returns a non-null string, while `OssApiProbe.probe()` is the actual method (`agent-runtime/src/main/java/ascend/springai/runtime/probe/OssApiProbe.java:41`).

Recommendation:

- Run a status-ledger cleanup pass after every architecture pass, not only after code changes.
- Add a text-truth check for method names named by active module architecture docs.

## Overdesign Assessment

Not overdesigned for L0:

- Dual-mode graph and agent-loop SPI: justified by the stated agent runtime domain.
- RunStatus DFA and transition validation: essential contract, already W0-testable.
- In-memory W0 reference orchestrator: good proof without forcing Postgres or Temporal early.
- Cognition-action separation: useful boundary, especially with Spring AI, MCP, and optional sandboxed code paths.
- Explicit no-mandatory-Python sidecar rule: reduces operational complexity and contract ambiguity.

Potential overdesign unless narrowed:

- Listing many deleted starters and SPI names as active platform contracts.
- CPU and heap enforcement in `SkillResourceMatrix` for in-process VETTED Java skills.
- Full RunPlanSheet planner toolset before a minimal PlanState / PlanRef contract is defined.
- Three physical streaming channels if treated as mandatory W0 behavior rather than W2 design.
- mem0, Graphiti, Cognee, Docling sidecar references in active docs without a current module/status contract.

## Recommended L0 Release Gate

Before issuing a clean L0 release note, complete or explicitly defer these items:

1. Refresh or archive `docs/contracts/contract-catalog.md`.
2. Refresh or archive `docs/plans/roadmap-W0-W4.md` and the stale sections of `docs/plans/engineering-plan-W0-W4.md`.
3. Fix `docs/cross-cutting/posture-model.md` to match POST/PUT/PATCH and `IllegalStateException`.
4. Decide the planner contract: remove `planningEnabled(true)` from active docs or add a minimal `PlanState` / `RunPlanRef` design.
5. Add a memory/knowledge taxonomy section and reconcile Graphiti/Cognee/mem0 claims.
6. Split Skill SPI resource limits into validated, enforceable, sandbox-enforceable, and advisory classes.
7. Add the missing `run_dispatcher_spi` status row or remove the reference.
8. Clean stale status-ledger claims around `agent_runtime_kernel`, `orchestration_spi`, and method names in `agent-runtime/ARCHITECTURE.md`.
9. Extend the architecture truth gate to catch active-doc references to missing starters, missing SPI names, and stale method names.

## Suggested release note after the above fixes

The release note should be issued only after the release gate is closed. A clean note could say:

> L0 architecture baseline is accepted for spring-ai-ascend. The platform boundary, Java/Spring AI default runtime, module dependency direction, tenant propagation rule, posture-aware idempotency rule, run lifecycle DFA, W0 in-memory orchestration reference path, and deferred W1-W4 contract spine are aligned across active architecture documents, ADRs, status ledger, and current code. Remaining planning, skill, memory, knowledge, streaming, and persistence work is explicitly staged as design-only or future implementation and no active document claims deleted starters or missing SPIs as shipped contracts.

