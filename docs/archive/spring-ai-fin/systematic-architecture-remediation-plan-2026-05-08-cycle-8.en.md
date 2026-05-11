# Systematic Architecture Remediation Plan - Cycle 8

Date: 2026-05-08
Reviewed HEAD: `51ee916`
Scope: `D:\chao_workspace\spring-ai-fin`
Review stance: strict architecture review after the cycle-7 remediation pass.

## Executive Verdict

Cycle 7 fixed several important issues from the prior review: the Windows architecture-sync gate now completes with structured JSON, the manifest uses an explicit two-SHA vocabulary, historical `operator_shape_gate` rows were re-keyed, and active governance files were partially normalized to ASCII.

The architecture is still not evidence-safe. The highest-risk defect is that the POSIX architecture-sync gate is currently not executable from its shebang path because `gate/check_architecture_sync.sh` has CRLF line terminators in the working tree. The self-test catches this, but the committed delivery file still claims cycle-7 architecture-sync evidence. More importantly, the new two-SHA model is not fully bound to committed evidence: the manifest stores `evidence_commit_sha: TBD`, `authoritative_index_sha: TBD`, and `architecture_sync_logs.{posix,windows}: null`; the cycle-7 delivery file says `gate/log/ba4bcd5-posix.json` is part of the audit-trail diff, but the committed audit-trail diff actually contains `gate/log/868dc85-posix.json`.

Current ship posture:

- Windows architecture-sync gate: PASS at `51ee916`, structured JSON produced during review.
- POSIX architecture-sync gate: FAILS when invoked as `gate/check_architecture_sync.sh` because the shebang resolves as `bash\r`.
- POSIX gate self-test: FAILS because the architecture-sync script produces no log.
- Rule 8 operator-shape smoke: FAILS closed with `FAIL_ARTIFACT_MISSING` on both Windows and POSIX, which remains correct.
- Runtime implementation: still absent; no Maven manifests, Java source tree, database migrations, or executable service artifact.

No runtime capability should be promoted beyond design evidence. The next remediation should focus on making architecture-sync evidence durable, platform-executable, and graph-complete before any W0 runtime implementation starts.

## Review Evidence

Commands and observations:

- `git rev-parse --short HEAD` returned `51ee916`.
- `git rev-parse --short HEAD^` returned `ba4bcd5`.
- `git status --short` was clean before and after review commands.
- `gate/check_architecture_sync.ps1` exited 0 and produced structured JSON at `gate/log/51ee916-windows.json` during review; the generated log was removed after inspection.
- `gate/check_architecture_sync.sh` failed when invoked directly from POSIX with `/usr/bin/env: 'bash\r': No such file or directory`.
- `bash gate/check_architecture_sync.sh` also failed with `set: pipefail\r: invalid option name`, proving the body has CRLF contamination, not just the shebang.
- `gate/test_architecture_sync_gate.sh` failed: `FAIL [check_architecture_sync.sh]: no log produced`.
- `git ls-files --eol` reported `i/lf w/crlf` for `gate/check_architecture_sync.sh`.
- `git diff --name-only HEAD^..HEAD` listed `gate/log/868dc85-posix.json`, not `gate/log/ba4bcd5-posix.json`.
- `gate/log/868dc85-posix.json` reports `"sha":"868dc85"`.
- `gate/run_operator_shape_smoke.ps1` and `gate/run_operator_shape_smoke.sh` both exited 1 with `FAIL_ARTIFACT_MISSING`.
- `.gitattributes` does not exist, so shell-script line ending policy is not enforced.

## Root-Cause Summary

Observed failure: the governance corpus claims cycle-7 evidence closure, but the POSIX gate cannot execute in operator shape and the manifest/delivery/log graph still contains unbound or mismatched evidence fields.

Execution path: cycle 7 introduced a two-SHA model and audit-trail commit pattern, then committed delivery evidence at `51ee916`. The audit-trail commit is allowed to change delivery, manifest, status, index, and logs. However, the committed log is for `868dc85`, while the delivery file and status ledger describe `ba4bcd5`. The gate rules do not fail missing per-SHA logs because delivery-log parity skips a delivery file when no matching log exists. At the same time, Windows checkout converted `gate/check_architecture_sync.sh` to CRLF, breaking the POSIX entry point and the self-test.

