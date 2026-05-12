# spring-ai-ascend Engineering Plan -- W0..W4

> Companion to `ARCHITECTURE.md`. This is the *only* document
> that schedules work and defines acceptance. Updated only when a wave
> ends or a wave's scope is renegotiated.
> **Last refreshed:** 2026-05-08
> **Cadence rule:** at most one wave open at a time. When a wave closes,
> the 32-dimension scoring framework score advances.

## 0. Plan-level rules

1. **No wave exceeds 3 weeks.** A wave that needs more is split.
2. **Every wave ends with a green CI run** on `main` covering its tests.
3. **Every wave moves at least one of the 32 scoring dimensions.** A
   wave that does not is dropped.
4. **Governance changes are not waves.** Gate / manifest / status-YAML
   changes ride on the wave that introduces real artifact change. If a
   wave has *zero* artifact deliverables, do not run it.
5. **Decline reviewer findings during a wave** unless the finding blocks
   that wave's acceptance test. Reviewer findings are batched and
   triaged at wave close. **Exception:** a finding in a Rule 9
   ship-blocking category (model path, run lifecycle, HTTP contract,
   security boundary, resource lifetime, observability) must be resolved
   within the wave and may not be deferred.
6. **Posture default is `dev` in all waves.** `research` and `prod`
   strict-mode tests are added per wave; full posture certification is
   W4 sec-acceptance.
7. **One Java version, one Spring Boot major.** Java 21 LTS, Spring Boot
   4.0.5. No fork, no preview features in production code.
8. **CI smoke is not Rule 8 (cycle-9 sec-D2).** Fake-provider sequential
   runs in CI are named `ci_operator_shape_smoke` and have
   `dependency_mode: fake` + `rule_8_eligible: false`. A run is named
   `rule_8_operator_shape` and may set `rule_8_eligible: true` only
   when `dependency_mode: real` AND a real Maven artifact is built AND
   a long-lived process is started. No delivery file may claim Rule 8
   PASS while `dependency_mode: fake`.

## 1. Wave summary

| Wave | Theme                                  | Duration  | Score lift target               |
|------|----------------------------------------|-----------|---------------------------------|
| W0   | Foundation skeleton                    | 1.5 weeks | R1, R6 -> 1; R2 >= 1500; R3 >= 1000 |
| W1   | Identity, tenancy, RLS                 | 2 weeks   | F2, F3, F6 -> 1                 |
| W2   | LLM gateway + run lifecycle (sync)     | 3 weeks   | R7, F1 (smoke), F7 -> 1; G1 finite |
| W3   | ActionGuard + tools + memory + cost    | 3 weeks   | F4, F5 -> 1; P2 + P3 deliverables |
| W4   | Long-running workflows + eval + HA     | 3 weeks   | R8 -> 1; F8 -> 1; HA test green |

**Total: ~12.5 calendar weeks if linear.** Two engineers in parallel
can compress to ~7 weeks.

After W4, the project's score on the 32-dimension framework should
read R 8/8, F 7/8 (with the remaining F dim covered by a separate
wave), G 4/6, C 3/5, E 1/5. Aggregate target: **23/32 by end-of-W4.**

## 2. W0 -- Foundation skeleton

### 2.1 Goal

Make the repo a runnable Spring Boot application with Postgres-backed
persistence, a `/health` endpoint, and one passing end-to-end test
against a real local Postgres. Replace the v6 documentation tower's
claim of "the platform" with an actual minimal artifact.

**Current state (cycle-14): W0 skeleton step 1 is committed (pom.xml + src tree +
HealthEndpointIT) but not yet compiled or tested by CI. W0 acceptance requires the
behavior gates in sec-2.7 to turn green.**

### 2.2 Scope (in)

- Maven multi-module: `spring-ai-ascend/` (parent), `agent-platform/`,
  `agent-runtime/`.
- Spring Boot 4.0.5, Java 21, virtual threads on.
- One Spring Boot main class in `agent-platform`.
- One controller `/v1/health` returning `{"status":"UP","sha":"..."}`.
- Postgres 16 in `ops/compose.yml`; Flyway with one migration creating
  a `health_check` table.
- One Spring Data JDBC repository hitting Postgres in the `/health`
  flow.
- Logback JSON encoder; Micrometer + Prometheus actuator endpoint.
- `Dockerfile` (Buildpacks-based) + `compose.yml`.
- GitHub Actions: build + test on PR.
- One Testcontainers integration test that spins Postgres and asserts
  `/v1/health` returns 200 with the SHA.
- Refresh banner on `ARCHITECTURE.md` (continuous v6 line, dated 2026-05-08).

### 2.3 Scope (out, deferred)

- Auth (W1).
- Multi-tenant logic (W1).
- LLM, tool calling, memory (W2+).
- Helm chart (W2).
- Vault, OPA (W2-W3).

### 2.4 OSS dependencies pinned

