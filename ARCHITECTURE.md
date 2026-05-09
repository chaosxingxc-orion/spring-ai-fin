# spring-ai-fin Platform -- Architecture (v6.0)

> **Last refreshed:** 2026-05-08 (continuous refinement; not a major version
> bump). This document folds in the 2026-05-08 reset described in
> `docs/architecture-meta-reflection-2026-05-08.en.md`: every core
> component is now grounded in a named open-source project, every
> architectural claim has a row in `docs/plans/engineering-plan-W0-W4.md`,
> and aspirational surfaces that did not survive cycles 1..8 of review
> have been removed. The version line stays v6 -- this is a refresh, not
> a rewrite, per the user's "no fast version bumps" rule.
>
> **Authoring rule:** every section either names an OSS component + a
> glue module + a test, or it does not belong in this document.

## 0. Purpose and constraints

spring-ai-fin is a self-hostable agent runtime for financial-services
operators. It accepts authenticated tenant requests, drives one or more
LLMs through a tool-calling loop with audit-grade evidence, and persists
durable side effects through an idempotent outbox. It is built on Spring
Boot 3.x + Java 21.

Four constraints applied to every section below:

1. **OSS-first.** Every core component is an existing open-source project
   we depend on, configure, or harden. Self-development is restricted to
   glue (filters, dispatchers, repositories, configuration beans).
2. **Nine quality attributes.** Functional idempotency, high concurrency,
   evolvability, high availability, high reliability, scalability,
   user-configurable customization, persistently evolving intelligence,
   and stable long-running task execution. Section 4 maps each to a
   mechanism + a test.
3. **Three first-principles.** (P1) the user's threshold for adopting
   the platform decreases over time; (P2) the user's per-task cost
   decreases over time; (P3) the platform's intelligence improves over
   time. Section 5 maps every component to one or more principles.
4. **Engineering plan.** Every architectural claim has a row in
   `docs/plans/engineering-plan-W0-W4.md` with a wave, an OSS dependency,
   a glue module, a test, and an acceptance metric from the 32-dimension
   scoring framework defined in
   `docs/architecture-meta-reflection-2026-05-08.en.md`.

A claim that does not satisfy all four constraints is removed.

## 1. Layered system view

Three layers, each layer terminates at a public contract.

```
+-------------------------------------------------------------+
|  L1: Edge -- Spring Cloud Gateway / Spring Web              |
|     - JWT validation (Spring Security + Keycloak / OIDC)    |
|     - Tenant binding (JWT claim -> request scope)           |
|     - Idempotency-Key dedup (Postgres dedup table)          |
|     - Rate limit + circuit breaker (Resilience4j)           |
+----------------------|--------------------------------------+
                       |
+----------------------v--------------------------------------+
|  L2: Application -- Spring Boot 3.x + Java 21 virtual threads|
|     - RunController, ToolController, AdminController         |
|     - RunOrchestrator (sync) | TemporalRunWorkflow (async)   |
|     - ActionGuard (filter pipeline)                          |
|     - Spring AI ChatClient (LLM)                             |
|     - MCP Server adapters (tool calling)                     |
|     - MemoryService (Caffeine -> Postgres -> pgvector)       |
|     - OutboxPublisher                                        |
+----------------------|--------------------------------------+
                       |
+----------------------v--------------------------------------+
|  L3: Persistence + external                                 |
|     - PostgreSQL 16 (Flyway, pgvector, RLS, outbox)         |
|     - Valkey (cache + ephemeral state)                      |
|     - Temporal Cluster (durable workflows)                  |
|     - LLM providers (Anthropic, OpenAI, Bedrock, on-prem)   |
|     - Vault (secrets); Keycloak (identity); OPA (policy)    |
+-------------------------------------------------------------+
```

Each layer's responsibility:

- **L1 Edge** rejects anything not safe to enter L2: missing JWT, weak
  algorithms, missing tenant claim, replayed idempotency key,
  rate-limited tenant. Implementation: Spring Cloud Gateway routes +
  Spring Security filter chain. No business logic.
- **L2 Application** is stateless across replicas; all state lives in
  L3. Implementation: Spring Boot. Long-running flows are delegated to
  Temporal so the application process can crash without losing work.
- **L3 Persistence** is the only place state survives. Implementation:
  Postgres for relational + vector + outbox; Valkey for cache;
  Temporal for workflow state; Vault for secrets.

## 2. OSS component matrix

Concrete dependency choices. Hardening = configuration + glue + test;
secondary development = patches we contribute upstream.

