# Competitive Architecture Analysis: SAA + AgentScope-Java vs spring-ai-ascend

**Date:** 2026-05-12
**Author:** Architecture Team (assisted by research agents)
**Status:** Committed — constraints, rules, ADRs, and wave-plan edits land in the same commit as this document.
**Predecessor:** `docs/reviews/2026-05-12-architecture-review-response.en.md` (response to reviewer whitepaper; shipped SHA `021095f`).

---

## 1. Context

The prior architecture review response added ARCHITECTURE.md §4 #10–#15 and CLAUDE-deferred Rules 15–17 in response to an external reviewer's whitepaper. That addressed the reviewer's surface critique and 13 hidden structural defects.

This document addresses a different question: **if a competing team built an agent platform by combining Spring AI Alibaba (SAA) with AgentScope-Java (AS-Java), what architectural capability would their combined platform deliver that our design — including the just-shipped §4 #10–#15 — still does not cover?**

Strategic constraints in force throughout this analysis:
- **No SAA Maven dependency**: `spring-ai-alibaba-*` and `com.alibaba.cloud.ai.*` are competitor artifacts; we study patterns and SPI shapes only.
- **No AS-Java Maven dependency**: same policy.
- **OSS-first**: any proposed enhancement must route through an existing OSS project before introducing glue code.
- **Occam pass**: every proposed constraint must answer "why is this not already covered by §4 #1–#15 or the W1–W4 wave plan?"

---

## 2. Research Summary

### 2.1 Spring AI Alibaba (SAA)

Source: `github.com/alibaba/spring-ai-alibaba` @ `main`, release `1.1.2.2` (Spring AI `1.1.2`, Spring Boot `3.5.8`, Java 17).

SAA is best understood as three layers:

**Layer A — Graph engine** (`spring-ai-alibaba-graph-core`): A full LangGraph-class state machine in Java. `StateGraph` (DAG builder) + `CompiledGraph` (runtime executor). Per-key `KeyStrategy` reducers (`ReplaceStrategy`, `AppendStrategy`, `MergeStrategy`) applied when a node returns a partial `OverAllState` update. Conditional routing via `addConditionalEdges(src, AsyncCommandAction, Map<String,String>)`. Subgraph support. **Eight checkpointer backends** (Memory, file, MySQL, PostgreSQL, Oracle, MongoDB, Redis, Versioned). HITL via `interruptBefore` / `interruptAfter` compile options + `InterruptionHook`. Streaming via `Flux<NodeOutput>`. Mermaid/PlantUML topology export at compile time.

**Layer B — Agent framework** (`spring-ai-alibaba-agent-framework`): Pattern library on top of the graph. `ReactAgent`, `SequentialAgent`, `ParallelAgent`, `LoopAgent`, `LlmRoutingAgent`. Full **hook system** at six positions: `BEFORE_MODEL`, `AFTER_MODEL`, `BEFORE_TOOL`, `AFTER_TOOL`, `BEFORE_AGENT`, `AFTER_AGENT`. Reference hooks include PII filter, summariser, token counter, tool-call-limit, and shell-tool sandboxing (`spring-ai-alibaba-sandbox`, experimental, GraalVM 24.2.1).

**Layer C — Ecosystem**: `spring-ai-alibaba-admin` — a bundled webapp with Evaluator (LLM-as-judge, versioned), Dataset (creatable from OTel trace captures), Experiment (batch + comparison + restart), Trace UI, and Prompt management. `spring-boot-starters/spring-ai-alibaba-starter-a2a-nacos` — A2A distributed agent discovery via Nacos 3.1.0 consuming the Google A2A Java SDK (`io.github.a2asdk`, Beta). Vertical apps in sibling repos: **Lynxe** (formerly JManus — multi-agent planner + UI), **DataAgent** (NL2SQL, exposes itself as an MCP server), **deepresearch** (hybrid RAG: vector + BM25).

**Key insight**: SAA has no `spring-ai-alibaba-jmanus` or `spring-ai-alibaba-nl2sql` reactor module in the main repo. Those are standalone Spring Boot applications. The framework / application boundary is clear.

### 2.2 AgentScope-Java (AS-Java)

Source: `github.com/agentscope-ai/agentscope-java` @ `main`, release `1.0.12`, RC `1.1.0-RC1`.

