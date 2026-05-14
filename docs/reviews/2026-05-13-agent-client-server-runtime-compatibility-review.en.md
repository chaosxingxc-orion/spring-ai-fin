# L0 Architecture Review: Agent Client, Agent Server, Business Interaction Boundary, and Heterogeneous Java AI Runtime Compatibility

Date: 2026-05-13  
Audience: Architecture design team  
Scope reviewed: root `ARCHITECTURE.md`, `agent-platform/ARCHITECTURE.md`, `agent-runtime/ARCHITECTURE.md`, current W0 implementation shape, orchestration SPI contracts, existing review documents under `docs/reviews`, and the proposed product-level design intent that splits the Agent into a business-side Client and a remote Server.

## Executive Summary

The proposed product-level architecture is a distributed Agent system:

- **Agent Client** is deployed inside, or directly beside, the business system.
- **Agent Server** is deployed remotely and owns LLM access, MCP integration, durable run lifecycle, memory, tool orchestration, and external environment interaction.
- **Agent Server** should be compatible with heterogeneous Java AI runtimes such as Spring AI, LangChain4j, AgentScope-style Java runtimes, and future Java-based agent frameworks.

The current project is a strong early **Agent Server internal skeleton**, but it is not yet a complete **Agent Client / Agent Server distributed architecture**. The existing split between `agent-platform` and `agent-runtime` is a server-internal split, not a deployment-level client/server split. The current architecture also does not yet define the client-side SDK, the bidirectional Client-Server protocol, the Server-to-business-system action boundary, or the runtime-adapter SPI needed to support multiple Java AI runtimes.

The L0 architecture should be revised before W1/W2 implementation so that the following are first-class concepts:

1. `AgentClient` as the trusted business-side endpoint.
2. `AgentServer` as the remote runtime service.
3. A versioned Client-Server protocol with control, event, callback/action, and audit planes.
4. A Business Action Boundary requiring business-system interactions to be mediated by AgentClient by default.
5. A Runtime Adapter SPI that prevents the Agent Server core from depending on any single Java AI runtime's object model.

## L0 Review Standard

For this review, L0 is considered sufficient only if the architecture answers these questions without relying on future implementation guesses:

- What is deployed inside the business system?
- What is deployed remotely?
- What is the trust boundary between them?
- How does the Server request business data or business actions during a run?
- Which side owns user permission checks for business data?
- Which protocol carries run control, progress events, business action requests, and audit receipts?
- How can Spring AI, LangChain4j, AgentScope, and future Java AI runtimes be swapped or combined without changing the core domain model?

The current architecture answers parts of the remote Server internals, but it does not yet answer the full distributed Agent boundary.

## Root-Cause Block

Observed failure: the current architecture can be read as a server-side runtime only, while the product design intent requires an explicit Agent Client / Agent Server deployment model.

Execution path: a developer reading `ARCHITECTURE.md` sees `agent-platform` as the HTTP front door and `agent-runtime` as the cognitive runtime kernel; the documents then describe LLMs, MCP, tools, outbox, and memory as server-side capabilities, but no active L0 document defines a business-side Agent Client, a client callback channel, or a runtime-neutral adapter boundary for multiple Java AI frameworks.

Root cause: the original W0 architecture decomposed the remote service into platform/runtime modules before defining the higher-level distributed Agent topology. As a result, server-internal module boundaries are being used where deployment-level Client/Server boundaries are required.

Evidence:

- The current module set contains `agent-platform`, `agent-runtime`, `spring-ai-ascend-graphmemory-starter`, and the dependency BoM, but no `agent-client-api` or `agent-client-sdk` module.
- `agent-platform/ARCHITECTURE.md` describes a northbound HTTP facade, not an embedded business-side client.
- `agent-runtime/ARCHITECTURE.md` describes a cognitive runtime kernel, not a runtime-neutral Server adapter layer.
- The W0 orchestration SPI is pure Java and useful, but it has no explicit callback/action protocol for asking the business system for data or actions during a run.
- The current root architecture excludes LangChain4j dispatch from scope while the revised product intent asks for heterogeneous Java AI runtime compatibility.

## Finding 1 — AgentClient Must Be Defined as a First-Class L0 Component

