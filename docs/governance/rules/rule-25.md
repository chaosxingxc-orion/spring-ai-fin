---
rule_id: 25
title: "Architecture-Text Truth"
level: L0
view: scenarios
principle_ref: P-A
authority_refs: [ADR-0025, ADR-0026, ADR-0027]
enforcer_refs: []
status: active
kernel_cap: 8
kernel: |
  **Every `shipped: true` row in `docs/governance/architecture-status.yaml` MUST have a non-empty `tests:` list pointing to a real test class. Every `implementation:` path MUST exist on disk. Every prose claim in `ARCHITECTURE.md` / `agent-*/ARCHITECTURE.md` that names an enforcer ("enforced by X", "asserted by X", "tested by X") MUST be backed by X actually performing the named assertion.**
---

## Motivation

Architecture documents that claim "enforced by X" without X actually running the assertion erode the trust signal that distinguishes shipped from designed. Once the corpus contains a single false-shipped claim, no reviewer can rely on any other claim without re-verifying. Rule 25 closes the loop: shipped rows cite real tests, implementation paths exist on disk, and prose enforcer claims are backed by enforcers performing the named assertion.

## Details

Path-existence violations caught by Gate Rule 7 (`shipped_impl_paths_exist`). Version-drift violations caught by Gate Rule 8 (`no_hardcoded_versions_in_arch`). Route-exposure violations caught by Gate Rule 9 (`openapi_path_consistency`). Module-dep-direction violations caught by Gate Rule 10 (`module_dep_direction`). Prose-enforcer claims without a real enforcer are a ship-blocking finding under Rule 9.

## Cross-references

- ADR-0025, ADR-0026, ADR-0027 — origin decision records.
- Architecture reference: §4 #24.
- Rule 9 (Self-Audit is a Ship Gate, Not a Disclosure) — prose-enforcer drift is the canonical ship-blocking finding.
- Rule 28 (Code-as-Contract) — Rule 25 is the architecture-text projection of the broader code-as-contract discipline.
