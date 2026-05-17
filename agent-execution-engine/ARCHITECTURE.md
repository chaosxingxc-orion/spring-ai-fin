---
level: L1
view: logical
module: agent-execution-engine
status: skeleton-receiving-extraction
freeze_id: null
covers_views: [logical]
spans_levels: [L1]
authority: "ADR-0072 (Engine Envelope + Strict Matching); Layer-0 principle P-M (Heterogeneous Engine Contract); Rule 43 (Engine Envelope Single Authority), Rule 44 (Strict Engine Matching)"
---

# agent-execution-engine — L1 architecture (skeleton, receiving extraction)

> Owner: AgentExecutionEngine team | Wave: W2 | Maturity: SPI + 2 reference adapters
> Created: 2026-05-17 (six-module materialization PR — code extraction in T2.B2)

## Status

**This module is a deliberately empty skeleton at v2.0.0-rc4 (this PR).**
The engine code (EngineRegistry, EngineEnvelope, ExecutorAdapter,
ExecutorDefinition, GraphExecutor, AgentLoopExecutor) stays in
`agent-runtime/engine/` and `agent-runtime/orchestration/spi/` until the
follow-up PR resolves a dependency-direction snag surfaced during the
materialization PR:

- `EngineRegistry` and the executor SPIs **reference** `Run`, `RunContext`,
  and `SuspendSignal` from the runtime kernel (`agent-runtime/runs/`,
  `agent-runtime/orchestration/spi/`).
- A naive extraction would create a back-dep: `agent-execution-engine` →
  `agent-runtime` → `agent-execution-engine` (cycle).
- The follow-up PR decides between two clean approaches: (a) move
  `Run` / `RunContext` / `SuspendSignal` into a shared `agent-runtime-core`
  module that both sides depend on, or (b) make the engine SPI carry only
  primitives (runId, tenantId, payload) and re-hydrate Run state inside
  the runtime side, mirroring the `HookContext` solution used for
  middleware extraction.

The skeleton + metadata + dependency declarations ship today so the
AgentExecutionEngine team has a stable workspace. The physical move lands
in the follow-up PR.

### Planned end-state (when the follow-up PR lands)

| Moves from | Moves to |
|---|---|
| `agent-runtime/.../engine/EngineRegistry.java` | `agent-execution-engine/.../engine/EngineRegistry.java` |
| `agent-runtime/.../engine/EngineEnvelope.java` | `agent-execution-engine/.../engine/EngineEnvelope.java` |
| `agent-runtime/.../orchestration/spi/ExecutorAdapter.java` | `agent-execution-engine/.../engine/spi/ExecutorAdapter.java` |
| `agent-runtime/.../orchestration/spi/ExecutorDefinition.java` | `agent-execution-engine/.../engine/spi/ExecutorDefinition.java` |
| `agent-runtime/.../orchestration/spi/GraphExecutor.java` | `agent-execution-engine/.../engine/spi/GraphExecutor.java` |
| `agent-runtime/.../orchestration/spi/AgentLoopExecutor.java` | `agent-execution-engine/.../engine/spi/AgentLoopExecutor.java` |

Reference adapters (`SequentialGraphExecutor`, `IterativeAgentLoopExecutor`)
stay in `agent-runtime/.../orchestration/inmemory/` because they wire
Run/RunContext from the runtime kernel — they implement the engine SPI but
are not part of the engine contract surface.

## 0.4 Layered 4+1 view map

| Section | View | Notes |
|---|---|---|
| §1 Role | logical | heterogeneous engine contract surface |
| §2 Envelope schema | logical | `docs/contracts/engine-envelope.v1.yaml` |
| §3 Matching strictness | process | Rule 44 — `engine_type=X` MUST be executed only by adapter X |

## 1. Role

`agent-execution-engine` is the **engine contract surface**. It owns:

- `EngineEnvelope` — execution-engine request shape (envelope_version,
  engine_type, payload_class_ref, schema_ref).
- `EngineRegistry` — single authority for `resolve(envelope)` /
  `resolveByPayload(def)`; pattern-matching on `ExecutorDefinition`
  subtypes OUTSIDE this module is forbidden (Rule 43).
- `ExecutorAdapter` + `ExecutorDefinition` SPIs.
- Engine-type-specific executor interfaces (`GraphExecutor`,
  `AgentLoopExecutor`).
- Boot-time self-validation against
  `docs/contracts/engine-envelope.v1.yaml` (every `known_engines` id
  has a registered adapter; every registered adapter is `known`).

## 2. Envelope schema (authority)

`docs/contracts/engine-envelope.v1.yaml` is the single source of truth.
The `EngineEnvelope` Java record mirrors the schema (required fields
validated on construction). `known_engines` membership is enforced by
`EngineRegistry.resolve(...)` + registry boot validation; constructor-
level membership validation is deferred per Rule 48.c.

## 3. Strict matching (Rule 44)

A Run with `engine_type=X` executes only on the adapter registered
under `X`. Mismatch → `EngineMatchingException` → `Run.FAILED` with
reason `engine_mismatch`. **No fallback policy.** No silent
reinterpretation of payloads as another engine's configuration.

## 4. Forbidden imports

`ascend.springai.engine.spi.*` imports only `java.*` + `agent-middleware`
SPI (for `HookPoint` reference). Enforced by `SpiPurityGeneralizedArchTest`
(E48, extended in T2.G to scan this module).

## Reading order for new contributors

1. `module-metadata.yaml` — identity + dependency promises.
2. `docs/contracts/engine-envelope.v1.yaml` — envelope schema.
3. `docs/contracts/engine-hooks.v1.yaml` — hook surface this engine
   fires (consumed via `agent-middleware`).
4. ADR-0072 — module authority.
5. `docs/dfx/agent-execution-engine.yaml` — Design-for-X declarations.