### Verdict

`AgentClient` should be defined at L0. It is not optional if the intended product topology is Client inside the business system and Server remote.

### Why It Is Needed

Without an explicit Agent Client, the architecture cannot reliably define:

- Where business-user identity and permissions are captured.
- How business data is accessed without exposing internal databases to the Server.
- How the Server requests additional business context during a run.
- How local business actions are approved, executed, retried, and audited.
- How a business system integrates with the remote Agent Server without hand-written ad hoc HTTP calls.

The current `agent-platform` is not AgentClient. It is the Server-side HTTP front door.

### Recommended Definition

`AgentClient` is the trusted business-side agent endpoint. It is embedded inside the business system or deployed beside it. It initiates runs, carries business authorization context, exposes approved local business capabilities, receives Server action requests, enforces business-system permissions, and records local audit evidence before any business data or business action crosses the boundary.

### Non-Goals

AgentClient should not become a second Agent runtime. It should not own global model routing, long-running workflow state, cross-tenant memory, MCP server registry, or external LLM provider keys. Those belong to AgentServer.

### Recommended Responsibilities

AgentClient should own:

- Run submission from the business application.
- Tenant, user, role, scope, session, and business-object context collection.
- Local business capability registration.
- Local permission checks before business data leaves the business boundary.
- Local execution of business reads and business mutations when authorized.
- Server callback verification.
- Local audit logs and correlation IDs.
- Reconnection, heartbeat, timeout handling, and idempotent retry for client-side actions.

### Recommended Deployment Shapes

The primary L0 deployment shape should be an embedded Java SDK:

```text
Business System JVM
└── AgentClient SDK
    ├── Run submission API
    ├── Local capability registry
    ├── Permission bridge
    ├── Callback handler
    └── Audit bridge
```

A sidecar deployment can be supported later for non-Java systems or stricter dependency isolation:

```text
Business System
   │ localhost / mTLS / signed local token
   ▼
AgentClient Sidecar
   │ remote protocol
   ▼
AgentServer
```

### Recommended Module Shape

Add these as architecture-level modules before implementation:

```text
agent-client-api        # pure Java interfaces and DTOs
agent-client-sdk-java   # embeddable Java client implementation
agent-server-api        # wire DTOs shared by platform and client
agent-platform          # remote Server HTTP implementation
agent-runtime           # remote Server runtime kernel
```

The current project does not need to implement all of these immediately, but L0 should reserve the boundaries.

## Finding 2 — AgentClient and AgentServer Need a Versioned Protocol

### Verdict

The AgentClient-AgentServer interface must be defined as a stable product contract. It should not be treated as incidental REST calls.

### Recommended Protocol Planes

The protocol should have four planes:

| Plane | Direction | Purpose |
|---|---|---|
| Control Plane | Client -> Server | Start, resume, cancel, query runs |
| Event Plane | Server -> Client | Progress events, token deltas, terminal status, heartbeat |
| Action Plane | Server -> Client -> Business System | Business data requests, business mutations, approval requests |
| Audit Plane | Both directions | Evidence receipts, policy decisions, action correlation |

### Minimum Control API

The Server should expose a versioned run lifecycle API:

```text
POST /v1/runs
GET  /v1/runs/{runId}
POST /v1/runs/{runId}/resume
POST /v1/runs/{runId}/cancel
GET  /v1/runs/{runId}/events
```

The request envelope should include:

- `tenantId`
- `clientId`
- `userId`
- `sessionId`
- `capabilityName`
- `input`
- `businessContextRefs`
- `authorizationContext`
- `idempotencyKey`
- `callbackChannel`
- `traceId`
- `schemaVersion`

### Minimum Server-to-Client Action API

When the Server needs business data or a business action, it should issue an action request through the registered callback channel:

```text
POST {clientCallbackBaseUrl}/agent/actions
```

The action envelope should include:

- `runId`
- `actionId`
- `tenantId`
- `clientId`
- `userId`
- `operation`
- `arguments`
- `requiredScopes`
- `reason`
- `deadline`
- `idempotencyKey`
- `traceId`

The Client response should be typed:

```text
SUCCEEDED | DENIED | FAILED | RETRYABLE | EXPIRED
```

