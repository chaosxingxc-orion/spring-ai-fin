# Systematic Architecture Remediation Plan - Cycle 4

Date: 2026-05-08
Reviewed HEAD: `8badd62`
Scope: `D:\chao_workspace\spring-ai-fin`
Review stance: strict architecture review after the cycle-3 remediation pass.

## Executive Verdict

The architecture corpus is materially better than the prior review cycles. The ActionGuard stage count is now aligned in L0 and L2, the server RLS L2 now correctly uses transaction-scoped `SET LOCAL`, the security-control matrix no longer depends on HikariCP `connectionInitSql`, and `gate/README.md` now separates the architecture-sync gate from the future Rule 8 operator-shape gate.

However, the current repository is still not delivery-ready. The current HEAD does not have valid architecture-sync evidence, the architecture-sync gate fails on the current content, platform submodule docs still carry the old HMAC/posture model, and several governance/diagram docs still contain stale RLS reset language. The Rule 8 operator-shape gate and runnable artifact are still absent.

Ship posture:

- Architecture-sync delivery claim: blocked until a clean gate pass is recorded for the exact successor SHA.
- Rule 8 delivery claim: blocked because `gate/run_operator_shape_smoke.*` and a runnable artifact do not exist.
- Security design claim: partially accepted at L0/L1, but not yet test-verified or operator-gated.

## Review Evidence

Commands and local observations:

- `git rev-parse --short HEAD` reported `8badd62`.
- `gate/check_architecture_sync.ps1` failed on the current content before producing delivery-valid evidence.
- `gate/check_architecture_sync.sh` failed with `semantic_pass: false` and `evidence_valid_for_delivery: false`.
- The POSIX gate log at `gate/log/8badd62.json` reports:
  - `dirty_tree` after the PowerShell gate produced an untracked local log;
  - four `forbidden_closure_shortcut` findings in `docs/delivery/2026-05-08-003ed6f.md`.
- File inventory shows this repository is still documentation and gate-script only: 55 Markdown files, 10 JSON files after the local gate run, 2 YAML files, 1 PowerShell gate, 1 POSIX gate, and no Java/Maven/runtime implementation files.

## Root-Cause Summary

Observed failure: the current architecture-sync gate fails and no delivery-valid evidence exists for HEAD `8badd62`.

Execution path: `gate/check_architecture_sync.*` builds a scan list that includes delivery Markdown files, applies the broader cycle-3 forbidden status-claim regexes, and scans `docs/delivery/2026-05-08-003ed6f.md`. That delivery file documents the exact forbidden phrase examples as raw prose, so the regex matches its own evidence document. The gate writes `gate/log/8badd62.json`; the next gate run then sees that untracked log as a dirty tree.

Root cause statement: the current HEAD fails architecture-sync because `docs/delivery/2026-05-08-003ed6f.md:68-74` lists the newly forbidden phrase examples in raw text, which causes `check_architecture_sync.*` to fail before valid evidence can be produced for `8badd62`.

Evidence:

- `docs/delivery/2026-05-08-003ed6f.md:3-4` says the delivery file is evidence only for SHA `003ed6f`.
- `docs/delivery/2026-05-08-003ed6f.md:68-74` lists the raw forbidden phrase examples that now fail the gate.
- `gate/log/8badd62.json` reports `semantic_pass: false` and `evidence_valid_for_delivery: false`.

## Findings by Category

### A. Evidence and Governance Gates

#### Finding A1 - P0 - Current architecture-sync gate fails on its own delivery evidence

The cycle-3 delivery file records the expanded closure-language regex by listing raw phrase examples. Because delivery docs are inside the scan list, those examples now trigger the gate.

Evidence:

- `docs/delivery/2026-05-08-003ed6f.md:68-74`
- `gate/log/8badd62.json`

Impact:

- The current HEAD cannot claim document-consistency evidence.
- A future reviewer cannot distinguish a real forbidden status claim from a self-referential regex example.
- The gate is semantically useful but operationally brittle.

Correction:

1. Rewrite `docs/delivery/2026-05-08-003ed6f.md:68-74` so it references rule identifiers only, not raw forbidden phrase examples.
2. Add a gate fixture or test note that proves the regex works without embedding forbidden examples in scanned delivery evidence.
3. Keep delivery docs in the scan set, but document a safe way to describe gate rules, for example by using rule names such as `closed_by_design_phrase` without spelling out the matched prose.

