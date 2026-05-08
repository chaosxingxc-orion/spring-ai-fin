# delivery — Operator-shape gate evidence

Per CLAUDE.md Rule 8 and `docs/systematic-architecture-improvement-plan-2026-05-07.en.md` §4.8.

Every release SHA records its operator-shape gate run as `docs/delivery/<date>-<sha>.md`. Format:

```markdown
# Delivery <date> <short-sha>

## Posture / shape
- APP_POSTURE=
- APP_DEPLOYMENT_SHAPE=

## Long-lived process
- start command:
- pid:
- uptime at gate end:

## Real dependencies
- Postgres URL (redacted):
- LLM provider:
- WORM target (if prod):

## Sequential runs
| run | terminal status | duration | fallback_events |
|---|---|---|---|
| 1 | DONE |  | [] |
| 2 | DONE |  | [] |
| 3 | DONE |  | [] |

## Cross-context resource stability
- WebClient instance reuse confirmed: yes/no
- Connection pool reuse confirmed: yes/no

## Lifecycle observability
- current stage non-null within 30s: yes/no
- finished_at populated on terminal: yes/no

## Cancellation round-trip
- known run id -> 200 + DRIVE_TO_TERMINAL: yes/no
- unknown run id -> 404: yes/no

## Gate result
- PASS / FAIL
- recorded by:
- log attached: gate/log/<sha>.json
```

A release without a delivery file at its SHA is unreleased.

## Dirty-tree rule

**Delivery files MUST NOT attach dirty-tree gate logs.** Per `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-2.en.md` §8, a clean working tree is a precondition for any delivery file:

- The gate log referenced by a delivery file MUST have `working_tree_clean: true` and `evidence_valid_for_delivery: true`.
- Logs produced under `--local-only` mode have `evidence_valid_for_delivery: false` and CANNOT be referenced from a delivery file.
- A delivery file that references a `evidence_valid_for_delivery: false` log is rejected by the next remediation gate.
- The architecture-sync gate fails by default when `git status --porcelain` is non-empty; `--local-only` is the only escape, and it is explicitly non-delivery evidence.
- `gate/run_operator_shape_smoke.*` (W0 deliverable) MUST never accept dirty-tree input under any flag — there is no local-only mode for the operator-shape gate.

A delivery file's `Gate result` section must record the gate log path AND assert `evidence_valid_for_delivery: true`. Anything else is a draft, not a delivery file.

## SHA-current rule (cycle-3)

Per `docs/systematic-architecture-remediation-plan-2026-05-08-cycle-3.en.md` §5, every review or release decision must be evaluated against the **exact SHA being reviewed**, not an earlier SHA:

- A delivery file at `docs/delivery/<date>-<X>.md` is evidence for SHA `X` only. It cannot be reused as evidence for any later SHA `Y`, even when `Y` differs from `X` only by documentation edits.
- A reviewer evaluating SHA `Y` must confirm:
  1. there is a `gate/log/<Y>.json` with `working_tree_clean: true`, `semantic_pass: true`, and `evidence_valid_for_delivery: true`;
  2. there is a `docs/delivery/<date>-<Y>.md` referencing that log;
  3. the delivery file states explicitly whether it is **architecture-sync evidence** or **Rule 8 operator-shape evidence**;
  4. for Rule 8 claims, the log was produced by `gate/run_operator_shape_smoke.*` (not `gate/check_architecture_sync.*`).
- If any condition fails, the SHA is unreviewed for that purpose. Older delivery files are retained as historical record only.

## Architecture-sync evidence vs Rule 8 evidence

Every delivery file MUST classify itself in its header:

- **Architecture-sync evidence** — produced by `gate/check_architecture_sync.{ps1,sh}`. Proves the document corpus is internally consistent at a SHA. Does NOT prove the system runs. Cannot authorize ship.
- **Rule 8 operator-shape evidence** — produced by `gate/run_operator_shape_smoke.{ps1,sh}`. The scripts exist in fail-closed form (cycle-4-fail-closed) and will produce only `FAIL_ARTIFACT_MISSING` until W0 lands a runnable artifact. Once W0 lands, the scripts run the real Rule 8 flow (long-lived process, real dependencies, sequential runs, cancellation, lifecycle, fallback-zero) and the resulting PASS log is the only kind of evidence that can authorize ship. A `FAIL_ARTIFACT_MISSING` log is NOT delivery evidence — it is honest absence-evidence.

A delivery file that mixes the two classifications, or omits the classification entirely, is rejected by the next remediation gate.
