# agent-runtime -- L1 architecture (2026-05-12 fourth-review refresh)

> Owner: runtime | Wave: W0..W4 | Maturity: W0
> Last updated: 2026-05-12

## 1. System boundary

`agent-runtime` is the **cognitive runtime kernel**. It receives an authenticated,
tenant-bound `RunRequest` from `agent-platform`, drives one or more LLMs through a
tool-calling loop, persists run state, and emits durable events via the outbox. It
trusts that `agent-platform` has already authenticated and bound the tenant.

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

## 4. Active submodules

| Package | Purpose | Wave |
|---|---|---|
| `orchestration/spi/` | Orchestrator, RunContext, GraphExecutor, AgentLoopExecutor, SuspendSignal, Checkpointer SPIs | W0 |
| `orchestration/inmemory/` | SyncOrchestrator, SequentialGraphExecutor, IterativeAgentLoopExecutor, InMemoryCheckpointer, InMemoryRunRegistry — dev-posture reference impls | W0 |
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
| `RunTest` | Unit | Run record construction, withStatus(), withSuspension() |
| `InMemoryCheckpointerTest` | Unit | save/load/clear round-trip |
| `OrchestrationSpiArchTest` | ArchUnit | SPI packages import only java.* |
| `TenantPropagationPurityTest` | ArchUnit | Rule 21: runtime never imports TenantContextHolder |
| `NestedDualModeIT` | Integration | 3-level graph→agent-loop→graph nesting via SuspendSignal |
| `RunStatusTransitionIT` | Integration | SUSPENDED→RUNNING→SUCCEEDED state transitions |
| `SuspendSignalTest` | Unit | SuspendSignal construction + childRunId accessor |

W2-deferred tests (placeholder):
- `RunHappyPathIT`, `RunCancellationIT`, `ActionGuardE2EIT`, `OutboxAtLeastOnceIT`, `LongRunResumeIT`
