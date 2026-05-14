# agent-platform -- L1 architecture (2026-05-14 L1-modular-russell refresh)

> Owner: platform | Wave: W0..W3 | Shipped through: L1 (W1)
> Last refreshed: 2026-05-14 (L1 Phase J + K)
> Governing rule: Rule 28 — Code-as-Contract (ADR-0059). Every constraint
> below maps to at least one row in `docs/governance/enforcers.yaml`.

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

### idempotency -- Durable claim/replay (L1, ADR-0057)

`IdempotencyHeaderFilter` intercepts POST/PUT/PATCH requests, validates
the `Idempotency-Key` header as UUID, wraps the request in
`ContentCachingRequestWrapper`, hashes `method:path:body` (SHA-256 →
base64url), and calls `IdempotencyStore.claimOrFind(tenantId, key,
requestHash)`. Collisions return 409 `idempotency_conflict` (same hash)
or 409 `idempotency_body_drift` (different hash) via
`ErrorEnvelopeWriter`.

`IdempotencyStore` is an SPI interface with two impls wired by
`IdempotencyStoreAutoConfiguration`:

- `JdbcIdempotencyStore` (default when DataSource present) — INSERT …
  ON CONFLICT (tenant_id, idempotency_key) DO NOTHING; SELECT on
  collision. Flyway `V2__idempotency_dedup.sql` adds the table with a
  PRIMARY KEY composite (schema-layer enforcer E13) and a CHECK
  constraint on `status` (CLAIMED|COMPLETED|FAILED).
- `InMemoryIdempotencyStore` — `ConcurrentHashMap`. Registered ONLY
  when `app.posture=dev` AND `app.idempotency.allow-in-memory=true`.

`IdempotencyProperties` (`@ConfigurationProperties("app.idempotency")`)
exposes `ttl` (default PT24H) and `allowInMemory` (default false).

Status transitions (CLAIMED → COMPLETED/FAILED) and response replay are
W2 work; L1 returns 409 for any duplicate and recovers via
`expires_at` TTL.

Enforcer rows: E12 (durability), E13 (schema), E14 (body-drift),
E22 (allow-in-memory matrix).

### auth -- JWT validation (L1, ADR-0056)

`AuthProperties` (`@ConfigurationProperties("app.auth")`) holds issuer,
jwks-uri, audience, clock-skew (default PT60S), jwks-cache-ttl
(default PT5M), and dev-local-mode (default false). Cross-field
`@AssertTrue` rejects `dev-local-mode=true` together with a configured
`jwks-uri`.

`JwtDecoderConfig` wires exactly one `JwtDecoder` (Rule 6): JWKS-backed
when `app.auth.issuer` is set, dev-local-mode-backed when the flag is
set and posture is dev (`PostureBootGuard` rejects the combo
elsewhere). Validator chain: RS256 signature + `JwtTimestampValidator`
+ issuer + audience, wrapped in `CountingValidator` that emits
`springai_ascend_auth_failure_total{reason,source}`.

`WebSecurityConfig` is stateless, permits `/v1/health`,
`/actuator/{health,info,prometheus}`, `/v3/api-docs(/**)`, and requires
authentication everywhere else when a `JwtDecoder` bean is present.
Falls back to `denyAll` when no decoder is wired (preserves W0
zero-config dev behaviour; `PostureBootGuard` enforces fail-closed in
research/prod).

Enforcer rows: E9 (validation matrix), E11 (dev-local-mode posture
guard).

### tenant -- Header validation + JWT claim cross-check (L1, ADR-0056 §3)

`TenantContextFilter` (W0, unchanged) reads `X-Tenant-Id`, validates
UUID shape, populates `TenantContextHolder` (request-scoped
ThreadLocal) and Logback MDC.

`JwtTenantClaimCrossCheck` (L1, order 15 — after Spring Security's
`BearerTokenAuthenticationFilter`, before `TenantContextFilter` at 20)
compares the JWT `tenant_id` claim with the `X-Tenant-Id` header.
Mismatch → 403 `tenant_mismatch`; claim missing with header present →
403 `jwt_missing_tenant_claim`. Counters:
`springai_ascend_tenant_mismatch_total`,
`springai_ascend_jwt_missing_tenant_claim_total`.

Rule 21 generalised at L1 (ADR-0055): runtime main sources MUST NOT
import any class under `ascend.springai.platform..`
(`RuntimeMustNotDependOnPlatformTest`, enforcer E2).