Root cause statement: evidence validity still depends on permissive conventions (`TBD`, `null`, optional logs, stdout as canonical evidence, and unpinned line endings) instead of a closed manifest graph that requires exact SHA, log, platform, and file-format invariants.

Evidence:

- `docs/governance/evidence-manifest.yaml:32` has `evidence_commit_sha: TBD`.
- `docs/governance/evidence-manifest.yaml:62-63` has `architecture_sync_logs.posix: null` and `windows: null`.
- `docs/governance/evidence-manifest.yaml:156` has `authoritative_index_sha: TBD`.
- `docs/delivery/2026-05-08-ba4bcd5.md:22` says the audit-trail diff includes `gate/log/ba4bcd5-posix.json`.
- Actual audit-trail diff includes `gate/log/868dc85-posix.json`.
- `gate/check_architecture_sync.sh:520-530` skips delivery-log parity when no matching log is found.
- `gate/check_architecture_sync.ps1:493-497` has the same skip-on-missing-log behavior.
- `gate/test_architecture_sync_gate.sh:72-92` skips PowerShell checks when `pwsh` is unavailable.

## Findings by Category

### A. Gate Executability and Cross-Platform Readiness

#### Finding A1 - P0 - POSIX architecture-sync gate is broken by CRLF line endings

The POSIX gate is not executable via its canonical path. `gate/check_architecture_sync.sh` has CRLF line terminators in the working tree. Direct execution fails at the shebang, and explicit `bash gate/check_architecture_sync.sh` fails inside the script body.

Evidence:

- `gate/check_architecture_sync.sh` direct execution: `/usr/bin/env: 'bash\r': No such file or directory`.
- Explicit bash execution: `set: pipefail\r: invalid option name`.
- `git ls-files --eol gate/check_architecture_sync.sh` reports `i/lf w/crlf`.
- `gate/test_architecture_sync_gate.sh` fails because no POSIX architecture-sync log is produced.

Impact:

- POSIX architecture-sync evidence cannot be regenerated from the committed checkout.
- The cycle-7 delivery statement that POSIX architecture-sync evidence is current is operationally false in a Windows checkout.
- The gate intended to police architecture drift is itself not operator-ready.

Correction:

1. Add `.gitattributes` with:

   ```gitattributes
   *.sh text eol=lf
   gate/*.sh text eol=lf
   *.ps1 text eol=crlf
   *.md text eol=lf
   *.yaml text eol=lf
   *.json text eol=lf
   ```

2. Re-normalize all shell scripts with LF in the index and working tree.
3. Add an `eol_policy` rule to the architecture-sync gate that fails if any `*.sh` file contains CRLF.
4. Make `gate/test_architecture_sync_gate.sh` part of delivery evidence, not an optional helper.

Exit criteria:

- `gate/check_architecture_sync.sh` runs directly from WSL/Linux/macOS.
- `bash gate/check_architecture_sync.sh` also runs.
- `git ls-files --eol gate/*.sh` reports `w/lf` for all shell scripts.

#### Finding A2 - P1 - Self-test exists but is not a delivery gate

The new self-test correctly caught the broken POSIX gate, but the repository still contains a committed cycle-7 delivery file claiming the gate was usable. That means the self-test is not wired as a blocking delivery step.

Evidence:

- `gate/test_architecture_sync_gate.sh` exits 1 at `51ee916`.
- `docs/delivery/2026-05-08-ba4bcd5.md` still claims cycle-7 architecture-sync evidence.
- No delivery file records a self-test PASS artifact.

Impact:

- The team can commit a delivery evidence file even when the gate self-test is red.
- Future gate-script regressions may be documented after the fact instead of blocked before delivery.

Correction:

