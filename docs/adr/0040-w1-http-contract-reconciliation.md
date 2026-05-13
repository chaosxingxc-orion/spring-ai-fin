# 0040. W1 HTTP Contract Reconciliation

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-13
**Technical story:** Post-seventh L0 readiness follow-up (P1.2) surfaced three contradictions
across five active documents (`agent-platform/ARCHITECTURE.md`, `ARCHITECTURE.md`,
`docs/contracts/contract-catalog.md`, `docs/contracts/http-api-contracts.md`,
`docs/contracts/openapi-v1.yaml`) regarding: (a) whether W1 replaces `X-Tenant-Id` with JWT
or cross-checks it; (b) whether a newly-created run starts in `CREATED` or `PENDING` status;
(c) whether the cancel route is `DELETE /v1/runs/{id}` or `POST /v1/runs/{id}/cancel`.
This ADR resolves all three contradictions and names the canonical W1 HTTP contract.

## Context

Three contradictory signals existed before this ADR:

**Tenant model:**
- `agent-platform/ARCHITECTURE.md:34-35` said W1 "will replace header-based extraction with
  JWT `tenant_id` claim validation."
- `ARCHITECTURE.md:149-153` echoed: "replace header with JWT `tenant_id` claim at W1."
- `http-api-contracts.md:19` already described a JWT cross-check *against* `X-Tenant-Id`
  (not replacement): "W1+ cross-checks the JWT `tenant_id` claim against the header value."
- `contract-catalog.md:10` kept `X-Tenant-Id` required at W1.
- The existing `TenantContextFilter` design describes a cross-check model, not a replacement.

**Initial run status:**
- `http-api-contracts.md:92` said runs start in `CREATED` stage.
- `RunStatus.java` has no `CREATED` enum value.
- `ARCHITECTURE.md:283` DFA starts at `PENDING`.

**Cancel route shape:**
- `http-api-contracts.md:110-120` said `POST /v1/runs/{id}/cancel`.
- `openapi-v1.yaml:54 x-w1-note` mentioned `DELETE /v1/runs/{runId}` as the W1 addition.

## Decision Drivers

- `RunStatus.java` is the ground truth: no `CREATED` value exists. Introducing it would be
  a new enum value with no state-machine role — a ship-blocking defect per Rule 9.
- `DELETE /v1/runs/{runId}` contradicts the immutable-run-record model: a cancelled run
  transitions to `CANCELLED` (terminal); the run record is never physically deleted.
  Rule 20 (RunStateMachine) confirms `RUNNING → CANCELLED` is a state transition, not deletion.
- Replacing `X-Tenant-Id` entirely at W1 would break all W0 clients without a deprecation
  window. The cross-check model is additive: it adds JWT validation on top of the existing
  header, with no breaking change.

## Considered Options

1. **Cross-check: X-Tenant-Id required; JWT `tenant_id` claim added at W1** (this decision).
2. **Replace: W1 removes X-Tenant-Id; JWT claim becomes the sole tenant signal** — breaking
   for W0 clients; no deprecation window exists.
3. **No change to W1 tenant surface** — defers the cross-check; leaves the contradiction open.

## Decision Outcome

**Chosen option:** Option 1 — header + JWT cross-check (additive W1 hardening).

### Canonical W1 HTTP Contract (§4 #37)

**Tenant model:**
```
W0: X-Tenant-Id header required on all /v1/** routes.
W1: JWT token required alongside X-Tenant-Id.
     TenantContextFilter MUST cross-check JWT tenant_id claim == X-Tenant-Id value.
     Mismatch → 403 Forbidden.
     Missing JWT → 401 Unauthorized.
     X-Tenant-Id is NOT removed at W1.
```

**Initial run status:**
```
POST /v1/runs → 201 Created, body: { runId, status: "PENDING", ... }
  RunStatus.PENDING is the only legal initial status.
  RunStatus has no CREATED value; any doc claiming CREATED is wrong.
```

