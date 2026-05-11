# Systematic Architecture Remediation Plan - Cycle 6

Date: 2026-05-08
Reviewed HEAD: `06724c4`
Scope: `D:\chao_workspace\spring-ai-fin`
Review stance: strict architecture review after the cycle-5 remediation pass.

## Executive Verdict

Cycle 5 fixed meaningful architecture drift: the server RLS L2 no longer lists `HikariConnectionResetPolicy` as an active component, the RLS vocabulary gate now scans current L0/L1/L2 architecture files, the HS256 row in the security-control matrix now rejects prod explicitly, and architecture-sync logs now use platform suffixes.

The remaining issue is evidence governance. The project is very close to a usable documentation gate, but the current HEAD still cannot be treated as delivery-reviewed because the SHA-bound evidence chain is not closed. The latest committed delivery file is for `302337f`, while the reviewed HEAD is `06724c4`. The new manifest exists, but it is stale and still points to `a070a77`. The current architecture index is stale and says the cycle-5 delivery file will be added even though it already exists. The status ledger also still reports `operator_shape_gate.last_validated_sha: a070a77`.

Current ship posture:

- Architecture-sync scripts: semantically pass at `06724c4` when run locally.
- Committed architecture-sync delivery evidence: not current for `06724c4`.
- Rule 8 operator-shape evidence: still absent; fail-closed artifact-missing only.
- Runtime implementation: still absent; no Maven manifest, no Java source tree, no migrations.

No core runtime capability should be promoted beyond design evidence. The immediate work is to make the evidence model manifest-driven and current-SHA complete before W0 implementation begins.

## Review Evidence

Commands and observations:

- `git rev-parse --short HEAD` returned `06724c4`.
- `git status --short` was empty before the review commands.
- `gate/check_architecture_sync.ps1` returned PASS and generated `gate/log/06724c4-windows.json` with `semantic_pass: true` and `evidence_valid_for_delivery: true`.
- `gate/check_architecture_sync.sh --local-only` returned PASS semantically and wrote `gate/log/local/06724c4-posix.json`.
- `gate/run_operator_shape_smoke.ps1` exited 1 with `FAIL_ARTIFACT_MISSING`.
- `gate/run_operator_shape_smoke.sh` exited 1 with `FAIL_ARTIFACT_MISSING`.
- No `pom.xml`, `agent-platform/pom.xml`, `agent-runtime/pom.xml`, Java source tree, Gradle build, or SQL migration files exist.
- Latest committed delivery file: `docs/delivery/2026-05-08-302337f.md`.
- Latest committed cycle-5 audit log after that delivery: `gate/log/24b6735-posix.json`.
- No committed delivery file exists for `24b6735` or `06724c4`.

## Root-Cause Summary

Observed failure: the current HEAD has a local architecture-sync PASS, but the committed governance corpus still points to older evidence and cannot prove delivery validity for `06724c4`.

Execution path: cycle-5 generated delivery evidence for `302337f`, then additional audit-trail commits were added (`24b6735`, `06724c4`). The architecture-sync gate can produce a current log, but the delivery file, evidence manifest, current architecture index, and architecture-status ledger are not updated for the final reviewed SHA. The gate also does not enforce manifest freshness, delivery-log parity, README internal consistency, or status-ledger currentness.

Root cause statement: the evidence chain drifts because final-SHA evidence is still managed by human sequencing across multiple prose files instead of a single enforced manifest that binds current HEAD, delivery file, platform logs, status ledger, current index, and Rule 8 state.

Evidence:

- `docs/delivery/2026-05-08-302337f.md:6` says the delivery file is evidence only for `302337f`.
- `docs/governance/evidence-manifest.yaml` still has `reviewed_sha: a070a77`.
- `docs/governance/current-architecture-index.md:81-85` lists delivery evidence only through `a070a77` and says the cycle-5 delivery file will be added later.
- `docs/governance/architecture-status.yaml:229-230` still says the architecture-sync portion was last delivery-valid at `a070a77`.
- `gate/README.md:69-70` contradicts itself by saying the architecture-sync scripts pass at HEAD while the operator-shape smoke gate "does not exist"; the same README earlier says the smoke scripts exist in fail-closed form.

