# 0003. Temporal Java SDK 1.35.0 for durable workflows, not Airflow / Step Functions

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Long-running runs (>30s) need crash-safe state, replay, cancellation, and signal-based extension.

## Context

Agent runs that exceed 30 seconds require crash-safe state persistence, deterministic
replay on worker restart, structured cancellation, and signal-based extension during
execution. A lightweight in-process state machine cannot satisfy these requirements
reliably. The orchestration layer must support workflow versioning to allow agent
evolution without breaking in-flight runs.

## Decision Drivers

- Customer can self-host (Temporal cluster on K8s), aligning with on-prem v1 deployment.
- Workflow versioning via `Workflow.getVersion` is exactly the pattern needed to evolve agents without breaking running workflows.
- Java SDK + activity-only-IO discipline is well-documented.
- Managed Temporal Cloud is an available upgrade path for operational simplicity.

## Considered Options

1. Temporal Java SDK 1.35.0 -- battle-tested; Java SDK; explicit `getVersion` for workflow evolution.
2. Apache Airflow / Prefect -- DAG-oriented; weaker at sub-second / signal-driven flows.
3. AWS Step Functions -- excellent at AWS but locks deployment to AWS.
4. Custom outbox-driven state machine -- minimum dependencies; maximum bugs.

## Decision Outcome

**Chosen option:** Option 1 (Temporal Java SDK 1.35.0), because it is the only option
that provides crash-safe replay, signal-driven extension, and self-hostable deployment
while remaining compatible with the Java stack.

### Consequences

**Positive:**
- Crash-safe replay with deterministic workflow re-execution.
- Signal-based extension supports long-running agent interactions.
- Self-hostable on K8s; managed cloud upgrade path available.

**Negative:**
- Temporal cluster is operational complexity not present in the rest of the stack.
- Team training required on Temporal workflow model and non-determinism constraints.
- Non-determinism lint becomes a CI gate requirement.

### Reversal cost

medium (sync-mode RunOrchestrator is still in tree as fallback for short runs)

## Pros and Cons of Options

### Option 1: Temporal Java SDK 1.35.0

- Pro: Crash-safe deterministic replay.
- Pro: `Workflow.getVersion` supports zero-downtime agent evolution.
- Pro: Self-hostable on K8s; Temporal Cloud available for ops simplicity.
- Con: Operational complexity of running a Temporal cluster.
- Con: Non-determinism constraints require team training and CI enforcement.

### Option 2: Apache Airflow / Prefect

- Pro: Mature DAG tooling with broad community.
- Con: DAG orientation is poorly suited to sub-second and signal-driven flows.
- Con: Weaker support for dynamic agent branching.

### Option 3: AWS Step Functions

- Pro: Fully managed; no cluster to operate.
- Con: Locks the deployment exclusively to AWS.
- Con: Incompatible with on-prem v1 customer requirement.

### Option 4: Custom outbox-driven state machine

- Pro: Zero new operational dependencies.
- Con: Re-implements solved problems (replay, versioning, signals) with high bug risk.
- Con: Difficult to evolve without breaking in-flight runs.

## References

- `agent-runtime/temporal/ARCHITECTURE.md`
- `docs/cross-cutting/oss-bill-of-materials.md` sec-3.2
