# Systematic Architecture Remediation Plan - Cycle 5

Date: 2026-05-08
Reviewed HEAD: `291c635`
Scope: `D:\chao_workspace\spring-ai-fin`
Review stance: strict architecture review after the cycle-4 remediation pass.

## Executive Verdict

Cycle 4 fixed several important issues. The architecture-sync gate now passes semantically at the reviewed HEAD, the POSIX gate no longer depends on a fragile locale, platform auth/posture drift is mostly corrected, historical documents are better quarantined, and `gate/run_operator_shape_smoke.{ps1,sh}` now exists and fails closed when no runnable artifact exists.

The remaining problem is not a single document typo. The architecture governance system is still weaker than it claims:

- the reviewed HEAD has no committed delivery file;
- delivery evidence for `a070a77` disagrees with its referenced JSON log;
- gate documentation and delivery documentation still say the operator-shape scripts do not exist even though they do;
- the RLS vocabulary gate misses the current server L2, where `HikariConnectionResetPolicy` is still listed as an active component;
- the security-control matrix still describes HS256 as required under research/prod in a way that conflicts with the auth L2;
- the governance ledger does not record the cycle-4 findings it claims were addressed;
- there is still no runnable artifact, source tree, build manifest, or real Rule 8 evidence.

Current ship posture:

- Architecture-sync semantic state: improved, but current HEAD evidence is incomplete until a committed log and delivery file are added for `291c635` or its successor.
- Rule 8 state: fail-closed, not operator-gated.
- Capability maturity: no core capability should move beyond `design_accepted` or, for scripts only, `implemented_unverified`.

## Review Evidence

Commands and observations:

- `git rev-parse --short HEAD` returned `291c635`.
- `git status --short` was empty before review commands.
- `gate/check_architecture_sync.ps1` returned PASS and generated `gate/log/291c635.json` with `evidence_valid_for_delivery: true`.
- `gate/check_architecture_sync.sh --local-only` returned PASS semantically and wrote under `gate/log/local/`.
- `gate/run_operator_shape_smoke.ps1` exited 1 with `FAIL_ARTIFACT_MISSING`.
- `gate/run_operator_shape_smoke.sh` exited 1 with `FAIL_ARTIFACT_MISSING`.
- Artifact probes confirmed no `pom.xml`, no `agent-platform/pom.xml`, no `agent-runtime/pom.xml`, and no Java source trees under `agent-platform/src/main/java` or `agent-runtime/src/main/java`.
- The latest committed delivery file is `docs/delivery/2026-05-08-a070a77.md`, which is scoped to SHA `a070a77`, not the reviewed HEAD `291c635`.

## Root-Cause Summary

Observed failure: the current repository can pass the architecture-sync script locally, but the governance corpus still cannot prove the current HEAD is delivery-reviewed, and several status documents contradict the scripts and L2 architecture.

Execution path: the team added cycle-4 gates and delivery evidence, then added later commits (`17f5cd9`, `291c635`) without adding a matching delivery file for the final reviewed HEAD. The sync gate checks selected semantic patterns but does not verify delivery-file/log field parity, does not scan server L2 for stale RLS reset vocabulary, does not verify `gate/README.md` against actual gate files, and does not require cycle findings to appear in `architecture-status.yaml`.

Root cause statement: `291c635` is under-evidenced because the evidence model is still file-existence and pattern driven, not manifest driven; the gate proves a subset of document consistency but does not yet validate that current SHA, delivery files, logs, status ledger, gate README, and authoritative index all describe the same architecture state.

Evidence:

- `docs/delivery/2026-05-08-a070a77.md:6` scopes the latest delivery file to `a070a77`.
- `docs/delivery/2026-05-08-a070a77.md:60` reports `scan_files_count` as `44`, while `gate/log/a070a77.json` reports `42`.
- `gate/README.md:35-38` says `run_operator_shape_smoke.*` does not exist, while both scripts exist in `gate/`.
- `docs/delivery/README.md:80` also says the operator-shape gate does not exist yet.
- `agent-runtime/server/ARCHITECTURE.md:20` still lists `HikariConnectionResetPolicy` as an active component.
- `gate/check_architecture_sync.ps1:264-270` restricts the RLS reset vocabulary rule to governance, diagram, and matrix files, not server L2.
- `docs/governance/architecture-status.yaml` ends at `REM-2026-05-08-C3-5`; it has no cycle-4 finding ledger entries.

## Findings by Category

### A. Evidence Chain and SHA-Bound Delivery

