# 0014. 3-posture model (dev/research/prod), not 5 or 2

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-10
**Technical story:** Needed a small enum to drive default behaviors at boot across development, pre-production, and production environments.

## Context

The system's default behaviors (schema validation strictness, persistence backend,
scope requirement, fallback telemetry) must vary across development, internal staging,
and customer-facing environments. A single boot-time enum must cover all real
deployment targets without proliferating per-environment code paths.

## Decision Drivers

- Three levels cover the four real environments (dev laptop, internal staging, customer-pre-prod, customer-prod).
- Each level has clear, non-overlapping default semantics.
- Tests can be tagged per-posture, enabling posture-aware CI assertions.
- Fewer levels mean fewer defaults to maintain across every config table.

## Considered Options

1. dev/research/prod -- 3 levels; covers internal, pre-production, and production.
2. dev/staging/prod -- 3 levels but "staging" is less expressive than "research".
3. dev/test/staging/uat/prod -- 5 levels; too granular; each adds defaults to maintain.
4. dev/prod only -- 2 levels; too coarse; no place for "real-deps but not customer-data" mode.

## Decision Outcome

**Chosen option:** Option 1 (dev permissive / research strict with real deps / prod strict + harder),
because three levels map cleanly to the four real deployment environments and each level
has unambiguous semantics that tests and config tables can rely on.

### Consequences

**Positive:**
- Every posture-aware config table has exactly 3 columns; maintainability is uniform.
- Tests can be tagged per-posture; CI enforces posture-correct behavior.
- "research" mode provides a safe pre-production mode with real dependencies.

**Negative:**
- Every posture-aware default must define 3 values; no shortcuts.
- New config knobs require decisions for all 3 postures.

### Reversal cost

medium (tables in every L2 doc + bootstrap configuration)

## Pros and Cons of Options

### Option 1: dev / research / prod (3 levels)

- Pro: Three levels cover all four real deployment environments.
- Pro: Each level has unambiguous semantics for config table authors.
- Pro: Test tagging per-posture is straightforward.
- Con: Every new config knob must define 3 values explicitly.

### Option 2: dev / staging / prod

- Pro: Also 3 levels; "staging" is a common term.
- Con: "staging" is less expressive than "research"; does not signal "real deps but not customer data".

### Option 3: dev / test / staging / uat / prod (5 levels)

- Pro: Highest granularity; every environment has an explicit posture.
- Con: Each additional level multiplies the number of defaults to maintain.
- Con: Granularity beyond 3 levels adds complexity without proportional benefit.

### Option 4: dev / prod only (2 levels)

- Pro: Minimum complexity; only 2 columns in every table.
- Con: No place for a pre-production mode that uses real dependencies but not customer data.
- Con: Too coarse; "dev" and "prod" must each cover too wide a range of behaviors.

## References

- `docs/cross-cutting/posture-model.md`
- `agent-platform/bootstrap/ARCHITECTURE.md`
