> ARCHIVED 2026-05-12. Pre-refresh design rationale; not active spec. Current state: see docs/STATE.md.

# Interaction Sequences -- cross-cutting policy

> Owner: architecture | Wave: W0 anchor; per-wave updates | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

End-to-end sequence diagrams for the system's primary flows. Closes
Phase A (Conceptual Design) by making the cross-module interaction
explicit. Replaces implicit "the orchestrator calls the runtime which
calls the LLM" prose. Diagrams use ASCII (gate-ASCII compatible);
when a Mermaid render is needed, the same diagram is duplicated in
fenced ` ```mermaid` blocks.

Six flows below: 1 happy path, 3 critical failure paths, 1 long-running
(Temporal), 1 idempotent retry.

## 2. Flow 1: happy path -- POST /v1/runs (sync mode)

```
Client          Edge(GW)        Web         Auth         Tenant       Idemp        RunCtrl     RunOrch     ActionGuard   LlmRouter   Tool        Postgres    OutboxPub
  |                |             |            |             |            |             |           |             |            |          |             |             |
  |--POST /v1/runs->|             |            |             |            |             |           |             |            |          |             |             |
  |  Authorization  |             |            |             |            |             |           |             |            |          |             |             |
  |  Idem-Key       |             |            |             |            |             |           |             |            |          |             |             |
  |                |--HTTPS-term->|            |             |            |             |           |             |            |          |             |             |
  |                |             |--filter--->|             |            |             |           |             |            |          |             |             |
  |                |             |            |--JWT verify->|            |             |           |             |            |          |             |             |
  |                |             |            |  via JWKS    |            |             |           |             |            |          |             |             |
  |                |             |            |<-tenant_id--|             |            |             |           |             |            |          |             |
  |                |             |            |             |--bind ctx--|             |             |           |             |            |          |             |
  |                |             |            |             |            |--check key->|             |           |             |            |          |             |
  |                |             |            |             |            |<-no-dup-----|             |           |             |            |          |             |
  |                |             |            |             |            |             |--validate->|             |           |             |            |          |
  |                |             |            |             |            |             |  + budget   |            |           |             |            |          |
  |                |             |            |             |            |             |             |--SET LOCAL +tx-->|       |             |            |          |
  |                |             |            |             |            |             |             |  app.tenant_id     |       |             |            |          |
  |                |             |            |             |            |             |             |  INSERT run        |       |             |            |          |
  |                |             |            |             |            |             |             |<-run_id--------|        |             |            |          |
  |<-202 + run_id--|             |            |             |            |             |             |                |        |             |            |          |
  |                |             |            |             |            |             |             |                                                                |
  |  (orchestration loop until terminal)                                              |             |                                                                |
  |                |             |            |             |            |             |             |--LlmRequest-->                                                 |
  |                |             |            |             |            |             |             |                |--cheapest tier--|                            |
  |                |             |            |             |            |             |             |                |  ChatClient.prompt().call()                  |
  |                |             |            |             |            |             |             |                |<--LlmResponse--|                            |
  |                |             |            |             |            |             |             |<--text + usage |                |                            |
  |                |             |            |             |            |             |             |--ActionEnv-->|                                                |
  |                |             |            |             |            |             |             |  (capability=tool.echo)                                       |
  |                |             |            |             |            |             |             |              |--Authenticate(JWT re-assert) OK              |
  |                |             |            |             |            |             |             |              |--Authorize(OPA query) OK                     |
  |                |             |            |             |            |             |             |              |--Bound(rate limit / token budget / idem) OK   |
  |                |             |            |             |            |             |             |              |--Execute--->                                  |
  |                |             |            |             |            |             |             |              |             |--MCP call--|                  |
  |                |             |            |             |            |             |             |              |             |<-result----|                  |
  |                |             |            |             |            |             |             |              |<-result-----                                  |
  |                |             |            |             |            |             |             |              |--Witness:                                     |
  |                |             |            |             |            |             |             |              |  INSERT audit_log                             |
  |                |             |            |             |            |             |             |              |  INSERT outbox_event                          |
  |                |             |            |             |            |             |             |              |  (within run's tx; commits on terminal)       |
  |                |             |            |             |            |             |             |<-OK--------                                                  |
  |                |             |            |             |            |             |             |--UPDATE run SET status=SUCCEEDED, finished_at, response, cost
  |                |             |            |             |            |             |             |--COMMIT--->                                                    |
  |                |             |            |             |            |             |             |                                                |--scheduled |
  |                |             |            |             |            |             |             |                                                |  poll      |
  |                |             |            |             |            |             |             |                                                |--FOR UPDATE
  |                |             |            |             |            |             |             |                                                |  SKIP LOCK |
  |                |             |            |             |            |             |             |                                                |<-rows------|
  |                |             |            |             |            |             |             |                                                |--emit------>
  |                |             |            |             |            |             |             |                                                |  to sink   |
  |                |             |            |             |            |             |             |                                                |  + UPDATE  |
  |                |             |            |             |            |             |             |                                                |  sent_at   |
GET /v1/runs/{id} returns SUCCEEDED + response.
```

Boundary review:

- **TB-1 Edge**: TLS terminated; JWT validated; tenant_id extracted; idempotency dedup. Anything not authenticated never reaches L2.
- **TB-2 Application**: Tenant binding via `SET LOCAL app.tenant_id`; transaction scoping; rate limit applied at Resilience4j filter. RLS prevents cross-tenant query results.
- **TB-3 ActionGuard**: 5-stage chain. Authenticate re-asserts JWT context; Authorize calls OPA; Bound checks idempotency + token budget + rate; Execute dispatches tool; Witness writes audit + outbox.
- **TB-4 DB / Outbound**: Postgres RLS + assertion trigger; outbound LLM / tool calls go through provider clients with circuit breakers.

Per-step latency budget references the SLO table in
`docs/cross-cutting/non-functional-requirements.md` sec-2.1.

## 3. Flow 2 (failure): LLM provider outage

```
Client       RunCtrl     RunOrch    LlmRouter         CB(Resilience4j)   Provider
  |            |           |           |                    |                 |
  |--POST----->|           |           |                    |                 |
  |            |--start--->|           |                    |                 |
  |            |           |--call---->|                    |                 |
  |            |           |           |--invoke----------->|                 |
  |            |           |           |                    |--HTTP----------->|
  |            |           |           |                    |<-5xx (1)---------|
  |            |           |           |                    |--retry x N------>|
  |            |           |           |                    |<-5xx-------------|
  |            |           |           |                    |  (after N fails, OPEN)
  |            |           |           |<-CallNotPermitted--|                 |
  |            |           |           |                                       |
  |            |           |           |--escalate to next tier-->             |
  |            |           |           |  (if router has fallback model)       |
  |            |           |           |  ELSE: emit *_fallback_total + WARN log
  |            |           |           |  + run.fallback_events += { ... }      |
  |            |           |<-LlmFail--|                                       |
  |            |           |--UPDATE run SET status=FAILED, error_code=LLM_PROVIDER_UNAVAILABLE
  |            |           |--COMMIT---|                                       |
  |            |<-FAILED---|                                                  |
  |<-502-------|           |                                                  |
  |  Problem-detail with code=LLM_PROVIDER_UNAVAILABLE                         |
```

Observable per Rule 7 (resilience must not mask signals):

- `agent_run_terminal_total{outcome=failed,reason=llm_provider_unavailable}` increments.
- `*_fallback_total{module=llm,branch=...}` increments.
- WARN log with run_id + tenant_id + provider.
- `run.fallback_events` JSONB has at least one entry.

Recovery: circuit breaker half-opens after configured period; the
next probe call decides if it returns to CLOSED.

## 4. Flow 3 (failure): Postgres tx fails mid-run

```
RunOrch      Postgres
  |            |
  |--SET LOCAL app.tenant_id=...
  |            |
  |--INSERT run (PENDING)----->
  |            |
  |--LLM call (out-of-tx; long)
  |            |
  |--re-acquire tx
  |            |
  |--UPDATE run SET status=RUNNING
  |            |
  |--Witness: INSERT audit_log, INSERT outbox_event
  |            |
  |--COMMIT--->
  |            |  ERROR: 40001 serialization failure
  |<-rollback--|
  |            |
  |--retry tx (Spring @Transactional with retry-on-deadlock; up to N)
  |            |
  |  (if retries exhausted)
  |            |
  |--separate tx: UPDATE run SET status=FAILED, error_code=SYS_DEPENDENCY_DOWN
  |--COMMIT--->|
```

Side-effect-on-DB-failure semantics:

- The audit_log + outbox_event were inside the same tx as the run-state update; ALL roll back together. No half-witnessed action.
- The client's `Idempotency-Key` row dedup-table reflects "request received" but not "side effect committed"; retry with same key MAY produce a fresh attempt (the orchestrator may choose to retry).

Observable:

- `*_tx_retry_total{outcome=...}` increments per retry.
- Final state: run row exists with status=FAILED, error_code=SYS_DEPENDENCY_DOWN.

## 5. Flow 4 (failure): tenant suspended mid-run

```
TenantBinder       TenantContext        RunOrch        Postgres
     |                    |                |               |
     |  (request 1: tenant=T1, status=active)             |
     |--bind T1---------->|                |               |
     |                    |--SET LOCAL---->|               |
     |                    |                |--run starts---|
     |                    |                |               |
     |  (admin: POST /v1/admin/tenants/T1:suspend; T1 -> suspended)
     |                    |                |               |
     |  (request 2: tenant=T1; cached state may be 'active' for up to 60s TTL)
     |--bind T1---------->|                |               |
     |                    |--check_state-->|               |
     |                    |<-active(stale) |               |
     |                    |--SET LOCAL---->|               |
     |                    |                |--BUDGET CHECK ok                |
     |                    |                |--LLM call ...|                  |
     |                    |                |               |--re-fetch tenants
     |                    |                |               |  (every Witness; W3)
     |                    |                |               |  state=suspended
     |                    |                |<-403 TENANT_SUSPENDED          |
     |                    |                |--UPDATE run SET status=FAILED, error_code=TENANT_SUSPENDED
     |                    |                |--COMMIT-------|
```

Posture-aware behavior:

- **dev**: TenantContext cache TTL 0 (no caching); state checked every request.
- **research**: TTL 60s (per `agent-platform/config/`); up to 60s of grace where suspended-state is stale.
- **prod**: TTL 60s; suspend audit row is the source of truth.

Observable:

- `agent_run_terminal_total{reason=tenant_suspended}` increments.
- `audit_log` records both the suspend (admin action) and the rejected
  side effect.

## 6. Flow 5: long-running run via Temporal (W4)

```
Client        RunCtrl       RunOrch          Temporal-Client      Temporal-Cluster      Worker
  |             |              |                  |                     |                  |
  |--POST------>|              |                  |                     |                  |
  |             |--start------>|                  |                     |                  |
  |             |              |--est. TTL > 30s? |                     |                  |
  |             |              |  yes -> delegate                       |                  |
  |             |              |--start workflow->|                     |                  |
  |             |              |                  |--gRPC StartWF------>|                  |
  |             |              |                  |<-runId---------------|                  |
  |             |<-202 run_id--|                                                            |
  |<------------|              |                                                            |
  |                                                                                          |
  |  Worker picks up workflow                                                                |
  |                                                                            |--poll task->|
  |                                                                            |<-WF task----|
  |                                                                            |             |
  |  RunWorkflowImpl.execute(...)                                                            |
  |    int v = Workflow.getVersion("v_initial", ...)                                         |
  |    LlmCallActivity.invoke(...)  --(activity option: timeout 60s, retry 3)                |
  |                                                                            |--exec task->|
  |                                                                            |<-result-----|
  |    ToolCallActivity.invoke(...)                                                          |
  |    WriteAuditActivity.invoke(...)                                                        |
  |    EmitOutboxActivity.invoke(...)                                                        |
  |    return RunResponse                                                                    |
  |                                                                                          |
  |  GET /v1/runs/{id} polls run row (workflow updates row at each step)                     |
  |  Cancel via POST /v1/runs/{id}/cancel:                                                   |
  |    RunCtrl --> Temporal-Client.signalWorkflow(CancelRunSignal)                          |
  |    workflow's signal handler sets cancelled flag                                         |
  |    next Workflow.await(cancelled) wakes; throws CanceledFailure                          |
  |    workflow records terminal CANCELLED + UPDATE run                                     |
```

Crash recovery: if a worker dies mid-activity, Temporal re-schedules the
activity on a healthy worker (activities are idempotent per `agent-runtime/temporal/` sec-10.4).

Workflow versioning: every behavior change adds a `Workflow.getVersion(...)`
marker; existing workflows replay deterministically with the old code path.

## 7. Flow 6: idempotent retry (Idempotency-Key replay)

```
Client       Edge       Web      IdempFilter      RunCtrl     RunOrch     Postgres
  |            |          |          |              |            |             |
  |--POST run + Idem-Key=K1
  |            |--TLS---->|          |              |            |             |
  |            |          |--filter->|              |            |             |
  |            |          |          |--lookup K1-->|            |             |
  |            |          |          |<-MISS--------|            |             |
  |            |          |          |--insert (T1,K1) marker|   |             |
  |            |          |          |              |--start---->|             |
  |            |          |          |              |            |--run flow-->|
  |            |          |          |              |            |<-OK---------|
  |            |          |          |              |<-200+body  |             |
  |            |          |          |--update (T1,K1) status=DONE, body=...
  |<-200+body                                                    |             |
  |                                                                            |
  |  (network glitch; client retries with same Idem-Key=K1)                    |
  |                                                                            |
  |--POST run + Idem-Key=K1
  |            |--TLS---->|          |              |            |             |
  |            |          |--filter->|              |            |             |
  |            |          |          |--lookup K1-->|            |             |
  |            |          |          |<-DONE+body---|            |             |
  |            |          |          |--return cached body + Idempotent-Replayed: true
  |<-200+body+ Idempotent-Replayed: true
  |                                                                            |
  |  (concurrent retry while first call is still IN-FLIGHT)                    |
  |--POST run + Idem-Key=K1
  |            |--TLS---->|          |              |            |             |
  |            |          |          |--lookup K1-->|            |             |
  |            |          |          |<-IN_FLIGHT--|             |             |
  |            |          |          |--409 Conflict                            |
  |<-409-------+                                                                |
  |  Problem-detail with code=IDEM_KEY_CONFLICT                                 |
```

Stored-body cap: 64 KiB. Larger responses skip the cache and re-execute
on retry (documented at API conventions sec-3 + idempotency L2 sec-9).

## 8. References

- `docs/cross-cutting/trust-boundary-diagram.md` (TB-1..TB-4)
- `docs/cross-cutting/non-functional-requirements.md` (per-step latency targets)
- `docs/cross-cutting/failure-modes-catalog.md` (per-module failure detection)
- `agent-runtime/run/ARCHITECTURE.md` (orchestrator semantics)
- `agent-runtime/temporal/ARCHITECTURE.md` (durable workflow contract)
- `agent-runtime/action/ARCHITECTURE.md` (5-stage chain)
- `agent-platform/idempotency/ARCHITECTURE.md` (dedup contract)
