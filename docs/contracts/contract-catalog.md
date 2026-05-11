# Contract Catalog

> Single source of truth for all public contracts in the spring-ai-ascend platform.
> Version: 0.1.0-SNAPSHOT | Last refreshed: 2026-05-10

---

## 1. HTTP API contracts

| Route | Method | Stability | Wave | Required headers |
|-------|--------|-----------|------|-----------------|
| /v1/health | GET | stable | W0 | none (exempt) |
| /v1/runs | POST | planned | W1 | X-Tenant-Id, Idempotency-Key |
| /v1/runs/{id} | GET | planned | W1 | X-Tenant-Id |
| /v1/runs/{id}/cancel | POST | planned | W1 | X-Tenant-Id, Idempotency-Key |
| /actuator/health | GET | stable | W0 | none (exempt) |
| /actuator/prometheus | GET | stable | W0 | none (exempt) |

Routes marked "planned" are specified in `docs/contracts/http-api-contracts.md` and in the OpenAPI snapshot at `docs/contracts/openapi-v1.yaml`. They are not yet implemented (W1 deliverable).

---

## 2. SPI contracts

| SPI interface | Owner module | Version pin mechanism | Stability tier |
|---|---|---|---|
| LongTermMemoryRepository | spring-ai-ascend-memory-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| GraphMemoryRepository | spring-ai-ascend-memory-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| ToolProvider | spring-ai-ascend-skills-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| LayoutParser | spring-ai-ascend-knowledge-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| DocumentSourceConnector | spring-ai-ascend-knowledge-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| PolicyEvaluator | spring-ai-ascend-governance-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| RunRepository | spring-ai-ascend-persistence-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| IdempotencyRepository | spring-ai-ascend-persistence-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| ArtifactRepository | spring-ai-ascend-persistence-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| ResilienceContract | spring-ai-ascend-resilience-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |

All SPI packages (`ascend.springai.runtime.spi.*`) import only `java.*` types. Spring, Micrometer, and platform classes are forbidden in SPI packages. Enforced by `ApiCompatibilityTest.spi_packages_import_only_java_sdk_types`.

Full per-SPI semantic contracts are in [spi-contracts.md](spi-contracts.md).

---

## 3. Configuration contracts

All platform configuration properties use the `springai.ascend.*` prefix. Property details (type, default, posture impact, owning starter) are in [configuration-contracts.md](configuration-contracts.md).

| Prefix | Owner starter | Summary |
|--------|---------------|---------|
| springai.ascend.memory.* | spring-ai-ascend-memory-starter | Memory SPI toggle and config |
| springai.ascend.mem0.* | spring-ai-ascend-mem0-starter | Mem0 sidecar adapter; enabled=false default |
| springai.ascend.graphmemory.* | spring-ai-ascend-graphmemory-starter | Graphiti sidecar adapter; enabled=false default |
| springai.ascend.docling.* | spring-ai-ascend-docling-starter | Docling sidecar adapter; enabled=false default |
| springai.ascend.skills.* | spring-ai-ascend-skills-starter | Skills SPI toggle |
| springai.ascend.knowledge.* | spring-ai-ascend-knowledge-starter | Knowledge SPI toggle |
| springai.ascend.governance.* | spring-ai-ascend-governance-starter | Governance SPI toggle |
| springai.ascend.persistence.* | spring-ai-ascend-persistence-starter | Persistence SPI toggle |
| springai.ascend.resilience.* | spring-ai-ascend-resilience-starter | Resilience SPI toggle |
| app.posture | agent-platform | dev/research/prod posture; read at boot |

---

## 4. Telemetry contract

All platform-emitted Prometheus counters use the namespace `SPRINGAI_ASCEND_*`. Cardinality rules and structured log field schema are in [telemetry-contracts.md](telemetry-contracts.md).

Counter naming pattern: `SPRINGAI_ASCEND_<domain>_<subject>_total`

Examples:
- `SPRINGAI_ASCEND_memory_default_impl_not_configured_total` tagged `spi, method`
- `SPRINGAI_ASCEND_idempotency_claimed_total`
- `SPRINGAI_ASCEND_filter_errors_total` tagged `filter, reason`

---

## 5. Maven BoM coordinates

| Artifact | GroupId | ArtifactId | Version |
|---|---|---|---|
| BoM | ascend.springai | spring-ai-ascend-dependencies | 0.1.0-SNAPSHOT |
| Memory starter | ascend.springai | spring-ai-ascend-memory-starter | 0.1.0-SNAPSHOT |
| Skills starter | ascend.springai | spring-ai-ascend-skills-starter | 0.1.0-SNAPSHOT |
| Knowledge starter | ascend.springai | spring-ai-ascend-knowledge-starter | 0.1.0-SNAPSHOT |
| Governance starter | ascend.springai | spring-ai-ascend-governance-starter | 0.1.0-SNAPSHOT |
| Persistence starter | ascend.springai | spring-ai-ascend-persistence-starter | 0.1.0-SNAPSHOT |
| Mem0 starter | ascend.springai | spring-ai-ascend-mem0-starter | 0.1.0-SNAPSHOT |
| GraphMemory starter | ascend.springai | spring-ai-ascend-graphmemory-starter | 0.1.0-SNAPSHOT |
| Docling starter | ascend.springai | spring-ai-ascend-docling-starter | 0.1.0-SNAPSHOT |
| LangChain4j profile | ascend.springai | spring-ai-ascend-langchain4j-profile | 0.1.0-SNAPSHOT |
| Resilience starter | ascend.springai | spring-ai-ascend-resilience-starter | 0.1.0-SNAPSHOT |

---

## 6. HTTP header conventions

| Header | Format | Scope | Exempt paths |
|--------|--------|-------|--------------|
| X-Tenant-Id | UUID (RFC 4122) | Required on all mutable routes | /v1/health, /actuator/** |
| Idempotency-Key | UUID (RFC 4122) | Required on all POST routes | /v1/health, /actuator/**, GET routes |

Validation: `TenantContextFilter` (order 20) validates `X-Tenant-Id` format; 400 on malformed UUID. `IdempotencyHeaderFilter` (order 30) validates `Idempotency-Key` format; 400 on malformed UUID.

---

## Related documents

- [spi-contracts.md](spi-contracts.md) for per-SPI semantic contracts
- [configuration-contracts.md](configuration-contracts.md) for property reference
- [telemetry-contracts.md](telemetry-contracts.md) for metric and log field schema
- [http-api-contracts.md](http-api-contracts.md) for per-route HTTP contracts
- [docs/cross-cutting/contract-evolution-policy.md](../cross-cutting/contract-evolution-policy.md) for versioning rules
