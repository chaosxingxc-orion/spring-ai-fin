# gate -- Architecture-sync gates and (planned) Rule 8 operator-shape gate

Per CLAUDE.md Rule 8, `docs/systematic-architecture-improvement-plan-2026-05-07.en.md` sec-4.8, and `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-3.en.md` sec-8.

This directory holds two distinct families of gate scripts. They are NOT interchangeable. The architecture-sync gate proves the document corpus is internally consistent; the Rule 8 operator-shape gate proves a runnable artifact behaves correctly under deployment shape.

## Implemented now (architecture-sync gate)

- `check_architecture_sync.ps1` -- Windows PowerShell entry point
- `check_architecture_sync.sh` -- Linux / macOS / Git Bash entry point

These scan the architecture corpus (44-45 files: L0 + L1/L2 `ARCHITECTURE.md` + governance + delivery + gate metadata) and enforce the rules documented in `docs/governance/closure-taxonomy.md` and the cycle-1/2/3 remediation plans. They emit `gate/log/<sha>.json` with `working_tree_clean`, `semantic_pass`, `evidence_valid_for_delivery`, and a structured `failures` list with line numbers.

**These architecture-sync gates do NOT satisfy Rule 8.** They:

- do NOT start the application;
- do NOT use real dependencies;
- do NOT execute three sequential public-entry runs;
- do NOT prove resource reuse, lifecycle observability, cancellation round-trip, or fallback-zero;
- are NOT release evidence.

A PASS from these gates only means the document corpus is internally consistent. It does not authorize ship.

### Modes

| Invocation | Working tree | `evidence_valid_for_delivery` | Use |
|---|---|---|---|
| `bash check_architecture_sync.sh` (default) | must be clean | `true` on PASS | the only mode whose log a delivery file may reference |
| `bash check_architecture_sync.sh --local-only` | may be dirty | `false` always (enforced by script) | local development; cannot be referenced by delivery |
| `pwsh check_architecture_sync.ps1` (default) | must be clean | `true` on PASS | Windows equivalent |
| `pwsh check_architecture_sync.ps1 -LocalOnly` | may be dirty | `false` always (enforced by script) | Windows local development |

The two scripts emit equivalent semantic results. **Local-only enforcement is done by the script itself** (cycle-14 A2): even on a clean tree, `--local-only` / `-LocalOnly` forces `evidence_valid_for_delivery=false` and always writes under `gate/log/local/`. The `gate/log/self-test-*.sh` fixture verifies this invariant.

Two additional gate rules are enforced by both scripts (cycle-14 A1 and B1):

- `ci_no_or_true_mask`: scans `.github/workflows/*.yml` and fails if any line that calls `gate/run_*` also contains `|| true`. Prevents a silently-ignored operator-shape smoke result from masking CI failure.
- `rule_8_state_machine_coherent`: cross-validates `artifact_present_state` against `rule_8.state` in the manifest. Valid pairs: `none <-> fail_closed_artifact_missing`, `source_only <-> fail_closed_needs_build`, `jar_present <-> fail_closed_needs_real_flow | pass`.

## Operator-shape smoke gate -- fail-closed pre-W0; runnable-flow post-W0

- `run_operator_shape_smoke.ps1` -- Windows entry point (exists; cycle-4-fail-closed)
- `run_operator_shape_smoke.sh` -- Linux / macOS entry point (exists; cycle-4-fail-closed)

**Current state**: both scripts exist and **fail closed** (exit 1 with structured `FAIL_ARTIFACT_MISSING` JSON written to `gate/log/local/operator-shape-<sha>-{posix,windows}.json`) because no runnable artifact exists yet. They are NOT Rule 8 PASS evidence -- only Rule 8 absence-evidence.

When W0 produces the runnable artifact (Maven multi-module + minimal Spring Boot per `docs/plans/W0-evidence-skeleton.md`), these scripts will be replaced with the real Rule 8 flow. Until then the architecture's own Rule 8 says "no PASS exists at this SHA."

