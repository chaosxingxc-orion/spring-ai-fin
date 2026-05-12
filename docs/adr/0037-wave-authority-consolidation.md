# 0037. Wave Authority Consolidation

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-13
**Technical story:** Seventh reviewer (P1.2) found both `roadmap-W0-W4.md` and
`engineering-plan-W0-W4.md` were stale with multiple contradictions versus `ARCHITECTURE.md`.
Cluster 4 self-audit surfaced 9 hidden defects including Spring AI version drift, LangChain4j
Python sidecar references, and a 32-dimension scoring framework that was superseded. This ADR
establishes a single wave authority and archives the two stale documents.

## Context

Two parallel planning documents existed alongside `ARCHITECTURE.md`, each claiming wave-level
authority:
- `docs/plans/roadmap-W0-W4.md`
- `docs/plans/engineering-plan-W0-W4.md`

Both lagged behind `ARCHITECTURE.md` in multiple dimensions: Spring AI version (1.0.x vs 2.0.0-M5),
W2 ActionGuard stage count (11 vs 5), Python sidecar scope (W2 vs excluded), and a 32-dimension
scoring framework that was superseded by the binary `shipped:` field in `architecture-status.yaml`.

Having three wave-authority documents guarantees drift. The reviewer is correct that this creates
confusion about what is actually planned.

## Decision Drivers

- Seventh reviewer P1.2: two planning docs contradict `ARCHITECTURE.md`; single authority needed.
- Hidden defects 4.1–4.8: specific contradictions documented between the three documents.
- Hidden defect 4.9: no single wave authority means each doc accretes independent drift.
- Rule 25 (Architecture-Text Truth): truth claims in docs must reflect code and current plan.

## Considered Options

1. **Archive both stale docs; declare `ARCHITECTURE.md` + `architecture-status.yaml` + `CLAUDE-deferred.md` as single wave authority** — this decision.
2. **Merge into one doc** — merging creates a fourth document that still needs to be kept in sync.
3. **Keep both docs but add a "last refreshed" enforcement gate** — doesn't eliminate the drift surface; just adds friction.

## Decision Outcome

**Chosen option:** Option 1.

### Single Wave Authority (§4 #34)

The authoritative sources for wave planning are, in priority order:

1. **`ARCHITECTURE.md`** — the primary wave-boundary and §4 constraint document.
2. **`docs/governance/architecture-status.yaml`** — per-capability shipped/deferred status.
3. **`docs/CLAUDE-deferred.md`** — deferred rules with re-introduction triggers.

Any document that contradicts these three sources is incorrect by definition. There is no other
wave-authority document.

### Archival

`docs/plans/roadmap-W0-W4.md` and `docs/plans/engineering-plan-W0-W4.md` are moved to:
- `docs/archive/2026-05-13-plans-archived/roadmap-W0-W4.md`
- `docs/archive/2026-05-13-plans-archived/engineering-plan-W0-W4.md`

Each archived file retains its content prefixed with a banner:

```
> **ARCHIVED 2026-05-13.** Historical planning document. Do not treat as current wave authority.
> Active wave authority: `ARCHITECTURE.md §1` + `docs/governance/architecture-status.yaml` +
> `docs/CLAUDE-deferred.md`. See ADR-0037.
```

The originals at `docs/plans/roadmap-W0-W4.md` and `docs/plans/engineering-plan-W0-W4.md` are
deleted to prevent two-copy drift.

### Consequences

**Positive:**
- Eliminates the surface that produces wave-plan contradictions.
- Future reviewers have a single authoritative answer to "what is in W2?"
- The 32-dimension scoring framework is silently archived and no longer cited.

**Negative:**
- `ARCHITECTURE.md` must carry more wave-boundary detail than before (already true; this just formalises it).
- Historical planning rationale is archived but not deleted — available for audit if needed.

## References

- Seventh reviewer P1.2: `docs/reviews/2026-05-13-l0-architecture-readiness-agent-systems-review.en.md`
- `docs/archive/2026-05-13-plans-archived/` — archive location
- `ARCHITECTURE.md` §1 — active wave authority
- `architecture-status.yaml` row: `wave_authority_consolidation`
