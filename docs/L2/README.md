---
level: L2
view: scenarios
status: scaffold
authority: "ADR-0068 (Layered 4+1 + Architecture Graph)"
---

# L2 — Technical Detailed Designs

This directory holds **L2** documents in the Layered 4+1 corpus defined by Rule 33 / ADR-0068.

## Scope

L2 documents are **per-feature** technical-detail designs that bind specific implementation classes, packages, sequences, and physical placements to the L0 / L1 contracts above. Each L2 document:

- Targets one feature or one use case (not a module, not the whole system).
- May omit views that are not relevant to the feature (Rule 33).
- Must declare `level: L2` + `view: {logical|development|process|physical|scenarios}` front-matter.
- Must link upward to the L1 module document(s) it specialises and the ADRs it implements.
- Lives here under `docs/L2/<feature-slug>/<view>.md` or `docs/L2/<feature-slug>.md`.

## Naming conventions

```
docs/L2/run-http-contract/logical.md         # L2, logical view, run HTTP contract
docs/L2/run-http-contract/process.md         # L2, process view, idempotency body lifetime
docs/L2/telemetry-vertical/development.md    # L2, development view, package layout
```

A single-file form (`docs/L2/<feature>.md`) is permitted when only one view is in scope.

## Gate behaviour

- Gate Rule 37 (`architecture_artefact_front_matter`): every file in this tree (excluding this README) must declare `level: L2` + `view:` front-matter.
- Gate Rule 38 (`architecture_graph_well_formed`): every L2 file must link upward to at least one L1 or L0 node (resolves through the `relates_to:` or `extends:` edges in the L2 front-matter).
- Gate Rule 39 (`review_proposal_front_matter`): proposals in `docs/reviews/` touching L2 files must declare `affects_level: L2`.

## Current contents

This directory ships empty at W1 entry. First L2 documents to land (post-W1):

| Slug | Trigger |
|---|---|
| `run-http-contract` | when authenticated `POST /v1/runs` matrix completes (closes P0-2 / P0-3 from L1 expert review) |
| `telemetry-vertical` | when W2 Hook SPI un-freezes |
| `idempotency-body-lifetime` | when `IdempotencyHeaderFilter` body-wrapper fix lands (closes P1-1) |

## Authority

- Rule 33 — Layered 4+1 Discipline (`CLAUDE.md`)
- Rule 34 — Architecture-Graph Truth (`CLAUDE.md`)
- ADR-0068 — Layered 4+1 + Architecture Graph as Twin Sources of Truth (`docs/adr/0068-layered-4plus1-and-architecture-graph.yaml`)