| Concern                | Primary OSS                          | Hardening / glue we own                             | Wave |
|------------------------|--------------------------------------|-----------------------------------------------------|------|
| HTTP server            | Spring Boot 3.5.x + embedded Tomcat  | Controllers, exception handlers                     | W0   |
| Concurrency            | Java 21 virtual threads (Project Loom) | `spring.threads.virtual.enabled=true`             | W0   |
| Build / package        | Maven 3.9                            | `pom.xml` multi-module                              | W0   |
| Migrations             | Flyway 10.x                          | SQL files                                           | W0   |
| Persistence            | PostgreSQL 16                        | Schemas, RLS policies                               | W0   |
| Connection pool        | HikariCP 5.x                         | Pool config + RLS sync                              | W0-W1|
| Identity (OIDC)        | Keycloak 25.x (default)              | Realm config; JWKS URL                              | W1   |
| AuthN filter           | Spring Security 6                    | `SecurityFilterChain` + JWT decoder                 | W1   |
| Tenant binding         | (glue: `TenantBinder`)               | Spring filter + `SET LOCAL app.tenant_id`           | W1   |
| Authorization (policy) | Open Policy Agent 0.65.x             | Rego policies + sidecar adapter                     | W3   |
| Resilience             | Resilience4j 2.x                     | `@CircuitBreaker`, `@RateLimiter` annotations       | W1   |
| Idempotency            | Postgres dedup table                 | `IdempotencyFilter` glue                            | W1   |
| LLM client             | Spring AI 1.0.7 (GA; latest 1.0.x patch) | `ChatClient` beans per provider; routing rules    | W2   |
| Tool protocol          | MCP Java SDK 2.0.0-M2 (milestone)    | MCP servers as Spring beans                         | W3   |
| Vector search          | pgvector 0.7.x + Spring AI VectorStore | `EmbeddingStoreConfig` + retrieval glue           | W2-W3|
| Embeddings             | Provider-side (OpenAI / Voyage)      | `EmbeddingClient` bean                              | W2   |
| Document parsing       | Apache Tika 2.x                      | `DocumentParser` glue                               | W3   |
| Workflow / durable     | Temporal Java SDK 1.34.0 + Cluster   | `RunWorkflow` interface + activity classes          | W4   |
| Caching                | Caffeine 3.x (in-process) + Valkey 7.x | `CacheManager` config                             | W1-W2|
| Outbox                 | Postgres `outbox` table              | `OutboxPublisher` glue                              | W2   |
| Observability metrics  | Micrometer + Prometheus              | Custom metrics; `@Timed` annotations                | W0   |
| Observability traces   | OpenTelemetry Java agent 2.x         | Auto-instrumentation; `@WithSpan` for hot paths     | W1   |
| Observability logs     | Logback JSON encoder + Loki          | Log appender config                                 | W0   |
| Dashboards             | Grafana                              | Pre-built JSON dashboards                           | W2   |
| Validation             | Jakarta Bean Validation (Hibernate Validator) | `@Valid` on DTOs                            | W0   |
| Serialization          | Jackson                              | `ObjectMapper` config                               | W0   |
| API docs               | springdoc-openapi 2.x                | OpenAPI annotations                                 | W0   |
| Secrets                | HashiCorp Vault (OSS)                | Spring Cloud Vault binding                          | W2   |
| Container              | Buildpacks (Paketo) or Dockerfile    | `Dockerfile`                                        | W0   |
| Orchestration          | Kubernetes 1.30+ + Helm 3 (prod); Compose (dev) | Helm chart + `compose.yml`               | W0-W2|
| Testing unit           | JUnit 5                              | Test classes                                        | W0   |
| Testing integration    | Testcontainers 1.20.x                | Postgres, Temporal, Valkey containers               | W0-W2|
| Testing E2E            | RestAssured + Karate                 | Karate `.feature` files                             | W1   |
| Eval harness           | Custom on JUnit + Ragas-Java port    | Eval suite                                          | W4   |
| CI                     | GitHub Actions                       | `.github/workflows/*.yml`                           | W0   |
| Linting                | Checkstyle + ErrorProne              | `.checkstyle.xml`                                   | W0   |
| _Multi-framework dispatch_ | _LangChain4j (alternative bean)_  | _Adapter glue if a customer demands_                | W4+  |
| _Python sidecar_        | _Generic gRPC; FastAPI / sidecar app_ | _Only if a customer demands_                       | W4+  |

This table is the authoritative dependency list. Adding a row requires a
decision in the engineering plan; removing a row requires explicit
deprecation evidence. Glue we own totals an estimated 4-6k LOC across W0-W4.

### 2.1 OSS dependency policy

- **Pin via Maven BOM.** Each managed dep has its version range in a
  parent `pom.xml`. No floating ranges in module POMs.
- **Security advisories.** GitHub Dependabot enabled on the repo;
  Snyk weekly scan; CVE >= 7.0 must be patched within 14 days, CVE
  >= 9.0 within 72 hours.
- **Upgrade cadence per tier.**
  - Tier-1 (security-critical: Spring Security, Spring Boot, Postgres
    JDBC, JJWT/Nimbus, Vault): minor monthly; major within 90 days
    of release.
  - Tier-2 (runtime-critical: Spring AI, Temporal, pgvector,
    Resilience4j, Caffeine): minor quarterly; major within 180 days
    of release.
  - Tier-3 (testing/build: Testcontainers, JUnit, Maven plugins):
    minor on convenience; major opportunistic.
- **Breaking-change handling.** A Tier-1 or Tier-2 major upgrade
  requires (a) a wave-style plan in
  `docs/plans/engineering-plan-W0-W4.md` for the version bump, (b)
  green CI on a feature branch before merge, (c) a rollback recipe
  documented in the wave's Rollback subsection.
