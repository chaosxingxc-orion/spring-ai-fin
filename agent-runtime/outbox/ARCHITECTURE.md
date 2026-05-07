# outbox — Outbox + Sync-Saga + Direct-DB (L2)

> **L2 sub-architecture of `agent-runtime/`.** Up: [`../ARCHITECTURE.md`](../ARCHITECTURE.md) · L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md)

---

## 1. Purpose & Boundary

`outbox/` owns the **three-path write taxonomy** that resolves v5.0's H6 finding (the "Outbox-as-universal" antipattern that punted A→B fund transfer to "Saga, somehow").

Three named write paths, each declared via `@WriteSite(consistency=...)` annotation at the call site. CI fails on unannotated writes. Each path has different latency, consistency, and failure semantics:

| Path | Used for | Mechanism | Latency | Consistency |
|---|---|---|---|---|
| **OUTBOX_ASYNC** | Telemetry, agent run events, artifact metadata, cost events, audit-non-PII | Same-Postgres-txn outbox table; `OutboxRelay` polls and publishes | event visible in 200ms–2s | eventual within tenant |
| **SYNC_SAGA** | Cross-business-entity strong consistency (fund transfer A→B; multi-account post; loan disbursement; settlement) | `SyncSagaOrchestrator` over typed steps with explicit compensations | sub-second p95 | strong within saga; isolated across tenants |
| **DIRECT_DB** | Read-your-write within one aggregate (single account read after write; balance lookup) | Single Postgres transaction; no relay | sub-100ms | strict serializable at row level |

The package owns:

- `OutboxStore` — durable Postgres table (`outbox_event`) with append-only semantics
- `OutboxRelay` — polling worker that publishes events to in-process subscribers (and, when Kafka is adopted in v1.1+, to Kafka topics)
- `DebeziumFeed` — opt-in CDC source for downstream consumers to tail the outbox without polling
- `SyncSagaOrchestrator` — typed step + compensation framework
- `@WriteSite` annotation + `WriteSiteAuditTest` reflective gate

Does NOT own:

- Postgres schema migrations (Flyway/Liquibase under `agent-runtime/server/migrations/`).
- Kafka transport (deferred to v1.1+; adoption trigger in §10).
- Event-bus federation (in-process subscribers only at MVP).
- Event-payload schemas (carried by `agent-platform/contracts/v1/streaming/Event.java`).

---

## 2. Why three paths, not one (H6 fix)

### v5.0's mistake

v5.0 Ch.8.3 framed Outbox as "the cross-store transaction model" (singular). §8.3.4 admitted Outbox does NOT handle cross-business-entity strong consistency (fund transfer A→B), punting it to "Seata TCC or business-layer Saga" — without specifying *which* fund-flow paths use Saga vs Outbox. In a finance platform, A→B fund transfer is the canonical transaction; saying "use Saga for that" without enforcement is exactly the gap that produces the inconsistency Rule 1 was designed to prevent.

### v6.0's resolution

Three paths, each declared at the call site via annotation. The annotation is greppable; CI fails on unannotated writes; reviewers can audit consistency choices in O(N) where N = number of write sites.

```java
@WriteSite(consistency = OUTBOX_ASYNC, reason = "telemetry; eventual within tenant")
public void recordRunCompleted(RunId id, Duration d) { ... }

@WriteSite(consistency = SYNC_SAGA, reason = "fund transfer A→B; cross-entity strong consistency required")
public TransferReceipt transfer(AccountId from, AccountId to, Money amount) { ... }

@WriteSite(consistency = DIRECT_DB, reason = "single-row balance read after write")
public Money balance(AccountId id) { ... }
```

`WriteSiteAuditTest` reflects over `@WriteSite` annotations and asserts every write-bearing method (`EntityManager.persist`, `JdbcTemplate.update`, `JpaRepository.save`, etc.) carries the annotation. Unannotated writes fail CI.

---

## 3. OUTBOX_ASYNC path

### Schema

```sql
CREATE TABLE outbox_event (
    id BIGSERIAL PRIMARY KEY,
    tenant_id VARCHAR(255) NOT NULL,                 -- contract spine (Rule 11)
    aggregate_type VARCHAR(64) NOT NULL,
    aggregate_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(128) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    relay_status SMALLINT NOT NULL DEFAULT 0,        -- 0 = pending, 1 = relayed, 2 = failed
    relay_attempts SMALLINT NOT NULL DEFAULT 0,
    relayed_at TIMESTAMPTZ
);

CREATE INDEX idx_outbox_pending ON outbox_event(relay_status, created_at) WHERE relay_status = 0;
CREATE INDEX idx_outbox_tenant_time ON outbox_event(tenant_id, created_at);

ALTER TABLE outbox_event ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON outbox_event USING (tenant_id = current_setting('app.tenant_id'));
```

### Write contract

```java
@Service
public class OutboxStore {
    @WriteSite(consistency = DIRECT_DB, reason = "outbox row written in same txn as business write")
    public void append(String tenantId, String aggregateType, String aggregateId, 
                       String eventType, JsonNode payload) {
        // INSERT INTO outbox_event ... ; same Postgres transaction as business write
    }
}
```

