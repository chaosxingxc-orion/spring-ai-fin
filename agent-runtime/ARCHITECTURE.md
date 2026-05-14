---
level: L1
view: scenarios
module: agent-runtime
status: active
freeze_id: null
covers_views: [logical, development, process, physical]
spans_levels: [L1]
authority: "ADR-0068 (Layered 4+1 + Architecture Graph) + ADR-0059 (Code-as-Contract)"
---

# agent-runtime -- L1 architecture (2026-05-13 L0 final entrypoint truth review refresh)

> Owner: runtime | Wave: W0..W4 | Maturity: W0
> Last updated: 2026-05-13 (L0 final entrypoint truth review — §1 boundary prose split into target vs W0 shipped; previously refreshed at post-seventh third-pass)

## 0.4 Layered 4+1 view map (W1 — ADR-0068)

This document is the **L1 root** for the `agent-runtime` module. Until full 4+1 view reorganisation lands, the table below classifies each existing major section:

| Section | View | Notes |
|---|---|---|
| §1 System boundary | scenarios | runtime mission + target-vs-W0 split |
| §2 OSS dependencies | development | dependency direction + BoM authority |
| §3 SPI surface | logical | `Orchestrator` / `GraphExecutor` / `AgentLoopExecutor` / `SuspendSignal` / `Checkpointer` |
| §4 Wave-staged packages | scenarios | placeholders + wave qualifiers |
| Run state machine | process | DFA validator + `RunStateMachine` |
| Telemetry vertical hooks | process | `TraceContext` SPI + carrier semantics |

## 1. System boundary

`agent-runtime` is the **cognitive runtime kernel**. The boundary below separates the
**target architecture** (the W1–W4 contract) from the **W0 shipped subset** (what runs today).
Both views trust that `agent-platform` has already authenticated and bound the tenant.

**Target architecture (W1–W4).** The runtime receives an authenticated, tenant-bound
`RunRequest` from `agent-platform`, drives one or more LLMs through a tool-calling loop,
persists run state to a durable backend, and emits durable side effects via the outbox.
ActionGuard, the MCP tool registry, Temporal workflows, and the per-tenant capability
registry layer onto this contract.

**W0 shipped subset.** At the current release, `agent-runtime` ships: orchestration SPI
contracts (`Orchestrator`, `GraphExecutor`, `AgentLoopExecutor`, `SuspendSignal`,
`Checkpointer`, `ExecutorDefinition`, `RunContext`); the `Run` entity, `RunStatus` formal
DFA, and `RunStateMachine` validator; posture-gated in-memory reference executors
(`SyncOrchestrator`, `SequentialGraphExecutor`, `IterativeAgentLoopExecutor`,
`InMemoryCheckpointer`, `InMemoryRunRegistry`) — these fail-closed in research/prod via
`AppPostureGate`; the `ResilienceContract` operation-routing SPI; the `GraphMemoryRepository`
SPI scaffold (no adapter); the `OssApiProbe` classpath shape probe; and the
`IdempotencyRecord` contract-spine entity. The LLM gateway (`llm/`), outbox publisher
(`outbox/`), tool registry (`tool/`), ActionGuard (`action/`), and Temporal workflow
package (`temporal/`) are listed in `§4` as wave-staged placeholders — no Java
implementation ships at W0.

## 2. OSS dependencies

Dependency versions are managed by the parent POM (`pom.xml`) and the
`spring-ai-ascend-dependencies` BoM. Consult `pom.xml` properties for canonical
values (keys: `spring-ai.version`, `temporal.version`, `mcp.version`,
`resilience4j.version`, `caffeine.version`, `testcontainers.version`).

| Dependency | Role |
|---|---|
| Spring AI (see parent POM) | `ChatClient` abstraction + provider bindings |
| MCP Java SDK | Tool protocol (per-tenant MCP server registry, W3) |
| Temporal Java SDK | Durable workflows for runs > 30 s (W4) |
| Apache Tika | Document-parser reference tool (W3) |
| Resilience4j | Circuit breaker on LLM + tool calls |
| Caffeine | In-process cancel-flag cache |
| Spring Boot actuator | Lifecycle + metrics |

## 3. W0 smoke test -- OssApiProbe

`OssApiProbe` is the W0 shape probe. It is a plain class (not a Spring
context test). `OssApiProbeTest` runs 3 tests:

1. `classIsLoadable` — `OssApiProbe.class` loads without `NoClassDefFoundError`.
2. `probeReturnsNonNullString` — `probe.probe()` returns a non-null String.
3. `temporalGetVersionShapeReturnsMinusOne` — Temporal client stub returns -1
   (confirms SDK is on classpath without a live server).

Green OssApiProbeTest is a required gate for every wave.

## 4. Submodules (current + planned)

