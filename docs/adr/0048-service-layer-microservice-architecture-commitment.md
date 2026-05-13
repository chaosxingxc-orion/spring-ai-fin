# 0048. Service-Layer Microservice-Architecture Commitment

**Status:** accepted
**Deciders:** architecture, chaos.xing.xc@gmail.com
**Date:** 2026-05-13
**Technical story:** Mid-discussion review of `docs/spring-ai-ascend-architecture-whitepaper-en.md` realization gap surfaced a five-tier topology recommendation (per-Run serverless within long-running Agent Service instances coordinated via Agent Bus, with middleware as an outside-in peer layer). User reviewed the analysis and made a pragmatic engineering decision: the serverless direction is future-correct but the current engineering foundation does not support per-Run-serverless deployment today; commit the Service Layer to microservice architecture as a core constraint. User also directed the Agent Bus traffic split — data flow P2P, control flow on event bus — to mitigate the whitepaper §5.2 congestion-deadlock failure mode while operating under the microservice deployment commitment.

## Context

The full analysis is archived at `docs/archive/2026-05-13-serverless-architecture-future-direction.md`. Key findings driving this decision:

- W0 has serverless-friendly SPI primitives (`SuspendSignal`, `Checkpointer`, `RunRepository`, `RunStateMachine` DFA, ADR-0024 suspension atomicity).
- W0 implementations are **dev-only stubs**: `InMemoryCheckpointer` + `InMemoryRunRegistry` are fail-closed in research/prod via `AppPostureGate` (ADR-0035).
- Production serverless would require: W2 Postgres checkpointer, W2 `PayloadCodec` serialization (ADR-0022, deferred), W2 `CapabilityRegistry` to replace inline `NodeFunction` lambdas (§4 #15, deferred), W4 Temporal — none shipped.
- Industry trajectory in enterprise agent platforms (Spring AI Alibaba A2A, AutoGen distributed, AgentScope cluster) is microservice-first; engineering team familiarity with Spring Cloud is high.
- Cold-start latency for LLM agents is unsolved at production scale.
- Cross-JVM serialization of agent context (potentially MBs of conversation + tool results) has real overhead.
- Whitepaper §5.2 warns that collapsing heavy data and control flow into a single channel causes congestion deadlock — any cross-process bus implementation must respect the three-track split.

## Decision Drivers

- Engineering team velocity favors familiar Spring Cloud patterns over serverless innovation.
- Production infrastructure (Kubernetes pods, VMs) is microservice-shaped, not function-as-a-service-shaped.
- W2-W4 horizon is far; betting unproven serverless implementations on it is risky.
- The SPI shape can stay serverless-friendly without committing the deployment layer.
- Whitepaper §5.2 three-track design must be respected in any cross-process bus implementation.

## Considered Options

1. **Microservice-first for the Service Layer; SPI stays serverless-friendly; bus data-P2P / control-event-bus split** (chosen).
2. **Serverless-first** — commit to per-Run hydration as the deployment model. Rejected: production foundation not yet built; cold-start unsolved; betting against engineering team familiarity.
3. **Defer the decision** — keep both deployment options open. Rejected: leaves W1-W4 design choices ambiguous; teams need a deployment-model anchor.
4. **Single-broker bus collapsing data and control** — Rejected: re-introduces the network-congestion failure mode the whitepaper §5.2 warns about.

## Decision Outcome

**Chosen option:** Option 1.

### Service-Layer commitment

The Service Layer is deployed and scaled as **long-running microservices**:

- `agent-platform` (northbound HTTP edge): stateless across replicas; horizontal scaling.
- `agent-runtime` (cognitive runtime): long-running JVM processes; each instance holds an in-flight pool of hydrated Runs and acts as a worker on the Agent Bus.
- Multiple Agent Service instances coordinate via the Agent Bus (cross-docker, cross-service).

### Agent Bus traffic split (locked at this ADR)

The substrate choice and detailed wire formats are deferred to expanded ADR-0031 (W2+). The *split itself* is locked here so future bus implementation work cannot collapse data and control back onto a single broker.

- **Data flow is P2P** between Agent Service instances. Heavy payloads — LLM context windows, tool results, scraped documents — flow point-to-point (gRPC streaming over mTLS or equivalent), never through a central broker. This avoids the whitepaper §5.2 network-congestion failure mode where heavy data crushes control traffic.
- **Control flow is on a centralized event bus.** PAUSE/KILL/RESUME/UPDATE_CONFIG commands, scheduling decisions, capability bidding, and heartbeats flow through a pub/sub event bus (Kafka / NATS JetStream / Redpanda — choice deferred to expanded ADR-0031).
- Direct broker-to-broker forwarding of heavy data payloads is forbidden.

### Per-Run hydration remains a future direction

The SPI primitives (`SuspendSignal`, `Checkpointer`, `RunRepository`, `RunStateMachine` DFA, ADR-0024 suspension atomicity) stay serverless-friendly. The deployment commitment is at the *service-layer* level, not the *SPI* level. W4+ migration to per-Run hydration as the deployment model remains open.

### Archived analysis

The full five-tier topology analysis (per-Run serverless within long-running Agent Service instances + Agent Bus + Capability Registry + middleware + C-Side SDK), the outside-in middleware classification, and the design-difficulty/engineering-difficulty comparison are archived at `docs/archive/2026-05-13-serverless-architecture-future-direction.md` for future reference. Parked items: revising ADR-0030 (Skill SPI MCP framing), auditing ADR-0034 (memory taxonomy platform-colonization), building the Agent Client SDK, resolving the `S-side / C-side` vocabulary collision, whitepaper refresh.

### Microservice-trap mitigation (whitepaper §1.3)

The whitepaper §1.3 explicitly rejects "Microservice Dictatorship" — packaging each agent type as a heavyweight microservice with Nacos JSON-RPC fan-out. **This decision adopts microservice for the *Service Layer* (the platform itself), NOT for individual agents.** Agents within an Agent Service instance are in-process; cross-instance coordination uses the Agent Bus with the data-P2P / control-event-bus split. The bus owns scheduling, capability bidding, and work-state recording — not free-for-all inter-service RPC. Agent-to-agent calls are intent-routed through the bus, never directly endpoint-addressed.

### Out of scope

- Replacing or modifying the existing SPI primitives.
- Pre-W4 commitment to function-as-a-service deployment.
- Choosing the specific event-bus substrate (Kafka vs NATS JetStream vs Redpanda) — deferred to expanded ADR-0031.
- Choosing the specific P2P transport (gRPC streaming vs alternatives) — deferred to expanded ADR-0031.
- Multi-region replication (post-W4).

### Consequences

**Positive:**
- Engineering team velocity unblocked; familiar Spring Cloud patterns.
- Production infrastructure (Kubernetes, VMs) directly compatible.
- No cold-start latency for in-flight Runs.
- Cross-JVM state serialization is required only for Run handoff (existing scope), not every Run execution.
- Whitepaper §5.2 congestion-deadlock failure mode avoided by the data-P2P / control-event-bus separation.
- Whitepaper §1.3 microservice-dictatorship trap mitigated by scoping microservice to the Service Layer (not per-agent) and routing inter-agent calls through the bus by intent.

**Negative:**
- Idle baseline cost: each Agent Service instance is always-on, consuming memory + CPU even when its Run pool is empty.
- Cross-instance P2P fanout complexity: N instances means N*(N-1)/2 potential direct connections (mitigated by routing decisions on the event bus that minimise actual fanout).
- Long-horizon sleep (whitepaper §5.4) is less elegant: a sleeping Run still holds a slot in an instance pool until checkpointed; instances cannot scale-to-zero based on sleep state alone.
- Two bus substrates to operate (one event bus + one P2P transport) instead of one — additional ops surface compared to a single-broker design (but the single-broker design is rejected above).
- Serverless future-migration path remains a non-trivial future commitment; the SPI shape is preserved but the implementation work (Postgres checkpointer, PayloadCodec, CapabilityRegistry, Temporal) does not get easier just because the SPI is friendly.

## References

- `docs/archive/2026-05-13-serverless-architecture-future-direction.md` — archived five-tier topology analysis, outside-in middleware classification, design/engineering difficulty comparison
- `docs/spring-ai-ascend-architecture-whitepaper-en.md` §1.3 (microservice-dictatorship trap), §5.2 (three-track channel isolation rationale), §5.4 (Chronos Hydration — preserved as future direction)
- ARCHITECTURE.md §4 #46 — this ADR's main constraint
- ADR-0024 — suspension write atomicity (preserved; SPI shape stays serverless-friendly under this commitment)
- ADR-0031 — three-track channel isolation; to be expanded for cross-process wire formats, substrate choice, scheduling semantics, capability bidding mechanism, work-state event schema under this commitment
- ADR-0035 — `AppPostureGate` single-construction-path (preserved)
- `architecture-status.yaml` row: `service_layer_microservice_commitment`
