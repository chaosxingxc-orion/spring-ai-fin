# ADR-0047: Active-Entrypoint Truth and System-Boundary Prose Convention

> Status: accepted | Date: 2026-05-13 | Deciders: architecture team

## Context

After ADR-0046 + Gate Rule 26 closed the GATE-SCOPE-GAP for `docs/releases/*.md`, an eleventh review cycle (`docs/reviews/2026-05-13-l0-final-entrypoint-truth-review.en.md`) found two residual classes of active-entrypoint drift the prior gates did not catch:

| Finding | Failure shape |
|---|---|
| **P1 — Root README baseline drift** | At SHA `56f52e3` the root `README.md` Status paragraph still asserted "Forty-one architectural constraints ... `#1-#41`" while `docs/governance/architecture-status.yaml.architecture_sync_gate.allowed_claim` had advanced to "44 §4 constraints ... 46 ADRs ... 26 active gate rules ... 28 gate self-tests". The README and the canonical baseline can drift independently because no gate cross-checked them. (Resolved by content edit at `0ed6a35`; this ADR closes the gate gap so it cannot recur.) |
| **P2 — System-boundary prose drift** | Root `ARCHITECTURE.md §1` and `agent-runtime/ARCHITECTURE.md §1` described "drives LLMs through a tool-calling loop ... persists durable side effects through an idempotent outbox" in present tense, as if W0 ships those capabilities. The Java sources do not contain a production `LlmRouter`, `OutboxPublisher`, `ActionGuard`, or `RunController` at W0; those are W1–W4 deferred. The boundary section read as a description of running behavior. |

These map to two new defect shapes the 5-shape model from ADR-0046 did not name explicitly:

- **CANONICAL-DRIFT** — two artifacts both assert the same baseline fact (e.g. constraint count, ADR count) and can move independently. Without a cross-reference check, the visible-to-user artifact (README) stops matching the source-of-truth artifact (architecture-status.yaml).
- **TEMPORAL-OVERREACH** — entrypoint prose uses present tense for capabilities that are W1–W4 deferred, blurring the line between what runs today and what is contracted for the future. The reader cannot tell from §1 alone what is actually shipped.

A third finding (P3 — header metadata staleness across active docs) is real but secondary: the architecture-status.yaml is the canonical baseline statement; document headers tracking "Last updated" are best maintained as **content-change dates**, not **re-review dates**. We codify this as the header-metadata convention.

## Decision Drivers

- Catch CANONICAL-DRIFT mechanically before the README and the YAML diverge.
- Make the W0/W1–W4 boundary visible at the first §1 a developer reads.
- Avoid header-churn: not every review cycle should rewrite every document's header.
- Compose with the existing rules (24, 25, 26) without overlap.

## Decision

### Sub-decision A — Gate Rule 27 (`active_entrypoint_baseline_truth`)

The root `README.md` MUST contain the four architecture baseline counts currently asserted by `docs/governance/architecture-status.yaml.architecture_sync_gate.allowed_claim`:

- `<N> §4 constraints`
- `<N> ADRs`
- `<N>` followed by `gate rules` (with or without "active" qualifier)
- `<N>` followed by `self-tests` (with or without "gate" qualifier)

The gate extracts each `<N>` from the YAML's `allowed_claim` string via regex, then verifies the same numeric value appears in `README.md` paired with the same noun. A mismatch (either a missing count or a contradicting count) fails the rule with a diagnostic naming the expected value, the README's actual value, and the source of truth.

Implementation: PowerShell uses `[regex]::Matches` over the YAML line and `Get-Content` over README.md; bash mirrors with POSIX `grep -oE` and `awk`. The rule scopes to a single file (`README.md`) and a single ledger row, so it is fast and unambiguous.

Self-tests:
- **rule27_baseline_pos** — synthetic README containing all four matching counts → PASS.
- **rule27_baseline_neg** — synthetic README with a stale §4 count → FAIL.

Self-test total moves 28 → 30.

### Sub-decision B — Target-vs-W0 prose split

Every `ARCHITECTURE.md §1` system-boundary section (root + per-module) MUST present two clearly labeled views:

1. **Target architecture (W1–W4)** — present-tense description of the contract the platform commits to deliver.
2. **W0 shipped subset** — enumeration of what runs today, scoped to actual Java symbols and tests.

Capabilities staged for W1–W4 may appear in the target section. Present-tense claims like "drives LLMs", "persists via outbox", "audit-grade evidence" are forbidden in the W0 subset description unless the named Java symbol ships at W0.

This is enforced by review and by the §1 heading structure itself, not by a regex gate, because reviewer judgment is required to decide whether a given verb-clause crosses the line. The structure makes the line easy to inspect.

### Sub-decision C — Header-metadata convention

Document headers (`> Last updated: ...`) MUST track the **last content-change date**, not the most recent review-cycle date. A re-review without content changes does not justify a header bump.

