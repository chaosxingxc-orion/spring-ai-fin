# agent-runtime/run -- L2 architecture (2026-05-08 refresh)

> Owner: runtime | Wave: W2 | Maturity: L0 | Reads: prompt_version, tenant_budget | Writes: run, audit_log, outbox_event
> Last refreshed: 2026-05-08

## 1. Purpose

Owner of the **run lifecycle**. Accepts a tenant-bound `RunRequest`,
creates a `run` row, drives the cognitive loop (LLM + tools), persists
state at every transition, and returns a terminal `RunResponse`.
Synchronous orchestration in W2; long runs are delegated to
`temporal/` in W4 once estimated TTL > 30s.

Replaces v6 `agent-runtime/server/`, `runner/`, and `runtime/`. The v6
split was over-decomposed; the refresh uses a single L2.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Spring Boot starter jdbc | 3.5.x | repository |
| Spring AI ChatClient | 1.0.x | LLM call (via `llm/`) |
| Resilience4j | 2.x | circuit breaker on LLM call |
| Caffeine | 3.x | cancel-flag cache |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `run/Run.java` (record) | DTO + enum status | 50 |
| `run/RunStatus.java` | enum | 30 |
| `run/RunRepository.java` | jdbc (read/write run) | 100 |
| `run/RunController.java` | POST/GET/cancel endpoints | 140 |
| `run/RunOrchestrator.java` | sync orchestration; delegates to llm/, tool/, action/ | 220 |
| `run/RunCancellationRegistry.java` | in-process cancel signals | 60 |
| `db/migration/V3__run.sql` | run table + indexes | 80 |

## 4. Public contract

REST:

- `POST /v1/runs` -> 202 + `{run_id}`
- `GET /v1/runs/{id}` -> 200 + `Run`
- `POST /v1/runs/{id}/cancel` -> 200 (idempotent); 404 if unknown id

DB row `run`: `(run_id uuid pk, tenant_id uuid, status, current_stage,
prompt_id, model, started_at, finished_at, response, cost_usd,
fallback_events jsonb)`. RLS policy on `run`.

State machine:

```
PENDING -> RUNNING -> (SUCCEEDED | FAILED | CANCELLED)
```

Cancellation is cooperative: the orchestrator checks the cancel flag at
each LLM/tool boundary. Forced termination is not supported in W2;
Temporal in W4 supports signal-based cancellation.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| Synchronous vs Temporal threshold | 60s | 30s | 30s |
| Per-run timeout | 5 min | 5 min | 2 min |
| Allow run without `prompt_id` | yes | no | no |
| `fallback_events` non-empty terminal | warn | block delivery | block delivery |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `RunHappyPathIT` | E2E | Fake provider; terminal SUCCEEDED <= 30s |
| `RunCancellationIT` | E2E | Cancel live run -> 200 + CANCELLED <= 5s |
| `RunUnknownCancelIT` | Integration | unknown id -> 404 |
| `RunCircuitBreakerIT` | Integration | provider 5xx storm -> circuit opens; runs fail fast |
| `RunStatePersistenceIT` | Integration | crash mid-run, restart; orchestrator marks orphan FAILED |
| `RunRlsIsolationIT` | E2E | Tenant A's run not visible to B |

## 7. Out of scope

- LLM provider routing (`llm/`).
- Tool calling (`tool/`).
- ActionGuard authorization (`action/`).
- Long-running survival (`temporal/`, W4).

## 8. Wave landing

W2 brings the module in synchronous mode. W4 swaps the orchestrator
implementation to delegate to Temporal for runs estimated > 30s; the
HTTP contract does not change.

## 9. Risks

- Synchronous orchestrator pinning a virtual thread for the whole run:
  mitigated by per-step timeout + cancel checkpoint.
- Race between cancel signal and step completion: cancel wins only if
  status is RUNNING; SUCCEEDED is terminal.
- Crash mid-run leaves stale RUNNING rows: mitigated by a periodic
  reaper that marks rows older than max-timeout as FAILED.

## 10. Parallel runs + timeout escalation (added cycle-10 per RUN-1, RUN-2)

### 10.1 Parallel runs per tenant

A tenant may have multiple in-flight runs. Concurrency cap enforced
at the controller (TB-2) before the orchestrator starts.

| Posture | Default cap per tenant | Configurable per tenant? |
|---|---|---|
| dev | unbounded | n/a |
| research | 50 | yes (`tenant_config.runs.max_parallel`) |
| prod | 200 | yes |

Cap exceeded -> 429 `BUDGET_RUN_LIMIT`. Counter kept in Valkey for hot
path.

Within a run, no orchestrator-level parallelism in v1: a run does one
LLM call + tool dispatch at a time. Tool calls themselves may fan-out
internally but that is the tool's responsibility. W4+ may add parallel
tool execution.

### 10.2 Timeout escalation

Three timeout levels:

| Timeout | Default (research) | Default (prod) | Source |
|---|---|---|---|
| Per-LLM-call | 60s | 30s | Resilience4j; Spring AI ChatClient |
| Per-tool-call (in-process) | 5s | 3s | per-tool override allowed |
| Per-tool-call (out-of-process) | 30s | 15s | per-tool override allowed |
| Per-step total | 90s | 60s | LlmCall + ToolCall + state-machine bookkeeping |
| Per-run total | 5min | 2min | wall clock from POST to terminal |
| Per-run idle | 60s | 30s | no LLM/tool activity |

Escalation:

- Per-call timeout -> retry (Resilience4j; up to 3 attempts).
- Per-step timeout -> circuit breaker may open; record fallback event;
  step terminates with error.
- Per-run total OR per-run idle exceeded -> orchestrator marks run
  FAILED with `RUN_TIMEOUT`.

Long-running runs (estimated > 30s in research/prod) are delegated to
Temporal in W4 -- the per-run total timeout becomes a workflow-level
timeout managed by Temporal.

### 10.3 Cancellation semantics across sync vs Temporal boundary

- Sync orchestrator: cancellation via in-process `CancelRunRegistry`;
  cooperative checkpoint at every step boundary.
- Temporal-managed (W4): cancellation via `CancelRunSignal`; activity
  may not be interruptible mid-flight (Temporal cooperative cancel).
- API contract: `POST /v1/runs/{id}/cancel` returns 200 in both modes;
  internal mechanism differs but observable shape is the same.
- Late cancel (after terminal): 200 idempotent; no state change.

### 10.4 Tests

| Test | Layer | Asserts |
|---|---|---|
| `RunParallelCapIT` | Integration | exceeding cap -> 429 |
| `RunPerStepTimeoutIT` | Integration | step timeout fires -> step terminates; run continues if recoverable |
| `RunTotalTimeoutIT` | Integration | total timeout fires -> run FAILED with RUN_TIMEOUT |
| `RunIdleTimeoutIT` | Integration | no activity 30s -> RUN_TIMEOUT |
| `CancelDuringSyncIT` | E2E | sync orchestrator cancels at next checkpoint |
| `CancelDuringTemporalIT` | E2E (W4) | signal cancels workflow within tolerance |
