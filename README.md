# spring-ai-ascend

Enterprise agent platform scaffold for financial services teams building on Spring AI 2.0.0-M5 + Spring Boot 4.0.5.

**Status**: W0 scaffold; 5 modules; dual-mode orchestration SPI (graph + agent-loop) with SuspendSignal nesting shipped (C32–C34); 56 tests GREEN

---

## Modules

| Module | Role |
|--------|------|
| `agent-platform` | Northbound HTTP facade — filter chain, health endpoint, idempotency |
| `agent-runtime` | Cognitive runtime — SPI contracts, OSS API probe |
| `spring-ai-ascend-dependencies` | BoM — pins all SDK and OSS dependency versions |
| `spring-ai-ascend-graphmemory-starter` | Sidecar adapter — Graphiti REST (opt-in, `enabled=false` by default) |

---

## Integration paths

| Path | When to use | Entry point |
|------|-------------|-------------|
| Drop-in `@Bean` override | Provide your own `GraphMemoryRepository` impl; starter auto-config wires it | `spring-ai-ascend-graphmemory-starter` |
| Direct Spring AI / Spring Data | Use `ChatMemory`, `VectorStore`, `CrudRepository` directly without starters | No starter needed |
| BoM import only | Pin all SDK versions; manage wiring yourself | `spring-ai-ascend-dependencies` BoM |

---

## Runtime model

`Run.mode` discriminates `GRAPH` (deterministic state machine) from `AGENT_LOOP` (ReAct-style LLM reasoning). Both modes share one interrupt primitive — `SuspendSignal` — which the `Orchestrator` catches to checkpoint the parent, dispatch a child Run, and resume the parent with the child's result. Three-level bidirectional nesting (graph → agent-loop → graph) is proved by `NestedDualModeIT`.

Six architectural constraints govern the design path from W0 to W4 (see `ARCHITECTURE.md §4 #10–#15`):
- **#10** Long-horizon lifecycle: typed suspend reasons + `AgentSubject` identity + paged `RunRepository` queries.
- **#11** Northbound handoff contract: sync (shipped) + streamed `Flux<RunEvent>` + yield; all with cancel, heartbeat ≤ 30 s, typed progress events.
- **#12** Two-axis resource arbitration: tenant × skill capacity matrix; saturation suspends, not fails.
- **#13** Payload serialization: inline bytes ≤ 16 KiB; `resumePayload` must be byte-serializable by W2.
- **#14** Resume re-authorization: every resume re-validates `tenantId`; mismatch returns 403.
- **#15** SPI serialization path: `NodeFunction`/`Reasoner` lambdas become named `CapabilityRegistry` entries before W4 Temporal.

---

## Quick start

```bash
./mvnw clean test
```

Posture is set via `APP_POSTURE` env var (`dev` / `research` / `prod`).
Research and prod reject sentinel stubs at startup; provide real `@Bean` overrides before deploying.

---

## Reading order

1. `README.md` — this file, current status
2. `docs/STATE.md` — per-capability shipped/deferred table
3. `ARCHITECTURE.md` — system boundary, decision chains, SPI contracts
