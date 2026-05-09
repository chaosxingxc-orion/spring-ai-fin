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