The business write site:

```java
@WriteSite(consistency = OUTBOX_ASYNC, reason = "agent run completion event; telemetry")
@Transactional
public void completeRun(RunId runId, RunResult result) {
    runStore.update(runId, RunStatus.DONE);                   // business write
    outboxStore.append(currentTenant(), "run", runId.toString(), 
                       "run_completed", payload(result));     // outbox row
    // Spring closes the @Transactional boundary, atomically committing both rows.
}
```

### Relay

```java
@Component
public class OutboxRelay {
    @Scheduled(fixedDelay = 100)  // every 100ms
    public void poll() {
        var pending = outboxStore.fetchPending(batchSize=100);
        for (var event : pending) {
            try {
                eventBus.publish(event);                       // in-process subscribers
                outboxStore.markRelayed(event.id());
            } catch (Exception e) {
                outboxStore.markFailed(event.id(), e);
                fallbacks.recordFallback("outbox-relay-failed", e);
            }
        }
    }
}
```

### Consumers

In-process subscribers register via Spring's `@EventListener`:

```java
@Component
public class TraceLakeConsumer {
    @EventListener
    public void onRunCompleted(OutboxEvent event) {
        if (!event.eventType().equals("run_completed")) return;
        traceStore.append(event.payload());
    }
}
```

When Kafka is adopted in v1.1+, the `OutboxRelay` additionally publishes to a Kafka topic (e.g., `springaifin.run.completed`). The schema does not change.

### CDC (opt-in)

`DebeziumFeed` is opt-in. If enabled, downstream consumers can tail the `outbox_event` table directly via Debezium's Postgres connector, without polling. This is for high-volume pipelines where polling latency is too high.

---

## 4. SYNC_SAGA path

### Step + Compensation framework

```java
public abstract class SagaStep<R> {
    public abstract R execute() throws SagaStepException;
    public abstract void compensate(R partialResult);
}
```

### Orchestrator

```java
public class SyncSagaOrchestrator {
    public <R> R orchestrate(List<SagaStep<?>> steps) {
        var executed = new ArrayList<Pair<SagaStep<?>, Object>>();
        try {
            Object lastResult = null;
            for (var step : steps) {
                var result = step.execute();
                executed.add(Pair.of(step, result));
                lastResult = result;
            }
            return (R) lastResult;
        } catch (Exception e) {
            // compensate in reverse order; each compensation in its own transaction
            for (int i = executed.size() - 1; i >= 0; i--) {
                var pair = executed.get(i);
                try {
                    ((SagaStep<Object>) pair.getLeft()).compensate(pair.getRight());
                } catch (Exception compE) {
                    fallbacks.recordFallback("saga-compensation-failed", compE);
                    auditStore.append(saga.id(), "compensation_failed", compE);
                    // continue compensating remaining steps
                }
            }
            throw new SagaFailedException(e);
        }
    }
}
```

### Fund transfer example

```java
@Service
public class TransferService {
    @WriteSite(consistency = SYNC_SAGA, reason = "fund transfer A→B; cross-entity strong consistency")
    public TransferReceipt transfer(AccountId from, AccountId to, Money amount) {
        return sagaOrchestrator.orchestrate(List.of(
            new InitiateTransferStep(from, to, amount),
            new DebitStep(from, amount),
            new CreditStep(to, amount),
            new RecordOutboxStep(from, to, amount)
        ));
    }
}

class DebitStep extends SagaStep<DebitResult> {
    @Override @WriteSite(consistency = DIRECT_DB, reason = "saga step: debit account")
    public DebitResult execute() {
        // BEGIN; SELECT FOR UPDATE balance; UPDATE balance; INSERT debit_journal; COMMIT
    }
    @Override @WriteSite(consistency = DIRECT_DB, reason = "saga step: refund debit")
    public void compensate(DebitResult result) {
        // BEGIN; UPDATE balance += amount; INSERT refund_journal; COMMIT
    }
}
```

Each step's `execute()` is a single Postgres transaction. The orchestrator drives the sequence; compensation runs in reverse on failure.

### Saga state durability

Sagas survive JVM restart via the `saga_run` table:

```sql
CREATE TABLE saga_run (
    id UUID PRIMARY KEY,
    tenant_id VARCHAR(255) NOT NULL,
    saga_type VARCHAR(128) NOT NULL,
    state VARCHAR(32) NOT NULL,                      -- PENDING, RUNNING, COMPLETED, COMPENSATING, COMPENSATED, FAILED
    steps JSONB NOT NULL,                            -- step status + partial results
    started_at TIMESTAMPTZ NOT NULL,
    finished_at TIMESTAMPTZ
);
```

On startup, `SagaRecoveryController` re-attaches to in-flight sagas: PENDING/RUNNING are aborted (compensation runs); COMPENSATING resumes; COMPENSATED/COMPLETED/FAILED are terminal.

---

## 5. DIRECT_DB path

### Use cases