This typed response is essential because business permission denial is not the same as infrastructure failure.

### Transport Recommendation

L0 should not overfit to one transport. However, it should choose a default path:

- **Control**: HTTP/JSON, versioned under `/v1`.
- **Events**: SSE or WebSocket; SSE is simpler for W1 if only Server-to-Client streaming is needed.
- **Actions**: callback HTTP POST or reverse channel over WebSocket when Client is not directly reachable.
- **Audit**: explicit receipts in both Control and Action responses.

The key L0 decision is not the final transport library. The key decision is that the protocol is bidirectional and versioned.

## Finding 3 — Business-System Interaction Should Be Mediated by AgentClient by Default

### Verdict

AgentServer should not directly access business-system internals by default. Business data access and business mutations should be mediated by AgentClient unless an approved connector provides equivalent authorization, idempotency, tenant isolation, and audit guarantees.

### Recommended L0 Rule

Business Action Boundary:

> AgentServer may produce business action intent, but business-system data reads and business mutations must be executed through AgentClient by default. Direct Server-to-business-system access is allowed only through explicitly registered approved connectors with equivalent tenant, user, scope, idempotency, and audit controls.

### Default Path

```text
LLM / Runtime
   │
   ▼
AgentServer ActionGuard
   │
   ▼
AgentClient callback/action channel
   │
   ▼
Business permission check
   │
   ▼
Business service / repository
```

### Why Direct Access Is Dangerous

Direct Server access to business systems creates several risks:

- Server-side service accounts can bypass end-user permissions.
- Prompt injection can cause excessive business-data retrieval.
- Tenant isolation becomes harder to prove.
- Business audit trails become incomplete.
- Data minimization is weakened.
- Server implementation teams may accidentally couple agent logic to business database schemas.

### Allowed Exceptions

Direct Server access can be allowed only for approved connectors, such as:

- Public or low-sensitivity SaaS APIs.
- Enterprise APIs with OAuth2 client credentials and explicit scopes.
- Read-only reference data APIs.
- Tenant-neutral metadata services.

Even then, the connector must declare:

- Operation ID.
- Tenant scope.
- User delegation semantics.
- Required permission scope.
- Idempotency behavior.
- Audit evidence format.
- Timeout and retry policy.

### Business Data Should Prefer References Over Payloads

The Client should not send all business data up front by default. Prefer business references:

```json
{
  "businessContextRefs": [
    {
      "type": "customer",
      "id": "C123",
      "scope": "customer:summary:read",
      "expiresAt": "2026-05-13T12:00:00Z"
    }
  ]
}
```

If the Server needs details later, it requests them through AgentClient. This keeps permission checks close to the business system and reduces unnecessary data exposure.

## Finding 4 — Heterogeneous Java AI Runtime Compatibility Is Feasible but Needs an Adapter SPI

### Verdict

Supporting multiple Java AI runtimes is technically feasible, but only if the Agent Server core does not depend on any concrete runtime's object model. Spring AI can remain the default adapter, but it should not define the domain model of the core Agent Server.

### Current Assessment

The current orchestration SPI is a good foundation because it is mostly pure Java:

- `Orchestrator`
- `RunContext`
- `GraphExecutor`
- `AgentLoopExecutor`
- `ExecutorDefinition`
- `SuspendSignal`
- `Checkpointer`

However, the architecture still treats Spring AI as the primary LLM integration direction, and current documents do not define an adapter model for LangChain4j, AgentScope-style runtimes, or future Java AI frameworks.

### Recommended Runtime Adapter Boundary

Introduce a runtime-neutral adapter SPI:

```text
agent-runtime-adapter-spi
├── AiRuntimeAdapter
├── ModelGateway
├── ToolBridge
├── MemoryBridge
├── RuntimeCapabilities
└── RuntimeEventMapper
```

Concrete adapters should live outside the core:

```text
agent-runtime-spring-ai-adapter
agent-runtime-langchain4j-adapter
agent-runtime-agentscope-adapter
```

### Core Principle

AgentServer core should own:

- Run lifecycle.
- Tenant propagation.
- Idempotency semantics.
- ActionGuard and business action policy.
- Tool intent model.
- Memory port model.
- Event model.
- Audit model.

