# ADR-0042: Test-Evidence Enforcement for Rule 25 (Gate Rule 19)

> Status: accepted | Date: 2026-05-13 | Deciders: architecture team

## Context

CLAUDE.md Rule 25 ("Architecture-Text Truth [Active]") states that every `shipped: true` row in
`docs/governance/architecture-status.yaml` must have a non-empty `tests:` list pointing to a real
test class. Gate Rule 7 (`shipped_impl_paths_exist`) validates only the `implementation:` path
list; it does not check `tests:`.

**Confirmed violation:** `architecture_sync_gate` has `shipped: true` and `tests: []`. The gate
self-test at `gate/test_architecture_sync_gate.sh` exists and covers 6 rules; it is the correct
test evidence for this row but was never recorded in the YAML ledger.

**Root cause statement:** Gate Rule 7 validates implementation paths but the symmetric tests-list
constraint from Rule 25 is not gate-enforced. A future commit can add a `shipped: true` row with
`tests: []` and no gate will fail.

## Decision Drivers

- Rule 25 is normative: `shipped: true` claims test evidence as a condition.
- `gate/test_architecture_sync_gate.sh` already exists and provides partial-coverage evidence for the gate.
- The gate self-test was never referenced in the YAML, creating a false impression of an
  un-evidenced shipped row.

## Considered Options

1. **Mark `architecture_sync_gate` as `shipped: false`** — reduces the claim but is factually wrong; the gate is shipped and actively exercised.
2. **Add `gate/test_architecture_sync_gate.sh` to `tests:` and add Gate Rule 19** — closes the enforcement gap and makes the ledger truthful.

## Decision

**Option 2.** Populate `architecture_sync_gate.tests: [gate/test_architecture_sync_gate.sh]`, and
add Gate Rule 19 (`shipped_row_tests_evidence`) that fails every `shipped: true` row whose `tests:`
field is empty (`[]` or absent). Also update the gate self-test header to honestly declare that it
covers only Rules 1–6 (12 tests) as partial coverage; full gate verification requires running
`pwsh gate/check_architecture_sync.ps1` against the live repo.

## Consequences

**Positive:**
- Rule 25 prose and gate enforcement are consistent.
- Future contributors cannot accidentally add a `shipped: true` row without test evidence.
- The gate self-test header declares its coverage scope honestly.

**Negative:**
- Gate Rule 19 requires future developers to add test evidence before marking any capability as shipped — a small overhead that is the intended Rule 25 discipline.

## Gate Rule 19 Specification

**Name:** `shipped_row_tests_evidence`

**Check:** In `docs/governance/architecture-status.yaml`, every capability row with `shipped: true`
must have a `tests:` list with at least one entry. `tests: []` on a shipped row is a gate failure.

**Scope:** `docs/governance/architecture-status.yaml`.

**Excludes:** Rows with `shipped: false` or `shipped: null`.

## §4 Constraint

**§4 #39:** Every `shipped: true` capability row in `architecture-status.yaml` must have non-empty
`tests:` evidence (non-empty list of real test paths). Gate Rule 19 enforces this as a complement
to Rule 25 and Gate Rule 7. See ADR-0042, `shipped_row_tests_evidence`.

## References

- `docs/governance/architecture-status.yaml` (architecture_sync_gate row, lines 57–70)
- `gate/check_architecture_sync.ps1` Rule 7 (`shipped_impl_paths_exist`)
- `gate/test_architecture_sync_gate.sh` (existing gate self-test)
- CLAUDE.md Rule 25 (Architecture-Text Truth)
