# agent-platform -- L1 architecture (2026-05-08 refresh)

> Owner: platform | Wave: W0..W3 | Maturity: L1 | Reads: JWT + tenant
> overrides | Writes: tenant_workspace, idempotency_dedup, audit_log
> Last refreshed: 2026-05-12

## 1. Purpose

`agent-platform` is the **northbound module**. It accepts authenticated
HTTP requests, binds them to a tenant, deduplicates idempotency keys,
and forwards to `agent-runtime` for cognitive work. It is stateless
across replicas; all state lives in Postgres (via `agent-runtime`
repositories) or Valkey (cache).

**It is not** the cognitive runtime. The platform does not call LLMs,
does not run tool-calling loops, and does not own run lifecycle. Those
belong to `agent-runtime`.

## 2. Shipped components

### web -- HTTP front door (W0)

`HealthController` serves `GET /v1/health` → 200 + JSON body. This is
the only route live in W0. Swagger UI and `/v3/api-docs` are not
exposed until W1. Virtual-thread dispatcher enabled via
`spring.threads.virtual.enabled=true`.

### tenant -- Per-request tenant binding (W1)

`TenantContextFilter` reads the `tenant_id` JWT claim, builds a
`TenantContext`, and propagates the tenant into Postgres as a
transaction-scoped GUC (`SET LOCAL app.tenant_id = :id`). Postgres RLS
policies use this GUC to filter rows. Binding is per-transaction, not
per-connection; HikariCP pool is multi-tenant.

### idempotency -- Deduplication filter (W1)

`IdempotencyHeaderFilter` intercepts every POST/PUT/PATCH. Same
`(tenant_id, Idempotency-Key)` pair returns the cached response; a
concurrent duplicate returns 409; missing key returns 400 in
research/prod. `IdempotencyStore` persists dedup rows in
`idempotency_dedup` with a 24h TTL.

## 3. OSS dependencies

| Dependency | Version | Role |
|---|---|---|
| Spring Boot | 3.5.x | HTTP server, lifecycle, actuator |
| Spring Web (MVC) | (BOM) | Controllers + filters |
| Spring Security | 6.x | JWT validation + filter chain |
| HikariCP | (BOM) | DB pool with virtual-thread-safe semantics |
| Flyway | 10.x | Schema migrations (platform-owned tables) |
| Hibernate Validator | (BOM) | `@Valid` on DTOs |
| Jackson | (BOM) | JSON serialization |
| Micrometer + Prometheus | (BOM) | Metrics |

## 4. Public contract

- HTTP: REST, JSON. Versioned URL prefix `/v1/`.
- Auth: Bearer JWT, RS256, JWKS URL configured at boot (W1).
- Idempotency: `Idempotency-Key` header on POST endpoints (W1).
- Tenant: `tenant_id` claim in JWT, validated against `tenants` table (W1).

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Missing `tenant_id` claim | warn | reject 401 | reject 401 |
| Weak JWT alg (HS256) | accept w/ warning | reject | reject |
| `Idempotency-Key` missing on POST | accept | reject 400 | reject 400 |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `HealthEndpointIT` | Integration | `/v1/health` 200 + body |
| `TenantIsolationIT` | E2E | Tenant A's writes invisible to B |
| `IdempotencyDoubleSubmitIT` | E2E | Same key -> same row id |
| `GucEmptyAtTxStartIT` | Integration | Bypassing TenantBinder fails the trigger |

## 7. Out of scope

- LLM calls, tool calling, run lifecycle: `agent-runtime/`.
- Long-running workflows: `agent-runtime/temporal/`.
- Auth filter chain, per-tenant config overrides, Spring Cloud Gateway: W1–W3.

## 8. Wave landing

- W0: `web/` (HealthController), `bootstrap/` (PlatformApplication + AppPosture), actuator.
- W1: `auth/`, `tenant/` (TenantContextFilter), `idempotency/` (IdempotencyHeaderFilter + IdempotencyStore), posture-aware defaults.
- W2: `config/`, Spring Cloud Gateway routing, OTel auto-instrumentation.
- W3+: per-tenant config overrides via Spring Cloud Config.

## 9. Risks

- **Virtual-thread + JDBC pinning**: mitigated by HikariCP 5.x and
  no-synchronized-around-JDBC discipline (CI rule W1).
- **Spring Security 6 filter ordering**: covered by integration tests in
  `auth/`; one shared `SecurityFilterChain` per profile.
- **JWT replay attacks**: idempotency-key dedup + JWKS-cache tuned TTL.
- **Tenant-id confusion in multi-step requests**: every controller and
  every async handoff re-asserts `TenantContext.current()` (lint rule).