Exit criteria:

- `gate/check_architecture_sync.ps1` and `gate/check_architecture_sync.sh` both return exit code 0 on a clean tree.
- The generated log for the successor SHA has `semantic_pass: true`, `working_tree_clean: true`, and `evidence_valid_for_delivery: true`.

#### Finding A2 - P0 - Current HEAD has no valid evidence file

The latest delivery document is scoped to `003ed6f`, while the reviewed HEAD is `8badd62`. The current gate run fails, so no delivery-valid evidence exists for the content under review.

Evidence:

- `docs/delivery/2026-05-08-003ed6f.md:3-4`
- `docs/delivery/2026-05-08-003ed6f.md:135-137`
- `gate/log/8badd62.json`

Impact:

- The governance model correctly says evidence is SHA-bound, but the current repository has fallen out of evidence coverage.
- Any status claim for `8badd62` would be unreproducible.

Correction:

1. Fix the gate-blocking content first.
2. Rerun both architecture-sync gates on a clean tree at the successor SHA.
3. Commit `gate/log/<successor-sha>.json`.
4. Add `docs/delivery/2026-05-08-<successor-sha>.md` that explicitly states architecture-sync evidence only, not Rule 8 evidence.

Exit criteria:

- The delivery file and gate log both name the same SHA.
- The delivery file does not contain raw forbidden status phrases.
- `docs/delivery/README.md` continues to reject local-only or dirty-tree logs.

#### Finding A3 - P1 - Gate output mutates the working tree during failed evidence runs

The gate writes `gate/log/<sha>.json` even when the run fails. After the PowerShell run generated `gate/log/8badd62.json`, the POSIX run reported a dirty tree.

Evidence:

- `git status --short` reported `?? gate/log/8badd62.json`.
- `gate/log/8badd62.json` reports `dirty_tree`.

Impact:

- A failed local check contaminates the next delivery-evidence run.
- Reviewers must manually reason about whether `dirty_tree` is caused by the gate itself or by unrelated changes.

Correction:

1. Add an explicit output mode:
   - default delivery mode writes committed evidence only when the tree is clean and semantic checks pass;
   - local mode writes under an ignored path such as `gate/log/local/`;
   - failed delivery mode prints the JSON to stdout or writes to a caller-specified temp path.
2. Include the command line and script name in the output so PowerShell and POSIX runs cannot overwrite each other without intent.

Exit criteria:

- A failed local gate does not create an untracked file in `gate/log/`.
- A delivery-valid log is produced only from a clean tree.

#### Finding A4 - P1 - Governance status overstates the architecture-sync portion

The status model says the architecture-sync portion is implemented-unverified and runnable, but the current HEAD does not pass the architecture-sync gate. The status is no longer truthful for the reviewed content.

Evidence:

- `docs/governance/architecture-status.yaml:409-415`
- `gate/README.md:65-66`
- `gate/log/8badd62.json`

Impact:

- The ledger weakens its role as the source of truth.
- Teams may treat an older pass as current evidence.

Correction:

1. Downgrade the cycle-3 closure-enforcement entry until the successor SHA has a clean PASS.
2. Add a `last_validated_sha` field for each gate capability.
3. Require status text to distinguish "script exists" from "script passes at current HEAD".

Exit criteria:

- `architecture-status.yaml` does not imply a current pass unless the matching SHA has a valid log.

### B. Security Model Consistency

#### Finding B1 - P0 - Platform submodule docs still carry the old HMAC/posture model

The root platform L1 now says research SaaS and prod use RS256/ES256 with JWKS, with HS256 only for explicit BYOC or loopback carve-outs. Several platform submodule architecture files still describe `APP_JWT_SECRET` as required under research/prod or posture as mirrored through `Environment.getProperty`.

Evidence:

- `agent-platform/ARCHITECTURE.md:322` says `APP_JWT_SECRET` is no longer the standard research/prod path.
- `agent-platform/bootstrap/ARCHITECTURE.md:104` still asserts `APP_JWT_SECRET` for research/prod.
- `agent-platform/cli/ARCHITECTURE.md:105` still ties `--prod` to `APP_JWT_SECRET`.
- `agent-platform/config/ARCHITECTURE.md:42` marks `jwt-secret` as required under research/prod.
- `agent-platform/config/ARCHITECTURE.md:123` says posture is mirrored through `Environment.getProperty`.

