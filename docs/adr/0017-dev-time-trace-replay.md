# 0017. Dev-time Trace Replay Surface — MCP Server, No Admin UI

**Status:** accepted
**Deciders:** architecture
**Date:** 2026-05-12
**Technical story:** Competitive analysis confirmed SAA and AS-Java both ship visual trace replay (SAA-Admin + SAA-Studio; AgentScope Studio). spring-ai-ascend §1 explicitly excludes "admin UI." This ADR defines how we deliver trace replay within the §1 constraint.

## Context

Both Spring AI Alibaba and AgentScope-Java ship Studio-style trace replay:
- **SAA**: `spring-ai-alibaba-studio` (embedded dev-time UI) + `spring-ai-alibaba-admin`
  (full webapp: trace ingest from OTLP, dataset creation, evaluator, experiment). Captures
  per-node state + parent pointers via `GraphObservationLifecycleListener`; supports
  `CompiledGraph.resume(threadId, fromNode)` replay.
- **AS-Java**: Studio as a separate Node.js service consuming custom HTTP/WebSocket protocol
  (`StudioMessageHook`); OTLP as a parallel stream.

spring-ai-ascend ARCHITECTURE.md §1 states: "Not in scope: admin UI." This decision affirms
that exclusion while delivering functional trace replay through a composable mechanism that
reuses our existing strategy — MCP-server exposure of agent platform capabilities.

## Decision Drivers

- Developers debugging failing runs need a structured timeline of node executions, tool calls,
  and reasoning steps — not just raw logs.
- An Admin UI carries a significant maintenance burden (JS/CSS/HTML, auth, multi-browser
  testing, security review) that is unjustified for the developer-tooling use case.
- We already plan to expose agent capabilities via MCP (W3); a trace replay surface via MCP
  is a natural extension — any client that speaks MCP (Claude Desktop, CLI, custom scripts)
  can consume it without a dedicated UI.
- OTLP traces are already planned for W2 via Micrometer + OTel; the trace replay surface
  simply reads structured spans from the `trace_store` Postgres table.

## Considered Options

1. MCP-server trace replay (read-only, OTel-driven, no HTML/JS) — this decision.
2. Full Admin UI reversal (override §1 exclusion and ship an HTML/JS app).
3. Keep excluded; ship nothing for trace replay.

## Decision Outcome

**Chosen option:** Option 1 — MCP-server trace replay (W4).

The dev-time trace replay surface consists of:
- **`trace_store` table** (Postgres): `run_id`, `node_id`, `parent_span_id`, `kind`
  (`model_call | tool_call | agent_loop | graph_node`), `started_at`, `finished_at`,
  `prompt_tokens`, `completion_tokens`, `status`, `attributes_json`.
- **`GraphObservationLifecycleListener`** (W2, Micrometer): writes a row to `trace_store`
  on every node start + end.
- **`TraceReplayMcpServer`** (W4): exposes two MCP tools:
  - `get_run_trace(runId: String)` → list of span rows in chronological order.
  - `list_runs(tenantId: String, since: Instant, limit: int)` → recent run summaries.
- Clients: Claude Desktop (MCP native), any CLI that calls the MCP server, custom scripts.

§1 exclusion is preserved: no HTML, no JavaScript, no CSS, no browser-tested UI. The MCP
protocol is the transport; the client renders the timeline.

`trace_replay_dev_surface` row in `architecture-status.yaml` tracks intent.

### Consequences

**Positive:**
- No UI maintenance burden (JS/CSS/HTML/security review for a web surface).
- Trace data is available to any MCP client — composable, not monolithic.
- Reuses `trace_store` written by `GraphObservationLifecycleListener` (shared with eval harness
  — SAA-Admin creates datasets from traces; our eval corpus can also be seeded from trace data).
- §1 exclusion of Admin UI stays clean and unambiguous.

**Negative:**
- A visual timeline (Gantt-like, color-coded by node type) is not achievable via text-only MCP
  output; developers must mentally render the structured data.
- Clients that don't speak MCP (web browsers with no extension) cannot access the timeline
  without a third-party MCP bridge.

### Reversal cost

Low — if the review team later decides a minimal read-only trace viewer is worth the cost, the
`trace_store` schema and MCP tools are the data layer; adding a read-only React component on
top does not require schema changes.

## Pros and Cons of Options

### Option 1: MCP-server trace replay (chosen)

- Pro: no UI maintenance cost.
- Pro: MCP = composable; any compliant client benefits.
- Pro: shares data infrastructure with eval harness.
- Con: no visual rendering without a client plugin.

### Option 2: Admin UI reversal

- Pro: full visual timeline (Gantt, graph topology).
- Con: violates §1; sets precedent for UI scope creep.
- Con: significant maintenance burden (JS ecosystem, multi-browser, auth, CSP).

### Option 3: Ship nothing for trace replay

- Pro: zero maintenance cost.
- Con: debugging complex runs requires reading raw logs — unacceptable developer experience.
- Con: competitive gap vs SAA + AS-Java widens with no mitigation.

## References

- SAA Studio: [spring-ai-alibaba-studio (alibaba/spring-ai-alibaba)](https://github.com/alibaba/spring-ai-alibaba/tree/main/spring-ai-alibaba-studio)
- SAA Admin: [spring-ai-alibaba-admin (alibaba/spring-ai-alibaba-admin)](https://github.com/spring-ai-alibaba/spring-ai-alibaba-admin)
- AS-Java Studio: [AgentScope Studio observability docs](https://java.agentscope.io/en/task/observability.html)
- competitive analysis: `docs/reviews/2026-05-12-competitive-analysis-and-enhancements.en.md`
- `architecture-status.yaml` row: `trace_replay_dev_surface`
- ARCHITECTURE.md §1 (Admin UI exclusion)