| Dep | Version |
|---|---|
| Java | 21.0.x LTS |
| Spring Boot | 4.0.5 |
| Postgres | 16.x |
| Flyway | 10.x |
| HikariCP | (transitive via Spring Boot) |
| Micrometer | (transitive) |
| Logback | (transitive) |
| Testcontainers | 1.20.x |
| Maven | 3.9.x |

### 2.5 Glue modules to build

| Path | Purpose | Approx LOC |
|---|---|---|
| `pom.xml` (root) | parent POM, dependency mgmt | 150 |
| `agent-platform/pom.xml` | platform module POM | 80 |
| `agent-runtime/pom.xml` | runtime module POM (empty src in W0) | 60 |
| `agent-platform/src/main/java/.../PlatformApplication.java` | main class | 30 |
| `.../web/HealthController.java` | controller | 40 |
| `.../persistence/HealthCheckRepository.java` | Spring Data JDBC | 40 |
| `agent-platform/src/main/resources/application.yml` | config | 60 |
| `agent-platform/src/main/resources/db/migration/V1__init.sql` | Flyway migration | 20 |
| `agent-platform/src/test/java/.../HealthEndpointIT.java` | integration test | 80 |
| `ops/compose.yml` | dev compose | 80 |
| `Dockerfile` (root) | container | 30 |
| `.github/workflows/ci.yml` | CI | 60 |

Total glue: ~730 LOC.

### 2.6 Tests

#### Step 1 done (cycle-13)

| Test name | Layer | Asserts |
|---|---|---|
| `HealthEndpointIT` | Integration (Testcontainers Postgres) | GET `/v1/health` -> 200 + body shape |

#### Remaining for W0 acceptance

| Test name | Layer | Status |
|---|---|---|
| `FlywayMigrationIT` | Integration | pending (or formally deferred to W1) |
| `BuildSmokeTest` | CI | pending (blocked on CI green) |

### 2.7 Acceptance gates (must all pass)

Behavior gates (cycle-14 D2: replaced R2/R3 LOC gates with these):

- **B1**: `mvn -B -ntp --strict-checksums verify` exits 0 in CI on Linux runner.
- **B2**: `HealthEndpointIT` passes with real Testcontainers Postgres in CI.
- **B3**: `FlywayMigrationIT` passes, OR is formally moved to W1 acceptance with a
  recorded architecture-status.yaml entry.
- **B4**: Posture guard tests (`PostureBootGuardResearchIT`, `PostureBootGuardProdIT`,
  `PostureBootGuardDevIT`) are deferred to W1 per cycle-14 C1 re-scope.
- **R6**: `docker compose up` brings the app online + Postgres + the health endpoint
  returns 200 within 60s of start.
- v6 supersession banner committed.

#### 2.7.1 W0 step-1 outcome (cycle-13 f98dbae)

Done:
- [x] Maven multi-module scaffold with BoM-pinned versions
- [x] W0 minimal Spring Boot skeleton with /v1/health
- [x] HealthEndpointIT Testcontainers test committed
- [x] Probe code per critical-path dep (cited APIs imported)
- [x] Dockerfile + compose + CI workflow (mvn verify blocking)
- [x] Operator-shape smoke gate tri-state

Pending for W0 acceptance:
- [ ] CI green on mvn verify (B1)
- [ ] CI green on HealthEndpointIT (B2)
- [ ] FlywayMigrationIT decision (B3)
- [ ] R6 docker compose smoke

### 2.8 Out-of-scope reviewer findings during W0

The architecture-sync gate WILL find new drift: pre-refresh L2 claims
diverge from the W0 reality. **Do not fix these as they appear.**
Batch all such findings into a single audit-trail commit at W0 close
that updates active-corpus.yaml + status YAML.

### 2.9 Risks + mitigations

| Risk | Mitigation |
|---|---|
| Java 21 + virtual threads + JDBC blocking pinning | Use HikariCP 5.x + connection pool sized appropriately; pin tests |
| Testcontainers slow on first pull | Pre-pull images in CI cache step |
| Flyway version drift in v8+ | Pin to 10.x in BOM |
| Buildpack vs Dockerfile drift | Document choice in W0; pick one, no fork |

### 2.10 Rollback

W0 is greenfield. Rollback = revert the W0 commit chain on the
refresh branch.

---

## 3. W1 -- Identity, tenancy, RLS

### 3.1 Goal

A request authenticated by a JWT carrying a tenant claim opens a
Postgres transaction with `app.tenant_id` GUC set; the transaction
sees only that tenant's rows even though it queries a shared table.
Two tenants writing to the same endpoint produce isolated rows; an
attempt to read across tenants returns nothing.

### 3.2 Scope (in)

- Keycloak in `compose.yml` with one realm + two test tenants
  (`tenant-a`, `tenant-b`), two test users.
