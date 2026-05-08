# Systematic Architecture Remediation Plan -- Cycle-8 Response

Date: 2026-05-08
Reviewed input documents:

- `docs/systemic-remediation-operating-plan-2026-05-08.en.md` (the systemic
  diagnosis + Phase 0..6 program).
- `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-8.en.md`
  (the per-finding cycle-8 review).

Stance: this is the cycle-8 author's structured response after the strict
review. Each finding is given an ACCEPT / ACCEPT-WITH-NOTE / DEFER /
REJECT verdict with reasoning. Accepted findings are mapped to concrete
fixes that ship in the cycle-8 architectural commit.

## 1. Per-finding decisions (cycle-8 review)

| Finding | Severity | Verdict | Resolution |
|---|---|---|---|
| A1 -- POSIX gate broken by CRLF | P0 | ACCEPT | `.gitattributes` enforces LF for `*.sh`/`*.md`/`*.yaml`/`*.json`; gate adds `eol_policy` rule that fails if any tracked `*.sh` has CRLF in index or working tree. |
| A2 -- Self-test exists but not delivery-blocking | P1 | ACCEPT | Manifest gains `self_test`: `pass_sha`, `log_path`, `state`. Delivery rules require self-test PASS at evidence commit SHA. |
| A3 -- PowerShell parity optional in self-test | P1 | ACCEPT-WITH-NOTE | Manifest tracks per-platform state explicitly (`pass`/`fail`/`missing_blocker`/`not_applicable`/`historical_only`). When `pwsh` is absent, the manifest records `architecture_sync_logs.windows.state: missing_blocker`. The self-test does not crash, but a manifest with two `missing_blocker` slots is not delivery-valid. (NOTE: full CI matrix remains W1; this cycle adds the blocker contract, not the CI pipeline.) |
| B1 -- Delivery references non-existent log | P0 | ACCEPT | New gate rule `delivery_log_exact_binding`: every authoritative delivery file MUST name its log path; the named log MUST exist; the log's `sha` field MUST equal `reviewed_content_sha` or `evidence_commit_sha`. Cycle-7 delivery file is corrected; the stale `gate/log/868dc85-posix.json` is removed by the cycle-8 architectural commit. |
| B2 -- Delivery-log parity skips missing logs | P0 | ACCEPT | `delivery_log_parity` rule no longer skips on missing log when the delivery file is named in the manifest as the current authoritative delivery (or when its date prefix is the active cycle); it FAILS. Historical legacy deliveries (cycles 1..3, pre-suffix naming) are listed in `manifest.architecture_sync_logs.legacy_exemptions[]`. |
| B3 -- `TBD`/`null` in authoritative manifest fields | P0 | ACCEPT | Manifest schema bumped to `evidence-manifest/v3`. `TBD` is forbidden in delivery-valid identity fields. Log slots use explicit states. |
| B4 -- "stdout PASS" treated as canonical | P1 | ACCEPT | Manifest comments removed. Delivery files state explicitly that the canonical evidence is the committed JSON log; stdout is a human convenience only. |
| C1 -- Rule 8 fail-closed because no artifact | P0 | ACCEPT-AS-CORRECT | The fail-closed outcome is the correct shape for pre-W0. No code change; manifest records `rule_8.state: fail_closed_artifact_missing` explicitly and `rule_8_state_consistency` rule below makes overstating impossible. |
| C2 -- Rule 8 state parity unenforced | P1 | ACCEPT | New gate rule `rule_8_state_consistency`: when `manifest.rule_8.state == fail_closed_artifact_missing`, no capability row in status YAML may have `maturity: L3` or `evidence_state: operator_gated`; no delivery file may claim Rule 8 PASS. |
| D1 -- Active corpus encoding corruption | P1 | ACCEPT | Phase 3 Active Corpus Registry is created (`docs/governance/active-corpus.yaml`). `ascii_only_governance` rule is renamed `ascii_only_active_corpus` and its scan list is derived from the registry. All ~35 active L0/L1/L2/cross-cutting docs are converted to ASCII. Banner-marked + path-skipped historical docs remain excluded. |
| E1 -- Maturity not primary | P1 | ACCEPT | Status YAML re-ordered so `maturity` is the first field on every capability row. `evidence_state` alias is introduced (mirrors `status` for backward compatibility); the gate now reads either name. |

