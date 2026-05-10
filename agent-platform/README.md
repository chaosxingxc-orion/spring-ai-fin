# agent-platform

> Northbound HTTP facade; accepts authenticated tenant requests, runs the filter chain (TenantContextFilter order 20, IdempotencyHeaderFilter order 30), and forwards to agent-runtime via SPI contracts. Maturity: L1.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| (consumer only) | -- | agent-platform consumes SPI interfaces defined in spring-ai-fin-*-starter modules; it does not define new SPI interfaces |

The platform calls `RunRepository`, `IdempotencyRepository`, `PolicyEvaluator`, and all other SPI interfaces through the starter contracts. It never imports `agent-runtime` Java types directly (enforced by `ApiCompatibilityTest`).

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | JWT validation skipped (permitAll); tenant header optional with WARN; idempotency optional |
| research | JWT required; X-Tenant-Id required; idempotency key required on mutable routes; BeanCreationException on missing sentinel overrides |
| prod | JWT required; X-Tenant-Id required; idempotency key required; strict TLS; all sentinels rejected at context load |

## Filter chain

| Filter | Order | Responsibility |
|--------|-------|----------------|
| JWTAuthFilter | 10 | Validate JWT; reject invalid algorithm or missing token in research/prod |
| TenantContextFilter | 20 | Bind X-Tenant-Id to request scope; set Postgres GUC app.tenant_id per transaction |
| IdempotencyHeaderFilter | 30 | Reserve or replay Idempotency-Key; emit 4 metrics on every decision |

JWTAuth (order 10) is a W2 deliverable; W0/W1 run with a passthrough dev filter at order 10.

## Health endpoint

`GET /v1/health` -- stable, no required headers, exempt from idempotency and tenant filters.

- Response 200: `{"status":"UP","sha":"<git-sha>","posture":"<dev|research|prod>"}`
- `HealthEndpointIT` is GREEN at commit 97b0827.

## Drop-in override (@Bean recipe)

Platform-level beans are not SPI-overridable. Customization is via starter @Bean overrides (see individual starter READMEs) or application properties.

## Counters emitted

- `springai_fin_filter_errors_total` tagged `filter=<filter-class>, reason=<reason>` -- emitted by each filter on failure (Rule 7)
- `springai_fin_idempotency_claimed_total` -- new key claimed
- `springai_fin_idempotency_replayed_total` -- existing key replayed
- `springai_fin_idempotency_conflict_total` -- key claimed by different run
- `springai_fin_idempotency_error_total` -- storage error during claim

## See also

- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design
- [agent-platform/api/ARCHITECTURE.md](api/ARCHITECTURE.md) for HTTP transport layer detail
- [docs/contracts/http-api-contracts.md](../docs/contracts/http-api-contracts.md) for route-level HTTP contracts
- [docs/contracts/spi-contracts.md](../docs/contracts/spi-contracts.md) for SPI semantic contracts