#### Finding A1 - P0 - Current HEAD has no committed delivery evidence

The reviewed HEAD is `291c635`. The latest delivery file is for `a070a77`; it explicitly says it is evidence only for that SHA. A local PowerShell run generated `gate/log/291c635.json`, but no committed `docs/delivery/2026-05-08-291c635.md` exists.

Impact:

- The project still violates its own SHA-current rule.
- A reviewer cannot use the committed corpus to prove the final reviewed HEAD is delivery-reviewed.
- Any claim that `291c635` is covered by `a070a77` evidence is invalid.

Correction:

1. After all remediation edits land, run both architecture-sync gates on a clean tree at the final SHA.
2. Commit `gate/log/<final-sha>.json`.
3. Add `docs/delivery/2026-05-08-<final-sha>.md`.
4. Do not add follow-up commits after delivery evidence without regenerating evidence for the new SHA.

Exit criteria:

- `docs/delivery/<date>-291c635.md` exists, or a successor SHA has both a committed log and a committed delivery file.
- The delivery file states architecture-sync evidence only unless the real Rule 8 gate passes.

#### Finding A2 - P1 - Delivery file values do not match the referenced gate log

`docs/delivery/2026-05-08-a070a77.md` reports `scan_files_count` as `44`, but `gate/log/a070a77.json` reports `42`. The same delivery file claims both PowerShell and POSIX scripts ran, but the referenced log has a single `script` value.

Impact:

- The delivery file is not a faithful rendering of its evidence artifact.
- Manual transcription is already drifting from JSON evidence.
- Cross-platform parity is claimed but not preserved as separate evidence.

Correction:

1. Generate delivery tables from the JSON log rather than hand-copying values.
2. Store separate logs when both scripts run, for example:
   - `gate/log/<sha>-windows.json`
   - `gate/log/<sha>-posix.json`
   - or a combined manifest with both child log hashes.
3. Gate delivery files by checking that referenced fields match the JSON exactly.

Exit criteria:

- A delivery file fails the sync gate if `scan_files_count`, `script`, `sha`, `semantic_pass`, `working_tree_clean`, or `evidence_valid_for_delivery` disagrees with the referenced log.

#### Finding A3 - P1 - Gate logs overwrite cross-platform evidence

Both architecture-sync scripts write to `gate/log/<sha>.json` in delivery-valid mode. Both operator-shape scripts write to `gate/log/local/operator-shape-<sha>.json` in fail-closed mode. Running both platforms sequentially overwrites the first result with the second.

Impact:

- The repo cannot prove that both Windows and POSIX gates passed unless the delivery file manually says so.
- The operator-shape fail-closed logs lose which platform produced which result.
- Cross-platform evidence is not durable.

Correction:

1. Include script/platform in the log filename or write a parent manifest.
2. Make the delivery file reference every platform-specific log.
3. Add a parity rule that confirms both scripts have the same semantic result.

Exit criteria:

- Running PowerShell and POSIX gates for the same SHA leaves two durable evidence records or one combined manifest containing both records.

### B. Gate Documentation and Status Truth

#### Finding B1 - P1 - Gate README and delivery README still say operator-shape scripts do not exist

The scripts now exist, and both fail closed as expected before W0. However, `gate/README.md` and `docs/delivery/README.md` still describe them as absent.

Evidence:

- `gate/run_operator_shape_smoke.ps1` exists.
- `gate/run_operator_shape_smoke.sh` exists.
- `gate/README.md:35-38` says they do not exist and are planned.
- `gate/README.md:56` says `run_operator_shape_smoke.*` is absent.
- `docs/delivery/README.md:80` says the Rule 8 gate does not exist yet.

Impact:

- Operators cannot trust the gate documentation.
- The delivery README contradicts the latest delivery file.
- The status model conflates "fail-closed script exists" with "not yet produced."

Correction:

1. Update both README files to say:
   - operator-shape smoke scripts exist;
   - current version is `cycle-4-fail-closed`;
   - they are not Rule 8 PASS evidence until W0 adds a runnable artifact and real dependency flow.
2. Add a gate rule that compares README statements against actual gate file presence.

Exit criteria:

- No current README says `run_operator_shape_smoke.*` is absent.
- README status matches actual script behavior and delivery classification.

#### Finding B2 - P1 - Governance ledger omits cycle-4 findings and current validation state

The cycle-4 delivery file says eight findings were addressed, but `architecture-status.yaml` has no cycle-4 ledger entries and leaves `REM-2026-05-08-C3-4.last_validated_sha` as `null`.