**Cancel route:**
```
POST /v1/runs/{runId}/cancel → 200 OK (idempotent if already CANCELLED)
                             → 409 Conflict if terminal-non-CANCELLED (SUCCEEDED, FAILED, EXPIRED)
  DELETE /v1/runs/{runId} is NOT the cancel mechanism.
  Cancellation is a state transition (RUNNING/SUSPENDED → CANCELLED per Rule 20 DFA).
  The run record is never deleted; only its status changes.
```

### Affected documents (all patched in this cycle)

| Document | Field | Before | After |
|---|---|---|---|
| `agent-platform/ARCHITECTURE.md:34-35` | W1 tenant model | "replace … with JWT" | "add JWT cross-check against X-Tenant-Id" |
| `ARCHITECTURE.md:149-153` | W1 tenant model | "replace header with JWT" | "add JWT cross-check; X-Tenant-Id stays required" |
| `http-api-contracts.md:92` | initial status | `CREATED` | `PENDING` |
| `openapi-v1.yaml x-w1-note` | W1 additions | mentions `DELETE /v1/runs/{runId}` | `POST /v1/runs/{id}/cancel` |
| `contract-catalog.md:10` | W1 tenant | (added note) | "JWT cross-check at W1 per this ADR" |

### Gate Rule 16 (§4 #37)

`http_contract_w1_tenant_and_cancel_consistency` — fails if any of:
- Active `.md` files contain `replace.*X-Tenant-Id` (signals the deprecated "replace" wording).
- `http-api-contracts.md` references `CREATED` as initial status.
- `openapi-v1.yaml` `x-w1-note` mentions `DELETE /v1/runs/{runId}` as the cancel mechanism.

**Rule 16a variant-phrasing forbidden list (L0 release hardening):** Gate Rule 16a uses
case-sensitive matching and catches the following phrasings that imply X-Tenant-Id replacement
— all are forbidden under this ADR:

| Phrasing | Reason |
|----------|--------|
| `TenantContextFilter switches to JWT` | "switches to" implies replacement, not addition |
| `TenantContextFilter replaces with JWT` | explicit replacement verb |
| `TenantContextFilter moves to JWT` | "moves to" implies abandoning the header |
| `will replace.*X-Tenant-Id` | original forbidden pattern (preserved) |
| `replace header-based.*with JWT` | original forbidden pattern (preserved) |
| `W1 replaces.*X-Tenant-Id` | original forbidden pattern (preserved) |

Any phrasing not in the "permitted" set below is suspect and should be reviewed against this ADR:

**Permitted phrasings:** "adds JWT cross-check", "cross-checks JWT", "validates JWT ... against
X-Tenant-Id", "JWT cross-check on top of X-Tenant-Id", "X-Tenant-Id stays required; W1 adds JWT".

### Consequences

**Positive:**
- W0 clients continue working at W1 — no breaking change.
- `RunStatus` enum requires no new value.
- Cancel route is consistent with Rule 20 RunStateMachine DFA.
- Single canonical statement (this ADR) replaces five contradicting partial statements.

**Negative:**
- W1 must implement the cross-check in `TenantContextFilter`; the existing W0 filter
  reads `X-Tenant-Id` only.
- All W1 clients must provide a valid JWT alongside the header.

### Reversal cost

Low — the `X-Tenant-Id` header is additive; reverting the JWT cross-check at W1 is a one-line
filter change. The `PENDING` initial-status and `POST /cancel` route shape are already
implemented (W0 DFA + http-api-contracts.md:110-120).

## References

- Post-seventh L0 readiness follow-up: `docs/reviews/2026-05-13-post-seventh-l0-readiness-followup.en.md` (P1.2)
- Response document: `docs/reviews/2026-05-13-post-seventh-l0-readiness-followup-response.en.md` (Cluster B)
- `http-api-contracts.md:19` — canonical JWT cross-check wording (correct before this ADR)
- ADR-0020: RunLifecycle SPI + RunStatus formal DFA (RUNNING → CANCELLED transition)
- Rule 20 (active): RunStatus transition validity
- §4 #37 (new, this ADR): W1 HTTP contract reconciliation
- Gate Rule 16: `http_contract_w1_tenant_and_cancel_consistency`
- `architecture-status.yaml` row: `w1_http_contract_reconciliation`
