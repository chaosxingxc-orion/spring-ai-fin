# Current State (W0)

<!-- columns: capability | shipped | code-path | test-path | posture-coverage | claim -->

## Shipped (W0)

| capability | shipped | code-path | test-path | posture-coverage | claim |
|------------|---------|-----------|-----------|------------------|-------|
| health-endpoint | true | `agent-platform/src/main/java/ascend/springai/platform/web/HealthController.java` | `agent-platform/src/test/java/ascend/springai/platform/HealthEndpointIT.java` | dev/research/prod | GET /v1/health returns 200 |
| tenant-filter | true | `agent-platform/src/main/java/ascend/springai/platform/tenant/TenantContextFilter.java` | `agent-platform/src/test/java/ascend/springai/platform/tenant/TenantContextFilterTest.java` | dev/research/prod | X-Tenant-Id validated; dev default on missing |
| idempotency-filter | true | `agent-platform/src/main/java/ascend/springai/platform/idempotency/IdempotencyHeaderFilter.java` | `agent-platform/src/test/java/ascend/springai/platform/idempotency/IdempotencyHeaderFilterTest.java` | dev/research/prod | Idempotency-Key validated; dev accepts missing |
| idempotency-store | false | `agent-platform/src/main/java/ascend/springai/platform/idempotency/IdempotencyStore.java` | `agent-platform/src/test/java/ascend/springai/platform/idempotency/IdempotencyStoreTest.java` | dev (W0); research/prod throws | W0 stub; W1 will add Postgres-backed claimOrFind |
| graphmemory-spi | false | `agent-runtime/src/main/java/ascend/springai/runtime/memory/spi/GraphMemoryRepository.java` (interface) | `agent-runtime/src/test/java/ascend/springai/runtime/memory/spi/MemorySpiArchTest.java` | no runtime path | SPI contract only; no impl; ArchUnit enforces isolation |
| oss-api-probe | true | `agent-runtime/src/main/java/ascend/springai/runtime/probe/OssApiProbe.java` | `agent-runtime/src/test/java/ascend/springai/runtime/probe/OssApiProbeTest.java` | dev | Smoke test: Spring AI + MCP + Temporal + Tika compile |

---

## Deferred

- Rule 8 gate runs (N≥3 real-LLM sequential runs) and Rule 11 contract-spine fields (`tenant_id` on all
  persistent records) are tracked in [`docs/CLAUDE-deferred.md`](CLAUDE-deferred.md).
- Architecture-level capability status and L-level assignments are tracked in
  [`docs/governance/architecture-status.yaml`](governance/architecture-status.yaml).

---

## Design rationale

Archived pre-refresh docs: `docs/v6-rationale/`

---

## Reading order for new team members

1. `README.md` — project name, status, modules, quick start
2. `docs/STATE.md` — this file; per-capability shipped/deferred table
3. `ARCHITECTURE.md` — system boundary, decision chains, SPI contracts
