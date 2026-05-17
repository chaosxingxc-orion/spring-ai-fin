---
rule_id: 34
title: "Architecture-Graph Truth"
level: L0
view: scenarios
principle_ref: P-C
authority_refs: [ADR-0068]
enforcer_refs: [E56, E58]
status: active
kernel_cap: 8
kernel: |
  **`docs/governance/architecture-graph.yaml` is the single machine-readable index of architectural relationships. It MUST be generated, never hand-edited, by `gate/build_architecture_graph.sh` from authoritative inputs (`docs/governance/principle-coverage.yaml`, `enforcers.yaml`, `architecture-status.yaml`, `module-metadata.yaml`, and the `docs/adr/*.yaml` corpus). The graph MUST encode at minimum these edge classes: `principle → rule`, `rule → enforcer`, `enforcer → test`, `enforcer → artefact`, `capability → test`, `module → module` (allowed / forbidden), `adr → adr` (`supersedes` / `extends` / `relates_to`), and `(level, view) → artefact`. The `supersedes` and `extends` sub-graphs MUST be DAGs. Every edge endpoint MUST resolve to a real graph node or file path. The build script MUST be idempotent — re-running on the same inputs MUST produce a byte-identical output.**
---

## Motivation

This rule operationalises the principle that an LLM cannot traverse what it has not been shown. The pre-existing YAML side-files (`enforcers.yaml`, `architecture-status.yaml`, etc.) are indexes but supply no joins; reasoning about which test ultimately enforces principle P-B today requires chaining through prose ADR citations the model has to ingest sequentially. The graph encodes those joins as first-class edges and the gate validates the joins close.

## Cross-references

- Enforced by Gate Rule 38 (`architecture_graph_well_formed`) and Gate Rule 40 (`enforcer_reachable_from_principle`).
- Architecture reference: §4 #65, ADR-0068.
- Companion rule: Rule 33 ([`rule-33.md`](rule-33.md)) — Layered 4+1 Discipline (the level × view structural substrate the graph indexes).
- Authoritative inputs: `docs/governance/principle-coverage.yaml`, `docs/governance/enforcers.yaml`, `docs/governance/architecture-status.yaml`, `<module>/module-metadata.yaml`, `docs/adr/*.yaml`.
