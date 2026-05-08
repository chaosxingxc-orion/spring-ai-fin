# Roadmap — W0 through W4

> Per `docs/systematic-architecture-improvement-plan-2026-05-07.en.md` §5.
> Each wave defines deliverables and exit criteria. No wave starts until the prior wave's exit criteria are met and `docs/delivery/<date>-<sha>.md` is committed for the prior wave's HEAD.

## W0 — Evidence Skeleton

See `W0-evidence-skeleton.md`.

Deliverables:
- Maven multi-module skeleton.
- Minimal Spring Boot app with `/health` + `/ready` + stub run routes.
- Posture boot guard.
- Contract DTOs that compile (ContractError record + ContractException class split).
- Minimal durable run store with tenant_id column.
- First operator-shape gate scripts.
- `docs/delivery/<date>-<W0-sha>.md`.

Exit criteria:
- `mvn test` passes.
- `gate/run_operator_shape_smoke.*` passes.
- No capability is reported above L1.

## W1 — v1 Contract and Run Happy Path

Goal: make `POST /v1/runs` real under dev and research posture.

Deliverables:
- Route inventory tests (every controller path is enumerated and asserted).
- TenantContext filter (`X-Tenant-Id` validated against JWT claim).
- Idempotency reserve/replay (`IdempotencyStore` per-tenant).
- Run state machine (PENDING → RUNNING → DONE/FAILED/CANCELLED).
- SSE event stream minimal path (`GET /v1/runs/{id}/events`).
- Contract freeze digest scaffold (ContractFreezeTest skeleton).

Exit criteria:
- Dev path accepts loopback-only anonymous mode.
- Research path requires JWT and tenant.
- Cross-tenant event read returns 404.
- W1 SHA recorded in `docs/delivery/`.

## W2 — Security Gate

Goal: close the accepted P0 security findings with implementation evidence.

Deliverables:
- ActionGuard mandatory boundary (11 stages including PreActionEvidenceWriter and PostActionEvidenceWriter).
- ActionGuardCoverageTest (CI-blocking).
- RS256/JWKS validator + IssuerRegistry + JwksCache for research SaaS + prod.
- HmacValidator scoped to dev loopback + BYOC carve-out only.
- RLS connection-pool protocol (`RlsConnectionInterceptor` AOP advice).
- Audit class model (5 classes + class-aware durability + AuditFacade + AuditStore).
- WORM anchoring (daily Merkle root + RFC 3161 timestamp).
- Prompt section taxonomy + taint model in `agent-runtime/llm/`.
- Sidecar conformance checks if sidecar is enabled.
- Gateway conformance readiness check.
- ObservabilityPrivacyPolicy CI gate.

Exit criteria:
- All P0 acceptance tests pass (per finding response §P0-1 through §P0-10).
- Security control matrix rows reference real tests with green CI runs.
- No P0 row in `architecture-status.yaml#findings` remains `design_accepted`; all are at least `test_verified`.
- Operator-shape gate green under `prod` posture against real LLM + real Postgres + real WORM target.

## W3 — Financial Write and Outbox Hardening

Goal: make write consistency explicit and enforceable.

Deliverables:
- `@WriteSite(consistency, financialClass, reason)` annotation.
- `WriteSiteAuditTest` (CI-blocking).
- `FinancialWriteCompatibilityTest` (CI-blocking).
- `outbox_event` Postgres table + RLS policy.
- `OutboxRelay` polling worker.
- `SyncSagaOrchestrator` + `saga_run` table + reversal-journal pattern.
- Reconciliation queue + `RECONCILIATION_REQUIRED` saga state.
- Reversal/reconciliation records for every saga compensation path.

Exit criteria:
- Unannotated write fails CI.
- `FinancialWriteCompatibilityTest` rejects `OUTBOX_ASYNC` for `SAGA_COMPENSATED` writes.
- Direct database writes cannot claim cross-account mutation.
- Saga compensation failure opens an operational gate (`RECONCILIATION_REQUIRED` state).
- Operator-shape gate green for fund-transfer happy path + compensation path + compensation-failure path.

## W4 — Multi-Framework Dispatch

Goal: support Spring AI as default; LangChain4j and Python sidecar gated behind W2.

Deliverables:
- `FrameworkAdapter` interface.
- Spring AI default adapter.
- LangChain4j opt-in adapter.
- Sidecar profile verification (per `docs/sidecar-security-profile.md`).
- Adapter fallback metrics + fallback-zero gate.

Exit criteria:
- Python sidecar is not generally available until identity, payload validation, message limits, cancellation, and supply-chain checks pass.
- Operator-shape gate green for all enabled adapters; per-adapter `*_fallback_total == 0` on the happy path.

## Cross-wave invariants

- Every wave's PR updates `docs/governance/architecture-status.yaml`.
- Every wave's PR updates `docs/governance/decision-sync-matrix.md` for any touched decision.
- Every wave's HEAD ships a `docs/delivery/<date>-<sha>.md` recording the operator-shape gate run.
- No wave introduces a new capability above L1 without a recorded `operator_gated` status.
