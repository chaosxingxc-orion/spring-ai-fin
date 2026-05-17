# spring-ai-ascend

> Enterprise agent platform on Spring AI 2.0.0-M5 + Spring Boot 4.0.5 + Java 21 — as of v2.0.0-rc3 (2026-05-17).

## What is this?

`spring-ai-ascend` is a self-hostable agent runtime for financial-services teams. It ships a dual-mode orchestration kernel — deterministic graph state machines and ReAct-style agent loops sharing a single interrupt primitive — with audit-grade evidence, posture-aware fail-closed defaults, and an OSS-first integration model. Build on top of it the same way you would build on Spring Boot itself: pull in the BoM, write `@Bean` overrides for the SPI surface you need, and ship.

## Status

**L1 module-level architecture shipped.** W0 runtime kernel + L1 platform composition (JWT validation, tenant claim cross-check, durable idempotency, posture boot guard, W1 run HTTP API, high-cardinality metric scrub, Rule 28 Code-as-Contract governance) shipped; W2–W4 capabilities remain design contracts.

- Formal release: [docs/releases/2026-05-14-L1-modular-russell-release.en.md](docs/releases/2026-05-14-L1-modular-russell-release.en.md) (L0 v2 superseded — marked historical)
- Per-capability shipped/deferred ledger: [docs/governance/architecture-status.yaml](docs/governance/architecture-status.yaml)
- Architecture baseline (v2.0.0-rc3 cross-constraint audit closure): 65 §4 constraints · 77 ADRs · 63 active gate rules · 92 self-tests · 34 active engineering rules · 13 Layer-0 governing principles · 93 enforcer rows · 242 Maven tests GREEN under `./mvnw verify` (147 agent-runtime surefire + 29 agent-platform surefire + 65 agent-platform failsafe, of which 34 are Docker-skipped + 1 graphmemory-starter; +4 vs rc2: 3 new trace-ID validator cases in S2cCallbackEnvelopeValidationTest + 1 new ArchUnit method in SpiPurityGeneralizedArchTest) (the post-release review surfaced that `./mvnw test` skipped the `*IT.java` enforcers; rc1 verification now uses `verify` per post-release response §4). Trajectory: L1 release Phase L per ADR-0060; Telemetry Vertical L1.x per ADR-0061/0062/0063; Layer-0 governing principles P-A..P-D per ADR-0064/0065/0066/0067; W1 Layered 4+1 + Architecture Graph + Phase M per ADR-0068, Rules 33–34, gate Rules 37–44; W1.x Phase 1 L0 ironclad rules P-E..P-L per ADR-0069, Rules 35–42, gate Rules 45–52, enforcers E55–E71; W1.x Phase 8+9 cursor flow + ResilienceContract runtime per ADR-0070, Rules 36.b/41.b activated, gate Rules 53/54, enforcers E72/E73; W2.x Engine Contract Structural Wave P-M per ADR-0071..0077, Rules 43–48, gate Rules 55–60, enforcers E74–E87; W2.x Phase 7 audit closure adds E88+E89 with sunset discipline (gate Rule 60 widening); v2.0.0-rc1 post-release hotfix adds Rule 28k (`javadoc_enforcer_citation_semantic_check`), 45.b deferred (HookOutcome Run-state consumption to W2 Telemetry Vertical), E90 (S2C FAILED transition IT), E91 (engine-envelope classpath fallback IT), and `plan-projection.v1.yaml` design-only contract; v2.0.0-rc2 second-pass review closure (F-α / F-β / F-γ category audit) adds gate Rules 61 (`legacy_powershell_gate_deprecated`), 62 (`contract_yaml_declares_status`), 63 (`release_note_retracted_tag_qualified`) with 6 new self-test cases (2 each), deprecates the PowerShell gate entrypoint (canonical-bash posture), narrows W2.x deferred-as-live overclaims in engine-envelope/engine-hooks/HookOutcome/SyncOrchestrator/skill-capacity prose, and adds sub-clause 28k.b (schema↔Java-shape parity ArchUnit deferred to W3).

## Quick start

```bash
./mvnw -T 1C verify
```

