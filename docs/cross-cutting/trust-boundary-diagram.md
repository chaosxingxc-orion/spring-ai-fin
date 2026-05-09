# Trust Boundary Diagram -- cross-cutting policy

> Owner: security | Wave: W1..W3 | Maturity: L0
> Last refreshed: 2026-05-09

## 1. Purpose

Names the trust boundaries every request crosses and what is enforced
at each. Replaces the pre-refresh `docs/trust-boundary-diagram.md`.

## 2. Boundary diagram

```
+---------------+   TLS   +-----------------------+
| External      | ------> | TB-1: Edge (gateway)  |
| client        |         |  - TLS termination    |
+---------------+         |  - JWT validation     |
                          |  - tenant_id extracted |
                          +-----------+-----------+
                                      |
                                      v
                          +-----------------------+
                          | TB-2: Application     |
                          |  - request scope      |
                          |  - idempotency dedup  |
                          |  - rate limit         |
                          |  - tx with SET LOCAL  |
                          +-----------+-----------+
                                      |
                                      v
                          +-----------------------+
                          | TB-3: ActionGuard     |
                          |  (only for runtime)   |
                          |  - re-assert auth     |
                          |  - OPA authorization  |
                          |  - bound check        |
                          |  - witness audit      |
                          +-----------+-----------+
                                      |
                            +---------+---------+
                            |                   |
                            v                   v
                   +---------------+   +-----------------+
                   | TB-4a: DB     |   | TB-4b: Outbound |
                   |  - RLS + GUC  |   |  (LLM / tool /  |
                   |  - INSERT-    |   |   external HTTP)|
                   |    only audit |   +--------+--------+
                   +---------------+            |
                                                v
                                       +-----------------+
                                       | External LLM    |
                                       | provider /      |
                                       | tool sidecar    |
                                       +-----------------+
```

## 3. Per-boundary enforcement

### TB-1 Edge (`agent-platform/web` + `auth`)

- TLS terminated at the gateway (Spring Cloud Gateway when present;
  otherwise Tomcat).
- JWT validated against JWKS; algorithm allowlist enforced.
- `tenant_id` claim extracted into request-scoped `Authentication`.
- Anything not authenticated -> 401.

### TB-2 Application (`agent-platform/tenant` + `idempotency` + `web`)

- Request bound to tenant via `TenantBinder` filter.
- Idempotency-Key dedup checked against Postgres.
- Rate limit checked.
- Database transaction opens with `SET LOCAL app.tenant_id = :id`.
- Anything attempting cross-tenant access via DB -> RLS hides rows.

### TB-3 ActionGuard (`agent-runtime/action`)

- Only entered for runtime side effects (LLM call, tool call, outbox event).
- Re-asserts the auth context (defense in depth).
- Calls OPA for capability authorization decision.
- Checks token budget + rate limit + per-call idempotency.
- Records audit row + outbox event on terminal outcome.

### TB-4a Database (`agent-runtime/run|memory|outbox`)

- RLS policies per table.
- Append-only audit role (INSERT-only).
- Postgres GUC `app.tenant_id` set transactionally.
- Triggers reject any INSERT/UPDATE on tenant tables when GUC is empty.

### TB-4b Outbound (`agent-runtime/llm|tool`)

- LLM calls go through `LlmRouter` -> Spring AI ChatClient -> provider.
- Tool calls go through `tool/Dispatcher` -> MCP server (in-process or sidecar).
- Outbound HTTP from tools is allowlisted (`HttpGetAllowlistTool`).
- All outbound is wrapped in Resilience4j circuit breakers and emits
  `*_fallback_total` metrics on failure.

## 4. What can NOT cross a boundary

| From | To | Forbidden |
|---|---|---|
| TB-1 | TB-2 | unauthenticated request reaching app code |
| TB-2 | TB-4a | DB query without `app.tenant_id` GUC set |
| TB-2 | TB-4b | side effect bypassing TB-3 |
| TB-4a | TB-4b | direct tool call from a DB function |
| TB-4b external | TB-4a | external service writing to our DB (no inbound) |

## 5. Tests

Tests are co-located in the relevant L2 modules' Tests sections.
Cross-boundary tests:

| Test | Boundary | Module |
|---|---|---|
| `TenantIsolationIT` | TB-2 -> TB-4a | `agent-platform/tenant` |
| `GucEmptyAtTxStartIT` | TB-4a | `agent-platform/tenant` |
| `ActionGuardBypassDetectionIT` | TB-3 -> TB-4b | `agent-runtime/action` |
| `ToolAllowlistIT` | TB-4b external | `agent-runtime/tool` |
| `AuditAppendOnlyIT` | TB-4a audit | `agent-runtime/action` |

## 6. Open issues / deferred

- Egress proxy with auditable host log: W4+.
- Network policies in K8s (NetworkPolicy resources): W2 (Helm chart).
- mTLS between app and Postgres: W4+ post (depends on customer demand).