- Single-account balance lookup after write (read-your-write).
- Single-record idempotency reservation (the IdempotencyStore itself is `DIRECT_DB`).
- Per-row state machine transitions on a single aggregate (`run_state_transitions`).

### Pattern

Single Postgres transaction; no outbox row, no saga orchestration. Annotated for audit:

```java
@WriteSite(consistency = DIRECT_DB, reason = "single-row state transition")
@Transactional
public void transition(RunId id, RunState from, RunState to) {
    int updated = runStore.updateState(id, from, to);
    if (updated == 0) {
        throw new IllegalStateTransitionException(id, from, to);
    }
}
```

---

## 6. Architecture Decisions

| ADR | Decision | Why |
|---|---|---|
| **AD-1: Three named paths** | OUTBOX_ASYNC + SYNC_SAGA + DIRECT_DB | Each finance write has different consistency needs; one path size doesn't fit all (review H6) |
| **AD-2: Annotation enforces consistency choice** | `@WriteSite(consistency=...)` mandatory; CI fails on unannotated writes | Decisions visible at call site; reviewers can audit in O(N) |
| **AD-3: Outbox in same Postgres txn** | INSERT outbox row in business txn | Atomic dual-write without distributed transaction protocol |
| **AD-4: In-process subscribers at MVP, Kafka deferred** | EventBus.publish() in-process; Kafka v1.1+ | Avoids day-0 Kafka adoption (review M2 / H2) |
| **AD-5: Saga state in `saga_run` table for restart-survival** | Saga survives JVM restart; recovery on startup | Same durability discipline as runs |
| **AD-6: Compensation runs even if intermediate compensation fails** | Continue compensating remaining steps; record failures to audit | Better to compensate as much as possible than fail-stop |
| **AD-7: OutboxRelay polls every 100ms** | Polling, not LISTEN/NOTIFY | LISTEN/NOTIFY drops messages on disconnect; polling is simpler and more resilient. CDC (Debezium) for high-volume customers |
| **AD-8: Postgres RLS on outbox_event** | `tenant_id = current_setting('app.tenant_id')` | Cross-tenant outbox leak prevented at the database level |

---

## 7. Cross-cutting hooks

| Concern | Implementation |
|---|---|
| **Posture (Rule 11)** | OutboxRelay enabled in research/prod; in dev, optional via `app.outbox.relay.enabled` |
| **Spine (Rule 11)** | `outbox_event.tenant_id` mandatory; spine validation at INSERT |
| **Resilience (Rule 7)** | OutboxRelay failure → `springaifin_outbox_relay_errors_total{reason}` + WARNING + `fallbackEvents` + gate-asserted |
| **Saga compensation telemetry** | `springaifin_saga_compensation_total{saga_type, status}` |
| **Saga duration** | `springaifin_saga_duration_seconds{saga_type, terminal_state}` histogram |
| **Idempotency** | Saga steps are idempotent by construction (each carries an idempotency key); replay produces same result |

---

## 8. Quality Attributes

| Attribute | Target | Verification |
|---|---|---|
| **OUTBOX_ASYNC visibility latency** | p95 ≤ 500ms (in-process); p95 ≤ 2s (CDC) | `tests/integration/OutboxLatencyIT` |
| **SYNC_SAGA round-trip** | p95 ≤ 1s for 4-step saga | `tests/integration/SyncSagaLatencyIT` |
| **Saga compensation correctness** | All-or-nothing across step failure points | `tests/integration/SyncSagaCompensationIT` (all failure permutations) |
| **WriteSite coverage** | 100% of write methods annotated | `WriteSiteAuditTest` |
| **Saga restart-survival** | In-flight saga survives JVM crash; recovers on startup | `tests/integration/SagaCrashRecoveryIT` |
| **OutboxRelay backpressure** | Backlog ≥ 10K events triggers WARNING + scaling alarm | `springaifin_outbox_pending_total{tenant_id}` gauge |

---

## 9. Risks & Technical Debt

| Risk | Plan |
|---|---|
| Outbox table unbounded growth | `OutboxRelay` purges relayed events older than 24h (clones idempotency purge pattern) |
| Saga compensation bug | Reviewer + integration test at every saga; saga_type-specific test suite |
| Cross-tenant relay leak | Postgres RLS + relay enforces `tenant_id` propagation in EventBus payload |
| OutboxRelay single-replica bottleneck | At MVP, single replica; v1.1 adds work-stealing across replicas |
| Direct-DB writes that should be Saga | Reviewer audit; CI annotation but no automated detection of misclassification |

---

## 10. References

- L0: [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md) §5.4 (sync transaction example)
- L1: [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- Server / RunManager: [`../server/ARCHITECTURE.md`](../server/ARCHITECTURE.md)
- Hi-agent prior art (Outbox in Python/SQLite): `D:/chao_workspace/hi-agent/hi_agent/server/idempotency.py` — same purge pattern adapted to Postgres
- Postgres outbox pattern: https://microservices.io/patterns/data/transactional-outbox.html
- Saga pattern: https://microservices.io/patterns/data/saga.html
