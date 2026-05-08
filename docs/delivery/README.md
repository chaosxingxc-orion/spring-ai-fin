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