1. Add a delivery rule: no architecture-sync delivery file is valid unless `gate/test_architecture_sync_gate.sh` passes on the same evidence commit.
2. Record the self-test output in `docs/delivery/<date>-<sha>.md`.
3. Add `self_test_pass_sha` and `self_test_log` fields to the evidence manifest.

#### Finding A3 - P1 - PowerShell parity is optional in the self-test

The self-test skips PowerShell checks when `pwsh` is unavailable. That is acceptable for a local developer convenience test, but it cannot prove cross-platform parity.

Evidence:

- `gate/test_architecture_sync_gate.sh:72-92` checks `command -v pwsh` and prints `SKIP` when missing.
- The cycle-7 delivery file says the PowerShell script is a parity implementation and points to the self-test harness as validation.

Impact:

- A POSIX-only environment can claim self-test coverage without exercising the Windows gate.
- Cross-platform parity remains an assertion unless a Windows job actually runs the PowerShell script.

Correction:

1. Split self-tests into `local_smoke` and `delivery_required`.
2. For delivery-required evidence, require both:
   - Windows PowerShell gate run on a Windows host.
   - POSIX bash gate run on a POSIX host.
3. Store both logs in the manifest, or mark the missing platform as an explicit delivery blocker.

### B. Evidence Graph and SHA Binding

#### Finding B1 - P0 - Cycle-7 delivery references a non-existent reviewed-content log

The delivery file says the audit-trail diff includes `gate/log/ba4bcd5-posix.json`, but the actual audit-trail commit contains `gate/log/868dc85-posix.json`. The committed log reports `sha=868dc85`, which is neither the reviewed content SHA `ba4bcd5` nor the evidence commit SHA `51ee916`.

Evidence:

- `docs/delivery/2026-05-08-ba4bcd5.md:22` lists `gate/log/ba4bcd5-posix.json`.
- `git diff --name-only HEAD^..HEAD` lists `gate/log/868dc85-posix.json`.
- `gate/log/868dc85-posix.json` reports `"sha":"868dc85"`.

Impact:

- Reviewers cannot reconstruct which SHA actually passed.
- The delivery file, manifest, and committed log disagree on the evidence identity.
- A stale or unrelated log can be committed without failing the gate.

Correction:

1. Require every architecture-sync delivery file to name the exact committed log path.
2. Require that log path to exist.
3. Require the log's `sha` to equal either:
   - `reviewed_content_sha` for direct evidence, or
   - `evidence_commit_sha` for audit-trail evidence.
4. Reject logs whose `sha` is neither of those values.

#### Finding B2 - P0 - Delivery-log parity skips missing logs

The cycle-7 delivery-log parity rule still treats missing per-SHA logs as acceptable. In both scripts, if no matching `gate/log/<delivery-sha>-*.json` exists, the rule simply continues. This is why the `ba4bcd5` delivery file can survive without `gate/log/ba4bcd5-posix.json`.

Evidence:

- `gate/check_architecture_sync.sh:526-530` searches for matching logs and then continues if none is found.
- `gate/check_architecture_sync.ps1:493-497` does the same.

Impact:

- The strongest evidence rule only validates logs that happen to exist.
- Missing evidence is treated as absence of work, not a failure.
- Delivery files can describe a pass without a verifiable log.

Correction:

1. If a delivery file is current-authoritative, missing matching logs must fail.
2. If a historical delivery file predates platform-suffix logs, require an explicit legacy exemption list.
3. Make the delivery file include a machine-readable `evidence_log:` field.
4. Validate the field against the manifest and log content.

#### Finding B3 - P0 - Manifest v2 still permits `TBD` and `null` in authoritative evidence fields

The manifest claims to be the authoritative evidence graph, but its key evidence fields are intentionally unresolved. `evidence_commit_sha` and `authoritative_index_sha` are `TBD`, and `architecture_sync_logs` are null for both platforms.

Evidence:

- `docs/governance/evidence-manifest.yaml:32` has `evidence_commit_sha: TBD`.
- `docs/governance/evidence-manifest.yaml:62-63` has `posix: null` and `windows: null`.
- `docs/governance/evidence-manifest.yaml:156` has `authoritative_index_sha: TBD`.

