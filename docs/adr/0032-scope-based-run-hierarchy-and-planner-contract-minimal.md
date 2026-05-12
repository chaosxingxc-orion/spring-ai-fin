# 0032. Scope-Based Run Hierarchy and Planner Contract Minimal

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-13
**Technical story:** Sixth reviewer (LucioIT L1) found no scope discriminator on `Run`; any nested
run is implicitly swarm-capable. Seventh reviewer (P1.4) found `AgentLoopDefinition.planningEnabled(true)`
claimed in three places but absent in code. Cluster 1 self-audit surfaced 8 hidden defects around
hierarchy vocabulary and planning contract. This ADR names the scope axis and the minimal planner
contract without shipping code at W0.

## Context

`Run` expresses hierarchy through `parentRunId` and `RunMode`, but has no explicit scope
discriminator. A run nested via `SuspendSignal` could be a step-local sub-task or a peer agent in
a swarm delegation — the intent is invisible from the record.

`AgentLoopDefinition.planningEnabled` was mentioned in three documentation locations but does not
exist in `ExecutorDefinition.java`. The planning capability has no minimal type contract to anchor
future design.

## Decision Drivers

- Sixth reviewer L1: hierarchy should express scope (STEP_LOCAL vs SWARM), not just mode (GRAPH vs AGENT_LOOP).
- Seventh reviewer P1.4: removing a false claim and naming the minimal planner contract prevents W2 surprise.
- Hidden defects 1.1–1.8: `AgentLoopDefinition` accumulates 3 future-breaking changes (typed payload, plan-state, scope discriminator) without a unified migration plan.
- Rule 25 (Architecture-Text Truth): claims in docs must reflect reality.

## Considered Options

1. **Name scope axis + minimal planner contract (design-only at W0)** — this decision.
2. **Add RunScope Java field at W0** — introduces a DB column before Postgres schema exists.
3. **Defer entirely** — leaves reviewer L1 unaddressed and planningEnabled claim dangling.

## Decision Outcome

**Chosen option:** Option 1.

### RunScope taxonomy (§4 #29)

```
RunScope {
  STEP_LOCAL — a sub-task dispatched by the parent within the same logical flow.
               Lifecycle is bound to the parent; termination propagates upward.
  SWARM      — a peer agent delegated a goal independently. Lifecycle is autonomous;
               the parent awaits a result signal but does not own the child's lifecycle.
}
```

Field addition deferred to W2 alongside Postgres schema revision. At W0 the taxonomy is
named in ADR and §4 only. `SuspendReason.SwarmDelegation` variant addition also deferred
(sealed interface `SuspendReason` does not exist at W0 as runnable code).

### Planner contract minimal (§4 #29 extension)

`PlanState` and `RunPlanRef` are named as design contracts for the planner subsystem:

```java
// Design-only (W4+). No production code at W0.

/** Represents the decomposed execution plan for a goal. */
public record PlanState(
    UUID planId,
    String goal,
    List<PlanStep> steps,  // ordered list of RunPlanRef entries
    PlanStatus status      // PENDING | IN_PROGRESS | COMPLETED | FAILED
) {}

/** A reference from a parent Run to a planned child Run. */
public record RunPlanRef(
    UUID parentRunId,
    UUID plannedRunId,
    String stepKey,
    RunScope scope  // STEP_LOCAL or SWARM
) {}
```

`AgentLoopDefinition.planningEnabled` claim is removed from all active documents.
No `PlanState` or `RunPlanRef` code ships at W0; first implementation binding at W4
when the planner subsystem is scheduled.

### RunRepository.findRootRuns (shipped W0)

```java
/** Returns top-level runs for a tenant — runs with no parent (parentRunId == null). */
List<Run> findRootRuns(String tenantId);
```

Shipped in `RunRepository.java` + `InMemoryRunRegistry` (W0). Supports the scope
hierarchy principle by enabling callers to enumerate the root of each run tree.

### Consequences

**Positive:**
- Scope discriminator prevents W2/W3 schema decisions that conflate STEP_LOCAL and SWARM semantics.
- Planner contract naming prevents three more docs from accreting false claims about `planningEnabled`.
- `findRootRuns` ships now — small, low-risk, directly supports the hierarchy taxonomy.

**Negative:**
- `RunScope` field deferred to W2; `Run` record remains narrower than the named taxonomy until then.
- Two new record shapes (`PlanState`, `RunPlanRef`) are named but not implemented; must not be treated as stable API before W4.

## References

- Sixth reviewer L1: `docs/reviews/2026-05-12-architecture-LucioIT-wave-1-request.en.md`
- Seventh reviewer P1.4: `docs/reviews/2026-05-13-l0-architecture-readiness-agent-systems-review.en.md`
- ADR-0019: SuspendReason taxonomy (SwarmDelegation variant deferred here)
- ADR-0028: CausalPayloadEnvelope (initialContext + payload migration context)
- ADR-0039: Payload migration adapter strategy (Object → Payload → CausalPayloadEnvelope)
- `RunRepository.java`, `InMemoryRunRegistry.java` — findRootRuns shipped W0
- `architecture-status.yaml` rows: `scope_based_run_hierarchy`, `planner_contract_minimal`