Impact:

- Implementers can build the wrong auth path while still following an L2 document.
- Research/prod identity posture remains ambiguous across platform packages.
- The cycle-2 auth/posture correction is not actually propagated through the full platform design.

Correction:

1. Update all platform submodule docs so:
   - research SaaS and prod require issuer registry plus JWKS validation;
   - HS256 is limited to dev loopback or explicit BYOC single-tenant allowlist;
   - `APP_JWT_SECRET` is asserted only when `HmacValidator` is active;
   - posture is read once in bootstrap and injected, never mirrored ad hoc through `Environment.getProperty`.
2. Add an architecture-sync rule that scans every `agent-platform/**/ARCHITECTURE.md`, not only `agent-platform/ARCHITECTURE.md`, for unqualified `APP_JWT_SECRET` and old posture language.
3. Add allowlist-aware wording for legitimate HS256 references.

Exit criteria:

- No platform doc says `APP_JWT_SECRET` is the standard research/prod credential.
- No platform doc says posture decisions are made by direct `Environment.getProperty` reads outside the approved bootstrap seam.
- The gate fails on a deliberately reintroduced old auth/posture sentence in any platform submodule architecture file.

#### Finding B2 - P1 - Gate rule scope is narrower than the scan scope

The gate builds a broad L1/L2 scan list, but the auth and contract-posture rules only inspect `agent-platform/ARCHITECTURE.md`. That mismatch is why stale auth/posture language survives in submodule docs.

Evidence:

- `gate/check_architecture_sync.ps1:83-103` collects all `agent-platform/**/ARCHITECTURE.md` files.
- `gate/check_architecture_sync.ps1:203-231` applies contract-posture and auth checks only to `$agentPlatformL1 = 'agent-platform/ARCHITECTURE.md'`.

Impact:

- The gate appears broad but is selectively narrow for important security-policy rules.
- Future teams may assume submodule L2 docs are covered when they are not.

Correction:

1. Apply auth/posture rules to the complete `$NonDocsArchFiles` set or to a dedicated `$PlatformArchFiles` set.
2. Keep explicit exceptions path-scoped and comment-backed.
3. Report the matched file and line for every policy violation.

Exit criteria:

- The stale lines currently in `agent-platform/bootstrap`, `cli`, and `config` would fail the gate if reintroduced.

### C. Tenant Isolation and RLS Lifecycle

#### Finding C1 - P1 - RLS reset vocabulary still drifts across governance and diagrams

Server L2 and the security matrix now correctly define the RLS safety property as transaction-scoped `SET LOCAL` plus validation at transaction start. Governance and diagram files still use "HikariCP reset", "HikariConnectionResetPolicy", and "reset on connection check-in" language.

Evidence:

- `agent-runtime/server/ARCHITECTURE.md:172-173` states the corrected transaction-scoped `SET LOCAL` protocol.
- `docs/security-control-matrix.md:42-45` now aligns with `SET LOCAL`, `TenantBinder`, and `PooledConnectionLeakageIT`.
- `docs/governance/architecture-status.yaml:101` still says `HikariCP reset`.
- `docs/governance/architecture-status.yaml:201` still says `SET LOCAL + HikariCP reset`.
- `docs/governance/architecture-status.yaml:299` still says the RLS protocol includes `HikariCP reset`.
- `docs/governance/decision-sync-matrix.md:85` still names `HikariConnectionResetPolicy.java`.
- `docs/trust-boundary-diagram.md:242` still says reset on connection check-in.

Impact:

- The corrected RLS design is not consistently propagated.
- Implementation may resurrect a fake reset seam instead of proving transaction-scoped isolation.
- The security-control matrix is now right, but the governance spine still carries stale vocabulary.

Correction:

