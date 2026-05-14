---
level: L0
view: scenarios
status: active
authority: "ADR-0068 (Layered 4+1 + Architecture Graph)"
---

# Session-Start Architectural Context

This is the canonical entry-point for any human contributor or LLM agent starting a new working session on `spring-ai-ascend`. Read this first. It contains the graph map; details live in the linked artefacts.

## TL;DR

The architecture lives in **two coupled forms** (per ADR-0068):

1. **Layered 4+1 corpus (human-facing)** — prose at three levels (L0 / L1 / L2), each organised by five views (logical / development / process / physical / scenarios).
2. **Architecture knowledge graph (machine-facing)** — `docs/governance/architecture-graph.yaml`, generated from authoritative inputs, encodes every relationship as an explicit edge.

**Do not read the 67 ADRs sequentially.** Start with the graph; drill into the prose only after you know which edge you are traversing.

## Reading order

| Step | Open | Purpose |
|---|---|---|
| 1 | `CLAUDE.md` | Rules 1–34 (the active constraint set) and the four Layer-0 principles P-A..P-D |
| 2 | `ARCHITECTURE.md` §0.4 | Layered 4+1 view map of root-level sections |
| 3 | `docs/governance/architecture-graph.yaml` | All relationships, machine-readable |
| 4 | `docs/governance/architecture-graph.mmd` (optional) | Mermaid render of the graph spine |
| 5 | `docs/governance/enforcers.yaml` | 59 rows mapping constraints to enforcers |
| 6 | `docs/governance/architecture-status.yaml` | Capability ledger (what is shipped / verified) |
| 7 | the ADR YAML referenced by the edge you are traversing | rationale and `extends:` / `relates_to:` |

## Graph traversal cheatsheet

To answer "which test ultimately enforces principle X?":

```
principle X
  --(operationalised_by)--> Rule-N           # principle → rule
  --(enforced_by)--> E<n>                    # rule → enforcer
  --(asserts_in)--> file:<path>#<anchor>     # enforcer → test/artefact
```

To answer "what does this test verify?":

```
file:<test-path>
  ←(asserts_in)-- E<n>                       # invert: artefact → enforcer
  ←(enforced_by)-- Rule-N                    # invert: enforcer → rule
  ←(operationalised_by)-- principle          # invert: rule → principle
```

To answer "what depends on / forbids importing module M?":

```
module:M
  --(may_depend_on)--> module:<allowed>
  --(must_not_depend_on)--> module:<forbidden>
```

To answer "which ADR superseded ADR-N?":

```
?
  --(supersedes)--> ADR-N
```

(Query the graph; `supersedes` and `extends` sub-graphs are DAGs validated by Gate Rule 38.)

## Editing rules in a session

Before editing any architectural artefact:

1. **Read the front-matter.** Every architectural file declares `level:` + `view:`. Edits change semantics; declare the level/view your change applies to.
2. **Write a `docs/reviews/` proposal first** if the artefact is L0 or L1 and is frozen (`freeze_id:` is set). Use `docs/reviews/_TEMPLATE.md`.
3. **Update the graph inputs, never the graph file.** Edit `enforcers.yaml`, `principle-coverage.yaml`, ADR YAML, or `module-metadata.yaml`. Then run `bash gate/build_architecture_graph.sh` to regenerate the graph. Rule 34 forbids hand-editing the graph.
4. **Run the gate.** `bash gate/check_architecture_sync.sh` exits 0. New Rule 33–34 gate rules (37–40) catch missing front-matter, broken edges, orphaned enforcers, and missing review-proposal tags.

## What is *not* a session-start input

These are part of the corpus but should NOT be read at session start:

- Individual ADRs unless an edge in the graph points at one.
- Archived plans under `docs/archive/`.
- Historical review files under `docs/reviews/2026-05-1[23]-*.md` (they are frozen evidence, not active guidance).
- `docs/CLAUDE-deferred.md` unless you are about to land a deferred rule.

## Mental model

> "The graph is the city plan. Prose ADRs are the deeds for individual lots. Read the map before you visit a property."

Authority: CLAUDE.md Rule 33 + Rule 34, ADR-0068.
