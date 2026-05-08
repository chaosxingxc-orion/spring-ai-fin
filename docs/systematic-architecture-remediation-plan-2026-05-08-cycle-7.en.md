# Systematic Architecture Remediation Plan - Cycle 7

Date: 2026-05-08
Reviewed HEAD: `93abdac`
Scope: `D:\chao_workspace\spring-ai-fin`
Review stance: strict architecture review after the cycle-6 remediation pass.

## Executive Verdict

Cycle 6 materially improved the architecture corpus: the RLS design now uses transaction-scoped `SET LOCAL` instead of a Hikari checkout reset myth, the auth model no longer treats `APP_JWT_SECRET` as the standard prod credential, the operator-shape smoke scripts exist in fail-closed form, and the evidence manifest now records the latest delivery-valid architecture-sync SHA.

The remaining architecture weakness is no longer primarily "missing prose." It is control-plane integrity. The project now has several governance artifacts, but they do not yet form a machine-enforced chain of custody from current HEAD to delivery evidence. The Windows architecture-sync gate crashes before producing structured results. The POSIX gate can pass at `93abdac` even though the authoritative manifest still points to `81ff802`. The manifest intentionally lags HEAD by one audit-trail commit, but the gate does not prove that the lag is exactly one commit, that the parent is the reviewed content SHA, or that the audit-trail commit only changed allowed evidence files.

Current ship posture:

- Architecture-sync gate, POSIX: semantic PASS at `93abdac`; generated `gate/log/93abdac-posix.json` during review.
- Architecture-sync gate, Windows: unusable; crashes before structured gate output.
- Authoritative manifest: still points to `81ff802`, not current HEAD `93abdac`.
- Delivery evidence: latest authoritative delivery file is `docs/delivery/2026-05-08-81ff802.md`.
- Rule 8 operator-shape gate: fails closed with `FAIL_ARTIFACT_MISSING` on both Windows and POSIX.
- Runtime implementation: still absent; no Maven manifests, Java source tree, migrations, or executable service artifact exist.

No runtime capability should be promoted beyond design evidence. The next remediation pass should focus less on adding more explanatory text and more on making the evidence graph executable, cross-platform, and self-testing.

## Review Evidence

Commands and observations:

- `git rev-parse --short HEAD` returned `93abdac`.
- `git rev-parse --short HEAD^` returned `81ff802`.
- `git show --name-only HEAD` shows the audit-trail commit changed only:
  - `docs/delivery/2026-05-08-81ff802.md`
  - `docs/governance/architecture-status.yaml`
  - `docs/governance/current-architecture-index.md`
  - `docs/governance/evidence-manifest.yaml`
  - `gate/log/81ff802-posix.json`
- `gate/check_architecture_sync.ps1` failed before structured output with: `Cannot bind argument to parameter 'Path' because it is null.`
- `gate/check_architecture_sync.sh` passed semantically at `93abdac` and wrote `gate/log/93abdac-posix.json`.
- `gate/run_operator_shape_smoke.ps1` exited 1 with `FAIL_ARTIFACT_MISSING`.
- `gate/run_operator_shape_smoke.sh` exited 1 with `FAIL_ARTIFACT_MISSING`.
- File inventory remains documentation/gate-only: `.md`, `.json`, `.yaml`, `.sh`, `.ps1`, `.gitignore`, `.gitkeep`. There are no build manifests or runtime source trees.

## Root-Cause Summary

Observed failure: the repository has a large governance corpus, but the current HEAD cannot be proven delivery-reviewed by a single cross-platform, self-consistent, machine-enforced evidence chain.

Execution path: cycle 6 produced architecture changes at `81ff802`, then added an audit-trail commit at `93abdac` containing delivery evidence for `81ff802`. The manifest documents that one-commit lag, and the POSIX gate accepts it as a warning-level trade-off. The Windows gate crashes before evaluating the same corpus because a cycle-6 README-to-files rule uses `$gateReadme` before assigning it.

Root cause statement: evidence validity is still implemented as a prose convention across manifest, delivery file, status ledger, index, and platform-specific scripts instead of as a tested evidence graph with one authoritative schema and equivalent Windows/POSIX enforcement.