1. Replace "HikariCP reset" with "transaction-scoped GUC auto-discard plus transaction-start validation" in the governance ledger.
2. Remove or explicitly deprecate `HikariConnectionResetPolicy.java` from the decision-sync matrix.
3. Update the trust-boundary diagram row to say `SET LOCAL` is discarded at commit or rollback, with stale-GUC validation at the next tenant transaction start.
4. Extend the gate to flag:
   - `HikariCP reset`;
   - `HikariConnectionResetPolicy`;
   - "reset on connection check-in";
   - "connection check-out hook" when used as the RLS safety mechanism.

Exit criteria:

- Only historical or remediation-review files mention the obsolete reset vocabulary.
- Current governance, matrix, and diagrams describe the same RLS protocol as server L2.

### D. Operator-Shape Readiness

#### Finding D1 - P0 - Rule 8 operator-shape gate still does not exist

The repository correctly labels the operator-shape gate as planned, but the gate is still absent. Architecture-sync evidence cannot substitute for Rule 8 evidence.

Evidence:

- `gate/README.md:35-56`
- `docs/delivery/2026-05-08-003ed6f.md:80-86`
- Repository inventory contains no runnable Java/Maven artifact.

Impact:

- No artifact can be shipped under the repo's own Rule 8.
- There is no proof of long-lived process behavior, real dependency calls, sequential run stability, lifecycle observability, cancellation, or fallback-zero delivery posture.

Correction:

1. Add `gate/run_operator_shape_smoke.ps1` and `gate/run_operator_shape_smoke.sh`.
2. If no runnable artifact exists yet, the scripts must fail closed with a structured "artifact missing" result rather than being absent.
3. Define the first runnable target, process supervisor, dependency endpoints, and evidence schema before any implementation claims L3.
4. Add delivery documentation that separates:
   - architecture-sync PASS;
   - operator-shape FAIL because artifact is missing;
   - operator-shape PASS once the real target exists and passes all six Rule 8 checks.

Exit criteria:

- The operator-shape gate exists, is executable on Windows and POSIX, and fails closed until a real artifact is available.
- Once implementation exists, the gate runs N >= 3 public-entry invocations against real dependencies with fallback count zero.

### E. Documentation Lifecycle and Historical Material

#### Finding E1 - P2 - Historical docs remain easy to confuse with current architecture

Some older review and response documents still contain superseded security claims. The gate excludes selected historical files, but not every stale document is clearly quarantined for human readers.

Evidence:

- `docs/security-response-2026-05-08.md` is excluded by the gate as historical.
- `docs/architecture-review-2026-05-07.md` still contains old auth/cardinality examples.
- `docs/deep-architecture-security-assessment-2026-05-07.en.md` still records the older HS256-first assessment.

Impact:

- Engineers may copy old examples into current design or implementation work.
- The repo depends on implicit memory of which docs are current.

Correction:

1. Add a "historical, do not implement" banner to superseded review/response docs.
2. Maintain `docs/governance/current-architecture-index.md` listing the authoritative L0, L1, L2, matrix, and delivery evidence files.
3. Make the gate require that any excluded historical file has an explicit historical banner.

Exit criteria:

- Every skipped historical file is visibly marked.
- Current implementers have one index that points to authoritative design documents.

## Systematic Category Review

| Category | Current state | Residual risk | Required correction |
|---|---|---|---|
| Evidence governance | Gate exists but fails at current HEAD | High | Fix self-triggering delivery doc, rerun clean gates, bind evidence to successor SHA |
| Auth/posture architecture | Root L1 fixed; submodule L2s stale | High | Propagate JWKS/BYOC carve-out model to all platform docs and gate all platform L2s |
| Tenant isolation | Server L2 and matrix fixed; governance/diagrams stale | Medium-high | Replace reset vocabulary with transaction-scoped `SET LOCAL` protocol everywhere current |
| Operator readiness | Explicitly planned, not implemented | High | Add fail-closed Rule 8 scripts, then real operator-shape evidence when artifact exists |
| Historical documentation | Exclusions exist but reader warnings are incomplete | Medium | Banner historical docs and publish a current architecture index |

## Remediation Roadmap

### W0 - Evidence and design consistency

1. Remove raw forbidden status-phrase examples from `docs/delivery/2026-05-08-003ed6f.md`.
2. Update platform submodule docs to align with the JWKS-first research/prod identity posture.
3. Remove stale RLS reset vocabulary from governance and diagrams.
4. Expand gate rules so auth/posture and RLS lifecycle checks apply across all current L1/L2 docs.
5. Rerun both architecture-sync gates from a clean tree.
6. Add a new delivery file for the exact successor SHA.
7. Update `architecture-status.yaml` with `last_validated_sha` and truthful status text.

