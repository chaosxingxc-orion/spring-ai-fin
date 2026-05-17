---
rule_id: 28
title: "Code-as-Contract (L1 Governing Rule)"
level: L0
view: scenarios
principle_ref: P-C
authority_refs: [ADR-0059]
enforcer_refs: [E28, E29, E30, E31, E32, E33]
status: active
kernel_cap: 12
kernel: |
  **Every active normative constraint MUST be enforced by code, registered in `docs/governance/enforcers.yaml`, and reach at least one of:**

  1. An **ArchUnit test** that fails when the constraint is violated.
  2. A **gate-script rule** in `gate/check_architecture_sync.sh` that exits non-zero.
  3. An **integration test** that asserts the observable behaviour.
  4. A **schema constraint** (NOT NULL / UNIQUE / CHECK / PRIMARY KEY) at the storage layer.
  5. A **compile-time check** (`@ConfigurationProperties` + `@Valid`, sealed types, package-info enforcement).
---

## Motivation

Prose normative constraints rot — reviewers forget them, agents skip them, and downstream PRs land that silently violate the rule the corpus claims to enforce. Rule 28 closes the loop by requiring every active normative constraint to be expressible as code, registered in the machine-readable enforcer index, and reachable through at least one of five enforcement surfaces (ArchUnit, gate script, integration test, schema constraint, compile-time check). The rule covers shipped AND deferred constraints, positive capabilities AND negative invariants ("X must NOT happen" requires an enforcer that detects X).

## Details

**Coverage discipline.** New normative constraints are gate-enforced via the meta-rule `constraint_enforcer_coverage` and sub-checks 28a–28j (path existence, anchor existence, hardcoded versions, prose-only markers, module count, mandatory tags, etc.). Per-sentence audit across `ARCHITECTURE.md` (root + per-module), ADR decision rules, and `docs/plans/*.md` is enforced via PR review under Rule 9 (Self-Audit Ship Gate) — no automated sentence scanner exists today.

**Scope.** Rule 28 covers shipped *and* deferred constraints, positive capabilities *and* negative invariants ("X must NOT happen" requires an enforcer that detects X).

**No deferred enforcers for active constraints.** An *active* constraint (any rule paragraph or ARCHITECTURE.md §4 entry whose status is `active_runtime_enforced` or `active_schema_enforced` per the Constraint State Taxonomy below) and its enforcer ship in the same PR. "Test deferred to next sprint" is forbidden for active constraints — drop the constraint or land the enforcer. *Deferred sub-clauses* (e.g. Rule 46.c, Rule 48.b, Rule 28k.b) and *design-only contracts* (`status: design_only` per Rule 62 / cross-constraint audit β-4) are explicitly permitted as long as each carries an explicit re-introduction trigger in `docs/CLAUDE-deferred.md` (or its own YAML file). They do NOT require a same-PR enforcer because they make no present-tense runtime claim.

**Constraint State Taxonomy** (added in v2.0.0-rc3 per cross-constraint audit β-4 / γ-3 to formalize the vocabulary that gate Rule 62 polices). Every contract YAML under `docs/contracts/*.v1.yaml` and the listed governance YAMLs (`skill-capacity.yaml`, `sandbox-policies.yaml`, `bus-channels.yaml`, `evolution-scope.v1.yaml`, `plan-projection.v1.yaml`) MUST declare a top-level `status:` field with one of:

| Status | Meaning | Enforcer requirement |
|---|---|---|
| `active_runtime_enforced` (or legacy alias `runtime_enforced`) | The contract is shipped and a runtime path enforces it today (e.g. registry boot validation, request-time check, ArchUnit test). | MUST have an enforcer row in `docs/governance/enforcers.yaml` referencing a real `*Test.java` / `*IT.java` / gate-script rule. |
| `active_schema_enforced` (or legacy alias `schema_shipped`) | The schema YAML is shipped + structurally validated (gate Rule 62 / similar), but the runtime consumer is deferred. | MUST have a gate-script row asserting the schema is well-formed; MAY defer the runtime consumer via a `docs/CLAUDE-deferred.md` sub-clause with a re-introduction trigger. |
| `design_only` | The contract is declared as design surface only; no schema validation, no runtime consumer. | MUST have a `docs/CLAUDE-deferred.md` entry with an explicit re-introduction trigger. MUST NOT use present-tense prose for runtime effects. |

A **separate vocabulary** at `docs/governance/architecture-status.yaml` per-capability rows uses `{design_accepted, implemented_unverified, test_verified, deferred_w1, deferred_w2}` (enforced by gate Rule 1). The two vocabularies are NOT interchangeable — `status:` in a contract YAML obeys the Constraint State Taxonomy above; `status:` in `architecture-status.yaml` obeys the gate-Rule-1 enum. Reviewers MUST NOT cross-cite values between them.

**Self-enforcement.** `docs/governance/enforcers.yaml` is the machine-readable cross-reference (every active constraint → ≥ 1 enforcer row → real artifact). Gate Rule 28 (`constraint_enforcer_coverage`) plus sub-checks 28a–28j police the index itself.

## Cross-references

- ADR-0059 — origin decision record.
- Architecture reference: §4 #45.
- Rule 9 (Self-Audit is a Ship Gate, Not a Disclosure) — per-sentence audit of constraints is performed under Rule 9 PR review.
- Rule 25 (Architecture-Text Truth) — Rule 25 is the architecture-text projection; Rule 28 is the broader code-as-contract discipline.
- Rule 48 (Schema-First Domain Contracts) — leaf-level companion: Rule 28 says enforce in code, Rule 48 says shape your taxonomy as schema-first.
- Deferred sub-clause 28k.b — schema↔Java-shape parity ArchUnit (W3 trigger).
