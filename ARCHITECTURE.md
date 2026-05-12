# spring-ai-ascend Platform — Architecture

> Last updated: 2026-05-12 (C26 Occam's Razor cleanup).

## 1. System boundary

spring-ai-ascend is a self-hostable agent runtime for financial-services operators.
It accepts authenticated tenant HTTP requests, drives LLMs through a tool-calling
loop with audit-grade evidence, and persists durable side effects through an
idempotent outbox. Built on Spring Boot 4.0.5 + Java 21.

**Not in scope:** admin UI, LangChain4j dispatch, Python sidecars, multi-region
replication, on-device models. See `docs/CLAUDE-deferred.md` for deferred items.

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
        IdempotencyHeaderFilter.java           # Idempotency-Key dedup
        IdempotencyStore.java                  # dev-posture in-memory store
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
        RunStatus.java                         # PENDING/RUNNING/SUSPENDED/SUCCEEDED/FAILED/CANCELLED
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

  spring-ai-ascend-graphmemory-starter/        # E2 middleware shell (enabled=false, W2)
    src/main/java/ascend/springai/runtime/graphmemory/
      GraphMemoryAutoConfiguration.java
      GraphMemoryProperties.java

```

Module dependency direction (enforced by `ApiCompatibilityTest` ArchUnit rules):

```
agent-platform  ──SPI-only──►  agent-runtime  ──►  [Postgres / LLMs / sidecars]
                                     ▲
                     spring-ai-ascend-graphmemory-starter
                     (provides SPI impl when enabled=true + URL set)
```

`agent-platform` must not import `agent-runtime` Java types directly.
SPI packages (`ascend.springai.runtime.*.spi.*`) import only `java.*`.

---

## 3. OSS dependencies

| Component | Version | Role |
|---|---|---|
| Spring Boot | 4.0.5 | HTTP server, DI container, actuator |
| Spring AI | 2.0.0-M5 | ChatClient, VectorStore, MCP adapters |
| Spring Security | 6.x | JWT filter chain, SecurityFilterChain |
| Spring Cloud Gateway | 2024.x | Edge routing (W1) |
| MCP Java SDK | 2.0.0-M2 | Tool protocol (W3) |
| Java (OpenJDK) | 21 | Virtual threads (Project Loom) |
| PostgreSQL | 16 | Relational + vector (pgvector) + outbox |
| Flyway | 10.x | Schema migrations |
| HikariCP | 5.x | Connection pool |
| Temporal Java SDK | 1.35.0 | Durable workflow engine (W4) |
| Resilience4j | 2.x | Circuit breaker, rate limiter |
| Caffeine | 3.x | In-process L0 cache |
| Apache Tika | 2.x | Document parsing (W3) |
| Micrometer + Prometheus | latest | Metrics (`springai_ascend_*` prefix) |
| Testcontainers | 1.20.x | Integration test containers |
| Maven | 3.9 | Build, multi-module |

---

## 4. Architecture constraints

1. **Dependency direction**: `agent-platform` → SPI interfaces only → `agent-runtime`.
   No reverse imports. Enforced by `ApiCompatibilityTest`.

2. **Posture model**: `APP_POSTURE={dev|research|prod}`. Read once at boot.
   `dev` is permissive (in-memory stores, relaxed validation).
   `research` and `prod` are fail-closed (Vault secrets, durable stores, strict JWT).

3. **Tenant isolation**: every HTTP request must carry `X-Tenant-Id`.
   `TenantContextFilter` binds it to `TenantContextHolder`. Every persistent
   record carries `tenant_id NOT NULL`. RLS policies enforce row visibility.
   Connection-level GUC `app.tenant_id` is set via `SET LOCAL` inside each
   transaction and auto-discarded on commit.

4. **Idempotency**: callers send `Idempotency-Key` header. `IdempotencyHeaderFilter`
   deduplicates at the edge. `IdempotencyStore` (dev: in-memory; W1: Postgres dedup
   table) prevents double side effects.

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
   (`SuspendSignal`) to delegate to a child run. The `Orchestrator` owns the
   catch/checkpoint/dispatch/resume loop; executors do not persist or wait.
   `Run.mode` discriminates `GRAPH` vs `AGENT_LOOP`; `Run.parentRunId` + `Run.parentNodeKey`
   encode the nesting chain. Durability tiers: in-memory (dev/W0) → Postgres
   checkpoint (W2) → Temporal child workflow (W4) — same SPI surface across all tiers.

---

## 5. W0 shipped capabilities

- `GET /v1/health` — liveness probe; JSON `{"status":"UP"}`.
- `TenantContextFilter` — extracts `X-Tenant-Id`, propagates via `TenantContextHolder`.
- `IdempotencyHeaderFilter` — deduplicates requests by `Idempotency-Key` header.
- `IdempotencyStore` — dev-posture stub (no-op + WARNING log); research/prod throws `IllegalStateException`; replaced in W1.
- `GraphMemoryRepository` SPI — interface only; no implementation shipped.
- `ResilienceContract` + `YamlResilienceContract` — per-operation resilience routing (operationId → policy triple).
- `Run` entity + `RunRepository` SPI — contract-spine entity (Rule 11 target); `mode` field (`GRAPH`|`AGENT_LOOP`) discriminates executor type; `parentRunId` + `parentNodeKey` + `SUSPENDED` status support interrupt-driven nesting.
- `IdempotencyRecord` entity — contract-spine entity with mandatory `tenantId` (Rule 11 target).
- `OssApiProbeTest` — compile-time probe verifying Spring AI + Spring Boot API surface.
- `ApiCompatibilityTest` — ArchUnit rules enforcing SPI purity and dependency direction.
- `Orchestrator` SPI + `GraphExecutor` + `AgentLoopExecutor` + `SuspendSignal` + `Checkpointer` — dual-mode runtime SPIs (§4 constraint #9).
- `InMemoryCheckpointer` — dev-posture in-memory checkpoint store (W2: Postgres-backed).
- `SyncOrchestrator` + `SequentialGraphExecutor` + `IterativeAgentLoopExecutor` + `InMemoryRunRegistry` — reference executors proving 3-level bidirectional graph↔agent-loop nesting via `SuspendSignal` interrupt. Dev-posture only; not on the production code path.

---

## 6. Roadmap pointers

- Deferred capabilities and re-introduction triggers: `docs/CLAUDE-deferred.md`
- Current per-capability state and maturity levels: `docs/STATE.md` (created in C27)
- Design rationale for pre-C26 decisions: `docs/v6-rationale/`
- Wave delivery plan (W0–W4): `docs/plans/engineering-plan-W0-W4.md`
- OSS BoM with per-dep verification level: `docs/cross-cutting/oss-bill-of-materials.md`
