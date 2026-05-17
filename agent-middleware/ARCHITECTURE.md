---
level: L1
view: logical
module: agent-middleware
status: skeleton-receiving-extraction
freeze_id: null
covers_views: [logical]
spans_levels: [L1]
authority: "ADR-0073 (Engine Hooks + Runtime Middleware SPI); Layer-0 principle P-M (Heterogeneous Engine Contract); Rule 45 (Runtime-Owned Middleware via Engine Hooks)"
---

# agent-middleware — L1 architecture (skeleton, receiving extraction)

> Owner: Middleware team | Wave: W2 | Maturity: SPI-only (consumer impls W2)
> Created: 2026-05-17 (six-module materialization PR — code extraction in T2.B1)

## Status

**Module receives the cross-cutting middleware SPI** during the same
materialization PR. The five SPI types
(`HookPoint`, `RuntimeMiddleware`, `HookContext`, `HookOutcome`,
`HookDispatcher`) move out of `agent-runtime/orchestration/spi/` and
`agent-runtime/engine/` into this module. The W2 Telemetry Vertical
populates the consumer impls (TokenCounterHook, PiiRedactionHook,
CostAttributionHook, LlmSpanEmitterHook).

## 0.4 Layered 4+1 view map (W1 — ADR-0068)

| Section | View | Notes |
|---|---|---|
| §1 Role | logical | runtime-owned cross-cutting concerns |
| §2 Hook surface | logical | 9 canonical HookPoint values per `docs/contracts/engine-hooks.v1.yaml` |
| §3 Dispatch order | process | declaration order; fail-fast inside the chain |

## 1. Role

`agent-middleware` is the **runtime-owned middleware module**. It
implements Rule 45 / P-M: cross-cutting policies (model gateway, tool
authz, memory governance, tenant policy, quota, observability, sandbox
routing, checkpoint, failure handling) are expressed as
`RuntimeMiddleware` listeners attached at canonical `HookPoint` events.

## 2. Hook surface

Authority: `docs/contracts/engine-hooks.v1.yaml` (gate Rule 57 enforces
yaml↔enum consistency). Nine canonical hook points:

| HookPoint | Fired by | Typical consumers |
|---|---|---|
| `BEFORE_LLM_INVOCATION` | engine | token-budget, pii-redaction |
| `AFTER_LLM_INVOCATION` | engine | cost-attribution, span emit |
| `BEFORE_TOOL_INVOCATION` | engine | tool-authz, action-guard |
| `AFTER_TOOL_INVOCATION` | engine | observability |
| `BEFORE_MEMORY_READ` | engine | tenant-scoped read filter |
| `AFTER_MEMORY_WRITE` | engine | privacy redaction |
| `BEFORE_SUSPENSION` | orchestrator | checkpoint enrichment |
| `BEFORE_RESUME` | orchestrator | run-state validation |
| `ON_ERROR` | engine + orchestrator | best-effort failure logging |

## 3. Dispatch semantics (W2.x scope)

- Hook ordering = middleware registration order.
- Default failure propagation = fail-fast inside the dispatcher chain
  (a non-`Proceed` outcome stops subsequent middlewares for the same
  `HookPoint`).
- Run-state consumption of outcomes (`Fail` → `Run.FAILED`,
  `ShortCircuit` → engine bypass) is DEFERRED to W2 Telemetry Vertical
  per `CLAUDE-deferred.md` 45.b.
- `on_error` is best-effort across the chain.

## 4. Forbidden imports (SPI purity per Rule 32)

The `ascend.springai.middleware.spi.*` packages import only from `java.*`
and own spi siblings. Enforced by `SpiPurityGeneralizedArchTest` (E48).
Constructive impls under `ascend.springai.middleware.*` may use any
agent-* dep listed in `module-metadata.yaml#allowed_dependencies` (today:
empty — the W2 Telemetry Vertical may widen this).

## Reading order for new contributors

1. `module-metadata.yaml` — identity + dependency promises.
2. `docs/contracts/engine-hooks.v1.yaml` — canonical hook surface.
3. ADR-0073 — module authority.
4. `docs/dfx/agent-middleware.yaml` — Design-for-X declarations.