## 2. Per-phase decisions (systemic operating plan)

| Phase | Verdict | Rationale + scope landed in cycle-8 |
|---|---|---|
| 0 -- Stop-the-line stabilization | ACCEPT | Cycle-8 architectural commit lands `.gitattributes`, LF normalization, gate self-test as a delivery requirement, and a "no L2+ promotion during stabilization" rule (encoded as `rule_8_state_consistency` + `evidence_state` constraints). |
| 1 -- Evidence Graph v3 | ACCEPT | Manifest schema bumped to v3 with `reviewed_content_sha`, `evidence_commit_sha`, `evidence_commit_parent_sha`, `evidence_commit_classification`, `delivery_file`, per-platform `architecture_sync_logs.{posix,windows}.{path,state}`, `operator_shape_logs.{posix,windows}.state`, `self_test.{pass_sha,log_path,state}`, `rule_8.state`, `capability_registry_path`, `active_corpus_path`, `current_index_path`. |
| 2 -- Gate productization | ACCEPT-PARTIAL | Cycle-8 lands: gate split into `--local-only` (today) and a delivery contract that requires the self-test. Fixture-based tests + CI matrix (Phase 2 actions 3, 4, 5) are W1 because they require a CI runner not present in this environment; the manifest records `gate_ci_matrix.state: missing_blocker` to make the gap explicit. |
| 3 -- Active corpus registry | ACCEPT | `docs/governance/active-corpus.yaml` created. Gate scan list derives from it. Encoding gate scoped via the registry. Historical docs are excluded by registry, not by ad hoc filename patterns (filename patterns retained as a defensive second line until W1). |
| 4 -- Capability registry + maturity reset | ACCEPT-PARTIAL | Status YAML re-ordered with `maturity` first; `evidence_state` alias added. A separate `capability-registry.yaml` is W1: introducing it now would require also migrating every consumer (matrix, READMEs, gate); cycle-8 instead extends the existing ledger and documents the W1 migration in `docs/plans/roadmap-W0-W4.md`. |
| 5 -- Minimal W0 runtime vertical slice | DEFER | Both review documents agree that runtime work should follow control-plane stabilization. Cycle-8 explicitly preserves `rule_8.state: fail_closed_artifact_missing` and the `rule_8_state_consistency` rule. W0 will land in a separate sprint after the cycle-8 evidence graph is stable. |
| 6 -- Security control implementation waves | DEFER | Same reason as Phase 5. Each wave depends on a runnable artifact. Cycle-8 keeps capabilities at L0/L1 so no wave can falsely claim closure. |

## 3. Findings explicitly NOT accepted

There are no rejected findings in cycle-8. The two DEFER items (Phases 5, 6)
are not rejections: the reviewer's own ordering places them after Phases 0..4,
and the cycle-8 strict review's final recommendation is "treat cycle 8 as an
evidence-hardening cycle, not a design-expansion cycle." Cycle-8's response
matches that recommendation exactly.

## 4. Cycle-8 architectural commit content (W0.1..W0.5 + Phase 0..4 partial)

Files changed in the cycle-8 architectural commit:

1. `.gitattributes` -- LF policy (Phase 0; A1).
2. `gate/check_architecture_sync.{sh,ps1}` -- new rules:
   `eol_policy`, `delivery_log_exact_binding`, `rule_8_state_consistency`,
   `ascii_only_active_corpus` (registry-driven). Tightened
   `delivery_log_parity` (no skip on missing log for current authoritative
   delivery). Version bumped to `cycle-8-evidence-graph-v3`.
3. `gate/test_architecture_sync_gate.sh` -- self-test now also asserts the
   manifest evidence graph (log paths exist; SHAs are consistent; states are
   from the explicit enum); records its own pass into the manifest's
   `self_test` block.
4. `docs/governance/evidence-manifest.yaml` -- schema v3.
5. `docs/governance/active-corpus.yaml` -- new; Phase 3 + D1.
6. `docs/governance/architecture-status.yaml` -- `maturity` first on every
   row; `evidence_state` alias.
7. Active L0/L1/L2 + cross-cutting docs -- ASCII conversion (D1).
8. `docs/plans/roadmap-W0-W4.md` -- adds explicit references to
   Phases 5, 6 deferral and the W0 unblock criteria.
