> ARCHIVED 2026-05-12. Pre-refresh design rationale; not active spec. Current state: see docs/STATE.md.

# agent-platform/config -- L2 architecture (2026-05-08 refresh)

> Owner: platform | Wave: W2 | Maturity: L0 | Reads: tenant_config, Spring Cloud Config server | Writes: --
> Last refreshed: 2026-05-08

## 1. Purpose

Layered configuration: defaults in code -> `application.yml` ->
Spring Cloud Config server (per environment) -> per-tenant overrides
in Postgres `tenant_config`. Caches per-tenant resolved config in
Caffeine for 60s.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Spring Cloud Config Client | 4.x | central config |
| Spring Cloud Config Server | 4.x | (separate ops process) |
| Caffeine | 3.x | per-tenant cache |
| Spring Boot starter jdbc | 3.5.x | tenant_config repo |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `config/TenantConfigKey.java` (record) | (tenant, key) | 30 |
| `config/TenantConfigLoader.java` | resolves with cache | 100 |
| `config/TenantConfigRepository.java` | jdbc | 80 |
| `db/migration/V2_3__tenant_config.sql` | tenant_config table + RLS | 50 |

## 4. Public contract

`TenantConfigLoader.get(tenantId, key, type)` returns:
1. tenant override row if present;
2. else Spring environment property;
3. else default.

Keys are namespaced (`llm.routing`, `memory.retention.l1.days`).

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Cloud Config server required | no | optional | required |
| Cache TTL | 0 (no cache) | 60s | 60s |
| Tenant override audit | optional | required | required |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `TenantOverrideIT` | E2E | two tenants with different overrides see different behavior |
| `ConfigCacheTtlIT` | Integration | override change visible after TTL |
| `ConfigFallbackIT` | Integration | missing tenant row falls through to default |
| `ConfigRlsIsolationIT` | Integration | tenant cannot read another tenant's overrides |

## 7. Out of scope

- Boot-time required-config validation (`bootstrap/`).
- Secrets (`docs/cross-cutting/secrets-lifecycle.md`).

## 8. Wave landing

W2 brings tenant_config table + loader. W3 adds change-audit on
override updates.

## 9. Risks

- Cache staleness across replicas: 60s TTL accepted; explicit cache
  invalidation API for ops; documented.
- Configuration explosion: typed keys enforced via `ConfigKey<T>`
  registry; ad-hoc string keys rejected by lint.
