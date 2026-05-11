# gate -- Architecture-sync gate (Occam's Razor cut, C24)

This directory holds two families of scripts. They are NOT interchangeable.

- **Architecture-sync gate** (`check_architecture_sync.*`) -- proves the document corpus is internally consistent.
- **Operator-shape smoke gate** (`run_operator_shape_smoke.*`) -- proves a runnable artifact behaves correctly under deployment shape (excluded from CI intentionally; fail-closed until W0 artifact lands).

## How to run

```bash
# Linux / macOS / Git Bash
bash gate/check_architecture_sync.sh

# Windows PowerShell
pwsh gate/check_architecture_sync.ps1
```

Exits 0 if all 6 rules pass (`GATE: PASS`), 1 if any fail (`GATE: FAIL`).

## The 6 rules

| # | Rule name | What it catches |
|---|---|---|
| 1 | `status_enum_invalid` | `docs/governance/architecture-status.yaml` `status:` values outside `{design_accepted, implemented_unverified, test_verified, deferred_w1, deferred_w2}` |
| 2 | `delivery_log_parity` | `gate/log/*.json` where `sha` field != filename basename, or `semantic_pass` field is missing |
| 3 | `eol_policy` | `*.sh` files in `gate/` that contain CRLF (must be LF) |
| 4 | `ci_no_or_true_mask` | `.github/workflows/*.yml` lines invoking `gate/run_*` masked with `\|\| true` |
| 5 | `required_files_present` | Missing `docs/contracts/contract-catalog.md` or `docs/contracts/openapi-v1.yaml` |
| 6 | `metric_naming_namespace` | Java metric names in `agent-platform/src` or `agent-runtime/src` without `springai_ascend_` prefix; also catches residual `springai_fin_` |

## Self-test

```bash
bash gate/test_architecture_sync_gate.sh
```

Runs 12 tests (one positive + one negative per rule). Prints `Tests passed: N/12`.

## Excluded scripts (do not modify)

- `run_operator_shape_smoke.sh` / `.ps1` -- excluded from CI intentionally; fail-closed until W0 artifact.
- `check_spring_ai_milestone.sh`, `doctor.sh`, `doctor.ps1` -- separate concerns.

## Audit trail

`gate/log/<sha>-posix.json` / `gate/log/<sha>-windows.json` files are kept on GitHub as audit artifacts. These are written by the old 27-rule script and remain as historical evidence. New runs of this 6-rule gate do not write log files.
