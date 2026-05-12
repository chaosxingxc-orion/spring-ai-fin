# 0016. A2A Federation — Strategic Deferral to Post-W4

**Status:** accepted (strategic deferral)
**Deciders:** architecture
**Date:** 2026-05-12
**Technical story:** Competitive analysis against Spring AI Alibaba (SAA) + AgentScope-Java (AS-Java) showed both frameworks ship A2A+Nacos-based distributed agent registry. spring-ai-ascend has no peer-agent discovery primitive; this ADR reserves the architectural space without scheduling W1–W4 work.

## Context

The comparative analysis (2026-05-12) confirmed that SAA ships
`spring-ai-alibaba-starter-a2a-nacos` consuming the Google A2A Java SDK
(`io.github.a2asdk`, Beta) and AS-Java ships `agentscope-extensions-a2a-{client,server}`
with Nacos-backed registry. Both treat distributed agent discovery as a first-class concern:
agents register capability descriptors (`AgentCard`) to a Nacos catalog; remote agents are
invoked across process boundaries like microservices.

spring-ai-ascend's current model supports only in-process parent→child `Run` nesting via
`SuspendSignal`. No mechanism exists to discover or invoke peer agents across JVM boundaries.

Reserving architectural space now prevents accidental API choices in W2–W4 that would
close off or complicate a future A2A-compatible surface.

**Strategic constraints in force:**
- We do not add `spring-ai-alibaba-*` artifacts as Maven dependencies (competitor).
- The official Google A2A Java SDK (`io.github.a2asdk`) is still Beta; its stability is
  not suitable for a production platform commitment before W4.
- W1–W4 schedule is fully occupied by identity, LLM gateway, action chain, memory, and
  Temporal durable workflows. Adding A2A discovery in any wave would blow the LOC budget.

## Decision Drivers

- Maintaining a path toward federated multi-agent deployment (cross-process, cross-region)
  without committing to implementation during waves where budget is constrained.
- Preventing W2–W4 design choices that would make A2A adoption at W4+ expensive to retrofit.
- Documenting the A2A contract surface so the team recognizes analogous patterns when
  reviewing future proposals.

## Considered Options

1. Defer to post-W4 as a strategic placeholder with reserved contract surface (this decision).
2. Explicitly drop A2A from the roadmap indefinitely (like ADR-0015 Python sidecar).
3. Include A2A in W4 wave alongside Temporal + eval + skill registry.

## Decision Outcome

**Chosen option:** Option 1 (strategic deferral — post-W4 placeholder).

Three contract types are named now and kept stable across W1–W4:
- **`AgentCard`** — capability descriptor; fields: `agentId`, `tenantId`, `skills[]`, `endpoint`.
- **`AgentRegistry`** — SPI interface: `register(AgentCard)`, `discover(skillName, tenantId)`.
- **`RemoteAgentClient`** — SPI interface: `invoke(AgentCard, RunContext, Object payload)` →
  `Object result`. Returns `SuspendSignal` on cross-agent suspension.

No implementation ships before W4. `a2a_federation_strategic` row in `architecture-status.yaml`
tracks intent. ADR-0033 (Logical Identity Equivalence, 2026-05-13) formalises the deployment-locus
vocabulary (S-Cloud / S-Edge / C-Device) that any A2A activation ADR will reference. A future
implementation ADR may activate `AgentRegistry` and `RemoteAgentClient` when the A2A SDK reaches
GA and platform demand justifies it.

### Consequences

**Positive:**
- W1–W4 scope stays tight.
- A2A SDK matures from Beta before we commit to it.
- The three contract types prevent W2–W4 decisions from making A2A adoption expensive.
- Nacos dependency does not enter our BoM prematurely; Consul or K8s Service are equally valid
  registry-binding targets (registry-binding is intentionally pluggable via `AgentRegistry` SPI).

**Negative:**
- Customers who need cross-process agent collaboration cannot be served until post-W4.
- SAA and AS-Java have a compounding head start on the A2A ecosystem; the gap widens until W4+.

### Reversal cost

Medium — three contract types are named; implementing them is a clean W4+ increment if the A2A
SDK stabilizes and demand materializes.

## Pros and Cons of Options

### Option 1: Strategic deferral with reserved contract surface (chosen)

- Pro: scope tight; contract surface stabilized before implementation begins.
- Pro: A2A SDK matures; registry-binding pluggable.
- Con: no cross-process agent capability until post-W4.

### Option 2: Drop A2A from roadmap entirely

- Pro: eliminates future design debt if the A2A spec never stabilizes.
- Con: closes off a likely customer requirement for distributed agent collaboration.
- Con: harder to retrofit than a clean increment from the reserved contract surface.

### Option 3: Include in W4

- Pro: narrows the gap vs SAA + AS-Java.
- Con: A2A SDK still Beta; W4 scope already stretches three weeks (Temporal + eval + HA).
- Con: adds Nacos or equivalent registry dependency before the operational model is proven.

## References

- [Google A2A Java SDK (io.github.a2asdk)](https://github.com/a2aproject/a2a-java)
- [SAA A2A Nacos starter (alibaba/spring-ai-alibaba)](https://github.com/alibaba/spring-ai-alibaba/tree/main/spring-boot-starters/spring-ai-alibaba-starter-a2a-nacos)
- [AS-Java A2A extensions (agentscope-ai/agentscope-java)](https://github.com/agentscope-ai/agentscope-java/tree/main/agentscope-extensions)
- competitive analysis: `docs/reviews/2026-05-12-competitive-analysis-and-enhancements.en.md`
- `architecture-status.yaml` row: `a2a_federation_strategic`
