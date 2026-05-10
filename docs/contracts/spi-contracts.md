# SPI Contracts

> Full semantic contracts for all spring-ai-fin SPI interfaces.
> Version: 0.1.0-SNAPSHOT | Last refreshed: 2026-05-10

All SPI interfaces share these cross-cutting contracts:

- **Thread safety**: every SPI implementation is required to be thread-safe. The runtime calls SPIs from Java 21 virtual threads concurrently.
- **Null returns**: SPI methods must never return null. Return Optional.empty() or an empty collection instead.
- **Tenant scope**: every method that has a `tenantId` parameter must scope its effect to that tenant. Operations must not leak data across tenant boundaries.
- **ArchUnit enforcement**: SPI packages (`fin.springai.runtime.spi.*`) import only `java.*` types. No Spring, Micrometer, or platform imports in SPI packages.
- **Binary API compatibility**: japicmp configured in spring-ai-fin-dependencies (BoM). Enforcement enabled from W1 onward when baseline JARs are available.

---

## LongTermMemoryRepository

Package: `fin.springai.runtime.spi.memory`
Owner: `spring-ai-fin-memory-starter`

| Method | Signature | Semantic guarantee | Error contract |
|--------|-----------|-------------------|----------------|
| put | put(tenantId, userId, content, metadata) -> MemoryEntry | Persists entry; returns assigned id; tenantId is non-null required | L0 sentinel throws IllegalStateException with message "LongTermMemoryRepository not configured"; L2+ throws implementation-specific checked exception |
| search | search(tenantId, userId, query, topK) -> List<MemoryEntry> | Returns at most topK relevant entries; empty list if none found; never null | Same as put |
| findById | findById(tenantId, entryId) -> Optional<MemoryEntry> | Returns entry only if tenantId matches; Optional.empty() otherwise | Same as put |
| delete | delete(tenantId, entryId) | No-op if not found or wrong tenant; never throws for missing | Same as put |

Posture-aware behavior:

- dev: sentinel active; WARN logged; no data persisted; returns dummy MemoryEntry with id="sentinel"
- research/prod: BeanCreationException at context load if sentinel is the registered implementation

---

## GraphMemoryRepository

Package: `fin.springai.runtime.spi.memory`
Owner: `spring-ai-fin-memory-starter`

| Method | Signature | Semantic guarantee | Error contract |
|--------|-----------|-------------------|----------------|
| addFact | addFact(tenantId, subject, relation, object, metadata) | Adds triple to tenant-scoped graph; idempotent if triple already exists | L0 sentinel throws IllegalStateException; L2+ implementation-specific |
| query | query(tenantId, subject, maxDepth) -> List<GraphEdge> | Traverses from subject up to maxDepth hops; tenant-scoped; never null | Same |
| search | search(tenantId, queryText, topK) -> List<GraphEdge> | Full-text + graph search; at most topK results; never null | Same |

Posture-aware behavior: same as LongTermMemoryRepository.

---

## ToolProvider

Package: `fin.springai.runtime.spi.skills`
Owner: `spring-ai-fin-skills-starter`

| Method | Signature | Semantic guarantee | Error contract |
|--------|-----------|-------------------|----------------|
| listTools | listTools(tenantId) -> List<ToolDescriptor> | Returns all tools available for the tenant, filtered by tenant allowlist; empty list if none; never null | L0 sentinel throws IllegalStateException; L2+ implementation-specific |
| invoke | invoke(tenantId, toolName, argumentsJson) -> String | Invokes named tool with JSON args; returns JSON-encoded result; throws on tool-not-found or invocation error | L0 sentinel throws IllegalStateException; L2+ throws ToolInvocationException (implementation-specific) |

Posture-aware behavior:

- dev: sentinel active; listTools returns empty list; invoke throws IllegalStateException
- research/prod: BeanCreationException at context load

---

## LayoutParser

Package: `fin.springai.runtime.spi.knowledge`
Owner: `spring-ai-fin-knowledge-starter`

| Method | Signature | Semantic guarantee | Error contract |
|--------|-----------|-------------------|----------------|
| parse | parse(document, options) -> List<ContentBlock> | Parses InputStream into ordered ContentBlock list with layout metadata; empty list if document is empty; never null | L0 sentinel throws IllegalStateException; L2+ throws DocumentParseException on unrecognized format |

ParseOptions, ContentBlock, and BoundingBox are process-internal records (not persisted or transmitted across tenants).

Posture-aware behavior:

- dev: sentinel active; parse returns empty list with WARN
- research/prod: BeanCreationException at context load

---

## DocumentSourceConnector

Package: `fin.springai.runtime.spi.knowledge`
Owner: `spring-ai-fin-knowledge-starter`

| Method | Signature | Semantic guarantee | Error contract |
|--------|-----------|-------------------|----------------|
| connectorId | connectorId() -> String | Returns non-null human-readable id (e.g. "s3", "github"); unique per connector type | Never throws |
| fetch | fetch(tenantId, config) -> Iterator<RawDocument> | Emits all documents; caller is responsible for closing the Iterator; Iterator may be lazy (does not load all docs into memory) | L0 sentinel throws IllegalStateException on fetch; L2+ throws SourceConnectorException on connectivity failure |

Multiple `DocumentSourceConnector` beans are supported. The `DocumentSourceConnectorRegistry` (provided by the knowledge starter) collects all registered connectors and fans out fetch calls.