Rationale: header dates serve a single purpose — pointing the reader at the most recent set of edits to inspect via `git log`. If a header date moves without a corresponding content change, the date loses signal. Architecture state is canonically asserted in `docs/governance/architecture-status.yaml` (capability ledger) + `docs/releases/` (formal release notes); headers do not need to duplicate that.

Practical effect: this cycle refreshes headers in only the files it actually edits (`ARCHITECTURE.md`, `agent-runtime/ARCHITECTURE.md`). The seven active docs flagged in the review (P3) that are not edited in this cycle keep their previous header dates — which honestly reflect "content last changed at the post-seventh third-pass cycle."

### §4 Constraint

**§4 #45 — Active-entrypoint truth and system-boundary prose convention.** Two sub-constraints, both under this ADR: (a) baseline cross-check (Gate Rule 27 — README counts match YAML allowed_claim), (b) target-vs-W0 prose split in §1 boundary sections. Header-metadata convention is codified here but enforced socially, not mechanically.

## Rejected Alternatives

1. **Header refresh for all 7 listed active docs.** Rejected: header-churn without content-change signal damages the header date's usefulness. Convention C addresses the underlying concern (when is this content current?) by pointing at architecture-status.yaml + release notes as canonical.

2. **A regex denylist for stale baseline tokens (`Forty-one`, `#1-#41`).** Rejected: brittle — every count advance requires updating the denylist. The chosen positive cross-reference (README must contain current YAML counts) handles all future advances automatically.

3. **Folding sub-decision B into Rule 25 (peripheral_wave_qualifier).** Rejected: Rule 25's pattern catalog is specific to peripheral-wave-qualifier shapes (`Primary sidecar impl:`, `Sidecar adapter —`). The §1 boundary-prose split is structural, not regex-detectable. Keeping it as a structural review-enforced rule preserves rule key clarity.

4. **A separate ADR for the header-metadata convention.** Rejected: convention C composes naturally with the active-entrypoint truth theme; carving it into a separate ADR creates index noise. It lives here.

## Consequences

- Future README updates that bump counts in `architecture-status.yaml` without updating `README.md` are caught at gate time.
- The W0/W1–W4 boundary is visible to a first-time reader from the §1 of every ARCHITECTURE.md they open.
- The 5-shape defect model from ADR-0046 now has two named successor shapes acknowledged in narrative: **CANONICAL-DRIFT** (closed by Rule 27) and **TEMPORAL-OVERREACH** (closed by §1 prose-split convention). The 5-shape table is not rewritten; these are forward-looking acknowledgments only.
- Architecture baseline moves 44/46/26/28 → 45/47/27/30 (§4 constraints, ADRs, gate rules, self-tests).

## Documents Changed (this cycle)

| Document | Change |
|---|---|
| `ARCHITECTURE.md` | §1 system-boundary section rewritten with target-vs-W0 split; §4 #45 added; header refreshed |
| `agent-runtime/ARCHITECTURE.md` | §1 system-boundary section rewritten with target-vs-W0 split; header refreshed |
| `docs/adr/0047-active-entrypoint-truth-and-system-boundary-prose-convention.md` | New ADR (this file) |
| `docs/adr/README.md` | ADR-0047 index row appended |
| `docs/governance/architecture-status.yaml` | `active_entrypoint_baseline_truth_gate` row added; `architecture_sync_gate.allowed_claim` counts bumped (44→45, 46→47, 26→27, 28→30); `adr_per_file.allowed_claim` corrected (46→47) |
| `docs/releases/2026-05-13-L0-architecture-release.en.md` | Baseline metrics table bumped; 11th historical-cycle row added |
| `README.md` | Baseline counts bumped to 45/47/27/30 |
| `gate/README.md` | Rule count 26→27; Rule 27 added to catalog; self-test coverage extended |
| `gate/check_architecture_sync.ps1` | Rule 27 block added after Rule 26; banner updated |
| `gate/check_architecture_sync.sh` | Rule 27 block added after Rule 26; banner updated |
| `gate/test_architecture_sync_gate.sh` | TOTAL 28 → 30; two Rule 27 self-tests added |

## References

- Eleventh-cycle review: `docs/reviews/2026-05-13-l0-final-entrypoint-truth-review.en.md`
- ADR-0045: shipped-row evidence + peripheral wave-qualifier (Gate Rules 24, 25)
- ADR-0046: release-note shipped-surface truth (Gate Rule 26) — composes without overlap with this ADR
- `gate/check_architecture_sync.ps1` (Rule 27)
- `gate/check_architecture_sync.sh` (mirror)
- `gate/test_architecture_sync_gate.sh` (self-tests for Rule 27)
- `docs/governance/architecture-status.yaml` — the canonical baseline statement Rule 27 cross-checks against