- **Reproducible builds.** `mvn -B -ntp` for CI; checksum-locked
  resolver via `--strict-checksums`.

### 2.1.5 OSS verification ladder (U0..U4)

The OSS matrix above pins each dep to a *version* and assigns a
*wave*. Cycle-11 added a parallel axis: how *verified* the
integration is. The ladder mirrors capability maturity (Rule 12 L0..L4)
but tracks OSS integration, not product readiness.

| Level | Meaning |
|---|---|
| **U0** | Design-only -- version chosen by reasoning; no docs read for this exact version |
| **U1** | API-doc-verified -- version pinned; release notes / Javadoc read for the cited APIs |
| **U2** | Sample-code-verified -- a probe in-tree compiles + the cited API resolves |
| **U3** | Integration-verified -- IT test exercises the API at the pinned version |
| **U4** | Production-verified -- prod traces show the API behaving as designed |

Today only Spring AI 1.0.7, Temporal Java SDK 1.34.0, and MCP Java SDK
2.0.0-M2 are at **U1** (cycle-11 verified them via upstream release
notes / Maven Central on 2026-05-09). Every other dep is at **U0**.
W0 advances all critical-path deps to U2 by adding a probe that
compiles the cited API surface.

The full per-dep BoM (groupId, artifactId, exact version, status,
verification level, cited APIs, glue, fallback, risks) lives in
`docs/cross-cutting/oss-bill-of-materials.md`. That doc is the
authoritative source; this matrix is a summary.

### 2.2 Glue / OSS LOC ratio targets

These targets enforce the OSS-first constraint quantitatively. Glue
LOC is everything we author; OSS LOC is the transitive Maven
dependency surface.

| Metric | At W0 close | At W2 close | At W4 close |
|---|---|---|---|
| Glue / Product LOC (glue + OSS jars) | <= 0.05 | <= 0.04 | <= 0.03 |
| Glue / OSS jar LOC (transitive) | <= 0.005 | <= 0.005 | <= 0.005 |
| Glue absolute LOC | <= 1500 | <= 4000 | <= 6000 |

A wave whose glue LOC overshoots the target triggers a refactor pass
before the next wave starts. The CI exposes
`scripts/loc-ratio-report.sh` (W0) that computes glue LOC vs. the
Maven dependency tree. The ratio target is asserted in the
architecture-design self-audit (`docs/architecture-design-self-audit.md`).

## 3. Module layout

```
spring-ai-fin/
  pom.xml                           # parent (Maven; Java 21; Spring Boot BOM)
  agent-platform/                   # northbound module (web + auth + edge)
    pom.xml
    src/main/java/...
      web/                          # Controllers + exception handlers
      auth/                         # Security filter chain config
      tenant/                       # TenantBinder + RLS interceptor
      idempotency/                  # IdempotencyFilter + dedup repo
      bootstrap/                    # Spring Boot main + PostureBootGuard
      config/                       # tenant-config + Spring Cloud Config
      contracts/                    # public DTO records + OpenAPI
    src/main/resources/
      application.yml
      db/migration/                 # Flyway SQL
    src/test/...                    # unit + integration tests
  agent-runtime/                    # cognitive runtime
    pom.xml
    src/main/java/...
      run/                          # RunController, RunOrchestrator
      llm/                          # ChatClient beans, LlmRouter
      tool/                         # MCP server registrations + ToolRegistry
      action/                       # ActionGuard 5-stage chain
      memory/                       # MemoryService (L0/L1/L2)
      outbox/                       # OutboxPublisher
      temporal/                     # Temporal workflow + activity classes
      observability/                # custom metrics + cardinality guard
    src/main/resources/
      application.yml
      db/migration/
    src/test/...
  agent-eval/                       # eval harness (W4)
    pom.xml
    src/main/java/...
  ops/
    compose.yml                     # dev compose: postgres, valkey, temporal, keycloak, grafana, loki
    helm/                           # prod chart
    grafana-dashboards/
    opa/policies/                   # Rego (W3)
  gate/                             # architecture-sync + operator-shape gates
  docs/
    plans/engineering-plan-W0-W4.md       # the wave plan
    plans/architecture-systems-engineering-plan.md   # doc-set drill-down
    cross-cutting/                  # security, posture, observability policies
    governance/                     # active-corpus, status, manifest
  CLAUDE.md
  AGENTS.md
```

The split between `agent-platform` and `agent-runtime` is the only
required module split. Sub-packages are organizational, not modular --
they map to L2 ARCHITECTURE.md files for documentation only, not for
build boundaries.

### 3.1 Module dependency graph

```
              [agent-platform/contracts]
                        ^
                        | (DTOs, IDs, types)
        +---------------+---------------+
        |                               |
[agent-platform/*]              [agent-runtime/*]
   web                              run
   auth                             llm
   tenant                           tool
   idempotency                      action
   bootstrap                        memory
   config                           outbox
   contracts                        temporal
                                    observability
        |                               |
        +---------------+---------------+
                        v
                   [Postgres / Valkey / Temporal / OPA / Vault]
                   (L3 dependencies; via Spring beans)

[agent-eval]  --(tests against agent-platform + agent-runtime contracts)-->
```