- Spring Security 6 `SecurityFilterChain` with `oauth2ResourceServer`
  + JWKS URL pointing at Keycloak.
- `TenantBinder` filter: parses `tenant_id` from JWT claim, attaches
  to request scope, registers `TransactionSynchronization` that runs
  `SET LOCAL app.tenant_id = :id` on every transaction.
- A `tenant_workspace` table with RLS policy; a `BEFORE INSERT` trigger
  raises if `current_setting('app.tenant_id', true)` is empty.
- `IdempotencyFilter` + `idempotency_dedup` table.
- Resilience4j rate limiter on the controller chain.
- `/v1/workspace` POST: writes a row in `tenant_workspace`; returns the
  row's id.
- Auth-aware E2E: two tenants posting to the same endpoint produce
  isolated rows.

### 3.3 Scope (out, deferred)

- Synchronous run lifecycle (`agent-runtime/run/`): W2.
- LLM provider clients: W2.
- ActionGuard 5-stage chain: W3.
- Memory tiers, vector store: W2/W3.
- Temporal durable workflows: W4.
- Prod-grade rate limit + circuit breaker tuning: W2.
- Per-tenant config overrides via Spring Cloud Config: W2.

### 3.4 OSS dependencies pinned

| Dep | Version |
|---|---|
| Spring Security | 6.x (transitive) |
| Keycloak | 25.x (in compose only) |
| Resilience4j | 2.x |
| Spring Cloud Gateway | NOT yet (W2) |

### 3.5 Glue modules to build

| Path | Purpose | LOC |
|---|---|---|
| `agent-platform/.../auth/SecurityConfig.java` | filter chain | 80 |
| `.../auth/JwtTenantClaimExtractor.java` | claim parser | 40 |
| `.../tenant/TenantContext.java` | request-scoped holder | 30 |
| `.../tenant/TenantBinder.java` | filter | 60 |
| `.../tenant/RlsTransactionSynchronization.java` | sets GUC on tx | 50 |
| `.../tenant/RlsAssertionTrigger.sql` | DB trigger | 20 |
| `.../idempotency/IdempotencyFilter.java` | dedup filter | 70 |
| `.../idempotency/IdempotencyRepository.java` | repo | 50 |
| `.../web/WorkspaceController.java` | controller | 50 |
| `agent-platform/src/main/resources/db/migration/V2__tenant_rls.sql` | RLS schema | 80 |
| `agent-platform/src/test/.../TenantIsolationIT.java` | E2E | 120 |
| `agent-platform/src/test/.../IdempotencyDoubleSubmitIT.java` | E2E | 80 |
| `agent-platform/src/test/.../GucEmptyAtTxStartIT.java` | E2E | 80 |
| `ops/compose.yml` | add Keycloak | 30 |

Total: ~840 LOC additional.

### 3.6 Tests

| Test | Asserts |
|---|---|
| `TenantIsolationIT` | Tenant A's writes invisible to tenant B |
| `IdempotencyDoubleSubmitIT` | Same Idempotency-Key -> same row id, only one insert |
| `GucEmptyAtTxStartIT` | A direct query bypassing TenantBinder fails the trigger |
| `JwtAlgorithmRejectionIT` (research posture) | HS256 with weak key rejected when posture=research |
| `JwksRotationIT` | Old key rotated, new key still validates |

### 3.7 Acceptance gates

- F2 = 1: `TenantIsolationIT` green.
- F3 = 1: `GucEmptyAtTxStartIT` green.
- F6 = 1: JWT validation E2E green (RS256 path; HS256 carve-out tested in research posture).
- All previous W0 gates remain green.
- No new gate-finding-induced fixes during the wave.

### 3.8 Out-of-scope reviewer findings during the wave

The architecture-sync gate WILL find drift on tenancy / RLS prose
across the L2 corpus. **Do not fix as they appear.** Batch into a
single audit-trail commit at W1 close that bumps the
`tenant_spine_capability` row in `architecture-status.yaml` and
records the W1 maturity advance.

### 3.9 Risks + mitigations

| Risk | Mitigation |
|---|---|
| HikariCP sets GUC at connection acquire, not transaction | Use `TransactionSynchronization` in Spring; explicit `SET LOCAL` in tx; covered by `GucEmptyAtTxStartIT` |
| Keycloak realm-import sluggish | Bake realm JSON into image; pre-imported on container start |
| Idempotency table grows unbounded | TTL job W2; for W1 keep manual cleanup |

### 3.10 Rollback

Wave is additive. Rollback = revert W1 commit chain; W0 still works.

---

## 4. W2 -- LLM gateway + run lifecycle (synchronous)

### 4.1 Goal

A tenant POSTs a prompt to `/v1/runs`; the platform calls one of
several configured LLMs (Anthropic / OpenAI / a fake provider for CI)
through Spring AI's `ChatClient`, persists run state, returns the
final response; cancellation works on a live run; outbox writes one
event per terminal run.