Posture-aware behavior:

- dev: sentinel connectorId returns "sentinel"; fetch throws IllegalStateException with WARN
- research/prod: BeanCreationException at context load

---

## PolicyEvaluator

Package: `fin.springai.runtime.spi.governance`
Owner: `spring-ai-fin-governance-starter`

| Method | Signature | Semantic guarantee | Error contract |
|--------|-----------|-------------------|----------------|
| evaluate | evaluate(tenantId, policyId, input) -> EvaluationResult | Returns ALLOW, DENY, or ABSTAIN; missing tenantId always returns DENY; DENY result always logged at WARNING+ with run id (Rule 7) | L0 sentinel throws IllegalStateException; L2+ returns DENY on policy not found or connectivity failure |

EvaluationResult carries tenantId, runId, Decision, reason, and details.

Posture-aware behavior:

- dev: sentinel active; returns DENY with reason "sentinel-not-configured"; WARN logged
- research/prod: BeanCreationException at context load

---

## RunRepository

Package: `fin.springai.runtime.spi.persistence`
Owner: `spring-ai-fin-persistence-starter`

| Method | Signature | Semantic guarantee | Error contract |
|--------|-----------|-------------------|----------------|
| create | create(run) -> RunRecord | Creates run record; returns stored record; runId must be unique per tenant | L0 sentinel throws IllegalStateException; L2+ throws DuplicateRunException on duplicate runId |
| findById | findById(tenantId, runId) -> Optional<RunRecord> | Returns run only if tenantId matches; Optional.empty() otherwise | L0 sentinel throws IllegalStateException |
| updateStage | updateStage(tenantId, runId, stage) -> RunRecord | Transitions stage; returns updated record; no-op if stage is already terminal | L0 sentinel throws IllegalStateException |
| markTerminal | markTerminal(tenantId, runId, terminalStage, outcome) -> RunRecord | Marks run as SUCCEEDED, FAILED, or CANCELLED; idempotent (second call with same terminal stage is a no-op) | L0 sentinel throws IllegalStateException |

RunRecord carries: runId, tenantId, userId, sessionId, parentRunId, stage, startedAt, finishedAt, outcome (full contract spine per Rule 11).

Posture-aware behavior:

- dev: sentinel active; throws IllegalStateException with WARN
- research/prod: BeanCreationException at context load

---

## IdempotencyRepository

Package: `fin.springai.runtime.spi.persistence`
Owner: `spring-ai-fin-persistence-starter`

| Method | Signature | Semantic guarantee | Error contract |
|--------|-----------|-------------------|----------------|
| claimOrFind | claimOrFind(tenantId, idempotencyKey, runId) -> Optional<IdempotencyRecord> | First call: claims key and returns Optional.empty(); subsequent calls with same (tenantId, idempotencyKey): returns existing record with the original runId | L0 sentinel throws IllegalStateException; L2+ returns existing record on conflict (never throws on duplicate) |

Posture-aware behavior:

- dev: sentinel active; throws IllegalStateException with WARN
- research/prod: BeanCreationException at context load

---

## ArtifactRepository

Package: `fin.springai.runtime.spi.persistence`
Owner: `spring-ai-fin-persistence-starter`

| Method | Signature | Semantic guarantee | Error contract |
|--------|-----------|-------------------|----------------|
| store | store(tenantId, runId, name, mimeType, content) -> ArtifactRecord | Stores bytes; returns record with storageUri; tenantId + runId required | L0 sentinel throws IllegalStateException; L2+ throws StorageException on backend failure |
| findById | findById(tenantId, artifactId) -> Optional<ArtifactRecord> | Returns artifact only if tenantId matches | L0 sentinel throws IllegalStateException |
| findByRunId | findByRunId(tenantId, runId) -> List<ArtifactRecord> | Lists all artifacts for run; tenant-scoped; never null | L0 sentinel throws IllegalStateException |

ArtifactRecord carries: artifactId, tenantId, runId, name, mimeType, sizeBytes, storageUri, createdAt (full contract spine).

Posture-aware behavior:

- dev: sentinel active; throws IllegalStateException with WARN
- research/prod: BeanCreationException at context load

---

## ResilienceContract

Package: `fin.springai.runtime.spi.resilience`
Owner: `spring-ai-fin-resilience-starter`

| Method | Signature | Semantic guarantee | Error contract |
|--------|-----------|-------------------|----------------|
| resolve | resolve(operationId) -> ResiliencePolicy | Returns policy with non-null circuitBreakerName, retryName, and timeLimiterName; never returns null | L0 sentinel throws IllegalStateException; L2+ never throws (returns a default policy for unknown operationId) |

ResiliencePolicy is a process-internal record (scope: process-internal; not persisted or transmitted across tenants). The caller uses the returned names to bind Resilience4j annotations at W2 call sites.

Posture-aware behavior:

- dev: sentinel active; returns policy with names "default-cb", "default-retry", "default-tl"; WARN logged
- research/prod: BeanCreationException at context load

---

## Related documents

- [contract-catalog.md](contract-catalog.md) for the full contract inventory
- [docs/cross-cutting/contract-evolution-policy.md](../cross-cutting/contract-evolution-policy.md) for versioning rules
- [ARCHITECTURE.md](../../ARCHITECTURE.md) section 3.2 for SPI extension surface
