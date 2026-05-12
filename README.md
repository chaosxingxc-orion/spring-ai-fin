# spring-ai-ascend

Enterprise agent platform scaffold for financial services teams building on Spring AI 2.0.0-M5 + Spring Boot 4.0.5.

**Status**: W0 scaffold; 4 modules; dual-mode orchestration SPI (graph + agent-loop) with SuspendSignal nesting shipped (C32–C34); §4 #16–#18 + Rules 18–19 + ADR-0016/0017/0018 + 9 design_accepted rows added (competitive analysis 2026-05-12); §4 #19–#23 + Rules 20–21 (active) + Rules 22–24 (deferred) + ADR-0019–0024 + 12 yaml rows + RunStateMachine + TenantPropagationPurityTest + EXPIRED status + MDC tenant_id (third-review 2026-05-12); architecture-code consistency cleanup: W0/W1/W2 contract split, idempotency narrowed, checkpoint ownership clarified, ADR-0025/0026/0027 (fourth-review 2026-05-12); data-plane typing + cognition-action separation + skill SPI + three-track channels: §4 #25–#28 + ADR-0028/0029/0030/0031 + Rules 26–27 (deferred) + 9 yaml rows + Gate Rule 11 + HD-A.8/HD-A.10 fixes (fifth-review 2026-05-12); scope hierarchy + posture consolidation + wave authority + contract-surface truth generalization + memory taxonomy + skill tiers + payload migration: §4 #29–#36 + ADR-0032–0039 + Gate Rules 12–14 + AppPostureGate + findRootRuns + plans archived + 8 stale starter coords removed + 101 tests GREEN (sixth+seventh combined review 2026-05-13)

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

Thirty-six architectural constraints govern the design path from W0 to W4+ (see `ARCHITECTURE.md §4 #1–#36`):
- **#10** Long-horizon lifecycle: typed suspend reasons + `AgentSubject` identity + paged `RunRepository` queries.
- **#11** Northbound handoff contract: sync (shipped) + streamed `Flux<RunEvent>` + yield; all with cancel, heartbeat ≤ 30 s, typed progress events.
- **#12** Two-axis resource arbitration: tenant × skill capacity matrix; saturation suspends, not fails.
- **#13** Payload serialization: inline bytes ≤ 16 KiB; `resumePayload` must be byte-serializable by W2.
- **#14** Resume re-authorization: every resume re-validates `tenantId`; mismatch returns 403.
- **#15** SPI serialization path: `NodeFunction`/`Reasoner` lambdas become named `CapabilityRegistry` entries before W2 async orchestrator.
- **#16** Runtime Hook SPI: every LLM/tool/agent boundary flows through `HookChain`; hook positions `PRE_LLM_CALL`/`POST_LLM_CALL`/`PRE_TOOL_INVOKE`/`POST_TOOL_INVOKE`/`PRE_AGENT_TURN`/`POST_AGENT_TURN`; reference hooks: PII filter, token counter, summariser, tool-call-limit. (W2)
- **#17** Graph DSL conformance: `GraphDefinition` gains `StateReducer` registry (OverwriteReducer/AppendReducer/DeepMergeReducer) + typed conditional edges + JSON/Mermaid export. (W3)
- **#18** Eval Harness Contract: every shipped capability must have golden corpus + LLM-as-judge + regression threshold gate. (W4)
- **#19** Suspend-reason taxonomy: sealed `SuspendReason` with `deadline()` on every variant; `JoinPolicy`/`ChildFailurePolicy` for fan-out; W0 single-child only. (ADR-0019)
- **#20** RunStatus formal DFA + audit trail: `RunStateMachine.validate(from, to)` enforced in `Run.withStatus`; `EXPIRED` terminal state added; `run_state_change` audit log at W2. (ADR-0020)
- **#21** Typed payload + `PayloadCodec` SPI: every cross-JVM payload encoded via `PayloadCodec<T>` with `codecId`; `RunEvent` sealed interface for streaming. (ADR-0022)
- **#22** Canonical run context: `RunContext.tenantId()` is sole tenant carrier in `agent-runtime`; `TenantContextHolder` HTTP-edge-only; MDC `tenant_id` populated at W0. (ADR-0023)
- **#23** Suspension write atomicity: `RunRepository.save(suspended)` + `Checkpointer.save(payload)` must be atomically observable; tiered contract per Checkpointer backend. (ADR-0024)
- **#29** Scope-based run hierarchy: `RunScope{STEP_LOCAL,SWARM}` discriminator; `SuspendReason.SwarmDelegation`; `PlanState`/`RunPlanRef` minimal contract; `findRootRuns` shipped W0. (ADR-0032)
- **#30** Logical identity equivalence: S-Cloud/S-Edge/C-Device deployment-locus vocabulary; no edge posture variant; Rule 17 S-side/C-side preserved. (ADR-0033)
- **#31** Memory taxonomy: 6 categories M1–M6 + common `MemoryMetadata` schema; Graphiti selected W1 reference; mem0/Cognee not-selected. (ADR-0034)
- **#32** Posture single-construction-path: `AppPostureGate` is the sole `APP_POSTURE` reader; Gate Rule 12 enforces literal presence in all 3 in-memory components. (ADR-0035)
- **#33** Contract-surface truth generalization: Gate Rule 13 (no deleted SPI names in contract-catalog); Gate Rule 14 (method names in ARCHITECTURE.md code-fences must exist in Java class). (ADR-0036)
- **#34** Wave authority consolidation: ARCHITECTURE.md §1 + `architecture-status.yaml` + `CLAUDE-deferred.md` are the single wave authority; stale plans archived. (ADR-0037)
- **#35** Skill SPI resource tiering: 4 enforceability tiers (hard/sandbox/advisory/hints); enforcement claims in docs must qualify tier. (ADR-0038)
- **#36** Payload migration adapter: single normative path `Object → Payload → CausalPayloadEnvelope`; `PayloadAdapter.wrap(Object)` required; `@Deprecated` window mandatory. (ADR-0039)

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