This wave makes the project actually intelligent -- Rule 8 partial
PASS becomes real.

### 4.2 Scope (in)

- Spring AI 2.0.0-M5 with `ChatClient` beans for: Anthropic, OpenAI,
  in-memory fake (for CI).
- `LlmRouter`: chooses provider + model based on a tenant config row.
- `Run` table: `run_id, tenant_id, status, current_stage, started_at,
  finished_at, prompt, response, model, cost_usd`.
- `RunController`:
  - `POST /v1/runs` creates a run, returns `202 + run_id`.
  - `GET /v1/runs/{id}` returns status + response.
  - `POST /v1/runs/{id}/cancel` cancels.
- `RunOrchestrator`: synchronous (no Temporal yet); uses virtual
  threads for fan-out; handles cancellation via `CompletableFuture` +
  shutdown signal.
- Outbox: `outbox_event` table; `OutboxPublisher` polls and emits to a
  log sink (real bus in W4).
- Spring Cloud Gateway in front (basic routing).
- HikariCP load test (200 concurrent runs against fake LLM).
- Cost telemetry: per-run cost computed from token counts;
  `agent_run_cost_usd_total{tenant,model}` Prometheus counter.
- Helm chart skeleton (single-replica).
- **RuntimeHook SPI** (`runtime_hook_spi`, §4 #16): `RuntimeHook` interface + `HookChain` bean;
  hook positions `PRE_LLM_CALL` / `POST_LLM_CALL` / `PRE_TOOL_INVOKE` / `POST_TOOL_INVOKE`
  (W2 LLM+tool scope; `PRE_AGENT_TURN`/`POST_AGENT_TURN` added W3 with agent-loop gateway);
  `@Bean`-ordered chain wired into `ChatClient` and tool-adapter calls. Reference hooks: PII filter (redacts PII
  patterns from prompt/response), token counter (emits `springai_ascend_tokens_total` counter),
  summariser (optional context compression), tool-call-limit (throws if call count exceeds
  `ResiliencePolicy.maxToolCalls`). `HookChainConformanceTest` (ArchUnit) asserts no bypass.
- **Multi-backend Checkpointer** (`multi_backend_checkpointer`): Postgres-backed `CheckpointerImpl`
  (primary, W2) + Redis-backed `RedisCheckpointer` (hot-standby) + file-backed `FileCheckpointer`
  (ops scripts / DR). All implement the existing `Checkpointer` SPI.

### 4.3 Scope (out, deferred)

- ActionGuard 5-stage chain: W3.
- MCP tool registry: W3.
- Memory L2 (pgvector): W3.
- Temporal durable workflows + long-running runs: W4.
- Eval harness: W4.
- Helm production chart (only single-replica skeleton in W2): W4.
- Real LLM providers in CI on every PR (kept nightly only).

### 4.4 OSS dependencies pinned

| Dep | Version |
|---|---|
| Spring AI | 1.0.x |
| Spring AI Anthropic | 1.0.x |
| Spring AI OpenAI | 1.0.x |
| Spring Cloud Gateway | 4.x |
| HashiCorp Vault | (compose) |
| Spring Cloud Vault | 4.x |

### 4.5 Glue modules to build

| Path | Purpose | LOC |
|---|---|---|
| `agent-runtime/.../llm/LlmRouter.java` | routing | 100 |
| `.../llm/ChatClientFactory.java` | per-provider beans | 80 |
| `.../llm/CostMetering.java` | token-cost map | 80 |
| `.../run/Run.java` (record) | dto | 30 |
| `.../run/RunRepository.java` | jdbc | 80 |
| `.../run/RunController.java` | REST | 120 |
| `.../run/RunOrchestrator.java` | orchestration | 200 |
| `.../outbox/OutboxEvent.java` | record | 30 |
| `.../outbox/OutboxRepository.java` | jdbc | 50 |
| `.../outbox/OutboxPublisher.java` | scheduled poller | 100 |
| `agent-runtime/src/main/resources/db/migration/V3__runs_outbox.sql` | schema | 60 |
| `ops/helm/templates/deployment.yaml` | helm | 80 |
| `ops/grafana/dashboards/runs.json` | grafana dashboard | 100 |
| Test files | several | 600 |

Total: ~1700 LOC.

### 4.6 Tests

| Test | Asserts |
|---|---|
| `LlmRouterUnitTest` | Routing rules pick correct provider |
| `RunHappyPathIT` | POST -> success terminal in < 30s with fake LLM |
| `RunCancellationIT` | Cancel a live run -> 200 + terminal `cancelled` <= 5s |
| `RunUnknownCancelIT` | Cancel unknown id -> 404 |
| `OutboxAtLeastOnceIT` | Crash publisher mid-batch; assert no event lost |
| `ConcurrencyLoadIT` | 200 concurrent runs against fake LLM; p99 < 2s |
| `CostMetricIT` | Counter increments per run with correct labels |
| `LlmProviderOutageIT` | WireMock 5xx on real provider; circuit breaker opens |
| `IdempotencyOnRunsIT` | Same Idempotency-Key -> same `run_id` |

### 4.7 Acceptance gates

- R7 = 1: `RunHappyPathIT` green with at least one real provider call (nightly job; CI uses fake).
- `ci_operator_shape_smoke` lands (W2): sequential N=3 runs against fake provider; zero fallback events. **Records `dependency_mode: fake` and `rule_8_eligible: false`** -- not Rule 8 evidence (cycle-9 sec-D2). F1 only unlocks when W4 lands `rule_8_operator_shape` against real dependencies.
- F7 = 1: cancellation IT green.
- G1 finite: governance LOC / product LOC ratio drops below `1.0`.
- ConcurrencyLoadIT green.

### 4.8 Out-of-scope reviewer findings during the wave

Reviewer findings about LLM-prompt-security wording, run-state
machine drift, or outbox semantics are batched. The W2 audit-trail
commit advances `llm_gateway`, `run_lifecycle`, and `outbox_capability`
rows in `architecture-status.yaml`.

### 4.9 Risks + mitigations

| Risk | Mitigation |
|---|---|
| Spring AI breaking changes | Pin to 1.0.x; lock with BOM |
| LLM provider quota in CI | Use fake provider in CI; nightly real-provider job with budget alarm |
| Cost telemetry under-reports | Token counts straight from provider response; unit-tested |
| Cancellation races | Use `CompletableFuture.cancel(true)` + DB status flag + cooperative checkpoints |

### 4.10 Rollback

W2 is additive. If a W2 commit breaks W0/W1, revert. Outbox table can
be left in DB; ignored by W0/W1 code.

---

## 5. W3 -- ActionGuard + tools + memory + cost-down

### 5.1 Goal

A tenant's run can call user-configured tools through MCP; ActionGuard
authorizes each call against an OPA policy; a per-tenant token budget
caps spend; pgvector-backed memory recalls relevant context across
runs in the same session; A/B prompt versions can be rolled out
gradually.

### 5.2 Scope (in)

- MCP Java SDK; one stub tool (`echo`) + one real tool
  (`http_get_with_allowlist`).
- `McpToolRegistry`: loads MCP servers as Spring beans; per-tenant
  enable list.
- `ActionGuard` filter chain: 5 stages (Authenticate / Authorize /
  Bound / Execute / Witness).
- OPA sidecar in compose; Rego policies under `ops/opa/policies/`.
- `audit_log` table (append-only; INSERT-only role).
- `MemoryService`: L0 Caffeine, L1 Postgres (`run_memory`,
  `session_memory`), L2 pgvector (`long_term_memory`).
- Spring AI VectorStore for pgvector; embedding via configured
  embedding provider.
- `prompt_version` table; `PromptRouter` selects version per tenant
  (A/B rule = hash(tenant_id) % 100 < threshold).
- Token budget: `tenant_budget` table; `BudgetGuard` checks before LLM
  call; 429 when exceeded.
- `feedback` table; `FeedbackController` accepts thumbs + optional
  text per `run_id`.
- **Graph DSL Conformance** (`graph_dsl_conformance`, §4 #17): extend
  `ExecutorDefinition.GraphDefinition` with: (a) `StateReducer` registry (`OverwriteReducer`,
  `AppendReducer`, `DeepMergeReducer`) applied on partial state updates; (b) typed `Edge` records with optional
  `Function<RunContext, Boolean>` predicate for conditional routing; (c) `GraphSerializer`
  emitting JSON + Mermaid topology. Factory method `GraphDefinition.simple(...)` retained for
  backward compat. Existing `NestedDualModeIT` updated to exercise conditional edge.
- **Hybrid RAG** (`hybrid_rag_bm25`): extend `MemoryService` L2 tier — alongside pgvector,
  maintain a BM25 keyword index (`pg_bm25` extension or ElasticSearch fallback); final
  relevance score = `alpha * vectorScore + (1 - alpha) * bm25Score` where `alpha` is a
  per-tenant tunable; default `alpha = 0.7`.
- **Sandbox Executor SPI** (`sandbox_executor_spi`, ADR-0018): `SandboxExecutor` interface
  consumed by ActionGuard Bound stage before tool execution. Default `NoOpSandboxExecutor`
  (in-JVM Java calls only). Pluggable reference: `GraalPolyglotSandboxExecutor` scaffold
  (GraalVM 24.2+, not activated in default compose). Bound stage rejects execution if
  `SandboxExecutor.check(toolCall, policy)` throws `SandboxViolationException`.

### 5.3 Scope (out, deferred)

- Temporal durable workflow swap (still synchronous orchestrator in W3): W4.
- Skill registry plug-in loading (capability beans only, no SPI hot-reload): W4.
- Eval harness wiring: W4.
- HA / chaos / multi-replica tests: W4.
- Production audit chain Merkle anchoring (in-Postgres only in W3): W4 optional.

### 5.4 OSS dependencies pinned

| Dep | Version |
|---|---|
| MCP Java SDK | latest stable (likely 0.x) |
| OPA | 0.65.x |
| pgvector | 0.7.x |
| Spring AI VectorStore PgVector | 1.0.x |

### 5.5 Glue modules

Estimated 2000 LOC. Key files:

- `agent-runtime/.../action/ActionEnvelope.java`
- `agent-runtime/.../action/ActionGuardFilter.java` (5-stage chain)
- `agent-runtime/.../tool/McpToolRegistry.java`
- `agent-runtime/.../tool/HttpGetAllowlistTool.java`
- `agent-runtime/.../memory/MemoryService.java`
- `agent-runtime/.../memory/PgVectorAdapter.java`
- `agent-runtime/.../prompt/PromptRouter.java`
- `agent-runtime/.../budget/BudgetGuard.java`
- `agent-runtime/.../feedback/FeedbackController.java`
- `agent-runtime/.../audit/AuditWriter.java`
- `ops/opa/policies/action_guard.rego`
- Tests: `ActionGuardE2EIT`, `ToolAllowlistIT`, `MemoryRecallIT`,
  `BudgetCapIT`, `PromptABRolloutIT`.

### 5.6 Tests

| Test | Layer | Asserts |
|---|---|---|
| `ActionGuardE2EIT` | E2E | Unauthorized tool call -> 403 + audit row |
| `ActionGuardLatencyIT` | Integration | OPA p99 < 5ms with sidecar |
| `ActionGuardOpaOutageIT` | Integration | OPA down -> deny in research/prod |
| `AuditAppendOnlyIT` | Integration | UPDATE / DELETE on audit_log fails (role) |
| `ToolAllowlistIT` | Integration | http_get rejects non-allowlisted host |
| `ToolDispatchE2EIT` | E2E | LLM tool-call -> ActionGuard -> tool -> result |
| `MemoryRecallIT` | E2E | Write fact in run 1; retrieve in run 2 of same session |
| `MemoryRlsIsolationIT` | E2E | Tenant A's memory invisible to B (RLS) |
| `BudgetCapIT` | Integration | Tenant budget exceeded -> 429 |
| `PromptABRolloutIT` | Integration | A/B rollout assigns deterministically |
| `OpaPolicyUnitTest` (Rego) | Unit | Each rule allow / deny case |

### 5.7 Acceptance gates

- F4 = 1: `ActionGuardE2EIT` green; an unauthorized tool call returns
  403 with audit row.
- F5 = 1: posture-boot-fail test green: missing required env in
  `research` posture refuses to start.
- P2 deliverables: `LlmRouter` cost-tier escalation in tests; budget
  cap test green.
- P3 deliverables: feedback collection works; prompt A/B test green.
- A/B rollout demonstrates 10% / 50% / 100% rollout works.

### 5.8 Out-of-scope reviewer findings during the wave

ActionGuard semantic findings batched. The W3 audit-trail commit
advances `action_guard`, `skill_runtime_authz`, `memory_capability`,
and `llm_prompt_security` rows in `architecture-status.yaml`.

### 5.9 Risks + mitigations

| Risk | Mitigation |
|---|---|
| OPA latency adds tail | Local sidecar; benchmark in `ActionGuardLatencyIT`; cap p99 < 5ms; degrade-to-deny on OPA outage |
| pgvector dimensions mismatch on provider switch | Store provider+model with embedding row; reject mismatch |
| Budget race conditions | Use Postgres advisory locks per tenant for budget decrement |
| MCP protocol versioning | Pin to one MCP version; document migration |

### 5.10 Rollback

ActionGuard can be disabled by removing the filter from the chain;
fallback is "all calls denied" (fail-closed). Memory is additive.

---

## 6. W4 -- Long-running workflows + eval + HA

### 6.1 Goal

A run that takes 10 minutes survives a worker crash. Nightly eval runs
detect prompt regressions. The platform runs in K8s with two replicas;
killing one replica during load produces zero 5xx outside the graceful
drain window. Skill registry permits adding a capability without
redeploying the platform.

### 6.2 Scope (in)

- Temporal Cluster in `compose.yml` (single-node) and Helm chart
  (cluster mode for prod).
- `RunWorkflow` interface; `RunWorkflowImpl` with activity boundaries
  at every LLM call + tool call.
- `LlmCallActivity`, `ToolCallActivity` (idempotent retries with
  exponential backoff via Temporal RetryOptions).
- `CancelRunSignal` for cancellation.
- `RunOrchestrator` swapped: long-running runs (TTL > 30s estimated)
  start a Temporal workflow instead of synchronous.
- Eval harness in `agent-eval/`: canonical prompt suite + assertions;
  CI nightly job; baseline thresholds checked in.
- Skill registry: capabilities loaded via `META-INF/services` SPI;
  capabilities can be added by deploying a sidecar or dropping a JAR
  into a configured plugin directory (dev-only); production skill
  isolation is via separate-pod sidecars.
- Helm chart full: 2 replicas, HPA, PDB, readiness/liveness probes,
  graceful shutdown, ConfigMap + Vault sidecar.
- Chaos test: kill one replica during 100 concurrent runs; assert zero
  5xx outside 30s graceful window.
- Audit chain: append-only audit log + periodic Merkle root anchor (in
  Postgres for v1; S3 Object Lock optional).
- **Eval Harness Contract** (`eval_harness_contract`, §4 #18, Rule 18): corpus loader reads
  `docs/eval/<capability>/corpus.jsonl`; LLM-as-judge runner (configurable judge model +
  versioned prompt template) scores each output; `EvalThresholdGate` reads
  `docs/eval/<capability>/thresholds.yaml` and blocks merge on regression. `EvalRegressionIT`
  replaces the generic placeholder with a real corpus-driven test.
- **Planner-as-Tool** (`planner_as_tool_pattern`): `RunPlanSheet` toolset for
  `IterativeAgentLoopExecutor` — tools: `createRunPlan`, `reviseRunPlan`, `completeSubtask`,
  `listSubtasks`, `finalizeRunPlan`, `listArchivedRunPlans`, `restoreArchivedRunPlan`. Plan rows
  persist in the `run_memory` table keyed by `run_id`; `parentRunId` chain enables plan-reuse
  across correlated runs.
  Activated by `AgentLoopDefinition.planningEnabled(true)`.
- **Trace Replay Dev Surface** (`trace_replay_dev_surface`, ADR-0017): MCP server exposing
  `/tools/get_run_trace(runId)` and `/tools/list_runs(tenantId, since)` that read structured
  OTel span data from the `trace_store` table populated by `GraphNodeTraceWriter`.
  No HTML/JS. Clients: Claude Desktop, custom CLI. `§1 Admin UI exclusion preserved`.

### 6.3 Scope (out, deferred)

- Multi-framework dispatch (LangChain4j / Python sidecar): W4+ post.
- Knowledge-graph integration (Apache Jena): deferred indefinitely.
- L3 memory warehouse export: W4+ post.
- Cross-region active-active deployment: W4+ post.
- Production multi-tenant Temporal Cloud subscription: ops-track.

### 6.4 OSS dependencies pinned

| Dep | Version |
|---|---|
| Temporal | server 1.24.x; Java SDK 1.25.x |
| Kubernetes | 1.30+ |
| Helm | 3.x |
| chaos-mesh or simple `kubectl delete pod` script | optional |

### 6.5 Glue modules

Estimated 2500 LOC. Key files:

- `agent-runtime/.../temporal/RunWorkflow.java`
- `agent-runtime/.../temporal/RunWorkflowImpl.java`
- `agent-runtime/.../temporal/LlmCallActivity.java`
- `agent-runtime/.../temporal/ToolCallActivity.java`
- `agent-runtime/.../temporal/TemporalConfig.java`
- `agent-eval/.../EvalRunner.java`
- `agent-eval/.../canonical/PromptCases.java`
- `ops/helm/` (full chart)
- `gate/run_operator_shape_smoke.sh` rewritten as the real flow

### 6.6 Tests

| Test | Layer | Asserts |
|---|---|---|
| `LongRunResumeIT` | E2E | Kill workers mid-run; restart; run completes |
| `CancelLiveRunIT` | E2E | Signal cancellation -> CANCELLED <= 5s |
| `WorkflowDeterminismLintIT` | CI | non-deterministic patterns rejected |
| `ActivityIdempotencyIT` | Integration | Replay activity twice; no double side effect |
| `TemporalProviderOutageIT` | Integration | Temporal hiccup; workflow recovers |
| `KillReplicaIT` | E2E | Kill 1 replica during 100-req load; zero 5xx outside drain |
| `EvalRegressionIT` | Nightly | baseline pass-rate not regressed |
| `EvalNightlyJobIT` | Nightly | full suite runs + report uploaded |
| `SkillRegistryHotLoadIT` | Integration | adding a skill JAR works without redeploy (dev only) |

### 6.7 Acceptance gates

- R8 = 1: real Postgres SET LOCAL test green (already W1; verify under load).
- F8 = 1: `rule_8_operator_shape` (sequential N=3 against real provider) green in nightly. **`dependency_mode: real` + `rule_8_eligible: true`.** Fallback count = 0.
- F9 (long-run) = 1: `LongRunResumeIT` green: kill workers mid-flight,
  run completes after worker restart.
- HA test green: kill replica during load; zero 5xx outside drain.
- Eval baseline checked in; nightly regression gate enabled.
- Operator-shape smoke gate emits a real PASS at the architectural
  SHA (no hand-crafted log).

### 6.8 Out-of-scope reviewer findings during the wave

Final-wave findings batched. The W4 audit-trail commit advances all
remaining capability rows to maturity L1 (W4 closes design coverage)
and records the operator-shape Rule 8 PASS evidence.

### 6.9 Risks + mitigations

| Risk | Mitigation |
|---|---|
| Temporal cluster cost in prod | Single-node for v1 customers; cluster only when load demands |
| Activity non-determinism | Activities only do I/O; workflow code is deterministic; lint rule |
| Eval regressions blocking release | Threshold tunable; clear rollback by reverting prompt version |
| Skill plugin security | Plugin signing + capability allowlist per tenant |

### 6.10 Rollback

Each component additive. Temporal can be turned off via feature flag
(falls back to synchronous orchestration for short runs). Skill
registry can be disabled.

---

## 7. Cross-wave artifacts

### 7.1 CI (GitHub Actions)

- Build on every PR.
- Unit + integration tests on every PR.
- Architecture-sync gate on every PR (kept; pruned in W0).
- Nightly: real-provider tests + eval harness.
- Linux + macOS matrix (Windows added in W2 via the existing PowerShell
  gate).

### 7.2 Documentation cadence

- Update this plan at every wave close.
- Update `architecture-v7.0.md` only when an architectural decision
  changes (new OSS, removed component). Not for wave progress.
- v6 design rationale moves to `docs/v6-rationale/` in W0.

### 7.3 Score reporting

Each wave's PR description includes a delta on the 32-dimension
framework. Format:

```
Score before: R 1/8 F 0/8 G 0/6 C 0/5 E 0/5 = 1/32
Score after:  R 4/8 F 0/8 G 1/6 C 0/5 E 0/5 = 5/32
+R2 +R3 +R6 +G1
```

A wave that does not advance the score is rolled back or replanned.

## 8. Risk register (plan-level)

| ID | Risk | Severity | Mitigation owner | Wave |
|---|---|---|---|---|
| RP-1 | Spring Boot 4.0.5 is the active baseline (upgraded from 3.5.x in cycle-13) | M | Baseline confirmed; no pin action needed | W0 |
| RP-2 | LLM provider terms-of-service for stored tenant prompts | H | Document data-handling per provider; per-tenant provider lock | W2 |
| RP-3 | Postgres scale ceiling at single instance | M | Read replicas + partitioning W4+; v1 customer < 500 RPS | W4+ |
| RP-4 | Temporal operational complexity | M | Single-node v1; managed Temporal Cloud as upgrade path | W4 |
| RP-5 | OPA policy debugging | L | Rego unit tests + `opa eval` CI step | W3 |
| RP-6 | Java virtual threads + JDBC pinning | M | HikariCP 5.x; no synchronized blocks around JDBC | W0 |
| RP-7 | Customer wants Python sidecar prematurely | M | Decline; document policy in `architecture-v7.0.md` sec-7 | always |

## 9. v6 deprecation tasks (W0 only)

A single audit-trail commit at W0 close, not per-file work:

1. Banner on `ARCHITECTURE.md` (v6) -> "Superseded; see
   `ARCHITECTURE.md`."
2. Move v6 entries in `docs/governance/active-corpus.yaml` from
   `active_documents` to `historical_documents` with reason `v6
   design rationale`.
3. Move `docs/plans/W0-evidence-skeleton.md`,
   `docs/plans/roadmap-W0-W4.md` to `historical_documents`.
4. `docs/governance/architecture-status.yaml`: add a `v7_migration`
   section listing every v6 capability with status `deprecated_in_v7`,
   `migrated_to_v7`, or `replaced_by_oss:<dep>`.
5. Update `docs/governance/current-architecture-index.md` to lead with
   v7.

After W0 the gate's scope shrinks substantially because v6 docs are
historical_documents.

## 10. End state at W4 close

The repository looks like:

- `~9000 LOC` of Java source across `agent-platform/` and `agent-runtime/`.
- `~3500 LOC` of test source.
- One Helm chart, one compose file.
- One eval harness with a baseline.
- Real Postgres + Temporal + Valkey + Keycloak + OPA + Vault running
  via compose.
- A working agent runtime that authenticates a tenant, calls real
  LLMs, calls real tools, persists durable runs, can survive a worker
  crash, and reports cost.
- Architecture-sync gate pruned to <= 200 lines because most of v6's
  drift surfaces are gone.

At that point spring-ai-ascend's score on the 32-dimension framework
reaches `~23/32`, and remaining gaps (E external grounding -- needs
real users; full F coverage; capability-registry separation) are real
product problems, not governance problems. Cycle 9 is no longer the
question; the question becomes which customer to onboard first.
