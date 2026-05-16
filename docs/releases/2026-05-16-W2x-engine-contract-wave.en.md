# W2.x Engine Contract Structural Wave — Release Note

**Date:** 2026-05-16
**Driver review:** 2026-05-15 LucioIT L0 proposal *"Runtime-Engine Contract for Heterogeneous Agent Execution"* (`docs/reviews/2026-05-15-l0architecture-lucio It-wave-1-supplement-runtime-engine-contract.en.md`)
**Response doctrine:** [docs/reviews/2026-05-16-engine-contract-structural-response.en.md](../reviews/2026-05-16-engine-contract-structural-response.en.md)
**Wave plan:** `D:/.claude/plans/https-github-com-chaosxingxc-orion-spri-compressed-taco.md`

---

## Baseline counts

| metric | count |
|---|---|
| §4 constraints | 65 |
| Active ADRs | 77 |
| Active gate rules | 60 |
| Gate self-test cases | 82 |
| active engineering rules | 34 |
| Layer-0 governing principles | 13 |
| enforcer rows | 87 |
| Maven tests GREEN | 200 |

## Summary

The W2.x wave absorbs the 2026-05-15 L0 proposal in seven phases. **One new Layer-0 governing principle** (**P-M — Heterogeneous Engine Contract & Server-Sovereign Boundary**) operationalised by **six new Layer-1 rules** (43–48), backed by **seven new ADRs** (0071–0077), **six new gate rules** (55–60), and **fourteen new enforcers** (E74–E87).

The wave's central design choice is the **structural-downstreaming invariant** — every new domain contract ships as:
```
yaml schema  →  Java type that validates against the schema  →  runtime self-validate
```
**Rule 48 (Schema-First Domain Contracts)** makes this invariant permanent and gate-enforced beyond this wave. The invariant is the structural prevention of defect family F1 (text-form governance drift), which accounted for 79 of 158 historical closed defects (~50%).

## Four Competitive Pillars

Pillar coverage by canonical name (`performance`, `cost`, `developer_onboarding`, `governance` — matches `docs/governance/competitive-baselines.yaml`):

| Pillar | Baseline | W2.x impact |
|---|---|---|
| `performance` | latency / throughput | no regression; SyncOrchestrator dispatch is now O(1) lookup via `EngineRegistry.resolveByPayload` (was sealed-pattern switch) |
| `cost` | per-call + infra | no change |
| `developer_onboarding` | time-to-first-agent + surface complexity | improved — new engine integrations register a single `ExecutorAdapter`, no orchestrator patches required |
| `governance` | tenant isolation, audit, eval, safety | strengthened — engine envelope adds compile-time + runtime validation against `known_engines`; S2C callbacks declared in schema with mandatory propagation fields |

## ADRs landed (7)

- **ADR-0071** Engine Contract Structural Wave (umbrella; declares P-M, lists 0072–0077 as dependents)
- **ADR-0072** Engine Envelope + Strict Matching (Phase 1, Rules 43+44)
- **ADR-0073** Engine Lifecycle Hooks + Runtime-Owned Middleware SPI (Phase 2, Rule 45)
- **ADR-0074** Server-to-Client Capability Callback Protocol (Phase 3, Rule 46)
- **ADR-0075** Evolution Scope Boundary (Phase 4, Rule 47)
- **ADR-0076** R2 Pilot — Runtime Self-Validates the Engine Envelope (Phase 5)
- **ADR-0077** Schema-First Domain Contracts (Phase 6, Rule 48 cross-cutting)

## Rules landed (6 active L1 rules + 1 new L0 principle)

| Rule | Title | Phase | Gate rule | Enforcers |
|---|---|---|---|---|
| 43 | Engine Envelope Single Authority | 1 | 55 | E74, E76 |
| 44 | Strict Engine Matching | 1 | 56 | E75, E77 |
| 45 | Runtime-Owned Middleware via Engine Hooks | 2 | 57 | E78, E79, E80 |
| 46 | S2C Callback Envelope + Lifecycle Bound | 3 | 58 | E81, E82, E83 |
| 47 | Evolution Scope Default Boundary | 4 | 59 | E86, E87 |
| 48 | Schema-First Domain Contracts | 6 | 60 | E85 |
| — | (Phase 5 R2 pilot; no new rule) | 5 | — | E84 |

