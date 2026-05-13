# 0034. Memory and Knowledge Taxonomy at L0

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-13
**Technical story:** Seventh reviewer (P1.5) found no memory/knowledge taxonomy section anywhere in
the architecture. Cluster 5 self-audit surfaced 8 hidden defects: `GraphMemoryRepository` metadata
is minimal (no ontology, provenance, or retention); mem0/Graphiti/Cognee are all referenced without
a "selected W1 default" decision; `oss-bill-of-materials.md` still names deleted SPIs. This ADR
names the 6-category taxonomy and common metadata schema.

## Context

At W0 the only memory-related SPI is `GraphMemoryRepository` (stub, no implementation). The
`spring-ai-ascend-graphmemory-starter` scaffolds the Spring Boot autoconfiguration but registers no
real bean. Three external libraries (mem0, Graphiti, Cognee) are listed in the BoM without a
"selected as default" decision. No common metadata schema exists.

Without a taxonomy, W1–W3 memory additions will make incompatible design choices about provenance,
retention, and ontology tagging.

## Decision Drivers

- Seventh reviewer P1.5: memory/knowledge taxonomy missing — must be named before W1 memory work begins.
- Hidden defect 5.4: `GraphMemoryRepository` metadata is minimal; no ontology, provenance, retention.
- Hidden defect 5.5: mem0/Graphiti/Cognee all referenced without selection decision.
- Hidden defect 5.3: no taxonomy section anywhere in active documentation.

## Considered Options

1. **Name 6-category taxonomy + common metadata schema (design-only at W0)** — this decision.
2. **Skip taxonomy; decide per-wave** — prior-reviewer experience shows per-wave decisions accumulate incompatible designs.
3. **Adopt one library (e.g., mem0) as the only memory model** — premature coupling.

## Decision Outcome

**Chosen option:** Option 1.

### Memory and Knowledge Taxonomy (§4 #31)

Six categories, from highest to lowest volatility:

| # | Category | Description | Lifetime |
|---|---|---|---|
| M1 | Short-Term Run Context | Variables, tool results, and intermediate payloads within a single Run execution | Run duration |
| M2 | Episodic Session Memory | Events and decisions from the current user session; supports in-session continuity | Session / configurable TTL |
| M3 | Semantic Long-Term Memory | Facts, preferences, and beliefs that persist across sessions; accessible by embedding similarity | Until explicit delete or expiry |
| M4 | Graph Relationship Memory | Entity–entity relationships (knowledge graph). Structured; queryable by pattern. | Until explicit delete or expiry |
| M5 | Knowledge Index | Indexed document/chunk store; powering retrieval-augmented generation | Document/version lifecycle |
| M6 | Retrieved Context | The result of a retrieval operation — assembled for a specific reasoning step | Ephemeral (one reasoning step) |

### Common Metadata Schema

All M2–M5 memory records carry a common metadata envelope:

```java
// Design-only at W0. Governs W1+ GraphMemoryRepository metadata expansion.
public record MemoryMetadata(
    String tenantId,           // required — mandatory tenant scoping
    UUID runId,                // nullable — null for cross-session semantic memories
    String sessionId,          // nullable — null for non-session facts
    String source,             // provenance URI or "user-input" / "llm-generated" / "tool-result"
    String ontologyTag,        // nullable — domain ontology label (e.g., "FHIR:Patient", "financial:trade")
    double confidence,         // 0.0–1.0 — 1.0 for user-asserted facts; <1.0 for inferred facts
    Instant expiresAt,         // nullable — null = no expiry
    String embeddingModelVersion, // nullable — model used for the embedding (e.g., "text-embedding-3-small@2")
    RedactionState redaction,  // CLEAR | REDACTED | ENCRYPTED_AT_REST
    VisibilityScope visibility // PRIVATE_TO_RUN | SHARED_IN_SESSION | SHARED_IN_TENANT | GLOBAL
) {}
```

`GraphMemoryRepository` SPI remains minimal at W0. The metadata expansion is a W2 contract revision.

### Library selection (oss-bill-of-materials.md aligned)

- **Graphiti (Neo4j)** — designated as the W1 reference sidecar for M4 (graph relationship memory). Listed as the example implementation in `oss-bill-of-materials.md`.
- **mem0** — not selected; architecture path remains open for a future activation ADR.
- **Cognee** — not selected; similar rationale.
- **Docling** — document parsing utility, not a memory library; moved to `docs/archive` context. Not in active BoM scope.

This is NOT a permanent exclusion of mem0 or Cognee. It is a clarification that neither is the W1 default. Future activation requires a dedicated ADR.

### Consequences

**Positive:**
- W1–W3 memory SPIs can reference the taxonomy instead of inventing their own naming.
- Common metadata schema enables cross-category provenance tracking from the start.
- Library selection clarity prevents a "we ship mem0 AND Graphiti AND Cognee" over-build.

**Negative:**
- `GraphMemoryRepository` metadata expansion deferred to W2; W0 impl remains a stub.
- Six-category taxonomy may prove incomplete as multi-modal memory (audio, vision, motion) is needed post-W4.

## References

- Seventh reviewer P1.5: `docs/reviews/2026-05-13-l0-architecture-readiness-agent-systems-review.en.md`
- ADR-0033: Deployment-locus vocabulary (memory may be scoped to a deployment locus)
- `GraphMemoryRepository.java` — current minimal SPI
- `docs/cross-cutting/oss-bill-of-materials.md` — Graphiti selected as W1 example; mem0/Cognee not-selected
- `architecture-status.yaml` row: `memory_knowledge_taxonomy`

## Forward note — ownership governed by ADR-0051 (whitepaper-alignment remediation, 2026-05-13)

The M1–M6 taxonomy defined here is the **platform memory taxonomy** from the S-Side perspective. It does NOT define ownership. Per ADR-0051 (Memory and Knowledge Ownership Boundary, §4 #49):

- M3 / M4 / M5 are **split** into platform-derived operational memory (S-Side owned) and business-owned ontology/fact events (C-Side owned by default; S-Side-stored only via explicit delegation contract).
- `GraphMemoryRepository` is the platform SPI for M4 graph relationship memory. It is **NOT** the default owner of customer business ontology. Any M4 adapter (including the W1 reference adapter Graphiti) MUST declare whether it stores **platform graph state**, **delegated business graph state**, or **both** — and any delegated business graph state requires a `DelegationGrant` per ADR-0051.
- The `PlaceholderPreservationPolicy` rule (ADR-0051) is a **first-class ship-blocking constraint** on every memory operation: placeholders (e.g. `[USER_ID_102]`) MUST be preserved verbatim through every memory read/write unless an explicit `DelegationGrant` authorises identity resolution at that scope.
- Business facts discovered during agent execution flow back to the C-Side via `BusinessFactEvent` (ADR-0051), NOT into S-Side memory by default.
