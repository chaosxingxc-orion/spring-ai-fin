# agent-runtime/llm -- L2 architecture (2026-05-08 refresh)

> Owner: runtime | Wave: W2 | Maturity: L0 | Reads: tenant_budget, prompt_version | Writes: cost metric, run.cost_usd
> Last refreshed: 2026-05-08

## 1. Purpose

LLM gateway. Owns provider clients, model routing, prompt-cache key
construction, cost telemetry, and circuit breakers on provider calls.
Used by `run/` orchestrator and `temporal/` activities.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Spring AI | 1.0.7 (GA; U1) | `ChatClient` abstraction |
| Spring AI Anthropic | 1.0.7 (GA; U1) | Anthropic provider |
| Spring AI OpenAI | 1.0.7 (GA; U1) | OpenAI provider |
| Spring AI Bedrock | 1.0.7 (GA; U1) | AWS Bedrock provider (W3) |
| Resilience4j | 2.x | circuit breaker per provider |
| WireMock | 3.x | provider fake in CI |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `llm/LlmRouter.java` | provider + model selection | 120 |
| `llm/ChatClientFactory.java` | per-provider beans | 100 |
| `llm/CostMetering.java` | token-cost mapping | 100 |
| `llm/PromptCacheKey.java` | cache-key derivation | 60 |
| `llm/PromptVersionResolver.java` | A/B + rollout | 80 |
| `llm/FakeChatClient.java` (test) | deterministic CI provider | 100 |

## 4. Public contract

`LlmRouter.complete(LlmRequest)` returns `LlmResponse(text, model,
usage)`. Routing rules read from `tenant_config.llm_routing` (YAML);
default escalation: cheap -> medium -> premium based on tool-call count
or output length thresholds.

Cost: `agent_run_cost_usd_total{tenant,model}` Prometheus counter
incremented per call.

Prompt cache: derived key includes `(model, system_prompt_hash,
prompt_section_taint, user_text_prefix_hash)`. Tenant-scoped keys are
not shared across tenants.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Fake provider allowed | yes | no (except CI) | no |
| Provider key in env vs Vault | env | Vault | Vault |
| Cost metric required | optional | required | required |
| Circuit breaker on | optional | required | required |
| Prompt-cache enabled | optional | recommended | recommended |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `LlmRouterUnitTest` | Unit | rules pick expected provider |
| `LlmHappyPathIT` | Integration (fake) | call -> LlmResponse |
| `LlmRealProviderNightlyIT` | E2E (nightly) | call against real provider |
| `LlmCircuitBreakerIT` | Integration | 5xx storm -> circuit opens; recovery after half-open |
| `LlmCostMeterIT` | Integration | counter labels correct |
| `LlmPromptCacheHitIT` | Integration | repeated identical request -> cache hit metric |
| `LlmPromptVersionABIT` | Integration | A/B rollout assigns deterministically by tenant |

## 7. Out of scope

- Tool-calling protocol (`tool/`).
- Run lifecycle (`run/`).
- Temporal activity (`temporal/`).

## 8. Wave landing

W2: Router + 2 providers + fake + cost metric. W3: Bedrock provider +
prompt versioning + budget guard integration. W4: prompt cache
introspection + provider-fan-out experiments.

## 9. Risks

- Spring AI API churn in 1.x: pinned via BOM; integration test against
  pinned version + nightly real-provider catch.
- Provider TOS for stored prompts: per-provider data-handling matrix;
  tenant-level provider lock.
- Cost mismatch with real billing: per-model token-cost map version
  pinned; alert when provider invoice / metric variance > 5%.
