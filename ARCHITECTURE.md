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

  agent-runtime/                               # Cognitive runtime kernel (SPI contracts)
    src/main/java/ascend/springai/runtime/
      memory/spi/
        GraphMemoryRepository.java             # SPI interface (interface only, W1+)
      probe/
        OssApiProbe.java

  spring-ai-ascend-graphmemory-starter/        # E2 middleware shell (enabled=false, W2)
    src/main/java/ascend/springai/runtime/graphmemory/
      GraphMemoryAutoConfiguration.java
      GraphMemoryProperties.java

  agent-eval/                                  # Eval harness (W4 placeholder)
    pom.xml
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

---

## 5. W0 shipped capabilities

- `GET /v1/health` — liveness probe; JSON `{"status":"UP"}`.
- `TenantContextFilter` — extracts `X-Tenant-Id`, propagates via `TenantContextHolder`.
- `IdempotencyHeaderFilter` — deduplicates requests by `Idempotency-Key` header.
- `IdempotencyStore` — dev-posture in-memory store (non-durable; replaced in W1).
- `GraphMemoryRepository` SPI — interface only; no implementation shipped.
- `OssApiProbeTest` — compile-time probe verifying Spring AI + Spring Boot API surface.
- `ApiCompatibilityTest` — ArchUnit rules enforcing SPI purity and dependency direction.

---

## 6. Roadmap pointers

- Deferred capabilities and re-introduction triggers: `docs/CLAUDE-deferred.md`
- Current per-capability state and maturity levels: `docs/STATE.md` (created in C27)
- Design rationale for pre-C26 decisions: `docs/v6-rationale/`
- Wave delivery plan (W0–W4): `docs/plans/engineering-plan-W0-W4.md`
- OSS BoM with per-dep verification level: `docs/cross-cutting/oss-bill-of-materials.md`
