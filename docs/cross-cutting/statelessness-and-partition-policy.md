> Owner: agent-platform | Maturity: L2 | Posture: all | Last refreshed: 2026-05-10

# Statelessness and Partition Policy

This document describes the state ownership model, per-transaction tenant isolation, horizontal scaling story, and known failure modes for the spring-ai-fin platform.

---

## State ownership map

| Storage tier | Technology | What lives here | Durability |
|---|---|---|---|
| Relational + vector | PostgreSQL 16 | Run records, idempotency keys, artifacts, audit log, prompt versions, feedback, tenant config, pgvector embeddings | Durable; ACID; WAL-replicated |
| Cache | Valkey 7.x | Session-scoped ephemeral state; Caffeine-backed in-process L0 cache for tenant config (60s TTL) | Ephemeral; lose on eviction or restart |
| Workflow | Temporal Cluster | Long-running workflow history; activity retry state; signals | Durable; Temporal's own WAL |

The application tier (`agent-platform`, `agent-runtime`) is stateless across replicas. No replica-local state that affects correctness. JVM heap may hold Caffeine L0 cache entries; these are rebuilt from Postgres on miss and on restart -- loss is safe.

---

## Row-Level Security and per-transaction GUC (W1)

Every tenant-scoped Postgres table has an RLS policy that restricts visibility to rows whose `tenant_id` matches the session GUC `app.tenant_id`.

The connection-level GUC is set with:

```sql
SET LOCAL app.tenant_id = '<uuid>';
```

`SET LOCAL` is transaction-scoped; Postgres discards the value automatically on `COMMIT` or `ROLLBACK`. No manual cleanup required.

The `TenantContextFilter` (order 20 in the HTTP filter chain) reads `X-Tenant-Id` from the validated request, binds it to the Spring request scope, and injects it into the HikariCP connection interceptor that issues the `SET LOCAL` before every statement in the transaction.

A `BEFORE INSERT/UPDATE` trigger on every tenant-scoped table asserts that `current_setting('app.tenant_id', true)` is non-empty; a transaction that does not set the GUC fails with a trigger violation rather than silently inserting a null-tenant row.

This is enforced in all postures. In `dev`, the GUC may be set to a synthetic tenant id for local testing.

---

## Horizontal scale story

The app tier is horizontally scalable by replica count:

- Spring Boot replicas share no in-process state that affects correctness.
- Caffeine L0 cache is per-replica; stale entries are refreshed from Postgres within the TTL (60s for tenant config).
- The Postgres connection pool (HikariCP, max 20 per replica) is the scaling bottleneck per replica; K8s HPA scales replica count based on CPU + `agent_runs_pending` Prometheus metric.
- Temporal cluster handles fan-out for long-running workflows independently of the app replica count.

Scale-out does not require sticky sessions, session affinity, or shared in-process caches. Any replica can handle any request.

---

## Failure modes

### Idempotency deduplication race

Two replicas receive the same `Idempotency-Key` within milliseconds of each other. The Postgres unique index on `(tenant_id, idempotency_key)` serializes the race: exactly one `INSERT` wins; the other sees a unique-constraint violation, which the `IdempotencyRepository` translates into a replay response. Both replicas return the same result to the client.

Mitigation: the dedup table insert uses `INSERT ... ON CONFLICT DO NOTHING RETURNING *`; the `claimOrFind` contract guarantees at most one winner.

### Replay with in-flight run

If the first request is still in flight when the replay arrives, the replay returns the cached response from the idempotency record. If no response is cached yet (run not terminal), the platform returns `202 Accepted` with the run id so the client can poll `GET /v1/runs/{id}`.

### Temporal workflow replay

Temporal replays workflow history on worker restart. Activity code must be replay-safe: no non-deterministic side effects inside activity bodies (random, time-based branching, external state). LLM calls and tool calls are activities with explicit retry policies; they are recorded in Temporal history before re-execution.

### Valkey eviction

Ephemeral session state stored in Valkey is soft-state only. Eviction or restart loses the value; the runtime rebuilds from Postgres on the next access. No correctness dependency on Valkey persistence. Applications must not store run lifecycle state in Valkey.

---

## Related documents

- [docs/cross-cutting/posture-model.md](posture-model.md) for posture-aware default behavior
- [docs/contracts/configuration-contracts.md](../contracts/configuration-contracts.md) for property reference
- [ARCHITECTURE.md](../../ARCHITECTURE.md) sections 6.1 and 6.2 for posture and tenant spine detail
