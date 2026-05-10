# Configuration Contracts

> Property reference for all springai.fin.* and app.* configuration properties.
> Version: 0.1.0-SNAPSHOT | Last refreshed: 2026-05-10

All properties are read once at startup (except Caffeine cache TTL which is read at cache-manager construction). Never hard-code posture or feature flags at call sites.

---

## Core platform properties

| Property | Type | Default | Posture impact | Owner |
|----------|------|---------|----------------|-------|
| app.posture | String | dev | Sets global posture; dev=permissive, research/prod=fail-closed | agent-platform |
| app.sha | String | dev | Git SHA injected at build time; surfaced in /v1/health response | agent-platform |
| spring.threads.virtual.enabled | boolean | true | Not posture-dependent | agent-platform |
| spring.datasource.url | String | jdbc:postgresql://localhost:5432/springaifin | research/prod: must point to real Postgres; no in-memory fallback | agent-platform |
| spring.datasource.username | String | springaifin | Sourced from Vault in research/prod | agent-platform |
| spring.datasource.password | String | springaifin | Sourced from Vault in research/prod | agent-platform |
| spring.datasource.hikari.maximum-pool-size | int | 20 | research/prod: size to match replica count * virtual thread fanout | agent-platform |
| spring.flyway.enabled | boolean | true | research/prod: must remain true; in-memory DB forbidden | agent-platform |
| server.port | int | 8080 | Not posture-dependent | agent-platform |

---

## Memory starter properties

| Property | Type | Default | Posture impact | Owner |
|----------|------|---------|----------------|-------|
| springai.fin.memory.enabled | boolean | true | dev: sentinel on missing @Bean; research/prod: BeanCreationException on missing @Bean | spring-ai-fin-memory-starter |

---

## Mem0 sidecar adapter properties

| Property | Type | Default | Posture impact | Owner |
|----------|------|---------|----------------|-------|
| springai.fin.mem0.enabled | boolean | false | When false: adapter not loaded in any posture | spring-ai-fin-mem0-starter |
| springai.fin.mem0.base-url | String | (none) | Required when enabled=true; missing URL causes BeanCreationException in all postures | spring-ai-fin-mem0-starter |

---

## GraphMemory sidecar adapter properties

| Property | Type | Default | Posture impact | Owner |
|----------|------|---------|----------------|-------|
| springai.fin.graphmemory.enabled | boolean | false | When false: adapter not loaded in any posture | spring-ai-fin-graphmemory-starter |
| springai.fin.graphmemory.base-url | String | (none) | Required when enabled=true; missing URL causes BeanCreationException in all postures | spring-ai-fin-graphmemory-starter |

---

## Docling sidecar adapter properties

| Property | Type | Default | Posture impact | Owner |
|----------|------|---------|----------------|-------|
| springai.fin.docling.enabled | boolean | false | When false: adapter not loaded in any posture | spring-ai-fin-docling-starter |
| springai.fin.docling.base-url | String | (none) | Required when enabled=true; missing URL causes BeanCreationException in all postures | spring-ai-fin-docling-starter |

---

## Skills starter properties

| Property | Type | Default | Posture impact | Owner |
|----------|------|---------|----------------|-------|
| springai.fin.skills.enabled | boolean | true | dev: sentinel on missing @Bean; research/prod: BeanCreationException on missing @Bean | spring-ai-fin-skills-starter |

---

## Knowledge starter properties

| Property | Type | Default | Posture impact | Owner |
|----------|------|---------|----------------|-------|
| springai.fin.knowledge.enabled | boolean | true | dev: sentinel on missing @Bean; research/prod: BeanCreationException on missing @Bean | spring-ai-fin-knowledge-starter |

---

## Governance starter properties

| Property | Type | Default | Posture impact | Owner |
|----------|------|---------|----------------|-------|
| springai.fin.governance.enabled | boolean | true | dev: sentinel on missing @Bean; research/prod: BeanCreationException on missing @Bean | spring-ai-fin-governance-starter |

---

## Persistence starter properties

| Property | Type | Default | Posture impact | Owner |
|----------|------|---------|----------------|-------|
| springai.fin.persistence.enabled | boolean | true | dev: sentinel on missing @Bean; research/prod: BeanCreationException on missing @Bean | spring-ai-fin-persistence-starter |

---

## Resilience starter properties

| Property | Type | Default | Posture impact | Owner |
|----------|------|---------|----------------|-------|
| springai.fin.resilience.enabled | boolean | true | dev: sentinel on missing @Bean; research/prod: BeanCreationException on missing @Bean | spring-ai-fin-resilience-starter |

---

## Management and observability properties

| Property | Type | Default | Posture impact | Owner |
|----------|------|---------|----------------|-------|
| management.endpoints.web.exposure.include | String | health,info,prometheus | research/prod: restrict to internal network only | agent-platform |
| management.endpoint.health.probes.enabled | boolean | true | Not posture-dependent | agent-platform |
| management.metrics.tags.service | String | agent-platform | Used to label all Micrometer metrics | agent-platform |

---

## Deprecation notices

None at this version. The deprecation policy (N+2 release window) is defined in [docs/cross-cutting/contract-evolution-policy.md](../cross-cutting/contract-evolution-policy.md).

---

## Related documents

- [contract-catalog.md](contract-catalog.md) for the full contract inventory
- [docs/cross-cutting/posture-model.md](../cross-cutting/posture-model.md) for posture semantics
- [docs/cross-cutting/integration-guide.md](../cross-cutting/integration-guide.md) for integration paths