Evidence:

- `gate/check_architecture_sync.ps1:335` calls `Test-Path $gateReadme` before `$gateReadme` is assigned at `gate/check_architecture_sync.ps1:382`.
- `docs/governance/evidence-manifest.yaml:25-35` says the manifest tracks the latest delivery-valid SHA, not current HEAD.
- `docs/governance/evidence-manifest.yaml:28` has `reviewed_sha: 81ff802`, while reviewed HEAD is `93abdac`.
- `docs/delivery/2026-05-08-81ff802.md:104` explicitly records strict HEAD equality as a structural trade-off, not done.
- `docs/governance/evidence-manifest.yaml:23` still says `schema_version: cycle-5-skeleton`.
- `docs/governance/evidence-manifest.yaml:110` still says `authoritative_index_last_updated_in_cycle: cycle-5` even though cycle 6 updated the index.

## Findings by Category

### A. Gate Runtime Integrity and Platform Parity

#### Finding A1 - P0 - Windows architecture-sync gate crashes before structured output

The PowerShell gate is not a valid W0 evidence producer at the reviewed HEAD. It exits with a PowerShell binding error before it can emit the structured JSON gate result. This is a hard governance defect because the project claims cross-platform gate coverage, but one platform cannot even complete the semantic scan.

Evidence:

- Reproduction command: `gate/check_architecture_sync.ps1`.
- Runtime error: `Cannot bind argument to parameter 'Path' because it is null.`
- `gate/check_architecture_sync.ps1:335` uses `$gateReadme`.
- `gate/check_architecture_sync.ps1:382` assigns `$gateReadme`.

Impact:

- Windows delivery-valid architecture-sync evidence cannot be generated.
- The cycle-6 README-to-files rule is not actually enforced by the Windows gate.
- Any future Windows-only contributor can bypass drift detection because the gate is operationally broken, not semantically red.

Correction:

1. Move `$gateReadme = 'gate/README.md'` and `$delReadme = 'docs/delivery/README.md'` into the shared variable initialization block before any rule uses them.
2. Add null-safe checks for every path variable consumed by `Test-Path`.
3. Add a gate self-test that runs both `check_architecture_sync.ps1` and `check_architecture_sync.sh` on a clean tree and asserts both emit parseable JSON.
4. Make a gate crash distinct from semantic failure: `gate_runtime_error` with `semantic_pass: false` and `evidence_valid_for_delivery: false`.

Exit criteria:

- PowerShell and POSIX gates both run to structured completion on clean HEAD.
- Both logs contain the same `script.version`, `sha`, `working_tree_clean`, `semantic_pass`, and `evidence_valid_for_delivery` semantics.
- A broken rule implementation cannot terminate before writing a machine-readable failure log.

#### Finding A2 - P1 - Windows and POSIX gate rule parity is already drifting

The POSIX script header describes cycle-6 behavior and implements delivery-log parity for `semantic_pass` and `evidence_valid_for_delivery`. The PowerShell script header still describes cycle-5 behavior, and its delivery-log parity rule only compares the log SHA to the filename.

Evidence:

- `gate/check_architecture_sync.sh:1-14` declares cycle-6 expanded behavior and key-field delivery parity.
- `gate/check_architecture_sync.ps1:1-12` still describes cycle-5 changes.
- `gate/check_architecture_sync.ps1:350-367` only checks the log SHA field.
- `gate/check_architecture_sync.sh:531-547` checks `sha`, `semantic_pass`, and `evidence_valid_for_delivery`.

Impact:

- A delivery file can be accepted by one platform and rejected by another.
- The weaker PowerShell implementation hides parity regressions exactly where Windows gate evidence is needed.
- Reviewers cannot treat "architecture-sync gate" as one capability; it is two partially divergent scripts.

Correction:

1. Extract gate rules into a single data-driven manifest, or generate platform scripts from one rule definition.
2. Until then, add a parity test that feeds the same fixture corpus to both scripts and compares failure categories.
3. Keep script headers synchronized with `version` in the emitted JSON.
4. Extend the PowerShell `delivery_log_parity` rule to match the POSIX semantic/evidence checks.

