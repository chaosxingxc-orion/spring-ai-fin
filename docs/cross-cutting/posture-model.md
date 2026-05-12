# Posture Model

> Owner: architecture | Wave: W0 | Last updated: 2026-05-13 (sixth + seventh reviewer response)

## The three postures

| Posture | Intent | Defaults |
|---|---|---|
| `dev` | Local development | Permissive: warnings only; in-memory DBs allowed; no rate limits |
| `research` | Production-equivalent | Strict: required config present; real Postgres + LLM; rate limits on |
| `prod` | High-volume multi-tenant | Strict + Vault required; OTel 1% sample; full audit |

`APP_POSTURE` env var (default `dev`). Read once at boot via `app.posture: ${APP_POSTURE:dev}`.

## Generalised posture pattern (§4 #32, ADR-0035)

All dev-posture in-memory components follow the same construction-time pattern:

> **dev**: emit `[WARN]` to stderr and continue — component is non-durable, acceptable for local development.
> **research / prod**: throw `IllegalStateException` at construction time — operators must provide a durable implementation.

All posture-env reading is centralised in `AppPostureGate.requireDevForInMemoryComponent(componentName)`.
No other production class may call `System.getenv("APP_POSTURE")` directly (Gate Rule 12 enforces this).

## W0 enforced posture rules

| Aspect | Module / Component | dev | research/prod |
|---|---|---|---|
| Missing `X-Tenant-Id` | `agent-platform/tenant` | warn + default | reject 400 |
| Missing `Idempotency-Key` on POST / PUT / PATCH | `agent-platform/idempotency` | accept | reject 400 |
| No `GraphMemoryRepository` bean when enabled | `graphmemory-starter` | context loads, no bean | context loads, no bean |
| `IdempotencyStore.claimOrFind(...)` called | `agent-platform/idempotency` | warn + empty Optional | throws `IllegalStateException` |
| `InMemoryRunRegistry` construction | `agent-runtime/orchestration/inmemory` | warn (non-durable) | throws `IllegalStateException` |
| `InMemoryCheckpointer` construction | `agent-runtime/orchestration/inmemory` | warn (non-durable) | throws `IllegalStateException` |
| `SyncOrchestrator` construction | `agent-runtime/orchestration/inmemory` | warn (non-durable) | throws `IllegalStateException` |
| `InMemoryCheckpointer` inline payload > 16 KiB | `agent-runtime/orchestration/inmemory` | warn + stores (non-durable) | throws `IllegalStateException` (§4 #13) |

## Boot guard (W1 deferred)

`PostureBootGuard` is not yet built. When it lands in W1, it will be an
`ApplicationListener<ApplicationEnvironmentPreparedEvent>` bean — middleware-shell
pattern, no fabricated impl, only the boot-time required-key check — consistent with
the E2 pattern used by `spring-ai-ascend-graphmemory-starter`.

## W0 shipped tests

| Test | Asserts |
|---|---|
| `PostureBindingIT` | `APP_POSTURE=research` → `app.posture=research` |
| `TenantContextFilterTest` | dev/research/prod posture behaviours |
| `IdempotencyHeaderFilterTest` | dev/research/prod posture behaviours |
| `IdempotencyStoreTest` | dev warn; research/prod throw |
| `AppPostureGateTest` | dev/null passes; research/prod throws ISE with ADR-0035 ref |
| `SyncOrchestratorPostureGuardTest` | dev construction succeeds |
| `InMemoryRunRegistryFindRootRunsTest` | findRootRuns scoping + hierarchy |
| `InMemoryCheckpointerSizeCapTest` | dev warns; package-private failOnOversize=true throws |
