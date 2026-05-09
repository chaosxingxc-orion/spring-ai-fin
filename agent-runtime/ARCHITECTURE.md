# agent-runtime -- L1 architecture (2026-05-08 refresh)

> Owner: runtime | Wave: W2..W4 | Maturity: L0 | Reads: tenant_workspace,
> prompt_version, tool_registry | Writes: run, run_memory, session_memory,
> long_term_memory, outbox_event, audit_log
> Last refreshed: 2026-05-08

## 1. Purpose

`agent-runtime` is the **cognitive runtime kernel**. Given an
authenticated tenant-bound request from `agent-platform`, it drives one
or more LLMs through a tool-calling loop, persists run state, captures
audit evidence, and emits durable events via the outbox. Long-running
runs are delegated to a Temporal workflow so the JVM can crash without
losing work.

**It is not** a request-acceptance layer. The runtime trusts that
`agent-platform` has already authenticated, applied idempotency, and
bound the tenant.

## 2. OSS dependencies

| Dependency | Version | Role |
|---|---|---|
| Spring AI | 1.0.x | `ChatClient` per LLM provider |
| Spring AI Anthropic / OpenAI | 1.0.x | Provider-specific bindings |
| Spring AI VectorStore PgVector | 1.0.x | Vector store wrapper |
| MCP Java SDK | latest | Tool protocol |
| Temporal Java SDK + Cluster | server 1.24.x; SDK 1.25.x | Durable workflows |
| pgvector | 0.7.x | Vector index in Postgres |
| OPA | 0.65.x | Authorization policy (sidecar) |
| Resilience4j | 2.x | Circuit breaker on LLM + tool calls |
| Caffeine | 3.x | L0 in-process cache |
| Valkey | 7.x | L0/L1 ephemeral state across replicas (W2+) |
| HashiCorp Vault | (compose) | Secrets (provider keys) |
| Apache Tika | 2.x | Document parsing (W3) |
| Spring Boot actuator | (BOM) | Lifecycle + metrics |

## 3. Submodules (L2)

| L2 path | Purpose | Wave |
|---|---|---|
| `run/` | RunController, RunOrchestrator (sync), Run repository | W2 |
| `llm/` | LlmRouter, ChatClient beans, CostMetering | W2 |
| `tool/` | MCP server registry, per-tenant tool allowlist | W3 |
| `action/` | ActionGuard 5-stage filter chain, ActionEnvelope | W3 |
| `memory/` | MemoryService (L0 Caffeine, L1 Postgres, L2 pgvector) | W2..W3 |
| `outbox/` | Postgres-backed outbox + OutboxPublisher | W2 |
| `temporal/` | Temporal workflow + activity classes (long-running) | W4 |
| `observability/` | Custom metrics, span propagation | W2 |

Each L2 has its own `ARCHITECTURE.md` following the skeleton in `docs/plans/architecture-systems-engineering-plan.md` sec-3.

## 4. Public contract

- Inbound (from `agent-platform`): a `RunRequest` record with
  `tenant_id`, `prompt`, `agent_definition_id`, `idempotency_key`. The
  platform layer guarantees these are present and valid.
- Outbound (to caller): `RunResponse` (`run_id`, `status`, optional
  `response_text`, optional `cost_usd`).
- DB schema: `run`, `run_memory`, `session_memory`, `long_term_memory`,
  `outbox_event`, `audit_log`, `tool_registry`, `prompt_version`,
  `tenant_budget`, `feedback`. Owned by Flyway migrations under
  `agent-runtime/.../db/migration/`.
- Events (outbox): `RunCompleted`, `RunFailed`, `RunCancelled`,
  `ToolCalled`, `BudgetExceeded`. Sink is configurable; default is a
  log appender.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| LLM provider mock allowed | yes | no | no |
| Postgres in-memory (H2) allowed | yes | no | no |
| Vault required for provider keys | no | yes | yes |
| Token budget enforced | off | on | on |
| OPA policy required | warn-only | enforced | enforced |
| Temporal required for runs > 30s estimated | warn | enforced | enforced |
| Outbox sink real (not log appender) | optional | required | required |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `RunHappyPathIT` | E2E | POST /v1/runs -> terminal in < 30s with fake provider |
| `RunCancellationIT` | E2E | Cancel a live run -> 200 + terminal `cancelled` <= 5s |
| `LlmProviderOutageIT` | Integration | 5xx from provider -> circuit breaker opens; retries via Temporal |
| `ActionGuardE2EIT` | E2E | Unauthorized tool call -> 403 + audit row |
| `MemoryRecallIT` | E2E | Write fact in run 1; retrieve in run 2 of same session |
| `BudgetCapIT` | Integration | Tenant budget exceeded -> 429 |
| `OutboxAtLeastOnceIT` | Integration | Crash publisher mid-batch; no event lost |
| `LongRunResumeIT` | E2E (W4) | Kill workers mid-flight; run completes |
| `EvalRegressionIT` | Nightly | Canonical prompt suite passes baseline |

## 7. Out of scope

- Authentication (handled by `agent-platform/auth/`).
- Tenant binding / RLS GUC (handled by `agent-platform/tenant/`).
- Multi-framework dispatch (LangChain4j / Python sidecar): deferred to
  W4+; the active design surface is Spring AI only.
- Knowledge graph (Apache Jena): deferred indefinitely.
- Run analytics dashboards: future module.

## 8. Wave landing

- W2: `run/`, `llm/`, `outbox/`, `memory/` L0/L1, `observability/`.
- W3: `action/`, `tool/`, `memory/` L2 (pgvector), feedback, prompt
  versioning, token budget.
- W4: `temporal/`, eval harness wiring, skill registry plug-in.

Reference: `docs/plans/engineering-plan-W0-W4.md` sec-4 (W2), sec-5
(W3), sec-6 (W4).

## 9. Risks

- **LLM provider drift**: pinned to provider-specific Spring AI starter
  versions; integration tests against fakes; nightly real-provider
  test for at least one provider.
- **pgvector embedding-model mismatch**: every embedding row stores
  provider+model; mismatch rejected at retrieval time.
- **Temporal operational complexity in prod**: single-node OK for v1
  customer; cluster mode optional; Temporal Cloud as managed upgrade.
- **ActionGuard latency from OPA**: local sidecar benchmarked p99 < 5ms;
  fail-closed on OPA outage.
- **Cost telemetry under-counting**: token counts come from provider
  responses; unit-tested mapping per model.
- **Prompt-injection via tool output**: tool outputs flow back into
  the LLM as `tool_result`; classified as untrusted in
  `PromptSection`; ActionGuard re-checks before any side effect; an
  E2E test injects a prompt-injection payload and asserts no
  unauthorized side effect.
- **Memory poisoning across sessions**: tenant-scoped memory only;
  RLS prevents cross-tenant; per-session retention TTL + clear API.
- **Run state leakage on crash**: Temporal owns durable state; the
  crashed JVM holds no run state beyond an in-flight reference; reaper
  job catches orphan rows.
- **Vendor lock-in on a specific LLM provider**: `LlmRouter`
  abstraction permits swap; per-tenant provider lock allows
  customer-specific lock-in to be opt-in, not platform-wide.
