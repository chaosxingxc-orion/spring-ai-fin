# ADR-0044: SPI Contract Precision and Memory Metadata Reconciliation

> Status: accepted | Date: 2026-05-13 | Deciders: architecture team

## Context

Three precision gaps between the contract catalog and the Java source were identified in the
second-pass review:

**Gap 1 — SPI invariant overgeneralization:**
`docs/contracts/contract-catalog.md:20` claims "All SPI impls: tenant-scoped." Two SPIs are not
tenant-scoped at W0:
- `Checkpointer` — operations take `(UUID runId, String nodeKey)`, no `tenantId`. Run uniqueness
  is sufficient at W0 (single-tenant in-memory store). ADR-0027 §3 defers tenant-scoped dedup.
- `ResilienceContract` — `resolve(String operationId)` has no tenant parameter. ADR-0030 §4
  explicitly stages promotion to `(tenantId, operationId)` at W2.

**Gap 2 — RunContext misclassification:**
`contract-catalog.md:38` describes `RunContext` as "Per-run context record passed to SPIs."
`RunContext.java:16` is `public interface RunContext` — not a Java `record` type. The word
"record" misleads implementers into assuming it is a `record`, affecting how they store or
serialize it.

**Gap 3 — Memory metadata field naming drift:**
Three authoritative sources disagree on the `embeddingModel*` field name:
- `ARCHITECTURE.md:390` — `embeddingModel?`
- `docs/governance/architecture-status.yaml:822` — `embeddingModel`
- `docs/adr/0034-memory-and-knowledge-taxonomy-at-l0.md:66` — `embeddingModelVersion`

`GraphMemoryRepository.GraphMetadata` carries neither field; its W0 structure is
`(tenantId, sessionId, runId, createdAt)` — intentionally minimal for W0.

## Decision Drivers

- Contract catalog is a normative document read by SPI implementers; precision errors lead to
  incorrect implementations.
- ADR-0034 is the authoritative source for the memory taxonomy — its field names take precedence.
- W0 `GraphMetadata` was designed as a minimal graph-edge record; retrofitting full MemoryMetadata
  at W0 contradicts Rule 2 (surgical minimum change).

## Considered Options

### Gap 1 (tenant scope)

1. **Evolve Checkpointer and ResilienceContract to carry tenantId now** — premature; ADR-0027/0030 explicitly defer this.
2. **Refine the catalog invariant to match actual scope per SPI** — correct the claim, not the code.

### Gap 2 (RunContext type)

1. **Change RunContext to a `record` type** — breaks callers; unnecessary.
2. **Correct catalog classification to "interface"** — one-word doc fix.

### Gap 3 (embeddingModel naming)

1. **Canonicalize on `embeddingModelVersion` (ADR-0034)** — ADR-0034 is the authoritative source.
2. **Canonicalize on `embeddingModel` (ARCHITECTURE.md)** — fewer characters; but ADR-0034 is more specific (version identity matters).
3. **Add `embeddingModelVersion` to W0 GraphMetadata now** — out of scope for this cycle; GraphMetadata is W0-minimal by design.

## Decision

- **Gap 1:** Replace the blanket "tenant-scoped" invariant with a per-SPI scope table. The
  refined invariant: "SPIs that process tenant-owned runtime data MUST carry tenant scope
  (via explicit `tenantId` argument or `RunContext.tenantId()`). SPIs operating on
  tenant-agnostic configuration MAY be operation-scoped at W0."
- **Gap 2:** Correct `RunContext` catalog entry from "record" to "interface".
- **Gap 3:** Option 1. Normalize to `embeddingModelVersion` across ARCHITECTURE.md and
  `architecture-status.yaml`. Document `GraphMemoryRepository.GraphMetadata` as a pre-W2
  minimal graph-edge subset via JavaDoc; no Java code change.

## Per-SPI Scope Classification (canonical, post-ADR-0044)

| SPI | W0 scope | Tenant carrier | Planned scope evolution |
|---|---|---|---|
| `RunRepository` | tenant-scoped | explicit `tenantId` arg on `findByTenant*` | unchanged |
| `Checkpointer` | run-scoped | implicit via `runId` uniqueness | unchanged (ADR-0027) |
| `GraphMemoryRepository` | tenant-scoped | explicit `tenantId` first arg (every method, Rule 11) | unchanged |
| `ResilienceContract` | operation-scoped | no tenant param at W0 | tenant-aware `(tenantId, operationId)` at W2 (ADR-0030) |
| `Orchestrator` | tenant-scoped | explicit `tenantId` arg in `run(runId, tenantId, ...)` | unchanged |
| `GraphExecutor` | tenant-scoped | via injected `RunContext.tenantId()` | unchanged |
| `AgentLoopExecutor` | tenant-scoped | via injected `RunContext.tenantId()` | unchanged |

## Consequences

**Positive:**
- Contract catalog matches Java signatures; SPI implementers get accurate invariants.
- `embeddingModelVersion` is consistently named across all three active sources.
- `GraphMetadata` pre-W2 scope is explicitly documented; W2 will align the full `MemoryMetadata`
  schema.
- Gate Rule 17 extended to verify `RunContext` is labeled "interface" in the catalog.

**Negative:**
- Small diff in ARCHITECTURE.md and architecture-status.yaml; no Java code change.

## Gate Rule 17 Extension

Gate Rule 17 (`contract_catalog_spi_table_matches_source`) is extended to verify that the
`RunContext` row in the data-carriers sub-table contains the word "interface". If the row says
"record" (or does not say "interface"), the gate fails.

## §4 Constraint

**§4 #41:** The `contract-catalog.md` SPI table invariant claims MUST match each SPI's actual
Java signature at W0. `RunContext` must be classified as `interface` (not `record`). Scope
invariants must be per-SPI (tenant-scoped, run-scoped, or operation-scoped) rather than a blanket
claim. `embeddingModelVersion` is the canonical field name (ADR-0034). See ADR-0044.

## References

- `docs/contracts/contract-catalog.md:20,38` (invariant text + RunContext row)
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/RunContext.java`
- `agent-runtime/src/main/java/ascend/springai/runtime/resilience/ResilienceContract.java`
- `agent-runtime/src/main/java/ascend/springai/runtime/memory/spi/GraphMemoryRepository.java`
- `docs/adr/0034-memory-and-knowledge-taxonomy-at-l0.md:66` (embeddingModelVersion)
- `docs/adr/0027-idempotency-scope-w0-header-validation.md` (Checkpointer scope deferral)
- `docs/adr/0030-skill-spi-lifecycle-resource-matrix.md:223` (ResilienceContract W2 extension)
