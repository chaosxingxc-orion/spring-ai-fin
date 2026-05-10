# Contract Catalog

> Single source of truth for all public contracts in the spring-ai-fin platform.
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
| LongTermMemoryRepository | spring-ai-fin-memory-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| GraphMemoryRepository | spring-ai-fin-memory-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| ToolProvider | spring-ai-fin-skills-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| LayoutParser | spring-ai-fin-knowledge-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| DocumentSourceConnector | spring-ai-fin-knowledge-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| PolicyEvaluator | spring-ai-fin-governance-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| RunRepository | spring-ai-fin-persistence-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| IdempotencyRepository | spring-ai-fin-persistence-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| ArtifactRepository | spring-ai-fin-persistence-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |
| ResilienceContract | spring-ai-fin-resilience-starter | ArchUnit ApiCompatibilityTest | L1 (tested; no semver) |

All SPI packages (`fin.springai.runtime.spi.*`) import only `java.*` types. Spring, Micrometer, and platform classes are forbidden in SPI packages. Enforced by `ApiCompatibilityTest.spi_packages_import_only_java_sdk_types`.

Full per-SPI semantic contracts are in [spi-contracts.md](spi-contracts.md).

---

## 3. Configuration contracts

All platform configuration properties use the `springai.fin.*` prefix. Property details (type, default, posture impact, owning starter) are in [configuration-contracts.md](configuration-contracts.md).

| Prefix | Owner starter | Summary |
|--------|---------------|---------|
| springai.fin.memory.* | spring-ai-fin-memory-starter | Memory SPI toggle and config |
| springai.fin.mem0.* | spring-ai-fin-mem0-starter | Mem0 sidecar adapter; enabled=false default |
| springai.fin.graphmemory.* | spring-ai-fin-graphmemory-starter | Graphiti sidecar adapter; enabled=false default |
| springai.fin.docling.* | spring-ai-fin-docling-starter | Docling sidecar adapter; enabled=false default |
| springai.fin.skills.* | spring-ai-fin-skills-starter | Skills SPI toggle |
| springai.fin.knowledge.* | spring-ai-fin-knowledge-starter | Knowledge SPI toggle |
| springai.fin.governance.* | spring-ai-fin-governance-starter | Governance SPI toggle |
| springai.fin.persistence.* | spring-ai-fin-persistence-starter | Persistence SPI toggle |
| springai.fin.resilience.* | spring-ai-fin-resilience-starter | Resilience SPI toggle |
| app.posture | agent-platform | dev/research/prod posture; read at boot |

---

## 4. Telemetry contract

All platform-emitted Prometheus counters use the namespace `springai_fin_*`. Cardinality rules and structured log field schema are in [telemetry-contracts.md](telemetry-contracts.md).

Counter naming pattern: `springai_fin_<domain>_<subject>_total`

Examples:
- `springai_fin_memory_default_impl_not_configured_total` tagged `spi, method`
- `springai_fin_idempotency_claimed_total`
- `springai_fin_filter_errors_total` tagged `filter, reason`

---

## 5. Maven BoM coordinates

| Artifact | GroupId | ArtifactId | Version |
|---|---|---|---|
| BoM | fin.springai | spring-ai-fin-dependencies | 0.1.0-SNAPSHOT |
| Memory starter | fin.springai | spring-ai-fin-memory-starter | 0.1.0-SNAPSHOT |
| Skills starter | fin.springai | spring-ai-fin-skills-starter | 0.1.0-SNAPSHOT |
| Knowledge starter | fin.springai | spring-ai-fin-knowledge-starter | 0.1.0-SNAPSHOT |
| Governance starter | fin.springai | spring-ai-fin-governance-starter | 0.1.0-SNAPSHOT |
| Persistence starter | fin.springai | spring-ai-fin-persistence-starter | 0.1.0-SNAPSHOT |
| Mem0 starter | fin.springai | spring-ai-fin-mem0-starter | 0.1.0-SNAPSHOT |
| GraphMemory starter | fin.springai | spring-ai-fin-graphmemory-starter | 0.1.0-SNAPSHOT |
| Docling starter | fin.springai | spring-ai-fin-docling-starter | 0.1.0-SNAPSHOT |
| LangChain4j profile | fin.springai | spring-ai-fin-langchain4j-profile | 0.1.0-SNAPSHOT |
| Resilience starter | fin.springai | spring-ai-fin-resilience-starter | 0.1.0-SNAPSHOT |

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