### B. SHA-Bound Evidence and Manifest Truth

#### Finding B1 - P0 - The evidence model accepts HEAD lag without proving the lag is safe

The cycle-6 manifest intentionally tracks `81ff802` while current HEAD is `93abdac`. The pattern can be valid if `93abdac` is a pure audit-trail commit whose parent is exactly the reviewed content SHA. However, that safety condition is currently documented, not enforced.

Evidence:

- Current HEAD: `93abdac`.
- Parent: `81ff802`.
- `docs/governance/evidence-manifest.yaml:28` says `reviewed_sha: 81ff802`.
- `docs/governance/evidence-manifest.yaml:31-35` says the manifest lags HEAD by exactly one audit-trail commit.
- `docs/delivery/2026-05-08-81ff802.md:7` says HEAD will be one commit ahead of `81ff802`.
- `docs/delivery/2026-05-08-81ff802.md:104` marks strict HEAD equality as a structural trade-off.

Impact:

- The project has two competing rules: the delivery README says evidence is SHA-current, while the manifest says evidence intentionally lags HEAD.
- A malicious or accidental audit-trail commit could change non-evidence architecture content and still be accepted if reviewers only inspect the manifest prose.
- The POSIX gate can produce a PASS at `93abdac` while the authoritative manifest still points to `81ff802`, which weakens the meaning of "current".

Correction:

Adopt an explicit two-SHA evidence model:

```yaml
reviewed_content_sha: 81ff802
evidence_commit_sha: 93abdac
evidence_commit_parent_sha: 81ff802
evidence_commit_classification: audit_trail_only
allowed_audit_trail_paths:
  - docs/delivery/**
  - docs/governance/architecture-status.yaml
  - docs/governance/current-architecture-index.md
  - docs/governance/evidence-manifest.yaml
  - gate/log/**
```

Gate rules:

1. If `HEAD == reviewed_content_sha`, delivery evidence is direct.
2. If `HEAD == evidence_commit_sha`, require `git rev-parse HEAD^ == reviewed_content_sha`.
3. Require `git diff --name-only reviewed_content_sha..evidence_commit_sha` to be a subset of `allowed_audit_trail_paths`.
4. Require the delivery file and gate log to name `reviewed_content_sha`.
5. Require the manifest to name both SHAs and the audit-trail classification.
6. Reject any other lag shape by default.

Exit criteria:

- The manifest no longer relies on a prose statement that it lags by one commit.
- The gate proves parentage and changed-path constraints.
- Reviewers can answer both questions mechanically: "What content was reviewed?" and "Which commit records the evidence?"

#### Finding B2 - P1 - Manifest freshness is presence-based, not graph-complete

The manifest freshness rule verifies that the manifest's `reviewed_sha` names an existing delivery file and log. It does not prove current HEAD coverage, parent-child audit-trail shape, status ledger consistency, current index consistency, or platform parity.

Evidence:

- `gate/check_architecture_sync.ps1:320-328` checks only delivery/log existence for `manifest.reviewed_sha`.
- `gate/check_architecture_sync.sh` passes at `93abdac` even though the authoritative manifest still points to `81ff802`.
- `docs/governance/evidence-manifest.yaml:25-26` says W1 will extend HEAD coverage later.

Impact:

- The manifest is not yet a source of truth; it is a partially checked pointer.
- Status, index, delivery, and log can drift again without a full graph failure.
- The architecture team can keep fixing prose drift cycle by cycle without eliminating the drift mechanism.

Correction:

1. Promote manifest validation from "freshness" to "evidence graph validation."
2. Validate these edges in one gate rule:
   - manifest to delivery file;
   - manifest to gate log;
   - delivery file to gate log;
   - manifest to current architecture index;
   - manifest to architecture-status latest SHA fields;
   - manifest to Rule 8 state;
   - manifest to current HEAD or approved audit-trail commit.
3. Fail when any edge is missing, stale, or contradictory.

#### Finding B3 - P2 - Manifest metadata is stale and weakens operator trust

