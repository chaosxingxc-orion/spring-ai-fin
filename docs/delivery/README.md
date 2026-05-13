# docs/delivery/ — Gate Evidence Files

> Every release SHA records its gate evidence as `docs/delivery/<date>-<short-sha>.md`. A release without a delivery file at its SHA is unreleased.

## What is this?

`docs/delivery/` is the audit trail for every release SHA. Each file is the formal evidence — gate logs, posture, deployment shape, real-dependency verification — that authorized the SHA to ship. The format is fixed (see template below) so a reviewer can confirm at a glance that a given SHA actually passed the gates it claims to have passed.

## How to write a delivery file

**Filename.** `docs/delivery/<yyyy-mm-dd>-<short-sha>.md`, where `<short-sha>` is the first 7 hex chars of `git rev-parse HEAD`.

**Template.**

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

Every delivery file **must classify itself in its header**:

- **Architecture-sync evidence** — produced by `gate/check_architecture_sync.{ps1,sh}`. Proves the document corpus is internally consistent. Cannot authorize ship by itself.
- **Operator-shape evidence (CLAUDE.md Rule 8)** — produced by `gate/run_operator_shape_smoke.{ps1,sh}`. Proves the running system behaves under a real deployment shape. The only evidence that can authorize ship. (Currently fail-closed until a W4 runnable-artifact target lands; until then these scripts produce only `FAIL_ARTIFACT_MISSING`, which is honest absence-evidence, not delivery evidence.)

A file that mixes the two classifications, or omits the classification entirely, is rejected.

## Policies

### Dirty-tree rule

A delivery file **must not** attach a dirty-tree gate log. The referenced log MUST have `working_tree_clean: true` AND `evidence_valid_for_delivery: true`.

- The architecture-sync gate fails by default when `git status --porcelain` is non-empty. The `--local-only` flag is the only escape, and logs produced under it carry `evidence_valid_for_delivery: false` — they cannot be referenced from a delivery file.
- `gate/run_operator_shape_smoke.*` has no local-only mode; it must never accept dirty-tree input under any flag.

### SHA-current rule

Delivery evidence is valid only for the **exact SHA** it was produced at. A `docs/delivery/<date>-<X>.md` file is evidence for SHA `X` only; it cannot be reused for any later SHA `Y`, even when `Y` differs from `X` only by documentation edits.

A reviewer evaluating SHA `Y` must confirm all of:

1. `gate/log/<Y>.json` exists with `working_tree_clean: true`, `semantic_pass: true`, `evidence_valid_for_delivery: true`.
2. `docs/delivery/<date>-<Y>.md` exists and references that log.
3. The delivery file explicitly states whether it is architecture-sync evidence or Rule 8 operator-shape evidence.
4. For Rule 8 claims, the log was produced by `gate/run_operator_shape_smoke.*` (not `gate/check_architecture_sync.*`).

If any check fails, the SHA is unreviewed for that purpose.

### Architecture-sync vs operator-shape (the ship boundary)

Architecture-sync evidence answers "is the document corpus self-consistent?" Operator-shape evidence answers "does the system run correctly under deployment?" Only the latter authorizes a production ship. Conflating them is a common reviewer error and is explicitly prohibited.

## See also

- [gate/README.md](../../gate/README.md) — architecture-sync gate (26 rules) and self-tests.
- [ARCHITECTURE.md](../../ARCHITECTURE.md) — wave-boundary constraints and §4 #1–#44.
- [CLAUDE.md](../../CLAUDE.md) — engineering Rule 9 (self-audit is a ship gate) defines the ship-blocking categories.
- [docs/governance/architecture-status.yaml](../governance/architecture-status.yaml) — per-capability ledger (the truth `architecture-sync` evidence proves consistent with).
