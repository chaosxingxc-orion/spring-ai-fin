# gate — Operator-shape gate scripts

Per CLAUDE.md Rule 8 and `docs/systematic-architecture-improvement-plan-2026-05-07.en.md` §4.8.

This directory holds the executable gate scripts. They run against a long-lived process with real dependencies and verify the six properties of Rule 8.

## Scripts (W0 deliverables)

- `run_operator_shape_smoke.sh` — Linux/macOS entry point
- `run_operator_shape_smoke.ps1` — Windows entry point
- `check_architecture_sync.sh` / `.ps1` — verifies `docs/governance/decision-sync-matrix.md` against the L0/L2 corpus

## Invariants

- Scripts MUST exit non-zero on any FAIL.
- Scripts MUST emit a structured JSON log to `gate/log/<sha>.json` so the delivery file at `docs/delivery/<date>-<sha>.md` can attach it.
- Scripts MUST NOT mock providers or databases. If a real dependency is unavailable, the script exits with a "dependency missing" reason that the caller can react to (e.g., skip on developer laptop with `--allow-skip`); CI does not pass `--allow-skip`.

## Status

The scripts themselves are W0 deliverables; this directory is a placeholder until W0 lands.
