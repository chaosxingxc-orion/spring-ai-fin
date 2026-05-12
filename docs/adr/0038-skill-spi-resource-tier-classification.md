# 0038. Skill SPI Resource Tier Classification

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-13
**Technical story:** Seventh reviewer (P2.1) found that `SkillResourceMatrix` in ADR-0030 overstates
enforceability: `cpuMillis` and `maxMemoryBytes` cannot be enforced for in-process VETTED Java code
by the Orchestrator. Cluster 6 self-audit surfaced 8 hidden defects. This ADR splits the
`SkillResourceMatrix` into four enforceability tiers, making enforcement claims accurate.

## Context

ADR-0030 defines `SkillResourceMatrix` with 7 fields including `cpuMillis` and `maxMemoryBytes`.
The Orchestrator documentation (ARCHITECTURE.md §337-347) states "Orchestrator enforces declared
limits before init()" — which is factually too strong: CPU time and heap consumption of in-process
VETTED Java code cannot be reliably capped by the Orchestrator without a sandbox.

This creates a false enforcement assurance: operators may believe that a VETTED Java skill cannot
exceed its declared CPU/memory budget, when in fact only UNTRUSTED skills routed through a
non-NoOp `SandboxExecutor` provide that guarantee (ADR-0018, Rule 27).

## Decision Drivers

- Seventh reviewer P2.1: overstated enforcement claim must be corrected.
- Hidden defect 6.1: `SkillResourceMatrix` `cpuMillis` + `maxMemoryBytes` overstate enforceability for in-process VETTED Java.
- Hidden defect 6.3: `ADR-0030` VETTED→NoOpSandbox + CPU/memory fields compose to create false enforcement assurance.
- Hidden defect 6.2: ARCHITECTURE.md "enforces declared limits" too strong.

## Considered Options

1. **Split into 4 enforceability tiers; update ARCHITECTURE.md claim** — this decision.
2. **Remove cpuMillis and maxMemoryBytes from SkillResourceMatrix** — loses the advisory value for future sandbox integration.
3. **Add a Java SecurityManager-based enforcement** — SecurityManager is deprecated in Java 17+.

## Decision Outcome

**Chosen option:** Option 1.

### Four enforceability tiers (§4 #35)

| Tier | Fields | Enforcement point | When enforced |
|---|---|---|---|
| **Tier A — Hard-enforceable** | `tenantQuotaKey`, `globalCapacityKey`, `tokenBudget`, `wallClockMs`, `concurrencyCap`, trust tier, sandbox requirement | Orchestrator / ResilienceContract | W2; checked before init() |
| **Tier B — Sandbox-enforceable** | `cpuMillis`, `maxMemoryBytes` | SandboxExecutor (non-NoOp) | UNTRUSTED skills + non-NoOp sandbox (ADR-0018, Rule 27 W3) |
| **Tier C — Advisory/receipt** | Observed CPU time, observed wall clock, observed token count | SkillCostReceipt | Reported by skill on execute(); not enforced by Orchestrator |
| **Tier D — Skill-specific hints** | Custom fields declared by skill author | Skill implementation only | Not enforced by platform |

### Updated enforcement language

`ARCHITECTURE.md §337-347` is updated to:

> "The Orchestrator validates declared limits before init() and enforces the subset supported
> by the dispatch path (ADR-0038 Tier A). CPU/memory limits are sandbox-enforced (Tier B,
> UNTRUSTED + non-NoOp SandboxExecutor). Observed consumption is reported via SkillCostReceipt
> (Tier C); skill-specific hints are advisory only (Tier D)."

### ADR-0030 update

The `SkillResourceMatrix` Javadoc is updated to reference the tier classification. The record shape
is unchanged; the tier classification is a documentation constraint on how fields are interpreted.

### Consequences

**Positive:**
- Enforcement claims are now accurate per trust tier and dispatch path.
- Operators understand that VETTED Java skills cannot have CPU/memory enforced at W0-W2 without sandbox.
- Tier C (advisory receipt) retains the cost-receipt composability for Rule 13 (P1, deferred W3).

**Negative:**
- SkillResourceMatrix now has two classes of fields (enforced vs advisory) that look identical in the record.
  The tier classification must be documented carefully.

## References

- Seventh reviewer P2.1: `docs/reviews/2026-05-13-l0-architecture-readiness-agent-systems-review.en.md`
- ADR-0030: Skill SPI lifecycle + resource matrix (updated by this ADR)
- ADR-0018: SandboxExecutor SPI (Tier B enforcement mechanism)
- Rule 27 (deferred W3): posture-mandatory sandbox for UNTRUSTED skills
- `ARCHITECTURE.md §337-347` (updated language shipped this cycle)
- `architecture-status.yaml` row: `skill_resource_tier_classification`
