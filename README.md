# spring-ai-ascend

> Enterprise agent platform on Spring AI 2.0.0-M5 + Spring Boot 4.0.5 + Java 21.

## What is this?

`spring-ai-ascend` is a self-hostable agent runtime for financial-services teams. It ships a dual-mode orchestration kernel — deterministic graph state machines and ReAct-style agent loops sharing a single interrupt primitive — with audit-grade evidence, posture-aware fail-closed defaults, and an OSS-first integration model. Build on top of it the same way you would build on Spring Boot itself: pull in the BoM, write `@Bean` overrides for the SPI surface you need, and ship.

## Status

**L1 module-level architecture shipped.** W0 runtime kernel + L1 platform composition (JWT validation, tenant claim cross-check, durable idempotency, posture boot guard, W1 run HTTP API, high-cardinality metric scrub, Rule 28 Code-as-Contract governance) shipped; W2–W4 capabilities remain design contracts.

- Formal release: [docs/releases/2026-05-14-L1-modular-russell-release.en.md](docs/releases/2026-05-14-L1-modular-russell-release.en.md) (L0 v2 superseded — marked historical)
- Per-capability shipped/deferred ledger: [docs/governance/architecture-status.yaml](docs/governance/architecture-status.yaml)
- Architecture baseline: 65 §4 constraints · 69 ADRs · 52 active gate rules · 66 self-tests · 26 active engineering rules · 12 Layer-0 governing principles · 71 enforcer rows · 105+ Maven tests GREEN (L1 release, Phase L per ADR-0060; Telemetry Vertical L1.x per ADR-0061/0062/0063; Layer-0 governing principles P-A..P-D per ADR-0064/0065/0066/0067; W1 Layered 4+1 + Architecture Graph + Phase M remediation per ADR-0068, Rules 33–34, gate Rules 37–44; W1.x Phase 1 L0 ironclad rules P-E..P-L per ADR-0069, Rules 35–42, gate Rules 45–52, enforcers E55–E71).

## Quick start

```bash
./mvnw clean test
```

Posture is selected by the `APP_POSTURE` environment variable (`dev` / `research` / `prod`). `dev` is permissive (in-memory backends allowed, missing config emits WARN); `research` and `prod` fail-closed at startup if required config is missing.

## Modules

| Module | Role |
|--------|------|
| `agent-platform` | Northbound HTTP facade — filter chain, health endpoint, idempotency, tenant binding |
| `agent-runtime` | Cognitive runtime — Orchestration SPI, in-memory dev-posture executors, posture gate, SPI scaffolding |
| `spring-ai-ascend-dependencies` | Bill of Materials — pins all SDK + OSS transitive versions |
| `spring-ai-ascend-graphmemory-starter` | Graph-memory SPI scaffold; no bean registered at W0; Graphiti REST reference adapter lands W1 (ADR-0034) |

## Integration paths

| Path | When to use | Entry point |
|------|-------------|-------------|
| Drop-in `@Bean` override | You implement `GraphMemoryRepository`; starter auto-config wires it | `spring-ai-ascend-graphmemory-starter` |
| Direct Spring AI / Spring Data | Use `ChatMemory`, `VectorStore`, `CrudRepository` directly without starters | No starter needed |
| BoM import only | Pin SDK + OSS versions; manage wiring yourself | `spring-ai-ascend-dependencies` BoM |

## Runtime model

`Run.mode` discriminates `GRAPH` (deterministic state machine) from `AGENT_LOOP` (ReAct-style LLM reasoning). Both modes share one interrupt primitive — `SuspendSignal` — which the `Orchestrator` catches to checkpoint the parent, dispatch a child Run, and resume the parent with the child's result. Three-level bidirectional nesting (graph → agent-loop → graph) is proved by `NestedDualModeIT`.

The full architectural constraint set (§4 #1–#63) and the deferred-capability roadmap (W1–W4) live in [ARCHITECTURE.md](ARCHITECTURE.md) and [docs/governance/architecture-status.yaml](docs/governance/architecture-status.yaml). They are not duplicated here.

## Posture model

| Posture | Behavior |
|---------|----------|
| `dev` (default) | Permissive — in-memory backends allowed; missing config emits WARN, not exception |
| `research` | Fail-closed — required config present or `IllegalStateException`; durable persistence expected |
| `prod` | Fail-closed — same as research; stricter enforcement planned for W2 |

Full matrix: [docs/cross-cutting/posture-model.md](docs/cross-cutting/posture-model.md).

## Reading order

1. **README.md** — you are here.
2. **[docs/STATE.md](docs/STATE.md)** — per-capability shipped/deferred table.
3. **[ARCHITECTURE.md](ARCHITECTURE.md)** — system boundary, §4 constraints, SPI contracts, decision chains.
4. **[docs/contracts/](docs/contracts/)** — HTTP API contracts, SPI semantic contracts, pinned OpenAPI snapshot.
5. **[docs/adr/README.md](docs/adr/README.md)** — Architecture Decision Records (ADR-0001 … ADR-0069).
6. **[CLAUDE.md](CLAUDE.md)** — Layer-0 governing principles + Layer-1 engineering rules (26 active, 15 deferred + 13 new sub-clauses with re-introduction triggers). See also [docs/quickstart.md](docs/quickstart.md).

## See also

- [docs/releases/](docs/releases/) — formal release notes.
- [docs/governance/architecture-status.yaml](docs/governance/architecture-status.yaml) — capability ledger.
- [gate/README.md](gate/README.md) — architecture-sync gate (52 rules + 66 self-tests).
- [docs/cross-cutting/oss-bill-of-materials.md](docs/cross-cutting/oss-bill-of-materials.md) — OSS dependency policy.