## Findings by Category

### A. SHA-Bound Evidence and Manifest Truth

#### Finding A1 - P0 - Current HEAD has no committed delivery evidence

The reviewed HEAD is `06724c4`, but the latest delivery file is `docs/delivery/2026-05-08-302337f.md`. That delivery file explicitly scopes itself to `302337f`. There is no committed delivery file for `06724c4`; the current log generated during review is untracked.

Impact:

- The repo still fails its own SHA-current rule for the reviewed HEAD.
- Reviewers cannot use committed evidence to prove `06724c4` is delivery-reviewed.
- The audit-trail commit pattern keeps creating a new HEAD after evidence has already been recorded.

Correction:

1. Stop adding ordinary commits after a delivery file is generated.
2. If an audit-trail commit is required, it must be followed by a new delivery file for that audit-trail SHA.
3. Add a final-SHA check that fails when `HEAD` lacks both:
   - `gate/log/<HEAD>-<platform>.json` with `evidence_valid_for_delivery: true`;
   - `docs/delivery/<date>-<HEAD>.md` referencing that log.

Exit criteria:

- The final reviewed SHA has committed delivery evidence.
- No later commit exists after the newest delivery file unless that later commit has its own delivery file.

#### Finding A2 - P0 - Evidence manifest is stale and not enforced

`docs/governance/evidence-manifest.yaml` was introduced in cycle 5, but it still points to `a070a77`, not `302337f`, `24b6735`, or `06724c4`. The manifest claims to bind delivery, logs, findings, index, and Rule 8 state, but the gate does not enforce this binding.

Impact:

- The manifest exists but is not the source of truth.
- Delivery files and logs can advance while the manifest remains stale.
- The project has two competing evidence narratives: prose delivery and stale YAML.

Correction:

1. Update the manifest in the same commit as every delivery file.
2. Make `manifest_freshness` a W0 gate, not W1, because the manifest is already present.
3. Validate:
   - `reviewed_sha` equals the delivery file SHA;
   - delivery file path exists;
   - every listed architecture-sync log exists and has matching `sha`, `platform`, and `evidence_valid_for_delivery`;
   - `rule_8_state` matches the operator-shape logs or artifact absence.

Exit criteria:

- The manifest describes the newest delivery evidence and never lags behind committed delivery files.

#### Finding A3 - P1 - Current architecture index is stale

The current architecture index still lists delivery evidence only through `a070a77` and says the cycle-5 delivery file will be added after the PR lands. The cycle-5 delivery file now exists, but the index was not updated.

Impact:

- The index is no longer a reliable entry point for reviewers.
- Engineers following the authoritative index are pointed at old evidence.
- The promised `current_architecture_index_freshness` control is still deferred while the index is already being used.

Correction:

1. Update the delivery evidence section to include `2026-05-08-302337f.md` and the latest final-SHA evidence once generated.
2. Add a gate rule that rejects an index claiming "will be added" for a delivery file that already exists.
3. Tie index freshness to the manifest.

Exit criteria:

- The index points to the newest committed delivery evidence and clearly says whether that evidence covers the current HEAD.

#### Finding A4 - P1 - Status ledger currentness is inconsistent with delivery evidence

`architecture-status.yaml` reports `operator_shape_gate.last_validated_sha: a070a77`, while the cycle-5 delivery file records an architecture-sync PASS at `302337f`, and a later committed log exists for `24b6735`. Cycle-5 findings are present, but the status capability summary is stale.

Impact:

- The ledger is not the source of truth for validation state.
- Delivery files and governance status can diverge.
- Capability maturity claims remain hard to audit.

Correction:

1. Split `operator_shape_gate` into explicit sub-capabilities:
   - `architecture_sync_gate`;
   - `operator_shape_smoke_gate`.
2. Track independent fields:
   - `latest_semantic_pass_sha`;
   - `latest_delivery_valid_sha`;
   - `latest_delivery_file`;
   - `rule_8_pass_sha`.
3. Update those fields from the manifest, not by hand.

Exit criteria:

- The status ledger agrees with the manifest and newest delivery file.

### B. Gate Coverage and Cross-Platform Evidence

#### Finding B1 - P1 - Cross-platform evidence is structurally possible but not actually complete

Cycle 5 fixed log overwriting by adding `-posix` and `-windows` suffixes. However, the committed cycle-5 delivery evidence records only the POSIX architecture-sync run. It says the Windows run "will write" evidence when invoked. No committed `302337f-windows.json` exists.

Impact:

- The repository cannot claim both platforms passed for `302337f`.
- The DoD wording overstates "Windows + POSIX gate results both preserved"; only POSIX was preserved for that delivery.
- Windows gate health still depends on reviewer reruns.

Correction:

1. Require both platform logs before a delivery file can say cross-platform evidence is complete.
2. If only one platform ran, the delivery file must say POSIX-only or Windows-only.
3. Add a combined evidence manifest that lists required and optional platforms per cycle.

Exit criteria:

- Delivery files either include both platform logs or explicitly state the missing platform as a gap.

#### Finding B2 - P1 - Gate README still has stale operator-shape status text

`gate/README.md` correctly states that operator-shape smoke scripts exist in fail-closed form, but its status section still says the smoke gate does not exist and remains a W0 deliverable.

Evidence:

- `gate/README.md:35-40` says scripts exist and fail closed.
- `gate/README.md:69-70` says the smoke gate does not exist.

Impact:

- Operators see contradictory gate status in the same file.
- The architecture-sync gate does not catch README internal contradictions.

Correction:

1. Rewrite the status section to match the implemented fail-closed script state.
2. Add a `readme_to_files` rule:
   - if `gate/run_operator_shape_smoke.ps1` and `.sh` exist, no current README may say the smoke gate does not exist;
   - if they fail closed, README must say "exists, fail-closed, not Rule 8 PASS evidence."

Exit criteria:

- `gate/README.md` has one consistent operator-shape status.

#### Finding B3 - P1 - Delivery-log parity remains deferred while drift keeps recurring

Cycle 5 fixed one delivery/log mismatch, but the parity rule remains deferred to W1. The current evidence model still relies on manual transcription of log fields into Markdown.

Impact:

- A future `scan_files_count`, `script`, `platform`, or `sha` mismatch can recur.
- Reviewers must manually compare delivery files and JSON.

Correction:

1. Implement `delivery_log_parity` now.
2. Parse the referenced JSON logs from every delivery file.
3. Reject mismatches in `sha`, `script`, `platform`, `semantic_pass`, `working_tree_clean`, `local_only`, `evidence_valid_for_delivery`, and `failures`.

Exit criteria:

- A delivery Markdown file cannot disagree with its referenced log.

### C. Security and Runtime Architecture

#### Finding C1 - P1 - Auth L2 still has one ambiguous HMAC/prod test row

The security-control matrix now says HS256 is rejected in prod. The auth L2 posture table also says prod has no HS256 path. However, the auth L2 test table still says "Reject weak HMAC secret at boot | research/prod boot fails if APP_JWT_SECRET < 32 bytes." That wording can be read as implying `APP_JWT_SECRET` is a prod boot input.

Evidence:

- `agent-runtime/auth/ARCHITECTURE.md:55-59` says prod uses RS256/ES256 with JWKS and no HS256 path.
- `agent-runtime/auth/ARCHITECTURE.md:193` says `APP_JWT_SECRET` is asserted only when `HmacValidator` is active.
- `agent-runtime/auth/ARCHITECTURE.md:234` says research/prod boot fails if `APP_JWT_SECRET` is weak.

