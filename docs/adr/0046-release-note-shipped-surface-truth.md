# ADR-0046: Release-Note Shipped-Surface Truth Gate

> Status: accepted | Date: 2026-05-13 | Deciders: architecture team

## Context

After the L0 v1 architecture release (then at `docs/releases/2026-05-13-L0-architecture-release.en.md`, SHA `82a1397`; subsequently superseded by v2 and archived under `docs/archive/2026-05-13-l0-release-note-v1-superseded/`), a tenth review cycle was conducted as a release-note contract review (`docs/reviews/2026-05-13-l0-release-note-contract-review.en.md`). The reviewer found that all 25 prior gate rules passed but the release-note text itself overclaimed four W0 shipped surfaces:

| Finding | Overclaim | Truth |
|---|---|---|
| P1a | "`RunLifecycle` SPI" listed in W0 shipped runtime kernel | `RunLifecycle` is W2 design-only (ADR-0020); no Java class exists. The actual shipped orchestration SPIs are `Orchestrator`, `GraphExecutor`, `AgentLoopExecutor`, `SuspendSignal`, `Checkpointer`, `ExecutorDefinition`, `RunContext`. |
| P1b | "`RunContext` exposes `tenantId()`, `runId()`, `posture()`" | Actual interface (`agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/RunContext.java:16-37`) exposes `runId()`, `tenantId()`, `checkpointer()`, `suspendForChild(...)`. `posture()` is invented. |
| P2 | "`ApiCompatibilityTest` fails if the OpenAPI snapshot diverges" | `ApiCompatibilityTest` is ArchUnit-only (competitor-import ban + dependency-direction). The actual OpenAPI snapshot diff is `OpenApiContractIT` calling `OpenApiSnapshotComparator`. |
| P3 | `AppPostureGate` placed in "HTTP Edge (agent-platform)" table; described as "all runtime components receive posture as a constructor argument" | `AppPostureGate` lives in `agent-runtime/src/main/java/ascend/springai/runtime/posture/`. Only three in-memory components call it (`SyncOrchestrator`, `InMemoryRunRegistry`, `InMemoryCheckpointer`), not every runtime component. |

A fifth finding (P4 — `HEAD SHA: 82a1397` while `git HEAD` was `776d4e7`) was a HISTORY-PARADOX class defect addressed by renaming the field to `Semantic release SHA:` plus an explicit `Metadata follow-up SHAs:` line.

These four overclaims share a structural cause we hadn't named before. The 4-shape defect model (ADR-0045) covered REF-DRIFT, HISTORY-PARADOX, PERIPHERAL-DRIFT, and GATE-PROMISE-GAP. Each defect shape has dedicated gate enforcement. **But every gate is artifact-specific in its literal-token catalog**: Rule 24 scans `architecture-status.yaml`, Rule 25a scans SPI Javadoc, Rule 25b scans active markdown (excluding `docs/reviews/`, `docs/adr/`, `docs/delivery/`, `docs/plans/`, `docs/archive/`, `docs/v6-rationale/`). Rule 25b's exclusion list does **not** exclude `docs/releases/*.md`, but its token list (`Primary sidecar impl:`, `Sidecar adapter —`) didn't match any phrasing the release note used.

We name this fifth shape **GATE-SCOPE-GAP**: a truth-rule's pattern catalog is exhaustive *in shape* but its *token catalog* is artifact-specific. When a new artifact class enters the active corpus (release notes here, future W1/W2 release notes next), it inherits zero of the existing instrumentation until a rule with that class's tokens is added.

The 4-shape model remains canonical for the shapes it covers. GATE-SCOPE-GAP is a meta-shape that describes why an existing shape's gate misses a sibling artifact, not a new failure pattern in the artifact itself. We acknowledge it in the release-note narrative and address it with a dedicated Rule 26 rather than widening Rule 25.

## Decision Drivers

- Future release notes (W1, W2, …) must be mechanically checked for shipped-surface truth before publication.
- The rule must be narrowly scoped to release notes so it does not break legitimate ADR/review cross-references to past wrong claims.
- The rule must use the same case-sensitive PS pattern + POSIX-portable bash pattern + self-test fixture pattern that successfully landed Rules 24 and 25.
- The 4-shape defect model retains its canonical role; we add a fifth shape acknowledgment in narrative without renaming the four existing shapes.

