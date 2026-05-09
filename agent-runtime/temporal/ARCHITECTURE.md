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
| Temporal Java SDK | 1.25.x | workflow + activity APIs |
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