Impact:

- The status ledger is no longer the source of truth.
- Findings can be claimed in delivery files without being represented in governance.
- Capability status cannot be audited across cycles.

Correction:

1. Add `REM-2026-05-08-C4-*` entries for the cycle-4 findings.
2. Add `last_validated_sha` for gate-related capabilities.
3. Update `operator_shape_gate.implementation` to include both sync scripts and fail-closed operator-shape scripts.
4. Keep `operator_gate: null` until a real Rule 8 PASS exists.

Exit criteria:

- Every delivery-file finding reference has a matching architecture-status entry.
- No `last_validated_sha` remains null after a delivery-valid gate pass unless the status intentionally stays unvalidated.

#### Finding B3 - P2 - Current architecture index is stale

`current-architecture-index.md` correctly introduces an authoritative index, but its delivery section lists only the cycle-3 delivery file as current and does not list `2026-05-08-a070a77.md` or the later committed logs. It also says every historical remediation plan carries a historical banner, but the remediation plan files do not.

Impact:

- The index is useful but not yet authoritative.
- A reader following the index lands on old delivery evidence.
- Historical quarantine is described more strongly than implemented.

Correction:

1. Update the delivery evidence section with the latest valid delivery file and explain why it still does not cover later SHAs.
2. Add historical banners to the listed remediation/improvement plans, or remove the claim that they already have banners.
3. Add the promised `current_architecture_index_freshness` rule earlier than W2, because the index is already being used as an authority.

Exit criteria:

- The index always points to the newest delivery evidence and explicitly names whether it covers the reviewed HEAD.
- Every file listed as banner-marked actually has the banner.

### C. Tenant Isolation and RLS Lifecycle

#### Finding C1 - P0 - Server L2 still lists an obsolete RLS reset component

The server L2 correctly states later that transaction-scoped `SET LOCAL` is the actual safety property and `connectionInitSql` is not a checkout reset hook. But the same document's ownership section still lists `HikariConnectionResetPolicy` as a component that resets or validates pooled connections between checkouts.

Evidence:

- `agent-runtime/server/ARCHITECTURE.md:20`
- `agent-runtime/server/ARCHITECTURE.md:172-173`
- `agent-runtime/server/ARCHITECTURE.md:287`

Impact:

- Implementers can still create the wrong class because it is listed in the "Owns" section.
- The L2 document contradicts itself on the core tenant-isolation path.
- The delivery claim that current RLS docs have no active reset claim is false.

Correction:

1. Remove `HikariConnectionResetPolicy` from the active ownership list.
2. Replace it with the actual components:
   - `TenantBinder`;
   - `RlsConnectionInterceptor`;
   - transaction-start GUC-empty validator;
   - `PooledConnectionLeakageIT`.
3. If a pool-level defense-in-depth class remains, name it without implying reset and define exactly what it validates.

Exit criteria:

- No current L0/L1/L2 document lists `HikariConnectionResetPolicy` as an active implementation path.
- Server L2 has one coherent RLS lifecycle model from ownership section to ADRs.

#### Finding C2 - P1 - RLS vocabulary gate does not scan the server L2 it is supposed to protect

The cycle-4 gate claims to flag stale RLS reset vocabulary, but its file list omits `agent-runtime/server/ARCHITECTURE.md`, where the stale component name still appears.

Evidence:

- `gate/check_architecture_sync.ps1:264-270`
- `gate/check_architecture_sync.sh:315-321`
- `agent-runtime/server/ARCHITECTURE.md:20`

Impact:

- The gate has a false sense of coverage.
- Delivery files can claim "current RLS docs clean" while the server L2 remains dirty.

Correction:

1. Apply `rls_reset_vocabulary` to all current L0/L1/L2 architecture files, not only governance/diagram/matrix files.
2. Allow negated or historical mentions only in files explicitly marked historical or in lines with a clear deprecation marker.
3. Add a fixture that proves the gate catches `HikariConnectionResetPolicy` in server L2.

Exit criteria:

- Reintroducing the current line 20 into server L2 fails both PowerShell and POSIX gates.

### D. Identity and Security Control Matrix

#### Finding D1 - P1 - HS256 posture row is ambiguous and conflicts with auth L2

The auth L2 says prod has no HS256 path and research SaaS multi-tenant must use RS256/ES256 with JWKS. The security-control matrix still says HS256 validation is "research/prod: required (BYOC HS256 carve-out)", which can be read as requiring HS256 under prod.