Impact:

- The manifest cannot serve as a durable source of truth.
- Gate output becomes more authoritative than the committed manifest.
- Evidence validity depends on terminal output that may not be preserved.

Correction:

1. For delivery-valid evidence, forbid `TBD` in all identity fields.
2. Require at least one committed architecture-sync log per delivery-valid manifest.
3. If Windows evidence is absent, record it as `missing_blocker`, not `null`, unless the delivery classification is explicitly local-only.
4. Replace comments saying "set by gate" with committed values.

#### Finding B4 - P1 - "stdout PASS" is treated as canonical evidence

The manifest says the canonical pass evidence is the gate's stdout line at audit-trail SHA. That reverses the previous direction of remediation: delivery evidence should be durable and committed, not ephemeral terminal output.

Evidence:

- `docs/governance/evidence-manifest.yaml:60-62` says the canonical pass-evidence is the gate stdout.
- `docs/delivery/2026-05-08-ba4bcd5.md:31-33` makes the same argument.

Impact:

- Evidence cannot be independently re-read from the repository.
- CI logs or local terminal output become part of the trust chain without a retention contract.
- The manifest can pass while the committed evidence graph is incomplete.

Correction:

1. Treat stdout as a human convenience only.
2. Require committed JSON logs for all delivery-valid architecture-sync evidence.
3. Record `stdout_digest` only as an optional secondary checksum if needed.

### C. Rule 8 and Runtime Implementation

#### Finding C1 - P0 - Rule 8 remains fail-closed because there is no runnable artifact

The operator-shape smoke gate correctly fails closed. This remains the right outcome because the repository still has no executable system.

Evidence:

- `gate/run_operator_shape_smoke.ps1` returns `FAIL_ARTIFACT_MISSING`.
- `gate/run_operator_shape_smoke.sh` returns `FAIL_ARTIFACT_MISSING`.
- Missing artifacts include `pom.xml`, `agent-platform/pom.xml`, `agent-runtime/pom.xml`, and Java source trees.
- `docs/governance/evidence-manifest.yaml:78-81` records the same blocking state.

Impact:

- No artifact can ship.
- Security controls remain design assertions until implementation and three-layer tests exist.
- Architecture-sync evidence must not be interpreted as runtime readiness.

Correction:

1. Keep all runtime capabilities at L0/L1 until W0 creates an executable skeleton.
2. Build a minimal Maven multi-module Spring Boot artifact with real Postgres/LLM configuration surfaces.
3. Convert `run_operator_shape_smoke.*` from fail-closed absence evidence to a real Rule 8 flow only after the artifact exists.

#### Finding C2 - P1 - Rule 8 state parity is explicitly still unenforced

The manifest has `rule_8_state_parity: false`. That is honest, but it means the evidence graph cannot yet prove that status, delivery, and Rule 8 claims agree.

Evidence:

- `docs/governance/evidence-manifest.yaml:26` says `rule_8_state_parity: false`.
- `docs/governance/evidence-manifest.yaml:78-81` records fail-closed Rule 8 state.

Impact:

- A future delivery file could accidentally overstate Rule 8 readiness without a manifest parity failure.
- The project still relies on prose review to prevent shipping claims.

Correction:

1. Add a `rule_8_state_consistency` gate rule.
2. Assert that any delivery file saying Rule 8 PASS must reference `operator_shape_logs` with `rule_8_evidence: true`.
3. Assert that when `rule_8.state = fail_closed_artifact_missing`, no capability has `maturity: L3` or `evidence_state: operator_gated`.

### D. Active Architecture Corpus Quality

#### Finding D1 - P1 - Active docs still contain encoding corruption

Cycle 7 added ASCII-only checks for a small set of governance files, but active L1/L2 architecture and security matrix documents still contain mojibake. This is no longer just cosmetic: the project relies heavily on text gates, and corrupted characters reduce scan reliability.

Evidence:

- `docs/security-control-matrix.md:1-6` contains corrupted punctuation.
- `agent-runtime/server/ARCHITECTURE.md:1-20` contains corrupted arrows and section markers.
- `agent-runtime/auth/ARCHITECTURE.md:1-20` contains corrupted arrows and accented text.

