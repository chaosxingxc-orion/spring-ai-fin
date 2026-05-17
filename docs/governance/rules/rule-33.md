---
rule_id: 33
title: "Layered 4+1 Discipline"
level: L0
view: development
principle_ref: P-C
authority_refs: [ADR-0068]
enforcer_refs: [E55, E57]
status: active
kernel_cap: 8
kernel: |
  **Every architecture artefact (`ARCHITECTURE.md` section, `docs/adr/*.yaml`, `docs/L2/*.md`, `docs/reviews/*.md`) MUST declare two front-matter keys: `level: L0 | L1 | L2` and `view: logical | development | process | physical | scenarios`. The root `ARCHITECTURE.md` is the canonical L0 corpus; per-module `agent-*/ARCHITECTURE.md` files are L1; deep technical designs in `docs/L2/` are L2. Each level MUST organise its content under the 4+1 view headings; L2 MAY omit views not relevant to the feature. All change proposals in `docs/reviews/` MUST declare `affects_level:` and `affects_view:`. Phase-released L0/L1 artefacts are read-only — further edits MUST flow through `docs/reviews/`.**
---

## Motivation

This rule is the in-repo expression of the chief-architect doctrine (`docs/reviews/2026-05-14-architecture-governance-in-vibe-coding-era.en.md`): a flat ADR pile creates "tubular vision and context collapse" for both human reviewers and LLM agents — they remember constraint A and forget constraint B. View × level decomposition keeps each fragment small enough to load fully. The defect taxonomy from nine prior review rounds shows ~50% of all closed defects fall into the text-form drift family; structural decomposition is the primary mitigation.

## Cross-references

- Enforced by Gate Rule 37 (`architecture_artefact_front_matter`), Gate Rule 39 (`review_proposal_front_matter`), and `ArchitectureLayeringTest` (ArchUnit, agent-platform).
- Architecture reference: §4 #64, ADR-0068.
- Companion rule: Rule 34 ([`rule-34.md`](rule-34.md)) — Architecture-Graph Truth (graph encodes the joins between levels/views).
- Companion rule: Rule 48 ([`rule-48.md`](rule-48.md)) — Schema-First Domain Contracts (leaf-level taxonomy companion).
