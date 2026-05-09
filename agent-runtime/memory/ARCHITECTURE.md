# agent-runtime/memory -- L2 architecture (2026-05-08 refresh)

> Owner: runtime | Wave: W2..W3 | Maturity: L0 | Reads: tenant_workspace | Writes: run_memory, session_memory, long_term_memory
> Last refreshed: 2026-05-08

## 1. Purpose

Tiered memory for runs and sessions. Three tiers:

- **L0 in-process** (Caffeine): per-run scratch within a JVM.
- **L1 durable session** (Postgres): per-session facts surviving JVM
  restart but not session boundary.
- **L2 long-term semantic** (pgvector): per-tenant embedding store for
  cross-session retrieval.

L3 (warehouse export for fine-tuning corpora) is W4+.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Caffeine | 3.x | L0 in-process cache |
| PostgreSQL | 16 | L1 + L2 store |
| pgvector | 0.7.x | L2 vector index |
| Spring AI VectorStore PgVector | 1.0.x | wrapper over pgvector |
| Spring Boot starter jdbc | 3.5.x | L1 repository |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `memory/MemoryService.java` | tier router | 140 |
| `memory/RunMemoryStore.java` | L0 Caffeine | 80 |
| `memory/SessionMemoryRepository.java` | L1 jdbc | 100 |
| `memory/LongTermMemoryStore.java` | L2 pgvector wrapper | 120 |
| `memory/EmbeddingClient.java` | Spring AI EmbeddingClient binding | 60 |
| `db/migration/V4__memory.sql` | tables + indexes + RLS | 100 |

## 4. Public contract

`MemoryService` exposes:

- `recordFact(scope, key, value)` -> writes to the right tier.
- `retrieve(scope, query, k)` -> returns top-k matches.

Scopes: `RUN`, `SESSION`, `TENANT`. Tier routing is transparent to the
caller. Embeddings are on by default for `TENANT` scope.

DB: `run_memory(run_id, tenant_id, key, value, ts)`,
`session_memory(session_id, tenant_id, key, value, ts)`,
`long_term_memory(tenant_id, embedding vector(1536), payload jsonb,
provider, model, ts)`. RLS on all three.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| L0 cache TTL | 1h | 30 min | 30 min |
| L1 retention | 30d | 90d | 365d |
| L2 retention | 365d | tenant-config | tenant-config |
| Embedding provider mock allowed | yes | no | no |
| PII-tagging on writes | warn | required | required |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `MemoryRecallIT` | E2E | write fact in run 1; retrieve in run 2 |
| `MemoryTierRoutingIT` | Integration | RUN scope -> Caffeine; SESSION -> Postgres; TENANT -> pgvector |
| `MemoryRlsIsolationIT` | E2E | Tenant A's memory invisible to B (RLS) |
| `MemoryEmbeddingMismatchIT` | Integration | model change -> mismatch rejected |
| `MemoryRetentionIT` | Integration | rows older than retention pruned |

## 7. Out of scope

- Knowledge graph (deferred indefinitely).
- Vector DB outside Postgres (Qdrant etc): future migration if scale demands.
- Fine-tuning corpus export (W4+).

## 8. Wave landing

W2: L0 + L1 + repository. W3: L2 pgvector + embeddings + retention
policy. W4: corpus export job.

## 9. Risks

- pgvector index size growth: monitor `relation_size`; document threshold for migration to Qdrant.
- Embedding-model lock-in: provider+model stored with row; mismatch rejected; migration documented.
- L1 retention vs compliance: per-tenant override; default 90d for research; document GDPR / regional considerations.