### W1 - Gate ergonomics and historical quarantine

1. Split local failed gate output from delivery-valid evidence output.
2. Add parity tests or fixture checks for the PowerShell and POSIX rule sets.
3. Add historical banners to superseded review/response docs.
4. Add `docs/governance/current-architecture-index.md`.

### W2 - Operator-shape and implementation readiness

1. Add fail-closed `gate/run_operator_shape_smoke.*` scripts.
2. Define the first runnable artifact target and process supervisor.
3. Add the first source tree, build manifest, migration path, and test layout.
4. Implement the first Rule 8 smoke evidence flow only after a real artifact exists.

## Concrete File-Level Fix List

| File | Required change |
|---|---|
| `docs/delivery/2026-05-08-003ed6f.md` | Replace raw forbidden status-phrase examples with rule identifiers or safe paraphrases. |
| `agent-platform/bootstrap/ARCHITECTURE.md` | Replace research/prod `APP_JWT_SECRET` assertion with issuer/JWKS boot requirements; scope HMAC to dev loopback or BYOC allowlist. |
| `agent-platform/cli/ARCHITECTURE.md` | Remove the `--prod` plus `APP_JWT_SECRET` invariant; describe JWKS/issuer config for prod. |
| `agent-platform/config/ARCHITECTURE.md` | Update `jwt-secret` as optional and active only for HMAC carve-outs; remove posture mirroring via `Environment.getProperty`. |
| `gate/check_architecture_sync.ps1` | Apply auth/posture checks to all platform architecture docs; prevent failed delivery runs from writing untracked evidence logs. |
| `gate/check_architecture_sync.sh` | Keep semantic parity with the PowerShell changes. |
| `docs/governance/architecture-status.yaml` | Remove stale RLS reset claims; add `last_validated_sha`; align cycle-3 status with current gate result. |
| `docs/governance/decision-sync-matrix.md` | Remove or deprecate `HikariConnectionResetPolicy.java` as a current RLS implementation path. |
| `docs/trust-boundary-diagram.md` | Replace check-in reset language with transaction-scoped `SET LOCAL` discard semantics. |
| `gate/run_operator_shape_smoke.ps1` | Add fail-closed Windows Rule 8 entry point. |
| `gate/run_operator_shape_smoke.sh` | Add fail-closed POSIX Rule 8 entry point. |

## Acceptance Criteria for the Next Review

The next review should not accept "documentation updated" as sufficient. It should require the following evidence:

1. `git status --short` is empty before each delivery gate run.
2. `gate/check_architecture_sync.ps1` exits 0.
3. `gate/check_architecture_sync.sh` exits 0.
4. The new `gate/log/<sha>.json` has:
   - `sha` equal to the reviewed commit;
   - `working_tree_clean: true`;
   - `semantic_pass: true`;
   - `evidence_valid_for_delivery: true`;
   - `failures: []`.
5. `docs/delivery/2026-05-08-<sha>.md` exists for the same SHA and says architecture-sync evidence only.
6. `agent-platform/**/ARCHITECTURE.md` contains no unqualified research/prod `APP_JWT_SECRET` requirement.
7. Current RLS docs contain no active "HikariCP reset" or check-in reset claim.
8. `gate/run_operator_shape_smoke.*` exists and fails closed if no artifact exists.
9. `architecture-status.yaml` does not promote any capability beyond the evidence level supported by committed logs and tests.

## Final Recommendation

Treat cycle 4 as a W0 stabilization pass, not as an implementation wave. The highest-value move is to make the governance system truthful and hard to bypass:

1. Fix the current gate failure.
2. Expand the gate to cover all platform submodule architecture docs.
3. Remove stale RLS reset vocabulary from current governance documents.
4. Produce fresh SHA-bound architecture-sync evidence.
5. Add fail-closed Rule 8 operator-shape scripts before any future delivery claim.

Only after those are complete should the project start promoting capabilities toward implementation maturity. At the moment, the architecture is clearer than before, but the evidence chain is still broken at the current HEAD.