9. `docs/governance/current-architecture-index.md` -- references the new
   registry + the W0.1..W0.5 deliverables.
10. `gate/README.md`, `docs/delivery/README.md` -- delivery rules updated
    to require self-test PASS, the exact-log-binding contract, and explicit
    per-platform states.

The cycle-8 audit-trail commit on top of the architectural commit lands:

- `docs/delivery/2026-05-08-<arch_sha>.md` (cycle-8 delivery file).
- `gate/log/<arch_sha>-posix.json` (POSIX architecture-sync log).
- `gate/log/<arch_sha>-windows.json` if `pwsh` is available; otherwise the
  manifest carries `architecture_sync_logs.windows.state: missing_blocker`.
- Updated `docs/governance/evidence-manifest.yaml` with the audit-trail SHA.
- Updated `docs/governance/architecture-status.yaml` and
  `docs/governance/current-architecture-index.md` with the new delivery
  pointer. (Strict subset of `allowed_audit_trail_paths`.)

## 5. Definition-of-Done coverage (cycle-8 review's checklist)

| Cycle-8 DoD item | Cycle-8 fix |
|---|---|
| 1. POSIX gate runs directly + via `bash` | LF normalization + `.gitattributes` (A1). |
| 2. `gate/test_architecture_sync_gate.sh` passes | Self-test passes after CRLF fix; manifest records pass. |
| 3. `.gitattributes` enforces LF for shell | Yes (added). |
| 4. Authoritative delivery references existing log | Cycle-8 delivery references `gate/log/<arch_sha>-posix.json` (committed). |
| 5. Log SHA equals reviewed-or-evidence SHA | Enforced by `delivery_log_exact_binding`. |
| 6. No `TBD` in delivery-valid manifest | Enforced by manifest v3 + `manifest_no_tbd` rule. |
| 7. `architecture_sync_logs` real paths or explicit states | Enforced by manifest v3 schema. |
| 8. Missing logs FAIL on both gates | Enforced by `delivery_log_parity` (no skip path). |
| 9. Rule 8 cannot be overstated | Enforced by `rule_8_state_consistency`. |
| 10. Active docs no encoding corruption | All ~35 active docs converted to ASCII. |

## 6. Out-of-scope for cycle-8 (acknowledged W1+ work)

- CI matrix (Phase 2.4): GitHub Actions workflow `ci-architecture-sync.yml`
  with Windows + Ubuntu jobs.
- Negative fixture suite (Phase 2.3): explicit failing fixtures for every
  rule category.
- Capability registry as a separate file (Phase 4.1, 4.2).
- Convergence dashboard generation.
- Maturity language full rename (`status` -> `evidence_state` everywhere).
- W0 runtime vertical slice (Phase 5 + Cycle-8 C1).

These items are tracked as findings `REM-2026-05-08-C8-*` in
`docs/governance/architecture-status.yaml`.

## 7. Convergence status after cycle-8

| Convergence metric (per systemic plan sec-Convergence) | Pre-cycle-8 | Post-cycle-8 |
|---|---|---|
| Repeated P0/P1 finding families | 4 (encoding, manifest TBD, delivery-log parity, gate executability) | 0 (each family has a structural rule) |
| Delivery-valid `TBD` fields | 3 | 0 |
| Delivery-valid `null` evidence fields | 4 | 0 (replaced by explicit states) |
| Missing required platform logs | unbounded (silently skipped) | 0 (explicit `missing_blocker`) |
| Gate self-test pass rate | manual / not delivery-blocking | required for delivery |
| Active corpus encoding violations | ~35 files | 0 |
| Capabilities above L1 without tests | 0 | 0 |
| Capabilities at L3 without Rule 8 PASS | 0 (latent risk) | 0 (rule-enforced) |
| Findings fixed only by prose edit | 4 (cycle-7 family) | 0 (every cycle-8 finding has a rule) |
| Findings with negative fixture | 0 | 0 (W1) |

## 8. Final summary

Cycle-8 is an evidence-hardening cycle, not a design-expansion cycle. It
accepts every concrete cycle-8 finding and the systemic plan's Phases 0-4 +
W0.1-W0.5; it defers Phases 5 and 6 in line with the systemic plan's own
recommended sequencing. The cycle-8 architectural commit lands the rules
that make each previously-recurring failure family structurally impossible,
not just textually corrected.
