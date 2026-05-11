# agent-runtime -- L1 architecture

> Owner: runtime | Wave: W2..W4 | Maturity: L0
> Last updated: 2026-05-12

## 1. System boundary

`agent-runtime` is the **cognitive runtime kernel**. It receives an authenticated,
tenant-bound `RunRequest` from `agent-platform`, drives one or more LLMs through a
tool-calling loop, persists run state, and emits durable events via the outbox. It
trusts that `agent-platform` has already authenticated and bound the tenant.

## 2. OSS dependencies

| Dependency | Version | Role |
|---|---|---|
| Spring AI (+ Anthropic / OpenAI starters) | 1.0.7 GA | `ChatClient` abstraction + provider bindings |
| MCP Java SDK (`io.modelcontextprotocol.sdk:mcp`) | 2.0.0-M2 | Tool protocol (per-tenant MCP server registry) |
| Temporal Java SDK + Server | SDK 1.34.0; Server 1.24.x | Durable workflows for runs > 30 s (W4) |
| Apache Tika | 2.x | Document-parser reference tool (W3) |
| Resilience4j | 2.x | Circuit breaker on LLM + tool calls |
| Caffeine | 3.x | In-process cancel-flag cache |
| Spring Boot actuator | (BOM) | Lifecycle + metrics |

## 3. W0 smoke test -- OssApiProbe

`OssApiProbe` is the W0 shipped integration test. It instantiates
real Spring AI `ChatClient` beans against WireMock provider stubs,
calls one tool via MCP SDK, and asserts a non-null response. This
confirms OSS dependency wiring is correct before any business logic
lands. Green OssApiProbe is a required gate for every wave.

## 4. Active submodules

| Path | Purpose | Wave |
|---|---|---|
| `run/` | RunController, RunOrchestrator (sync), Run repository | W2 |
| `llm/` | LlmRouter, ChatClient beans, CostMetering | W2 |
| `outbox/` | Postgres-backed outbox + OutboxPublisher | W2 |
| `observability/` | Custom metrics, span propagation | W2 |
| `tool/` | MCP server registry, per-tenant tool allowlist | W3 |
| `action/` | ActionGuard 5-stage filter chain | W3 |
| `memory/` | MemoryService (Caffeine L0, Postgres L1, pgvector L2) | W2..W3 |
| `temporal/` | Temporal workflow + activity classes (long-running) | W4 |

Pre-refresh sub-architecture files for `action-guard`, `adapters`, `audit`, `auth`,
`capability`, `evolve`, `knowledge`, `llm`, `memory`, `observability`, `outbox`,
`posture`, `run`, `runner`, `runtime`, `server`, `skill`, `temporal`, and `tool`
have been archived under `docs/v6-rationale/`.

## 5. Roadmap

- Deferred capabilities and design decisions: `CLAUDE-deferred.md`
- Current delivery state per wave (W0..W4): `docs/STATE.md`
- Wave engineering plan: `docs/plans/engineering-plan-W0-W4.md`

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

| Test | Layer | Asserts |
|---|---|---|
| `OssApiProbeIT` | Integration | OSS wiring + real WireMock LLM call |
| `RunHappyPathIT` | E2E | POST /v1/runs -> terminal in < 30 s (fake provider) |
| `RunCancellationIT` | E2E | Cancel live run -> 200 + terminal CANCELLED <= 5 s |
| `ActionGuardE2EIT` | E2E | Unauthorized tool call -> 403 + audit row |
| `OutboxAtLeastOnceIT` | Integration | Crash publisher mid-batch; no event lost |
| `LongRunResumeIT` | E2E (W4) | Kill workers mid-flight; run completes |