Enforcer rows: E10 (cross-check), E2 (purity).

### posture -- Boot-time fail-closed gate (L1, ADR-0058)

`PostureBootGuard` listens on `ApplicationReadyEvent` and aborts startup
in research/prod when any of the required-config matrix entries is
missing: `AuthProperties.hasJwksConfig()`, DataSource bean,
JdbcIdempotencyStore bean, MeterRegistry bean; OR if
`InMemoryIdempotencyStore` is registered; OR if
`app.auth.dev-local-mode=true` outside posture=dev. Failures emit
`springai_ascend_posture_boot_failure_total{posture,reason}` then
throw `IllegalStateException` from the listener (which propagates and
aborts the application context).

`@RequiredConfig` annotation lands as documentation for the future
scanner; current matrix is encoded directly in the guard class.

Enforcer rows: E11, E21, E22.

### web/runs -- W1 HTTP run API (L1, plan §6)

`RunController` under `/v1/runs`:

- `POST /v1/runs` (consumes JSON `CreateRunRequest`) → 201 with status
  `PENDING` (initial state pinned by `RunStatusEnumTest`, enforcer E5;
  no `CREATED` state exists).
- `GET /v1/runs/{runId}` → 200 with current state; 404 `not_found` for
  unknown runs OR cross-tenant access (architect guidance §9.4
  "tenant-scope-as-not-found").
- `POST /v1/runs/{runId}/cancel` → 200 with `CANCELLED`; idempotent
  for already-cancelled runs; 409 `illegal_state_transition` for
  `SUCCEEDED`/`FAILED`/`EXPIRED` (enforcer E24). Cancellation is POST,
  never DELETE (enforcer E6).

`RunHttpExceptionMapper` (`@ControllerAdvice`) maps
`MethodArgumentNotValidException` → 422 `invalid_run_spec`,
`HttpMessageNotReadableException` → 400 `invalid_request`,
`IllegalArgumentException` → 400, uncaught `RuntimeException` →
500 `internal_error`. Every response uses `ErrorEnvelope`:
`{error:{code,message,details}}` — stable shape, enforcer E8.

`RunControllerAutoConfiguration` wires `InMemoryRunRegistry` as the
`RunRepository` when `app.posture=dev` and no other repository bean
exists. Research/prod require a durable repository (W2); until then
`PostureBootGuard` aborts startup.

Enforcer rows: E5, E6, E7, E8, E24.

### observability -- Tenant tagging, forbidden-tag scrub, Telemetry Vertical filter (L1 + L1.x)

`TenantTagMeterFilter` (L1) registers a `MeterFilter` that strips
high-cardinality tag keys (`run_id`, `idempotency_key`, `jwt_sub`,
`body`) from every `springai_ascend_*` metric at registration time.
Non-namespace metrics (jvm.*, etc.) are left untouched.

`TraceExtractFilter` (L1.x — Telemetry Vertical, ADR-0061 / §4 #55)
runs at order 10 (before `JwtTenantClaimCrossCheck` at 15 and
`TenantContextFilter` at 20). It parses the W3C version-00
`traceparent` header on every inbound request; if absent or malformed
it originates a fresh `trace_id` (32-char hex) + `span_id` (16-char
hex). MDC is populated with `trace_id`, `span_id`, `parent_span_id`
during the request scope (cleared in `finally`). On every outbound
response the filter emits `traceresponse: 00-<trace_id>-<span_id>-01`
so the W3 client SDK (ADR-0063) can correlate. Counters:
`springai_ascend_trace_originated_total{posture, source=client|server}`,
`springai_ascend_traceparent_invalid_total{posture}`. No OpenTelemetry
SDK dependency at L1.x — pure-Java parsing and id minting.

Filter chain order (L1.x):

1. `TraceExtractFilter` (order 10) — Telemetry Vertical (NEW).
2. `JwtTenantClaimCrossCheck` (order 15) — JWT vs `X-Tenant-Id` cross-check.
3. `TenantContextFilter` (order 20) — UUID binding + MDC tenant_id.
4. `IdempotencyHeaderFilter` (default Spring Security ordering after 20)
   — `Idempotency-Key` validation + claim/replay.

`run_id` is populated in MDC by `RunController` at the spot where a
Run is materialised (not in a filter — the run is created inside the
controller, after the filter chain). This is a deliberate L1.x design
choice; W2 may move it to a request-scoped bean if a second
Run-materialising controller appears.

Enforcer rows: E18 (metric prefix), E19 (forbidden tag scrubber),
E38 (Telemetry Vertical first-class), E40 (traceparent at edge),
E41 (MDC field-shape).

### architecture -- Layering enforcers (L1, ADR-0055)

ArchUnit tests under `src/test/java/.../architecture/`:

- `HttpEdgeMustNotImportMemorySpiTest` (E4) — HTTP edge cannot reach
  the runtime memory SPI.
- `PlatformImportsOnlyRuntimePublicApiTest` (E34, Phase K) — platform
  may only import runtime's public surface (`runs.*`,
  `orchestration.spi.*`, `posture.*`, plus `InMemoryRunRegistry`); other
  runtime packages stay internal.
