# ADR-0061 — Telemetry Vertical Layer

- Status: Accepted
- Date: 2026-05-14
- Authority: User reflection after the L1 release flagged that observability is treated piecemeal (fragments in §4 #5, #11, #16, #22 + `docs/observability/policy.md`) rather than as a named cross-cutting vertical. Reference architecture: Langfuse (https://github.com/langfuse/langfuse).
- Scope: Promote observability to a first-class **Telemetry Vertical** in `ARCHITECTURE.md §0.5.3` (sibling of Tenant Vertical and Posture Vertical). Define the entities (`Trace`, `Span`, `LlmCall`), the wire format (OTLP/HTTP), the hybrid sink strategy (OTLP exporter + `trace_store` Postgres dual-write per ADR-0017), and the L1.x / W2 / W3 / W4 staging.
- Extends: ADR-0009 (Micrometer observability — adds OTel + span layer above the metric layer). ADR-0017 (trace replay — places `trace_store` inside this vertical and re-confirms the MCP-only replay surface).
- Cross-link: ADR-0023 (cross-boundary context propagation — `TraceContext` is the trace companion of the `TenantContext` SPI), ADR-0062 (Trace ↔ Run ↔ Session N:M identity), ADR-0063 (Client SDK observability contract).

## Context

The L1 release shipped MDC `tenant_id`, `springai_ascend_*` Micrometer counters, and `TenantTagMeterFilter` for high-cardinality protection (commit `b193911`). It did not ship distributed tracing — no OpenTelemetry SDK, no span emission, no W3C `traceparent` propagation, no `trace_id` / `span_id` / `run_id` in MDC, no client SDK module, no `trace_store` table.

Observability fragments live in:

- `ARCHITECTURE.md §4 #5` — `springai_ascend_*` metric naming.
- `ARCHITECTURE.md §4 #11` — northbound handoff contract (carries `traceCorrelation` dimension in `SpawnEnvelope` per ADR-0053, but treats it as one of 15 envelope fields, not as a vertical).
- `ARCHITECTURE.md §4 #16` — Runtime Hook SPI (`HookChain`) deferred to W2.
- `ARCHITECTURE.md §4 #22` — RunContext canonical tenant propagation.
- `docs/observability/policy.md` — cardinality budget, label scheme, span attribute scheme, log fields. Staged rollout W0/W1/W2/W3/W4 but **not currently enforced by code**.

The user's strategic ask, translated to English:

> Our architecture is missing an end-to-end observability vertical. Compare against Langfuse. Observability should be a vertical layer in its own right. Client-side observability is the most important — it must include business logs, server-layer logs, and middleware-layer logs. The server layer must own all agent full-trace observability AND middleware observability.

## Decision

Adopt the **Telemetry Vertical** as a named top-level architectural concept in `ARCHITECTURE.md §0.5.3`, sibling to the existing Tenant Vertical (§4 #3 / #22 / Rule 21) and Posture Vertical (§4 #2 / #32). The vertical owns three entities, one carrier, one wire format, and one hybrid sink strategy, with rollout staged across L1.x → W2 → W3 → W4.

### 1. Three primary entities (OTel-native + Langfuse-compatible)

**`Trace`** — root container. Identifies one logical operation that MAY span 1..N Runs (N:M with `session_id`; see ADR-0062). Mandatory fields: `trace_id` (16-byte hex, OTel-native), `tenant_id`, `session_id`, `started_at`, `posture`. Optional: `user_id`, `parent_trace_id`, `tags[]`, `name`, `release`, `version`.

**`Span`** — corresponds to Langfuse Observation.SPAN. Generic work unit, nestable via `parent_span_id`. Mandatory: `span_id`, `trace_id`, `parent_span_id` (nullable for root), `name`, `started_at`, `ended_at`, `status` (`OK | ERROR | UNSET`), `tenant_id`. Optional: `attributes`, `events[]`, `kind`, `run_id`.

**`LlmCall`** — corresponds to Langfuse Observation.GENERATION. A specialised Span. Inherits all Span fields plus mandatory: `gen_ai.system`, `gen_ai.request.model`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, `langfuse.cost_usd`, `langfuse.latency_ms`. Optional: `gen_ai.request.temperature`, `gen_ai.response.finish_reason`, prompt/completion **refs only** (`payload_ref://<id>` — never inline content in posture=research/prod per §4 #58).

**`Score`** (Langfuse-compatible eval/feedback) is **deferred to W3**. The slot is reserved here; no L1.x storage.

### 2. Carrier SPI (L1.x)

`TraceContext` — pure-Java SPI in `agent-runtime/orchestration/spi/`, mirroring `RunContext`. Methods: `traceId() : String`, `spanId() : String`, `sessionId() : String`, `newChildSpan(name) : TraceContext`. Default implementation: `NoopTraceContext` (propagates IDs without emission).

`RunContext` is extended with `traceId()`, `spanId()`, `sessionId()` accessors (plain Strings — SPI purity preserved per §4 #7). This is the canonical carrier inside the runtime; ThreadLocal reads remain forbidden by Rule 21.

### 3. Wire format and sink strategy (W2 engine, L1.x contract)

**OTLP/HTTP** is the wire format. No gRPC. Selected because every relevant backend speaks it (Tempo, Jaeger, Langfuse, SigNoz, Honeycomb).

**Hybrid sink** — every Span is written to two destinations:

1. **OTLP/HTTP exporter** to a configurable backend (`springai.telemetry.otlp.endpoint`).
2. **`trace_store` Postgres** outbox (ADR-0017 schema) for MCP replay (§1 forbids an Admin UI).

Sampling, posture-aware:

| Posture | OTLP exporter | trace_store dual-write | Sampling |
|---|---|---|---|
| `dev` | stdout-OTLP (optional) | enabled | 100 % |
| `research` | OTLP/HTTP | enabled | 10 % head-based |
| `prod` | OTLP/HTTP fail-closed | enabled, tenant-scoped | 1 % head + tail-on-error (W4) |

### 4. HTTP-edge propagation (L1.x)

`TraceExtractFilter` (new, `agent-platform/observability/`, ~80 LOC, **no OTel SDK dep**) parses the W3C `traceparent` header on every inbound request:

- If present → adopt the trace, originate a server-rooted child span.
- If absent → originate a fresh trace (`trace_id` = 16-byte random hex; `span_id` = 8-byte random hex).

The filter populates Logback MDC with `trace_id` and `span_id`, and emits `traceresponse: 00-<trace_id>-<span_id>-01` on the outbound response so client SDKs (W3) can correlate. Filter order in the chain: **Trace → JwtTenantClaimCrossCheck → Tenant → RunId → Idempotency**.

`RunIdMdcFilter` (new) populates MDC `run_id` once a Run is materialised in the request scope.

### 5. Tenant scoping inside the vertical

Every Span carries `tenant.id` (raw, not bucketed — span storage is sampled at 1-10 %, unlike metric cardinality which is per-emission). `TraceExtractFilter` writes `tenant.id` into OTel Baggage at the HTTP edge; the runtime reads only via `RunContext.tenantId()`. MCP replay surface (W4) MUST fail closed on tenant mismatch (403). Application-enforced, like Langfuse's `project_id`. No raw PII in span attributes — `PiiRedactionHook` mandatory in posture=research/prod from W2 (§4 #58).

### 6. Reconciliation with `TenantTagMeterFilter` (L1, commit b193911)

The two policies do not collide:

- **Metrics**: `tenant_id` is forbidden as a raw meter tag; bucketed to `tenant_bucket` per `docs/telemetry/policy.md §2`. Reason: every metric emission carries every label; cardinality explodes.
- **Spans**: `tenant.id` is mandatory raw attribute per §4 #57. Reason: span storage is sampled (1-10 %), span attributes are not aggregation dimensions, and tenant-scoped trace lookup requires the raw value.

### 7. Hook SPI co-shipping (W2 trigger)

§4 #56 (GENERATION span schema) hard-depends on §4 #16 (Hook SPI). Both ship together in W2. `HookChain` is the sole emission path for `LlmCall` and middleware spans — adapters never emit telemetry directly. Reference hooks: `TokenCounterHook`, `PiiRedactionHook`, `CostAttributionHook`, `LlmSpanEmitterHook`, `ToolSpanEmitterHook`.

### 8. Staged rollout

- **L1.x**: ARCHITECTURE §0.5.3 + §4 #53–#59; ADR-0061/0062/0063; `TraceContext` SPI (Noop); `TraceExtractFilter`; `RunIdMdcFilter`; MDC expansion (`trace_id`, `span_id`, `run_id`, `session_id`); `Run.traceId` + `Run.sessionId` columns (nullable); ArchUnit + integration enforcers that do not require the OTel SDK.
- **W2**: OTel SDK + `opentelemetry-spring-boot-starter`; OTLP/HTTP exporter; Hook SPI un-frozen with reference hooks; `LlmGateway` emits `GENERATION` spans; `trace_store` Postgres + dual-write; `Run.traceId` NOT NULL.
- **W3**: `springai-ascend-client` (Java/Kotlin) per ADR-0063; `Score` entity; cost dashboards.
- **W4**: MCP replay tools (`get_run_trace`, `list_runs`, `get_llm_call`, `list_sessions`) per ADR-0017; tail-based sampling.

## Alternatives considered

**Alt A — OTLP only (no `trace_store` dual-write).** Cleaner, lighter. Rejected because §1 of `ARCHITECTURE.md` forbids an Admin UI; replacing the MCP replay surface with Grafana Tempo would re-introduce an admin UI by another name. Dual-write cost is bounded (one INSERT per terminal span, batched).

**Alt B — Custom JSON to `trace_store` only (no OTLP).** Re-invents an OTLP-shaped serializer, breaks Langfuse interop, loses Tempo/Jaeger tooling. Rejected.

**Alt C — Defer to W2 as a single block (no L1.x contract).** Rejected because Rule 28 (Code-as-Contract) forbids deferred enforcers. We lock the contract surface now and let the engine fill in at W2.

## Consequences

- **Positive**: One named vertical that every layer emits into; client-side, server-side, and middleware observability share the same `Trace` / `Span` / `LlmCall` schema; Langfuse interop is preserved; MCP replay surface remains the only operational read path (no Admin UI drift).
- **Negative**: OTel SDK dep (~3-4 MB) pulled at W2; dual-write cost (~one INSERT per terminal span); three IDs in MDC (`trace_id`, `span_id`, `run_id`, plus existing `tenant_id`) instead of one.
- **Risk surfaced**: Hook SPI un-deferral at W2 must co-ship with `LlmGateway` and GENERATION span emission; otherwise §4 #56 has no enforcer.

## Enforcers (Rule 28)

Every constraint introduced here ships with an executable enforcer. The full table lives in `docs/governance/enforcers.yaml` rows E38–E51 (new). Highlights:

- `TelemetryVerticalArchTest` (ArchUnit) — §4 #53.
- `RunContextIdentityAccessorsTest` (ArchUnit) — §4 #54 (SPI shape).
- `RunTraceSessionConsistencyIT` (integration) — §4 #54 (data consistency).
- `TraceExtractFilterIT` (integration) — §4 #55.
- `LlmGatewayHookChainOnlyTest` (ArchUnit) — §4 #56 (HookChain-only path).
- `SpanTenantAttributeRequiredTest` (ArchUnit) — §4 #57.
- `PostureBootPiiHookPresenceContractIT` (integration) — §4 #58 (contract; full negative test W2).
- `McpReplaySurfaceArchTest` (ArchUnit) — §4 #59.
- Gate Rule 30 (`telemetry_vertical_constraint_coverage`) — every §4 #53–#59 sentence maps to an enforcer row.

## §16 Review Checklist

- [x] Constraint text uses `MUST` / `MUST NOT` / `REQUIRED` and survives Rule 28 meta-scan.
- [x] Every constraint has at least one enforcer in `enforcers.yaml`.
- [x] No deferred enforcers — L1.x enforcers are active at L1.x; W2-only enforcers are named with class FQN but ship in W2 alongside their subject.
- [x] Cross-references to ADR-0017 (`trace_store`), ADR-0009 (Micrometer), ADR-0023 (TenantContext companion), §1 exclusion (no Admin UI) are explicit.
- [x] Wire format (OTLP/HTTP) is locked and reversal cost documented.
- [x] Staged rollout L1.x → W2 → W3 → W4 is explicit.
- [x] Posture-aware behaviour declared for dev / research / prod.
