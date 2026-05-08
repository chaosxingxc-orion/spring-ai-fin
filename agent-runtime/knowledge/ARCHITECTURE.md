# knowledge -- JSONB Glossary + 4-Layer Retrieval (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) . L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`knowledge/` owns the **user-facing knowledge surface**: stable facts (wiki + glossary + KG) and the unified retrieval pipeline used by agents during stage execution.

This is the M4 fix from the v5.0 review -- v5.0 proposed a three-layer FIBO ontology (Apache Jena + Protege + SPARQL + JSON-LD + SHACL + ontology2nebula); v6.0 ships **PostgreSQL JSONB + a 30-50 class hand-curated finance glossary** + four-layer retrieval (grep -> BM25 -> JSONB filter -> optional vector).

Owns:

- `KnowledgeStore` -- JSONB-backed store of finance glossary classes + customer-supplied wiki pages
- `FourLayerRetriever` -- grep -> BM25 -> JSONB filter -> optional vector (vector deferred until traffic justifies)
- `GlossaryLoader` -- bootstrap-time loader for `fin-domain-pack/glossary.json` (customer-supplied)
- `KnowledgeManager` -- orchestrator wiring the above

Does NOT own:

- Run-internal layered memory (delegated to `../memory/`)
- Embedding model (delegated to `../llm/` for embedding requests)
- Dream scheduling (delegated to `../server/LifespanController`)
- HTTP ingest routes (delegated to `agent-platform/api/`)

---

## 2. Why JSONB + glossary, not full FIBO

The v5.0 review (M4) found:

- FIBO has 2,436 classes; the proposed 200-500 subset is itself a year of ontology engineering
- The proposed Apache Jena + Protege + SPARQL + JSON-LD + SHACL + custom `ontology2nebula` converter + FIBO MCP server stack is multi-year work added on day 0
- The four core financial workflows (KYC, AML, suitability, fraud) need only ~30-50 classes

v6.0:

- Ship a **30-50 class hand-curated glossary** in JSON Schema covering the four workflows
- Inject relevant subset into LLM prompt as static context (M1 mode in v5.0 terminology)
- Defer Apache Jena / SPARQL / FIBO MCP / ontology2nebula to phase 2 with a regulatory trigger ("a named regulator demands semantic-graph reasoning evidence")

Customer can supply their own glossary via `fin-domain-pack/glossary.json` -- keeping with Rule 10 (capability-layer only; domain content is customer-owned).

---

## 3. Four-layer retrieval

```
query -> 
  Layer 1 grep        (regex over wiki+glossary text; <50ms)
       -> 
  Layer 2 BM25        (text ranking; <200ms; Apache Lucene via Spring Boot)
       -> 
  Layer 3 JSONB filter (Postgres GIN index on JSONB attributes; <100ms)
       -> 
  Layer 4 vector (opt) (deferred until Milvus/pgvector adopted Tier-2)
       -> 
  ranked + budget-bounded result list
```

Each layer can short-circuit: if grep finds an exact match, stop. If BM25 produces strong scores, optionally skip JSONB. The vector layer is opt-in and only fires when budget remains.

---

## 4. Key data structures

```java
public record KnowledgeRecord(
    @NonNull String tenantId,                   // spine -- every record per-tenant
    @NonNull String namespace,                  // "glossary", "wiki", "regulatory", etc.
    @NonNull String key,
    @NonNull JsonNode payload,
    @NonNull Set<String> tags,
    @NonNull Instant createdAt,
    @Nullable Instant updatedAt
) {
    public KnowledgeRecord { /* spine validation */ }
}

public interface KnowledgeStore {
    // Posture-aware: dev=JSON; research/prod=Postgres JSONB
    void upsert(KnowledgeRecord record);
    Optional<KnowledgeRecord> get(String tenantId, String namespace, String key);
    List<KnowledgeRecord> query(String tenantId, KnowledgeQuery query);
    // ...
}
```

---

## 5. Architecture decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: JSONB + 30-50 class glossary, NOT full FIBO** | Defer FIBO to phase 2 | M4 fix; FIBO over-engineering for MVP |
| **AD-2: Customer supplies glossary** | Out-of-repo `fin-domain-pack/glossary.json` | Rule 10 (capability-layer only); platform doesn't bake in OJK/MAS specifics |
| **AD-3: Four-layer retrieval, vector optional** | grep -> BM25 -> JSONB -> vector | Cheaper layers first; vector only when traffic justifies |
| **AD-4: Postgres JSONB + GIN index** | Not Neo4j | Same as memory L3; JSONB sufficient for query patterns |
| **AD-5: Posture-aware backend** | dev=JSON; research/prod=Postgres | Inspectability vs durability |
| **AD-6: Per-tenant Wiki partition** | tenant_id mandatory on every record | Cross-tenant leak prevented |
| **AD-7: Static M1 LLM injection at v1** | Glossary subset injected into prompt as system context | Simpler than M2 dynamic; latency-safe |
| **AD-8: Knowledge cache invalidation via schema_version + sha256** | Cached index includes both | Detect glossary updates; mirrors hi-agent's pattern |

---

## 6. Cross-cutting hooks

- **Rule 11**: every record carries tenant_id; spine validator enforces
- **Posture-aware**: backend factory reads posture
- **Rule 7**: retrieval failures (e.g., glossary unavailable) emit `springaifin_knowledge_retrieval_errors_total` + WARNING + fallback to grep-only
- **License (D-15)**: BM25 via Apache Lucene (Apache 2.0); pgvector (PostgreSQL license) when adopted

---

## 7. Quality

| Attribute | Target | Verification |
|---|---|---|
| Retrieval p95 latency | <= 200ms (3-layer); <= 500ms (with vector) | `tests/integration/KnowledgeRetrievalIT` |
| Glossary load time | <= 1s for 50-class glossary | `tests/integration/GlossaryLoaderIT` |
| Cross-tenant isolation | Wiki/glossary scoped per tenant | `tests/integration/KnowledgeTenantIsolationIT` |
| Spine validation | every record validated | `KnowledgeSpineValidationTest` |

## 8. Risks

- **Glossary missing or malformed**: fail at boot in research/prod (`assertGlossaryAvailable` in PlatformBootstrap); in dev, log WARNING + permit empty
- **FIBO demand from a customer**: phase-2 trigger; we honour with a dedicated wave (Apache Jena adoption + ontology2graph migration)
- **Vector retrieval recall@10**: target >= 0.85; measure quarterly to decide Milvus adoption (Tier-2 trigger)

## 9. References

- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Memory: [`../memory/ARCHITECTURE.md`](../memory/ARCHITECTURE.md)
- Hi-agent prior art: `D:/chao_workspace/hi-agent/hi_agent/knowledge/ARCHITECTURE.md`