Rules:

1. `agent-platform/contracts` is the only module that exports types
   used by both `agent-platform/*` and `agent-runtime/*`. Every other
   inter-module Java type lives in its owning module.
2. **No cycles.** Directional edges only:
   `agent-platform/* -> agent-platform/contracts`,
   `agent-runtime/* -> agent-platform/contracts`, and
   `agent-runtime/* <- agent-platform/*` is FORBIDDEN (the reverse;
   platform calls runtime via a published interface in
   `agent-platform/contracts` only).
3. `agent-eval` may depend on either platform or runtime contracts but
   neither depends on `agent-eval`.
4. L3 dependencies (Postgres, Valkey, Temporal, OPA, Vault) are
   accessed only via Spring beans configured in the relevant L2
   module. No L2 directly opens a connection that another L2 owns.
5. CI rule: ArchUnit tests in `agent-platform/contracts` enforce the
   no-cycle property at PR time (W0 deliverable in
   `BuildSmokeTest`).

The full Java type ownership table is in
`docs/cross-cutting/data-model-conventions.md` sec-13.

## 4. The nine quality attributes -- mechanism + test

For each quality the table names the OSS component or glue that
provides it, the configuration that activates it, and the integration
test that proves it.

### 4.1 Functional idempotency

| Element | Choice |
|---|---|
| Mechanism | `Idempotency-Key` HTTP header + Postgres dedup table; outbox-based side effects |
| OSS | Spring Web filter, Postgres unique index |
| Glue | `IdempotencyFilter`, `IdempotencyRepository`, `OutboxPublisher` |
| Test | `IdempotencyDoubleSubmitIT` -- send same key twice, assert one side effect |
| Wave | W1 (filter) + W2 (outbox) |

### 4.2 High concurrency

| Element | Choice |
|---|---|
| Mechanism | Java 21 virtual threads (Project Loom); HikariCP pool sized to virtual-thread fanout; Spring AI async `ChatClient` |
| OSS | OpenJDK 21, HikariCP, Spring AI |
| Glue | `application.yml`: `spring.threads.virtual.enabled=true`; pool sized via env |
| Test | `ConcurrencyLoadIT` -- 200 concurrent requests, assert tail latency p99 < target |
| Wave | W0 (loom) + W2 (load test) |

### 4.3 Evolvability

| Element | Choice |
|---|---|
| Mechanism | Maven multi-module enforces dependency direction; semver on the public REST contract; Flyway for DB; per-module ARCHITECTURE.md |
| OSS | Maven, Flyway, springdoc-openapi |
| Glue | `pom.xml` dependency rules; OpenAPI version header; CHANGELOG.md |
| Test | `OpenApiContractIT` -- read pinned `openapi-vN.yaml`, fail on breaking change |
| Wave | W0 (modules + Flyway) + W2 (contract test) |

### 4.4 High availability

| Element | Choice |
|---|---|
| Mechanism | Stateless app replicas; Postgres + Valkey + Temporal externalized; K8s liveness / readiness probes; PodDisruptionBudget; Spring Boot graceful shutdown |
| OSS | Kubernetes, Spring Boot actuator, Helm |
| Glue | Helm chart with PDB + HPA; `/actuator/health/readiness` mapped from real deps |
| Test | `KillReplicaIT` -- kill one replica during 100-req load, assert zero 5xx outside graceful drain window |
| Wave | W2 (Helm) + W4 (chaos test) |

### 4.5 High reliability

| Element | Choice |
|---|---|
| Mechanism | At-least-once outbox; Temporal workflow durability; Resilience4j circuit breakers + retries; Postgres ACID for synchronous side effects |
| OSS | Temporal, Resilience4j |
| Glue | `OutboxPublisher`, `RunWorkflow`, `@CircuitBreaker` on LLM + tool calls |
| Test | `LlmProviderOutageIT`, `OutboxAtLeastOnceIT`, `LongRunResumeIT` |
| Wave | W2 (outbox + retries) + W4 (Temporal full) |

### 4.6 Scalability

| Element | Choice |
|---|---|
| Mechanism | Stateless app -> horizontal scale via K8s HPA on CPU + queue-depth metric; Postgres scale-up + read replicas (W4+); Temporal cluster shards |
| OSS | Kubernetes HPA, Postgres streaming replication, Temporal |
| Glue | HPA YAML + `agent_runs_pending` Prometheus metric |
| Test | `LinearScaleIT` (manual) -- run with 1, 2, 4 replicas, plot throughput |
| Wave | W2 (HPA wired) + W4 (manual scale test) |

### 4.7 User-configurable customization

| Element | Choice |
|---|---|
| Mechanism | YAML agent definitions per tenant; MCP tool registry (drop-in tools); per-tenant prompt versioning in Postgres; Admin UI for non-engineers |
| OSS | Spring Boot externalized config + Profile, Anthropic MCP SDK, React (Admin UI in W4+) |
| Glue | `TenantConfigLoader`, `PromptVersionResolver`, `McpToolRegistry`, `admin-ui/` |
| Test | `TenantOverrideIT`, `ToolAllowlistIT`, `PromptABRolloutIT` |
| Wave | W3 (registry + prompts) + W4 (Admin UI MVP) |

