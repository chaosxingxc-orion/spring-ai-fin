# 0026. Module Dependency Direction: agent-platform-contracts Split (W1)

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-12
**Technical story:** Fourth architecture reviewer (F2) identified that `ARCHITECTURE.md:91,127`
claims "`agent-platform` → SPI-only → `agent-runtime`, no reverse imports," but
`agent-runtime/pom.xml:18` declares a Maven compile-scope dependency on `agent-platform`. The
claimed direction is backwards relative to the Maven module graph at W0. This ADR documents
the W0 exception, defines the target architecture, and sets the exit criterion for eliminating
the exception at W1.

## Context

`agent-runtime` requires shared types for tenant context (`TenantContext`, `TenantConstants`)
and for the run contract (`Run`, `RunStatus`, `RunMode`, `RunStateMachine`, `SuspendSignal`,
`Checkpointer`, `RunContext`). At W0, these types were placed in `agent-platform` and
`agent-runtime` respectively, but to avoid circular Maven dependencies the current structure
has `agent-runtime` depending on `agent-platform` as a temporary workaround.

The `ApiCompatibilityTest` ArchUnit rule enforces only the forward direction (platform MUST NOT
depend on runtime). It does not catch the reverse Maven module dependency.

The root cause is that shared SPI types have no dedicated home module. The target fix is a
dedicated `agent-platform-contracts` Maven module that both `agent-platform` and `agent-runtime`
can depend on, without either depending on the other.

## Decision Drivers

- Clean compile-time dependency direction: a rule that all reviewers (human and automated) can
  verify by reading a single Maven module graph.
- Zero circular dependencies: the contracts module must depend on nothing else in this project.
- Minimal disruption: the split should be a pure file-move refactor — no new abstractions, no
  behavior changes.
- Gate coverage: after the split, `RuntimeNoPlatformDependencyTest` (ArchUnit) asserts
  `agent-runtime` packages never import `ascend.springai.platform.*`.

## Considered Options

1. **Document the W0 exception; never split** — update `ARCHITECTURE.md` to acknowledge the
   reverse dep as permanent. Cost: violates the stated architectural principle; sets a precedent
   for more "documented violations."

2. **Move all shared types into `agent-runtime`** — `agent-platform` depends on `agent-runtime`.
   This is the direction `agent-platform/pom.xml` would need to express. Benefit: no new module.
   Cost: contradicts the stated northbound/southbound separation; makes `agent-platform` depend on
   `agent-runtime` types, which is semantically backwards.

3. **Split `agent-platform-contracts` module (W1)** — create a new Maven module with no Spring
   deps. Move shared SPI types there. Both `agent-platform` and `agent-runtime` depend on it.
   Benefit: clean diamond dependency graph. Cost: one additional Maven module and a mechanical
   import-rename across both modules.

## Decision Outcome

**Chosen option 3: split at W1 — but W0 turned out to be already clean.**

Investigation revealed that `agent-runtime/src/main` and `agent-runtime/src/test` have **zero
imports** of `ascend.springai.platform.*`. The `pom.xml` dependency on `agent-platform` was a
speculative reference added in anticipation of future cross-module types, but no code ever used
it. The fix was simply to **remove the unused pom.xml dependency** — no contracts module
creation was required at W0.

**W0 (resolved):** `agent-runtime/pom.xml` dependency on `agent-platform` removed. Neither
module depends on the other at the Maven module level.

**W1 target (future):** Create `agent-platform-contracts` Maven module containing:

| Type | Current location | New location |
|------|-----------------|--------------|
| `TenantContext` | `agent-platform/...platform/tenant/` | `contracts/...contracts/tenant/` |
| `TenantConstants` | `agent-platform/...platform/tenant/` | `contracts/...contracts/tenant/` |
| `Run` | `agent-runtime/...runtime/runs/` | `contracts/...contracts/runs/` |
| `RunStatus` | `agent-runtime/...runtime/runs/` | `contracts/...contracts/runs/` |
| `RunMode` | `agent-runtime/...runtime/runs/` | `contracts/...contracts/runs/` |
| `RunStateMachine` | `agent-runtime/...runtime/runs/` | `contracts/...contracts/runs/` |
| `SuspendSignal` | `agent-runtime/...runtime/orchestration/spi/` | `contracts/...contracts/orchestration/` |
| `Checkpointer` (interface) | `agent-runtime/...runtime/orchestration/spi/` | `contracts/...contracts/orchestration/` |
| `RunContext` | `agent-runtime/...runtime/orchestration/spi/` | `contracts/...contracts/orchestration/` |

Concrete implementations remain in their current modules:
- `TenantContextHolder` (ThreadLocal) — stays in `agent-platform`
- `SyncOrchestrator`, `SequentialGraphExecutor`, `IterativeAgentLoopExecutor`,
  `InMemoryCheckpointer`, `InMemoryRunRegistry` — stay in `agent-runtime`

**Exit criterion:** `agent-runtime/pom.xml` dependency on `agent-platform` is removed and
replaced with a dependency on `agent-platform-contracts`. `RuntimeNoPlatformDependencyTest`
passes. `ApiCompatibilityTest` updated to assert the clean three-module graph.

### Consequences

**Positive:**
- Dependency direction in Maven matches the architecture diagram.
- `RuntimeNoPlatformDependencyTest` can mechanically enforce the contract.
- `agent-platform-contracts` is the canonical home for all types that cross module boundaries;
  future cross-module types have a clear home.

**Negative:**
- Package rename for 9 types (mechanical but invasive — every consumer import changes).
- One additional Maven module to maintain.

### Reversal cost

Medium: once done, reverting requires moving 9 types back and updating all imports again.

## References

- Fourth-reviewer document: `docs/reviews/2026-05-12-architecture-code-consistency-feedback.en.md` (F2)
- Response document: `docs/reviews/2026-05-12-fourth-reviewer-response.en.md`
- §4 #1 (revised dependency direction description)
- ADR-0021 (layered SPI taxonomy — W1 contracts module is Layer 1 of the taxonomy)
- `architecture-status.yaml` row: `module_dependency_direction_w0`
- `agent-runtime/pom.xml:18-25` (W0 exception)
- `ApiCompatibilityTest.java:37-44` (platform→runtime direction only at W0)
