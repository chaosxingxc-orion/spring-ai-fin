# Telemetry Contracts

> Metric naming conventions, required tags, cardinality budget, and structured log field schema.
> Version: 0.1.0-SNAPSHOT | Last refreshed: 2026-05-10

---

## Metric naming convention

All platform-emitted Prometheus counters follow the pattern:

```
springai_fin_<domain>_<subject>_total
```

- `<domain>`: lower-case name of the owning starter domain (memory, skills, knowledge, governance, persistence, resilience, filter, idempotency)
- `<subject>`: what is being counted (e.g. default_impl_not_configured, claimed, replayed, errors)
- `_total`: Prometheus counter suffix (Micrometer appends this automatically for `Counter` instances)

Timers follow: `springai_fin_<domain>_<operation>_seconds` (Prometheus histogram/summary).

No Unicode characters in metric names. No camelCase. Underscores only.

---

## Required tags per metric family

### Sentinel not-configured counters (all starters)

| Tag | Values | Required |
|-----|--------|----------|
| spi | SPI interface simple name (e.g. LongTermMemoryRepository) | yes |
| method | Method name on the SPI interface (e.g. put, search) | yes |

Example: `springai_fin_memory_default_impl_not_configured_total{spi="LongTermMemoryRepository",method="put"}`

### Filter error counters (agent-platform)

| Tag | Values | Required |
|-----|--------|----------|
| filter | Filter class simple name (e.g. TenantContextFilter) | yes |
| reason | Short reason string (e.g. missing_tenant_header, invalid_uuid) | yes |

Example: `springai_fin_filter_errors_total{filter="TenantContextFilter",reason="missing_tenant_header"}`

### Idempotency counters (agent-platform)

| Counter name | Tags | Description |
|---|---|---|
| springai_fin_idempotency_claimed_total | (none beyond service tag) | Key claimed for the first time |
| springai_fin_idempotency_replayed_total | (none) | Key already claimed; response replayed |
| springai_fin_idempotency_conflict_total | (none) | Key claimed by a different runId |
| springai_fin_idempotency_error_total | reason | Storage error during claim attempt |

---

## Cardinality budget

High-cardinality labels (tenant_id, run_id, user_id) are forbidden on Prometheus counters. Use structured logs for per-tenant/per-run attribution. The observability policy (see `docs/cross-cutting/observability-policy.md`) caps the total number of distinct label value combinations per metric family at 1000 in research posture and 10000 in prod posture.

Forbidden tags on all metrics: `tenant_id`, `run_id`, `user_id`, `request_id`.

These identifiers belong in structured logs and OpenTelemetry trace attributes, not in Prometheus label sets.

---

## Structured log field schema

All application logs are emitted as JSON (Logback JSON encoder). Required fields per log line:

| Field | Type | Description | Present in |
|-------|------|-------------|-----------|
| timestamp | ISO-8601 string | Log emission time | all logs |
| level | String | Log level (INFO, WARN, ERROR) | all logs |
| logger | String | Logger class name | all logs |
| message | String | Human-readable message | all logs |
| run_id | String (UUID) | Agent run identifier; null if not in run context | WARNING+ logs from runtime |
| tenant_id | String (UUID) | Tenant identifier; null if not in tenant context | WARNING+ logs from runtime |
| posture | String | Current app posture (dev/research/prod) | all sentinel WARN logs |
| spi | String | SPI interface simple name | sentinel WARN logs |
| method | String | SPI method name | sentinel WARN logs |

Sentinel WARN log example:

```json
{
  "timestamp": "2026-05-10T08:00:00.000Z",
  "level": "WARN",
  "logger": "ascend.springai.runtime.memory.NotConfiguredLongTermMemoryRepository",
  "message": "LongTermMemoryRepository sentinel called -- no real impl configured",
  "posture": "dev",
  "spi": "LongTermMemoryRepository",
  "method": "put"
}
```

---

## All counters currently emitted by sentinels

| Counter | Tags | Emitting class |
|---------|------|----------------|
| springai_fin_memory_default_impl_not_configured_total | spi=LongTermMemoryRepository, method=put | NotConfiguredLongTermMemoryRepository |
| springai_fin_memory_default_impl_not_configured_total | spi=LongTermMemoryRepository, method=search | NotConfiguredLongTermMemoryRepository |
| springai_fin_memory_default_impl_not_configured_total | spi=LongTermMemoryRepository, method=findById | NotConfiguredLongTermMemoryRepository |
| springai_fin_memory_default_impl_not_configured_total | spi=LongTermMemoryRepository, method=delete | NotConfiguredLongTermMemoryRepository |
| springai_fin_memory_default_impl_not_configured_total | spi=GraphMemoryRepository, method=addFact | NotConfiguredGraphMemoryRepository |
| springai_fin_memory_default_impl_not_configured_total | spi=GraphMemoryRepository, method=query | NotConfiguredGraphMemoryRepository |
| springai_fin_memory_default_impl_not_configured_total | spi=GraphMemoryRepository, method=search | NotConfiguredGraphMemoryRepository |
| springai_fin_skills_default_impl_not_configured_total | spi=ToolProvider, method=listTools | NotConfiguredToolProvider |
| springai_fin_skills_default_impl_not_configured_total | spi=ToolProvider, method=invoke | NotConfiguredToolProvider |
| springai_fin_knowledge_default_impl_not_configured_total | spi=LayoutParser, method=parse | NotConfiguredLayoutParser |
| springai_fin_knowledge_default_impl_not_configured_total | spi=DocumentSourceConnector, method=fetch | NotConfiguredDocumentSourceConnector |
| springai_fin_governance_default_impl_not_configured_total | spi=PolicyEvaluator, method=evaluate | NotConfiguredPolicyEvaluator |
| springai_fin_persistence_default_impl_not_configured_total | spi=RunRepository, method=create | NotConfiguredRunRepository |
| springai_fin_persistence_default_impl_not_configured_total | spi=RunRepository, method=findById | NotConfiguredRunRepository |
| springai_fin_persistence_default_impl_not_configured_total | spi=RunRepository, method=updateStage | NotConfiguredRunRepository |
| springai_fin_persistence_default_impl_not_configured_total | spi=RunRepository, method=markTerminal | NotConfiguredRunRepository |
| springai_fin_persistence_default_impl_not_configured_total | spi=IdempotencyRepository, method=claimOrFind | NotConfiguredIdempotencyRepository |
| springai_fin_persistence_default_impl_not_configured_total | spi=ArtifactRepository, method=store | NotConfiguredArtifactRepository |
| springai_fin_persistence_default_impl_not_configured_total | spi=ArtifactRepository, method=findById | NotConfiguredArtifactRepository |
| springai_fin_persistence_default_impl_not_configured_total | spi=ArtifactRepository, method=findByRunId | NotConfiguredArtifactRepository |
| springai_fin_resilience_default_impl_not_configured_total | spi=ResilienceContract, method=resolve | NotConfiguredResilienceContract |

---

## Related documents

- [contract-catalog.md](contract-catalog.md) for the full contract inventory
- [docs/cross-cutting/observability-policy.md](../cross-cutting/observability-policy.md) for cardinality budget detail