AS-Java is a framework-agnostic agent SDK built on Project Reactor (Mono/Flux), Jackson, and SLF4J — no Spring Boot compile dependency in core.

**Critical structural fact**: AS-Java's "Custom Workflow" (conditional agent routing, graph-of-nodes) **depends on SAA's `spring-ai-alibaba-graph-core`** via `AgentScopeAgent.asNode()`. So "SAA + AS-Java combined" is structurally **SAA with AS-Java as an extension layer** — the SAA dependency is not optional for conditional flows.

AS-Java's distinctive contributions (not derived from SAA):
- **`MsgHub`** — in-memory pub/sub (`io.agentscope.core.pipeline.MsgHub`): `enter`/`exit`/`broadcast`/`setAutoBroadcast`. Agents communicate via immutable `Msg` objects with typed content blocks (`TextBlock`, `ImageBlock`, `AudioBlock`, `ToolUseBlock`). No durable bus in core.
- **Flow-agents** — `SequentialAgent`, `ParallelAgent`, `LoopAgent` (each is itself an `Agent` subclass containing sub-agents). Pipeline topology is fixed; graph topology delegates to SAA.
- **`PlanNotebook`** — planner-as-tool pattern (`io.agentscope.core.plan`). The same `ReActAgent` becomes a planner by enabling planning tools: `create_plan`, `revise_current_plan`, `update_subtask_state`, `finish_subtask`, `view_subtasks`, `finish_plan`, `view_historical_plans`, `recover_historical_plan`. More programmable than Lynxe's planner-as-agent UI.
- **A2A + Nacos** — same A2A protocol as SAA; AS-Java's `agentscope-extensions-a2a-{client,server}` + `agentscope-extensions-nacos`. Distinctive: AS-Java treats distributed agent discovery as first-class even without a graph.
- **Studio** — separate Node.js service; custom HTTP/WebSocket protocol via `StudioMessageHook` (distinct from OTLP traces, which also fire).

AS-Java's **self-admitted weaknesses** vs spring-ai-ascend: no tenant isolation, no idempotency store, no posture-aware defaults, durable session only via filesystem JSON (`JsonSession`; Redis/MySQL session adapters flagged as v1-incompatible in their own docs), and an explicit warning that "the same agent instance cannot be called concurrently — use independent instances per request" (conflicts with our Rule 6 single-construction-path).

---

## 3. Comparative Matrix

Score legend: **0** = absent; **D** = designed, no impl; **S** = shipped (impl + ≥1 GREEN test); **S+** = shipped + matured (UI, multi-impl, eval corpus, etc.).