Runtime adapters should own:

- Calling the concrete model API.
- Translating tool schemas into the runtime's expected format.
- Translating runtime tool-call outputs back into the Server's tool intent model.
- Translating streaming events into the Server's event model.
- Declaring runtime capabilities and limitations.

### Minimum SPI Shape

A minimal L0 shape could be:

```java
public interface AiRuntimeAdapter {
    RuntimeId id();
    RuntimeCapabilities capabilities();
    ChatResult chat(ChatRequest request);
    StreamHandle stream(ChatRequest request, RuntimeEventSink sink);
}

public record RuntimeCapabilities(
    boolean supportsStreaming,
    boolean supportsToolCalling,
    boolean supportsStructuredOutput,
    boolean supportsEmbeddings,
    boolean supportsNativeMemory,
    boolean supportsDurableResume
) {}
```

The exact Java code does not need to be committed at L0, but the boundary should be documented.

### Important Constraint

Durable run lifecycle should remain owned by AgentServer, not by Spring AI, LangChain4j, or AgentScope. Different AI runtimes have different ideas of memory, tool calls, streaming, and agent loops. The project should normalize those into its own run/event/tool/action model.

## Recommended L0 Architecture Revision

Add a new top-level architecture section:

```text
Agent Deployment Roles
├── AgentClient
│   ├── embedded business-side SDK
│   ├── local capability registry
│   ├── permission bridge
│   ├── callback/action receiver
│   └── audit bridge
│
└── AgentServer
    ├── agent-platform
    ├── agent-runtime
    ├── runtime adapter SPI
    ├── Spring AI adapter
    ├── LangChain4j adapter
    ├── AgentScope adapter
    ├── MCP integration
    ├── memory ports
    └── durable run store
```

Add new architecture rules:

1. **Client-Server Separation Principle**: Client runs inside the business trust boundary; Server runs in the remote runtime trust boundary.
2. **Business Action Boundary**: business data and mutations go through AgentClient by default.
3. **Runtime Adapter Neutrality**: Server core does not depend on any concrete Java AI runtime object model.
4. **Protocol Versioning Rule**: Client-Server envelopes are versioned and backward compatible within a major version.
5. **Business Capability Registration Rule**: business-side tools are registered as Client capabilities and invoked only through policy-checked action envelopes.

## Proposed Module Roadmap

### L0 Documentation Only

- Define AgentClient and AgentServer roles.
- Define Client-Server protocol planes.
- Define Business Action Boundary.
- Define Runtime Adapter SPI concept.
- Mark concrete SDK and adapters as W1/W2 implementation work.

### W1 Minimal Contract

- `agent-server-api`: DTOs and OpenAPI contract for run control.
- `agent-client-api`: pure Java interfaces for run submission and callback handlers.
- `agent-client-sdk-java`: minimal embedded SDK for submit/query/cancel/events.
- Server-side callback channel design, even if only one transport is implemented.

### W2 Runtime Compatibility

- `agent-runtime-adapter-spi`.
- `agent-runtime-spring-ai-adapter` as default.
- `agent-runtime-langchain4j-adapter` as optional experimental adapter.
- Runtime capability negotiation.
- Tool-call normalization and event normalization.

### W3+ Advanced Integration

- MCP tool bridge.
- Business-side local tool registry.
- Approval workflow.
- Multi-transport callback channel.
- AgentScope-style runtime adapter if a stable Java integration surface exists.

## Final Verdict

The current project is a solid W0 foundation for the **remote Agent Server internals**, especially around platform/runtime separation, run-state DFA, pure Java orchestration SPI, and in-memory proof-of-shape execution.

It is not yet a complete L0 architecture for the proposed **Agent Client / Agent Server distributed system**. The missing pieces are conceptual and contractual, not implementation details:

- AgentClient is not defined.
- The Client-Server protocol is not defined.
- The Server-to-business-system interaction boundary is not defined.
- Heterogeneous Java AI runtime compatibility is not defined as an adapter architecture.

Recommendation: update the L0 architecture before implementing W1 run APIs or W2 LLM integration. Otherwise, early Server APIs may accidentally hard-code a server-only topology and make the later AgentClient and runtime-adapter work a breaking redesign.
