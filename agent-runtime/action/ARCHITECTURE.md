# agent-runtime/action -- L2 architecture (2026-05-08 refresh)

> Owner: runtime | Wave: W3 | Maturity: L0 | Reads: tool_registry, OPA policies | Writes: audit_log, outbox_event
> Last refreshed: 2026-05-08

## 1. Purpose

ActionGuard: the authorization + audit boundary for any side effect
the runtime performs (tool call, DB write, outbound HTTP). Five stages:
**Authenticate -> Authorize -> Bound -> Execute -> Witness**.

V6's 11-stage design is collapsed because 6 of those stages were
informational, not enforced. The 5 stages map to enforcement points
that all have tests.

## 2. OSS dependencies

| Dep | Version | Role |
|---|---|---|
| Open Policy Agent (OPA) | 0.65.x | authorization decisions |
| Spring AOP | (BOM) | filter chain via interceptor |
| Resilience4j | 2.x | rate limit + circuit breaker on OPA |

## 3. Glue we own

| File | Purpose | LOC |
|---|---|---|
| `action/ActionEnvelope.java` (record) | (tenant, run, capability, args, idem_key) | 60 |
| `action/ActionGuardChain.java` | 5-stage filter chain | 200 |
| `action/StageAuthenticate.java` | re-asserts JWT context | 60 |
| `action/StageAuthorize.java` | OPA query | 120 |
| `action/StageBound.java` | rate limit + token budget + idempotency | 120 |
| `action/StageExecute.java` | dispatch to capability | 80 |
| `action/StageWitness.java` | audit + outbox | 80 |
| `action/AuditWriter.java` | append-only writer | 80 |
| `db/migration/V5__audit_log.sql` | append-only table + INSERT-only role | 60 |
| `ops/opa/policies/action_guard.rego` | OPA policy | 100 |

## 4. Public contract

Internal Java API only. Consumers (tool/, llm/) construct an
`ActionEnvelope` and submit to `ActionGuardChain`. The chain returns an
`ActionResult` (success + payload, or denial + reason). Side effects
**must** flow through ActionGuard; bypassing is a CI-rejected pattern.

OPA policy package `action_guard`: input is the envelope; output is
`{allow: bool, reason: string}`.

## 5. Posture-aware defaults

| Aspect | dev | research | prod |
|---|---|---|---|
| OPA outage behavior | warn + allow | fail-closed (deny) | fail-closed (deny) |
| Audit row writes | optional | required | required |
| Outbox event on side effect | optional | required | required |
| Bypass-detection in CI | warn | error | error |

## 6. Tests

| Test | Layer | Asserts |
|---|---|---|
| `ActionGuardE2EIT` | E2E | Unauthorized capability call -> 403 + audit row |
| `ActionGuardLatencyIT` | Integration | OPA p99 < 5ms with sidecar |
| `ActionGuardOpaOutageIT` | Integration | OPA down -> deny in research/prod; warn in dev |
| `AuditAppendOnlyIT` | Integration | UPDATE / DELETE on audit_log fails (role) |
| `ActionGuardBypassDetectionIT` | Integration | A side effect not flowing through chain -> CI fails |
| `OpaPolicyUnitTest` (Rego) | Unit | Each rule allow / deny case |

## 7. Out of scope

- Authentication (`auth/` upstream).
- Tool execution mechanics (`tool/`).
- Run lifecycle (`run/`).
- Posture enforcement (`bootstrap/`).

## 8. Wave landing

W3 brings the entire module. OPA policies are version-pinned per
release; rolling them out independently is a W4+ deliverable (policy
hot-reload).

## 9. Risks

- OPA latency tail: local sidecar; benchmark in `ActionGuardLatencyIT`;
  cap via Resilience4j; degrade-to-deny on slow OPA.
- Rego policy bugs: unit tests for every rule; `opa test` in CI.
- Bypass: a developer calls a side-effect API directly; mitigated by
  CI rule that scans for side-effect signatures outside `action/`.
- Audit table growth: partitioned by month via `pg_partman`; archive
  old partitions to S3 on prod (W4).
