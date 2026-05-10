# 0004. PostgreSQL 16 with RLS + pgvector, not separate vector DB

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Needed a multi-tenant relational store, durable outbox, plus vector search for memory L2.

## Context

The system needs a multi-tenant relational data store, a durable outbox for at-least-once
delivery, and vector search for the memory L2 layer. Using separate databases for
relational and vector workloads would multiply operational complexity and create
inconsistency risks between the two stores.

## Decision Drivers

- v1 customer profile (~500k rows per tenant; 5 tenants = 2.5M rows) fits under pgvector's practical threshold.
- Row-level security (RLS) uniformly applies to relational and vector tables.
- One DB to operate, one backup story, one access-control story.
- Customer DBA teams already know PostgreSQL.

## Considered Options

1. Postgres 16 + pgvector -- one DB; RLS policies cover relational + vector; familiar to ops.
2. Postgres + Qdrant -- specialized vector DB; better at >10M rows per tenant.
3. Postgres + Elasticsearch -- mature vector + full-text but operationally heavy.

## Decision Outcome

**Chosen option:** Option 1 (Postgres 16 + pgvector for v1; Qdrant trigger criteria documented),
because a single database covers the v1 data volume with uniform RLS and eliminates the
operational and consistency costs of a second store.

### Consequences

**Positive:**
- Single database: one backup story, one access-control story.
- RLS uniformly covers relational and vector tables.
- Customer DBAs are already familiar with PostgreSQL.
- Qdrant migration trigger threshold (>5M rows per tenant) is documented for future planning.

**Negative:**
- pgvector ANN index tuning is the team's responsibility as data grows.
- Qdrant migration plan is needed but not pre-built.

### Reversal cost

medium (memory L2 store is one adapter; Qdrant adapter is plug-in)

## Pros and Cons of Options

### Option 1: Postgres 16 + pgvector

- Pro: Single database eliminates cross-store consistency risk.
- Pro: RLS covers both relational and vector tables uniformly.
- Pro: Operational simplicity; no second cluster to manage.
- Con: pgvector ANN tuning is complex at high row counts.
- Con: Qdrant migration path must be planned when volume exceeds threshold.

### Option 2: Postgres + Qdrant

- Pro: Qdrant optimized for high-volume vector search (>10M rows).
- Con: Two databases to operate and secure.
- Con: RLS does not extend to Qdrant; separate access-control story required.

### Option 3: Postgres + Elasticsearch

- Pro: Mature vector and full-text search capabilities.
- Con: Elasticsearch is operationally heavy relative to the v1 workload.
- Con: Same dual-database operational complexity as Option 2.

## References

- `agent-runtime/memory/ARCHITECTURE.md`
- `docs/cross-cutting/data-model-conventions.md`
- `docs/cross-cutting/oss-bill-of-materials.md` sec-4.2