### 4.8 Persistently evolving intelligence

| Element | Choice |
|---|---|
| Mechanism | Memory tiers: L0 Caffeine in-process; L1 Postgres (run + session memory); L2 pgvector (long-term embeddings); Feedback collection table; nightly eval harness; A/B prompt versions |
| OSS | Caffeine, pgvector, Spring AI VectorStore |
| Glue | `MemoryService`, `FeedbackController`, `agent-eval` module |
| Test | `MemoryRecallIT`, `EvalRegressionIT` |
| Wave | W2 (L0/L1) + W3 (L2 + feedback) + W4 (eval harness) |

### 4.9 Stable long-running tasks

| Element | Choice |
|---|---|
| Mechanism | Temporal workflow per run with activity boundaries at each LLM / tool call; checkpoint at every step; signals for cancellation; replay-safe activity code |
| OSS | Temporal Java SDK + Temporal Cluster |
| Glue | `RunWorkflow` interface, `LlmCallActivity`, `ToolCallActivity`, `CancelRunSignal` |
| Test | `LongRunResumeIT`, `CancelLiveRunIT`, `WorkflowDeterminismLintIT` |
| Wave | W4 |

## 5. First-principle alignment

Every component is justified by at least one principle.

### P1 Lower user threshold

- One-command bringup: `docker compose up` brings Postgres, Temporal, Valkey, Keycloak, the app, Grafana. (W0 deliverable.)
- Helm chart installable with `helm install`. (W2 deliverable.)
- OpenAPI auto-generated by springdoc; published at `/swagger-ui`. (W0.)
- Default agent definitions ship in-tree under `examples/`. (W3.)
- Admin UI for non-engineers. (W4 MVP.)
- Documented quickstart with copy-paste curls.

### P2 Lower user cost

- Multi-tier LLM routing inside `LlmRouter`: cheap model first; escalate on unsatisfactory output (e.g., `gpt-4o-mini` -> `claude-sonnet` -> `claude-opus` only when needed). (W3.)
- Spring AI prompt caching enabled by default for providers that support it. (W2.)
- Per-tenant token budget enforcement: monthly cap configurable; 429 when exceeded. (W3.)
- Cost telemetry per run (`agent_run_cost_usd_total{tenant,model}` Prometheus metric). (W2.)
- Batch inference for non-realtime workloads. (W4+.)

### P3 Persistently evolving intelligence

- Feedback collection (thumbs up/down + free-text) attached to runs, stored in Postgres. (W3.)
- Eval harness runs nightly against canonical prompts; regression must not exceed threshold. (W4.)
- Skill registry: capabilities are named beans loaded at start; new capability JARs can be dropped in without redeploy of the whole platform (Spring Boot DevServices for dev; sidecar pattern for prod isolation). (W4.)
- A/B prompt versions per tenant stored in `prompt_version` table; gradual rollout. (W3.)
- Run-as-training-data export job for fine-tuning corpora. (W4+.)

### 5.4 Measurable proxies (added cycle-10 per L0-2)

Each first-principle has at least one quantitative proxy that the
roadmap can regress over time. Targets evolve wave-over-wave; the
initial baselines below are W4-close targets.

| Principle | Proxy metric | Source | W4-close target |
|---|---|---|---|
| P1 lower threshold | `time_to_first_run_seconds` -- from `docker compose up` to a successful `POST /v1/runs` returning a terminal status | manual stopwatch + scripted measurement in `bin/onboard-smoke.sh` | <= 600s on a stock laptop |
| P1 lower threshold | `helm_install_to_health_seconds` -- from `helm install` to `/actuator/health/readiness` returning UP | scripted measurement in CI on a fresh kind cluster | <= 300s |
| P1 lower threshold | `default_examples_count` -- agents shipped under `examples/` and runnable with one command | repo count | >= 5 |
| P2 lower cost | `median_run_cost_usd_p50` -- per-run LLM cost across the canonical eval suite using cheap-tier-first router | `agent_run_cost_usd_total{}` over a known eval pass | <= $0.005 |
| P2 lower cost | `prompt_cache_hit_rate` -- fraction of LLM calls served from prompt-cache | `llm_prompt_cache_hit_total{} / total` over 24h | >= 30% |
| P2 lower cost | `tenant_budget_breach_per_month` -- count of `BUDGET_TENANT_EXHAUSTED` 429s per tenant per month | `agent_run_budget_breach_total{}` | <= 1 per active tenant |
| P3 evolving intelligence | `eval_pass_rate_baseline` -- canonical prompt suite pass-rate (running against deployed default prompts) | `eval_pass_rate{suite="canonical"}` nightly | >= 0.85 with monotonic non-regression |
| P3 evolving intelligence | `feedback_collection_rate` -- fraction of completed runs with at least one feedback row | `feedback_attached_total{} / agent_run_terminal_total{}` | >= 0.10 (10% of runs get feedback) |
| P3 evolving intelligence | `prompt_ab_rollout_outcomes_per_quarter` -- count of prompt-version PRs that completed an A/B rollout to 100% with eval delta documented | manual ledger | >= 4 per quarter |