- `RepositoryPaginationTest` (E16) — repository methods returning
  Collection/Page must declare Pageable. Armed for W1 persistence
  growth; vacuous at L1.
- `NoStringConcatSqlTest` (E17) — no String + SQL concatenation under
  `persistence/` or `idempotency/jdbc/`.
- `MetricNamingTest` (E18) — every Micrometer builder("…") starts with
  `springai_ascend_`.
- `RunStatusEnumTest` (E5) — pins the seven-status enum; no CREATED.
- `ErrorEnvelopeContractTest` (E8) — JSON shape exactly
  `{error:{code,message,details}}`.

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

### L1 shipped tests (all green; Testcontainers ITs guarded by `@Testcontainers(disabledWithoutDocker = true)`; remaining tests are pure JUnit)

| Test | Layer | Asserts |
|---|---|---|
| `HealthEndpointIT` | Integration | `/v1/health` 200 + body |
| `TenantContextFilterIT` | Integration | UUID binding, dev-default, 400 on missing in research |
| `IdempotencyHeaderFilterIT` | Integration | UUID validation, 400 on missing, header passthrough |
| `PostureBindingIT` | Integration | `APP_POSTURE` env-var bridge wired |
| `OpenApiContractIT` | Integration | live `/v3/api-docs` agrees with pinned `openapi-v1.yaml` for every `/v1/**` path (Phase L stiffening — no undocumented live operations) |
| `AuthPropertiesValidationTest` | Unit | `app.auth.*` binding + cross-field consistency check (Phase C) |
| `JwtValidationIT` | Integration | real Nimbus decoder + RSA keypair, every failure row of ADR-0056 §4 (Phase C, enforcer E9) |
| `JwtDevLocalModeGuardIT` | Integration | `dev-local-mode=true` is fatal outside `app.posture=dev` (Phase F, enforcer E11) |
| `JwtTenantClaimCrossCheckTest` | Unit | claim==header / claim!=header / missing-claim / no-auth branches (Phase D, enforcer E10) |
| `IdempotencyStoreTest` | Unit | In-memory dev-posture store contract (Phase E) |
| `IdempotencyStorePostgresIT` | Integration | JDBC `INSERT … ON CONFLICT` + body-drift returns existing hash (Phase E, enforcer E14) |
| `IdempotencyDurabilityIT` | Integration | row persists across simulated downstream failure (Phase K, enforcer E12) |
| `InMemoryIdempotencyAllowFlagIT` | Integration | in-memory store posture-gated (Phase E, enforcer E22) |
| `PostureBootGuardIT` | Integration | research/prod fail-closed on missing config (Phase F, enforcer E21) |
| `RunHttpContractIT` | Integration | unauthenticated 401/403 + Phase L authenticated matrix (`createReturnsPending`, `tenantMismatchReturns403`, `cancelTerminalReturns409`, `duplicateIdempotencyKeyReturns409`, `cancel_route_is_post_not_delete`); enforcers E5/E6/E7/E10/E24 |
| `RunStatusEnumTest` | Unit | enum pinned at 7 values; no `CREATED` (Phase G, enforcer E5) |
| `ErrorEnvelopeContractTest` | Unit | every 4xx/5xx response has `{error:{code,message,details}}` shape (Phase D, enforcer E8) |
| `TenantTagMeterFilterTest` | Unit | forbidden high-cardinality tags stripped from `springai_ascend_*` (Phase H, enforcer E19) |
| `PlatformImportsOnlyRuntimePublicApiTest` | ArchUnit | platform main sources may only import the runtime public-API packages (Phase K, enforcer E34) |
| `RuntimeMustNotDependOnPlatformTest` | ArchUnit | runtime main sources MUST NOT import any platform package (Phase B, enforcer E2) |
| `HttpEdgeMustNotImportMemorySpiTest` | ArchUnit | HTTP edge cannot reach the memory SPI (Phase B, enforcer E4) |
| `ApiCompatibilityTest` | ArchUnit | module-dep direction + SPI purity (W0 baseline) |
| `JwtTestFixture` | Test fixture | shared RSA keypair + JWT mint helper for L1 authenticated tests (Phase L, enforcer E37) |

