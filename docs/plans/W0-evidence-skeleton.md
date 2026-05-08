# W0 — Evidence Skeleton

> Per `docs/systematic-architecture-improvement-plan-2026-05-07.en.md` §4.8 and §5.

## Goal

Convert the corpus from "document-only" into a runnable, gateable skeleton. The skeleton's purpose is to prove the architecture **can** be operated, not to ship features. No capability rises above L1 in W0.

## Scope

- A Maven multi-module build that compiles cleanly.
- A minimal Spring Boot app with `/health`, `/ready`, and a stub `POST /v1/runs` + `GET /v1/runs/{id}` route.
- `AppPosture` + `DeploymentShape` + `PostureBootGuard` wired and read once at boot.
- `ContractError` (record) and `ContractException` (RuntimeException) compiled and exercised by the controller advice.
- `RunRecord` with `tenant_id` persisted to a real local Postgres (no in-memory backend on `research`).
- `gate/run_operator_shape_smoke.{sh,ps1}` script that drives steps 1–6 of Rule 8.
- `docs/delivery/<date>-<sha>.md` recorded for the W0 SHA.

## Out of scope (deferred to later waves)

- ActionGuard pipeline (W2)
- Audit class model + WORM (W2)
- JWKS validation, IssuerRegistry (W2)
- RLS connection interceptor (W2)
- SyncSagaOrchestrator + FinancialWriteClass (W3)
- Multi-framework adapter dispatch (W4)

## Required outputs

```text
pom.xml
agent-platform/pom.xml
agent-runtime/pom.xml

agent-platform/contracts/v1/run/RunRequest.java
agent-platform/contracts/v1/run/RunResponse.java
agent-platform/contracts/v1/errors/ContractError.java         # record
agent-platform/contracts/v1/errors/ContractException.java     # RuntimeException
agent-platform/api/RunsController.java                        # POST/GET /v1/runs
agent-platform/api/HealthController.java                      # /health, /ready
agent-platform/api/error/GlobalExceptionHandler.java
agent-platform/facade/PostureAwareValidator.java

agent-runtime/posture/AppPosture.java
agent-runtime/posture/DeploymentShape.java
agent-runtime/posture/PostureBootGuard.java
agent-runtime/posture/BootCheck.java
agent-runtime/server/RunRecord.java                            # @Entity with tenant_id
agent-runtime/server/RunStore.java                             # JPA repository

agent-runtime/server/migrations/V001__run_record.sql           # tenant_id column

gate/run_operator_shape_smoke.sh
gate/run_operator_shape_smoke.ps1
gate/check_architecture_sync.sh
gate/check_architecture_sync.ps1

docs/delivery/<date>-<W0-sha>.md
```

## Exit criteria

- `mvn -q -pl agent-platform,agent-runtime test` exits 0.
- `gate/run_operator_shape_smoke.{sh,ps1}` exits 0 against a long-lived `java -jar` process and a real local Postgres (per posture matrix; `dev` posture loopback only).
- `gate/check_architecture_sync.{sh,ps1}` exits 0 — every L0 decision in `decision-sync-matrix.md` is reflected in its claimed L2 document and `architecture-status.yaml`.
- `architecture-status.yaml` reports no capability above L1 and no status above `operator_gated`.
- `docs/delivery/<date>-<W0-sha>.md` records: SHA, posture, deployment shape, three sequential `POST /v1/runs` runs reusing the same JVM resources, two cancellation tests (200 / 404), zero fallback events.

## Owner gates

- W0 PR template requires:
  - `docs/governance/architecture-status.yaml` updated.
  - `docs/governance/decision-sync-matrix.md` `Status` column updated for each touched decision.
  - `gate/run_operator_shape_smoke.*` green log attached.

## Wave succession

W1 begins only when W0 exit criteria are met and `docs/delivery/<date>-<W0-sha>.md` is committed.