Each proxy is owned by one L2 module (the source of the metric or
script). Per-wave Acceptance gates in the engineering plan reference
these proxies when the wave's principle alignment is non-trivial.

Reporting cadence: monthly first-principles review at wave close;
proxies that regress block wave closure (cycle-9 sec-E1 alignment --
maturity is the headline; proxies are the diagnostic).

## 6. Cross-cutting policies

### 6.1 Posture model

`APP_POSTURE` env var = `dev | research | prod`. Read once at boot via
`AppPosture` bean. Strict-mode defaults active for `research` and `prod`:
posture-required env vars must be present, RLS must be enforced, secrets
must come from Vault, weak JWT algorithms rejected. `dev` is permissive.
Implementation: `PostureBootGuard` runs at `ApplicationStartedEvent`;
defined in `agent-platform/bootstrap/`.

### 6.2 Tenant spine

Every persistent record carries `tenant_id NOT NULL`. RLS policies on
every tenant-scoped table enforce row visibility. Connection-level GUC
`app.tenant_id` is set with `SET LOCAL` inside every transaction;
Postgres auto-discards on `COMMIT`/`ROLLBACK`. Validation: a transaction
that does not set `app.tenant_id` must fail (a `BEFORE` trigger on every
tenant-scoped table checks `current_setting('app.tenant_id', true)`).
Implementation: `agent-platform/tenant/`.

### 6.3 ActionGuard (collapsed from cycles 1..8 11-stage)

Cycles 1..8 over-specified the boundary to 11 stages. The refresh
reduces it to **5 stages** with the same semantics:

1. **Authenticate** (already done at edge; ActionGuard re-asserts).
2. **Authorize** (OPA query: tenant + capability + posture).
3. **Bound** (rate limit, token budget, idempotency check).
4. **Execute** (the side effect).
5. **Witness** (write audit row + outbox event).

5 stages compose; 11 stages were aspirational. Implementation: a
filter chain inside `agent-runtime/action/`. Pre/post evidence is the
audit row + outbox row; not separate stages.

### 6.4 Audit model

Cycles 1..8 had a 5-class audit model. The refresh collapses to two
surfaces:

- **OpenTelemetry traces** for all LLM / tool / DB spans. Sampled and
  exported to Loki + Tempo.
- **Audit log table** in Postgres for any side effect that affects a
  tenant's data. Append-only via Postgres `INSERT`-only role; periodic
  WORM anchor (hash chain stored, optional S3 Object Lock when prod
  demands).

This drops the bespoke 5-class taxonomy. OTel traces + an audit table
cover every reviewer use case.

### 6.5 Secrets and config

- `application.yml` has only non-secret defaults.
- All secrets via Spring Cloud Vault or, in dev, `compose.env`.
- Per-tenant overrides via `tenant_config` table; loaded by
  `TenantConfigLoader`; cached in Caffeine for 60s.

## 6.6 Non-functional requirements (summary; full table in cross-cutting doc)

Pinned NFRs live in `docs/cross-cutting/non-functional-requirements.md`.
The headline numbers per posture:

| Concern | research | prod |
|---|---|---|
| `POST /v1/runs` (real LLM) p99 | < 5s | < 5s |
| `POST /v1/runs/{id}/cancel` p99 | < 200ms | < 100ms |
| HTTP RPS / replica | 50 | 200 |
| API availability monthly | 99.5% | 99.9% |
| Run lifecycle availability | 99.5% | 99.9% (sync) / 99.95% (Temporal) |
| Per-run median LLM cost | <= $0.005 | <= $0.003 |
| Tenants per single-region deployment | 1-10 | up to 1000 |

W4-close targets. Acceptance gates per wave (in
`docs/plans/engineering-plan-W0-W4.md`) reference these. Ratchet
direction: prod numbers are non-negotiable; research and dev are
relaxed.

## 7. What is removed in this refresh

Explicitly removed or deferred from the cycle-1..8 design surface to
avoid documentation-as-implementation:

- **Multi-framework dispatch** (Python sidecar, LangChain4j adapter): deferred to W4+. Not promised.
- **Apache Jena knowledge graph**: deferred indefinitely until a customer demands it.
- **5-class audit model**: replaced by OTel + one audit table.
- **11-stage ActionGuard**: replaced by 5-stage.
- **L3 memory (warehouse)**: deferred to W4+.
- **Sidecar security profile (UDS / SPIFFE)**: deferred until Python sidecar lands.
- **Strong consistency claims for cross-entity sagas**: removed; outbox is at-least-once, callers are idempotent.

These items are not architectural decisions deferred -- they are removed
from the active surface. Reintroducing one requires a new wave plan with
an identified customer.

## 7.5 Cross-link tables: attribute / principle -> L2 module

These tables are the rubric the architecture-design self-audit
(`docs/architecture-design-self-audit.md`) uses to score G6 coverage
dims. Every quality attribute and every first-principle traces to at
least one L2 module + one wave + one named test.

### 7.5.1 Quality attribute -> L2 module(s) -> wave -> test