`verify` (not `test`) is the canonical command — `test` skips the `*IT.java` enforcers, several of which are ship-blocking under Rule 9. `-T 1C` builds independent reactor modules in parallel; surefire runs JUnit classes concurrently inside each fork (toggle with `-DjunitParallel=false`); failsafe runs IT classes sequentially within a fork (Spring Boot 4.0.5 isn't thread-safe at `SpringApplication.run()`).

Posture is selected by the `APP_POSTURE` environment variable (`dev` / `research` / `prod`). `dev` is permissive (in-memory backends allowed, missing config emits WARN); `research` and `prod` fail-closed at startup if required config is missing.

## Modules — six-module materialization (in transit)

The L0 architecture (CLAUDE.md P-A..P-M) declares **six team-facing modules**.
The reactor currently ships 9 modules — the original 4 plus 5 new skeletons
filed in the six-module materialization PR (2026-05-17). The Phase-C follow-up
folds `agent-platform` + the runtime kernel into `agent-service`, returning the
reactor to **6 substantive modules + BoM + graphmemory starter**.

| Module | Plane (P-I) | Owner team | Maturity today |
|--------|-------------|-----------|----------------|
| `agent-client` | Edge Access | AgentClient | skeleton (SDK; W3+ per ADR-0049) |
| `agent-service` (planned) — today: `agent-platform` + `agent-runtime` | Compute & Control | AgentService | shipped; merge in Phase C |
| `agent-middleware` | Compute & Control | Middleware | SPI extracted from agent-runtime (T2.B1, this PR) |
| `agent-execution-engine` | Compute & Control | AgentExecutionEngine | skeleton; code-extraction deferred to T2.B2 follow-up PR |
| `agent-bus` | Bus & State Hub | AgentBus | skeleton (contracts only; W2 impl per ADR-0050) |
| `agent-evolve` | Evolution | AgentEvolve | skeleton (Python ML pipeline; Java adapter deferred) |
| `spring-ai-ascend-dependencies` | (build-time) | platform | shipped (BoM) |
| `spring-ai-ascend-graphmemory-starter` | Bus & State Hub | AgentBus | shipped (graphmemory SPI scaffold; ADR-0034) |

Per-module `module-metadata.yaml` is the authoritative identity + dependency
declaration. Per-module `ARCHITECTURE.md` carries the L1 view. Per-module
`docs/dfx/<module>.yaml` declares the five DFX dimensions (Rule 32).

### Five-plane topology (P-I)

Each module is pinned to exactly one of five deployment planes. Workloads
with different runtime characteristics MUST NOT share infrastructure — see
`docs/governance/principle-coverage.yaml` for the principle ↔ rule map and
`docs/governance/bus-channels.yaml` for the three-track channel isolation
that protects the Bus & State Hub plane.

### Three-track bus channel isolation (P-E / Rule 35)

Cross-service internal traffic is sliced into three physically isolated
channels declared in `docs/governance/bus-channels.yaml`:

| Channel | Cargo | Priority |
|---------|-------|----------|
| `control` | PAUSE / KILL / CANCEL intents | highest — never blocks for `data` congestion |
| `data` | run payload bodies (≤16 KiB inline cap §4 #13) | normal |
| `rhythm` | heartbeat / liveness pulses | lowest — drops oldest if saturated |

### W2.x heterogeneous engine contract (v2.0.0-rc3 headline)

The engine surface is a structured contract: `docs/contracts/engine-envelope.v1.yaml`
governs registration / matching / observability; engines fire canonical
`HookPoint` events declared in `docs/contracts/engine-hooks.v1.yaml`; the
server-to-client capability protocol uses `docs/contracts/s2c-callback.v1.yaml`;
the evolution-scope discriminator lives in
`docs/governance/evolution-scope.v1.yaml`. Authority: Rules 43–48 +
ADR-0071..0077. Release note:
[docs/releases/2026-05-16-W2x-engine-contract-wave.en.md](docs/releases/2026-05-16-W2x-engine-contract-wave.en.md).

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
2. **[docs/governance/architecture-status.yaml](docs/governance/architecture-status.yaml)** — per-capability shipped/deferred ledger (the canonical machine-readable index; an earlier README incorrectly linked to a non-existent `docs/STATE.md`).
3. **[ARCHITECTURE.md](ARCHITECTURE.md)** — system boundary, §4 constraints, SPI contracts, decision chains.
4. **[docs/contracts/](docs/contracts/)** — HTTP API contracts, SPI semantic contracts, pinned OpenAPI snapshot, engine envelope, engine hooks, S2C callback.
5. **[docs/adr/README.md](docs/adr/README.md)** — Architecture Decision Records (ADR-0001 … ADR-0077).
6. **[CLAUDE.md](CLAUDE.md)** — Layer-0 governing principles (13: P-A..P-M) + Layer-1 engineering rules (34 active, 15 deferred + 19 sub-clauses with re-introduction triggers — see CLAUDE.md "Deferred Rules" line for the authoritative count). See also [docs/quickstart.md](docs/quickstart.md).
7. **[docs/CLAUDE-deferred.md](docs/CLAUDE-deferred.md)** — every staged rule + sub-clause with its explicit re-introduction trigger.
8. **[docs/governance/SESSION-START-CONTEXT.md](docs/governance/SESSION-START-CONTEXT.md)** — machine-readable entrypoint context (graph traversal cues).
9. **[docs/governance/principle-coverage.yaml](docs/governance/principle-coverage.yaml)** — Layer-0 principle ↔ Layer-1 rule traceability.
10. **[docs/governance/retracted-tags.txt](docs/governance/retracted-tags.txt)** — released tags retracted by superseding fixes.
11. **[docs/governance/competitive-baselines.yaml](docs/governance/competitive-baselines.yaml)** — P-B measurement baseline (Performance / Cost / Developer Onboarding / Governance).

## See also

- [docs/releases/](docs/releases/) — formal release notes.
- [docs/governance/architecture-status.yaml](docs/governance/architecture-status.yaml) — capability ledger.
- [gate/README.md](gate/README.md) — architecture-sync gate (63 rules + 92 self-tests; rc3 adds no new gate sub-rules).
- [docs/cross-cutting/oss-bill-of-materials.md](docs/cross-cutting/oss-bill-of-materials.md) — OSS dependency policy.
