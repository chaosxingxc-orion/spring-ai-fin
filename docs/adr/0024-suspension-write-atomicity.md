# 0024. Suspension Write Atomicity: Checkpointer and RunRepository Transactional Contract

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-12
**Technical story:** Third architecture reviewer raised Issue 9: no transaction boundary is defined between `Checkpointer` and `RunRepository`. When a Run suspends, two writes occur: (1) `RunRepository.save(run.withSuspension(...))` marks status `SUSPENDED`; (2) the executor writes a checkpoint via `RunContext.checkpointer()`. If either write succeeds while the other fails, the system is permanently inconsistent. This ADR defines the atomicity contract per durability tier.

## Context

The reviewer identifies two concrete failure modes:

**Scenario A**: `RunRepository.save(suspended)` succeeds; checkpoint write fails.
Result: `Run.status = SUSPENDED` but no checkpoint exists. Resume is impossible — the orchestrator
has no resume point; the run is stuck forever.

**Scenario B**: checkpoint write succeeds; `RunRepository.save(suspended)` fails.
Result: a checkpoint exists for the next execution step, but `Run.status = RUNNING` (or the save
exception propagates and the run never transitions). The scheduler/timer never triggers a resume.

At W0, these are theoretical: `SyncOrchestrator.executeLoop` is single-threaded; both writes happen
on the same call stack with no restart between them. At W2 Postgres, both scenarios are real.

## Decision Drivers

- W2 `PostgresOrchestrator` writes Run status to the `runs` table; checkpoint bytes to `run_checkpoints`
  table (or a `checkpoint_data` JSONB column on `runs`). Whether it's one table or two, a transaction
  boundary is mandatory.
- W2 `MultiBackendCheckpointer` (see `architecture-status.yaml: multi_backend_checkpointer`) may be
  Redis-backed — not in the Postgres transaction. The transactional outbox pattern (ADR-0007) handles this.
- W4 Temporal owns durability entirely; neither `RunRepository` nor `Checkpointer` is invoked for
  suspension writes.

## Considered Options

1. **Same Postgres transaction** — `RunRepository.save(suspended)` + `Checkpointer.save(payload)` in
   one `@Transactional` block. Requires both to use the same `DataSource`.
2. **Transactional outbox** — `RunRepository.save(suspended)` + pending outbox row in one Postgres txn;
   outbox publisher writes the Checkpoint store and clears the row; reconciliation sweeper handles crashes.
3. **Two-phase commit (XA)** — coordinates across multiple stores. Overkill; most Checkpoint backends
   do not support XA.
4. **Eventual consistency with idempotent resume** — checkpoint write retried independently; resume
   re-reads checkpoint on every attempt. Viable only if resume-from-beginning is safe (not always true).

## Decision Outcome

**Chosen option:** tiered — same transaction for Postgres Checkpointer; outbox for non-DB Checkpointer.

| Checkpointer backend | Atomicity strategy |
|---|---|
| W0 in-memory (`InMemoryCheckpointer`) | Single-threaded reference impl; sequential writes are effectively atomic. Documented in `SyncOrchestrator.executeLoop` javadoc. |
| W2 Postgres (`PostgresCheckpointer`) | Both `runs` and `run_checkpoints` in the same DataSource; single `@Transactional` block in the orchestrator state-transition method. |
| W2 Redis (`RedisCheckpointer`) | Transactional outbox: write `run_status=SUSPENDED` + `pending_checkpoint` row in one Postgres txn; outbox publisher writes Redis + deletes pending row; reconciliation sweeper re-drives stuck rows on restart. |
| W4 Temporal (`TemporalOrchestrator`) | SPI bypassed. `TemporalOrchestrator` does not call `RunRepository.save` or `Checkpointer.save` for suspension — Temporal workflow state machine is the atomic record. |

### W0 documentation (shipped now)

`SyncOrchestrator.executeLoop` Javadoc clarifies the single-thread atomicity invariant. See the
accompanying code edit.

### Rule 23 (deferred, W2 trigger)

Any W2+ `Orchestrator` implementation that performs the suspension pair MUST:
1. Document its atomicity strategy in Javadoc on the suspend-transition method.
2. Enforce it with an integration test that kills the JVM mid-write and asserts post-restart
   consistency (e.g., via `ProcessBuilder` + DB state check).

An implementation that cannot demonstrate this contract is a ship-blocking defect per Rule 9
(category: "Run lifecycle — checkpoint/resume atomicity").

### Consequences

**Positive:**
- W2 engineers have a clear, falsifiable contract.
- Redis-backed Checkpointer can be implemented safely using the established outbox pattern (ADR-0007).
- W4 Temporal bypass is explicit; no outbox needed for that tier.

**Negative:**
- W2 Postgres `@Transactional` block must encompass both SPI calls; this couples `RunRepository`
  and `Checkpointer` into the same transaction manager, which may be challenging if they use
  different `DataSource` beans (mitigation: use a single shared `DataSource` for both at W2).

### Reversal cost

Low for the documentation. Medium for the W2 implementation if the initial `PostgresOrchestrator`
misses the transaction boundary and must be retrofitted.

## References

- Third-reviewer document: `docs/reviews/Architectural Perspective Review` (Issue 9)
- Response document: `docs/reviews/2026-05-12-third-reviewer-response.en.md` (Cat-E)
- §4 #23 (suspension write atomicity)
- Rule 23 (deferred, W2): suspension write atomicity enforcement
- ADR-0007 (Postgres outbox pattern)
- `architecture-status.yaml` row: `suspension_write_atomicity_contract`
- W2 wave plan: `docs/archive/2026-05-13-plans-archived/engineering-plan-W0-W4.md` §4.2 (archived per ADR-0037)
