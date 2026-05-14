# ADR-0063 — Client SDK Observability Contract (W3, design recorded at L1.x)

- Status: Accepted — design contract. Implementation deferred to W3.
- Date: 2026-05-14
- Authority: User directive — "Client-side observability is the most important; it must include business logs + server-layer logs + middleware-layer logs." The client SDK that delivers on this directive is a W3 deliverable, but the contract is locked at L1.x so the server-side work in L1.x and W2 lines up with it.
- Scope: Define the protocol contract between a client of `agent-platform` and the server, specifically for end-to-end trace correlation, baggage propagation, and PII redaction. Name the W3 deliverable artifact (`springai-ascend-client`) and the language priorities.
- Cross-link: ADR-0061 (Telemetry Vertical), ADR-0062 (Trace ↔ Run ↔ Session N:M), ADR-0017 (MCP replay).

## Context

L1.x ships the server-side contract surface for end-to-end observability:

- `TraceExtractFilter` extracts or originates W3C `traceparent` on every inbound request.
- The server emits `traceresponse: 00-<trace_id>-<span_id>-01` on outbound responses so client SDKs can correlate the server trace with their local view.
- MDC carries `trace_id`, `span_id`, `run_id`, `tenant_id` for log-line correlation.

The L1.x scope explicitly excludes the client-side SDK; clients today can integrate via vanilla OTel SDKs (Java `opentelemetry-api`, JS `@opentelemetry/sdk`, Python `opentelemetry`). The platform-owned client SDK — `springai-ascend-client` — ships in W3.

The user's directive is concrete and three-part:

1. **Business logs** — application code spans (the user's own product instrumentation) are captured locally by the SDK.
2. **Server logs** — when the application calls our server, the server emits its own spans under the propagated `traceparent`; the client SDK reads `traceresponse` to correlate.
3. **Middleware logs** — middleware spans (DB, cache, vector store, LLM provider, MCP tool, outbox) flow through the server's `HookChain` and end up under the same `trace_id`.

Locking the protocol contract now means the server-side L1.x and W2 work cannot drift away from what the W3 SDK needs.

## Decision

### 1. Wire protocol

- **Inbound from client → server**: `traceparent: 00-<trace_id>-<span_id>-01` (W3C Trace Context spec). Optional `tracestate` is accepted and forwarded but not interpreted by the server.
- **Outbound from server → client**: `traceresponse: 00-<trace_id>-<span_id>-01` on every response (200/4xx/5xx). The server's root span is the value; the client SDK uses it to attach server spans to its local view in dashboards.
- **OTel Baggage** (L1.x prep, W2 wire): client SDK MUST propagate `tenant.id`, `session.id`, `user.id` via the standard `baggage` header. Server reads `tenant.id` from baggage if `X-Tenant-Id` header is absent (W2; not at L1.x because L1.x keeps `X-Tenant-Id` mandatory per §4 #37).

### 2. Client SDK module (W3 deliverable)

**Name**: `springai-ascend-client` — a new top-level Maven module reactor entry (sibling of `agent-platform`, `agent-runtime`).

**Language priority**:

1. **Java/Kotlin** — ships in W3. Built on `opentelemetry-api` 1.x; provides a `SpringaiAscendClient` facade that wraps OTel `Tracer` + `BatchSpanProcessor`. Coexists with user-managed OTel SDKs (the client uses whatever `OpenTelemetry` instance is on the classpath).
2. **JS/TS** — deferred to W3+ once Java/Kotlin is hardened. Rule 2: ship one language, harden it, then expand.
3. **Python** — deferred to W3++. Same reason.

The SDK MUST NOT pull a heavy OTel exporter dep transitively; it relies on the host application's exporter configuration. SDK glue LOC ≤ 600 (per §4.6 budget).

### 3. SDK responsibilities

The W3 SDK delivers exactly five responsibilities:

1. **Capture business spans locally** via the standard OTel `Tracer` interface; no SDK-specific API for span creation.
2. **Propagate `traceparent` outbound** on HTTP requests to `agent-platform`. If a span is already current, use it; otherwise, originate a fresh trace.
3. **Read `traceresponse` from server** responses and attach the server-rooted span as a child of the client's span (via the `Link` API for cross-trace linkage where needed).
4. **Batch OTLP/HTTP send** to the client team's chosen backend (Tempo / Jaeger / Langfuse / SigNoz). The SDK does not own the exporter — it borrows the host application's.
5. **Redact PII before send** in posture=prod. Configurable redaction pattern set; defaults block obvious PII keys (`email`, `phone`, `ssn`, `credit_card`). Server-side `PiiRedactionHook` is authoritative; client-side redaction is defence-in-depth.

The SDK does NOT:

- Buffer offline (W3+ if needed; L1 prefers in-process retry only).
- Replay events to the platform's `trace_store` (Langfuse-style ingestion is server-side, not client-side, in our architecture).
- Provide a UI / dashboard (§1 admin-UI exclusion).

### 4. Authentication

The SDK MUST send a valid JWT (ADR-0056) as `Authorization: Bearer <jwt>`. The JWT's `tenant_id` claim MUST match the `X-Tenant-Id` header (W1 cross-check). The SDK does not manage JWT issuance — the host application supplies the token.

### 5. Versioning

The SDK follows the platform's `/v1/` API contract version (ADR-0040). A breaking change in the trace propagation protocol bumps to `/v2/`. No SDK-internal version drift permitted; the SDK is contract-bound, not feature-versioned.

### 6. Server-side prerequisite (L1.x → W2)

Every responsibility above requires the server to honor:

- L1.x: `TraceExtractFilter` populates MDC; server responds with `traceresponse`.
- W2: OTel SDK + OTLP exporter; `HookChain` emits middleware + LLM spans under the propagated `traceparent`.
- W4: MCP replay surface — `get_run_trace(runId)`, `list_sessions(tenantId, ...)` — backed by `trace_store`.

The SDK launch in W3 is gated on W2 completion.

## Alternatives considered

**Alt A — Ship the SDK at L1.x or W2.** Rejected because the server engine (W2) must be solid before the SDK can deliver on the user's directive ("business + server + middleware logs"). Shipping the SDK against an L1.x server that emits no spans wastes the client trip.

**Alt B — JS/Python first.** Considered because LLM-app prototypes skew toward Python. Rejected because our customer profile (financial-services operators) skews toward JVM-side integration. Java/Kotlin first reflects market truth.

**Alt C — Build a custom client wire protocol.** Rejected; W3C `traceparent` is the de facto standard, OTel SDKs already implement it, and reinventing it would burn glue LOC budget for zero differentiation.

## Consequences

- **Positive**: Server-side L1.x and W2 work is anchored to a concrete W3 client deliverable; the W3C wire format means clients can integrate via vanilla OTel SDKs in the meantime; SDK launch in W3 ships with minimal glue.
- **Negative**: Customers who need JS/Python today must use vanilla OTel SDKs (acceptable — they all speak `traceparent`); the platform commits to a `springai-ascend-client` module name and reactor entry at W3.
- **Risk surfaced**: The server-side L1.x MDC + `traceresponse` emission MUST land before any vanilla-OTel integration tests; otherwise external customers cannot validate the protocol against our server.

## Enforcers (Rule 28)

L1.x enforcers (server-side prerequisites of the W3 contract):

- `TraceExtractFilterIT` — asserts inbound `traceparent` is honored and outbound `traceresponse` is set on 200 + 4xx + 5xx responses.
- `LogFieldShapeIT` (extended) — asserts MDC carries `trace_id`, `span_id` in addition to `tenant_id`.

W3 enforcers (deferred — class FQNs locked here):

- `springai-ascend-client/src/test/.../client/TraceparentOutboundIT.java` — outbound HTTP requests carry a well-formed `traceparent`.
- `springai-ascend-client/src/test/.../client/TraceresponseCorrelationIT.java` — server `traceresponse` is consumed and linked to the local span.
- `springai-ascend-client/src/test/.../client/PiiRedactionContractIT.java` — posture=prod scrubs configured PII keys before OTLP send.

## §16 Review Checklist

- [x] Wire protocol (W3C `traceparent` + `traceresponse` + Baggage) is locked.
- [x] SDK responsibilities are bounded to five; non-responsibilities are explicit (no admin UI, no replay endpoint).
- [x] Language priority (Java/Kotlin → JS/TS → Python) is named.
- [x] Server-side L1.x prerequisites are listed and bound to enforcers.
- [x] W3 enforcer artifact FQNs are pre-declared so the W3 PR cannot drift.
- [x] Authentication and versioning policy stated.
- [x] No admin UI commitment; §1 exclusion preserved.