## Decision

### Gate Rule 26 — `release_note_shipped_surface_truth`

Scoped to `docs/releases/*.md` (active release artifacts only). Implements four sub-checks under a single rule key:

**26a — RunLifecycle name guard.** A line containing the literal token `RunLifecycle` must either (i) appear in a one-line window (the line itself, the line above, or the line below) that contains a wave qualifier `W1`/`W2`/`W3`/`W4`, or (ii) appear on a line that contains one of `design-only`, `deferred`, `not shipped`, `remains design`, `materialised at W`. Otherwise the line is asserting a W0 shipped `RunLifecycle` SPI, which is false.

**26b — RunContext method-list guard.** A line containing the token `RunContext` together with at least one parenthesised method-name token (e.g. `tenantId()`, `posture()`) must (i) not contain `posture()`, and (ii) only list method-name tokens from the canonical set `{runId, tenantId, checkpointer, suspendForChild}`. Other tokens flag an invented method. (`RunContext` lines without method-list parentheses — pure references — are not flagged.)

**26c — OpenAPI snapshot test attribution.** A line that asserts the OpenAPI snapshot is enforced by a named test must reference `OpenApiContractIT` (and optionally `OpenApiSnapshotComparator`). Forbidden patterns: `ApiCompatibilityTest` co-occurring with `snapshot`/`OpenAPI.*spec`/`diverges` on the same line, in either order.

**26d — AppPostureGate scope guard.** Two forbidden patterns: (i) the substring `AppPostureGate` co-occurring with `HTTP Edge` on the same line (placement error — `AppPostureGate` lives in `agent-runtime`, not the HTTP edge module); (ii) the phrase pattern `all runtime components.*posture.*constructor` on a single line (breadth error — only the three in-memory components call the gate).

All four sub-checks fire under the single rule key `release_note_shipped_surface_truth`. Failure of any sub-check fails the rule with a sub-check-specific diagnostic identifying the file, line number, and remediation reference.

### Implementation

- `gate/check_architecture_sync.ps1` (Rule 26 block after Rule 25): `Get-ChildItem -Path 'docs/releases' -Filter '*.md' -File`; PS `-cmatch` for case-sensitive substring; ±1 line context window for 26a.
- `gate/check_architecture_sync.sh` (Rule 26 block after Rule 25): `find docs/releases -name '*.md' -type f`; POSIX `grep -nE`; `sed -n` for context-window extraction.
- `gate/test_architecture_sync_gate.sh` (TOTAL: 24 → 28): four cases — `rule26_runlifecycle_pos` (wave-qualified passes), `rule26_runlifecycle_neg` (unqualified fails), `rule26_runcontext_pos` (canonical methods pass), `rule26_runcontext_neg` (`posture()` fails).

Sub-checks 26c and 26d are exercised end-to-end by running the real gate against the corrected release note; we keep the self-test suite lean at four cases for the two most-failure-prone sub-checks (26a and 26b).

### §4 Constraint

**§4 #44 — Release-note shipped-surface truth.** Every shipped row in `docs/releases/*.md` must reference real Java symbols and real test classes; group labels must match either the actual Java surface or carry an explicit deferred/design-only qualifier. Method lists on shipped SPIs must be a subset of the canonical interface. Test attributions must name the test that actually performs the asserted check. Module placement and component-breadth claims must match the code's call sites. Enforced by Gate Rule 26.

## Rejected Alternatives

1. **Widen Rule 25 to add the four new tokens.** Rejected: Rule 25 is conceptually `peripheral_wave_qualifier` covering PERIPHERAL-DRIFT in SPI Javadoc and active markdown. Release-note shipped-surface truth is a distinct concept (GATE-SCOPE-GAP closure for the release artifact class). Keeping the rule keys distinct preserves diagnostic clarity.

2. **A prose-style global "no-overclaim" rule applied across the entire active corpus.** Rejected: too broad to gate mechanically. False-positive rate would be high (legitimate cross-references in ADRs, reviews, plans). Narrow per-artifact rules with specific token catalogs are the gate pattern that has worked for Rules 7, 13, 14, 16, 20, 25.