| Package | Purpose | Wave |
|---|---|---|
| `orchestration/spi/` | Orchestrator, RunContext, GraphExecutor, AgentLoopExecutor, SuspendSignal, Checkpointer, TraceContext SPIs | W0 (TraceContext L1.x — ADR-0061) |
| `orchestration/inmemory/` | SyncOrchestrator, SequentialGraphExecutor, IterativeAgentLoopExecutor, InMemoryCheckpointer, InMemoryRunRegistry — dev-posture reference impls | W0 |
| `orchestration/` | NoopTraceContext — L1.x default TraceContext impl (Telemetry Vertical, ADR-0061) | L1.x |
| `runs/` | Run entity, RunStatus DFA, RunMode, RunStateMachine, RunRepository SPI | W0 |
| `resilience/` | ResilienceContract SPI, ResiliencePolicy, YamlResilienceContract | W0 |
| `memory/spi/` | GraphMemoryRepository SPI (interface only) | W0 shell |
| `probe/` | OssApiProbe (Spring AI + Temporal classpath shape probe) | W0 |
| `idempotency/` | IdempotencyRecord (contract-spine entity) | W0 |
| `llm/` | LlmRouter, ChatClient beans, CostMetering | W2 |
| `outbox/` | Postgres-backed outbox + OutboxPublisher | W2 |
| `observability/` | Custom metrics, span propagation | W2 |
| `tool/` | MCP server registry, per-tenant tool allowlist | W3 |
| `action/` | ActionGuard 5-stage filter chain | W3 |
| `temporal/` | Temporal workflow + activity classes (long-running) | W4 |

## 5. Roadmap

- Deferred capabilities and design decisions: `docs/CLAUDE-deferred.md`
- Current delivery state per wave (W0..W4): `docs/STATE.md`
- Wave engineering plan: `ARCHITECTURE.md §1 + docs/governance/architecture-status.yaml + docs/CLAUDE-deferred.md` (per ADR-0037; engineering-plan-W0-W4.md archived)

## 6. Key posture defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| LLM provider mock allowed | yes | no | no |
| Vault required for provider keys | no | yes | yes |
| Token budget enforced | off | on | on |
| OPA policy required | warn-only | enforced | enforced |
| Temporal for runs > 30 s | warn | enforced | enforced |
| Outbox sink (not log appender) | optional | required | required |

## 7. Core tests

W0 shipped tests:

| Test | Layer | Asserts |
|---|---|---|
| `OssApiProbeTest` | Unit | OSS classpath shape (3 tests; no Spring context) |
| `RunStateMachineTest` | Unit | Legal + illegal DFA transitions; EXPIRED terminal |
| `TelemetryVerticalArchTest` | ArchUnit | §4 #53 — adapter classes must not write `TraceContext` outside hook/observability packages |
| `RunContextIdentityAccessorsTest` | ArchUnit | §4 #54 — `RunContext` exposes `traceId()` / `spanId()` / `sessionId()` / `traceContext()` returning declared types |
| `RunTraceSessionConsistencyIT` | Integration | §4 #54 — `Run.traceId` non-null hex when populated; nullable column tolerated at L1.x; child Run inherits sessionId via Checkpointer |
| `LlmGatewayHookChainOnlyTest` | ArchUnit | §4 #56 — no `agent-runtime/llm/*` class imports `ChatModel` outside `HookChain` package (vacuous at L1.x; arms for W2) |
| `SpanTenantAttributeRequiredTest` | ArchUnit | §4 #57 — emission sites declare `tenant.id` attribute (vacuous at L1.x; arms for W2) |
| `McpReplaySurfaceArchTest` | ArchUnit | §4 #59 — no `@RestController` resides in `web/replay/`, `web/trace/`, or `web/session/` |
| `PostureBootPiiHookPresenceContractIT` | Integration | §4 #58 — boot-gate contract for `PiiRedactionHook` in research/prod (full negative test W2) |
| `RunTest` | Unit | Run record construction, withStatus(), withSuspension() |
| `InMemoryCheckpointerTest` | Unit | save/load/clear round-trip |
| `OrchestrationSpiArchTest` | ArchUnit | SPI packages import only java.* |
| `TenantPropagationPurityTest` | ArchUnit | Rule 21: runtime never imports TenantContextHolder |
| `NestedDualModeIT` | Integration | 3-level graph→agent-loop→graph nesting via SuspendSignal |
| `RunStatusTransitionIT` | Integration | SUSPENDED→RUNNING→SUCCEEDED state transitions |
| `SuspendSignalTest` | Unit | SuspendSignal construction + childRunId accessor |

W2-deferred tests (placeholder):
- `RunHappyPathIT`, `RunCancellationIT`, `ActionGuardE2EIT`, `OutboxAtLeastOnceIT`, `LongRunResumeIT`