W2-deferred tests (currently `@Disabled` — scaffold only):

- `TenantIsolationIT` — enables when V2__tenant_rls.sql lands (W2).
- `GucEmptyAtTxStartIT` — enables when JDBC + GUC wired (W2).
- `RlsPolicyCoverageIT` — enables when RLS policies active (W2).

## 7. Out of scope at L1

- LLM calls, tool calling, run lifecycle execution: `agent-runtime/` (Run state-machine sources, executors).
- `SET LOCAL` GUC, Postgres RLS policies: W2.
- Spring Cloud Gateway, per-tenant config overrides: W2–W3.
- Three-track `RunDispatcher`, streaming `Flux<RunEvent>` handoff: W2.

## 8. Wave landing

- W0 (delivered 2026-05-13): `web/` (HealthController), `bootstrap/` (PlatformApplication + AppPosture), actuator,
  `tenant/` (TenantContextFilter — header binding + MDC), `idempotency/` (IdempotencyHeaderFilter
  — UUID validation on POST/PUT/PATCH), `probe/` (OssApiProbe).
- W1 / L1 (delivered 2026-05-14): `auth/` (AuthProperties + JwtDecoderConfig — JWKS-backed + dev-local-mode RSA fixture), `tenant/JwtTenantClaimCrossCheck` (cross-check against `X-Tenant-Id` header per ADR-0056 §3), `idempotency/` claim/replay store (`JdbcIdempotencyStore` + `InMemoryIdempotencyStore` + `IdempotencyHeaderFilter` body-hash claim/replay per ADR-0057), `posture/PostureBootGuard` (fail-closed startup in research/prod per ADR-0058), `web/runs/` (RunController + CreateRunRequest + RunResponse + RunHttpExceptionMapper for `POST /v1/runs`, `GET /v1/runs/{runId}`, `POST /v1/runs/{runId}/cancel`), `observability/TenantTagMeterFilter` (strips forbidden high-cardinality tags from `springai_ascend_*` metrics).
- W2: `config/`, tenant GUC + RLS, Spring Cloud Gateway routing, OTel auto-instrumentation, durable `RunRepository` (Postgres-backed beyond the L1 in-memory dev-posture wiring), streaming run event handoff.
- W3+: per-tenant config overrides via Spring Cloud Config; PowerShell mirror of Rule 28a–28j sub-checks (deferred at L1 per ADR-0060 §3); LLM gateway resilience routing (W2 trigger).

## 9. Risks

- **Virtual-thread + JDBC pinning** (active at L1): HikariCP wired at L1 alongside the durable `JdbcIdempotencyStore`. Watch for unexpected `parkNanos`/`Unsafe.park` pinning under load; monitor `springai_ascend_*` pool metrics (`hikaricp.connections.pending`, `hikaricp.connections.usage`).
- **Spring Security 6/Boot 4 filter ordering**: filters are registered with explicit `FilterRegistrationBean` order — `JwtTenantClaimCrossCheck` at 15, `TenantContextFilter` at 20, `IdempotencyHeaderFilter` after that. `RunHttpContractIT` proves the full chain end-to-end.
- **Idempotency claim→completion window** (W2 trigger): if an orchestrator crashes after `claimOrFind` but before marking COMPLETED, the row stays CLAIMED until expires_at. Acceptable at L1 (replays return the original 201); W2 will add an orchestrator-side completion hook per ADR-0057 §4.
- **Tenant-id confusion in multi-step requests**: every async handoff sources tenant from `RunContext.tenantId()` (Rule 21, enforced by `TenantPropagationPurityTest` ArchUnit + `RuntimeMustNotDependOnPlatformTest`), not from `TenantContextHolder`.