Evidence:

- `agent-runtime/auth/ARCHITECTURE.md:55-59`
- `agent-runtime/auth/ARCHITECTURE.md:193`
- `docs/security-control-matrix.md:15-16`

Impact:

- The matrix can drive a wrong control implementation.
- Test planning may add prod HS256 tests instead of enforcing prod rejection.
- The identity boundary becomes posture-ambiguous again.

Correction:

1. Rewrite the HS256 row posture as:
   - dev loopback: allowed;
   - research BYOC single-tenant: allowed only by allowlist with audit alarm;
   - research SaaS multi-tenant: rejected;
   - prod: rejected.
2. Keep the JWKS row as the research SaaS and prod default.
3. Add a matrix consistency gate that rejects "prod" and "HS256" on the same control row unless the row explicitly says "rejected" or "not permitted".

Exit criteria:

- Security matrix posture language matches auth L2 exactly.

### E. Rule 8 and Implementation Readiness

#### Finding E1 - P0 - Operator-shape gate exists but can only prove artifact absence

This is an improvement over an absent gate, but it is still not Rule 8 evidence. Both scripts fail closed because no runnable artifact exists.

Evidence:

- `gate/run_operator_shape_smoke.ps1` exits 1 with `FAIL_ARTIFACT_MISSING`.
- `gate/run_operator_shape_smoke.sh` exits 1 with `FAIL_ARTIFACT_MISSING`.
- No Maven build manifest or Java source tree exists.

Impact:

- No release, deployment, or L3 capability claim is valid.
- The system cannot prove long-lived process behavior, real dependency access, sequential runs, resource reuse, lifecycle observability, cancellation, or fallback-zero.

Correction:

1. Treat the fail-closed gate as a W0 guard, not a readiness result.
2. Implement the minimal runnable artifact before any further maturity promotion.
3. Convert the fail-closed gate into the real six-part Rule 8 flow after the artifact exists.

Exit criteria:

- Operator-shape smoke runs a supervised long-lived process, real Postgres, real LLM provider in research/prod posture, three sequential public-entry runs, cancellation checks, lifecycle checks, and fallback-zero assertions.

### F. Gate Coverage and Manifest Design

#### Finding F1 - P1 - The architecture-sync gate is still pattern-driven, not manifest-driven

The gate has grown useful checks, but it still misses relationships that should be first-class invariants: delivery file to log parity, current SHA coverage, gate README to actual files, cycle finding to status ledger, index to current evidence, and platform-specific log preservation.

Impact:

- Every cycle adds another regex but leaves structural drift possible.
- Evidence truth depends on human discipline.
- False PASS results remain likely.

Correction:

1. Add a machine-readable `docs/governance/evidence-manifest.yaml`.
2. Record:
   - reviewed SHA;
   - current delivery file;
   - architecture-sync logs by platform;
   - operator-shape logs by platform;
   - status ledger entries addressed;
   - authoritative document index version;
   - artifact presence and Rule 8 state.
3. Make the gate validate the manifest instead of relying only on prose scans.

Exit criteria:

- A delivery file cannot claim a finding, SHA, log value, script, or status unless the manifest and referenced artifacts agree.

## Systematic Category Review

| Category | Current state | Residual risk | Required correction |
|---|---|---|---|
| SHA-bound evidence | Sync gate can pass, but current HEAD lacks committed delivery evidence | High | Generate final-SHA delivery evidence and prevent post-evidence commits without refresh |
| Gate documentation | Scripts exist but README files say absent | Medium-high | Update README files and add file-presence consistency checks |
| Governance ledger | Cycle-4 claims are not reflected in status YAML | High | Add cycle-4 ledger entries and `last_validated_sha` |
| RLS tenant isolation | Server L2 still lists obsolete reset component | High | Remove `HikariConnectionResetPolicy`; expand gate to server L2 |
| Identity posture | Auth L2 mostly correct; matrix HS256 row ambiguous | Medium-high | Rewrite posture row and gate HS256/prod wording |
| Rule 8 readiness | Fail-closed scripts exist; runnable artifact missing | High | Build minimal artifact and implement real operator-shape smoke flow |
| Evidence model | Regex-driven checks catch some drift but miss structural parity | High | Introduce evidence manifest and generated delivery tables |

## Remediation Roadmap

### W0 - Evidence truth and gate correction

