# agent-platform -- L1 architecture (2026-05-08 refresh)

> Owner: platform | Wave: W0..W3 | Maturity: L1 | Reads: JWT + tenant
> overrides | Writes: tenant_workspace, idempotency_dedup, audit_log
> Last refreshed: 2026-05-10

## 1. Purpose

`agent-platform` is the **northbound module**. It accepts authenticated
HTTP requests, binds them to a tenant, deduplicates idempotency keys,
rate-limits per tenant, and forwards to `agent-runtime` for cognitive
work. It is stateless across replicas; all state lives in Postgres
(via `agent-runtime` repositories) or Valkey (cache).

**It is not** the cognitive runtime. The platform does not call LLMs,
does not run tool-calling loops, and does not own run lifecycle. Those
belong to `agent-runtime`.

## 2. OSS dependencies

| Dependency | Version | Role |
|---|---|---|
| Spring Boot | 3.5.x | HTTP server, lifecycle, actuator |
| Spring Web (MVC) | (BOM) | Controllers + filters |
| Spring Security | 6.x | JWT validation + filter chain |
| Spring Cloud Gateway | 4.x | Edge routing (W2; not W0) |
| Resilience4j | 2.x | Rate limit + circuit breaker |
| HikariCP | (BOM) | DB pool with virtual-thread-safe semantics |
| Flyway | 10.x | Schema migrations (platform-owned tables) |
| Hibernate Validator | (BOM) | `@Valid` on DTOs |
| Jackson | (BOM) | JSON serialization |
| springdoc-openapi | 2.x | OpenAPI generation |
| Micrometer + Prometheus | (BOM) | Metrics |
| OpenTelemetry Java agent | 2.x | Auto-instrumented traces (W1) |

## 3. Submodules (L2)

| L2 path | Purpose | Wave |
|---|---|---|
| `web/` | Controllers, exception handlers, OpenAPI annotations | W0 |
| `auth/` | Spring Security filter chain + Keycloak integration | W1 |
| `tenant/` | TenantBinder filter, RLS GUC binding, RLS interceptor | W1 |
| `idempotency/` | `Idempotency-Key` filter + Postgres dedup | W1 |
| `bootstrap/` | Spring Boot main class + PostureBootGuard | W0 |
| `config/` | Spring Cloud Config integration + tenant overrides | W2 |
| `contracts/` | OpenAPI surface (versioned) + DTO records | W0 |

Each L2 has its own `ARCHITECTURE.md` following the skeleton in `docs/plans/architecture-systems-engineering-plan.md` sec-3.

9 SPI surfaces are published by the `spring-ai-fin-*-starter` modules and frozen by `ApiCompatibilityTest` (ArchUnit 4 rules GREEN). Platform code calls runtime capabilities only through these SPI contracts, never through direct Java imports of `agent-runtime` types.

## 4. Public contract

- HTTP: REST, JSON, OpenAPI 3 published at `/v3/api-docs` (springdoc).
- Versioning: URL prefix `/v1/...`; major version bump for breaking
  changes; the `agent-platform/contracts/` module owns the OpenAPI
  spec.
- Auth: Bearer JWT, RS256, JWKS URL configured at boot.
- Idempotency: `Idempotency-Key` header on POST endpoints.
- Tenant: `tenant_id` claim in JWT, validated against `tenants` table.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Missing `tenant_id` claim | warn | reject 401 | reject 401 |
| Weak JWT alg (HS256) | accept w/ warning | reject | reject |
| `Idempotency-Key` missing on POST | accept | reject 400 | reject 400 |
| Rate limit | off | on | on (lower) |
| OpenAPI exposed publicly | yes | internal only | internal only |

`PostureBootGuard` (W0) refuses to start in `research`/`prod` if
required env / config is missing.

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `HealthEndpointIT` | Integration | `/v1/health` 200 + body |
| `JwtAlgorithmRejectionIT` | Integration (research posture) | HS256 rejected |
| `JwksRotationIT` | Integration | rotated key still validates |
| `TenantIsolationIT` | E2E | Tenant A's writes invisible to B |
| `IdempotencyDoubleSubmitIT` | E2E | Same key -> same row id |
| `RateLimitIT` | Integration | 429 after configured threshold |
| `GucEmptyAtTxStartIT` | Integration | Bypassing TenantBinder fails the trigger |

## 7. Out of scope

- LLM calls, tool calling, run lifecycle: `agent-runtime/`.
- Long-running workflows: `agent-runtime/temporal/`.
- Cross-tenant analytics: future module, not in W0-W4.

## 8. Wave landing

- W0: `web/`, `bootstrap/`, `contracts/`, basic actuator.
- W1: `auth/`, `tenant/`, `idempotency/`, posture-aware defaults.
- W2: `config/`, Spring Cloud Gateway routing, OTel auto-instrumentation.
- W3+: per-tenant config overrides via Spring Cloud Config.

Reference: `docs/plans/engineering-plan-W0-W4.md` sec-2 (W0), sec-3 (W1),
sec-4 (W2).

## 9. Risks

- **Virtual-thread + JDBC pinning**: mitigated by HikariCP 5.x and
  no-synchronized-around-JDBC discipline (CI rule W1).
- **Spring Security 6 filter ordering**: covered by integration tests in
  `auth/`; one shared `SecurityFilterChain` per profile.
- **Keycloak ops complexity**: dev runs single-node; prod uses managed
  identity provider (any OIDC-compliant; Keycloak default).
- **JWT replay attacks**: idempotency-key dedup + JWKS-cache tuned TTL
  + `jti` claim recorded in `idempotency_dedup` for N minutes; covered
  by an integration test in W1.
- **Tenant-id confusion in multi-step requests**: every controller and
  every async handoff re-asserts `TenantContext.current()` (lint rule);
  any code path that builds a downstream request without going through
  `TenantBinder` is rejected.
- **Idempotency-Key abuse (DoS via key explosion)**: per-tenant cap on
  active keys + cleanup job; enforced in `idempotency/`.
- **OpenAPI surface drift between agents and humans**: snapshot test +
  per-PR diff in `agent-platform/contracts/`; breaking change needs
  `/v2/` prefix.
