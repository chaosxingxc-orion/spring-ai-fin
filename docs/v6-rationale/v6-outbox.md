> ARCHIVED 2026-05-12. Pre-refresh design rationale; not active spec. Current state: see docs/STATE.md.

# agent-runtime/outbox -- L2 architecture (2026-05-08 refresh)

> Owner: runtime | Wave: W2 | Maturity: L0 | Reads: outbox_event | Writes: outbox_event, downstream sink
> Last refreshed: 2026-05-08

## 1. Purpose

At-least-once delivery of side-effect events. Producer writes a row
inside the same transaction as the side effect; a publisher reads
unsent rows in batches and emits them; events are deduplicated by
event_id at the consumer (or downstream-side outbox).

Default sink is a log appender; Kafka or NATS adapters are optional
and only enabled when scale demands.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| PostgreSQL | 16 | outbox table |
| Spring Boot starter jdbc | 3.5.x | repository |
| Resilience4j | 2.x | retry on sink |
| (optional) Apache Kafka client | 3.7.x | sink (W4+) |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `outbox/OutboxEvent.java` (record) | event_id, tenant_id, type, payload, created_at, sent_at | 50 |
| `outbox/OutboxRepository.java` | jdbc | 100 |
| `outbox/OutboxPublisher.java` | scheduled poller; locks via `FOR UPDATE SKIP LOCKED` | 140 |
| `outbox/sink/LogSink.java` | default sink | 40 |
| `outbox/sink/KafkaSink.java` | optional sink | 100 |
| `db/migration/V4_2__outbox.sql` | table + index | 50 |

## 4. Public contract

Producer: `OutboxRepository.append(event)` inside the side-effect
transaction. The event becomes visible after commit.

Publisher: scheduled at fixed delay (configurable). Picks rows where
`sent_at IS NULL` with `FOR UPDATE SKIP LOCKED`, emits in order, sets
`sent_at`. Crashed mid-batch retries on next tick (idempotent at
sink).

Event schema versioned by `type` + `version` field; consumers tolerate
forward-compatible changes.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Sink | log | log or kafka | kafka (when scale demands) |
| Polling interval | 5s | 1s | 1s |
| Retention of sent rows | 7d | 30d | 90d |
| Per-row max retries | 5 | 10 | 10 |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `OutboxAtLeastOnceIT` | Integration | crash publisher mid-batch; no event lost |
| `OutboxSkipLockedIT` | Integration | two publishers see different rows |
| `OutboxOrderingIT` | Integration | events from same tenant emitted in insertion order |
| `OutboxSinkRetryIT` | Integration | sink fails N times; eventually succeeds |
| `OutboxRlsIsolationIT` | Integration | RLS prevents cross-tenant reads |
| `OutboxDeadLetterIT` | Integration | row exceeding max retries moves to `outbox_event_dlq` |

## 7. Out of scope

- Strong cross-entity consistency: explicitly not provided; callers
  must be idempotent.
- Real-time streaming: outbox is near-real-time (1s tick); WebSocket
  push is a separate module if needed.

## 8. Wave landing

W2: table + publisher + log sink. W3: dead-letter handling +
per-tenant retry config. W4+: Kafka sink and partitioning per tenant
when scale demands.

## 9. Risks

- Outbox table bloat: partitioning by month via pg_partman; archival
  job W4.
- Polling latency too high: batch size tuned + index on `sent_at IS
  NULL`; benchmark in `OutboxAtLeastOnceIT`.
- Sink lag: alert on `outbox_unsent_age_seconds_max` Prometheus
  metric exceeding SLO.

## 10. Per-tenant ordering + DLQ procedure (added cycle-10 per OUT-1, OUT-2)

### 10.1 Per-tenant ordering

The publisher provides **per-tenant in-order delivery** at the sink.
Cross-tenant ordering is NOT guaranteed (tenants are independent).

Mechanism:

- A row's order key is `(tenant_id, created_at, id)`.
- The publisher batch-fetches rows with `FOR UPDATE SKIP LOCKED` per
  tenant -- one batch query per tenant in flight, not a global batch.
- Within a batch for a tenant, rows are emitted in insertion order.
- Multiple publisher replicas: each replica works on a *non-overlapping
  set of tenants* via consistent hashing (W4+); within v1 single
  replica is sufficient.

Tradeoff: per-tenant batching limits throughput vs a global batch.
Mitigation: increase replica count when load demands.

### 10.2 DLQ table

`outbox_event_dlq`:

```
event_id uuid PRIMARY KEY,
tenant_id uuid NOT NULL,
type text NOT NULL,
payload jsonb NOT NULL,
created_at timestamptz NOT NULL,
last_attempted_at timestamptz NOT NULL,
attempt_count integer NOT NULL,
last_error text,
moved_to_dlq_at timestamptz NOT NULL DEFAULT now()
```

A row from `outbox_event` moves to `outbox_event_dlq` when
`attempt_count > max_retries` (default 10 in research; 5 in prod).

### 10.3 DLQ replay procedure

Manual operator action via admin API:

```
POST /v1/admin/outbox/dlq/{event_id}:replay
```

Effects:

1. Move row from `outbox_event_dlq` back to `outbox_event` with
   `attempt_count` reset to 0.
2. Audit row recorded with operator id.
3. Publisher picks up the row in the next tick.

Bulk replay:

```
POST /v1/admin/outbox/dlq:replay
body: { tenant_id?: uuid, type?: string, limit: 100 }
```

Replay runs are themselves audited. Replays cannot bypass per-tenant
ordering: a replayed row is re-inserted with a NEW `created_at` to
avoid re-ordering older rows.

### 10.4 DLQ alerting

Two metrics:

- `outbox_event_dlq_count{tenant,type}` (gauge): current DLQ depth.
- `outbox_event_dlq_oldest_age_seconds{tenant}` (gauge): age of oldest
  DLQ row.

Alerts:

- ANY DLQ depth > 0 sustained 5min -> WARN.
- DLQ depth > 100 for any tenant -> CRIT.
- Oldest DLQ age > 24h -> CRIT.

### 10.5 Tests

| Test | Layer | Asserts |
|---|---|---|
| `OutboxPerTenantOrderingIT` | Integration | events from same tenant emit in insertion order; cross-tenant order unconstrained |
| `OutboxDlqMoveIT` | Integration | row exceeding max retries moves to DLQ |
| `OutboxDlqReplayIT` | E2E | replay reinserts row; audit recorded; sink eventually receives |
| `OutboxDlqAlertIT` | Integration | DLQ depth metric + alert rule fire as expected |
| `OutboxConsistentHashShardIT` | Integration (W4+) | two publisher replicas work on non-overlapping tenants |