## Schemas landed (4)

- `docs/contracts/engine-envelope.v1.yaml` — engine metadata + payload routing
- `docs/contracts/engine-hooks.v1.yaml` — 9 canonical hook points + ordering
- `docs/contracts/s2c-callback.v1.yaml` — S2C request/response shape + 6 mandatory fields + outcome enum
- `docs/governance/evolution-scope.v1.yaml` — in/out evolution scope contract

## Java SPI surfaces added

- `ascend.springai.runtime.orchestration.spi`: `ExecutorAdapter`, `EngineMatchingException`, `HookPoint`, `HookContext`, `HookOutcome`, `RuntimeMiddleware`, `EngineHookSurface` (all pure `java.*` per E3)
- `ascend.springai.runtime.engine`: `EngineEnvelope`, `EngineRegistry`, `HookDispatcher`
- `ascend.springai.runtime.s2c`: `S2cCallbackEnvelope`, `S2cCallbackResponse`, `InMemoryS2cCallbackTransport`
- `ascend.springai.runtime.s2c.spi`: `S2cCallbackSignal`, `S2cCallbackTransport`
- `ascend.springai.runtime.evolution`: `EvolutionExport`
- `ascend.springai.runtime.resilience.SuspendReason.AwaitClientCallback` (new sealed variant)

## Cross-rule co-design audit (Phase 3a — hard gate before S2C code)

S2C touched the highest cross-cutting risk in the wave. The Phase 3a audit matrix in the response doctrine §5 named the resolution for **each of the 5 affected existing rules** (20 state machine, 35 channels, 38 no-sleep, 41 capacity, 42 sandbox) BEFORE any S2C code landed. Outcome: S2C absorbed without modifying any existing rule. Pattern reusable for future cross-cutting features.

## What's deferred

- **Runtime ResilienceContract integration for `s2c.client.callback` skill capacity** — declared in `skill-capacity.yaml`, runtime enforcement at SyncOrchestrator deferred to W2 per ADR-0074.
- **Production S2C transports** (webhook POST, SSE, WebSocket) — only `InMemoryS2cCallbackTransport` ships at W2.x; W3 scope.
- **Engine-side hooks** (LLM × 2, tool × 2, memory × 2) — only the 3 structural hooks (`on_error`, `before_suspension`, `before_resume`) fire from SyncOrchestrator at W2.x; engine-side firing lands in W2 Telemetry Vertical with the first consumer hooks.
- **RunEvent + EvolutionExport integration** — `EvolutionExport` enum + armed-empty ArchUnit ship at W2.x; W2 RunEvent variants will declare `evolutionExport()`.
- **Existing prose-enum retrofit** — 10 grandfathered entries in `gate/schema-first-grandfathered.txt` (RunStatus DFA, RunMode, deployment_plane, SuspendReason variants, RunScope, SkillKind, SkillTrustTier, JoinPolicy/ChildFailurePolicy, SemanticOntology, AdmissionDecision, BackpressureSignal, IdempotencyRecord CHECK). Retrofit scheduled per `CLAUDE-deferred.md` 48.b (W3).

## Verification

- `./mvnw test` → 200 tests / 0 failures (135 agent-runtime + 65 agent-platform)
- `bash gate/check_architecture_sync.sh` → GATE: PASS with 66 active rules
- `bash gate/test_architecture_sync_gate.sh` → 82/82 self-tests PASS
- `bash gate/build_architecture_graph.sh` → 219+ nodes / 272+ edges; idempotent regen byte-identical

## Authority

- ADR-0071 (umbrella) authoritative
- L0 principle P-M operationalised by Rules 43–48
- W2.x doctrine response: `docs/reviews/2026-05-16-engine-contract-structural-response.en.md`
- Wave plan: `D:/.claude/plans/https-github-com-chaosxingxc-orion-spri-compressed-taco.md`