Impact:

- The test plan can accidentally reintroduce prod HMAC semantics.
- Implementers may add a prod HMAC secret check instead of rejecting HMAC activation under prod.

Correction:

1. Rewrite the test row to:
   - "Weak HMAC secret rejected when HmacValidator is active under dev loopback or research BYOC carve-out."
   - "Prod boot rejects HmacValidator activation regardless of secret length."
2. Extend the HS256/prod gate beyond `docs/security-control-matrix.md` to current auth L2 docs.

Exit criteria:

- No current auth document implies `APP_JWT_SECRET` is a standard prod input.

#### Finding C2 - P0 - Rule 8 still has no runnable artifact

Both operator-shape smoke scripts fail closed because no runnable artifact exists. This is honest and better than a placeholder, but it is not readiness evidence.

Impact:

- No ship authorization exists.
- No L3 capability claim is valid.
- No long-lived process, real dependencies, sequential public-entry runs, resource reuse, cancellation, lifecycle observability, or fallback-zero assertion has been proven.

Correction:

1. Keep all runtime capabilities below L3.
2. Make W0 produce the minimal runnable artifact:
   - root Maven manifest;
   - `agent-platform` and `agent-runtime` module manifests;
   - minimal Spring Boot entry point;
   - health/readiness endpoints;
   - real or explicitly configured local Postgres dependency.
3. Convert `run_operator_shape_smoke.*` from artifact-missing fail-closed to real Rule 8 flow once the artifact exists.

Exit criteria:

- Operator-shape smoke can start a supervised long-lived process and execute the six Rule 8 checks.

### D. Governance Model Shape

#### Finding D1 - P1 - Architecture-sync remains regex-heavy despite the manifest skeleton

The gate has grown many valuable regex checks, but the manifest skeleton has not become the governing contract. Current drift is structural, not textual: HEAD vs delivery, delivery vs manifest, index vs delivery, status vs delivery, and README status vs actual files.

Impact:

- Regex additions keep chasing symptoms.
- Structural evidence drift remains possible after every audit-trail commit.
- Review effort stays manual and repetitive.

Correction:

1. Promote `evidence-manifest.yaml` from skeleton to contract.
2. Make architecture-sync read the manifest and verify graph consistency:
   - `HEAD -> manifest.reviewed_sha`;
   - `manifest.delivery_file -> delivery header SHA`;
   - `manifest.architecture_sync_logs.* -> JSON sha/platform`;
   - `manifest.status_findings_addressed -> architecture-status.yaml entries`;
   - `manifest.authoritative_index -> includes delivery_file`;
   - `manifest.rule_8_state -> operator-shape log state`.
3. Allow a deliberate non-current manifest only in `--local-only`, never in delivery mode.

Exit criteria:

- A PASS means the evidence graph is current, not merely that text patterns look clean.

## Systematic Category Review

| Category | Current state | Residual risk | Required correction |
|---|---|---|---|
| SHA-bound evidence | Current HEAD lacks delivery evidence | High | Generate final-SHA delivery and block post-delivery audit-chain drift |
| Evidence manifest | Exists but points to `a070a77` | High | Enforce manifest freshness in W0 |
| Current index | Does not list cycle-5 delivery | Medium-high | Gate index freshness against manifest |
| Status ledger | Cycle entries exist, but capability validation SHA is stale | Medium-high | Split sync gate from operator gate and update from manifest |
| Cross-platform evidence | Suffixes exist, but delivery records POSIX only | Medium | Require both logs or state single-platform scope |
| README consistency | Same README says smoke exists and does not exist | Medium | Add README-to-files rule |
| Auth posture | One HMAC/prod test row remains ambiguous | Medium-high | Rewrite auth L2 test row and extend HS256/prod scan |
| Rule 8 | Fail-closed only, no artifact | High | W0 runnable artifact and real operator-shape flow |

## Remediation Roadmap