The manifest has cycle-6 content but still declares itself as a cycle-5 skeleton. It also says the authoritative index was last updated in cycle 5, even though cycle 6 claims and commits an index update.

Evidence:

- `docs/governance/evidence-manifest.yaml:23` has `schema_version: cycle-5-skeleton`.
- `docs/governance/evidence-manifest.yaml:98-107` lists cycle-6 findings addressed.
- `docs/governance/evidence-manifest.yaml:110` has `authoritative_index_last_updated_in_cycle: cycle-5`.
- `docs/governance/current-architecture-index.md:85` says the cycle-6 delivery file is the current authoritative delivery evidence.

Impact:

- Operators cannot tell whether they are looking at a skeleton, a cycle-6 enforced schema, or a W1 target.
- The manifest looks less authoritative than the prose docs it is supposed to supersede.

Correction:

1. Rename `schema_version` to a real schema identifier such as `evidence-manifest/v2`.
2. Track `schema_capabilities` as machine-readable booleans: `head_coverage`, `delivery_log_parity`, `status_ledger_parity`, `rule_8_state_parity`.
3. Update `authoritative_index_last_updated_in_cycle` to the cycle that actually touched the index, or replace it with `authoritative_index_sha`.

### C. Rule 8 Operator-Shape Readiness and Runtime Existence

#### Finding C1 - P0 - Rule 8 still has only fail-closed absence evidence

The operator-shape smoke scripts now exist, which is better than prior cycles. But both scripts still fail closed because no runnable artifact exists. That is the correct behavior, but it means the architecture remains non-shippable by its own Rule 8.

Evidence:

- `gate/run_operator_shape_smoke.ps1` exits 1 with `FAIL_ARTIFACT_MISSING`.
- `gate/run_operator_shape_smoke.sh` exits 1 with `FAIL_ARTIFACT_MISSING`.
- Missing artifacts include `pom.xml`, `agent-platform/pom.xml`, `agent-runtime/pom.xml`, `agent-platform/src/main/java`, and `agent-runtime/src/main/java`.
- `docs/governance/evidence-manifest.yaml:112-120` records `artifact_present: false` and the same missing artifacts.

Impact:

- No artifact can be released.
- Architecture-sync PASS cannot authorize delivery to downstream users.
- Security controls such as RLS, ActionGuard, auth posture, prompt tainting, and sidecar trust remain design assertions until W0 produces executable paths and tests.

Correction:

1. Keep `operator_shape_smoke_gate` at L0 until a runnable W0 artifact exists.
2. Build the minimal Spring Boot service and module manifests before adding more control-plane prose.
3. Convert the fail-closed smoke gate into a real Rule 8 flow only after the artifact can start under a supervisor with real dependencies.

Exit criteria:

- Operator-shape smoke runs a long-lived managed process.
- It performs three sequential public-entry runs.
- It verifies real dependency access logs and metrics.
- It proves cancellation behavior.
- It asserts fallback count is zero.

#### Finding C2 - P0 - Security architecture is still not backed by implementation or tests

The architecture corpus now describes many correct controls, but the repo still contains no runtime code or test tree. This is acceptable for an L0/L1 design phase, but it must not be reported as tested, production-default, or operator-gated capability.

Evidence:

- File inventory contains documentation and gate scripts only.
- `docs/governance/evidence-manifest.yaml:112-120` records missing build and source artifacts.
- Many L2 documents reference future tests such as `PooledConnectionLeakageIT`, `PostureBootGuardIT`, and `SecretAssertionIT`, but those tests do not exist in the repository.

Impact:

- The strongest controls are still unverifiable at runtime.
- The architecture has no proof of dependency wiring, transaction boundaries, state persistence, cancellation, or tenant isolation.
- The risk profile is still design risk, not implementation risk.

Correction:

1. Treat referenced tests as acceptance criteria, not evidence.
2. Add a "test_reference_state" field to the manifest: `planned`, `exists`, `passing`, or `operator_gated`.
3. Fail the gate if a capability claims L2+ maturity while all test references are still planned-only.

### D. Governance Ledger, Maturity Language, and Corpus Hygiene

#### Finding D1 - P1 - Capability status language still competes with the L0-L4 maturity model