| Dimension | spring-ai-ascend | SAA | AS-Java | SAA+AS combined |
|---|---|---|---|---|
| **D1. Long-horizon lifecycle** | D (§4 #10: AgentSubject, typed SuspendReasons, paged RunRepository) | S+ (8 checkpointers, HITL compile-time + InterruptionHook, typed graph pause/resume) | S (JsonSession only; MySQL/Redis flagged v1-incompatible) | S+ |
| **D2. Multi-agent topology** | 0 (parent→child SuspendSignal nesting only; no peer discovery) | D (A2A+Nacos; Google A2A SDK Beta; no in-process bus) | S (MsgHub in-process pub/sub + A2A+Nacos extension) | S+ |
| **D3. Workflow expressiveness** | S– (programmatic Map edges; no reducers; no conditional predicate; no export) | S+ (StateGraph + KeyStrategy reducers + conditional edges + Mermaid export + subgraphs) | S (inherits SAA StateGraph for custom workflow) | S+ |
| **D4. Memory architecture** | D (Caffeine L0 + Postgres L1 + pgvector L2 planned W3; graphmemory-starter stub) | S (pluggable Store SPI; short-term via checkpointer; Hybrid RAG in DeepResearch app) | S (Mem0 long-term memory; 5 rag-* extensions for vector + RAG backends) | S+ |
| **D5. Trace replay / observability** | S– (Micrometer planned W2; no structured run timeline; no replay) | S+ (Studio embedded dev UI + SAA-Admin OTel ingest + dataset-from-trace creation) | S (AgentScope Studio Node.js; dual-stream: OTLP + custom WS protocol) | S+ |
| **D6. Tool ecosystem** | D (W3 ActionGuard 5-stage; MCP planned W3; no sandbox; no allowlist runtime) | S (MCP stock Spring AI; experimental GraalVM sandbox; Nacos-published MCP catalog; DataAgent as MCP server) | S (Toolkit + @Tool annotation + MCP client wrapper; runtime sandbox in separate repo) | S+ |
| **D7. Evaluation harness** | 0 (W4 wave plan names "eval harness" generically; no corpus, no judge, no threshold gate) | S+ (SAA-Admin: Evaluator + Dataset (from OTel traces) + Experiment; JPA-backed; version-controlled) | 0 (tracing only; no eval) | S+ |
| **D8. Enterprise hardening** | S+ (§4 #10–#15 + Rules 11/15/16/17: tenancy, RLS, idempotency, posture, audit, degradation, resume re-auth, cost) | S– (Nacos namespace = partial tenant boundary; no RLS, no idempotency, no posture model) | 0 (no tenant isolation, no idempotency, no posture, no audit) | S– |
| **D9. Runtime hooks** | 0 (ActionGuard is per-action auth, not per-LLM-boundary lifecycle) | S (hook chain at 6 positions: BEFORE/AFTER MODEL, TOOL, AGENT; reference hooks: PII, summariser, token counter, tool-call-limit) | S (io.agentscope.core.hook; StudioMessageHook) | S+ |
| **D10. Async / concurrency model** | S (Rule 5: one async resource per execution context; Rule 6: single construction path; Spring DI singletons) | S (Spring DI singletons; sync-first with reactive optional) | S– (per-request agent instantiation mandatory; same-instance concurrency explicitly prohibited) | mixed |

**Reading the matrix**: D8 and D10 are our structural advantages. D3, D5, D7, D9 are genuine gaps. D1, D2, D4, D6 are partially covered by our design or wave plan.

---

## 4. Gap Inventory

Each gap below passed the two-filter test: (a) SAA or AS-Java is at least `D` while we are `0`; (b) not covered by §4 #1–#15, CLAUDE-deferred Rules 7–17, the W1–W4 wave plan, or architecture-status.yaml `design_accepted` rows as of SHA `021095f`.

---

### G1 — Runtime Hook SPI *(D9; Tier A — binding §4 #16)*

**What SAA+AS deliver**: SAA ships a full hook chain at `BEFORE_MODEL` / `AFTER_MODEL` / `BEFORE_TOOL` / `AFTER_TOOL` / `BEFORE_AGENT` / `AFTER_AGENT` with reference hooks — PII filter (redacts sensitive patterns from prompts and completions), token counter (metric emission), summariser (context compression), tool-call-limit (throws when a per-run tool call cap is reached). AS-Java's `io.agentscope.core.hook` provides `StudioMessageHook` and further hook positions.

**Our gap**: W3 `ActionGuard` is a 5-stage per-action authorization chain (Authenticate / Authorize / Bound / Execute / Witness). It addresses *who is allowed to make this call*, not *what cross-cutting concerns must fire on every LLM/tool boundary*. No `BEFORE_MODEL` token counting, no `AFTER_TOOL` PII redaction, no context summarisation hook exists in our W0–W4 plan.

**Resolution (committed)**: `ARCHITECTURE.md §4 #16` — Runtime Hook SPI. `HookChain` bean; hook positions `PRE_LLM_CALL` / `POST_LLM_CALL` / `PRE_TOOL_INVOKE` / `POST_TOOL_INVOKE` / `PRE_AGENT_TURN` / `POST_AGENT_TURN`; hooks are `@Bean`-ordered; reference hooks PII + token counter + summariser + tool-call-limit ship in W2. `HookChainConformanceTest` (ArchUnit) asserts no bypass (Rule 19). YAML row: `runtime_hook_spi`.

---

### G2 — Graph DSL Conformance *(D3; Tier A — binding §4 #17)*

**What SAA+AS deliver**: SAA's `StateGraph` supports per-key `KeyStrategy` reducers (`ReplaceStrategy`, `AppendStrategy`, `MergeStrategy`) — essential for accumulating `messages` lists across nodes. Conditional routing via `addConditionalEdges(src, AsyncCommandAction, Map<String,String>)` instead of flat always-on edges. Mermaid/PlantUML topology export at compile time. AS-Java inherits all of this via `AgentScopeAgent.asNode()`.

**Our gap**: `ExecutorDefinition.GraphDefinition(Map<String, NodeFunction> nodes, Map<String, String> edges, String startNode)` is programmatic and flat. Edges carry no predicate — all are unconditional. No per-key reducer. No export. This means our graphs cannot accumulate state across nodes (required for multi-turn message history), cannot take conditional branches without embedding if-logic inside a `NodeFunction`, and cannot be introspected visually.

**Resolution (committed)**: `ARCHITECTURE.md §4 #17` — Graph DSL Conformance. Extends `GraphDefinition` with `StateReducer` registry (`OverwriteReducer`/`AppendReducer`/`DeepMergeReducer`), typed `Edge` records with optional predicate, JSON/Mermaid export via `GraphSerializer`. Backward-compatible factory `GraphDefinition.simple(...)` retained. Implementation W3. YAML row: `graph_dsl_conformance`.

---

### G3 — Eval Harness Contract *(D7; Tier A — binding §4 #18)*

**What SAA+AS deliver**: SAA-Admin ships a complete eval loop: Evaluator (LLM-as-judge with versioned prompt templates), Dataset (versioned input/expected pairs; creatable from OTel traces), Experiment (batch + restart + comparison). JPA-backed (H2/MySQL/Postgres). This is a real product, not a debug screen.

**Our gap**: W4 names "eval harness" in the wave summary. The wave plan's `EvalRegressionIT` is a placeholder without a corpus contract, judge definition, or threshold gate. There is no specification of what "pass" means, which models are judges, or what regression threshold blocks a merge.

**Resolution (committed)**: `ARCHITECTURE.md §4 #18` — Eval Harness Contract. Corpus in `docs/eval/<capability>/corpus.jsonl`; judge definition in `docs/eval/<capability>/evaluator.yaml`; thresholds in `docs/eval/<capability>/thresholds.yaml`. `EvalThresholdGate` blocks merge on regression (Rule 18). Implementation W4. YAML row: `eval_harness_contract`.

---

### G4 — Dev-time Trace Replay Surface *(D5; Tier C — ADR-0017)*

**What SAA+AS deliver**: Both ship Studio-style trace replay — SAA via embedded Studio + SAA-Admin; AS-Java via a separate Node.js service over custom WebSocket. Replay uses the checkpointed per-node state + parent pointer chain.

**Our gap**: §1 excludes "admin UI." No structured run timeline or replay surface exists in any wave.

**Resolution (committed)**: ADR-0017 — preserves §1 Admin UI exclusion. Adds a read-only dev-time trace timeline exposed via MCP server tools (`get_run_trace`, `list_runs`) reading the `trace_store` Postgres table written by `GraphNodeTraceWriter`. No HTML/JS. Clients: Claude Desktop, CLI, custom scripts. Wave-plan W4. YAML row: `trace_replay_dev_surface`.

---

### G5 — Sandbox Executor SPI *(D6; Tier C — ADR-0018)*

**What SAA+AS deliver**: SAA's `spring-ai-alibaba-sandbox` provides an experimental GraalVM 24.2.1 polyglot sandbox. AS-Java externalizes sandboxing to `agentscope-runtime-java` (K8s pod + Alibaba FC backends).

**Our gap**: W3 ActionGuard Bound stage has no sandbox primitive. A tool plugin running in-JVM can access arbitrary platform internals. Operators deploying code-interpreter tools have no isolation mechanism.

**Resolution (committed)**: ADR-0018 — `SandboxExecutor` SPI at the Bound stage; `NoOpSandboxExecutor` default (in-JVM Java tools); `GraalPolyglotSandboxExecutor` scaffold (W3). Wave-plan W3. YAML row: `sandbox_executor_spi`.

---

### G6 — A2A Federation Strategic Placeholder *(D2; Tier C — ADR-0016, post-W4)*

**What SAA+AS deliver**: Both ship A2A+Nacos-based distributed agent discovery — SAA via `spring-ai-alibaba-starter-a2a-nacos`; AS-Java via `agentscope-extensions-a2a`. Both consume the Google A2A Java SDK (`io.github.a2asdk`, Beta). Agents register `AgentCard` capability descriptors to Nacos; remote agents are invoked across processes.

**Our gap**: We have no peer-agent discovery primitive. `SuspendSignal` nesting is in-process only.

**Resolution (committed)**: ADR-0016 — strategic post-W4 deferral. Contract surface named: `AgentCard`, `AgentRegistry` SPI, `RemoteAgentClient` SPI. Registry-binding pluggable (Nacos/Consul/K8s). No W1–W4 schedule (A2A SDK still Beta; W4 scope already at capacity). YAML row: `a2a_federation_strategic`.

---

### G7 — Multi-backend Checkpointer *(D1; Tier B — W2 wave-plan expansion)*

**What SAA delivers**: 8 `BaseCheckpointSaver` implementations (Memory, file, MySQL, PostgreSQL, Oracle, MongoDB, Redis, Versioned).

**Our gap**: `InMemoryCheckpointer` only at W0. W2 plan adds Postgres alone.

**Resolution (committed)**: W2 wave-plan expansion — alongside Postgres, ship `RedisCheckpointer` (hot-standby) + `FileCheckpointer` (ops/DR). All behind the existing `Checkpointer` SPI; no SPI change. YAML row: `multi_backend_checkpointer`.

---

### G8 — Hybrid RAG (vector + BM25 keyword) *(D4; Tier B — W3 wave-plan expansion)*

**What SAA delivers**: SAA's DeepResearch application implements vector + BM25 hybrid scoring (inside the app, not as a framework module).

**Our gap**: W3 plans `MemoryService` L2 with pgvector only. No keyword index, no hybrid scoring.

**Resolution (committed)**: W3 wave-plan expansion — alongside pgvector, maintain a BM25 index (`pg_bm25` or ElasticSearch fallback); hybrid score = `alpha * vectorScore + (1 - alpha) * bm25Score`; `alpha` tunable per tenant (default `0.7`). YAML row: `hybrid_rag_bm25`.

---

### G9 — Planner-as-Tool Pattern *(D1; Tier B — W4 wave-plan addition)*

**What SAA+AS deliver**: SAA's Lynxe (formerly JManus) ships plan-and-execute as a planner-as-agent app. AS-Java's `PlanNotebook` ships plan-and-execute as a toolset embedded in the same `ReActAgent` — tools: `create_plan`, `revise_current_plan`, `update_subtask_state`, `finish_subtask`, `view_subtasks`, `finish_plan`, `view_historical_plans`, `recover_historical_plan`.

**Our gap**: `IterativeAgentLoopExecutor` is a single-reasoner ReAct loop with no plan persistence, no subtask state, and no plan reuse across correlated runs.

**Resolution (committed)**: W4 wave-plan addition — `RunPlanSheet` toolset on `AgentLoopExecutor` (tools: `createRunPlan`, `reviseRunPlan`, `completeSubtask`, `listSubtasks`, `finalizeRunPlan`, `listArchivedRunPlans`, `restoreArchivedRunPlan`); plan rows in `run_memory` keyed by `run_id`; `parentRunId` chain enables plan-reuse across correlated runs; activated by `AgentLoopDefinition.planningEnabled(true)`. YAML row: `planner_as_tool_pattern`.

---

## 5. What We Deliberately Do Not Adopt

**Reactor-pure agent contracts** (AS-Java's stance: every method is `Mono<T>` / `Flux<T>`). AS-Java explicitly forbids virtual threads, `ThreadLocal`, and concurrent same-instance use. This conflicts with our Rule 5 (one async resource per execution context) and Rule 6 (single construction-path per resource, Spring DI singleton). Our Spring-DI-singleton stance with Flux at the northbound surface (§4 #11) is a deliberate platform choice that trades pure-reactive purity for Spring ecosystem compatibility and tenant-scoped injection simplicity.

**NL2SQL / structured-data Q&A** (SAA DataAgent). This is a vertical application shipped as a standalone MCP server, not a framework component. It is out of scope for this platform. Operators who need NL2SQL can deploy DataAgent as a sidecar MCP server alongside spring-ai-ascend.

**SAA-Admin full web application** (HTML/JS). §1 excludes Admin UI. ADR-0017 provides the dev-time trace replay surface via MCP server within that exclusion.

**Mem0 / Letta / Zep-style long-term memory backends** (AS-Java). These are pluggable implementations behind our planned `LongTermMemory` SPI (W3). They are not framework-binding; operators add them as `@Bean` overrides.

---

## 6. Sequencing Across Waves

| Gap | Resolution | Wave |
|---|---|---|
| G7. Multi-backend Checkpointer | W2 wave-plan expansion (Postgres + Redis + file) | W2 |
| G1. Runtime Hook SPI | §4 #16 + W2 wave-plan expansion (HookChain + ref hooks) | W2 |
| G2. Graph DSL Conformance | §4 #17 + W3 wave-plan expansion (StateReducer + typed Edge + Mermaid) | W3 |
| G8. Hybrid RAG | W3 wave-plan expansion (pgvector + BM25 + alpha blend) | W3 |
| G5. Sandbox Executor SPI | ADR-0018 + W3 wave-plan addition (SandboxExecutor SPI + NoOp default) | W3 |
| G3. Eval Harness Contract | §4 #18 + W4 wave-plan expansion (corpus + judge + gate) | W4 |
| G9. Planner-as-Tool | W4 wave-plan addition (RunPlanSheet toolset) | W4 |
| G4. Dev-time Trace Replay | ADR-0017 + W4 wave-plan addition (MCP server) | W4 |
| G6. A2A Federation | ADR-0016 (strategic post-W4 placeholder) | post-W4 |

---

## 7. Artifacts Committed Alongside This Document

| File | Action |
|---|---|
| `ARCHITECTURE.md` | Added §4 #16 (Runtime Hook SPI), #17 (Graph DSL Conformance), #18 (Eval Harness Contract) |
| `docs/CLAUDE-deferred.md` | Added Rule 18 (Eval Harness Gate) and Rule 19 (Runtime Hook Conformance) |
| `docs/governance/architecture-status.yaml` | Added 9 `design_accepted` rows under C7–C10 categories |
| `docs/adr/0016-a2a-federation-strategic-deferral.md` | New ADR — post-W4 strategic placeholder for A2A federation |
| `docs/adr/0017-dev-time-trace-replay.md` | New ADR — dev-time trace replay via MCP server, no Admin UI |
| `docs/adr/0018-sandbox-executor-spi.md` | New ADR — SandboxExecutor SPI for ActionGuard Bound stage |
| `docs/plans/engineering-plan-W0-W4.md` | W2/W3/W4 wave-plan insertions for G1 + G2 + G3 + G4 + G5 + G7 + G8 + G9 |
| `docs/STATE.md` | C7–C10 design_accepted subsection added |
| `README.md` | Status line and reading order refreshed |

---

## 8. Verification

- `gate/check_architecture_sync.ps1` / `.sh` exits 0: ARCHITECTURE.md + architecture-status.yaml + STATE.md are aligned.
- `./mvnw clean test`: 56 existing tests stay GREEN (this commit is doc-only; no Java code changed).
- Three new ADRs match MADR 4.0 format of ADR-0015.
- No §4 constraint added duplicates existing #1–#15 semantics (verified by cross-check in gap-detection methodology §3 of this analysis).

---

## 9. References

**Spring AI Alibaba (SAA)**:
- Main repo: `github.com/alibaba/spring-ai-alibaba` @ `main`, release `1.1.2.2`
- `StateGraph.java`: `spring-ai-alibaba-graph-core/src/main/java/com/alibaba/cloud/ai/graph/StateGraph.java`
- Checkpointer savers (8): `spring-ai-alibaba-graph-core/.../checkpoint/savers/`
- Hook system: `spring-ai-alibaba-agent-framework/.../hook/`
- A2A Nacos starter: `spring-boot-starters/spring-ai-alibaba-starter-a2a-nacos/`
- Graph observation: `spring-ai-alibaba-graph-core/.../observation/`
- Lynxe (formerly JManus): `github.com/spring-ai-alibaba/Lynxe`
- DataAgent (NL2SQL): `github.com/spring-ai-alibaba/DataAgent`
- SAA-Admin: `github.com/spring-ai-alibaba/spring-ai-alibaba-admin`

**AgentScope-Java (AS-Java)**:
- Main repo: `github.com/agentscope-ai/agentscope-java` @ `main`, release `1.0.12`
- Key concepts: `java.agentscope.io/en/quickstart/key-concepts.html`
- MsgHub: `java.agentscope.io/en/task/msghub.html`
- PlanNotebook: `java.agentscope.io/en/task/plan.html`
- Observability + Studio: `java.agentscope.io/en/task/observability.html`
- Custom Workflow (SAA StateGraph dep): `java.agentscope.io/en/multi-agent/workflow.html`
- Runtime sandbox repo: `github.com/agentscope-ai/agentscope-runtime-java`
