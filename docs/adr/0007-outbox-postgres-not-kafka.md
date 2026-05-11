# 0007. At-least-once outbox in Postgres, not Kafka, for v1

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Side-effects must be durable across crashes; eventual delivery must be guaranteed for the v1 workload.

## Context

Agent side-effects (external calls, notifications, audit writes) must survive process
crashes and be delivered at least once. A reliable delivery mechanism is required
without introducing operational infrastructure beyond what v1 already runs.

## Decision Drivers

- v1 customer (~50 RPS sustained) does not need Kafka-scale throughput.
- The outbox sink interface is one method; Kafka is a drop-in replacement when scale demands it.
- Using Postgres for the outbox keeps the operational footprint to one database.
- `FOR UPDATE SKIP LOCKED` pattern is well-understood and production-proven in Postgres.

## Considered Options

1. Postgres outbox table + scheduled publisher (FOR UPDATE SKIP LOCKED).
2. Kafka direct -- proven scale but requires the cluster as a v1 dependency.
3. NATS JetStream -- lighter than Kafka; still adds operational surface.

## Decision Outcome

**Chosen option:** Option 1 (Postgres outbox at v1; Kafka adapter pluggable when scale demands),
because the v1 workload does not justify Kafka cluster overhead and the outbox sink
interface allows a Kafka replacement without changing callers.

### Consequences

**Positive:**
- Zero new operational dependencies; Postgres already runs.
- Outbox sink interface allows Kafka swap when scale demands it.
- `FOR UPDATE SKIP LOCKED` provides per-tenant ordering without cross-tenant contention.

**Negative:**
- Per-tenant ordering requires per-tenant batches (cycle-10 outbox sec-10.1).
- Cross-region outbox replication is W4+ work.

### Reversal cost

low (sink adapter swap)

## Pros and Cons of Options

### Option 1: Postgres outbox table + scheduled publisher

- Pro: No new operational dependency.
- Pro: One-method sink interface; Kafka is a drop-in replacement later.
- Pro: `FOR UPDATE SKIP LOCKED` is production-proven at the v1 scale.
- Con: Per-tenant ordering requires per-tenant publisher batches.
- Con: Not suitable beyond moderate throughput without moving to Kafka.

### Option 2: Kafka direct

- Pro: Proven at very high throughput with strong ordering guarantees.
- Con: Requires a Kafka cluster; operational overhead not justified at v1 scale.
- Con: Adds a dependency that must be secured, monitored, and upgraded.

### Option 3: NATS JetStream

- Pro: Lighter than Kafka; lower operational overhead.
- Con: Still adds a new operational surface beyond what v1 needs.
- Con: Less familiar to the customer's existing ops team.

## References

- `agent-runtime/outbox/ARCHITECTURE.md`
- `docs/cross-cutting/deployment-topology.md` sec-4

> NOTE 2026-05-12: `agent-runtime/outbox/ARCHITECTURE.md` moved to `docs/v6-rationale/v6-outbox.md` in 2026-05-12 Occam pass.