| Attribute | L2 module(s) | Wave | Named test |
|---|---|---|---|
| 4.1 Idempotency | `agent-platform/idempotency`, `agent-runtime/outbox` | W1 + W2 | `IdempotencyDoubleSubmitIT`, `OutboxAtLeastOnceIT` |
| 4.2 Concurrency | `agent-platform/web` (virtual threads), `agent-runtime/run` | W0 + W2 | `ConcurrencyLoadIT` |
| 4.3 Evolvability | `agent-platform/contracts` (OpenAPI), `agent-platform/bootstrap` (Flyway) | W0 + W2 | `OpenApiContractIT` |
| 4.4 HA | `agent-runtime/temporal`, `ops/helm` | W2 + W4 | `KillReplicaIT` |
| 4.5 HR | `agent-runtime/outbox`, `agent-runtime/temporal`, `agent-runtime/llm` (circuit breaker) | W2 + W4 | `OutboxAtLeastOnceIT`, `LlmProviderOutageIT` |
| 4.6 Scalability | `ops/helm` HPA, `agent-runtime/observability` (queue-depth metric) | W2 + W4 | `LinearScaleIT` |
| 4.7 Configurable | `agent-platform/config`, `agent-runtime/tool` (MCP), `agent-runtime/llm` (PromptVersionResolver) | W2 + W3 | `TenantOverrideIT`, `ToolAllowlistIT`, `PromptABRolloutIT` |
| 4.8 Evolving intelligence | `agent-runtime/memory`, `agent-eval`, feedback table | W2 + W3 + W4 | `MemoryRecallIT`, `EvalRegressionIT` |
| 4.9 Long-running tasks | `agent-runtime/temporal`, `agent-runtime/run` | W4 | `LongRunResumeIT`, `CancelLiveRunIT` |

### 7.5.2 First-principle -> L2 module(s) -> wave -> mechanism

| Principle | L2 module(s) | Wave | Concrete mechanism |
|---|---|---|---|
| P1 Lower threshold | `ops/compose.yml`, `ops/helm`, `agent-platform/contracts` (OpenAPI), `agent-runtime/tool` (drop-in MCP), `examples/`, admin-ui | W0 + W2 + W3 + W4 | One-command compose; Helm install; OpenAPI; Examples; Admin UI |
| P2 Lower cost | `agent-runtime/llm` (LlmRouter cheap-tier escalation), Spring AI prompt cache, `agent-runtime/outbox` (no extra bus), `agent-platform/idempotency` (no double-charge), token-budget table | W2 + W3 | Cost-tier router; cache; budget cap |
| P3 Evolving intelligence | `agent-runtime/memory` tiers, feedback table, `agent-runtime/llm` PromptVersionResolver, `agent-eval`, skill registry | W3 + W4 | A/B prompts; memory; eval baseline; skill plug-ins |

### 7.5.3 No-reinvention rule (Rule R-OSS)

Adding a glue module that duplicates an OSS component's responsibility
is forbidden. Specifically:

- **Do not** wrap Spring Security in a custom auth filter when the
  out-of-the-box `SecurityFilterChain` works.
- **Do not** wrap Spring AI's `ChatClient` in a custom abstraction when
  Spring AI's API + a `LlmRouter` selector already meet the use case.
- **Do not** invent a custom workflow engine when Temporal can do the
  job.
- **Do not** invent a custom DI / IoC container; Spring is the IoC.
- **Do not** invent a custom JSON / YAML / metrics framework; Jackson
  + SnakeYAML + Micrometer are sufficient.

Glue is allowed only for: tenant binding, idempotency contract, MCP
adapters, ActionGuard chain, OPA bridge, prompt-version resolver,
outbox publisher, RLS sync, posture boot guard, observability
cardinality guard, and similar **adapter / integration** code.

A PR adding glue must answer in the PR description: "Why is this not
a configuration of an existing OSS dep?" -- if the answer is unclear,
the PR is rejected.

### 7.5.4 Restated CLAUDE.md rules in refresh terms

For convenience, the four CLAUDE.md rules most often violated by
documentation-as-implementation are restated here:

- **Rule 4 (three-layer testing)**: every L2 module names unit + integration + E2E tests (or explains absence). Verified by the architecture-design self-audit's G2.x.3 dim.
- **Rule 7 (resilience must not mask signals)**: every fallback path emits a metric, a log, and a delivery-blocking flag. Verified by `agent-runtime/observability` cardinality guard tests + the `*_fallback_total` Prometheus metric on each LlmRouter / OutboxPublisher / ActionGuard fallback branch.
- **Rule 11 (contract spine)**: every persistent record has `tenant_id NOT NULL`. Verified by `agent-platform/tenant` RLS assertion trigger + `RlsPolicyCoverageIT`.
- **Rule 12 (capability maturity)**: every capability declares `maturity: L0..L4` in `architecture-status.yaml` + advances only with three-layer test evidence. Verified by `gate/check_architecture_sync.*` + the audit cadence.

## 8. Mapping to the 32-dimension scoring framework

Each component contributes to specific dimensions in the scoring
framework defined in `docs/architecture-meta-reflection-2026-05-08.en.md`.
The engineering plan uses these dimensions as wave acceptance gates.

