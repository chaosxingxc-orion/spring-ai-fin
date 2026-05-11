# 0006. ActionGuard 5-stage chain (cycle-9 truth-cut), not 11-stage

**Status:** accepted (supersedes earlier 11-stage design from cycles 1-8)
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Cycles 1-8 over-specified ActionGuard to 11 stages; 6 of those were informational rather than enforced gates.

## Context

The ActionGuard component was originally designed with 11 stages across cycles 1-8.
A cycle-9 review found that 6 of those stages were informational documentation slots
rather than enforced checks. Retaining them created ambiguity about what was actually
gated and enlarged the surface area where a stage could be accidentally skipped.

## Decision Drivers

- Each remaining stage must map to an enforced check, not a documentation slot.
- Pre/Post evidence writers can fold into the Witness stage as audit and outbox writes.
- A smaller stage surface reduces the number of places where a stage can be skipped.
- OPA policies and test coverage must align with enforced stage boundaries.

## Considered Options

1. 5-stage: Authenticate / Authorize / Bound / Execute / Witness.
2. 11-stage as designed in cycles 1-8.
3. 3-stage (Authenticate / Decide / Witness) -- too coarse for OPA + budget + idempotency split.

## Decision Outcome

**Chosen option:** Option 1 (5-stage chain), because each of the five stages maps to
a concrete enforcement point and eliminating the 6 informational stages removes
ambiguity about what is actually gated.

### Consequences

**Positive:**
- Every stage is an enforced check; no documentation-only slots remain.
- Gate rule binds exclusively to 5-stage paths.
- Smaller surface reduces accidental stage-skip risk.

**Negative:**
- 11-stage documentation in `agent-runtime/action-guard/` and `docs/security-control-matrix.md` must move to `transitional_rationale`.

### Reversal cost

medium (chain class structure; OPA policies; tests)

## Pros and Cons of Options

### Option 1: 5-stage (Authenticate / Authorize / Bound / Execute / Witness)

- Pro: Every stage is enforced; no ambiguity about what is gated.
- Pro: Pre/Post evidence writers fold cleanly into Witness stage.
- Pro: Smaller surface reduces accidental skip risk.
- Con: Existing 11-stage documentation must be reclassified.

### Option 2: 11-stage as in cycles 1-8

- Pro: No documentation migration cost.
- Con: 6 of 11 stages are informational, not enforced; gating is ambiguous.
- Con: Larger surface increases accidental skip risk.

### Option 3: 3-stage (Authenticate / Decide / Witness)

- Pro: Minimal surface; very hard to skip a stage.
- Con: Too coarse to accommodate OPA authorization, budget bounds, and idempotency as separate enforced checks.

## References

- `agent-runtime/action/ARCHITECTURE.md`
- cycle-9 response sec-C1

> NOTE 2026-05-12: `agent-runtime/action/ARCHITECTURE.md` moved to `docs/v6-rationale/v6-action.md` in 2026-05-12 Occam pass.