1. Add a delivery file and committed logs for the final reviewed SHA.
2. Fix `gate/README.md` and `docs/delivery/README.md` to reflect that fail-closed operator-shape scripts now exist.
3. Add cycle-4 findings to `architecture-status.yaml`.
4. Update `current-architecture-index.md` delivery and historical-banner sections.
5. Remove `HikariConnectionResetPolicy` from server L2 active ownership.
6. Expand RLS vocabulary checks to current L0/L1/L2 files.
7. Fix the HS256 row in `docs/security-control-matrix.md`.
8. Split platform-specific gate logs or add a combined evidence manifest.

### W1 - Manifest-backed evidence

1. Add `docs/governance/evidence-manifest.yaml`.
2. Generate delivery tables from JSON logs.
3. Gate delivery-log parity.
4. Gate status-ledger coverage for every remediation cycle finding.
5. Gate README-to-file consistency.

### W2 - Minimal runnable architecture

1. Add Maven root and module manifests.
2. Add minimal Spring Boot entry point and health/readiness endpoints.
3. Add placeholder-free implementations for posture boot guard, auth dispatch, tenant binding, run lifecycle, and observability counters.
4. Convert operator-shape smoke from artifact-missing fail-closed to real-flow FAIL/PASS behavior.
5. Keep all core capabilities below L3 until Rule 8 PASS exists.

## Concrete File-Level Fix List

| File | Required change |
|---|---|
| `docs/delivery/2026-05-08-a070a77.md` | Correct values to match `gate/log/a070a77.json`, or mark as superseded by final-SHA evidence. |
| `gate/log/291c635.json` | Commit only with matching final-SHA delivery file, or regenerate after fixes. |
| `gate/README.md` | Replace "does not exist yet" wording with "exists and fails closed until W0 runnable artifact." |
| `docs/delivery/README.md` | Same operator-shape wording correction; keep Rule 8 PASS distinction. |
| `docs/governance/architecture-status.yaml` | Add cycle-4 ledger entries, update `operator_shape_gate.implementation`, set truthful `last_validated_sha`. |
| `docs/governance/current-architecture-index.md` | Point to latest delivery evidence and fix historical-banner claim. |
| `agent-runtime/server/ARCHITECTURE.md` | Remove `HikariConnectionResetPolicy` from active ownership; keep only transaction-scoped `SET LOCAL` safety model. |
| `gate/check_architecture_sync.ps1` | Apply RLS reset vocabulary checks to current L0/L1/L2 architecture files and validate delivery-log parity. |
| `gate/check_architecture_sync.sh` | Maintain parity with PowerShell gate changes. |
| `docs/security-control-matrix.md` | Rewrite HS256 posture row so prod is reject-only and research BYOC is explicit carve-out only. |
| `gate/run_operator_shape_smoke.*` | Write platform-specific logs or a combined manifest so one platform does not overwrite the other. |

## Acceptance Criteria for the Next Review

The next review should require all of the following:

1. `git status --short` is empty before delivery evidence generation.
2. The final reviewed SHA has a committed architecture-sync log and a committed delivery file.
3. Delivery file fields match the referenced JSON logs exactly.
4. Windows and POSIX gate results are both preserved.
5. `gate/README.md`, `docs/delivery/README.md`, actual gate files, and `architecture-status.yaml` agree on operator-shape script state.
6. `agent-runtime/server/ARCHITECTURE.md` contains no active `HikariConnectionResetPolicy` ownership claim.
7. The RLS vocabulary gate scans server L2 and fails on the current stale line if reintroduced.
8. The security matrix says HS256 is rejected in prod and allowed only for dev loopback or research BYOC allowlist.
9. Cycle-4 findings appear in `architecture-status.yaml`.
10. `current-architecture-index.md` points to the latest evidence and does not overclaim historical banners.
11. Operator-shape smoke still fails closed until a runnable artifact exists; once the artifact exists, fail-closed absence is replaced by real Rule 8 checks.

## Final Recommendation

Cycle 5 should be a governance-hardening pass before implementation begins. The architecture team has made real progress, but the evidence system still permits inconsistent PASS narratives. Fix the evidence model now, while the repository is still documentation-first. Once source code and runtime behavior arrive, these inconsistencies will become harder and more expensive to unwind.

The project should not promote any runtime capability until:

1. final-SHA evidence is committed;
2. server RLS vocabulary is clean in the authoritative L2;
3. identity posture is unambiguous across auth L2 and security matrix;
4. gate documentation matches actual scripts;
5. Rule 8 is either honestly fail-closed due missing artifact or fully operator-gated with real dependencies.