The eventual real Rule 8 smoke flow must:

1. build the runnable artifact;
2. start a long-lived managed process (systemd / docker / pm2 / supervised JVM);
3. use real local Postgres (no mock);
4. use a real LLM provider (no mock under research/prod);
5. hit `/health` and `/ready`;
6. perform three sequential `POST /v1/runs` invocations against the same long-lived process;
7. prove every run reaches a terminal state in <= `2 x observed_p95`;
8. prove run lifecycle fields (`current_stage`, `finished_at`) populate within 30s and on terminal respectively;
9. cancel a live run and drive it to a terminal state (`200`);
10. cancel an unknown run id and return `404`;
11. assert `*_fallback_total == 0` for the happy path;
12. write `gate/log/<sha>.json` with `evidence_valid_for_delivery=true`;
13. write `docs/delivery/<date>-<sha>.md` referencing the log.

`run_operator_shape_smoke.*` exists in fail-closed form **until W0 produces a runnable artifact**. Once the artifact exists, the scripts are replaced with the real flow. There is no `--local-only` mode for the operator-shape gate; dirty trees are never valid Rule 8 evidence.

## Audit trail

`gate/log/<sha>.json` files are kept on GitHub as audit artifacts (per the user's "all process artifacts on GitHub" policy committed in `f67719f`). Maintainers commit gate logs that delivery files reference.

## Status (per `docs/governance/architecture-status.yaml`)

Cycle-8 sec-E1: maturity is the primary readiness language. Status / evidence_state is the lifecycle field.

- **`architecture_sync_gate` capability**: maturity `L0`; evidence_state `implemented_unverified`. Both `check_architecture_sync.ps1` and `check_architecture_sync.sh` exist; latest delivery-valid PASS recorded by the manifest in `docs/governance/evidence-manifest.yaml`.
- **`operator_shape_smoke_gate` capability**: maturity `L0`; evidence_state `design_accepted`. Both `run_operator_shape_smoke.ps1` and `run_operator_shape_smoke.sh` **exist in `cycle-4-fail-closed` form** (exit 1 with structured `FAIL_ARTIFACT_MISSING` JSON to `gate/log/local/operator-shape-<sha>-{posix,windows}.json`). They are NOT Rule 8 PASS evidence -- only honest absence-evidence. W0 will replace fail-closed with the real Rule 8 flow once a runnable artifact exists.

No reader should mistake an architecture-sync PASS for Rule 8 evidence. No reader should mistake `FAIL_ARTIFACT_MISSING` for "the script does not exist."

## Cycle-8 evidence contract

Per `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-8.en.md` and `docs/systemic-remediation-operating-plan-2026-05-08.en.md` Phases 0-4:

1. `gate/test_architecture_sync_gate.sh` MUST PASS at the evidence commit SHA before any delivery file is committed (cycle-8 sec-A2). The self-test result is recorded in `gate/log/local/self-test-<sha>.json` and copied by the audit-trail commit when authoritative.
2. The current authoritative `manifest.delivery_file` MUST have a matching `gate/log/<sha>-{posix,windows}.json` whose `sha` field equals the manifest's `reviewed_content_sha` or HEAD (cycle-8 sec-B1, sec-B2).
3. `architecture_sync_logs.{posix,windows}.state` is from the closed enum: `pass | fail | missing_blocker | not_applicable | historical_only | pre_audit_trail`. `null` and `TBD` are forbidden in delivery-valid manifest fields (cycle-8 sec-B3).
4. `*.sh` scripts are LF (CRLF disallowed by `.gitattributes` and the `eol_policy` gate rule; cycle-8 sec-A1).
5. Active corpus files are ASCII only, scoped via `docs/governance/active-corpus.yaml` (cycle-8 sec-D1, Phase 3).
6. While `manifest.rule_8.state == fail_closed_artifact_missing`, no capability has maturity `L3`/`L4` or `evidence_state: operator_gated` / `released`, and no delivery file claims Rule 8 PASS (cycle-8 sec-C2).