3. **A Java-symbol-reflection check that compares release-note method lists against the actual `.java` interface signatures at build time.** Rejected for L0: adds a build-system dependency on Javaparser or similar, expanding scope beyond a documentation-truth gate. Token-catalog matching covers the failure modes seen in the tenth review cycle; symbol reflection can be reconsidered if a new method-list overclaim shape emerges.

## Consequences

- Future release notes (`docs/releases/*.md` — W1, W2, …) are mechanically checked for the four shapes before commit; no new instrumentation needed when a new release artifact lands.
- The release-note authoring process now has a fail-fast feedback loop: write the note, run `bash gate/check_architecture_sync.sh`, fix any Rule 26 finding before publishing.
- The 4-shape defect model + GATE-SCOPE-GAP shape becomes the canonical five-shape lens that any future architecture review should use; ADRs ADR-0045 (REF-DRIFT + PERIPHERAL-DRIFT closure) and ADR-0046 (GATE-SCOPE-GAP closure) compose without overlap.
- Architecture baseline counts move from 43/45/25/24 to 44/46/26/28 (§4 constraints, ADRs, gate rules, self-tests).

## Documents Changed (this cycle)

| Document | Change |
|---|---|
| `docs/archive/2026-05-13-l0-release-note-v1-superseded/2026-05-13-L0-architecture-release.en.md` (then at `docs/releases/`) | SHA field renamed (`HEAD SHA:` → `Semantic release SHA:` + `Metadata follow-up SHAs:`); `AppPostureGate` row moved from HTTP Edge to Runtime Kernel and narrowed; `RunLifecycle` SPI row renamed to `Orchestration` SPI with W2 qualifier on `RunLifecycle`; `RunContext` method list corrected to actual interface; `ApiCompatibilityTest` correctly attributed to ArchUnit, `OpenApiContractIT` correctly attributed to OpenAPI snapshot diff; Posture Defaults section narrowed to three actual callers; baseline counts bumped to 44/46/26/28; tenth cycle row added; 4-shape table extended with GATE-SCOPE-GAP |
| `docs/adr/0046-release-note-shipped-surface-truth.md` | New ADR (this file) |
| `docs/adr/README.md` | ADR-0046 index row appended |
| `ARCHITECTURE.md` | §4 #44 added; header date refreshed |
| `docs/governance/architecture-status.yaml` | `release_note_shipped_surface_truth_gate` capability row added; `gate_architecture_sync.allowed_claim` counts bumped (43→44, 45→46, 25→26, 24→28); `adr_per_file.allowed_claim` corrected to "46 per-file MADR 4.0 ADRs (0001–0046)" |
| `gate/check_architecture_sync.ps1` | Rule 26 block added after Rule 25; banner updated |
| `gate/check_architecture_sync.sh` | Rule 26 block added after Rule 25; banner updated |
| `gate/test_architecture_sync_gate.sh` | TOTAL: 24 → 28; four Rule 26 self-tests added; banner updated |

## References

- Tenth-cycle review: `docs/reviews/2026-05-13-l0-release-note-contract-review.en.md`
- ADR-0020: RunLifecycle SPI separation + RunStatus formal DFA + transition audit (defines `RunLifecycle` as W2 design-only)
- ADR-0035: Posture enforcement single-construction-path (defines `AppPostureGate` placement and three callers)
- ADR-0045: Shipped-row evidence path existence (Gate Rule 24) and peripheral wave-qualifier (Gate Rule 25) — composes without overlap with this ADR
- `gate/check_architecture_sync.ps1` (Rule 26)
- `gate/check_architecture_sync.sh` (mirror)
- `gate/test_architecture_sync_gate.sh` (self-tests for Rule 26)
- `agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/RunContext.java:16-37` (canonical `RunContext` interface)
- `agent-platform/src/test/java/ascend/springai/platform/contracts/OpenApiContractIT.java` (canonical OpenAPI snapshot test)
- `agent-platform/src/test/java/ascend/springai/platform/api/ApiCompatibilityTest.java` (canonical ArchUnit test — not OpenAPI)
- `agent-runtime/src/main/java/ascend/springai/runtime/posture/AppPostureGate.java` (canonical posture-gate module)
