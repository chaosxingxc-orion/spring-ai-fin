# ADR-0045: Shipped-Row Evidence Path Existence and Peripheral Wave-Qualifier Gate

> Status: accepted | Date: 2026-05-13 | Deciders: architecture team

## Context

The seventh reviewer's third pass (`docs/reviews/2026-05-13-post-seventh-l0-readiness-third-pass.en.md`)
identified four P1 blockers (P1.1–P1.4) and two P2 consistency findings (P2.1–P2.2). The user's
cross-cycle meta-analysis distilled the recurring root cause into **four defect shapes**:

| Shape | Recurring pattern |
|---|---|
| **REF-DRIFT** | References are syntactically valid but the target is wrong (non-existent file, stale wave window, wrong adapter). |
| **HISTORY-PARADOX** | A document is treated as both active and historical; its body is stale relative to current truth. |
| **PERIPHERAL-DRIFT** | Central canonical files were fixed but README/JavaDoc/sidebar prose still carries the old claim. |
| **GATE-PROMISE-GAP** | ARCHITECTURE.md/ADR narrative promises a general semantic rule; gate code enforces only a narrow literal. |

Previous ADRs (0042–0044) closed several instances. This ADR closes the two structural gaps the
third pass found that still escape existing gates:

1. **REF-DRIFT at shipped-row evidence level**: `l2_documents:` and `latest_delivery_file:` entries
   on `shipped: true` rows reference non-existent files. Gate Rule 7 covers `implementation:`; Gate
   Rule 19 covers `tests:`. No rule covered the other two evidence fields.

2. **PERIPHERAL-DRIFT at entry-point level**: SPI Javadoc and active markdown docs name future-wave
   implementations without a wave qualifier, producing the same "is it shipped or deferred?" ambiguity
   that the root README graphmemory row (P1.2) exhibited. Gate Rule 20 caught specific ghost class
   names in module READMEs; no rule caught unconditional impl-naming patterns in SPI Javadoc or
   module tables.

This ADR also codifies:
- The Rule 19 strengthening (absent, block-empty, and non-existent test paths — not just `tests: []`).
- The Rule 22 PowerShell case-sensitivity fix (`-cmatch`) and corpus widening (full
  ACTIVE_NORMATIVE_DOCS, not just `docs/contracts/*.md`).
- Archive of `docs/plans/W0-evidence-skeleton.md` (HISTORY-PARADOX fix — file was simultaneously
  listed as active L2 evidence and classified as historical by ADR-0043).

## Decision Drivers

- Prevent REF-DRIFT and PERIPHERAL-DRIFT from surfacing again in the next review cycle.
- Close the pattern at the gate level (structural prevention), not case-by-case (reactive patching).
- Gate rules must match the narrative contract claimed in ARCHITECTURE.md and ADRs.

## Decision

### Gate Rule 24 — `shipped_row_evidence_paths_exist`

Every `l2_documents:` entry and `latest_delivery_file:` value on a `shipped: true` capability row
in `docs/governance/architecture-status.yaml` must resolve to a file that exists on disk.

**Implementation:** Both `gate/check_architecture_sync.ps1` (Rule 24 block) and
`gate/check_architecture_sync.sh` (Rule 24 block) parse the YAML line-by-line, tracking
`shipped: true` blocks, and test each `l2_documents:` list item and each `latest_delivery_file:`
value with `Test-Path` / `[ -e ]`.

**Self-tests:** `gate/test_architecture_sync_gate.sh` — positive case (existing path passes) and
negative case (non-existent path detected).

### Gate Rule 25 — `peripheral_wave_qualifier`

SPI Javadoc in `agent-runtime/src/main/java` must not use `"Primary sidecar impl:"` or
`"Primary impl:"` without a wave qualifier (W0/W1/W2/W3/W4) in the surrounding ±3 line context.
Active normative markdown docs must not use `"Sidecar adapter —"` without a wave qualifier or an
ADR reference on the same line.

**Implementation:** Both gate scripts scan SPI Java files and active markdown files for these
patterns, then check context for wave qualifiers.

**Self-tests:** Positive case (wave-qualified impl claim passes) and negative case (unqualified
"Primary sidecar impl:" detected).

### Rule 19 strengthening

Gate Rule 19 (`shipped_row_tests_evidence`) is extended from literal `tests: []` detection to:

- `tests:` key absent on a shipped row → FAIL.
- `tests:` key present but block-empty (no list items) → FAIL.
- `tests:` key present with non-empty list where any path does not exist on disk → FAIL.

**Self-tests:** Four negative cases (absent, `[]`, block-empty, non-existent path) added to
`gate/test_architecture_sync_gate.sh`.

### Rule 22 fix

Gate Rule 22 (`lowercase_metrics_in_contract_docs`) is corrected:

- PowerShell `-match` replaced with `-cmatch` (case-sensitive) to prevent false-positive FAIL on
  compliant lowercase metric names (the `SPRINGAI_ASCEND_[a-z]` pattern with case-insensitive
  matching was firing on `springai_ascend_filter_errors_total`).
- Scan corpus widened from `docs/contracts/*.md` to full ACTIVE_NORMATIVE_DOCS (same exclusion list
  as Rule 18). The POSIX `grep -E` side was already case-sensitive; the corpus widening is mirrored.

### Archive of W0-evidence-skeleton.md

`docs/plans/W0-evidence-skeleton.md` was listed as active L2 evidence for the `architecture_sync_gate`
shipped capability while ADR-0043 classified `docs/plans/**` as HISTORICAL_EXCLUSIONS (with this file
as the sole exception). The file body contained stale W0 requirements (`/health`/`/ready` routes,
JPA entities, `RunStore`, `decision-sync-matrix.md`, `operator_gated`) that match no current W0
artifact. The file is archived to `docs/archive/2026-05-13-plans-archived/W0-evidence-skeleton.md`
and removed from `l2_documents:` in `architecture-status.yaml`. The real evidence for
`architecture_sync_gate` is the `implementation:` entries (gate scripts) and `tests:` entries.
ADR-0043's `docs/plans/**` exclusion is simplified to "entirely historical".

## §4 Constraints

**§4 #42:** Shipped-row evidence paths must resolve on disk (Gate Rule 24). See above.

**§4 #43:** Entry-point prose must carry wave qualifiers for future-wave impl claims (Gate Rule 25). See above.

## Documents Changed (this cycle)

| Document | Change |
|---|---|
| `docs/governance/architecture-status.yaml` | Header cycle tag; drop `l2_documents:` entries (both non-existent); fix `latest_delivery_file:` to actual path; update `allowed_claim` counts |
| `docs/plans/W0-evidence-skeleton.md` | Archived → `docs/archive/2026-05-13-plans-archived/W0-evidence-skeleton.md` |
| `docs/adr/0043-*` | `docs/plans/**` carve-out simplified to "entirely historical" |
| `README.md` | graphmemory-starter row: "Sidecar adapter — Graphiti REST" → W0 scaffold truth |
| `README.md` | Status string updated with third-pass scope |
| `ARCHITECTURE.md` | Last updated header; §4 #42–#43 added |
| `agent-platform/ARCHITECTURE.md` | Refresh header |
| `agent-runtime/ARCHITECTURE.md` | Refresh header; "Active submodules" → "Submodules (current + planned)" |
| `docs/contracts/contract-catalog.md` | Last refreshed header |
| `docs/contracts/http-api-contracts.md` | Last refreshed header |
| `docs/cross-cutting/oss-bill-of-materials.md` | Refresh cycle tag |
| `docs/cross-cutting/non-functional-requirements.md` | Refresh header |
| `docs/cross-cutting/posture-model.md` | Refresh header |
| `docs/observability/policy.md` | Refresh header |
| `agent-runtime/.../GraphMemoryRepository.java` | Javadoc: "Primary sidecar impl:" → wave-qualified "W1 reference sidecar" |
| `agent-runtime/.../RunRepository.java` | Javadoc: "W1-W2" → correct "W0 dev: InMemoryRunRegistry. W2: Postgres" |
| `agent-runtime/.../Run.java` | Javadoc: "W1-W2 backed by Postgres" → "W2: backed by Postgres. W0 dev: InMemoryRunRegistry" |
| `agent-runtime/.../IdempotencyRecord.java` | Javadoc: unconditional "W1: Postgres" → "W0: not persisted. W1: Postgres" |
| `gate/check_architecture_sync.ps1` | Banner; Rule 19 strengthened; Rule 22 `-cmatch` + widened; Rules 24 + 25 added |
| `gate/check_architecture_sync.sh` | Banner; Rule 19 strengthened; Rule 22 widened; Rules 24 + 25 added |
| `gate/test_architecture_sync_gate.sh` | Header; total updated to 20; tests for Rules 19/22/24/25 added |

## References

- Third-pass review: `docs/reviews/2026-05-13-post-seventh-l0-readiness-third-pass.en.md`
- ADR-0042: test-evidence enforcement for Rule 25 (Rule 19 origin)
- ADR-0043: active normative doc catalog and peripheral drift prevention (Rule 22 origin)
- ADR-0044: SPI contract precision and memory metadata reconciliation
- `docs/governance/architecture-status.yaml` (shipped capabilities ledger)
- `gate/check_architecture_sync.ps1` (Rules 19, 22, 24, 25)
- `gate/check_architecture_sync.sh` (mirror)
- `gate/test_architecture_sync_gate.sh` (self-tests for Rules 19, 22, 24, 25)
