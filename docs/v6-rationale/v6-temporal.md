> ARCHIVED 2026-05-12. Pre-refresh design rationale; not active spec. Current state: see docs/STATE.md.

# agent-runtime/temporal -- L2 architecture (2026-05-08 refresh)

> Owner: runtime | Wave: W4 | Maturity: L0 | Reads: run, tool_registry | Writes: run (status updates), outbox_event
> Last refreshed: 2026-05-08

## 1. Purpose

Durable workflow execution for runs estimated > 30s. Survives JVM
crashes; replays activities from history; supports cancellation
signals; idempotent retries via Temporal's RetryOptions.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Temporal Server | 1.24.x | cluster (single-node dev; cluster prod) |
| Temporal Java SDK | 1.34.0 (U1; `Workflow.getVersion(...)` API confirmed) | workflow + activity APIs |
| Postgres | 16 | Temporal persistence (default) |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `temporal/RunWorkflow.java` (interface) | workflow contract | 30 |
| `temporal/RunWorkflowImpl.java` | deterministic implementation | 200 |
| `temporal/LlmCallActivity.java` | wraps `llm/LlmRouter` call | 80 |
| `temporal/ToolCallActivity.java` | wraps `tool/Dispatcher` call | 80 |
| `temporal/TemporalConfig.java` | client + worker beans | 100 |
| `temporal/CancelRunSignal.java` | signal definition | 30 |
| `ops/compose.yml` (Temporal additions) | server + UI | 40 |
| `ops/helm/temporal-values.yaml` | prod chart | 60 |

## 4. Public contract

Internal interface: `RunOrchestrator` calls
`temporalClient.start(RunWorkflow::execute, runId, ...)` and registers
a cancellation signal handler. Activities are idempotent; retry
policies are declared at the activity level.

Workflow code is **deterministic**: no `System.currentTimeMillis()`,
no random, no `UUID.randomUUID()`, no direct I/O. Workflow lints
enforce this (Temporal SDK provides a Maven plugin; CI enabled W4).

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Temporal cluster mode | single-node | cluster | cluster |
| Workflow lint | warn | enforced | enforced |
| Activity idempotency review | encouraged | required (PR checklist) | required |
| Retry max attempts | 3 | 5 | 5 |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `LongRunResumeIT` | E2E | Kill workers mid-run; restart; run completes |
| `CancelLiveRunIT` | E2E | Signal cancellation -> CANCELLED <= 5s |
| `WorkflowDeterminismLintIT` | CI | non-deterministic patterns rejected |
| `ActivityIdempotencyIT` | Integration | Replay activity twice; no double side effect |
| `TemporalProviderOutageIT` | Integration | Temporal server hiccup; workflow recovers |

## 7. Out of scope

- Sync orchestration (`run/RunOrchestrator`).
- Activity bodies that don't dispatch to existing modules (no business
  logic in `temporal/`; only adapters).

## 8. Wave landing

W4 only. Until W4, `run/RunOrchestrator` runs sync and cancels via
in-process registry; W4 swaps the implementation transparently.

## 9. Risks

- Temporal cluster ops in prod: managed Temporal Cloud as upgrade path;
  Helm chart documents the migration steps.
- Workflow non-determinism slipping in: lint + activity-only-I/O rule
  + integration test pinning history.
- DB pressure from Temporal persistence: separate Postgres in prod;
  shared DB in dev only.

## 10. Workflow versioning + signal discipline + namespaces (added cycle-10 per TMP-1, 2, 3)

### 10.1 Workflow versioning

Use Temporal's `getVersion(...)` API for every change to workflow
code that affects already-running workflows. Pattern:

```java
int v = Workflow.getVersion("v_<change-name>", DEFAULT_VERSION, NEW_VERSION);
if (v == DEFAULT_VERSION) {
  // old code path
} else {
  // new code path
}
```

Rules:

- Every behavior-changing PR to `RunWorkflowImpl` introduces a
  `v_<change-name>` token. Naming: short, descriptive, kebab-case.
- The `<change-name>` is part of the PR description and the test name
  (`WorkflowReplayIT_v_<change-name>`).
- A token is retired (removed from code) only after all workflows
  started before the change have completed (typically 30 days).
- A migration tool (W4+) lists currently-active version markers and
  oldest workflow start time per marker.

### 10.2 Signal contract

Defined signals (W4):

| Signal | Payload | Effect |
|---|---|---|
| `CancelRunSignal` | `{ reason: string }` | sets cancel flag; orchestrator cancels at next checkpoint |
| `BumpBudgetSignal` (W4+) | `{ delta_usd: number }` | extends per-run budget; rare admin action |
| `PauseRunSignal` (W4+) | `{}` | pauses workflow until `ResumeRunSignal` |
| `ResumeRunSignal` (W4+) | `{}` | unpauses |

Signal-handler discipline:

- Handlers MUST be deterministic (no I/O).
- Handlers MUST NOT block; they update workflow state and return.
- Workflow code uses `Workflow.await(...)` to react to flag changes
  rather than `Thread.sleep`.
- Every signal has a unit test that fires it during `WorkflowReplayIT`
  and asserts the resulting state.

### 10.3 Namespace strategy

| Posture | Namespace pattern | Notes |
|---|---|---|
| dev | `local-dev` | single namespace; all tenants share |
| research | `<env>-research` (e.g., `staging-research`) | per-environment, all tenants share |
| prod single-customer | `<customer>-prod` (e.g., `acme-prod`) | one namespace per customer |
| prod multi-tenant | `prod-<region>` (e.g., `prod-eu-west`) | per-region; tenants share |

Namespaces have separate retention policies + per-namespace metrics.
Crossing namespaces (cross-customer or cross-region workflow) is NOT
supported in v1.

### 10.4 Activity catalog and idempotency

Every activity:

- Has a stable `ActivityType` constant (registered with Temporal at
  startup).
- Is idempotent (same input -> same output). Side effects flow through
  `agent-runtime/action/ActionGuardChain` so the witness step keeps
  the audit single-write.
- Has explicit `RetryOptions` (no implicit defaults).

Activity catalog (W4):

| Activity | Idempotent on | Retry policy |
|---|---|---|
| `LlmCallActivity` | `(prompt_hash, model)` | 3x backoff; circuit-breaker integration |
| `ToolCallActivity` | `(tool_name, version, args_hash)` | 5x; per-tool override |
| `WriteAuditActivity` | `(audit_id)` (UUIDv7) | 10x; tx-bound; non-recoverable -> fail workflow |
| `EmitOutboxActivity` | `(event_id)` | 10x; same as audit |

### 10.5 Tests

| Test | Layer | Asserts |
|---|---|---|
| `WorkflowReplayIT_*` | Replay | every active version marker has a passing replay test |
| `SignalHandlerDeterminismIT` | Replay | signal handlers replay deterministically |
| `ActivityIdempotencyIT` | Integration | replay activity twice; no double side effect |
| `NamespaceIsolationIT` | Integration | workflows in different namespaces cannot interact |
| `VersionMarkerInventoryIT` | CI (W4) | active markers + oldest workflow start age listed; fail if a marker > 90d old without retirement |
