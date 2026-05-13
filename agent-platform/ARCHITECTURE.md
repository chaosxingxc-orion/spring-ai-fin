# agent-platform -- L1 architecture (2026-05-13 post-seventh third-pass refresh)

> Owner: platform | Wave: W0..W3 | Maturity: W0
> Last refreshed: 2026-05-13 (post-seventh third-pass)

## 1. Purpose

`agent-platform` is the **northbound module**. It accepts HTTP requests,
binds them to a tenant, validates idempotency keys, and forwards to
`agent-runtime` for cognitive work. It is stateless across replicas.

**It is not** the cognitive runtime. The platform does not call LLMs,
does not run tool-calling loops, and does not own run lifecycle. Those
belong to `agent-runtime`.

## 2. Shipped components

### web -- HTTP front door (W0)

`HealthController` serves `GET /v1/health` → 200 + JSON body. This is
the only route live in W0. `/v3/api-docs` is exposed at W0 for contract
verification (gate: `OpenApiContractIT`). Swagger UI (HTML) is blocked
until W1. Virtual-thread dispatcher enabled via
`spring.threads.virtual.enabled=true`.

### tenant -- Per-request tenant binding (W0)

`TenantContextFilter` reads the `X-Tenant-Id` header (UUID shape),
builds a `TenantContext`, stores it in `TenantContextHolder` (request-
scoped ThreadLocal), and propagates `tenant_id` into the Logback MDC
for log correlation. No JWT claim is read at W0; no Postgres GUC is
set.

W1 will add JWT `tenant_id` claim cross-check against the existing
`X-Tenant-Id` header value (per ADR-0040); `X-Tenant-Id` remains
required at W1. W2 will add `SET LOCAL app.tenant_id` GUC and enable
RLS policies on tenant tables. See ADR-0027, ADR-0040, ADR-0023.

### idempotency -- Header validation filter (W0)

`IdempotencyHeaderFilter` intercepts POST, PUT, and PATCH requests. It
validates the presence and UUID shape of the `Idempotency-Key` header.
Missing key returns 400 in research/prod (dev: warning + continue). The
filter does **not** deduplicate, cache responses, or interact with
`IdempotencyStore` at W0.

W1 will wire `IdempotencyStore` with `(tenant_id, Idempotency-Key)`
claim/replay semantics backed by Postgres; a concurrent duplicate will
return 409 at W1. See ADR-0027.

## 3. OSS dependencies

Dependency versions are managed by the parent POM (`pom.xml`) and the
`spring-ai-ascend-dependencies` BoM. Module architecture files do not
duplicate version pins — consult `pom.xml` properties for canonical
values.

| Dependency | Role |
|---|---|
| Spring Boot (see parent POM) | HTTP server, lifecycle, actuator |
| Spring Web (MVC) | Controllers + filters |
| Spring Security | Filter chain ordering |
| HikariCP | DB pool (W1 when JDBC wired) |
| Flyway | Schema migrations (tenant tables land W2) |
| Hibernate Validator | `@Valid` on DTOs |
| Jackson | JSON serialization |
| Micrometer + Prometheus | Metrics (`springai_ascend_*` prefix) |

## 4. Public contract

- HTTP: REST, JSON. Versioned URL prefix `/v1/`.
- Auth: Bearer JWT, RS256, JWKS URL configured at boot (W1).
- Idempotency: `Idempotency-Key` header on POST/PUT/PATCH (W0: UUID validation; W1: dedup).
- Tenant: `X-Tenant-Id` header required at W0 and W1; W1 adds JWT `tenant_id` claim cross-check (ADR-0040).

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Missing `X-Tenant-Id` | warn + DEV_DEFAULT | reject 400 | reject 400 |
| Weak JWT alg (HS256) | accept w/ warning (W1) | reject (W1) | reject (W1) |
| `Idempotency-Key` missing on POST/PUT/PATCH | accept w/ warning | reject 400 | reject 400 |

## 6. Tests

W0 shipped tests (all green; `HealthEndpointIT` and `OpenApiContractIT` use Testcontainers via `@Testcontainers(disabledWithoutDocker = true)`; remaining tests are pure JUnit):

| Test | Layer | Asserts |
|---|---|---|
| `HealthEndpointIT` | Integration | `/v1/health` 200 + body |
| `TenantContextFilterIT` | Integration | UUID binding, dev-default, 400 on missing in research |
| `IdempotencyHeaderFilterIT` | Integration | UUID validation, 400 on missing, header passthrough |
| `PostureBindingIT` | Integration | `APP_POSTURE` env-var bridge wired |
| `OpenApiContractIT` | Integration | `/v3/api-docs` snapshot matches pinned `openapi-v1.yaml` |
| `ApiCompatibilityTest` | ArchUnit | SPI purity + dependency direction |

W2-deferred tests (currently `@Disabled` — scaffold only):

- `TenantIsolationIT` — enables when V2__tenant_rls.sql lands (W2).
- `GucEmptyAtTxStartIT` — enables when JDBC + GUC wired (W2).
- `RlsPolicyCoverageIT` — enables when RLS policies active (W2).

## 7. Out of scope

- LLM calls, tool calling, run lifecycle: `agent-runtime/`.
- JWT validation, Spring Security auth filters: W1.
- `SET LOCAL` GUC, Postgres RLS policies: W2.
- Spring Cloud Gateway, per-tenant config overrides: W2–W3.

## 8. Wave landing

- W0: `web/` (HealthController), `bootstrap/` (PlatformApplication + AppPosture), actuator,
  `tenant/` (TenantContextFilter — header binding + MDC), `idempotency/` (IdempotencyHeaderFilter
  — UUID validation on POST/PUT/PATCH), `probe/` (OssApiProbe).
- W1: `auth/` (JWTAuthFilter + JWKS), tenant JWT claim extraction, idempotency dedup store
  (Postgres-backed), posture-aware JWT validation.
- W2: `config/`, tenant GUC + RLS, Spring Cloud Gateway routing, OTel auto-instrumentation.
- W3+: per-tenant config overrides via Spring Cloud Config.

## 9. Risks

- **Virtual-thread + JDBC pinning** (W1 trigger): HikariCP 5.x mitigates pinning
  once JDBC is wired at W1. No JDBC calls at W0; risk not active.
- **Spring Security 6 filter ordering**: covered by integration tests;
  one shared `SecurityFilterChain` per profile.
- **JWT replay attacks** (W1 trigger): idempotency-key dedup + JWKS-cache TTL
  tuning deferred alongside JWT auth.
- **Tenant-id confusion in multi-step requests**: every async handoff sources
  tenant from `RunContext.tenantId()` (Rule 21), not `TenantContextHolder`.
