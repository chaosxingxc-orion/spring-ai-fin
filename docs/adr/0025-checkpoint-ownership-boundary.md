# 0025. Checkpoint Ownership Boundary: Executor Resume Cursors vs Orchestrator Run Row

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-12
**Technical story:** Fourth architecture reviewer (F1) identified that `ARCHITECTURE.md:161`
states "executors do not persist or wait," but `SequentialGraphExecutor` and
`IterativeAgentLoopExecutor` both call `ctx.checkpointer().save(...)` on suspension. This ADR
clarifies the ownership model so that both the architecture text and the code describe the same
invariant.

## Context

When a Run suspends, two categories of state must be persisted:

1. **Run row** (`RunStatus.SUSPENDED` + `suspendedAt` + `parentNodeKey`) — the orchestrator-level
   record that the scheduler/timer will use to trigger a resume. Owner: `Orchestrator`.

2. **Executor-local resume cursor** — the exact sub-position within the current executor where
   execution will restart (e.g., which graph node is next, or which loop iteration index to
   restart from). Owner: the executor that generated it, because only that executor knows the
   resume-cursor format.

The reviewer read "executors do not persist" as meaning executors have no persistence interaction
at all. The intent was that executors do not own the Run-row persistence. The wording was
ambiguous; both the code and the architecture document needed reconciliation.

## Decision Drivers

- Resume correctness: when `SyncOrchestrator` handles a `SuspendSignal` and later calls
  `run(resumedRun, definition)`, the executor must be able to reconstruct its exact position.
  Without the executor-local cursor, re-execution would restart from the beginning.
- Clean SPI boundary: `Checkpointer` SPI is the shared mechanism for opaque byte persistence.
  Executors are consumers of `Checkpointer`; the orchestrator is also a consumer (through
  `RunRepository`). Both roles are legitimate.
- Key namespace isolation: executor-written keys are reserved (`_` prefix) to prevent
  orchestrator code from accidentally colliding.

## Considered Options

1. **Move all persistence to the orchestrator** — executor signals which node/iteration it
   stopped at via a field on `SuspendSignal`; orchestrator writes both the Run row and the
   cursor. Benefit: single ownership. Cost: every new executor type must extend `SuspendSignal`,
   and the orchestrator must understand each executor's internal cursor format — leaky abstraction.

2. **Split ownership: executor writes cursor, orchestrator writes Run row** — each party writes
   what only it knows. Executor writes reserved-prefix checkpoint keys; orchestrator writes the
   Run row. Both writes happen in the same call stack (W0) or same transaction (W2).

3. **Eliminate executor-local cursors entirely** — executors restart from scratch on resume,
   using only the inputs from the Run row. Benefit: no cursor complexity. Cost: graph execution
   restarts from node 0 on every resume; loop restarts from iteration 0 — incorrect for
   long-running workflows.

## Decision Outcome

**Chosen option 2: split ownership.**

| Owner | What it writes | Keys / table |
|-------|---------------|--------------|
| `SequentialGraphExecutor` | next-node cursor | `_graph_next_node` (checkpoint key) |
| `IterativeAgentLoopExecutor` | iteration index + loop state | `_loop_resume_iter`, `_loop_resume_state` (checkpoint keys) |
| `SyncOrchestrator` | Run row status transition | `runs` table / `InMemoryRunRegistry` |

**Key namespace rule**: all executor-written checkpoint keys MUST start with `_`. No other code
may use `_`-prefixed keys via `Checkpointer`. This is documented in `Checkpointer.java` Javadoc.
Enforced at W2 by `CheckpointKeyNamespaceTest` (ArchUnit, deferred).

**Architecture text correction**: §4 #9 now reads:

> "Executors persist executor-local **resume cursors** via `Checkpointer.save()`; the
> `Orchestrator` persists the **Run row** via `RunRepository.save()`."

The old wording "executors do not persist or wait" is replaced.

### Consequences

**Positive:**
- Each component writes only what it knows; no leakage of cursor format across SPI boundary.
- Adding a new executor type (e.g., `TemporalActivityExecutor`) only requires defining its own
  cursor key namespace — no orchestrator changes.
- ADR-0024 atomicity contract still applies: both writes occur in the same call stack (W0) or
  same `@Transactional` block (W2).

**Negative:**
- Checkpoint key conventions are informal at W0 (javadoc only). Until `CheckpointKeyNamespaceTest`
  is activated at W2, a future developer could accidentally use a `_`-prefixed key from
  orchestrator code without a gate failure.

### Reversal cost

Low: renaming checkpoint key ownership is a refactor with no user-visible surface change.

## References

- Fourth-reviewer document: `docs/reviews/2026-05-12-architecture-code-consistency-feedback.en.md` (F1)
- Response document: `docs/reviews/2026-05-12-fourth-reviewer-response.en.md`
- §4 #9 (revised wording)
- ADR-0024 (suspension write atomicity — the atomicity contract for both writes)
- `architecture-status.yaml` row: `checkpoint_ownership_boundary`
- `SequentialGraphExecutor.java:44`, `IterativeAgentLoopExecutor.java:52`
