# 0041. Active-Corpus Truth Sweep

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-13
**Technical story:** Post-seventh L0 readiness follow-up (P1.1) identified eleven active documents
referencing `docs/plans/engineering-plan-W0-W4.md` — a plan archived on 2026-05-13 per ADR-0037.
Self-audit surfaced a twelfth hit (`docs/adr/0012-valkey-session-cache.md`) and a companion plan
(`docs/plans/architecture-systems-engineering-plan.md`) that now violates the single-wave-authority
principle. This ADR defines the active-corpus truth contract: archived plan paths must not appear
in active documents, and establishes Gate Rule 15 to prevent recurrence.

## Context

ADR-0037 (Wave Authority Consolidation, 2026-05-13) archived both `engineering-plan-W0-W4.md`
and `roadmap-W0-W4.md` to `docs/archive/2026-05-13-plans-archived/`. However, eleven active
documents continued referencing the original (now-deleted) path. Two failure modes:

1. **Dead link**: `docs/plans/engineering-plan-W0-W4.md` no longer exists at that path. Any
   reader following the reference gets a 404-equivalent.
2. **Authority confusion**: A reader seeing a reference to the planning document may treat it
   as an active authority, contradicting the wave-authority hierarchy established by ADR-0037.

Additionally, `docs/plans/architecture-systems-engineering-plan.md` self-described as a
"companion to `docs/plans/engineering-plan-W0-W4.md`" — it shared the same root authority and
therefore must be archived alongside its peer.

## Decision Drivers

- ADR-0037 §2 defines the active wave authority: `ARCHITECTURE.md §1` + `architecture-status.yaml`
  + `docs/CLAUDE-deferred.md`. All other planning artifacts are superseded.
- Historical ADRs benefit from pointing at the archived copy (not the wave authority) because
  their `## References` sections are evidentiary records of the decision context, not pointers
  to current guidance.
- Active normative documents (`ARCHITECTURE.md`, `oss-bill-of-materials.md`) should reference
  the wave authority, not the archived plan.

## Considered Options

1. **Update ADR references to archived copy; update active docs to wave authority; archive
   companion plan; add Gate Rule 15** (this decision).
2. **Delete all references to the archived plan** — loses the evidentiary chain in ADR `## References`
   sections.
3. **Restore the plan at its original path** — contradicts ADR-0037; the plan contains stale data.

## Decision Outcome

**Chosen option:** Option 1 — tiered correction.

### Correction strategy (§4 #38)

| Document type | Fix |
|---|---|
| Historical ADR `## References` | Replace `docs/plans/engineering-plan-W0-W4.md §N.N` with `docs/archive/2026-05-13-plans-archived/engineering-plan-W0-W4.md §N.N (archived per ADR-0037)` |
| Active normative docs (ARCHITECTURE.md, oss-bill-of-materials.md) | Replace with wave authority reference: `ARCHITECTURE.md §1 + docs/governance/architecture-status.yaml + docs/CLAUDE-deferred.md (per ADR-0037)` |
| Companion plan | Archive to `docs/archive/2026-05-13-plans-archived/architecture-systems-engineering-plan.md` with banner; delete original from `docs/plans/` |

### Documents corrected in this cycle

| File | Change |
|---|---|
| `docs/adr/0012-valkey-session-cache.md` | References → archived copy |
| `docs/adr/0018-sandbox-executor-spi.md` | References → archived copy |
| `docs/adr/0019-suspend-signal-and-suspend-reason-taxonomy.md` | References → archived copy |
| `docs/adr/0020-runlifecycle-spi-and-runstatus-formal-dfa.md` | References → archived copy |
| `docs/adr/0024-suspension-write-atomicity.md` | References → archived copy |
| `docs/adr/0028-causal-payload-envelope-and-semantic-ontology.md` | References → archived copy |
| `docs/adr/0030-skill-spi-lifecycle-resource-matrix.md` | References → archived copy |
| `docs/adr/0031-three-track-channel-isolation.md` | References → archived copy |
| `agent-runtime/ARCHITECTURE.md` | → wave authority reference |
| `docs/cross-cutting/oss-bill-of-materials.md` | → wave authority reference |
| `docs/plans/architecture-systems-engineering-plan.md` | Archived to `docs/archive/2026-05-13-plans-archived/` |
| `docs/archive/2026-05-13-plans-archived/README.md` | Added third archived doc to table |

### Gate Rule 15 (§4 #38)

`no_active_refs_deleted_wave_plan_paths` — active `.md` files (excluding
`docs/archive/`, `docs/reviews/`, `third_party/`, `target/`, `.git/`) must not contain
either of the deleted plan paths:
- `docs/plans/engineering-plan-W0-W4.md`
- `docs/plans/roadmap-W0-W4.md`

PowerShell selector for active docs:
```powershell
Get-ChildItem -Recurse -Filter *.md |
  Where-Object { $_.FullName -notmatch '\\docs\\archive\\|\\docs\\reviews\\|\\third_party\\|\\target\\|\\.git\\' }
```

### Consequences

**Positive:**
- Readers following ADR `## References` links reach a real file (archived copy) with a banner
  directing them to the active wave authority.
- Active normative docs point directly at the live authority layer, not a superseded planning
  artifact.
- Gate Rule 15 prevents recurrence; future commits that re-introduce deleted plan paths into
  active docs will fail the gate.
- Companion plan is no longer an orphan; it lives with its peer in the archive.

**Negative:**
- Gate Rule 15 excludes `docs/reviews/` from the scan: reviewer-submitted documents may
  reference the old path and that is acceptable (they are frozen historical artifacts).
- Any future archived document that legitimately references the archived plan path must ensure
  the file lands in an excluded directory.

### Reversal cost

Low — all changes are documentation-only. Restoring references would require touching the same
files listed above.

## References

- Post-seventh L0 readiness follow-up: `docs/reviews/2026-05-13-post-seventh-l0-readiness-followup.en.md` (P1.1)
- Response document: `docs/reviews/2026-05-13-post-seventh-l0-readiness-followup-response.en.md` (Cluster A)
- ADR-0037: Wave Authority Consolidation (motivation for archiving the plans)
- §4 #38 (new, this ADR): active-corpus truth contract
- Gate Rule 15: `no_active_refs_deleted_wave_plan_paths`
- `architecture-status.yaml` row: `active_corpus_truth_sweep`
- Archived plan at `docs/archive/2026-05-13-plans-archived/engineering-plan-W0-W4.md`
- Archived companion at `docs/archive/2026-05-13-plans-archived/architecture-systems-engineering-plan.md`