The current rules say capability status should use L0-L4 rather than legacy labels such as "implemented" or ad-hoc delivery terms. The status ledger now contains `maturity: L0`, which is good, but it still exposes lifecycle states such as `implemented_unverified` and `design_accepted` as primary status values.

Evidence:

- `docs/governance/architecture-status.yaml:6` defines statuses including `design_accepted`, `implemented_unverified`, `test_verified`, `operator_gated`, and `released`.
- `docs/governance/architecture-status.yaml:216-249` records `architecture_sync_gate.status: implemented_unverified` and `operator_shape_smoke_gate.status: design_accepted`.
- `gate/README.md:68-69` uses the same status language.

Impact:

- Readers can mistake `implemented_unverified` for a stronger claim than L0.
- Delivery notices can drift back into status inflation even while `maturity: L0` is present.
- The architecture team must maintain two classification systems.

Correction:

1. Make `maturity: L0-L4` the primary status field.
2. Rename the old lifecycle field to `evidence_state` if it is still needed for workflow tracking.
3. Update README and delivery templates to report capability maturity first.
4. Add a gate rule that rejects delivery language such as "implemented" unless the same row also declares the L-level and evidence state.

#### Finding D2 - P1 - Historical finding entries still use the old `operator_shape_gate` capability bucket

Cycle 6 split the gate model into `architecture_sync_gate` and `operator_shape_smoke_gate`, but many historical finding rows still attach architecture-sync remediation to the old `operator_shape_gate` capability. Historical traceability is useful, but the status ledger is also used as a current governance source, so capability keys should be normalized.

Evidence:

- `docs/governance/architecture-status.yaml:354-360` records architecture-sync scripts under `capability: operator_shape_gate`.
- `docs/governance/architecture-status.yaml:384-398` records architecture-sync scan/dirty-tree work under `capability: operator_shape_gate`.
- `docs/governance/architecture-status.yaml:400-406` records the missing operator-shape smoke script under the same bucket.
- `docs/governance/architecture-status.yaml:610-611` says cycle 6 split the single capability into two sub-capabilities.

Impact:

- Status queries by capability will mix architecture-sync evidence with Rule 8 operator-shape readiness.
- Future automation cannot cleanly answer "Is document sync green?" versus "Can the artifact run in operator shape?"

Correction:

1. Keep historical descriptions, but add normalized fields:
   - `legacy_capability: operator_shape_gate`
   - `capability: architecture_sync_gate` or `operator_shape_smoke_gate`
2. Add a gate rule that rejects new findings using the deprecated `operator_shape_gate` bucket.
3. Add a one-time migration note explaining that older rows were re-keyed for query correctness, not rewritten for history.

#### Finding D3 - P2 - Current governance docs contain visible encoding corruption

Several current governance files show mojibake tokens such as a corrupted section marker and a corrupted arrow marker. This is not a security defect, but it lowers trust in the governance corpus and makes automated text matching less reliable.

Evidence:

- `docs/governance/evidence-manifest.yaml:1-3` contains corrupted section-marker text.
- `docs/governance/current-architecture-index.md:60-75` contains corrupted arrow and section-marker text.
- `docs/delivery/README.md:1-3` contains corrupted punctuation in the title and references.

Impact:

- Humans cannot reliably distinguish intentional wording from encoding damage.
- String-based gates can miss or misread corrupted patterns.
- The corpus looks less mature than the governance model it describes.

Correction:

1. Normalize all current governance files to UTF-8.
2. Replace non-ASCII punctuation with ASCII where possible.
3. Add an encoding/printability check for current, non-historical governance files.
4. Exempt explicitly historical files only if they are banner-marked and excluded from active gates.

### E. Gate Testability and Failure-Mode Design

#### Finding E1 - P1 - The gate scripts have no self-tests, which allowed a basic variable-order defect to ship

The PowerShell crash is not a complex architecture issue. It is a script-order bug that a one-command gate self-test would have caught immediately. This shows that the governance layer itself lacks the same test honesty expected from the runtime architecture.

Evidence:

- `gate/check_architecture_sync.ps1` crashes on a clean current tree.
- No test fixture or CI-like script was found that runs both architecture-sync gates and parses their JSON result.
- The project has only two `.ps1` files and two `.sh` files, but no test harness for them.

Impact:

- New gate rules can make the gate less reliable while claiming to make governance stronger.
- Evidence production can fail operationally after a remediation cycle already claims the issue is addressed.

Correction:

1. Add `gate/test_architecture_sync_gate.ps1` or a portable test harness that:
   - runs both platform scripts;
   - asserts exit code semantics;
   - validates JSON schema;
   - checks expected failure categories on fixture docs.
2. Add at least one negative fixture for every rule category.
3. Require gate self-tests before any commit touching `gate/check_architecture_sync.*`.

## Systemic Remediation Plan

### W0.1 - Make the gate executable and cross-platform

1. Fix the PowerShell `$gateReadme` initialization defect.
2. Align PowerShell and POSIX rule coverage.
3. Add JSON schema validation for gate logs.
4. Add platform parity self-tests.
5. Run both architecture-sync gates on a clean tree.

### W0.2 - Replace prose evidence with an evidence graph

1. Replace `reviewed_sha` with explicit content/evidence commit fields.
2. Enforce audit-trail parentage and allowed changed paths.
3. Validate manifest-to-delivery-to-log-to-status-to-index edges.
4. Reject any manifest that cannot explain current HEAD.

### W0.3 - Keep Rule 8 fail-closed until there is an artifact

1. Do not reinterpret architecture-sync PASS as operator readiness.
2. Keep operator-shape smoke at `FAIL_ARTIFACT_MISSING` until W0 runtime exists.
3. Add minimal Maven/Spring Boot skeleton only when the three-layer test and Rule 8 plan are ready.

### W0.4 - Normalize governance status and encoding

1. Make L0-L4 maturity the primary status language.
2. Re-key historical findings from `operator_shape_gate` to split capabilities with `legacy_capability` preserved.
3. Clean UTF-8 corruption in active governance files.
4. Add a text-encoding check to the architecture-sync gate.

## Recommended Target Evidence Model

The project should distinguish "reviewed content" from "evidence commit" explicitly:

```yaml
version: 2
schema_version: evidence-manifest/v2

reviewed_content_sha: 81ff802
evidence_commit_sha: 93abdac
evidence_commit_parent_sha: 81ff802
evidence_commit_classification: audit_trail_only

delivery_file: docs/delivery/2026-05-08-81ff802.md
architecture_sync_logs:
  posix: gate/log/81ff802-posix.json
  windows: null

current_head_policy:
  accepted_shapes:
    - direct_reviewed_content
    - one_parent_audit_trail_only
  allowed_audit_trail_paths:
    - docs/delivery/**
    - docs/governance/architecture-status.yaml
    - docs/governance/current-architecture-index.md
    - docs/governance/evidence-manifest.yaml
    - gate/log/**

rule_8:
  state: fail_closed_artifact_missing
  pass_sha: null
```

This model preserves the audit-trail pattern without weakening SHA-bound evidence. It also gives future automation a precise contract.

## Definition of Done for the Next Remediation Pass

The next pass is complete only when all of the following are true:

1. `gate/check_architecture_sync.ps1` completes with structured JSON on Windows.
2. `gate/check_architecture_sync.sh` and `.ps1` enforce the same rule categories.
3. The manifest explains current HEAD through either direct SHA equality or verified one-parent audit-trail shape.
4. Delivery, manifest, status ledger, current index, and gate logs agree on the same reviewed content SHA.
5. No active governance file contains visible encoding corruption.
6. `operator_shape_smoke_gate` remains explicitly non-passing until a runnable artifact exists.
7. No capability row reports stronger than L0/L1 without real implementation and test evidence.

## Final Recommendation

The architecture team should pause additional L2 prose expansion and close the governance control-plane first. The current documents are now directionally strong, but the evidence machinery is still fragile. Fix the Windows gate, convert the manifest into a graph-validated schema, and make the audit-trail commit pattern machine-verifiable. After that, W0 implementation can begin with much less risk that security and readiness claims will drift away from the code.