### W0 - Close the evidence chain

1. Update `docs/governance/evidence-manifest.yaml` to the final SHA.
2. Add committed Windows and POSIX architecture-sync logs for the final SHA, or explicitly mark one platform absent.
3. Add `docs/delivery/2026-05-08-<final-sha>.md` for the final SHA.
4. Update `docs/governance/current-architecture-index.md` to include the latest delivery file.
5. Update `architecture-status.yaml` with accurate `latest_delivery_valid_sha` and `latest_delivery_file`.
6. Fix `gate/README.md:69-70`.
7. Rewrite `agent-runtime/auth/ARCHITECTURE.md:234`.

### W1 - Make the manifest enforceable

1. Implement `manifest_freshness`.
2. Implement `delivery_log_parity`.
3. Implement `readme_to_files`.
4. Implement `ledger_coverage`.
5. Implement `current_architecture_index_freshness`.
6. Make default architecture-sync delivery mode fail if the manifest does not cover HEAD.

### W2 - Move from documentation readiness to runnable readiness

1. Add Maven module structure.
2. Add minimal platform/runtime source trees.
3. Add health/readiness endpoints.
4. Add tenant-binding and posture boot skeletons without placeholder default paths.
5. Convert operator-shape smoke into real Rule 8 flow.

## Concrete File-Level Fix List

| File | Required change |
|---|---|
| `docs/governance/evidence-manifest.yaml` | Update `reviewed_sha`, delivery file, platform logs, and Rule 8 state to the final reviewed SHA. |
| `docs/governance/current-architecture-index.md` | Add cycle-5 and final-SHA delivery evidence; remove stale "will be added" wording. |
| `docs/governance/architecture-status.yaml` | Replace single `last_validated_sha` with sync/operator split fields; update current delivery SHA. |
| `docs/delivery/2026-05-08-302337f.md` | Keep as historical evidence for `302337f`; do not treat as evidence for later SHAs. |
| `gate/README.md` | Fix status section that still says the operator-shape smoke gate does not exist. |
| `gate/check_architecture_sync.ps1` | Add manifest freshness, delivery-log parity, README-to-files, ledger-coverage, and auth-L2 HS256/prod checks. |
| `gate/check_architecture_sync.sh` | Keep parity with PowerShell gate changes. |
| `agent-runtime/auth/ARCHITECTURE.md` | Rewrite weak-HMAC test row so prod rejects HMAC activation rather than treating `APP_JWT_SECRET` as a prod input. |
| `gate/run_operator_shape_smoke.*` | Remain fail-closed until W0 artifact exists; later replace with real Rule 8 flow. |

## Acceptance Criteria for the Next Review

The next review should require:

1. `git status --short` is empty before evidence generation.
2. `git rev-parse --short HEAD` equals `evidence-manifest.yaml.reviewed_sha`.
3. The manifest delivery file exists and names the same SHA.
4. Every architecture-sync log listed in the manifest exists and has matching `sha`, `platform`, and `evidence_valid_for_delivery`.
5. The current architecture index includes the manifest delivery file.
6. `architecture-status.yaml` reports the same latest delivery-valid SHA as the manifest.
7. `gate/README.md` contains no stale "smoke gate does not exist" wording.
8. `agent-runtime/auth/ARCHITECTURE.md` contains no prod HMAC secret requirement.
9. Operator-shape smoke still fails closed until a runnable artifact exists.
10. No L3 or ship claim is made before a real Rule 8 PASS.

## Final Recommendation

Cycle 6 should be the last governance-only cleanup before W0 implementation. The architecture itself is more coherent now, especially around RLS and identity posture. The weak point is evidence currentness. Do not start adding runtime code while the evidence graph can still drift across HEAD, delivery, manifest, index, and status.

The next corrective step is simple but strict: make `evidence-manifest.yaml` the enforced source of truth, then generate final-SHA evidence once and stop committing after it unless a new delivery file is generated.
