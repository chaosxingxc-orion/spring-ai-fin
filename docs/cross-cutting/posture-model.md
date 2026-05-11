# Posture Model

> Owner: architecture | Wave: W0 | Last updated: 2026-05-12 Occam pass

## The three postures

| Posture | Intent | Defaults |
|---|---|---|
| `dev` | Local development | Permissive: warnings only; in-memory DBs allowed; no rate limits |
| `research` | Production-equivalent | Strict: required config present; real Postgres + LLM; rate limits on |
| `prod` | High-volume multi-tenant | Strict + Vault required; OTel 1% sample; full audit |

`APP_POSTURE` env var (default `dev`). Read once at boot via `app.posture: ${APP_POSTURE:dev}`.

## W0 enforced posture rules

| Aspect | Module | dev | research/prod |
|---|---|---|---|
| Missing `X-Tenant-Id` | `agent-platform/tenant` | warn + default | reject 400 |
| Missing `Idempotency-Key` on POST | `agent-platform/idempotency` | accept | reject 400 |
| No `GraphMemoryRepository` bean when enabled | `graphmemory-starter` | context loads, no bean | context loads, no bean |
| `IdempotencyStore.claimOrFind(...)` called | `agent-platform/idempotency` | warn + empty Optional | throws `UnsupportedOperationException` |

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