| Component | Dim contributions |
|---|---|
| Maven + Spring Boot bringup | R1, R2, R6 |
| Postgres + RLS + tenant spine | R8, F2, F3 |
| Spring AI ChatClient | R7 |
| Idempotency filter | F (idempotency double-submit) |
| Temporal | F8, F9 (long-run) |
| Outbox | F (reliability) |
| Eval harness | E3, E4 |
| Helm + HPA | scalability dim |

If a wave does not move the score on at least one dimension, the wave
is reduced or replaced.

## 9. Disposition of pre-refresh L1/L2 documents

The cycle-1..8 design corpus (this file's predecessor + every
`agent-*/ARCHITECTURE.md` and the cross-cutting docs) is NOT deleted.
It is dispositioned via:

- A "v6 design rationale (DEFERRED IN current refresh)" banner at the
  top of every L2 file that the refresh does not retain as authoritative.
- Active vs historical scoping in `docs/governance/active-corpus.yaml`,
  with an explicit `v7_disposition` (legacy field name; means
  "refresh disposition") on each entry: `merged_into:<X>`,
  `renamed_to:<X>`, `deferred_in_v7`, or `deferred_indefinitely`.
- Status ledger marks each pre-refresh capability with a `v6_disposition`
  (legacy field name) of `kept_rewritten`, `merged_into:<X>`,
  `renamed_to:<X>`, or `deferred_in_v7`.

The full mapping is `docs/plans/architecture-systems-engineering-plan.md`.
The W0 deprecation step archives deferred files under
`docs/v6-rationale/`.

## 10. Authoring constraints (kept lean on purpose)

The refresh keeps L0 + L1 + per-module L2 docs, but every L2 follows a
fixed skeleton (see
`docs/plans/architecture-systems-engineering-plan.md` sec-3) and is
short (target 120-200 lines). A new L2 document requires three
justifications:

1. The information cannot live in code, README, or Javadoc.
2. The information has at least one downstream consumer outside the
   team (auditor, customer, regulator).
3. The information will be regression-tested by a gate rule or test.

Without all three, no L2 document. The refresh prunes ~14 of the
cycle-1..8 L2 files for not satisfying this filter; they become design
rationale with banners.

## 11. Companion documents (read these to understand the whole)

The L0 (this file) is the spine. Six companion documents fill in the
detail and are part of the active corpus:

| Document | Role |
|---|---|
| [`docs/plans/engineering-plan-W0-W4.md`](docs/plans/engineering-plan-W0-W4.md) | Wave plan; the only doc that schedules work and defines acceptance |
| [`docs/plans/architecture-systems-engineering-plan.md`](docs/plans/architecture-systems-engineering-plan.md) | Doc-set drill-down; which L1/L2 docs survive the refresh and which are deferred |
| [`docs/architecture-meta-reflection-2026-05-08.en.md`](docs/architecture-meta-reflection-2026-05-08.en.md) | Root-cause analysis of cycle-1..8 + the 32-dimension scoring framework |
| [`docs/architecture-design-self-audit.md`](docs/architecture-design-self-audit.md) | 240-dim audit rubric + Round-N scoring; cadence rule |
| [`docs/governance/active-corpus.yaml`](docs/governance/active-corpus.yaml) | Active vs. deferred document registry; gate scope source |
| [`docs/governance/architecture-status.yaml`](docs/governance/architecture-status.yaml) | Capability + finding ledger; maturity + evidence_state per capability |

Cross-cutting policies live as L1-equivalent documents under
`docs/cross-cutting/` (created in Round 2 of the architecture-design
self-audit; see the audit doc for status):

| Document | Role |
|---|---|
| `docs/cross-cutting/posture-model.md` | dev/research/prod posture semantics |
| `docs/cross-cutting/security-control-matrix.md` | Per-control owner / posture / test |
| `docs/cross-cutting/trust-boundary-diagram.md` | Tenant + ActionGuard trust boundaries |
| `docs/cross-cutting/secrets-lifecycle.md` | Vault path scheme + rotation cadence |
| `docs/cross-cutting/supply-chain-controls.md` | Image digest pin + SBOM |
| `docs/cross-cutting/observability-policy.md` | Cardinality budget + tenant-id label policy |

## 12. Closing note

This document plus `docs/plans/engineering-plan-W0-W4.md` and the
self-audit document together constitute the architecture spine. They
are intentionally smaller than the cycle-1..8 corpus. The next document
the reader should open is the engineering plan; the second is the
self-audit rubric; the third is the meta-reflection.

The design's correctness is no longer measured by reviewer agreement on
prose. It is measured by:

1. The **32-dimension scoring framework**
   (`docs/architecture-meta-reflection-2026-05-08.en.md`) -- "does the
   project actually exist and work?" -- which the engineering plan
   moves wave-by-wave.
2. The **240-dimension architecture-design self-audit rubric**
   (`docs/architecture-design-self-audit.md`) -- "is the design itself
   complete and consistent?" -- which is re-scored every commit that
   touches the active corpus.

When both reach their respective targets (R + F + G dims close to 100%
on the scoring framework; design-time cap on the self-audit), the
project is considered shipped on its v6 line.
