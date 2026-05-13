# agent-platform

> Northbound HTTP facade; accepts HTTP requests, validates tenant + idempotency headers, and forwards to agent-runtime via SPI contracts. Maturity: W0.

## SPI surface

| Interface | Method | Semantic guarantee |
|-----------|--------|--------------------|
| (consumer only) | -- | agent-platform consumes SPI interfaces defined in spring-ai-ascend-*-starter modules; it does not define new SPI interfaces |

At W0, the platform applies: Spring Security `AuthorizationManager` for access control, `TenantContextFilter` (validates X-Tenant-Id header), and `IdempotencyHeaderFilter` (validates Idempotency-Key UUID shape). It reads `RunRepository` from the `agent-runtime` SPI for run state queries. It never imports `agent-runtime` Java types directly (enforced by `ApiCompatibilityTest`).

## Posture defaults

| Posture | Behavior |
|---------|----------|
| dev | JWT validation skipped (permitAll); tenant header optional with WARN; idempotency optional |
| research | JWT required; X-Tenant-Id required; idempotency key required on mutable routes; BeanCreationException on missing sentinel overrides |
| prod | JWT required; X-Tenant-Id required; idempotency key required; strict TLS; all sentinels rejected at context load |

## Filter chain

| Filter | Order | Responsibility | Wave |
|--------|-------|----------------|------|
| JWTAuthFilter | 10 | Validate JWT; reject invalid algorithm or missing token in research/prod | W1 (passthrough at W0) |
| TenantContextFilter | 20 | Bind X-Tenant-Id header to TenantContextHolder + MDC tenant_id | W0 |
| IdempotencyHeaderFilter | 30 | Validate UUID shape of Idempotency-Key on POST/PUT/PATCH; 400 on missing in research/prod | W0 |

W0: TenantContextFilter reads `X-Tenant-Id` header only; no JWT, no `SET LOCAL` GUC.
W1: TenantContextFilter adds a JWT `tenant_id` claim cross-check on top of the required `X-Tenant-Id` header (per ADR-0040); IdempotencyHeaderFilter wires IdempotencyStore for dedup.
W2: `SET LOCAL app.tenant_id` GUC + RLS policies enabled.

## Health endpoint

`GET /v1/health` -- stable, no required headers, exempt from idempotency and tenant filters.

- Response 200: `{"status":"UP","sha":"<git-sha>","posture":"<dev|research|prod>"}`
- `HealthEndpointIT` is GREEN at commit 97b0827.

## Drop-in override (@Bean recipe)

Platform-level beans are not SPI-overridable. Customization is via starter @Bean overrides (see individual starter READMEs) or application properties.

## Counters emitted (W0)

All counters use lowercase `springai_ascend_` prefix (canonical naming per §4 #5):

- `springai_ascend_idempotency_header_missing_total` tagged `posture=<posture>` — missing Idempotency-Key header
- `springai_ascend_idempotency_header_invalid_total` tagged `posture=<posture>` — UUID parse failure
- `springai_ascend_tenant_header_missing_total` tagged `posture=<posture>` — missing X-Tenant-Id header
- `springai_ascend_tenant_header_invalid_total` tagged `posture=<posture>` — UUID parse failure

W1 will add `springai_ascend_idempotency_claimed_total`, `_replayed_total`, `_conflict_total` when IdempotencyStore is wired.

## See also

- [ARCHITECTURE.md](../ARCHITECTURE.md) for system design
- [ARCHITECTURE.md](ARCHITECTURE.md) for HTTP transport layer detail
- [docs/contracts/http-api-contracts.md](../docs/contracts/http-api-contracts.md) for route-level HTTP contracts
- [docs/contracts/contract-catalog.md](../docs/contracts/contract-catalog.md) for SPI semantic contracts