Impact:

- Text gates may miss intended terms or match corrupted terms incorrectly.
- Readers cannot reliably distinguish current design from encoding damage.
- The corpus looks less trustworthy than the governance standard it describes.

Correction:

1. Extend `ascii_only_governance` to all current active architecture files, not only selected governance docs.
2. Add a historical-file exemption list for intentionally preserved legacy docs.
3. Normalize active docs to UTF-8 or strict ASCII; given this repo's current gates, ASCII is safer.

### E. Governance Model and Maturity Claims

#### Finding E1 - P1 - Maturity language is still not fully primary

Cycle 7 acknowledged that status should be secondary to L0-L4 maturity, but the status ledger and README still lead with `implemented_unverified` and `design_accepted`.

Evidence:

- `docs/governance/architecture-status.yaml:238-241` uses delivery-valid SHA fields under `architecture_sync_gate`.
- `gate/README.md:68-69` still presents capability status as `implemented_unverified` / `design_accepted`.

Impact:

- Readers may infer stronger readiness from `implemented_unverified` than from L0.
- Automated policy must interpret two status systems.

Correction:

1. Make `maturity` the first field in every capability row.
2. Rename `status` to `evidence_state` everywhere.
3. Require delivery files to summarize maturity first, then evidence state.

## Systemic Remediation Plan

### W0.1 - Make gate scripts operator-executable

1. Add `.gitattributes`.
2. Re-normalize all `*.sh` files to LF.
3. Add `eol_policy` to the architecture-sync gate.
4. Require the self-test to pass before any delivery file can be committed.

### W0.2 - Close the evidence graph

1. Remove `TBD` from delivery-valid manifest fields.
2. Require at least one committed architecture-sync log for the current authoritative delivery.
3. Make delivery files reference exact committed log paths.
4. Reject logs whose `sha` is not the reviewed content SHA or evidence commit SHA.
5. Make missing logs a failure, not a skip.

### W0.3 - Separate local convenience from delivery validity

1. Keep `--local-only` and optional platform skips for developer loops.
2. For delivery, require both Windows and POSIX platform evidence or mark the delivery as non-authoritative.
3. Record platform-specific evidence in the manifest with explicit states: `pass`, `fail`, `missing_blocker`, or `not_applicable`.

### W0.4 - Keep Rule 8 fail-closed until W0 runtime exists

1. Preserve `FAIL_ARTIFACT_MISSING` as the correct operator-shape result.
2. Add `rule_8_state_consistency` so no document can claim runtime readiness early.
3. Begin runtime implementation only after the minimal W0 artifact and three-layer test plan are ready.

### W0.5 - Normalize active corpus text

1. Convert active L0/L1/L2 docs and current governance files to ASCII or clean UTF-8.
2. Add an active-corpus encoding gate.
3. Keep historical files excluded only with explicit banners.

## Definition of Done for the Next Remediation Pass

The next pass is complete only when all of the following are true:

1. `gate/check_architecture_sync.sh` runs directly and through `bash` on POSIX.
2. `gate/test_architecture_sync_gate.sh` passes.
3. `.gitattributes` enforces LF for shell scripts.
4. The authoritative delivery file references an existing committed log.
5. The referenced log's `sha` is either the reviewed content SHA or the evidence commit SHA.
6. Manifest delivery-valid fields contain no `TBD`.
7. `architecture_sync_logs` contains real log paths or explicit blocking states.
8. Missing delivery logs fail both PowerShell and POSIX gates.
9. Rule 8 remains fail-closed and cannot be overstated by any delivery file.
10. Active architecture/security docs no longer contain visible encoding corruption.

## Final Recommendation

The architecture team should treat cycle 8 as an evidence-hardening cycle, not a design-expansion cycle. The right next move is small but non-negotiable: fix line endings, require self-test PASS, make missing logs fatal, and commit exact evidence graph fields. Once the governance layer can prove what it says, W0 runtime work can start on a much firmer base.
