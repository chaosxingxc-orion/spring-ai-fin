# ADR-0062 — Trace ↔ Run ↔ Session Identity (N:M with session_id)

- Status: Accepted
- Date: 2026-05-14
- Authority: User chose N:M (Langfuse-style) over 1:1 (run_id == trace_id) when the L1.x Telemetry Vertical scope was finalised.
- Scope: Define the identity relationship between `Trace`, `Run`, and `Session` from L1.x. Govern child-Run trace federation, suspend-resume behaviour, and the L1.x → W2 column-nullability progression.
- Cross-link: ADR-0061 (Telemetry Vertical Layer), ADR-0019 (`SuspendSignal`), ADR-0024 (Suspension write atomicity), ADR-0025 (Checkpoint ownership boundary), ADR-0017 (trace replay — joins `trace_store` to `traces` via `trace_id`, not `run_id`).

## Context

The Telemetry Vertical (ADR-0061) introduces a `Trace` entity. The relationship between `Trace` and `Run` has two viable shapes:

1. **1:1** — `runId == traceId` (one Run = exactly one root Trace). Child Runs get a new Trace with `parent_trace_id` set.
2. **N:M with `session_id`** — `Trace` and `Run` are independent identities; multiple Runs MAY share a Trace via a common `session_id` (Langfuse's model).

The user chose option (2) explicitly during the L1.x scoping decision. This ADR records the decision, the rationale, and the column / SPI / suspend-resume semantics that follow.

## Decision

Adopt **N:M Trace ↔ Run with `session_id` from L1.x**.

### 1. Identity columns on `Run`

`Run.traceId` (String, 32-char lowercase hex — the OTel-native 16-byte trace ID rendered) — **nullable at L1.x; NOT NULL from W2** (research/prod). The trace under which this Run started. For root Runs (no parent), the platform originates a new trace at Run creation. For child Runs spawned via `SuspendForChild`, see §3 below.

`Run.sessionId` (String, UUID) — **nullable at L1.x and W2 dev**; **NOT NULL in posture=research/prod from W2**. The logical session this Run belongs to. Multiple Runs MAY carry the same `session_id`; the Trace store groups them when the MCP `list_sessions` tool is called (W4).

Both are additive to the `Run` record. No migration of existing rows at L1.x because the columns are nullable. W2 migration backfills `traceId` with a random hex value for legacy rows and ALTERs NOT NULL.

### 2. RunContext accessors

`RunContext.traceId() : String` and `RunContext.sessionId() : String` are mandatory L1.x accessors (§4 #54). `sessionId()` MAY return null at L1.x; runtime production code MUST handle null as "no session boundary established yet."

### 3. Child-Run trace federation (the `SuspendForChild` case)

When a Run suspends via `SuspendForChild`, the orchestrator starts a child Run. The child inherits `sessionId` from the parent (mandatory). For `traceId`, there are two policies:

- **Default policy (L1.x)** — **new Trace on child Run start**, with `parent_trace_id` attribute on the child's root span pointing at `parent.traceId`. Rationale: a suspended parent may resume hours later; nesting child spans inside an open parent trace requires the trace to stay open across long suspends, which breaks fixed-window OTel exporters and inflates tail-based sampling buffers.
- **Alternate policy (opt-in)** — **continue parent's Trace as a nested sub-span** when the suspend is expected to be sub-second (e.g. tool-call latency). Implementation deferred to W2 via a `Run.traceContinuation` discriminator.

The default policy is encoded in `Orchestrator` reference impls at L1.x; the alternate is reserved.

### 4. Cross-suspend trace propagation

`parent_trace_id` lives on the **persisted Run row** (`Run.traceId` of the parent), not in volatile context. This means:

- A child Run resumed hours after the parent suspended can still locate its parent's trace by reading `runRepository.findById(parentRunId).traceId()`.
- `Checkpointer` payloads carry `sessionId` as part of the resume envelope so a fresh process can populate MDC + baggage at resume time.

This is consistent with ADR-0024 (suspension write atomicity) — the trace identity is part of the atomic suspend write.

### 5. MDC carriers (L1.x)

The HTTP edge populates Logback MDC with four correlation IDs in this order:

```
tenant_id   (TenantContextFilter — existing)
trace_id    (TraceExtractFilter — new L1.x)
span_id     (TraceExtractFilter — new L1.x)
run_id      (RunIdMdcFilter      — new L1.x, populated once Run is materialised)
```

`session_id` is NOT in MDC at L1.x; it is carried only on the persisted Run row + in baggage when W2 OTel SDK lands. Reason: keeping MDC carriers minimal (Rule 2).

### 6. Reversal cost (back to 1:1, if ever needed)

If a future review decides 1:1 is preferable, the migration is additive:

1. Drop `Run.sessionId` column.
2. Backfill `Run.traceId = REPLACE(Run.runId::text, '-', '')` for all existing rows.
3. Remove `RunContext.sessionId()` accessor.
4. Remove `list_sessions` MCP tool.

Cost is bounded; no domain model rewrite required. The choice is reversible, so we pick the more expressive model now (Rule 1 strongest-interpretation default — "session" reading aligns with Langfuse's conversation/session concept).

## Alternatives considered

**Alt A — 1:1 (`runId == traceId`).** Simpler, fewer columns, two-ID MDC. Rejected because Langfuse models conversation sessions as N:M and the user's directive named client-side session correlation as a first-class concern. Reversal from 1:1 to N:M would require a sessions table migration; reversal from N:M to 1:1 is one DROP COLUMN.

**Alt B — Trace = Session.** Collapse the two into one identity. Rejected because Langfuse keeps them distinct (a single API request emits one Trace; a multi-request conversation aggregates multiple Traces via `session_id`); preserving the distinction means we never need to disambiguate later.

**Alt C — Defer session_id to W2.** Cleaner L1.x. Rejected because the column is nullable at L1.x so the cost is just two extra column declarations and one SPI accessor — well below the Rule 2 simplicity threshold.

## Consequences

- **Positive**: Aligns with Langfuse semantics from day one; enables session-scoped trace replay at W4; reversal to 1:1 is one DROP COLUMN if we ever need to backtrack; the SPI exposes the full identity surface (`traceId`, `spanId`, `sessionId`) so W2 OTel wiring has nowhere to drift to.
- **Negative**: Three IDs to populate on every Run creation (`runId`, `traceId`, `sessionId`); MDC carries four correlation IDs after L1.x (`tenant_id`, `trace_id`, `span_id`, `run_id`); `session_id` is nullable through L1.x and W2 dev, which means dashboards must tolerate nulls.
- **Risk surfaced**: Cross-suspend trace federation is non-trivial — the default policy (new Trace per child Run) loses span nesting for child-spawned work. ADR-0017's `trace_store.parent_span_id` column does NOT carry the parent-trace linkage; that linkage is `attributes_json.parent_trace_id`. W4 MCP replay tool implementations must follow the `parent_trace_id` attribute to re-stitch.

## Enforcers (Rule 28)

- `RunContextIdentityAccessorsTest` (ArchUnit) — asserts `RunContext` exposes `traceId()`, `spanId()`, `sessionId()` returning `String`.
- `RunTraceSessionConsistencyIT` (integration) — creates a Run; asserts `Run.traceId` is non-null 32-char hex, `Run.sessionId` MAY be null at L1.x; creates a child Run via `SuspendForChild`; asserts child's `parent_trace_id` attribute points to parent's `traceId`; asserts child inherits parent's `sessionId`.
- Schema constraint (W2) — `Run.traceId` NOT NULL via Flyway `V2__run_trace_id_notnull.sql`.

## §16 Review Checklist

- [x] N:M choice rationale (Langfuse alignment, user directive on client-side sessions) recorded.
- [x] Suspend-resume behaviour (`parent_trace_id` on persisted Run row, `Checkpointer` carries `sessionId`) documented.
- [x] Child-Run default policy (new Trace) vs alternate (nested sub-span) named, with implementation locus.
- [x] L1.x column nullability rules + W2 NOT NULL migration plan stated.
- [x] Reversal cost (drop one column) documented so the decision is genuinely reversible.
- [x] MDC carrier set listed; `session_id` exclusion from MDC at L1.x justified by Rule 2.
- [x] Every accessor / column has an enforcer row.
